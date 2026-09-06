# 1. ECR Registries for your Services
resource "aws_ecr_repository" "app" {
  for_each             = toset(["python-service", "java-service", "node-service"])
  name                 = each.key
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
}

# 2. Input Variables required from your Network Layer
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }

# 3. Core ECS Cluster Platform
resource "aws_ecs_cluster" "main" {
  name = "myorg-dev-cluster"
}

# 4. Identity Roles allowing your serverless container to talk to CloudWatch logs
resource "aws_iam_role" "ecs_execution_role" {
  name = "myorg-dev-ecs-execution-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 5. CloudWatch Logging Destination
resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/myorg-dev"
  retention_in_days = 7
}

# 6. Task Definition (Your Application running alongside the Datadog Agent)
resource "aws_ecs_task_definition" "python_service" {
  family                   = "python-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"  
  memory                   = "1024" 
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "python-app"
      image     = "docker.io/dockervase/python-service:latest" 
      essential = true
      portMappings = [{ containerPort = 8080, hostPort = 8080 }]
      environment = [
        { name = "DD_ENV", value = "dev" },
        { name = "DD_SERVICE", value = "python-service" },
        { name = "DD_VERSION", value = "1.0.0" },
        { name = "DD_AGENT_HOST", value = "127.0.0.1" } 
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = "eu-north-1"
          "awslogs-stream-prefix" = "python-app"
        }
      }
    },
    {
      name      = "datadog-agent"
      image     = "public.ecr.aws/datadog/agent:latest"
      essential = true
      environment = [
        { name = "DD_API_KEY", value = "YOUR_DATADOG_API_KEY_HERE" },
        { name = "DD_SITE", value = "datadoghq.com" },
        { name = "ECS_FARGATE", value = "true" },
        { name = "DD_APM_ENABLED", value = "true" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = "eu-north-1"
          "awslogs-stream-prefix" = "datadog"
        }
      }
    }
  ])
}

# 7. Traffic Security Guard
resource "aws_security_group" "ecs_tasks" {
  name        = "myorg-dev-ecs-tasks-sg"
  vpc_id      = var.vpc_id
  description = "Allow container traffic"
  ingress {
    protocol    = "tcp"
    from_port   = 8080
    to_port     = 8080
    cidr_blocks = ["0.0.0.0/0"] 
  }
  egress {
    protocol    = "all"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 8. Active Controller Orchestrating Your Service Instance
resource "aws_ecs_service" "python_service" {
  name            = "python-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.python_service.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true 
  }
}
