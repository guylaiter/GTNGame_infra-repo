# FinalProject Infrastructure

Production-ready EKS cluster with ArgoCD for GitOps deployments.

## Prerequisites

- Terraform >= 1.5
- kubectl
- ArgoCD CLI
- GitHub CLI (gh) - optional, for automatic GitHub secrets
- AWS CLI configured with credentials
- netcat (nc) - for port-forward health checks

## Quick Setup

### 1. Create EKS Cluster
```bash
cd terraform
terraform init
terraform apply
```

**Note:** This creates:
- EKS cluster in ap-south-1 (Mumbai)
- VPC with public/private subnets
- NAT Gateway 
- 1 t3a.medium worker node

**Time:** ~10-15 minutes

### 2. Configure kubectl
```bash
aws eks update-kubeconfig --region ap-south-1 --name Guy-FinalProject-Cluster
```

Verify cluster connection:
```bash
kubectl get nodes
```
**Expected:** 1 node in `Ready` status

### 3. Install and Configure ArgoCD (All-in-One)
```bash
cd ../scripts
chmod +x setup-argocd-complete.sh
./setup-argocd-complete.sh
```

**This single script will:**
- ✅ Install ArgoCD
- ✅ Enable API key capability
- ✅ Start port-forward in background
- ✅ Generate ArgoCD token
- ✅ Add secrets to GitHub (ARGOCD_TOKEN, ARGOCD_SERVER)

**Time:** ~3-5 minutes

## Access ArgoCD UI

**URL:** https://localhost:8080  
**Username:** `admin`  
**Password:** Shown at end of setup script, or get with:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

**Note:** Port-forward runs in background. To restart:
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

## Verify Setup

Check ArgoCD pods are running:
```bash
kubectl get pods -n argocd
```

Check GitHub secrets were added:
```bash
gh secret list -R guylaiter/FinalProject_app-repo
```
**Expected:** ARGOCD_TOKEN, ARGOCD_SERVER

## Teardown

**Destroy infrastructure:**
```bash
cd terraform
terraform destroy
```

**Note:** This deletes everything including ArgoCD. You'll need to re-run the setup script after recreating the cluster.

## Cost Estimate

- EKS Control Plane: ~$73/month
- t3a.medium node: ~$27/month
- NAT Gateway: ~$32/month
- **Total: ~$132/month**

## Troubleshooting

### Port-forward not working
```bash
# Kill existing port-forward
lsof -ti:8080 | xargs kill -9

# Restart
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### ArgoCD pods not ready
```bash
# Check pod status
kubectl get pods -n argocd

# Check specific pod logs
kubectl logs -n argocd <pod-name>
```

### Can't connect to cluster
```bash
# Reconfigure kubectl
aws eks update-kubeconfig --region ap-south-1 --name Guy-FinalProject-Cluster

# Test connection
kubectl cluster-info
```

## Repository Structure
```
.
├── terraform/                    # Infrastructure as Code
│   ├── versions.tf               # Terraform/provider versions
│   ├── variables.tf              # Input variables
│   ├── main.tf                   # Provider config
│   ├── vpc.tf                    # VPC and networking
│   ├── eks.tf                    # EKS cluster and node group
│   └── outputs.tf                # Outputs (cluster name, region, etc.)
├── scripts/                      # Setup scripts
│   └── setup-argocd-complete.sh  # All-in-one ArgoCD setup
└── README.md                     # This file
```

## Next Steps

After infrastructure is ready:
1. Create Helm charts in `FinalProject_cluster-repo`
2. Configure ArgoCD Application
3. Set up CI/CD pipeline to auto-deploy
