output "vpc_id" {
  description = "VPC ID"

  value = aws_vpc.main.id
}

output "public_subnet_1_id" {
  description = "Public subnet 1"

  value = aws_subnet.public_1.id
}

output "public_subnet_2_id" {
  description = "Public subnet 2"

  value = aws_subnet.public_2.id
}

output "ecr_repository_url" {
  description = "ECR repository URL"

  value = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster"

  value = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service"

  value = aws_ecs_service.app.name
}

output "ecs_instance_ids" {
  description = "ECS EC2 instance IDs"

  value = aws_instance.ecs[*].id
}

output "load_balancer_dns" {
  description = "Application Load Balancer DNS"

  value = aws_lb.app.dns_name
}

output "application_url" {
  description = "Application URL"

  value = "http://${aws_lb.app.dns_name}"
}