#!/bin/bash

# Script to import existing AWS resources into Terraform state
# This prevents "EntityAlreadyExists" errors

set -e

AWS_REGION="ap-south-1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo "Terraform Import Helper Script"
echo "=========================================="
echo ""
echo "This script will import existing AWS resources into Terraform state"
echo "to avoid 'EntityAlreadyExists' errors."
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to import resource if it exists
import_if_exists() {
    local resource_type=$1
    local terraform_address=$2
    local resource_id=$3
    local check_command=$4
    
    echo -n "Checking $resource_type ($resource_id)... "
    
    if eval "$check_command" &>/dev/null; then
        echo -e "${YELLOW}EXISTS${NC}"
        echo -n "  Importing into Terraform state... "
        
        if terraform import "$terraform_address" "$resource_id" &>/dev/null; then
            echo -e "${GREEN}SUCCESS${NC}"
            return 0
        else
            echo -e "${RED}FAILED${NC}"
            return 1
        fi
    else
        echo -e "${GREEN}NOT FOUND (will be created)${NC}"
        return 0
    fi
}

cd "$SCRIPT_DIR"

echo "Step 1: Checking Terraform initialization..."
if [ ! -d ".terraform" ]; then
    echo "Terraform not initialized. Running 'terraform init'..."
    terraform init
fi

echo ""
echo "Step 2: Backing up current state (if exists)..."
if [ -f "terraform.tfstate" ]; then
    cp terraform.tfstate "terraform.tfstate.backup.$(date +%Y%m%d_%H%M%S)"
    echo -e "${GREEN}State backed up${NC}"
else
    echo "No existing state file found"
fi

echo ""
echo "Step 3: Importing existing resources..."
echo ""

# IAM Roles
echo "--- IAM Roles ---"
import_if_exists \
    "Lambda IAM Role" \
    "aws_iam_role.lambda_role" \
    "lambda-role" \
    "aws iam get-role --role-name lambda-role --region $AWS_REGION"

import_if_exists \
    "EKS Cluster IAM Role" \
    "aws_iam_role.eks_role" \
    "eks-cluster-role" \
    "aws iam get-role --role-name eks-cluster-role --region $AWS_REGION"

import_if_exists \
    "EKS Node IAM Role" \
    "aws_iam_role.eks_node_role" \
    "eks-node-role" \
    "aws iam get-role --role-name eks-node-role --region $AWS_REGION"

echo ""
echo "--- VPC and Networking ---"

# Get VPC ID by tag or CIDR
VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=cidr,Values=10.0.0.0/16" \
    --query 'Vpcs[0].VpcId' \
    --output text \
    --region $AWS_REGION 2>/dev/null || echo "None")

if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
    import_if_exists \
        "VPC" \
        "aws_vpc.main" \
        "$VPC_ID" \
        "aws ec2 describe-vpcs --vpc-ids $VPC_ID --region $AWS_REGION"
    
    # Import subnets
    SUBNET_A=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=$VPC_ID" "Name=cidr-block,Values=10.0.1.0/24" \
        --query 'Subnets[0].SubnetId' \
        --output text \
        --region $AWS_REGION 2>/dev/null || echo "None")
    
    if [ "$SUBNET_A" != "None" ] && [ -n "$SUBNET_A" ]; then
        import_if_exists \
            "Subnet A" \
            "aws_subnet.subnet_a" \
            "$SUBNET_A" \
            "aws ec2 describe-subnets --subnet-ids $SUBNET_A --region $AWS_REGION"
    fi
    
    SUBNET_B=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=$VPC_ID" "Name=cidr-block,Values=10.0.2.0/24" \
        --query 'Subnets[0].SubnetId' \
        --output text \
        --region $AWS_REGION 2>/dev/null || echo "None")
    
    if [ "$SUBNET_B" != "None" ] && [ -n "$SUBNET_B" ]; then
        import_if_exists \
            "Subnet B" \
            "aws_subnet.subnet_b" \
            "$SUBNET_B" \
            "aws ec2 describe-subnets --subnet-ids $SUBNET_B --region $AWS_REGION"
    fi
fi

echo ""
echo "--- Security Groups ---"

# Find security groups by name
ALB_SG=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=alb-security-group" \
    --query 'SecurityGroups[0].GroupId' \
    --output text \
    --region $AWS_REGION 2>/dev/null || echo "None")

if [ "$ALB_SG" != "None" ] && [ -n "$ALB_SG" ]; then
    import_if_exists \
        "ALB Security Group" \
        "aws_security_group.alb_sg" \
        "$ALB_SG" \
        "aws ec2 describe-security-groups --group-ids $ALB_SG --region $AWS_REGION"
fi

echo ""
echo "--- EKS Cluster ---"

EKS_CLUSTER=$(aws eks list-clusters \
    --query 'clusters[?contains(@, `example-eks-cluster`)]|[0]' \
    --output text \
    --region $AWS_REGION 2>/dev/null || echo "None")

if [ "$EKS_CLUSTER" != "None" ] && [ -n "$EKS_CLUSTER" ]; then
    import_if_exists \
        "EKS Cluster" \
        "aws_eks_cluster.eks" \
        "$EKS_CLUSTER" \
        "aws eks describe-cluster --name $EKS_CLUSTER --region $AWS_REGION"
fi

echo ""
echo "--- Load Balancer ---"

ALB_ARN=$(aws elbv2 describe-load-balancers \
    --query 'LoadBalancers[?LoadBalancerName==`main-alb`].LoadBalancerArn' \
    --output text \
    --region $AWS_REGION 2>/dev/null || echo "None")

if [ "$ALB_ARN" != "None" ] && [ -n "$ALB_ARN" ]; then
    import_if_exists \
        "Application Load Balancer" \
        "aws_lb.main" \
        "$ALB_ARN" \
        "aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN --region $AWS_REGION"
fi

echo ""
echo "--- S3 Buckets ---"

# List S3 buckets matching pattern
S3_BUCKETS=$(aws s3api list-buckets \
    --query 'Buckets[?starts_with(Name, `my-upload-bucket-`)].Name' \
    --output text \
    --region $AWS_REGION 2>/dev/null || echo "")

if [ -n "$S3_BUCKETS" ]; then
    for bucket in $S3_BUCKETS; do
        import_if_exists \
            "S3 Bucket" \
            "aws_s3_bucket.bucket" \
            "$bucket" \
            "aws s3api head-bucket --bucket $bucket --region $AWS_REGION"
        break  # Only import the first one
    done
fi

echo ""
echo "--- Lambda Functions ---"

import_if_exists \
    "Lambda Function" \
    "aws_lambda_function.s3_lambda" \
    "s3-hello-world" \
    "aws lambda get-function --function-name s3-hello-world --region $AWS_REGION"

echo ""
echo "=========================================="
echo "Import Summary"
echo "=========================================="
echo ""
echo "Resources have been imported into Terraform state."
echo ""
echo "Next steps:"
echo "  1. Run: terraform plan"
echo "  2. Review the plan to ensure no unexpected changes"
echo "  3. Run: terraform apply"
echo ""
echo -e "${YELLOW}Note:${NC} Some resources may show differences in the plan."
echo "This is normal - Terraform will align the configuration with the actual state."
echo ""
echo "To see what's in your state:"
echo "  terraform state list"
echo ""
echo "To view a specific resource:"
echo "  terraform state show <resource_address>"
echo ""

