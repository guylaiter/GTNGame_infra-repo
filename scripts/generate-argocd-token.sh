#!/bin/bash
set -e

echo "===== Generating ArgoCD Token ====="
echo ""
echo "Make sure port-forward is running in another terminal:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
read -p "Press Enter when port-forward is ready..."

ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)

echo "Logging in to ArgoCD..."
argocd login localhost:8080 --username admin --password "$ADMIN_PASSWORD" --insecure

echo "Generating token..."
TOKEN=$(argocd account generate-token --account admin --expires-in 365d)

echo ""
echo "✅ Token generated!"
echo ""
echo "Token: $TOKEN"
echo ""
echo "Next: Run ./scripts/add-github-secrets.sh"