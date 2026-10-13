terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# =========================================================
# VPC
# =========================================================

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# =========================================================
# INTERNET GATEWAY
# =========================================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# =========================================================
# PUBLIC SUBNET 1
# =========================================================

resource "aws_subnet" "public_1" {
  vpc_id = aws_vpc.main.id

  cidr_block = "10.0.1.0/24"

  availability_zone = "us-east-1a"

  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-1"
  }
}

# =========================================================
# PUBLIC SUBNET 2
# =========================================================

resource "aws_subnet" "public_2" {
  vpc_id = aws_vpc.main.id

  cidr_block = "10.0.2.0/24"

  availability_zone = "us-east-1b"

  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-2"
  }
}

# =========================================================
# PUBLIC ROUTE TABLE
# =========================================================

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"

    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-route-table"
  }
}

# =========================================================
# ROUTE TABLE ASSOCIATION - SUBNET 1
# =========================================================

resource "aws_route_table_association" "public_1" {
  subnet_id = aws_subnet.public_1.id

  route_table_id = aws_route_table.public.id
}

# =========================================================
# ROUTE TABLE ASSOCIATION - SUBNET 2
# =========================================================

resource "aws_route_table_association" "public_2" {
  subnet_id = aws_subnet.public_2.id

  route_table_id = aws_route_table.public.id
}

# =========================================================
# ECS OPTIMIZED AMI
# =========================================================

data "aws_ami" "ecs" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name = "name"

    values = [
      "al2023-ami-ecs-hvm-*-x86_64"
    ]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# =========================================================
# ECR REPOSITORY
# =========================================================

resource "aws_ecr_repository" "app" {
  name = var.ecr_repository_name

  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-ecr"
  }
}

# =========================================================
# ECS CLUSTER
# =========================================================

resource "aws_ecs_cluster" "main" {
  name = var.cluster_name

  tags = {
    Name = var.cluster_name
  }
}

# =========================================================
# IAM ROLE FOR ECS EC2
# =========================================================

resource "aws_iam_role" "ecs_instance_role" {
  name = "${var.project_name}-ecs-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

# =========================================================
# ECS EC2 IAM POLICY
# =========================================================

resource "aws_iam_role_policy_attachment" "ecs_instance_policy" {
  role = aws_iam_role.ecs_instance_role.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# =========================================================
# INSTANCE PROFILE
# =========================================================

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "${var.project_name}-ecs-instance-profile"

  role = aws_iam_role.ecs_instance_role.name
}

# =========================================================
# ALB SECURITY GROUP
# =========================================================

resource "aws_security_group" "alb" {
  name = "${var.project_name}-alb-sg"

  description = "Security group for Application Load Balancer"

  vpc_id = aws_vpc.main.id

  # Internet -> ALB HTTP
  ingress {
    description = "Allow HTTP from Internet"

    from_port = 80
    to_port   = 80

    protocol = "tcp"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  # ALB -> Internet
  egress {
    from_port = 0
    to_port   = 0

    protocol = "-1"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

# =========================================================
# ECS EC2 SECURITY GROUP
# =========================================================

resource "aws_security_group" "ecs" {
  name = "${var.project_name}-ecs-sg"

  description = "Security group for ECS EC2 instances"

  vpc_id = aws_vpc.main.id

  # ALB -> ECS EC2 port 80
  ingress {
    description = "Allow HTTP from ALB"

    from_port = 80
    to_port   = 80

    protocol = "tcp"

    security_groups = [
      aws_security_group.alb.id
    ]
  }

  # SSH
  #
  # For production, restrict this to your IP.
  #
  ingress {
    description = "SSH"

    from_port = 22
    to_port   = 22

    protocol = "tcp"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  # EC2 -> Internet
  egress {
    from_port = 0
    to_port   = 0

    protocol = "-1"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  tags = {
    Name = "${var.project_name}-ecs-sg"
  }
}

# =========================================================
# ECS EC2 INSTANCE 1 + INSTANCE 2
# =========================================================

resource "aws_instance" "ecs" {
  count = var.ec2_instance_count

  ami = data.aws_ami.ecs.id

  instance_type = var.ec2_instance_type

  subnet_id = element(
    [
      aws_subnet.public_1.id,
      aws_subnet.public_2.id
    ],
    count.index
  )

  iam_instance_profile = aws_iam_instance_profile.ecs_instance_profile.name

  vpc_security_group_ids = [
    aws_security_group.ecs.id
  ]

  user_data = <<-EOF
    #!/bin/bash

    echo "ECS_CLUSTER=${aws_ecs_cluster.main.name}" >> /etc/ecs/ecs.config
  EOF

  tags = {
    Name = "${var.project_name}-ecs-instance-${count.index + 1}"
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_instance_policy
  ]
}

# =========================================================
# APPLICATION LOAD BALANCER
# =========================================================

resource "aws_lb" "app" {
  name = "${var.project_name}-alb"

  load_balancer_type = "application"

  security_groups = [
    aws_security_group.alb.id
  ]

  subnets = [
    aws_subnet.public_1.id,
    aws_subnet.public_2.id
  ]

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# =========================================================
# TARGET GROUP
# =========================================================

resource "aws_lb_target_group" "app" {
  name = "${var.project_name}-tg"

  port = 80

  protocol = "HTTP"

  vpc_id = aws_vpc.main.id

  target_type = "instance"

  health_check {
    enabled = true

    path = "/"

    protocol = "HTTP"

    port = "traffic-port"

    healthy_threshold = 2

    unhealthy_threshold = 3

    timeout = 5

    interval = 30

    matcher = "200"
  }

  tags = {
    Name = "${var.project_name}-target-group"
  }
}

# =========================================================
# ALB LISTENER
# =========================================================

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn

  port = 80

  protocol = "HTTP"

  default_action {
    type = "forward"

    target_group_arn = aws_lb_target_group.app.arn
  }
}

# =========================================================
# ECS TASK EXECUTION ROLE
# =========================================================

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}

# =========================================================
# ECS TASK EXECUTION POLICY
# =========================================================

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role = aws_iam_role.ecs_task_execution_role.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# =========================================================
# ECS TASK DEFINITION
# =========================================================

resource "aws_ecs_task_definition" "app" {
  family = var.task_family

  network_mode = "bridge"

  requires_compatibilities = [
    "EC2"
  ]

  cpu = "256"

  memory = "512"

  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name = var.container_name

      image = "${aws_ecr_repository.app.repository_url}:latest"

      essential = true

      cpu = 256

      memory = 512

      portMappings = [
        {
          containerPort = 80

          hostPort = 80

          protocol = "tcp"
        }
      ]
    }
  ])

  tags = {
    Name = "${var.project_name}-task-definition"
  }
}

# =========================================================
# ECS SERVICE
# =========================================================

resource "aws_ecs_service" "app" {
  name = var.service_name

  cluster = aws_ecs_cluster.main.id

  task_definition = aws_ecs_task_definition.app.arn

  desired_count = var.desired_count

  launch_type = "EC2"

  deployment_minimum_healthy_percent = 50

  deployment_maximum_percent = 200

  health_check_grace_period_seconds = 60

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn

    container_name = var.container_name

    container_port = 80
  }

  depends_on = [
    aws_lb_listener.http,
    aws_iam_role_policy_attachment.ecs_task_execution_policy
  ]

  tags = {
    Name = "${var.project_name}-ecs-service"
  }
}
