resource "aws_kms_key" "eks" {
  description             = "kro2026-eks-secrets"
  deletion_window_in_days = 7
}

resource "aws_kms_alias" "eks" {
  name          = "alias/kro2026-eks-secrets"
  target_key_id = aws_kms_key.eks.key_id
}
