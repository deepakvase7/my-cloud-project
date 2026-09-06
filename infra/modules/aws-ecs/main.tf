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

# 1. Create the OIDC Identity Provider for GitHub Trust
## 1. Dynamically fetch GitHub's live active certificate keys at runtime


# 2. Automated OIDC Provider for GitHub Actions
# 🟢 REPLACED: Hardcoded official production thumbprints to completely bypass network lookup errors
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}


# 3. Secure IAM Role with broad sub-domain allowance
resource "aws_iam_role" "github_actions_role" {
  name = "github-actions-ecs-deploy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Action    = "sts:AssumeRoleWithWebIdentity"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:deepakvase7/my-cloud-project:*"
          }
        }
      }
    ]
  })
}






# 3. Attach full administrative power to this specific deployment role
resource "aws_iam_role_policy_attachment" "github_admin_attach" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# 4. Output the exact Role ARN so you can use it in your pipeline script
output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions_role.arn
  description = "The exact ARN string for GitHub Actions to use"
}
