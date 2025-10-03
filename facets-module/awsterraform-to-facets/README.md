# AWS Infrastructure with API Gateway, ALB, EKS, and EC2

This Terraform configuration creates a complete AWS infrastructure with API Gateway and Application Load Balancer routing traffic to both EKS (Kubernetes) and EC2 instances.

## Architecture Overview

```
Internet
    ↓
API Gateway (HTTP API)
    ↓
VPC Link
    ↓
Application Load Balancer (ALB)
    ↓
    ├─→ /eks/* → EKS Target Group → EKS Nodes (nginx pods)
    ├─→ /ec2/* → EC2 Target Group → EC2 Instance
    └─→ default → EC2 Target Group → EC2 Instance
```

## Components

### 1. **Networking**
- VPC with CIDR `10.0.0.0/16`
- 2 Public Subnets in different AZs (ap-south-1a, ap-south-1b)
- Internet Gateway
- Route Tables

### 2. **API Gateway (HTTP API)**
- Entry point for all external traffic
- Routes:
  - `ANY /eks/{proxy+}` → Routes to ALB (then to EKS)
  - `ANY /ec2/{proxy+}` → Routes to ALB (then to EC2)
  - `$default` → Routes to ALB (then to EC2)
- VPC Link for private integration with ALB
- CloudWatch logging enabled

### 3. **Application Load Balancer (ALB)**
- Internet-facing ALB
- Two target groups:
  - **EC2 Target Group**: Routes to EC2 instance on port 80
  - **EKS Target Group**: Routes to EKS nodes on NodePort (30000-32767)
- Listener rules:
  - `/eks/*` → EKS Target Group
  - `/ec2/*` → EC2 Target Group
  - Default → EC2 Target Group

### 4. **EKS Cluster**
- Cluster name: `example-eks-cluster`
- Node group with 1-2 t3.small instances
- Kubernetes resources:
  - Namespace: `example`
  - Deployment: nginx (2 replicas)
  - Service: NodePort (exposes nginx on node ports)
- Security group allows traffic from ALB on NodePort range

### 5. **EC2 Instance**
- Instance type: t3.micro
- Runs Apache httpd with a simple "Hello from EC2" page
- Security group allows traffic from ALB on port 80

### 6. **S3 + Lambda**
- S3 bucket for file uploads
- Lambda function triggered on object creation
- Prints "Hello World" when files are uploaded

## Traffic Flow

### Via API Gateway
1. **Request to EKS**: `https://<api-gateway-endpoint>/eks/`
   - API Gateway → VPC Link → ALB → EKS Target Group → EKS Nodes → nginx pods

2. **Request to EC2**: `https://<api-gateway-endpoint>/ec2/`
   - API Gateway → VPC Link → ALB → EC2 Target Group → EC2 Instance

3. **Default request**: `https://<api-gateway-endpoint>/`
   - API Gateway → VPC Link → ALB → EC2 Target Group → EC2 Instance

### Direct to ALB
1. **Request to EKS**: `http://<alb-dns-name>/eks/`
   - ALB → EKS Target Group → EKS Nodes → nginx pods

2. **Request to EC2**: `http://<alb-dns-name>/ec2/`
   - ALB → EC2 Target Group → EC2 Instance

3. **Default request**: `http://<alb-dns-name>/`
   - ALB → EC2 Target Group → EC2 Instance

## Prerequisites

1. AWS CLI configured with appropriate credentials
2. Terraform >= 1.5.0
3. Lambda deployment package (`lambda.zip`) in the module directory

## Creating the Lambda Package

Create a simple Lambda function:

```bash
# Create lambda directory
mkdir -p lambda_src
cd lambda_src

# Create index.py
cat > index.py << 'EOF'
def handler(event, context):
    print("Hello World from Lambda!")
    print(f"Event: {event}")
    return {
        'statusCode': 200,
        'body': 'Hello World!'
    }
EOF

# Create zip file
zip ../lambda.zip index.py
cd ..
rm -rf lambda_src
```

## Deployment

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply the configuration
terraform apply

# Get outputs
terraform output
```

## Outputs

After deployment, you'll get:

- `api_gateway_endpoint`: API Gateway URL (primary entry point)
- `alb_dns_name`: ALB DNS name (direct access)
- `alb_endpoint`: ALB HTTP endpoint
- `eks_cluster_endpoint`: EKS cluster API endpoint
- `eks_cluster_name`: EKS cluster name
- `ec2_instance_id`: EC2 instance ID
- `ec2_public_ip`: EC2 public IP
- `s3_bucket_name`: S3 bucket name
- `traffic_routing_info`: Complete routing information

## Testing

### Test EC2 via API Gateway
```bash
API_ENDPOINT=$(terraform output -raw api_gateway_endpoint)
curl $API_ENDPOINT/ec2/
# Expected: "Hello from EC2 Instance"
```

### Test EKS via API Gateway
```bash
curl $API_ENDPOINT/eks/
# Expected: nginx default page
```

### Test EC2 via ALB
```bash
ALB_DNS=$(terraform output -raw alb_dns_name)
curl http://$ALB_DNS/ec2/
# Expected: "Hello from EC2 Instance"
```

### Test EKS via ALB
```bash
curl http://$ALB_DNS/eks/
# Expected: nginx default page
```

### Test S3 Lambda
```bash
BUCKET=$(terraform output -raw s3_bucket_name)
echo "test" > test.txt
aws s3 cp test.txt s3://$BUCKET/
# Check CloudWatch logs for "Hello World from Lambda!"
```

## Security Groups

- **ALB Security Group**: Allows inbound HTTP (80) and HTTPS (443) from internet
- **EC2 Security Group**: Allows HTTP (80) from ALB and SSH (22) from internet
- **EKS Nodes Security Group**: Allows NodePort range (30000-32767) from ALB

## Important Notes

1. **NodePort Configuration**: The EKS target group uses port 30000. You may need to adjust this based on the actual NodePort assigned to the nginx service. Check with:
   ```bash
   kubectl get svc -n example nginx-service
   ```

2. **Health Checks**: The EKS target group health check accepts both 200 and 404 status codes to handle routing during initialization.

3. **Cost**: This infrastructure will incur AWS costs. Remember to destroy when not needed:
   ```bash
   terraform destroy
   ```

4. **Production Considerations**:
   - Add HTTPS/TLS certificates to ALB
   - Use AWS Certificate Manager for SSL/TLS
   - Implement proper authentication/authorization
   - Use private subnets for EKS nodes and EC2
   - Add NAT Gateway for private subnet internet access
   - Implement proper logging and monitoring
   - Use AWS WAF for API Gateway protection

## Cleanup

```bash
terraform destroy
```

## Troubleshooting

### EKS nodes not registering with ALB
- Check security group rules allow ALB → EKS nodes on NodePort range
- Verify EKS nodes are running: `kubectl get nodes`
- Check target group health: AWS Console → EC2 → Target Groups

### API Gateway 502/504 errors
- Verify VPC Link is active
- Check ALB listener and target group health
- Review CloudWatch logs for API Gateway

### EC2 not responding
- Verify user_data script executed: `ssh ec2-user@<ec2-ip> "systemctl status httpd"`
- Check security group allows traffic from ALB

## License

MIT

