resource "aws_ecr_repository" "customer" {
  name                 = "kro2026-customer-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
