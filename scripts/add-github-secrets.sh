#!/bin/bash
set -e

echo "===== Adding Secrets to GitHub ====="
echo ""

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) not installed"
    echo "Install: sudo apt install gh"
    exit 1
fi

# Check if logged in
if ! gh auth status &> /dev/null; then
    echo "Logging in to GitHub..."
    gh auth login
fi

echo "Paste the ArgoCD token:"
gh secret set ARGOCD_TOKEN -R guylaiter/FinalProject_app-repo

gh secret set ARGOCD_SERVER -b "localhost:8080" -R guylaiter/FinalProject_app-repo

echo ""
echo "✅ Secrets added to GitHub!"
echo ""
echo "Setup complete! Ready to create Helm charts."