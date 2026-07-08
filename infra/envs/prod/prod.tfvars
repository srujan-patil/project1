aws_region   = "ap-south-1"
project_name = "hotelapp"
environment  = "prod"

vpc_cidr             = "10.20.0.0/16"
public_subnet_cidrs  = ["10.20.0.0/24", "10.20.1.0/24"]
private_subnet_cidrs = ["10.20.10.0/24", "10.20.11.0/24"]

container_image  = "public.ecr.aws/nginx/nginx:latest"
ecs_task_cpu      = "1024"
ecs_task_memory   = "2048"
ecs_desired_count = 2

rds_instance_class          = "db.r6g.large"
rds_backup_retention_period = 30
rds_deletion_protection     = true
rds_multi_az                = true
