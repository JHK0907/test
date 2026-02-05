# terraform/iam.tf

# 현재 AWS 계정 정보를 가져옵니다. (IAM Role ARN 생성에 필요)
data "aws_caller_identity" "current" {}

# GitHub Actions OIDC Provider 생성
# 이 Provider는 GitHub가 AWS에 대한 인증을 요청할 때 AWS가 GitHub를 신뢰하도록 설정합니다.
# AWS 계정당 한 번만 생성하면 됩니다.
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # GitHub Actions OIDC Provider의 현재 썸프린트입니다.
  # AWS 공식 문서를 통해 최신 값을 확인하여 업데이트할 수 있습니다.
  thumbprint_list = ["6938fd48ead637b5ddf9e0481287042340443974"] 

  tags = {
    Name = "${var.name_prefix}-${var.project_name}-github-oidc-provider"
  }
}

# GitHub Actions가 Assume Role할 IAM Role 생성
resource "aws_iam_role" "github_actions_deployer" {
  name = "${var.name_prefix}-${var.project_name}-github-actions-deployer"

  # 이 Role을 누가 Assume할 수 있는지 정의하는 Trust Policy (신뢰 정책)
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
        },
        Action    = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringLike = {
            # !!!!!!!! 중요 !!!!!!!!
            # "YOUR_GITHUB_ORG/YOUR_REPO_NAME" 부분을 실제 GitHub 조직/계정 이름과 리포지토리 이름으로 변경해야 합니다.
            # 예: "my-github-org/tetris-on-fargate"
            "token.actions.githubusercontent.com:sub": "repo:${var.github_repo_owner}/${var.github_repo_name}:ref:refs/heads/main"
          },
          StringEquals = {
            "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = {
    Name = "${var.name_prefix}-${var.project_name}-github-actions-deployer"
  }
}

# GitHub Actions Role에 연결할 권한 정책 정의
# ECR 이미지 푸시, ECS 서비스 업데이트, CloudWatch 로그 기록 권한 포함
resource "aws_iam_role_policy" "github_actions_policy" {
  name = "${var.name_prefix}-${var.project_name}-github-actions-policy"
  role = aws_iam_role.github_actions_deployer.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetAuthorizationToken"
        ],
        Resource = "*" # ECR 로그인 토큰 발급은 계정 전체 권한이 필요
      },
      {
        Effect = "Allow",
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages"
        ],
        Resource = aws_ecr_repository.web_app.arn # 나머지 ECR 작업은 특정 리포지토리 권한
      },
      {
        Effect = "Allow",
        Action = [
          "ecs:RegisterTaskDefinition",
          "ecs:DeregisterTaskDefinition",
          "ecs:DescribeTaskDefinition",
          "ecs:ListTaskDefinitions"
        ],
        Resource = "*" # 태스크 정의 관련 액션은 "*"으로 설정
      },
      # ECS Service / Cluster 관련 액션
      {
        Effect = "Allow",
        Action = [
          "ecs:DescribeServices",
          "ecs:UpdateService",
          "ecs:DescribeClusters"
        ],
        Resource = [
          aws_ecs_cluster.main.arn,
          "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/${aws_ecs_cluster.main.name}/${aws_ecs_service.web_app.name}"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${var.project_name}-web-app:*"
      },
      # PassRole is required to pass the task execution role to the ECS task..
      {
        "Effect": "Allow",
        "Action": [
            "iam:PassRole"
        ],
        "Resource": [
            aws_iam_role.ecs_task_execution_role.arn
        ]
      }
    ]
  })
}
