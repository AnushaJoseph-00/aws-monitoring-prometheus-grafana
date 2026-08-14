# ALB DNS Name
output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

# Frontend URL
output "frontend_url" {
  description = "Frontend application URL"
  value       = "http://${aws_lb.main.dns_name}"
}

# Backend URL
output "backend_url" {
  description = "Backend API URL"
  value       = "http://${aws_lb.main.dns_name}:4000"
}

# Admin URL
output "admin_url" {
  description = "Admin panel URL"
  value       = "http://${aws_lb.main.dns_name}:8080"
}

# ECR Repository URLs
output "ecr_backend_url" {
  description = "ECR URL for backend image"
  value       = aws_ecr_repository.backend.repository_url
}

output "ecr_frontend_url" {
  description = "ECR URL for frontend image"
  value       = aws_ecr_repository.frontend.repository_url
}

output "ecr_admin_url" {
  description = "ECR URL for admin image"
  value       = aws_ecr_repository.admin.repository_url
}

# ECS Cluster Name
output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

# VPC ID
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}