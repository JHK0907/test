# terraform/ecs.tf

# 1. ECS 클러스터 생성
resource "aws_ecs_cluster" "main" {
  name = "${var.name_prefix}-${var.project_name}-cluster"

  tags = {
    Name = "${var.name_prefix}-${var.project_name}-cluster"
  }
}

# 2. Fargate Task 실행을 위한 IAM Role 생성
#    Task가 ECR에서 이미지를 PULL하고 CloudWatch에 로그를 보낼 수 있는 권한.
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.name_prefix}-${var.project_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.name_prefix}-${var.project_name}-ecs-task-execution-role"
  }
}

# 생성한 Role에 AWS 관리형 정책 연결
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 3. ECS Task Definition 정의
#    - 어떤 Docker 이미지를 사용할지, CPU/Memory, 포트 매핑 등을 정의합니다.
#    - image는 나중에 GitHub Actions에서 빌드하고 ECR에 푸시한 이미지 주소로 변경될 예정입니다.
#      (지금은 임시로 public 예제 이미지를 사용)
resource "aws_ecs_task_definition" "web_app" {
  family                   = "${var.name_prefix}-${var.project_name}-web-app"
  network_mode             = "awsvpc" # Fargate는 awsvpc 모드만 지원
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"  # 0.25 vCPU (최소 단위)
  memory                   = "512"  # 0.5 GB (최소 단위)
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  
  # 실제 컨테이너 정의
  container_definitions = jsonencode([
    {
      name      = "${var.name_prefix}-${var.project_name}-container"
      image     = "nginxdemos/hello:latest" # 나중에 우리 테트리스 앱 이미지로 교체
      cpu       = 512
      memory    = 1024
      essential = true
      readonlyRootFilesystem = false
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.web_app.name,
          "awslogs-region"        = var.aws_region,
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = {
    Name = "${var.name_prefix}-${var.project_name}-web-app-td"
  }
}

# 4. ECS Service를 위한 CloudWatch Log Group 생성
resource "aws_cloudwatch_log_group" "web_app" {
  name = "/ecs/${var.name_prefix}-${var.project_name}-web-app"
  retention_in_days = 365

  tags = {
    Name = "${var.name_prefix}-${var.project_name}-log-group"
  }
}


# 5. ECS Service 생성
#    - Task Definition을 기반으로 실제 컨테이너(Task)를 몇 개 실행하고 어떻게 관리할지 정의합니다.
resource "aws_ecs_service" "web_app" {
  name            = "${var.name_prefix}-${var.project_name}-web-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.web_app.arn
  desired_count   = 1 # 우선 1개의 Task만 실행

  # 비용 절감을 위해 Fargate Spot 사용
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
  }

  network_configuration {
    subnets          = aws_subnet.public[*].id # Public Subnet에 배포
    security_groups  = [aws_security_group.fargate_sg.id]
    assign_public_ip = true # Public IP 할당 활성화 (매우 중요!)
  }
  
  # 서비스가 배포 또는 업데이트될 때 ALB 없이 바로 롤링 업데이트를 수행하기 위함
  # (이 설정이 없으면 Terraform apply 시 에러 발생 가능)
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

  tags = {
    Name = "${var.name_prefix}-${var.project_name}-web-service"
  }
}

# 6. Docker 이미지를 저장할 ECR(Elastic Container Registry) 생성
resource "aws_ecr_repository" "web_app" {
  name                 = "${var.name_prefix}-${var.project_name}-repo"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.name_prefix}-${var.project_name}-repo"
  }
}
