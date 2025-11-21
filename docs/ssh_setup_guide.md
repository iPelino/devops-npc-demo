# SSH Key Setup Guide

This guide explains how to generate and configure SSH keys for accessing EC2 instances in the DevOps pipeline.

## Option 1: Generate New SSH Key Pair (Recommended)

### Step 1: Generate SSH Key Locally

```bash
# Generate a new RSA key pair (4096 bits for better security)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/devops-demo-key -C "devops-demo@example.com"

# When prompted for passphrase, press Enter twice (no passphrase for CI/CD automation)
```

This creates two files:

- `~/.ssh/devops-demo-key` - Private key (keep this secure!)
- `~/.ssh/devops-demo-key.pub` - Public key

### Step 2: Import Public Key to AWS

```bash
# Set your AWS region
export AWS_REGION=us-east-1

# Import the public key to AWS EC2
aws ec2 import-key-pair \
  --key-name devops-demo-key \
  --public-key-material fileb://~/.ssh/devops-demo-key.pub \
  --region $AWS_REGION
```

Verify it was created:

```bash
aws ec2 describe-key-pairs --key-names devops-demo-key --region $AWS_REGION
```

### Step 3: Add Private Key to GitHub Secrets

1. Copy the private key content:

```bash
cat ~/.ssh/devops-demo-key
```

2. Go to your GitHub repository: `Settings` > `Secrets and variables` > `Actions`
3. Click **New repository secret**
4. Name: `SSH_PRIVATE_KEY`
5. Value: Paste the entire private key content (including `-----BEGIN` and `-----END` lines)
6. Click **Add secret**

### Step 4: Update Terraform Variable

Set the key name in your Terraform configuration. You have two options:

**Option A: Update the default in `infra/terraform/variables.tf`:**

```hcl
variable "key_name" {
  description = "Name of the SSH key pair to use"
  type        = string
  default     = "devops-demo-key"  # Change from null to your key name
}
```

**Option B: Pass via environment variable in CI/CD (add to `.github/workflows/ci.yml`):**

```yaml
- name: Terraform Apply
  run: terraform apply -auto-approve -input=false
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    TF_VAR_key_name: 'devops-demo-key'
```

## Option 2: Use Existing AWS Key Pair

If you already have an EC2 Key Pair in AWS:

### Step 1: Retrieve Private Key

You should have the `.pem` file you downloaded when you created the key pair. If you don't have it, you'll need to create a new key pair (see Option 1).

### Step 2: Add to GitHub Secrets

1. View the private key content:

```bash
cat /path/to/your-key.pem
```

2. Add it as `SSH_PRIVATE_KEY` secret in GitHub (same as Option 1, Step 3)

### Step 3: Update Terraform

Set `key_name` to your existing key pair name (same as Option 1, Step 4)

## Option 3: Create Key Pair via Terraform (Advanced)

You can also have Terraform create the key pair, but this requires storing the private key in Terraform state, which is less secure.

Add to `infra/terraform/main.tf`:

```hcl
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "deployer" {
  key_name   = "${var.environment}-deployer-key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# Update the instance to use this key
resource "aws_instance" "app_server" {
  # ... existing config ...
  key_name = aws_key_pair.deployer.key_name
  # ... rest of config ...
}
```

Add to `infra/terraform/outputs.tf`:

```hcl
output "private_key_pem" {
  description = "Private SSH key (sensitive)"
  value       = tls_private_key.ssh_key.private_key_pem
  sensitive   = true
}
```

Then retrieve and add to GitHub Secrets after first apply:

```bash
terraform output -raw private_key_pem > deployer-key.pem
chmod 600 deployer-key.pem
cat deployer-key.pem  # Copy this to GitHub Secrets
```

## Verification

After setup, test the SSH connection locally:

```bash
# Get the instance IP from Terraform
cd infra/terraform
terraform output instance_public_ip

# Test SSH connection (replace with actual IP)
ssh -i ~/.ssh/devops-demo-key ubuntu@<INSTANCE_IP>
```

If successful, you should see the Ubuntu welcome message.

## Troubleshooting

### "Permission denied (publickey)"

- Verify the private key in GitHub Secrets matches the public key in AWS
- Check that `key_name` in Terraform matches the AWS key pair name
- Ensure the Security Group allows SSH from the runner's IP (currently `0.0.0.0/0`)

### "Connection refused"

- The instance may not be fully initialized. The CI/CD pipeline includes a wait step for this.
- Verify Security Group rules allow port 22 inbound

### "Host key verification failed"

- This is handled by `StrictHostKeyChecking=no` in the CI wait step and `host_key_checking = False` in `ansible.cfg`
