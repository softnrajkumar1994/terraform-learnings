terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }

  required_version = ">= 1.5.0"
}

# Variables for resource naming and conflict avoidance
variable "resource_prefix" {
  description = "Prefix for resource names to avoid conflicts"
  type        = string
  default     = "tf-demo"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

provider "aws" {
  region = "ap-south-1"
}

# --------------------------
# Networking (VPC, Subnets)
# --------------------------
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "subnet_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "subnet-a" }
}

resource "aws_subnet" "subnet_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-south-1b"
  map_public_ip_on_launch = true
  tags                    = { Name = "subnet-b" }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.rt.id
}

# --------------------------
# IAM Roles for EKS
# --------------------------
resource "aws_iam_role" "eks_role" {
  name = "eks-cluster-rolea"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Node group IAM role
resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-rolea"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ec2_container_registry_readonly" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}


# Security group for EKS nodes
resource "aws_security_group" "eks_nodes_sg" {
  name        = "eks-nodes-security-group"
  description = "Security group for EKS worker nodes"
  vpc_id      = aws_vpc.main.id

  # Allow nodes to communicate with each other
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
  }

  # Allow traffic from ALB on specific NodePort (30080)
  ingress {
    from_port       = 30080
    to_port         = 30080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
    description     = "Allow ALB to access nginx NodePort"
  }

  # Allow traffic from ALB on full NodePort range (for other services)
  ingress {
    from_port       = 30000
    to_port         = 32767
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
    description     = "Allow ALB to access NodePort range"
  }

  # Allow traffic from control plane
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow kubectl access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "eks-nodes-sg" }
}

# --------------------------
# EKS Cluster + Node Group
# --------------------------
resource "aws_eks_cluster" "eks" {
  name     = "example-eks-cluster"
  role_arn = aws_iam_role.eks_role.arn

  vpc_config {
    subnet_ids              = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]
    security_group_ids      = [aws_security_group.eks_nodes_sg.id]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

resource "aws_eks_node_group" "eks_nodes" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "example-nodes"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]

  scaling_config {
    desired_size = 2
    max_size     = 2
    min_size     = 1
  }

  instance_types = ["t3.small"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ec2_container_registry_readonly
  ]
}

# --------------------------
# Kubernetes Provider
# --------------------------
data "aws_eks_cluster" "eks" {
  name = aws_eks_cluster.eks.name
}

data "aws_eks_cluster_auth" "eks" {
  name = aws_eks_cluster.eks.name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks.token
}

# --------------------------
# Kubernetes Resources
# --------------------------
resource "kubernetes_namespace" "example" {
  metadata {
    name = "example"
  }
  depends_on = [aws_eks_node_group.eks_nodes]
}

resource "kubernetes_deployment" "nginx" {
  metadata {
    name      = "nginx-deployment"
    namespace = kubernetes_namespace.example.metadata[0].name
  }

  spec {
    replicas = 2
    selector {
      match_labels = { app = "nginx" }
    }

    template {
      metadata { labels = { app = "nginx" } }
      spec {
        container {
          name  = "nginx"
          image = "nginx:latest"
          port { container_port = 80 }
        }
      }
    }
  }

  depends_on = [aws_eks_node_group.eks_nodes]
}

resource "kubernetes_service" "nginx" {
  metadata {
    name      = "nginx-service"
    namespace = kubernetes_namespace.example.metadata[0].name
    annotations = {
      # Use a fixed NodePort for ALB target group
      "service.beta.kubernetes.io/aws-load-balancer-type" = "external"
    }
  }

  spec {
    selector = { app = "nginx" }
    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
      node_port   = 30080 # Fixed NodePort for ALB integration
    }
    type = "NodePort"
  }

  depends_on = [aws_eks_node_group.eks_nodes]
}

# Create Kubernetes Ingress for ALB integration (alternative approach)
resource "kubernetes_ingress_v1" "nginx_ingress" {
  metadata {
    name      = "nginx-ingress"
    namespace = kubernetes_namespace.example.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"                    = "alb"
      "alb.ingress.kubernetes.io/scheme"               = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"          = "ip"
      "alb.ingress.kubernetes.io/healthcheck-path"     = "/"
      "alb.ingress.kubernetes.io/healthcheck-protocol" = "HTTP"
      "alb.ingress.kubernetes.io/listen-ports"         = "[{\"HTTP\": 80}]"
    }
  }

  spec {
    rule {
      http {
        path {
          path      = "/eks"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.nginx.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_service.nginx]
}



# Note: EKS nodes are automatically registered with the ALB target group
# via the autoscaling group attachment. The nginx service uses a fixed
# NodePort (30080) for consistent routing.

# --------------------------
# EC2 Instance (bastion/router)
# --------------------------
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-security-group"
  description = "Security group for EC2 instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow traffic from ALB
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "ec2" {
  ami                    = "ami-00d892bc42a247508" # Amazon Linux 2 in ap-south-1
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.subnet_a.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello from EC2 Instance</h1>" > /var/www/html/index.html
              EOF

  tags = { Name = "kube-router" }
}



# --------------------------
# Application Load Balancer
# --------------------------
resource "aws_security_group" "alb_sg" {
  name        = "alb-security-group"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "alb-sg" }
}

resource "aws_lb" "main" {
  name               = "main-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]

  enable_deletion_protection = false

  tags = { Name = "main-alb" }
}

# Target Group for EC2
resource "aws_lb_target_group" "ec2_tg" {
  name     = "ec2-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = { Name = "ec2-tg" }
}

# Attach EC2 instance to target group
resource "aws_lb_target_group_attachment" "ec2_attachment" {
  target_group_arn = aws_lb_target_group.ec2_tg.arn
  target_id        = aws_instance.ec2.id
  port             = 80
}

# Target Group for EKS (NodePort service on fixed port 30080)
resource "aws_lb_target_group" "eks_tg" {
  name        = "eks-target-group"
  port        = 30080 # Fixed NodePort defined in kubernetes_service
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200,404"
    path                = "/"
    port                = "30080"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = { Name = "eks-tg" }
}

# Get EKS node instances for target group attachment
data "aws_autoscaling_group" "eks_nodes" {
  name = aws_eks_node_group.eks_nodes.resources[0].autoscaling_groups[0].name

  depends_on = [aws_eks_node_group.eks_nodes]
}

# Use autoscaling attachment to automatically register/deregister nodes
resource "aws_autoscaling_attachment" "eks_nodes_to_alb" {
  autoscaling_group_name = data.aws_autoscaling_group.eks_nodes.name
  lb_target_group_arn    = aws_lb_target_group.eks_tg.arn
}

# ALB Listener - Default routes to EC2
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ec2_tg.arn
  }
}

# ALB Listener Rule - Route /eks/* to EKS
resource "aws_lb_listener_rule" "eks_route" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.eks_tg.arn
  }

  condition {
    path_pattern {
      values = ["/eks/*"]
    }
  }
}

# ALB Listener Rule - Route /ec2/* to EC2
resource "aws_lb_listener_rule" "ec2_route" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ec2_tg.arn
  }

  condition {
    path_pattern {
      values = ["/ec2/*"]
    }
  }
}


# --------------------------
# API Gateway (HTTP API)
# --------------------------
resource "aws_apigatewayv2_api" "main" {
  name          = "main-api-gateway"
  protocol_type = "HTTP"
  description   = "API Gateway routing to ALB for EKS and EC2"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
    allow_headers = ["*"]
  }

  tags = { Name = "main-api-gateway" }
}

# VPC Link for API Gateway to connect to ALB
resource "aws_apigatewayv2_vpc_link" "main" {
  name               = "alb-vpc-link"
  security_group_ids = [aws_security_group.alb_sg.id]
  subnet_ids         = [aws_subnet.subnet_a.id, aws_subnet.subnet_b.id]

  tags = { Name = "alb-vpc-link" }
}

# API Gateway Integration with ALB
resource "aws_apigatewayv2_integration" "alb" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = aws_lb_listener.http.arn
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.main.id

  payload_format_version = "1.0"
}

# Default route - forwards all traffic to ALB
resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.alb.id}"
}

# Route for /eks/* - explicitly route to ALB (which routes to EKS target group)
resource "aws_apigatewayv2_route" "eks" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /eks/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.alb.id}"
}

# Route for /ec2/* - explicitly route to ALB (which routes to EC2 target group)
resource "aws_apigatewayv2_route" "ec2" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "ANY /ec2/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.alb.id}"
}

# API Gateway Stage (deployment)
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  tags = { Name = "default-stage" }
}

# CloudWatch Log Group for API Gateway
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/main-api"
  retention_in_days = 7

  tags = { Name = "api-gateway-logs" }
}


# --------------------------
# S3 + Lambda (Hello World on Upload)
# --------------------------
resource "aws_s3_bucket" "bucket" {
  bucket = "my-upload-bucket-${random_id.rand.hex}"
}

resource "random_id" "rand" {
  byte_length = 4
}

resource "aws_iam_role" "lambda_role" {
  name = "${var.resource_prefix}-lambda-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = {
    Name        = "${var.resource_prefix}-lambda-role"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "s3_lambda" {
  function_name = "${var.resource_prefix}-s3-hello-world-${var.environment}"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "python3.9"

  filename = "${path.module}/lambda.zip"

  source_code_hash = filebase64sha256("${path.module}/lambda.zip")
}

resource "aws_s3_bucket_notification" "bucket_notify" {
  bucket = aws_s3_bucket.bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}

resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.bucket.arn
}



# --------------------------
# Outputs
# --------------------------
output "api_gateway_endpoint" {
  description = "API Gateway endpoint URL"
  value       = aws_apigatewayv2_api.main.api_endpoint
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = aws_lb.main.dns_name
}

output "alb_endpoint" {
  description = "Application Load Balancer HTTP endpoint"
  value       = "http://${aws_lb.main.dns_name}"
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.eks.endpoint
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.eks.name
}

output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.ec2.id
}

output "ec2_public_ip" {
  description = "EC2 instance public IP"
  value       = aws_instance.ec2.public_ip
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.bucket.id
}


output "nginx_nodeport" {
  description = "NodePort assigned to nginx service"
  value       = 30080
}

output "eks_autoscaling_group" {
  description = "EKS node group autoscaling group name"
  value       = try(data.aws_autoscaling_group.eks_nodes.name, "Not yet created")
}

output "traffic_routing_info" {
  description = "Traffic routing information"
  value = {
    api_gateway = {
      endpoint      = aws_apigatewayv2_api.main.api_endpoint
      eks_route     = "${aws_apigatewayv2_api.main.api_endpoint}/eks/"
      ec2_route     = "${aws_apigatewayv2_api.main.api_endpoint}/ec2/"
      default_route = "${aws_apigatewayv2_api.main.api_endpoint}/"
    }
    alb = {
      endpoint      = "http://${aws_lb.main.dns_name}"
      eks_route     = "http://${aws_lb.main.dns_name}/eks/"
      ec2_route     = "http://${aws_lb.main.dns_name}/ec2/"
      default_route = "http://${aws_lb.main.dns_name}/"
    }
    routing_rules = {
      "/eks/*"  = "Routes to EKS cluster (nginx pods on NodePort 30080)"
      "/ec2/*"  = "Routes to EC2 instance"
      "default" = "Routes to EC2 instance"
    }
    eks_details = {
      nodeport            = 30080
      target_group_port   = 30080
      autoscaling_enabled = true
    }
  }
}
