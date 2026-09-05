data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_security_group" "bastion" {
  name   = "kro2026-bastion-sg"
  vpc_id = aws_vpc.this.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "kro2026-bastion-sg" }
}

resource "aws_iam_role" "bastion" {
  name = "kro2026-bastion-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "bastion_ecr" {
  name = "kro2026-bastion-ecr-push"
  role = aws_iam_role.bastion.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "EcrAuth"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "EcrPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
        ]
        Resource = aws_ecr_repository.customer.arn
      },
      {
        Sid      = "EksDescribe"
        Effect   = "Allow"
        Action   = "eks:DescribeCluster"
        Resource = aws_eks_cluster.this.arn
      },
      {
        Sid      = "ArtifactsBucketRead"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [aws_s3_bucket.artifacts.arn, "${aws_s3_bucket.artifacts.arn}/*"]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "bastion" {
  name = "kro2026-bastion-instance-profile"
  role = aws_iam_role.bastion.name
}

resource "aws_s3_bucket" "artifacts" {
  bucket_prefix = "kro2026-bastion-artifacts-"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "binary" {
  bucket     = aws_s3_bucket.artifacts.id
  key        = "customer"
  source     = "${path.module}/src/app/customer"
  etag       = filemd5("${path.module}/src/app/customer")
  depends_on = [aws_s3_bucket_server_side_encryption_configuration.artifacts]
}

resource "aws_s3_object" "dockerfile" {
  bucket     = aws_s3_bucket.artifacts.id
  key        = "Dockerfile"
  content    = file("${path.module}/src/app/Dockerfile")
  etag       = filemd5("${path.module}/src/app/Dockerfile")
  depends_on = [aws_s3_bucket_server_side_encryption_configuration.artifacts]
}

resource "aws_s3_object" "namespace_yaml" {
  bucket     = aws_s3_bucket.artifacts.id
  key        = "namespace.yaml"
  content    = file("${path.module}/manifest/namespace.yaml")
  etag       = filemd5("${path.module}/manifest/namespace.yaml")
  depends_on = [aws_s3_bucket_server_side_encryption_configuration.artifacts]
}

resource "aws_s3_object" "kyverno_yaml" {
  bucket     = aws_s3_bucket.artifacts.id
  key        = "kyverno-policies.yaml"
  content    = file("${path.module}/manifest/kyverno-policies.yaml")
  etag       = filemd5("${path.module}/manifest/kyverno-policies.yaml")
  depends_on = [aws_s3_bucket_server_side_encryption_configuration.artifacts]
}

resource "aws_s3_object" "argocd_application_yaml" {
  bucket = aws_s3_bucket.artifacts.id
  key    = "argocd-application.yaml"
  content = replace(
    file("${path.module}/manifest/argocd-application.yaml"),
    "<GIT_REPO_URL>",
    github_repository.argocd_repo.http_clone_url,
  )
  depends_on = [aws_s3_bucket_server_side_encryption_configuration.artifacts]
}

resource "aws_s3_object" "argocd_ingress_yaml" {
  bucket     = aws_s3_bucket.artifacts.id
  key        = "argocd-ingress.yaml"
  content    = file("${path.module}/manifest/argocd-ingress.yaml")
  etag       = filemd5("${path.module}/manifest/argocd-ingress.yaml")
  depends_on = [aws_s3_bucket_server_side_encryption_configuration.artifacts]
}

resource "aws_security_group_rule" "cluster_ingress_from_bastion" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  source_security_group_id = aws_security_group.bastion.id
  description              = "Bastion kubectl/helm access to EKS control plane"
}

resource "aws_eks_access_entry" "bastion" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_iam_role.bastion.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "bastion_admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_iam_role.bastion.arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.bastion]
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = "t3.small"
  subnet_id                   = aws_subnet.pub_a.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  iam_instance_profile        = aws_iam_instance_profile.bastion.name

  user_data = templatefile("${path.module}/src/bastion.sh", {
    region                  = var.region
    ecr_uri                 = aws_ecr_repository.customer.repository_url
    cluster_name            = aws_eks_cluster.this.name
    ack_rds_role_arn        = aws_iam_role.ack_rds.arn
    alb_controller_role_arn = aws_iam_role.alb_controller.arn
    vpc_id                  = aws_vpc.this.id
    artifacts_bucket        = aws_s3_bucket.artifacts.bucket
  })

  tags = { Name = "kro2026-bastion-ec2" }

  depends_on = [
    aws_eks_cluster.this,
    aws_eks_node_group.app,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.kube_proxy,
    aws_eks_addon.coredns,
    aws_eks_access_policy_association.bastion_admin,
    aws_security_group_rule.cluster_ingress_from_bastion,
    aws_ecr_repository.customer,
    aws_route_table_association.pub_a,
    aws_route_table_association.app_a,
    aws_route_table_association.app_c,
    aws_nat_gateway.a,
    aws_nat_gateway.c,
    aws_vpc_endpoint.interface,
    aws_s3_object.binary,
    aws_s3_object.dockerfile,
    aws_s3_object.namespace_yaml,
    aws_s3_object.kyverno_yaml,
    aws_s3_object.argocd_application_yaml,
    aws_s3_object.argocd_ingress_yaml,
    aws_iam_role_policy.alb_controller,
    github_repository_file.app_rgd,
    github_repository_file.app_webapp_sample,
  ]
}
