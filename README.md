# DevOps Demo App

A minimal Express.js service that demonstrates a complete DevOps workflow: app code, automated tests, Docker containerization, local orchestration with Compose, and CI/CD via GitHub Actions.

## Features

- `/` route returns service metadata for quick smoke checks.
- `/health` route exposes uptime and version info for probes.
- Ready for container builds with multi-stage `Dockerfile` and `docker-compose.yml` for local iteration.
- GitHub Actions workflow runs lint, tests, and optionally publishes images to GHCR.

## Prerequisites

- Node.js 20+
- Docker Desktop (for container builds / Compose)

## Local Development

Install dependencies and run tests:

```bash
npm install
npm test
```

Start the server locally:

```bash
npm run dev
```

The service listens on `http://localhost:3000`.

## Docker

Build and run with Docker:

```bash
docker build -t devops-demo .
docker run -p 3000:3000 devops-demo
```

Or use Compose for hot reloads:

```bash
docker compose up --build
```

## Configuration

Environment variables (see `.env.example`):

- `PORT`: Port to bind (default `3000`).
- `APP_VERSION`: Surface build metadata in `/health`.

## CI/CD

`.github/workflows/ci.yml` executes lint/test for all pushes and publishes container images to `ghcr.io/<owner>/<repo>` when commits land on `main`. Set up your GitHub Container Registry permissions before merging.

## Infrastructure

The project includes Terraform for provisioning AWS resources and Ansible for configuration management.

### Prerequisites

- AWS Account and credentials
- Terraform >= 1.2.0
- Ansible

### Setup

1.  **Secrets**: Configure the following secrets in your GitHub repository:

    - `AWS_ACCESS_KEY_ID`: AWS Access Key ID
    - `AWS_SECRET_ACCESS_KEY`: AWS Secret Access Key
    - `SSH_PRIVATE_KEY`: Private SSH key for Ansible to connect to EC2 instances. (Ensure the corresponding public key is added to `infra/terraform/variables.tf` or passed as a variable if you enable key pair creation).

2.  **Terraform**:

    - Navigate to `infra/terraform`.
    - Initialize: `terraform init`.
    - Plan: `terraform plan`.
    - Apply: `terraform apply`.

3.  **Ansible**:
    - Navigate to `ansible`.
    - Run playbook: `ansible-playbook -i inventory_file playbook.yml` (Note: The CI pipeline handles dynamic inventory based on Terraform outputs).

### Architecture

- **Terraform**: Provisions an EC2 instance (Ubuntu 22.04) with a Security Group allowing SSH (22) and App (3000) traffic. It also sets up IAM roles for SSM access.
- **Ansible**: Installs Docker on the provisioned instance, logs into GHCR, pulls the latest image, and runs the container.
