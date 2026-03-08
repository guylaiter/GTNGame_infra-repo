# FinalProject Infrastructure

Production-ready EKS cluster with ArgoCD for GitOps deployments.

## Prerequisites

- Terraform >= 1.5
- AWS CLI configured with credentials
- kubectl
- ArgoCD CLI
- GitHub CLI (gh)

## Setup

### 1. Create EKS Cluster
```bash
cd terraform
terraform init
terraform apply
```

**Note:** This creates:
- EKS cluster in ap-south-1
- VPC with public/private subnets
- NAT Gateway 
- 1 t3a.medium worker node

### 2. Configure kubectl
```bash
aws eks update-kubeconfig --region ap-south-1 --name Guy-FinalProject-Cluster
```

Verify:
```bash
kubectl get nodes
```

### 3. Install ArgoCD
```bash
./scripts/install-argocd.sh
```

### 4. Start port-forward (in separate terminal)
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

**Keep this running!**

### 5. Generate ArgoCD token
```bash
./scripts/generate-argocd-token.sh
```

### 6. Add secrets to GitHub
```bash
./scripts/add-github-secrets.sh
```

## Access ArgoCD UI

**URL:** https://localhost:8080  
**Username:** `admin`  
**Password:** Get with:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

## Teardown

**Destroy infrastructure:**
```bash
cd terraform
terraform destroy
```

**Note:** This deletes everything including ArgoCD. You'll need to reinstall ArgoCD after recreating the cluster.

## Cost Estimate

- EKS Control Plane: ~$73/month
- t3a.medium node: ~$27/month
- NAT Gateway: ~$32/month
- **Total: ~$132/month**

## Repository Structure
```
.
├── terraform/          # Infrastructure as Code
│   ├── versions.tf     # Terraform/provider versions
│   ├── variables.tf    # Input variables
│   ├── main.tf         # Provider config
│   ├── vpc.tf          # Networking
│   ├── eks.tf          # EKS cluster
│   └── outputs.tf      # Outputs
├── scripts/            # Setup scripts
│   ├── install-argocd.sh
│   ├── generate-argocd-token.sh
│   └── add-github-secrets.sh
└── README.md
```