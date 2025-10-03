# Quick Fix for "EntityAlreadyExists" Error

## The Problem

```
Error: creating IAM Role (lambda-role): EntityAlreadyExists: 
Role with name lambda-role already exists.
```

This happens when AWS resources already exist but Terraform doesn't know about them.

---

## Solution 1: Import Existing Resources (Recommended)

### Quick Import for Lambda Role

```bash
cd facets-module/awsterraform-to-facets

# Import the existing lambda-role
terraform import aws_iam_role.lambda_role lambda-role

# Continue with apply
terraform apply
```

### Import All Existing Resources (Automated)

```bash
cd facets-module/awsterraform-to-facets

# Make the script executable
chmod +x import-existing-resources.sh

# Run the import script
./import-existing-resources.sh

# Review and apply
terraform plan
terraform apply
```

The script will automatically:
- ✅ Find existing AWS resources
- ✅ Import them into Terraform state
- ✅ Skip resources that don't exist
- ✅ Backup your state file

---

## Solution 2: Use Unique Resource Names

Update your configuration to use unique names:

```bash
cd facets-module/awsterraform-to-facets

# Apply with custom prefix
terraform apply -var="resource_prefix=myproject" -var="environment=dev"
```

This creates resources like:
- `myproject-lambda-role-dev` instead of `lambda-role`
- `myproject-s3-hello-world-dev` instead of `s3-hello-world`

---

## Solution 3: Delete Existing Resources (Destructive)

⚠️ **WARNING**: This will delete your existing resources!

```bash
# Delete the existing lambda role
aws iam delete-role --role-name lambda-role

# Then apply Terraform
terraform apply
```

---

## What is Terraform Import?

**Terraform Import** brings existing cloud resources under Terraform management without recreating them.

### How It Works

```
Before Import:
  AWS: lambda-role exists ❌ Terraform: doesn't know about it
  Result: "EntityAlreadyExists" error

After Import:
  AWS: lambda-role exists ✅ Terraform: manages it
  Result: No conflict!
```

### Basic Import Syntax

```bash
terraform import <terraform_resource_address> <cloud_resource_id>
```

**Examples:**

```bash
# Import IAM role
terraform import aws_iam_role.lambda_role lambda-role

# Import VPC
terraform import aws_vpc.main vpc-12345678

# Import EC2 instance
terraform import aws_instance.ec2 i-1234567890abcdef0

# Import S3 bucket
terraform import aws_s3_bucket.bucket my-bucket-name

# Import EKS cluster
terraform import aws_eks_cluster.eks my-cluster-name

# Import Load Balancer
terraform import aws_lb.main arn:aws:elasticloadbalancing:region:account:loadbalancer/app/my-alb/xxxxx
```

---

## Finding Resource IDs for Import

### IAM Roles
```bash
aws iam list-roles --query 'Roles[*].RoleName' --output table
```

### VPCs
```bash
aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,CidrBlock]' --output table
```

### EC2 Instances
```bash
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0]]' --output table
```

### S3 Buckets
```bash
aws s3 ls
```

### EKS Clusters
```bash
aws eks list-clusters
```

### Load Balancers
```bash
aws elbv2 describe-load-balancers --query 'LoadBalancers[*].[LoadBalancerName,LoadBalancerArn]' --output table
```

---

## Step-by-Step: Import Lambda Role

### 1. Check if role exists
```bash
aws iam get-role --role-name lambda-role
```

**Output:**
```json
{
    "Role": {
        "RoleName": "lambda-role",
        "Arn": "arn:aws:iam::123456789012:role/lambda-role",
        ...
    }
}
```

### 2. Import into Terraform
```bash
terraform import aws_iam_role.lambda_role lambda-role
```

**Output:**
```
aws_iam_role.lambda_role: Importing from ID "lambda-role"...
aws_iam_role.lambda_role: Import prepared!
aws_iam_role.lambda_role: Refreshing state...

Import successful!
```

### 3. Verify import
```bash
terraform state show aws_iam_role.lambda_role
```

### 4. Check plan
```bash
terraform plan
```

If you see differences, update your `.tf` file to match the actual resource.

### 5. Apply
```bash
terraform apply
```

---

## Common Import Commands for This Project

```bash
# IAM Roles
terraform import aws_iam_role.lambda_role lambda-role
terraform import aws_iam_role.eks_role eks-cluster-role
terraform import aws_iam_role.eks_node_role eks-node-role

# EKS
terraform import aws_eks_cluster.eks example-eks-cluster

# S3
terraform import aws_s3_bucket.bucket my-upload-bucket-xxxxx

# Lambda
terraform import aws_lambda_function.s3_lambda s3-hello-world

# Load Balancer (replace ARN)
terraform import aws_lb.main arn:aws:elasticloadbalancing:ap-south-1:123456789012:loadbalancer/app/main-alb/xxxxx
```

---

## Troubleshooting

### Error: Resource not found
```
Error: Cannot import non-existent remote object
```

**Solution:** The resource doesn't exist in AWS. Remove the import command and let Terraform create it.

### Error: Resource already in state
```
Error: Resource already managed by Terraform
```

**Solution:** The resource is already imported. Check with:
```bash
terraform state list | grep lambda_role
```

### Error: Configuration doesn't match
After import, `terraform plan` shows changes.

**Solution:** Update your `.tf` file to match the actual resource configuration.

---

## Best Practices

1. **Always backup state before importing:**
   ```bash
   cp terraform.tfstate terraform.tfstate.backup
   ```

2. **Import one resource at a time:**
   ```bash
   terraform import aws_iam_role.lambda_role lambda-role
   terraform plan  # Verify before continuing
   ```

3. **Use the automated script for bulk imports:**
   ```bash
   ./import-existing-resources.sh
   ```

4. **Verify after import:**
   ```bash
   terraform state list
   terraform plan
   ```

---

## Quick Reference

| Task | Command |
|------|---------|
| Import resource | `terraform import ADDRESS ID` |
| List state | `terraform state list` |
| Show resource | `terraform state show ADDRESS` |
| Remove from state | `terraform state rm ADDRESS` |
| Backup state | `cp terraform.tfstate terraform.tfstate.backup` |

---

## Need More Help?

See the detailed guide:
- **TERRAFORM_IMPORT_GUIDE.md** - Complete import documentation
- **import-existing-resources.sh** - Automated import script

---

## TL;DR - Just Fix It Now!

```bash
cd facets-module/awsterraform-to-facets

# Option 1: Import the lambda role
terraform import aws_iam_role.lambda_role lambda-role
terraform apply

# Option 2: Use the automated script
chmod +x import-existing-resources.sh
./import-existing-resources.sh
terraform apply

# Option 3: Use unique names
terraform apply -var="resource_prefix=myproject"
```

Done! 🎉

