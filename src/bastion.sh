#!/bin/bash
export HOME=/root
REGION=${region}
ECR_URI=${ecr_uri}
CLUSTER=${cluster_name}
ACK_ROLE_ARN=${ack_rds_role_arn}
ALB_ROLE_ARN=${alb_controller_role_arn}
VPC_ID=${vpc_id}
BUCKET=${artifacts_bucket}
ADMIN_PASSWORD='Skill53##'

sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd
echo "$ADMIN_PASSWORD" | passwd --stdin ec2-user

dnf install -y docker unzip tar gzip httpd-tools
systemctl enable --now docker

curl -sS "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install

curl -sS -LO "https://dl.k8s.io/release/v1.30.0/bin/linux/amd64/kubectl"
install -m 0755 kubectl /usr/local/bin/kubectl

curl -sS https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o /tmp/get-helm-3
chmod +x /tmp/get-helm-3
/tmp/get-helm-3

mkdir -p /opt/customer-app
aws s3 cp "s3://$BUCKET/main.go" /opt/customer-app/main.go
aws s3 cp "s3://$BUCKET/go.mod" /opt/customer-app/go.mod
aws s3 cp "s3://$BUCKET/go.sum" /opt/customer-app/go.sum
aws s3 cp "s3://$BUCKET/Dockerfile" /opt/customer-app/Dockerfile

mkdir -p /opt/manifests
aws s3 cp "s3://$BUCKET/namespace.yaml" /opt/manifests/namespace.yaml
aws s3 cp "s3://$BUCKET/kyverno-policies.yaml" /opt/manifests/kyverno-policies.yaml
aws s3 cp "s3://$BUCKET/argocd-application.yaml" /opt/manifests/argocd-application.yaml
aws s3 cp "s3://$BUCKET/argocd-ingress.yaml" /opt/manifests/argocd-ingress.yaml

REGISTRY=$(echo "$ECR_URI" | cut -d/ -f1)
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY"

docker build -t "$ECR_URI:v1" -t "$ECR_URI:latest" /opt/customer-app

docker push "$ECR_URI:v1"
docker push "$ECR_URI:latest"

aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION"

kubectl create namespace ack-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create serviceaccount ack-rds-controller -n ack-system --dry-run=client -o yaml | kubectl apply -f -
kubectl annotate serviceaccount ack-rds-controller -n ack-system \
  "eks.amazonaws.com/role-arn=$ACK_ROLE_ARN" --overwrite

helm repo add kyverno https://kyverno.github.io/kyverno/ >/dev/null 2>&1 || true
helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update

helm upgrade --install kro oci://ghcr.io/kro-run/kro/kro \
  --namespace kro-system --create-namespace

helm upgrade --install ack-rds-controller oci://public.ecr.aws/aws-controllers-k8s/rds-chart \
  --namespace ack-system \
  --set aws.region="$REGION" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=ack-rds-controller

helm upgrade --install kyverno kyverno/kyverno -n kyverno --create-namespace
helm upgrade --install argocd argo/argo-cd -n argocd --create-namespace

kubectl rollout status deployment/ack-rds-controller-rds-chart -n ack-system --timeout=300s || true
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s || true

kubectl create serviceaccount aws-load-balancer-controller -n kube-system --dry-run=client -o yaml | kubectl apply -f -
kubectl annotate serviceaccount aws-load-balancer-controller -n kube-system \
  "eks.amazonaws.com/role-arn=$ALB_ROLE_ARN" --overwrite

helm repo add eks https://aws.github.io/eks-charts >/dev/null 2>&1 || true
helm repo update

helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system \
  --set clusterName="$CLUSTER" \
  --set region="$REGION" \
  --set vpcId="$VPC_ID" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

kubectl rollout status deployment/aws-load-balancer-controller -n kube-system --timeout=180s || true

HASH=$(htpasswd -bnBC 10 "" "$ADMIN_PASSWORD" | tr -d ':\n')
kubectl -n argocd patch secret argocd-secret \
  -p "{\"stringData\":{\"admin.password\":\"$HASH\",\"admin.passwordMtime\":\"$(date -u +%FT%TZ)\"}}"
kubectl -n argocd delete secret argocd-initial-admin-secret --ignore-not-found

helm upgrade argocd argo/argo-cd -n argocd --reuse-values \
  --set configs.params.server\.insecure=true
kubectl rollout status deployment/argocd-server -n argocd --timeout=180s
kubectl rollout restart deployment/argocd-server -n argocd
kubectl rollout status deployment/argocd-server -n argocd --timeout=180s

kubectl apply -f /opt/manifests/namespace.yaml
kubectl apply -f /opt/manifests/kyverno-policies.yaml
kubectl apply -f /opt/manifests/argocd-ingress.yaml

kubectl apply -f /opt/manifests/argocd-application.yaml

