# Fix for "Invalid count argument" Error

## Problem

The original implementation attempted to dynamically discover and register EKS nodes with the ALB target group using:

```hcl
data "aws_instances" "eks_nodes" {
  instance_tags = {
    "eks:cluster-name" = aws_eks_cluster.eks.name
  }
  instance_state_names = ["running"]
  depends_on = [aws_eks_node_group.eks_nodes]
}

resource "aws_lb_target_group_attachment" "eks_nodes" {
  count            = length(data.aws_instances.eks_nodes.ids)
  target_group_arn = aws_lb_target_group.eks_tg.arn
  target_id        = data.aws_instances.eks_nodes.ids[count.index]
  port             = 30000
}
```

**Error:**
```
Error: Invalid count argument

The "count" value depends on resource attributes that cannot be determined 
until apply, so Terraform cannot predict how many instances will be created.
```

## Root Cause

Terraform cannot determine the `count` value at plan time because:
1. The data source `aws_instances` depends on resources that don't exist yet
2. The number of EKS nodes is unknown until after `terraform apply`
3. Terraform requires `count` to be known during the plan phase

## Solution

### 1. Fixed NodePort Configuration

Changed the Kubernetes service to use a **fixed NodePort** instead of a random one:

```hcl
resource "kubernetes_service" "nginx" {
  metadata {
    name      = "nginx-service"
    namespace = kubernetes_namespace.example.metadata[0].name
  }

  spec {
    selector = { app = "nginx" }
    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
      node_port   = 30080  # Fixed NodePort
    }
    type = "NodePort"
  }
}
```

### 2. Autoscaling Group Attachment

Instead of manually registering individual instances, we use AWS autoscaling group attachment which automatically handles node registration/deregistration:

```hcl
# Get the autoscaling group created by EKS node group
data "aws_autoscaling_group" "eks_nodes" {
  name = aws_eks_node_group.eks_nodes.resources[0].autoscaling_groups[0].name
  depends_on = [aws_eks_node_group.eks_nodes]
}

# Attach the autoscaling group to the target group
resource "aws_autoscaling_attachment" "eks_nodes_to_alb" {
  autoscaling_group_name = data.aws_autoscaling_group.eks_nodes.name
  lb_target_group_arn    = aws_lb_target_group.eks_tg.arn
}
```

### 3. Updated Target Group

Updated the target group to use the fixed NodePort:

```hcl
resource "aws_lb_target_group" "eks_tg" {
  name        = "eks-target-group"
  port        = 30080  # Matches the fixed NodePort
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200,404"
    path                = "/"
    port                = "30080"  # Health check on the NodePort
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
}
```

## Benefits of This Approach

### 1. **Automatic Scaling**
- When EKS node group scales up, new nodes are automatically registered with the ALB
- When nodes are terminated, they're automatically deregistered
- No manual intervention or additional Terraform runs needed

### 2. **Predictable Configuration**
- Fixed NodePort (30080) ensures consistent routing
- No dependency on runtime data during plan phase
- Terraform can validate the entire configuration before apply

### 3. **Simplified Management**
- Single autoscaling attachment instead of multiple instance attachments
- Cleaner Terraform state
- Easier to troubleshoot

### 4. **Production Ready**
- Handles node failures gracefully
- Works with cluster autoscaler
- Compatible with EKS managed node groups

## Alternative Approaches Considered

### Option 1: Two-Stage Apply (Not Recommended)
```bash
terraform apply -target=aws_eks_node_group.eks_nodes
terraform apply
```
**Drawback:** Requires manual intervention and multiple applies

### Option 2: AWS Load Balancer Controller (More Complex)
Install the AWS Load Balancer Controller in EKS and use Kubernetes Ingress resources.
**Drawback:** Requires additional setup and IRSA configuration

### Option 3: Manual Registration (Not Scalable)
Manually specify instance IDs in Terraform.
**Drawback:** Doesn't work with autoscaling

## Testing the Fix

### 1. Validate Configuration
```bash
cd facets-module/awsterraform-to-facets
terraform validate
```

### 2. Plan (Should work without errors)
```bash
terraform plan
```

### 3. Apply
```bash
terraform apply
```

### 4. Verify NodePort
```bash
kubectl get svc -n example nginx-service
# Should show NodePort 30080
```

### 5. Check Target Group Health
```bash
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw eks_target_group_arn)
```

### 6. Test Traffic Flow
```bash
# Via API Gateway
API_ENDPOINT=$(terraform output -raw api_gateway_endpoint)
curl $API_ENDPOINT/eks/

# Via ALB
ALB_DNS=$(terraform output -raw alb_dns_name)
curl http://$ALB_DNS/eks/
```

## Security Considerations

The security group for EKS nodes allows traffic from the ALB on:
- Port 30080 (specific nginx NodePort)
- Ports 30000-32767 (full NodePort range for other services)

```hcl
resource "aws_security_group" "eks_nodes_sg" {
  # ... other rules ...
  
  ingress {
    from_port       = 30080
    to_port         = 30080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
    description     = "Allow ALB to access nginx NodePort"
  }
}
```

## Monitoring

Monitor the autoscaling attachment:
```bash
# Check autoscaling group
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names $(terraform output -raw eks_autoscaling_group)

# Check target group targets
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>
```

## Rollback Plan

If issues occur:
1. The autoscaling attachment can be removed without affecting the EKS cluster
2. Nodes will continue to run but won't receive traffic from ALB
3. Can switch back to Kubernetes LoadBalancer service type if needed

## Additional Resources

- [AWS EKS Best Practices - Load Balancing](https://aws.github.io/aws-eks-best-practices/networking/loadbalancing/)
- [Terraform AWS Autoscaling Attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_attachment)
- [Kubernetes NodePort Service](https://kubernetes.io/docs/concepts/services-networking/service/#type-nodeport)

