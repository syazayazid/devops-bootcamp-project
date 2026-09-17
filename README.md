# DevOps Bootcamp Final Project — Automated Monitoring & Deployment Infrastructure on AWS

This project demonstrates an end-to-end DevOps workflow by provisioning cloud infrastructure with **Terraform** and configuring/deploying services with **Ansible**. The infrastructure consists of a monitoring stack (Grafana + Prometheus), an Ansible control node, and a public-facing web server that runs a containerized application pulled from Amazon ECR.

---

## Table of Contents

- [Infrastructure Overview](#infrastructure-overview)
- [Terraform Structure](#terraform-structure)
- [Ansible Structure](#ansible-structure)
- [What is Grafana?](#what-is-grafana)
- [What is Prometheus?](#what-is-prometheus)
- [What is Ansible?](#what-is-ansible)
- [Building & Pushing a Docker Image to Amazon ECR](#building--pushing-a-docker-image-to-amazon-ecr)

---

## Infrastructure Overview

| Component | Private IP | Subnet Type | Security Group | Purpose |
|---|---|---|---|---|
| Monitoring Server | 10.0.0.136 | Private | Private | Hosts Grafana & Prometheus |
| Ansible Controller | 10.0.0.135 | Private | Private | Runs Ansible playbooks to configure/deploy services |
| Web Server | 10.0.0.5 (+ Elastic IP) | Public | Public | Runs Docker container from ECR |

**Network Details**

| Item | Value |
|---|---|
| AWS Region | ap-southeast-1 |
| VPC | devops-vpc |
| CIDR Block | 10.0.0.0/24 |

**Domains & DNS**

| URL | Points To | How it's exposed |
|---|---|---|
| monitor.nurinyazid.my | Monitoring Server (Grafana) | Cloudflare Tunnel (no public inbound access) |
| web.nurinyazid.my | Web Server (Dockerized App) | Cloudflare DNS → Elastic IP |

**ECR Image**

```
ecr_registery.dkr.ecr.ap-southeast-1.amazonaws.com/devops-bootcamp-final:latest
```

### Connectivity: NAT Gateway & Cloudflare Tunnel

Since the Monitoring Server and Ansible Controller sit in a **private subnet** with no public IP, a **NAT Gateway** is used to give them outbound internet access (e.g. for package installs, pulling Docker images, or reaching Cloudflare). However, NAT Gateway alone does not allow *inbound* traffic — there's no way to reach Grafana on `10.0.0.136` directly from the internet.

To solve this without opening any inbound ports or attaching a public IP to the monitoring server, this project uses **Cloudflare Tunnel** (`cloudflared`):

- `cloudflared` runs on the Monitoring Server and creates an **outbound-only** encrypted connection to Cloudflare's edge.
- Cloudflare then routes `monitor.nurinyazid.my` through that tunnel back to Grafana, without needing any inbound security group rule or public IP on the instance.
- This keeps the monitoring server fully private while still making the Grafana dashboard reachable at `monitor.nurinyazid.my`.

For the **Web Server**, since it already has an Elastic IP in the public subnet, exposure is simpler — a **Cloudflare DNS A record** for `web.nurinyazid.my` simply points directly to the Elastic IP.

| Server | Exposure Method | Why |
|---|---|---|
| Monitoring Server (private) | Cloudflare Tunnel (outbound-only, via NAT Gateway) | No public IP / inbound rule needed |
| Web Server (public) | Cloudflare DNS → Elastic IP | Already public-facing, direct routing works |

---

## Terraform Structure

| File | Purpose |
|---|---|
| `network.tf` | Defines VPC, subnets (public/private), route tables |
| `ec2.tf` | Provisions the 3 EC2 instances |
| `security.tf` | Defines security groups (public/private rules) |
| `providers.tf` | AWS provider & Terraform configuration |
| `output.tf` | Outputs (IPs, resource IDs) for reference |
| `inventory.tf` | Generates dynamic Ansible inventory from Terraform outputs |
| `inventory.ini.tftpl` | Template file used to render the Ansible inventory |

---

## Ansible Structure

| File | Purpose |
|---|---|
| `ansible.cfg` | Ansible configuration (inventory path, SSH settings, etc.) |
| `inventory.ini` | List of managed hosts (monitoring, web server) |
| `playbook-stack.yaml` | Deploys the monitoring stack (Grafana + Prometheus) |
| `playbook-exporter.yaml` | Installs/configures Prometheus Node Exporter on target hosts |
| `playbook-ship.yaml` | Deploys/ships the application container to the web server |
| `prometheus.yaml` | Prometheus configuration file (scrape targets, jobs) |
| `compose.yaml` | Docker Compose file used to run Grafana/Prometheus or the app container |

---

## What is Grafana?

Grafana is an open-source **visualization and dashboarding tool**. It doesn't collect data itself — instead, it connects to data sources (like Prometheus, InfluxDB, Elasticsearch, etc.) and lets you build interactive dashboards, graphs, and alerts on top of that data. In this project, Grafana is used to visualize metrics collected by Prometheus, giving a real-time view of system health (CPU, memory, network, etc.) for the servers in the infrastructure.

## What is Prometheus?

Prometheus is an open-source **monitoring and alerting system** designed for reliability and time-series data. It works by "scraping" (pulling) metrics from configured targets at regular intervals via HTTP endpoints (usually `/metrics`). Each target — like a server running Node Exporter — exposes metrics that Prometheus stores in its own time-series database. Prometheus can also trigger alerts based on defined rules (e.g., "alert if CPU > 90% for 5 minutes"). In this project, Prometheus scrapes metrics from the web server (via Node Exporter) and feeds that data to Grafana for visualization.

## What is Ansible?

Ansible is an open-source **configuration management and automation tool** that lets you define infrastructure tasks (installing packages, deploying containers, editing configs) as code, written in YAML "playbooks". It's **agentless** — it connects to target servers via SSH and doesn't require any special software installed on managed nodes (other than Python). In this project, Ansible is run from the dedicated controller server to:

- Install and configure the Grafana/Prometheus stack on the monitoring server
- Install Prometheus Node Exporter on managed hosts
- Deploy and run the Docker container (pulled from ECR) on the web server

---

## Building & Pushing a Docker Image to Amazon ECR

Here's the general workflow to push a Docker image to ECR:

| Step | Command / Action |
|---|---|
| 1. Authenticate Docker to ECR | `aws ecr get-login-password --region ap-southeast-1 \| docker login --username AWS --password-stdin ecr_registery.dkr.ecr.ap-southeast-1.amazonaws.com` |
| 2. Build the Docker image | `docker build -t devops-bootcamp-final .` |
| 3. Tag the image for ECR | `docker tag devops-bootcamp-final:latest ecr_registery.dkr.ecr.ap-southeast-1.amazonaws.com/devops-bootcamp-final:latest` |
| 4. Push the image to ECR | `docker push ecr_registery.dkr.ecr.ap-southeast-1.amazonaws.com/devops-bootcamp-final:latest` |
| 5. Pull image on target server (via Ansible/Docker Compose) | `docker pull ecr_registery.dkr.ecr.ap-southeast-1.amazonaws.com/devops-bootcamp-final:latest` |

**Notes:**

- Step 1 requires the AWS CLI configured with credentials that have `ecr:GetAuthorizationToken` and push/pull permissions on the repository.
- If the ECR repository (`devops-bootcamp-final`) doesn't exist yet, create it first with:
  ```bash
  aws ecr create-repository --repository-name devops-bootcamp-final --region ap-southeast-1
  ```
- On the web server side, since it's on a public subnet, you'd typically have Ansible run the `docker login` + `docker pull` + `docker compose up` sequence as part of `playbook-ship.yaml`, using an IAM role attached to the EC2 instance (recommended) rather than hardcoded credentials.
