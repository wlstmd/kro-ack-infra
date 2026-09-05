resource "github_repository" "argocd_repo" {
  name        = var.git_repo_name
  description = "kro2026 WebApp self-service platform (kro + ACK + ArgoCD)"
  visibility  = var.git_repo_visibility

  auto_init = true
}

resource "github_repository_file" "namespace" {
  repository          = github_repository.argocd_repo.name
  branch              = "main"
  file                = "manifest/namespace.yaml"
  content             = file("${path.module}/manifest/namespace.yaml")
  commit_message      = "chore: add platform namespace"
  overwrite_on_create = true
}

resource "github_repository_file" "kyverno" {
  repository          = github_repository.argocd_repo.name
  branch              = "main"
  file                = "manifest/kyverno-policies.yaml"
  content             = file("${path.module}/manifest/kyverno-policies.yaml")
  commit_message      = "chore: add kyverno policies"
  overwrite_on_create = true
}

resource "github_repository_file" "app_rgd" {
  repository          = github_repository.argocd_repo.name
  branch              = "main"
  file                = "manifest/rgd.yaml"
  content             = file("${path.module}/manifest/rgd.yaml")
  commit_message      = "chore: add WebApp ResourceGraphDefinition"
  overwrite_on_create = true
}

resource "github_repository_file" "app_webapp_sample" {
  repository     = github_repository.argocd_repo.name
  branch         = "main"
  file           = "manifest/webapp-sample.yaml"
  commit_message = "chore: deploy hello-app"
  content = replace(
    file("${path.module}/manifest/webapp-sample.yaml"),
    "<ECR_URI>",
    aws_ecr_repository.customer.repository_url,
  )
  overwrite_on_create = true
}

resource "github_repository_file" "argocd_application" {
  repository     = github_repository.argocd_repo.name
  branch         = "main"
  file           = "manifest/argocd-application.yaml"
  commit_message = "chore: register ArgoCD application"
  content = replace(
    file("${path.module}/manifest/argocd-application.yaml"),
    "<GIT_REPO_URL>",
    github_repository.argocd_repo.http_clone_url,
  )
  overwrite_on_create = true
}