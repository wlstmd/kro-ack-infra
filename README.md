# kro2026-mission

kro(Kubernetes Resource Orchestrator) + ACK(AWS Controllers for Kubernetes)를 이용해, 개발자가 `WebApp` 커스텀 리소스 하나만 apply하면 Deployment, Service 등이 함께 프로비저닝되는 셀프서비스 배포 플랫폼입니다. Terraform으로 전체 인프라(VPC, EKS, RDS 연동, GitOps 파이프라인)를 한 번에 구성합니다.

## 구성 요소

- **Network**: VPC(`10.20.0.0/16`), Public/Private(App)/Private(DB) Subnet 각 2개 AZ, NAT Gateway 2개, ECR/S3 VPC Endpoint, VPC Flow Log
- **EKS**: `kro2026-eks-cluster`, Managed Node Group(Private Subnet, t3.medium, 2~4대), Control Plane 로그 전체 활성화, Secret KMS 암호화
- **Bastion EC2**: Public Subnet A, SSH 접속(`ec2-user` / `Skill53##`), 이미지 빌드·Helm 설치 등 초기 부트스트랩 전용 호스트
- **kro / ACK**: `kro-system`에 kro, `ack-system`에 ACK RDS Controller(RDS 생성/삭제 최소 권한 IRSA)
- **WebApp API**: `kro2026-webapp-rgd` (ResourceGraphDefinition) — WebApp 인스턴스 하나로 Deployment, Service 등 생성
- **Kyverno**: `:latest` 이미지 태그 Pod 차단, `app.kubernetes.io/managed-by: kro` 라벨 없는 Pod 차단
- **GitOps**: Terraform이 GitHub 저장소를 생성하고 매니페스트를 커밋 → Argo CD(`kro2026-webapp-app`)가 해당 저장소를 동기화

## 사전 준비

- Terraform >= 1.5, AWS CLI 자격증명(관리자 권한)
- GitHub Personal Access Token (repo 생성 권한)

## 배포

```bash
terraform init
terraform apply
```

## 주요 변수 (`provider.tf`)

| 변수                  | 설명                                | 기본값           |
| --------------------- | ----------------------------------- | ---------------- |
| `github_secret_token` | GitHub PAT (필수, 반드시 직접 설정) | `""`             |
| `github_owner`        | GitHub 계정/조직명 (필수)           | `""`             |
| `git_repo_name`       | 생성할 GitOps 저장소 이름           | `kro2026-repo`   |
| `region`              | 배포 리전                           | `ap-northeast-2` |

## 접속

- **Bastion**: `ssh ec2-user@<bastion public IP>` (비밀번호 `Skill53##`), IP는 `aws ec2 describe-instances` 또는 콘솔에서 확인
- **kubectl**: Bastion에 접속 후 이미 `aws eks update-kubeconfig` 완료 상태
- **Argo CD**: `kubectl get ingress -n argocd` 또는 `argocd-ingress.yaml`로 노출된 ALB 주소, 계정 `admin` / `Skill53##`
- **WebApp 배포 확인**: `kubectl get webapp -n kro2026 -o jsonpath='{.items[*].status}'`

## 정리

```bash
terraform destroy
```
