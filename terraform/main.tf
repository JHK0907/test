# terraform/main.tf

# 1. VPC 생성
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name_prefix}-${var.project_name}-vpc"
  }
}

# 2. Public Subnet 생성 (2개의 다른 가용 영역에)
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnets_cidr)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets_cidr[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true // Fargate Task에 Public IP를 자동 할당하기 위해 필수!

  tags = {
    Name = "${var.name_prefix}-${var.project_name}-public-subnet-${count.index + 1}"
  }
}

# 3. Internet Gateway 생성 및 VPC에 연결
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.name_prefix}-${var.project_name}-igw"
  }
}

# 4. Public Route Table 생성
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.name_prefix}-${var.project_name}-public-rt"
  }
}

# 5. Public Subnet과 Route Table 연결
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# 6. ECS Fargate Task를 위한 Security Group 생성
resource "aws_security_group" "fargate_sg" {
  name        = "${var.name_prefix}-${var.project_name}-fargate-sg"
  description = "Allow HTTP inbound traffic for Fargate tasks"
  vpc_id      = aws_vpc.main.id

  # 웹 서비스 접근을 위한 Ingress (HTTP Port 80)
  ingress {
    description      = "Allow HTTP from anywhere"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  
  # 인터넷 통신을 위한 Egress (컨테이너 이미지 pull 등)
  egress {
    description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1" # 모든 프로토콜
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-${var.project_name}-fargate-sg"
  }
}
