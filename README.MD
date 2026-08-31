# eks-platform

A from-scratch Terraform setup for provisioning EKS clusters (dev, staging,
prod) using **EKS Auto Mode**, bootstrapped with **ArgoCD** for GitOps.
Terraform builds the infrastructure and hands off to ArgoCD; everything
after "a running cluster with ArgoCD installed" is managed as Git commits,
not `terraform apply`.

This README is written so a teammate with no prior context can clone this
repo and stand up their own environment end to end. Follow it in order —
each step depends on the one before it.

---

## Table of contents

1. [Architecture overview](#1-architecture-overview)
2. [Repository structure](#2-repository-structure)
3. [Prerequisites](#3-prerequisites)
4. [One-time setup: state backend](#4-one-time-setup-state-backend)
5. [Files you must edit before applying](#5-files-you-must-edit-before-applying)
6. [Step-by-step: deploying an environment](#6-step-by-step-deploying-an-environment)
7. [Verifying the cluster and ArgoCD](#7-verifying-the-cluster-and-argocd)
8. [Adding add-ons (the GitOps way)](#8-adding-add-ons-the-gitops-way)
9. [Repeating for staging and prod](#9-repeating-for-staging-and-prod)
10. [Tearing everything down](#10-tearing-everything-down)
11. [Cost awareness](#11-cost-awareness)
12. [Security notes](#12-security-notes)
13. [Troubleshooting](#13-troubleshooting)
14. [Design decisions / FAQ](#14-design-decisions--faq)

---

## 1. Architecture overview

Three layers, applied in order by Terraform:

1. **Network** (`modules/vpc`) — VPC, public/private subnets across
   configurable AZs, Internet Gateway, NAT Gateway(s).
2. **Cluster** (`modules/eks-cluster`) — EKS control plane running in
   **Auto Mode** (AWS manages node lifecycle — no manually-defined node
   groups), IAM roles, KMS-encrypted Kubernetes Secrets, OIDC provider.
3. **Platform bootstrap** (`modules/helm-bootstrap`) — installs ArgoCD via
   Helm, then creates a single ArgoCD "app of apps" `Application` pointed
   at this repo's `gitops/infrastructure/<env>/` folder.

**After that, Terraform is done.** Every add-on that runs on top of the
cluster (ingress controller, cert-manager, policy engines, monitoring,
etc.) is added as a Git commit under `gitops/infrastructure/<env>/`, and
ArgoCD deploys it automatically. Do not add `helm_release` or
`aws_eks_addon` resources to the environment `.tf` files for anything
beyond the bare cluster — that fights ArgoCD for ownership.

Three independent environments (`dev`, `staging`, `prod`) share the same
Terraform modules but have separate state, separate VPCs (non-overlapping
CIDRs), and separate `.tfvars`.

---

## 2. Repository structure

```
eks-platform/
├── README.md                          <- you are here
│
├── global/backend-bootstrap/          <- run ONCE, ever (not per environment)
│   ├── main.tf                        creates the S3 state bucket + KMS key
│   ├── variables.tf
│   └── outputs.tf
│
├── modules/                           <- shared logic, called 3x (dev/staging/prod)
│   ├── vpc/                           VPC, subnets, IGW, NAT
│   ├── eks-cluster/
│   │   ├── iam.tf                     cluster + node IAM roles
│   │   ├── main.tf                    KMS key, EKS cluster (Auto Mode), OIDC provider
│   │   ├── variables.tf / versions.tf / outputs.tf
│   └── helm-bootstrap/                installs ArgoCD, creates the app-of-apps
│
├── environments/
│   ├── dev/
│   │   ├── backend.tf                 state bucket + key for this env
│   │   ├── versions.tf                required Terraform/provider versions
│   │   ├── providers.tf               aws / kubernetes / helm / kubectl provider config
│   │   ├── variables.tf               variable declarations + defaults
│   │   ├── main.tf                    wires the 3 modules together
│   │   ├── outputs.tf
│   │   └── terraform.tfvars           <- YOU EDIT THIS per environment
│   ├── staging/    (identical structure)
│   └── prod/       (identical structure, stricter defaults)
│
└── gitops/infrastructure/
    ├── dev/        <- ArgoCD watches this. Empty until you add something.
    ├── staging/
    └── prod/
```

---

## 3. Prerequisites

Install these locally before doing anything else:

| Tool | Minimum version | Why |
|---|---|---|
| [Terraform](https://developer.hashicorp.com/terraform/install) | `>= 1.11.0` | Native S3 state locking (`use_lockfile`) requires this version or newer |
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) | v2 | Authenticating to AWS, running `aws eks update-kubeconfig` |
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | Any recent version matching your cluster's K8s minor version (1.33) | Talking to the cluster after it's up |
| Git | Any recent version | This repo needs to live in a Git remote ArgoCD can reach |

You'll also need:

- **An AWS account** with permissions to create: VPCs/subnets/NAT/IGW,
  IAM roles/policies, EKS clusters, KMS keys, S3 buckets. If you're not
  using an admin-level role, ask whoever manages IAM in your org for a
  role/user with those permissions.
- **AWS credentials configured locally** — e.g. run `aws configure` (or
  `aws configure sso` if your org uses SSO) so the AWS provider can
  authenticate. Terraform will use whatever your default AWS CLI
  profile/credentials resolve to, unless you set `AWS_PROFILE`.
- **A Git remote for this repo** (GitHub, GitLab, etc.) that ArgoCD can
  reach — this is where you'll push `gitops/` changes for ArgoCD to sync.
  A **public** repo is simplest to start with; a private repo works too
  but needs an ArgoCD repo credential added separately (not covered in
  this README — see [ArgoCD's private repo docs](https://argo-cd.readthedocs.io/en/stable/user-guide/private-repositories/)
  if you need that).

---

## 4. One-time setup: state backend

This step runs **once for the whole team/project** — not once per person,
not once per environment. Whoever sets this up first should share the
resulting bucket name with the rest of the team.

```bash
cd global/backend-bootstrap
terraform init
terraform apply -var="state_bucket_name=<pick-a-globally-unique-name>"
```

Example: `terraform apply -var="state_bucket_name=acme-eks-platform-tfstate"`
(S3 bucket names are globally unique across *all* AWS accounts, so add
your company/team name to avoid collisions).

When it finishes, note the output:

```
state_bucket_name = "acme-eks-platform-tfstate"
```

You'll need this exact value in the next section. This bucket now holds
Terraform state for all three environments (each in its own key/prefix) —
do not run this bootstrap again, and do not delete this bucket without
understanding you'd be destroying every environment's state.

---

## 5. Files you must edit before applying

Every one of these has a placeholder in the repo. Search for `REPLACE`
if you want to find them quickly.

| File | What to change | Example |
|---|---|---|
| `environments/dev/backend.tf` | `bucket` — the state bucket name from Step 4 | `bucket = "acme-eks-platform-tfstate"` |
| `environments/staging/backend.tf` | same | same |
| `environments/prod/backend.tf` | same | same |
| `environments/dev/terraform.tfvars` | `gitops_repo_url` — your Git remote URL for **this repo** | `"https://github.com/your-org/eks-platform.git"` |
| `environments/dev/terraform.tfvars` | `endpoint_public_access_cidrs` — your office/VPN public IP CIDR | `["198.51.100.0/24"]` |
| `environments/staging/terraform.tfvars` | same two as dev | same |
| `environments/prod/terraform.tfvars` | `gitops_repo_url` only (prod has no public endpoint, so no CIDR to set) | `"https://github.com/your-org/eks-platform.git"` |

Optional, only if defaults don't fit your situation:

| File | What you might change | Default |
|---|---|---|
| any `terraform.tfvars` | `aws_region` | `us-east-1` |
| any `terraform.tfvars` | `vpc_cidr` (must not overlap between environments if you ever peer them) | `10.0.0.0/16` / `10.1.0.0/16` / `10.2.0.0/16` |
| any `terraform.tfvars` | `kubernetes_version` | `1.33` |
| `environments/prod/terraform.tfvars` | `gitops_target_revision` — consider pinning to a release tag instead of `main` for prod | `main` |

There is **no AWS account number anywhere in this repo** — Terraform
picks it up automatically from whichever AWS credentials/profile is
active in your terminal. If you work across multiple AWS accounts,
double-check `aws sts get-caller-identity` shows the account you expect
before running `terraform apply`.

---

## 6. Step-by-step: deploying an environment

Do `dev` first. Don't skip to staging/prod until dev works end to end.

```bash
# 1. Confirm you're pointed at the right AWS account
aws sts get-caller-identity

# 2. Go to the dev environment
cd environments/dev

# 3. Edit backend.tf and terraform.tfvars as described in Section 5

# 4. Initialize Terraform (downloads providers, connects to the S3 backend)
terraform init

# 5. Review the plan — read it, don't just skim past it
terraform plan

# 6. Apply
terraform apply
```

`terraform apply` will prompt for confirmation (`yes`). This single apply
creates, in order: VPC → subnets/NAT/IGW → EKS cluster (Auto Mode) → IAM
roles → KMS key → OIDC provider → ArgoCD (via Helm) → the app-of-apps
`Application`. Expect this to take **15-20 minutes**, most of it waiting
on the EKS control plane to become active.

```bash
# 7. Point kubectl at your new cluster (copy the exact command from the output)
terraform output configure_kubeconfig
# then run whatever it prints, e.g.:
aws eks update-kubeconfig --name eks-platform-dev --region us-east-1


aws eks update-kubeconfig --name eks-platform-dev --region us-east-1

# 8. Confirm you can reach it
kubectl get nodes
```

---

## 7. Verifying the cluster and ArgoCD

```bash
# Cluster is Auto Mode — you should see nodes AWS provisioned automatically
kubectl get nodes

# ArgoCD should be running in its own namespace
kubectl get pods -n argocd

# The app-of-apps Application should show up and be Synced/Healthy
kubectl get application -n argocd
```

To log into the ArgoCD UI:

```bash
# Get the auto-generated admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Port-forward the ArgoCD server locally (quickest way to reach the UI
# without setting up an ingress yet)
kubectl -n argocd port-forward svc/argocd-server 8080:443
```

Then open `https://localhost:8080` — username `admin`, password from
above. Change this password (or wire up SSO) before this cluster holds
anything real; the initial admin secret is meant to be temporary.

---

## 8. Adding add-ons (the GitOps way)

This is the whole point of the ArgoCD bootstrap. To add something (AWS
Load Balancer Controller, cert-manager, external-secrets, a policy engine,
monitoring, etc.):

1. Add an ArgoCD `Application` manifest (or a Kustomize overlay) under
   `gitops/infrastructure/<env>/`.
2. Commit and push to the branch/tag your `gitops_target_revision`
   points at (`main` by default).
3. ArgoCD picks it up automatically — the app-of-apps has
   `automated.selfHeal` and `automated.prune` turned on, so it syncs
   without you touching `kubectl apply` or `terraform apply`.

**Never** add a `helm_release` or `aws_eks_addon` Terraform resource for
these — Terraform's job stopped at "cluster + ArgoCD exist." Suggested
order to add things in for a production-ready, secured cluster:

1. AWS Load Balancer Controller (ALB/NLB ingress)
2. cert-manager (TLS automation)
3. external-secrets (pull from AWS Secrets Manager/SSM instead of raw
   K8s secrets)
4. A policy engine — Kyverno or OPA/Gatekeeper (block privileged pods,
   enforce resource limits)
5. GuardDuty EKS Protection / Runtime Monitoring agent
6. EBS/EFS CSI drivers (persistent storage)
7. metrics-server (needed for HPA)
8. An observability stack (Prometheus/Grafana or CloudWatch Container
   Insights)

---

## 9. Repeating for staging and prod

Same steps as Section 6, just in `environments/staging` and
`environments/prod`. Reminders:

- Each environment has **completely separate state** — applying prod
  cannot accidentally touch dev's resources.
- `prod` has no public API endpoint by design (`endpoint_public_access =
  false`). You'll need VPN/bastion/Transit Gateway access into that VPC,
  or a CI runner deployed inside it, to reach `kubectl` against prod.
- Consider pinning `gitops_target_revision` in prod's `terraform.tfvars`
  to a release tag rather than tracking `main` directly, so a bad commit
  to `gitops/` can't immediately roll out to prod.

---

## 10. Tearing everything down

Per environment, in reverse order of how you'd apply:

```bash
cd environments/dev
terraform destroy
```

Notes:
- This destroys the VPC, cluster, and everything ArgoCD deployed to it
  (since those Kubernetes resources live inside the cluster being
  deleted) — but it does **not** touch the shared state bucket from
  Section 4, which is protected with `prevent_destroy`.
- If `terraform destroy` fails partway because Auto Mode's own
  AWS-managed resources (e.g. an ALB created by an Ingress you added via
  ArgoCD) still hold a dependency, delete those Kubernetes objects first
  (`kubectl delete ...`) and re-run `terraform destroy`.

---

## 11. Cost awareness

Before leaving any environment running unattended, know what's billing:

- **EKS control plane**: a flat hourly charge per cluster, per environment.
- **NAT Gateways**: hourly charge *per NAT Gateway* plus per-GB data
  processing. `prod`'s `per_az` strategy means 3 NAT Gateways instead of
  1 — meaningfully more expensive than dev/staging's `single` strategy.
- **EKS Auto Mode compute**: billed per vCPU/memory of the nodes AWS
  provisions on your behalf — same underlying EC2 pricing model, just
  managed for you.
- **KMS keys**: minor per-key monthly charge, negligible.

If you're just testing this out, `terraform destroy` your dev environment
when you're done for the day rather than leaving it running.

---

## 12. Security notes

- Kubernetes Secrets are envelope-encrypted with KMS at the cluster level
  — set at creation time, cannot be retrofitted onto an existing cluster
  without recreating it.
- `dev`/`staging` allow public API endpoint access **restricted to the
  CIDR you set** in `endpoint_public_access_cidrs` — never leave this as
  `0.0.0.0/0`.
- `prod` has no public endpoint at all.
- Auto Mode node IAM role uses `AmazonEKSWorkerNodeMinimalPolicy` (not the
  broader legacy `AmazonEKSWorkerNodePolicy`) and pull-only ECR access —
  don't loosen this without a reason.
- ArgoCD's initial admin password (Section 7) is meant to be rotated or
  replaced with SSO before real workloads go on the cluster.
- Control plane audit/authenticator/controllerManager/scheduler logs ship
  to CloudWatch by default — useful for both security investigation and
  debugging.

---

## 13. Troubleshooting

**`terraform init` fails on the backend** — double check the bucket name
in `backend.tf` exactly matches the `state_bucket_name` output from
Section 4, and that your AWS credentials can reach that bucket's region.

**`terraform apply` hangs or times out waiting on the EKS cluster** — this
is normal for the first 10-15 minutes; EKS control plane creation is
inherently slow. If it fails outright, check the AWS Console → EKS →
your cluster → for an explicit error.

**`kubectl` can't connect / `Unauthorized`** — re-run the exact command
from `terraform output configure_kubeconfig`; your kubeconfig context or
AWS credentials may have changed since.

**ArgoCD Application stuck `OutOfSync` or not appearing** — confirm
`gitops_repo_url` in your `terraform.tfvars` is correct and reachable
(a private repo needs credentials configured in ArgoCD, not covered
here), and that `gitops_target_revision` matches a real branch/tag.

**`terraform destroy` fails on the VPC** ("has dependencies") — something
outside Terraform's tracking (usually a LoadBalancer/ALB created via an
Ingress you added through ArgoCD) is still attached to a subnet. Delete
that Kubernetes resource first, then retry.

---

## 14. Design decisions / FAQ

**Why no DynamoDB table for state locking?**
Terraform ≥1.11 supports native S3 locking (`use_lockfile = true`),
which replaced the older bucket+DynamoDB pattern. One less resource to
manage.

**Why EKS Auto Mode instead of managed node groups or Karpenter?**
Less to operate — AWS handles node provisioning, scaling, and AMI
patching. There's intentionally no `node-groups.tf` in
`modules/eks-cluster/` because there are no manually-defined node group
resources under Auto Mode.

**Why does Terraform install ArgoCD instead of just the cluster?**
So there's a single, consistent GitOps entry point from day one, instead
of a period where add-ons get added ad hoc via `kubectl apply` before
GitOps is wired up.

**Why is the state bucket shared across all three environments?**
One bucket, three key prefixes (`eks-platform/dev/...`,
`.../staging/...`, `.../prod/...`) is simpler to bootstrap and manage
than three separate buckets, while each environment's actual state file
stays fully isolated by its unique key.