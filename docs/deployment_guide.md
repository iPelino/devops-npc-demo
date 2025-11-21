# DevOps Deployment Guide

This guide details the configuration and settings required to set up the DevOps deployment pipeline for the Node.js Demo App.

## 1. Prerequisites

Ensure you have the following tools installed locally for development and troubleshooting:

*   **AWS CLI**: [Install Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
*   **Terraform** (v1.2.0+): [Install Guide](https://developer.hashicorp.com/terraform/downloads)
*   **Ansible**: [Install Guide](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)
*   **Docker**: [Install Guide](https://docs.docker.com/get-docker/)

## 2. AWS Configuration

### IAM User for CI/CD
Create an IAM User in AWS with programmatic access (Access Key ID and Secret Access Key). This user requires permissions to provision resources.

**Recommended Policy (Least Privilege):**
For this demo, the user needs permissions for:
*   **EC2**: `AmazonEC2FullAccess` (or restricted to specific regions/tags)
*   **IAM**: Permissions to create Roles and Instance Profiles (`iam:CreateRole`, `iam:PutRolePolicy`, `iam:CreateInstanceProfile`, etc.)
*   **S3 & DynamoDB**: If using remote state (see below).

### Key Pair (Optional)
If you intend to debug via SSH manually (outside of SSM), create an EC2 Key Pair in your target region (default `us-east-1`).
*   Download the `.pem` file.
*   Extract the private key content for GitHub Secrets.

## 3. GitHub Repository Settings

Navigate to `Settings` > `Secrets and variables` > `Actions` in your GitHub repository.

### Repository Secrets
Add the following secrets:

| Secret Name | Description |
| :--- | :--- |
| `AWS_ACCESS_KEY_ID` | The Access Key ID for the CI/CD IAM User. |
| `AWS_SECRET_ACCESS_KEY` | The Secret Access Key for the CI/CD IAM User. |
| `SSH_PRIVATE_KEY` | Private SSH key content (PEM format) for Ansible to connect to the EC2 instance. |
| `GHCR_PAT` | (Optional) Personal Access Token if default `GITHUB_TOKEN` permissions are insufficient for packages. |

### Branch Protection Rules
To ensure the "Infrastructure Apply" job only runs on approved code:
1.  Go to `Settings` > `Branches`.
2.  Add a rule for `main`.
3.  Check **Require a pull request before merging**.
4.  Check **Require status checks to pass before merging** (select `build-test` and `infra-plan`).

## 4. Terraform Configuration

### Remote State (Recommended)
By default, this project uses local state, which is reset on every CI run. For a persistent environment:

1.  **Create S3 Bucket**: e.g., `my-devops-demo-tfstate` (enable versioning).
2.  **Create DynamoDB Table**: e.g., `my-devops-demo-tflock` (Partition key: `LockID`).
3.  **Update `infra/terraform/providers.tf`**:
    Uncomment the `backend "s3"` block and update the bucket/table names.

```hcl
backend "s3" {
  bucket         = "my-devops-demo-tfstate"
  key            = "devops-demo/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "my-devops-demo-tflock"
}
```

## 5. Ansible Configuration

The Ansible playbook (`ansible/playbook.yml`) is configured to:
1.  Install Docker.
2.  Log in to GitHub Container Registry (GHCR).
3.  Pull and run the app container.

**Note on SSH Host Key Checking:**
`ansible/ansible.cfg` has `host_key_checking = False` to allow CI to connect to new instances without manual verification. Ensure this aligns with your security policy.

## 6. Deployment Workflow

1.  **Feature Branch**:
    *   Push changes to a feature branch.
    *   GitHub Actions runs `build-test` (App) and `infra-plan` (Terraform).
    *   Review the Terraform Plan output in the Actions logs.

2.  **Merge to Main**:
    *   Merge Pull Request to `main`.
    *   GitHub Actions runs `docker` (Build & Push Image).
    *   Then runs `infra-apply` (Terraform Apply).
    *   Finally runs `Run Ansible` to deploy the new image to the infrastructure.

## 7. Troubleshooting

*   **Terraform Lock**: If a job is cancelled mid-run, the state might be locked. You may need to manually unlock it via AWS CLI or Terraform force-unlock.
*   **Ansible Connection**: If Ansible fails to connect, verify the Security Group allows SSH from the runner's IP (currently `0.0.0.0/0` in `variables.tf` - restrict this for production!).
*   **GHCR Login**: If the app fails to pull the image, ensure the `GITHUB_TOKEN` has `read:packages` permissions or use a PAT.
