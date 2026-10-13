variable "aws_region" {
  description = "AWS region"

  type = string

  default = "us-east-1"
}

variable "project_name" {
  description = "Project name"

  type = string

  default = "my-ecs-project"
}

variable "ecr_repository_name" {
  description = "ECR repository name"

  type = string

  default = "my-ecs-app"
}

variable "cluster_name" {
  description = "ECS cluster name"

  type = string

  default = "my-ecs-cluster"
}

variable "task_family" {
  description = "ECS task definition family"

  type = string

  default = "my-ecs-task"
}

variable "container_name" {
  description = "ECS container name"

  type = string

  default = "my-app"
}

variable "service_name" {
  description = "ECS service name"

  type = string

  default = "my-ecs-service"
}

variable "ec2_instance_type" {
  description = "ECS EC2 instance type"

  type = string

  default = "t3.micro"
}

variable "ec2_instance_count" {
  description = "Number of ECS EC2 instances"

  type = number

  default = 2
}

variable "desired_count" {
  description = "Number of ECS tasks"

  type = number

  default = 2
}
