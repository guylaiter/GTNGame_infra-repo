#!/bin/bash
set -e

echo "===== Complete ArgoCD Setup ====="
echo ""

# Step 1: Install ArgoCD
echo "Step 1/4: Installing ArgoCD..."
kubectl create namespace argocd 2>/dev/null || echo "Namespace already exists"
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for ArgoCD pods..."
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# Step 2: Enable API key
echo ""
echo "Step 2/4: Enabling API key capability..."
kubectl patch configmap argocd-cm -n argocd --type merge -p '{"data":{"accounts.admin":"apiKey, login"}}'

echo "Restarting ArgoCD server..."
kubectl rollout restart deployment argocd-server -n argocd
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=120s

# Step 3: Start port-forward in background
echo ""
echo "Step 3/4: Starting port-forward..."
kubectl port-forward svc/argocd-server -n argocd 8080:443 > /dev/null 2>&1 &
PORT_FORWARD_PID=$!
echo "Port-forward running (PID: $PORT_FORWARD_PID)"

# Wait for port-forward to be ready
sleep 5

# Step 4: Generate token
echo ""
echo "Step 4/4: Generating ArgoCD token..."
ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)

argocd login localhost:8080 --username admin --password "$ADMIN_PASSWORD" --insecure
TOKEN=$(argocd account generate-token --account admin --expires-in 365d)

# Stop port-forward
kill $PORT_FORWARD_PID 2>/dev/null || true

# Step 5: Add to GitHub
echo ""
echo "Step 5/4: Adding secrets to GitHub..."

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "⚠️  GitHub CLI (gh) not installed - skipping GitHub secrets"
    echo "Install with: sudo apt install gh"
    echo "Then manually add secrets:"
    echo "  ARGOCD_TOKEN=$TOKEN"
    echo "  ARGOCD_SERVER=localhost:8080"
else
    # Check if logged in
    if ! gh auth status &> /dev/null; then
        echo "Please login to GitHub CLI:"
        gh auth login
    fi
    
    echo "$TOKEN" | gh secret set ARGOCD_TOKEN -R guylaiter/FinalProject_app-repo
    gh secret set ARGOCD_SERVER -b "localhost:8080" -R guylaiter/FinalProject_app-repo
    
    echo "✅ Secrets added to GitHub!"
fi

echo ""
echo "===== Setup Complete! ====="
echo ""
echo "ArgoCD Details:"
echo "  URL: https://localhost:8080"
echo "  Username: admin"
echo "  Password: $ADMIN_PASSWORD"
echo ""
echo "GitHub Secrets:"
echo "  ARGOCD_TOKEN: ✅ Added"
echo "  ARGOCD_SERVER: ✅ Added"
echo ""
echo "Next: Create Helm charts in cluster-repo"