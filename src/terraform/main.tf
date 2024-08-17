# Configure AWS provider
provider "aws" {
  region = "us-east-1"  # Replace with your desired region
}

# Route 53 Hosted Zone
resource "aws_route53_zone" "main" {
  name = "your-domain.com"  # Replace with your domain name
}

# Route 53 Record (alias) for the ELB
resource "aws_route53_record" "alias" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www"  # Adjust subdomain if needed
  type    = "A"

  alias {
    name = aws_elb.lb.dns_name
    zone_id = aws_route53_zone.main.zone_id
    evaluate_target_health = true  # Optional: Enable health checks
  }
}

# Elastic Load Balancer (ELB)
resource "aws_elb" "lb" {
  name   = "web-service-lb"
  security_groups = [aws_security_group.web_sg.id]
  subnets = aws_subnet.public.*.id  # Use all public subnets

  # Configure health checks (adjust as needed)
  health_check {
    target  = "TCP:80"  # Adjust port if your service runs on a different port
    interval = 30      # Seconds between health checks
    timeout  = 5       # Seconds to wait for response
    unhealthy_threshold = 2  # Number of consecutive failed checks to mark unhealthy
  }

  # (Optional) Configure connection draining for graceful termination
  # connecting_draining {
  #   enabled = true
  #   timeout = 300  # Seconds to wait for draining connections
  # }
}

# Security Group for the Web Service ECS Cluster
resource "aws_security_group" "web_sg" {
  name = "web-service-sg"
  description = "Security group for web service instances"

  ingress {
    from_port = 80  # Adjust if your service runs on a different port
    to_port   = 80  # Adjust if your service runs on a different port
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow all incoming traffic for testing (restrict in production)
  }

  egress {
    from_port = 0  # Allow all outgoing traffic
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "web_service" {
  name = "web-service-cluster"
}

# ECS Service (web1)
resource "aws_ecs_service" "web1" {
  name = "web1"
  cluster = aws_ecs_cluster.web_service.arn
  launch_type = "FARGATE"

  # Replace with your container image details
  task_definition = aws_ecs_task_definition.web_task.arn
  # ... additional service configuration options (desired_count, scaling policies, etc.)
}

# ECS Service (web2) can be defined similarly
resource "aws_ecs_service" "web2" {
  name = "web2"
  cluster = aws_ecs_cluster.web_service.arn
  launch_type = "FARGATE"

  task_definition = aws_ecs_task_definition.web_task.arn
  # ... additional service configuration options
}

# Similar definition for web3

# ECS Task Definition (web_task)
resource "aws_ecs_task_definition" "web_task" {
  family = "web-task-definition"
  cpu    = "256"
  memory = "512"
  network_mode = "awsvpc"  # Recommended for ECS tasks
  requires_compatibilities = ["FARGATE"]  # Task is intended for Fargate

  # Container definitions for your web service image and any dependencies
  container_definitions = <<EOF
[
  {
    "name": "web-container",
    "image": "your-web-service-image:latest",  # Replace with your image details
    "portMappings":