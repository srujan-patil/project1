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
  default = "dev"
}

variable "vpc_cidr" {
  type    = string
  default = "10.10.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.10.0.0/24", "10.10.1.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.10.10.0/24", "10.10.11.0/24"]
}

variable "container_image" {
  type    = string
  default = "public.ecr.aws/nginx/nginx:latest"
}

variable "ecs_task_cpu" {
  type    = string
  default = "256"
}

variable "ecs_task_memory" {
  type    = string
  default = "512"
}

variable "ecs_desired_count" {
  type    = number
  default = 1
}

variable "rds_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "rds_backup_retention_period" {
  description = "Dev: short retention is fine since data is disposable"
  type        = number
  default     = 1
}

variable "rds_deletion_protection" {
  description = "Dev: disabled so environments can be torn down freely"
  type        = bool
  default     = false
}

variable "rds_multi_az" {
  type    = bool
  default = false
}

variable "db_password" {
  type      = string
  sensitive = true
  default   = "changeme-use-secrets-manager"
}
