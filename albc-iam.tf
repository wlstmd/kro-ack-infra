resource "aws_iam_role" "alb_controller" {
  name = "kro2026-alb-controller-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.this.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_sub}:aud" = "sts.amazonaws.com"
          "${local.oidc_sub}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "alb_controller" {
  name = "kro2026-alb-controller-policy"
  role = aws_iam_role.alb_controller.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Ec2Elb"
        Effect = "Allow"
        Action = [
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcPeeringConnections",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeTags",
          "ec2:GetCoipPoolUsage",
          "ec2:DescribeCoipPools",
          "ec2:CreateSecurityGroup",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:DeleteSecurityGroup",
          "elasticloadbalancing:*",
        ]
        Resource = "*"
      },
      {
        Sid      = "AcmCertDiscovery"
        Effect   = "Allow"
        Action   = ["acm:DescribeCertificate", "acm:ListCertificates", "acm:GetCertificate"]
        Resource = "*"
      },
      {
        Sid      = "WafShield"
        Effect   = "Allow"
        Action   = ["waf-regional:*", "wafv2:*", "shield:DescribeProtection", "shield:GetSubscriptionState", "shield:CreateProtection", "shield:DeleteProtection"]
        Resource = "*"
      },
      {
        Sid      = "TagDiscovery"
        Effect   = "Allow"
        Action   = ["tag:GetResources", "tag:TagResources", "tag:UntagResources"]
        Resource = "*"
      },
      {
        Sid      = "IamServiceLinkedRole"
        Effect   = "Allow"
        Action   = "iam:CreateServiceLinkedRole"
        Resource = "*"
        Condition = {
          StringEquals = { "iam:AWSServiceName" = "elasticloadbalancing.amazonaws.com" }
        }
      },
      {
        Sid      = "CognitoDiscovery"
        Effect   = "Allow"
        Action   = "cognito-idp:DescribeUserPoolClient"
        Resource = "*"
      }
    ]
  })
}
