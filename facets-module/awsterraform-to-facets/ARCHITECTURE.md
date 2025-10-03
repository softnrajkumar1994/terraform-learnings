# Architecture Diagram

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              Internet                                    │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 │ HTTPS
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      API Gateway (HTTP API)                              │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  Routes:                                                          │   │
│  │  • ANY /eks/{proxy+}  → Forward to ALB                          │   │
│  │  • ANY /ec2/{proxy+}  → Forward to ALB                          │   │
│  │  • $default           → Forward to ALB                          │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                                 │ VPC Link
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                              VPC (10.0.0.0/16)                           │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │         Application Load Balancer (ALB)                         │    │
│  │  ┌──────────────────────────────────────────────────────────┐  │    │
│  │  │  Listener Rules:                                          │  │    │
│  │  │  • /eks/* → EKS Target Group (Priority 100)             │  │    │
│  │  │  • /ec2/* → EC2 Target Group (Priority 200)             │  │    │
│  │  │  • default → EC2 Target Group                           │  │    │
│  │  └──────────────────────────────────────────────────────────┘  │    │
│  └────────────────┬───────────────────────┬───────────────────────┘    │
│                   │                       │                             │
│                   │                       │                             │
│         ┌─────────▼─────────┐   ┌────────▼────────┐                   │
│         │  EKS Target Group │   │ EC2 Target Group│                   │
│         │  Port: 30000      │   │ Port: 80        │                   │
│         └─────────┬─────────┘   └────────┬────────┘                   │
│                   │                       │                             │
│    ┌──────────────┴──────────────┐       │                             │
│    │                             │       │                             │
│    ▼                             ▼       ▼                             │
│  ┌─────────────────────────────────────────────────────────────────┐  │
│  │  Subnet A (10.0.1.0/24)      │  Subnet B (10.0.2.0/24)         │  │
│  │  AZ: ap-south-1a             │  AZ: ap-south-1b                │  │
│  │                              │                                  │  │
│  │  ┌──────────────┐            │  ┌──────────────┐               │  │
│  │  │ EKS Node 1   │            │  │ EKS Node 2   │               │  │
│  │  │ (t3.small)   │            │  │ (t3.small)   │               │  │
│  │  │              │            │  │              │               │  │
│  │  │ ┌──────────┐ │            │  │ ┌──────────┐ │               │  │
│  │  │ │nginx pod │ │            │  │ │nginx pod │ │               │  │
│  │  │ │  :80     │ │            │  │ │  :80     │ │               │  │
│  │  │ └──────────┘ │            │  │ └──────────┘ │               │  │
│  │  └──────────────┘            │  └──────────────┘               │  │
│  │                              │                                  │  │
│  │  ┌──────────────┐            │                                  │  │
│  │  │ EC2 Instance │            │                                  │  │
│  │  │ (t3.micro)   │            │                                  │  │
│  │  │              │            │                                  │  │
│  │  │ Apache httpd │            │                                  │  │
│  │  │   :80        │            │                                  │  │
│  │  └──────────────┘            │                                  │  │
│  └─────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │                    EKS Control Plane                            │    │
│  │                  (Managed by AWS)                               │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                         Additional Components                            │
│                                                                          │
│  ┌──────────────┐         ┌──────────────┐                             │
│  │  S3 Bucket   │────────▶│   Lambda     │                             │
│  │              │ trigger │  Function    │                             │
│  │              │         │              │                             │
│  └──────────────┘         └──────────────┘                             │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

## Traffic Flow Details

### 1. Request to EKS Service

```
User Request: https://<api-gateway-endpoint>/eks/index.html
    │
    ▼
API Gateway
    │ (Route: ANY /eks/{proxy+})
    ▼
VPC Link
    │
    ▼
Application Load Balancer
    │ (Listener Rule: /eks/* → EKS Target Group)
    ▼
EKS Target Group
    │ (Port: 30000-32767, NodePort)
    ▼
EKS Worker Nodes
    │ (NodePort Service)
    ▼
nginx Pods
    │ (Container Port: 80)
    ▼
Response: nginx default page
```

### 2. Request to EC2 Instance

```
User Request: https://<api-gateway-endpoint>/ec2/
    │
    ▼
API Gateway
    │ (Route: ANY /ec2/{proxy+})
    ▼
VPC Link
    │
    ▼
Application Load Balancer
    │ (Listener Rule: /ec2/* → EC2 Target Group)
    ▼
EC2 Target Group
    │ (Port: 80)
    ▼
EC2 Instance
    │ (Apache httpd on port 80)
    ▼
Response: "Hello from EC2 Instance"
```

### 3. Default Request (No Path)

```
User Request: https://<api-gateway-endpoint>/
    │
    ▼
API Gateway
    │ (Route: $default)
    ▼
VPC Link
    │
    ▼
Application Load Balancer
    │ (Default Action → EC2 Target Group)
    ▼
EC2 Target Group
    │ (Port: 80)
    ▼
EC2 Instance
    │ (Apache httpd on port 80)
    ▼
Response: "Hello from EC2 Instance"
```

## Security Groups

### ALB Security Group
```
Ingress:
  - Port 80 (HTTP) from 0.0.0.0/0
  - Port 443 (HTTPS) from 0.0.0.0/0

Egress:
  - All traffic to 0.0.0.0/0
```

### EC2 Security Group
```
Ingress:
  - Port 22 (SSH) from 0.0.0.0/0
  - Port 80 (HTTP) from 0.0.0.0/0
  - Port 80 (HTTP) from ALB Security Group

Egress:
  - All traffic to 0.0.0.0/0
```

### EKS Nodes Security Group
```
Ingress:
  - All TCP from self (node-to-node communication)
  - Port 30000-32767 (NodePort range) from ALB Security Group
  - Port 443 (HTTPS) from 0.0.0.0/0 (for kubectl access)

Egress:
  - All traffic to 0.0.0.0/0
```

## Component Details

### API Gateway
- **Type**: HTTP API (API Gateway v2)
- **Protocol**: HTTPS
- **Integration**: VPC Link to ALB
- **Features**:
  - CORS enabled
  - CloudWatch logging
  - Auto-deploy stage

### Application Load Balancer
- **Type**: Application Load Balancer
- **Scheme**: Internet-facing
- **Subnets**: 2 public subnets across AZs
- **Target Groups**: 2 (EKS and EC2)
- **Health Checks**: Enabled on both target groups

### EKS Cluster
- **Version**: Latest (managed by AWS)
- **Node Group**: 1-2 t3.small instances
- **Networking**: VPC CNI
- **Service Type**: NodePort (for ALB integration)

### EC2 Instance
- **Type**: t3.micro
- **AMI**: Amazon Linux 2
- **Software**: Apache httpd
- **Purpose**: Simple web server

### S3 + Lambda
- **Trigger**: S3 object creation
- **Runtime**: Python 3.9
- **Purpose**: Event-driven processing

## Scalability Considerations

1. **EKS Auto-scaling**: Configure Horizontal Pod Autoscaler (HPA) and Cluster Autoscaler
2. **ALB**: Automatically scales to handle traffic
3. **API Gateway**: Serverless, scales automatically
4. **EC2**: Can be replaced with Auto Scaling Group

## High Availability

- Multi-AZ deployment (2 availability zones)
- EKS nodes distributed across AZs
- ALB distributes traffic across healthy targets
- Health checks ensure traffic only goes to healthy instances

## Monitoring

- CloudWatch Logs for API Gateway
- ALB access logs (can be enabled)
- EKS control plane logs
- Lambda execution logs
- CloudWatch metrics for all components

