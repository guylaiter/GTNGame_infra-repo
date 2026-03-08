#!/bin/bash
set -e

echo "===== Installing ArgoCD ====="

kubectl create namespace argocd 2>/dev/null || echo "Namespace already exists"
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for ArgoCD pods..."
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

echo "Enabling API key capability..."
kubectl patch configmap argocd-cm -n argocd --type merge -p '{"data":{"accounts.admin":"apiKey, login"}}'

echo "Restarting ArgoCD server..."
kubectl rollout restart deployment argocd-server -n argocd
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=120s

ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)

echo ""
echo "✅ ArgoCD installed!"
echo ""
echo "Admin password: $ADMIN_PASSWORD"
echo ""
echo "Next: Run ./scripts/generate-argocd-token.sh"