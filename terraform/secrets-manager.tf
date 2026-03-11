
# IAM Policy for Secrets Manager access
resource "aws_iam_policy" "secrets_manager_policy" {
  name        = "${var.cluster_name}-secrets-manager-policy"
  description = "Allow EKS nodes to read secrets from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:ap-south-1:900631658007:secret:guess-the-number/database-K2f9xq"
      }
    ]
  })
}

# Attach policy to EKS node role
resource "aws_iam_role_policy_attachment" "secrets_manager_attachment" {
  policy_arn = aws_iam_policy.secrets_manager_policy.arn
  role       = aws_iam_role.eks_nodes.name
}
