#!/bin/bash
set -e

# ============================================
# Configuration Variables
# ============================================
GITHUB_REPO="guylaiter/FinalProject_app-repo"
ARGOCD_NAMESPACE="argocd"
ARGOCD_PORT="8080"
TOKEN_EXPIRY="365d"
PORT_FORWARD_TIMEOUT=10  

# ============================================
# ArgoCD Complete Setup Script
# ============================================

echo "===== Complete ArgoCD Setup ====="
echo ""

# Prerequisites check
echo "Checking prerequisites..."
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

if ! command -v argocd &> /dev/null; then
    echo "❌ argocd CLI not found. Please install it first:"
    echo "   curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
    echo "   sudo install -m 555 argocd /usr/local/bin/argocd"
    exit 1
fi

# Check kubectl connection
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster. Please configure kubectl first."
    exit 1
fi

echo "✅ Prerequisites OK"
echo ""

# Step 1: Install ArgoCD
echo "Step 1/5: Installing ArgoCD..."
kubectl create namespace $ARGOCD_NAMESPACE 2>/dev/null || echo "Namespace already exists"

# Apply ArgoCD manifests (ignore annotation warning - it's non-critical)
kubectl apply -n $ARGOCD_NAMESPACE -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml 2>&1 | grep -v "Too long: must have at most" || true

echo "Waiting for ArgoCD pods to be ready (this may take 2-3 minutes)..."
kubectl wait --for=condition=Ready pods --all -n $ARGOCD_NAMESPACE --timeout=300s
echo "✅ ArgoCD installed"

# Step 2: Enable API key
echo ""
echo "Step 2/5: Enabling API key capability..."
kubectl patch configmap argocd-cm -n $ARGOCD_NAMESPACE --type merge -p '{"data":{"accounts.admin":"apiKey, login"}}'

echo "Restarting ArgoCD server..."
kubectl rollout restart deployment argocd-server -n $ARGOCD_NAMESPACE
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-server -n $ARGOCD_NAMESPACE --timeout=120s
echo "✅ API key enabled"

# Step 3: Start port-forward
echo ""
echo "Step 3/5: Starting port-forward..."

# Kill any existing port-forward on the specified port
if lsof -ti:$ARGOCD_PORT &> /dev/null; then
    echo "Killing existing process on port $ARGOCD_PORT..."
    lsof -ti:$ARGOCD_PORT | xargs kill -9 2>/dev/null || true
    sleep 1
fi

# Start port-forward in background
kubectl port-forward svc/argocd-server -n $ARGOCD_NAMESPACE $ARGOCD_PORT:443 > /dev/null 2>&1 &
PORT_FORWARD_PID=$!
echo "Port-forward started (PID: $PORT_FORWARD_PID)"

# Health check with timeout
echo "Waiting for port-forward to be ready (timeout: ${PORT_FORWARD_TIMEOUT}s)..."
ELAPSED=0
while [ $ELAPSED -lt $PORT_FORWARD_TIMEOUT ]; do
    if nc -z localhost $ARGOCD_PORT 2>/dev/null; then
        echo "✅ Port-forward ready"
        break
    fi
    sleep 1
    ELAPSED=$((ELAPSED + 1))
done

# Check if port-forward is actually ready
if ! nc -z localhost $ARGOCD_PORT 2>/dev/null; then
    echo "❌ Port-forward failed to start within ${PORT_FORWARD_TIMEOUT} seconds"
    kill $PORT_FORWARD_PID 2>/dev/null || true
    exit 1
fi

# Step 4: Generate token
echo ""
echo "Step 4/5: Generating ArgoCD token..."
ADMIN_PASSWORD=$(kubectl -n $ARGOCD_NAMESPACE get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)

if [ -z "$ADMIN_PASSWORD" ]; then
    echo "❌ Failed to retrieve admin password"
    kill $PORT_FORWARD_PID 2>/dev/null || true
    exit 1
fi

echo "Logging in to ArgoCD..."
if ! argocd login localhost:$ARGOCD_PORT --username admin --password "$ADMIN_PASSWORD" --insecure; then
    echo "❌ Failed to login to ArgoCD"
    kill $PORT_FORWARD_PID 2>/dev/null || true
    exit 1
fi

echo "Generating API token (expires in $TOKEN_EXPIRY)..."
TOKEN=$(argocd account generate-token --account admin --expires-in $TOKEN_EXPIRY)

if [ -z "$TOKEN" ]; then
    echo "❌ Failed to generate token"
    kill $PORT_FORWARD_PID 2>/dev/null || true
    exit 1
fi

echo "✅ Token generated"

# Step 5: Add to GitHub
echo ""
echo "Step 5/5: Adding secrets to GitHub..."

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "⚠️  GitHub CLI (gh) not installed - skipping GitHub secrets"
    echo ""
    echo "To add secrets manually:"
    echo "1. Install GitHub CLI: sudo apt install gh"
    echo "2. Run: gh auth login"
    echo "3. Add secrets:"
    echo "   echo '$TOKEN' | gh secret set ARGOCD_TOKEN -R $GITHUB_REPO"
    echo "   gh secret set ARGOCD_SERVER -b 'localhost:$ARGOCD_PORT' -R $GITHUB_REPO"
    echo ""
else
    # Check if logged in
    if ! gh auth status &> /dev/null; then
        echo "Please login to GitHub CLI:"
        gh auth login
    fi
    
    echo "Adding secrets to $GITHUB_REPO..."
    echo "$TOKEN" | gh secret set ARGOCD_TOKEN -R $GITHUB_REPO
    gh secret set ARGOCD_SERVER -b "localhost:$ARGOCD_PORT" -R $GITHUB_REPO
    
    echo "✅ Secrets added to GitHub!"
fi

echo ""
echo "===== Setup Complete! ====="
echo ""
echo "ArgoCD Details:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  URL:      https://localhost:$ARGOCD_PORT"
echo "  Username: admin"
echo "  Password: $ADMIN_PASSWORD"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "GitHub Secrets ($GITHUB_REPO):"
echo "  ✅ ARGOCD_TOKEN"
echo "  ✅ ARGOCD_SERVER"
echo ""
echo "⚠️  Port-forward is running in background (PID: $PORT_FORWARD_PID)"
echo "   To stop: kill $PORT_FORWARD_PID"
echo "   To restart: kubectl port-forward svc/argocd-server -n $ARGOCD_NAMESPACE $ARGOCD_PORT:443"
echo ""
echo "Next Steps:"
echo "  → Create Helm charts in cluster-repo"
echo "  → Configure ArgoCD application"
echo "  → Access UI at https://localhost:$ARGOCD_PORT"