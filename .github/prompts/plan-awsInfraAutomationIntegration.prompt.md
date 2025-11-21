## Plan: AWS Infra Automation Integration

Add Terraform modules for AWS resource provisioning, layer Ansible for post-provision config, wire both into GitHub Actions, and document workflows so DevOps demo covers infra + app lifecycle end to end.

### Steps
1. Scaffold `infra/terraform/` with `providers.tf`, `main.tf`, `variables.tf`, `outputs.tf`, plus env-specific configs (e.g., `envs/dev/`) and remote state backend docs/secrets guidance in `README.md`.
2. Define Terraform resources (VPC or default, security groups, EC2/ALB/SSM IAM roles) and outputs consumed by Ansible inventory templates within `infra/terraform/modules/...`.
3. Create `ansible/` directory containing `playbooks/site.yml`, `inventories/` (dynamic or Terraform-output-driven), and roles to install Node app dependencies, deploy container/images, and configure services.
4. Extend `.github/workflows/ci.yml` with jobs for `terraform fmt/validate/plan` (PR) and gated `apply` + Ansible runs on protected branches, loading AWS creds (`AWS_ACCESS_KEY_ID`, etc.) and vault/SSH secrets.
5. Update `README.md` (and/or `docs/infra.md`) with instructions for local Terraform/Ansible usage, CI secrets, and rollback procedures so contributors can reproduce the pipeline.

### Further Considerations
1. **State Backend**: Use S3 + DynamoDB locking vs. Terraform Cloud? Pick one before coding.
2. **Inventory Source**: Dynamic AWS inventory plugin vs. Terraform-generated host file? Impacts CI secrets.
3. **Provisioned Targets**: Run Node app on EC2 (systemd) vs. ECS/Fargate? Choose to determine Terraform modules + Ansible roles.
