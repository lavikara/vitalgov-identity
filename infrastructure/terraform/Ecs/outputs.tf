output "ecs_cluster_id" {
  description = "ID of the ECS cluster."
  value       = aws_ecs_cluster.main.id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster."
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_names" {
  description = "Map of service key → ECS service name."
  value       = { for k, svc in aws_ecs_service.service : k => svc.name }
}

output "task_execution_role_arn" {
  description = "ARN of the task execution role."
  value       = aws_iam_role.ecs_task_execution.arn
}

output "task_role_arn" {
  description = "ARN of the task role."
  value       = aws_iam_role.ecs_task.arn
}
