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
- [Lambda](../lambda/) - Serverless Python function
- [Azure App Service](../azure-app-service/) - Azure alternative

## License

MIT
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
README.md updated successfully
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

<!-- BEGIN_TF_DOCS -->


## Requirements

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |

## Providers

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.100.0 |

## Modules

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_auditledger_s3"></a> [auditledger\_s3](#module\_auditledger\_s3) | ../../modules/auditledger-s3 | n/a |

## Resources

## Resources

| Name | Type |
|------|------|
| [aws_iam_instance_profile.auditledger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.auditledger_ec2](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.auditledger_s3_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_instance.auditledger_app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_security_group.auditledger_app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |

## Inputs

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allowed_cidr_blocks"></a> [allowed\_cidr\_blocks](#input\_allowed\_cidr\_blocks) | CIDR blocks allowed to access the application | `list(string)` | <pre>[<br/>  "0.0.0.0/0"<br/>]</pre> | no |
| <a name="input_ami_id"></a> [ami\_id](#input\_ami\_id) | AMI ID for the EC2 instance | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region | `string` | `"us-east-1"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name | `string` | n/a | yes |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type | `string` | `"t3.small"` | no |
| <a name="input_retention_days"></a> [retention\_days](#input\_retention\_days) | Number of days to retain audit logs (minimum 365 days for compliance) | `number` | `2555` | no |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | Subnet ID for the EC2 instance | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID for the application | `string` | n/a | yes |

## Outputs

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bucket_arn"></a> [bucket\_arn](#output\_bucket\_arn) | ARN of the S3 bucket |
| <a name="output_bucket_id"></a> [bucket\_id](#output\_bucket\_id) | ID of the S3 bucket for audit logs |
| <a name="output_iam_role_arn"></a> [iam\_role\_arn](#output\_iam\_role\_arn) | ARN of the IAM role for EC2 instance |
| <a name="output_immutability_verified"></a> [immutability\_verified](#output\_immutability\_verified) | Confirmation that immutability is enforced |
| <a name="output_instance_id"></a> [instance\_id](#output\_instance\_id) | ID of the EC2 instance |
| <a name="output_instance_public_ip"></a> [instance\_public\_ip](#output\_instance\_public\_ip) | Public IP address of the EC2 instance |
<!-- END_TF_DOCS -->
