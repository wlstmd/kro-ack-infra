provider "aws" {
  region = var.region
}

provider "github" {
  token = var.github_secret_token
  owner = var.github_owner != "" ? var.github_owner : null
}

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 6.0" }
    tls    = { source = "hashicorp/tls", version = "~> 4.0" }
    github = { source = "integrations/github", version = "~> 6.0" }
  }
}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

variable "github_secret_token" {
  type      = string
  sensitive = true
  default   = "" # Change to your Github Personal Access Token
}

variable "github_owner" {
  type    = string
  default = "" # Change to your Github Name
}

variable "git_repo_name" {
  type    = string
  default = "kro2026-repo"
}

variable "git_repo_visibility" {
  type    = string
  default = "public"
}

variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "az_a" {
  type    = string
  default = "ap-northeast-2a"
}

variable "az_c" {
  type    = string
  default = "ap-northeast-2c"
}

variable "cluster_version" {
  type    = string
  default = "1.35"
}
