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

resource "github_repository_file" "app_main_go" {
  repository          = github_repository.argocd_repo.name
  branch              = "main"
  file                = "src/app/main.go"
  content             = file("${path.module}/src/app/main.go")
  commit_message      = "chore: add customer app source"
  overwrite_on_create = true
}

resource "github_repository_file" "app_go_mod" {
  repository          = github_repository.argocd_repo.name
  branch              = "main"
  file                = "src/app/go.mod"
  content             = file("${path.module}/src/app/go.mod")
  commit_message      = "chore: add go.mod"
  overwrite_on_create = true
}

resource "github_repository_file" "app_go_sum" {
  repository          = github_repository.argocd_repo.name
  branch              = "main"
  file                = "src/app/go.sum"
  content             = file("${path.module}/src/app/go.sum")
  commit_message      = "chore: add go.sum"
  overwrite_on_create = true
}

resource "github_repository_file" "app_dockerfile" {
  repository          = github_repository.argocd_repo.name
  branch              = "main"
  file                = "src/app/Dockerfile"
  content             = file("${path.module}/src/app/Dockerfile")
  commit_message      = "chore: add multi-stage Dockerfile"
  overwrite_on_create = true
}

resource "github_repository_file" "ci_workflow" {
  repository     = github_repository.argocd_repo.name
  branch         = "main"
  file           = ".github/workflows/ci.yml"
  commit_message = "chore: add CI workflow"
  content = replace(
    replace(
      replace(
        file("${path.module}/.github/workflows/ci.yml"),
        "<CI_ROLE_ARN>",
        aws_iam_role.github_actions_ci.arn,
      ),
      "<AWS_REGION>",
      var.region,
    ),
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