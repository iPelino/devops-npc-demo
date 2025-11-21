# Terraform State Recovery Guide

This guide explains how to handle "already exists" errors when Terraform state is out of sync with AWS.

## Problem

When you see errors like:

```
Error: The security group 'dev-app-sg' already exists
Error: Role with name dev-ec2-role already exists
```

This means:

1. Resources exist in AWS from a previous deployment
2. Terraform's state file doesn't know about them (lost/reset state)
3. Terraform tries to create them again and fails

## Solution 1: Import Existing Resources (Quick Fix)

Import the existing AWS resources into Terraform state:

```bash
cd infra/terraform

# Get the VPC ID where security group exists
export VPC_ID="vpc-03dc65d7e9e2d1f92"  # From the error message

# Get the security group ID
export SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=dev-app-sg" "Name=vpc-id,Values=$VPC_ID" \
  --query 'SecurityGroups[0].GroupId' \
  --output text)

# Import security group
terraform import aws_security_group.app_sg $SG_ID

# Import IAM role
terraform import aws_iam_role.ec2_role dev-ec2-role

# Import IAM role policy attachment
terraform import aws_iam_role_policy_attachment.ssm_policy dev-ec2-role/arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

# Import IAM instance profile
terraform import aws_iam_instance_profile.ec2_profile dev-ec2-profile

# Get the instance ID if it exists
export INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=dev-app-server" "Name=instance-state-name,Values=running,stopped" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)

# Import instance (if exists)
if [ "$INSTANCE_ID" != "None" ] && [ "$INSTANCE_ID" != "" ]; then
  terraform import aws_instance.app_server $INSTANCE_ID
fi

# Now run plan/apply
terraform plan
```

## Solution 2: Destroy and Recreate (Clean Slate)

If you want to start fresh:

```bash
# Manually delete resources in AWS Console or via CLI
aws ec2 terminate-instances --instance-ids <INSTANCE_ID>
aws ec2 delete-security-group --group-id <SG_ID>
aws iam remove-role-from-instance-profile --instance-profile-name dev-ec2-profile --role-name dev-ec2-role
aws iam delete-instance-profile --instance-profile-name dev-ec2-profile
aws iam detach-role-policy --role-name dev-ec2-role --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
aws iam delete-role --role-name dev-ec2-role

# Then run terraform apply
cd infra/terraform
terraform apply
```

## Solution 3: Setup Remote State (Recommended for Production)

Prevent this issue by using persistent remote state in S3:

### Step 1: Create S3 Backend Resources

```bash
# Set variables
export AWS_REGION=us-east-1
export STATE_BUCKET=my-devops-demo-tfstate-$(date +%s)
export LOCK_TABLE=my-devops-demo-tflock

# Create S3 bucket for state
aws s3 mb s3://$STATE_BUCKET --region $AWS_REGION

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket $STATE_BUCKET \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket $STATE_BUCKET \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Create DynamoDB table for locking
aws dynamodb create-table \
  --table-name $LOCK_TABLE \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region $AWS_REGION

echo "Bucket: $STATE_BUCKET"
echo "Table: $LOCK_TABLE"
```

### Step 2: Update Terraform Backend

Edit `infra/terraform/providers.tf` and uncomment/update the backend block:

```hcl
backend "s3" {
  bucket         = "your-actual-bucket-name"  # Use the bucket name from above
  key            = "devops-demo/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "my-devops-demo-tflock"
}
```

### Step 3: Initialize and Migrate State

```bash
cd infra/terraform

# Re-initialize with new backend
terraform init -migrate-state

# Verify state is in S3
aws s3 ls s3://$STATE_BUCKET/devops-demo/
```

### Step 4: Update CI/CD

The backend configuration is already in `providers.tf`, so no CI changes needed. Just ensure the AWS credentials have S3 and DynamoDB permissions.

## For CI/CD Environments

Add this step before `Terraform Apply` in `.github/workflows/ci.yml`:

```yaml
- name: Check for existing resources and import
  run: |
    # Try to import security group if it exists
    SG_ID=$(aws ec2 describe-security-groups \
      --filters "Name=group-name,Values=dev-app-sg" \
      --query 'SecurityGroups[0].GroupId' \
      --output text 2>/dev/null || echo "")

    if [ "$SG_ID" != "" ] && [ "$SG_ID" != "None" ]; then
      echo "Importing existing security group: $SG_ID"
      terraform import -input=false aws_security_group.app_sg $SG_ID || true
    fi

    # Try to import IAM role if it exists
    if aws iam get-role --role-name dev-ec2-role >/dev/null 2>&1; then
      echo "Importing existing IAM role"
      terraform import -input=false aws_iam_role.ec2_role dev-ec2-role || true
      terraform import -input=false aws_iam_role_policy_attachment.ssm_policy dev-ec2-role/arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore || true
      terraform import -input=false aws_iam_instance_profile.ec2_profile dev-ec2-profile || true
    fi
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

## Best Practice

**Always use remote state for any non-local deployment.** Local state in CI/CD is ephemeral and will cause these issues on every run.
