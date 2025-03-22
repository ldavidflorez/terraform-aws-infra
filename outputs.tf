# outputs.tf
output "ec2_public_ip" {
  description = "IP pública de la instancia EC2"
  value       = aws_instance.web.public_ip
}

output "rds_endpoint" {
  description = "Endpoint de la base de datos RDS"
  value       = aws_db_instance.rds.endpoint
}

output "alb_dns_name" {
  description = "DNS name del Application Load Balancer"
  value       = aws_lb.app_lb.dns_name
}