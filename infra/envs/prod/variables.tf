variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "project_name" {
  type    = string
  default = "hotelapp"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.20.0.0/24", "10.20.1.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.20.10.0/24", "10.20.11.0/24"]
}

variable "container_image" {
  type    = string
  default = "public.ecr.aws/nginx/nginx:latest"
}

variable "ecs_task_cpu" {
  type    = string
  default = "1024"
}

variable "ecs_task_memory" {
  type    = string
  default = "2048"
}

variable "ecs_desired_count" {
  type    = number
  default = 2
}

variable "rds_instance_class" {
  type    = string
  default = "db.r6g.large"
}

variable "rds_backup_retention_period" {
  description = "Prod: longer retention for real recovery needs"
  type        = number
  default     = 30
}

variable "rds_deletion_protection" {
  description = "Prod: enabled to prevent accidental destroys"
  type        = bool
  default     = true
}

variable "rds_multi_az" {
  description = "Prod: Multi-AZ for high availability"
  type        = bool
  default     = true
}

variable "db_password" {
  type      = string
  sensitive = true
  default   = "changeme-use-secrets-manager"
}
