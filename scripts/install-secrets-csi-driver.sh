#!/bin/bash
set -e

# ============================================
# Configuration Variables
# ============================================
NAMESPACE="kube-system"

# ============================================
# AWS Secrets Store CSI Driver Installation
# ============================================

echo "===== Installing AWS Secrets Store CSI Driver ====="
echo ""

# Prerequisites check
echo "Checking prerequisites..."
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo "❌ helm not found. Please install helm first."
    echo "   curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
    exit 1
fi

# Check kubectl connection
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster. Please configure kubectl first."
    exit 1
fi

echo "✅ Prerequisites OK"
echo ""

# Step 1: Add Helm repository
echo "Step 1/4: Adding Secrets Store CSI Driver Helm repository..."
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm repo update
echo "✅ Helm repository added"
echo ""

# Step 2: Install Secrets Store CSI Driver
echo "Step 2/4: Installing Secrets Store CSI Driver..."
helm install csi-secrets-store \
  secrets-store-csi-driver/secrets-store-csi-driver \
  --namespace $NAMESPACE \
  --set syncSecret.enabled=true \
  --set enableSecretRotation=true

echo "Waiting for CSI driver pods to be ready..."
kubectl wait --for=condition=Ready pods -l app=secrets-store-csi-driver -n $NAMESPACE --timeout=120s
echo "✅ Secrets Store CSI Driver installed"
echo ""

# Step 3: Install AWS Provider
echo "Step 3/4: Installing AWS Secrets Manager Provider..."
kubectl apply -f https://raw.githubusercontent.com/aws/secrets-store-csi-driver-provider-aws/main/deployment/aws-provider-installer.yaml

echo "Waiting for AWS provider pods to be ready..."
sleep 5
kubectl wait --for=condition=Ready pods -l app=csi-secrets-store-provider-aws -n $NAMESPACE --timeout=120s 2>/dev/null || echo "Provider pods starting..."
echo "✅ AWS Provider installed"
echo ""

# Step 4: Verify Installation
echo "Step 4/4: Verifying installation..."
echo ""
echo "CSI Driver Pods:"
kubectl get pods -n $NAMESPACE | grep -E "csi-secrets-store|secrets-store" || echo "No pods found"
echo ""

# Check DaemonSets
echo "DaemonSets:"
kubectl get daemonset -n $NAMESPACE | grep -E "csi-secrets-store|secrets-store" || echo "No daemonsets found"
echo ""

echo "===== Installation Complete! ====="
echo ""
echo "Installed Components:"
echo "  ✅ Secrets Store CSI Driver"
echo "  ✅ AWS Secrets Manager Provider"
echo ""
echo "Next Steps:"
echo "  1. Ensure EKS nodes have IAM permissions for Secrets Manager (via Terraform)"
echo "  2. Create SecretProviderClass in your Helm chart"
echo "  3. Mount secrets in your deployments"
echo ""
echo "Verify installation:"
echo "  kubectl get pods -n kube-system | grep csi"
