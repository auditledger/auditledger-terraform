# EC2 Deployment Example

This example demonstrates how to deploy an application using AuditLedger on an AWS EC2 instance with S3 storage for audit logs.

## Architecture

```
EC2 Instance
├── IAM Instance Profile (from module)
├── Security Group (configurable)
├── User Data (bootstrap script)
└── Connects to → S3 Bucket (audit logs)
```

## Features

- ✅ EC2 instance with IAM instance profile for S3 access
- ✅ S3 bucket with versioning and encryption
- ✅ Security group with configurable ingress rules
- ✅ User data script for application bootstrap
- ✅ Least-privilege IAM permissions

## Prerequisites

- AWS account with appropriate permissions
- VPC with at least one subnet
- AMI ID for your application

## Usage

### 1. Configure Variables

Create a `terraform.tfvars` file:

```hcl
aws_region           = "us-east-1"
environment          = "dev"
vpc_id               = "vpc-xxxxx"
subnet_id            = "subnet-xxxxx"
ami_id               = "ami-xxxxx"  # Your application AMI
instance_type        = "t3.small"
team                 = "platform"
allowed_cidr_blocks  = ["10.0.0.0/8"]  # Your corporate network
```

### 2. Deploy

```bash
terraform init
terraform plan
terraform apply
```

### 3. Access Your Instance

```bash
# Get instance public IP
terraform output instance_public_ip

# SSH to instance (if key pair configured)
ssh ec2-user@<instance-ip>
```

## Configuration Options

### Instance Configuration

```hcl
instance_type = "t3.small"   # Adjust based on workload
ami_id        = "ami-xxxxx"  # Your application AMI
```

### Security Group

```hcl
allowed_cidr_blocks = ["10.0.0.0/8"]  # Who can access the instance
```

### S3 Bucket Configuration

The S3 bucket is created via the `auditledger-s3` module with these defaults:
- Server-side encryption (AES256)
- Versioning enabled
- Public access blocked
- Lifecycle policies for cost optimization

## User Data Script

The `user_data.sh` script:
1. Updates system packages
2. Installs .NET runtime
3. Configures AuditLedger settings
4. Starts your application

Customize the script for your application's needs.

## Outputs

| Name | Description |
|------|-------------|
| `instance_id` | EC2 instance ID |
| `instance_public_ip` | Public IP address |
| `bucket_name` | S3 bucket for audit logs |
| `bucket_arn` | S3 bucket ARN |
| `iam_role_arn` | IAM role ARN |

## Security Considerations

### Production Hardening

For production use, consider:

1. **Enable IMDSv2** (add to instance):
   ```hcl
   metadata_options {
     http_endpoint               = "enabled"
     http_tokens                 = "required"
     http_put_response_hop_limit = 1
   }
   ```

2. **Encrypt EBS volumes**:
   ```hcl
   root_block_device {
     encrypted = true
   }
   ```

3. **Use private subnets** with NAT gateway
4. **Enable detailed monitoring**:
   ```hcl
   monitoring = true
   ```

5. **Restrict security group rules** to specific IPs

## Cost Estimate

**Monthly cost (us-east-1):**
- EC2 t3.small: ~$15/month
- S3 storage: ~$0.023/GB
- Data transfer: Variable

**Total:** ~$20-30/month for development

## Troubleshooting

### Instance can't access S3

Check IAM instance profile:
```bash
terraform output iam_role_arn
```

Verify instance has the role attached:
```bash
aws ec2 describe-instances --instance-ids <instance-id> \
  --query 'Reservations[0].Instances[0].IamInstanceProfile'
```

### Application not starting

Check user data logs:
```bash
ssh ec2-user@<instance-ip>
sudo cat /var/log/cloud-init-output.log
```

## Cleanup

```bash
terraform destroy
```

**Note:** If `force_destroy = false` on the S3 bucket, you'll need to empty it first:
```bash
aws s3 rm s3://<bucket-name> --recursive
terraform destroy
```

## Related Examples

- [ECS Fargate](../ecs-fargate/) - Containerized deployment
- [Lambda](../lambda/) - Serverless deployment
- [Azure App Service](../azure-app-service/) - Azure alternative

## License

MIT
