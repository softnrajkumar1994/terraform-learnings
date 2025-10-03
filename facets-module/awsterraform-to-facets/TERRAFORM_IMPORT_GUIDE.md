# Terraform Import Guide

## What is Terraform Import?

**Terraform Import** is a command that allows you to bring **existing infrastructure** (resources already created in AWS, Azure, GCP, etc.) into Terraform's management **without recreating them**.

### Why Use Terraform Import?

1. **Avoid Resource Conflicts**: When resources already exist (like your `lambda-role` error), import them instead of trying to create duplicates
2. **Migrate Existing Infrastructure**: Bring manually created resources under Terraform management
3. **Recover State**: Restore Terraform state after it's been lost or corrupted
4. **Team Collaboration**: Import resources created by other team members or tools

---

## How Terraform Import Works

```
┌─────────────────────────────────────────────────────────────────┐
│                    Before Import                                 │
│                                                                  │
│  AWS Cloud                          Terraform                   │
│  ┌──────────────┐                  ┌──────────────┐            │
│  │ lambda-role  │                  │  main.tf     │            │
│  │ (exists)     │                  │              │            │
│  └──────────────┘                  │ resource     │            │
│                                     │ "lambda_role"│            │
│  ❌ Conflict!                       └──────────────┘            │
│  Resource exists but                                            │
│  not in Terraform state                                         │
└─────────────────────────────────────────────────────────────────┘

                            ↓ terraform import

┌─────────────────────────────────────────────────────────────────┐
│                    After Import                                  │
│                                                                  │
│  AWS Cloud                          Terraform                   │
│  ┌──────────────┐                  ┌──────────────┐            │
│  │ lambda-role  │ ←────linked─────→│  main.tf     │            │
│  │ (exists)     │                  │              │            │
│  └──────────────┘                  │ resource     │            │
│                                     │ "lambda_role"│            │
│  ✅ Managed!                        │              │            │
│  Resource now tracked               │ terraform.   │            │
│  in Terraform state                 │ tfstate      │            │
│                                     └──────────────┘            │
└─────────────────────────────────────────────────────────────────┘
```

---

## Basic Syntax

```bash
terraform import [options] ADDRESS ID
```

- **ADDRESS**: The Terraform resource address (e.g., `aws_iam_role.lambda_role`)
- **ID**: The cloud provider's resource identifier (e.g., IAM role name, EC2 instance ID)

---

## Fixing Your Lambda Role Error

### Step 1: Check What Exists

```bash
# List existing IAM roles
aws iam list-roles --query 'Roles[?RoleName==`lambda-role`]'
```

### Step 2: Import the Existing Role

```bash
cd facets-module/awsterraform-to-facets

# Import the existing lambda-role into Terraform state
terraform import aws_iam_role.lambda_role lambda-role
```

**Output:**
```
aws_iam_role.lambda_role: Importing from ID "lambda-role"...
aws_iam_role.lambda_role: Import prepared!
  Prepared aws_iam_role for import
aws_iam_role.lambda_role: Refreshing state... [id=lambda-role]

Import successful!
```

### Step 3: Verify Import

```bash
# Check that the resource is now in state
terraform state list | grep lambda_role

# View the imported resource
terraform state show aws_iam_role.lambda_role
```

### Step 4: Continue with Apply

```bash
terraform plan
terraform apply
```

---

## Import All Existing Resources

Here's how to import all the resources that might already exist in your AWS account:

### 1. IAM Roles

```bash
# Lambda role
terraform import aws_iam_role.lambda_role lambda-role

# EKS cluster role
terraform import aws_iam_role.eks_role <role-name>

# EKS node role
terraform import aws_iam_role.eks_node_role <role-name>
```

### 2. VPC and Networking

```bash
# VPC
terraform import aws_vpc.main vpc-xxxxx

# Subnets
terraform import aws_subnet.subnet_a subnet-xxxxx
terraform import aws_subnet.subnet_b subnet-xxxxx

# Internet Gateway
terraform import aws_internet_gateway.igw igw-xxxxx

# Route Table
terraform import aws_route_table.public rtb-xxxxx
```

### 3. Security Groups

```bash
terraform import aws_security_group.alb_sg sg-xxxxx
terraform import aws_security_group.ec2_sg sg-xxxxx
terraform import aws_security_group.eks_nodes_sg sg-xxxxx
```

### 4. Load Balancer

```bash
# ALB
terraform import aws_lb.main arn:aws:elasticloadbalancing:region:account:loadbalancer/app/main-alb/xxxxx

# Target Groups
terraform import aws_lb_target_group.ec2_tg arn:aws:elasticloadbalancing:region:account:targetgroup/ec2-target-group/xxxxx
terraform import aws_lb_target_group.eks_tg arn:aws:elasticloadbalancing:region:account:targetgroup/eks-target-group/xxxxx
```

### 5. EKS Cluster

```bash
terraform import aws_eks_cluster.eks example-eks-cluster
terraform import aws_eks_node_group.eks_nodes example-eks-cluster:node-group-name
```

### 6. EC2 Instance

```bash
terraform import aws_instance.ec2 i-xxxxx
```

### 7. S3 Bucket

```bash
terraform import aws_s3_bucket.bucket my-upload-bucket-xxxxx
```

### 8. Lambda Function

```bash
terraform import aws_lambda_function.s3_lambda s3-hello-world
```

### 9. API Gateway

```bash
terraform import aws_apigatewayv2_api.main api-id
terraform import aws_apigatewayv2_vpc_link.main vpc-link-id
```

---

## Finding Resource IDs

### AWS CLI Commands

```bash
# IAM Roles
aws iam list-roles --query 'Roles[*].[RoleName,Arn]' --output table

# VPCs
aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' --output table

# Subnets
aws ec2 describe-subnets --query 'Subnets[*].[SubnetId,CidrBlock,AvailabilityZone]' --output table

# Security Groups
aws ec2 describe-security-groups --query 'SecurityGroups[*].[GroupId,GroupName]' --output table

# Load Balancers
aws elbv2 describe-load-balancers --query 'LoadBalancers[*].[LoadBalancerArn,LoadBalancerName]' --output table

# Target Groups
aws elbv2 describe-target-groups --query 'TargetGroups[*].[TargetGroupArn,TargetGroupName]' --output table

# EKS Clusters
aws eks list-clusters
aws eks describe-cluster --name example-eks-cluster

# EC2 Instances
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0]]' --output table

# S3 Buckets
aws s3 ls

# Lambda Functions
aws lambda list-functions --query 'Functions[*].[FunctionName,FunctionArn]' --output table

# API Gateway
aws apigatewayv2 get-apis --query 'Items[*].[ApiId,Name]' --output table
```

---

## Alternative: Use Unique Resource Names

Instead of importing, you can modify your Terraform to use unique names:

```hcl
# Before (causes conflict)
resource "aws_iam_role" "lambda_role" {
  name = "lambda-role"
  # ...
}

# After (unique name)
resource "aws_iam_role" "lambda_role" {
  name = "${var.resource_prefix}-lambda-role-${var.environment}"
  # Example: "tf-demo-lambda-role-dev"
  # ...
}
```

Update all resources to use the prefix:

```hcl
variable "resource_prefix" {
  default = "tf-demo"
}

variable "environment" {
  default = "dev"
}

# Apply to all resources
resource "aws_iam_role" "lambda_role" {
  name = "${var.resource_prefix}-lambda-role-${var.environment}"
}

resource "aws_eks_cluster" "eks" {
  name = "${var.resource_prefix}-eks-cluster-${var.environment}"
}

resource "aws_lb" "main" {
  name = "${var.resource_prefix}-alb-${var.environment}"
}
```

---

## Terraform Import Block (Terraform 1.5+)

Modern Terraform supports declarative imports:

```hcl
# In your main.tf or imports.tf
import {
  to = aws_iam_role.lambda_role
  id = "lambda-role"
}

import {
  to = aws_eks_cluster.eks
  id = "example-eks-cluster"
}
```

Then run:
```bash
terraform plan -generate-config-out=imported.tf
terraform apply
```

---

## Best Practices

### 1. **Import One Resource at a Time**
```bash
terraform import aws_iam_role.lambda_role lambda-role
terraform plan  # Verify before continuing
```

### 2. **Backup State Before Importing**
```bash
cp terraform.tfstate terraform.tfstate.backup
```

### 3. **Use Terraform State Commands**
```bash
# List all resources in state
terraform state list

# Show specific resource
terraform state show aws_iam_role.lambda_role

# Remove resource from state (if needed)
terraform state rm aws_iam_role.lambda_role
```

### 4. **Verify Configuration Matches**
After import, run `terraform plan` to ensure your configuration matches the imported resource. You may need to adjust your `.tf` files.

---

## Complete Import Script for Your Project

```bash
#!/bin/bash
# import-existing-resources.sh

# Set your AWS region
export AWS_REGION=ap-south-1

echo "Importing existing AWS resources into Terraform state..."

# Import IAM Role (if exists)
if aws iam get-role --role-name lambda-role 2>/dev/null; then
  echo "Importing lambda-role..."
  terraform import aws_iam_role.lambda_role lambda-role
fi

# Import VPC (replace vpc-xxxxx with actual ID)
# VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=main" --query 'Vpcs[0].VpcId' --output text)
# if [ "$VPC_ID" != "None" ]; then
#   terraform import aws_vpc.main $VPC_ID
# fi

# Add more imports as needed...

echo "Import complete! Run 'terraform plan' to verify."
```

Make it executable:
```bash
chmod +x import-existing-resources.sh
./import-existing-resources.sh
```

---

## Summary

| Action | Command | When to Use |
|--------|---------|-------------|
| **Import single resource** | `terraform import ADDRESS ID` | Resource already exists in cloud |
| **List state** | `terraform state list` | See what's managed |
| **Show resource** | `terraform state show ADDRESS` | View imported details |
| **Remove from state** | `terraform state rm ADDRESS` | Stop managing resource |
| **Find resource ID** | AWS CLI commands | Get ID for import |

**For your immediate issue:**
```bash
terraform import aws_iam_role.lambda_role lambda-role
terraform apply
```

This will resolve the "EntityAlreadyExists" error! 🎉

