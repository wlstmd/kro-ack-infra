resource "aws_iam_role" "ack_rds" {
  name = "kro2026-ack-rds-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.this.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_sub}:aud" = "sts.amazonaws.com"
          "${local.oidc_sub}:sub" = "system:serviceaccount:ack-system:ack-rds-controller"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "ack_rds" {
  name = "kro2026-ack-rds-policy"
  role = aws_iam_role.ack_rds.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DBInstanceLifecycle"
        Effect = "Allow"
        Action = [
          "rds:CreateDBInstance",
          "rds:DeleteDBInstance",
          "rds:ModifyDBInstance",
          "rds:RebootDBInstance",
          "rds:DescribeDBInstances",
        ]
        Resource = "*"
      },
      {
        Sid    = "DBInstanceReadOnly"
        Effect = "Allow"
        Action = [
          "rds:DescribeDBSubnetGroups",
          "rds:DescribeDBEngineVersions",
          "rds:DescribeOrderableDBInstanceOptions",
          "rds:DescribeEvents",
          "rds:ListTagsForResource",
          "rds:AddTagsToResource",
          "rds:RemoveTagsFromResource",
        ]
        Resource = "*"
      },
      {
        Sid    = "NetworkLookup"
        Effect = "Allow"
        Action = [
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeAvailabilityZones",
        ]
        Resource = "*"
      },
      {
        Sid      = "RdsServiceLinkedRole"
        Effect   = "Allow"
        Action   = "iam:CreateServiceLinkedRole"
        Resource = "*"
        Condition = {
          StringEquals = { "iam:AWSServiceName" = "rds.amazonaws.com" }
        }
      }
    ]
  })
}
