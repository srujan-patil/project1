aws_region   = "ap-south-1"
project_name = "hotelapp"
environment  = "dev"

vpc_cidr             = "10.10.0.0/16"
public_subnet_cidrs  = ["10.10.0.0/24", "10.10.1.0/24"]
private_subnet_cidrs = ["10.10.10.0/24", "10.10.11.0/24"]

container_image  = "public.ecr.aws/nginx/nginx:latest"
ecs_task_cpu      = "256"
ecs_task_memory   = "512"
ecs_desired_count = 1

rds_instance_class          = "db.t4g.micro"
rds_backup_retention_period = 1
rds_deletion_protection     = false
rds_multi_az                = false
