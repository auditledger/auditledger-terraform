# ECS Fargate Deployment Example

This example demonstrates how to deploy a containerized application using AuditLedger on AWS ECS Fargate with S3 storage for audit logs.

## Architecture

```
ECS Fargate Cluster
├── ECS Task (serverless containers)
│   ├── Task Role (from module) → S3 access
│   └── Execution Role → ECR, CloudWatch
├── CloudWatch Log Group
└── S3 Bucket (audit logs)
```

## Features

- ✅ Serverless container deployment (no EC2 to manage)
- ✅ S3 bucket with versioning and encryption
- ✅ Optional KMS encryption for production
- ✅ IAM roles for least-privilege access
- ✅ CloudWatch Logs integration
- ✅ Automatic lifecycle policies for cost optimization

## Prerequisites

- AWS account with appropriate permissions
- Docker image pushed to ECR (or public registry)
- VPC with subnets (for networking)

## Usage

### 1. Build and Push Your Container

```bash
# Build your application image
docker build -t auditledger-app .

# Tag and push to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
docker tag auditledger-app:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/auditledger-app:latest
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/auditledger-app:latest
```

### 2. Configure Variables

Create a `terraform.tfvars` file:

```hcl
aws_region   = "us-east-1"
environment  = "production"  # or "dev", "staging"
app_image    = "<account-id>.dkr.ecr.us-east-1.amazonaws.com/auditledger-app:latest"
task_cpu     = "256"   # 0.25 vCPU
task_memory  = "512"   # 512 MB
team         = "platform"
retention_days = 2555  # 7 years for HIPAA compliance
```

### 3. Deploy

```bash
terraform init
terraform plan
terraform apply
```

### 4. Verify Deployment

```bash
# Check task status
aws ecs list-tasks --cluster <environment>-auditledger-cluster

# View logs
aws logs tail /ecs/<environment>/auditledger --follow
```

## Configuration Options

### Environment Selection

The `environment` variable controls KMS encryption:
- **production**: Uses KMS encryption with key rotation
- **dev/staging**: Uses standard AES256 encryption (lower cost)

```hcl
environment = "production"  # Enables KMS encryption
```

### Task Sizing

Fargate CPU and memory must use specific combinations:

```hcl
# Small workload
task_cpu    = "256"   # 0.25 vCPU
task_memory = "512"   # 512 MB

# Medium workload
task_cpu    = "512"   # 0.5 vCPU
task_memory = "1024"  # 1 GB

# Large workload
task_cpu    = "1024"  # 1 vCPU
task_memory = "2048"  # 2 GB
```

See [AWS Fargate pricing](https://aws.amazon.com/fargate/pricing/) for valid combinations.

### Compliance Retention

```hcl
retention_days = 2555  # 7 years (HIPAA, SOX)
retention_days = 365   # 1 year (PCI DSS minimum)
retention_days = 2190  # 6 years (GDPR recommended)
```

## S3 Lifecycle Policies

The module automatically configures lifecycle policies:

```hcl
transition_to_ia_days      = 90   # Move to Infrequent Access after 90 days
transition_to_glacier_days = 365  # Move to Glacier after 1 year
```

**Cost savings:**
- Standard: $0.023/GB/month
- IA: $0.0125/GB/month (46% cheaper)
- Glacier: $0.004/GB/month (83% cheaper)

## Outputs

| Name | Description |
|------|-------------|
| `cluster_id` | ECS cluster ID |
| `task_definition_arn` | ECS task definition ARN |
| `bucket_name` | S3 bucket for audit logs |
| `bucket_arn` | S3 bucket ARN |
| `iam_role_arn` | Task IAM role ARN |

## Security Features

### Production KMS Encryption

When `environment = "production"`, the example creates:
- KMS key with automatic rotation
- Key policy allowing account root and S3 service access
- Alias for easy reference

### IAM Permissions

Two separate roles:
1. **Task Role**: Application permissions (S3 access for audit logs)
2. **Execution Role**: ECS infrastructure permissions (ECR pull, CloudWatch logs)

### Network Security

This example doesn't include VPC/networking configuration. For production:

```hcl
# Add to your main.tf
network_configuration {
  subnets          = var.private_subnet_ids  # Use private subnets
  security_groups  = [aws_security_group.ecs_tasks.id]
  assign_public_ip = false  # No public IPs in production
}
```

## Cost Estimate

**Monthly cost (us-east-1):**

| Resource | Cost |
|----------|------|
| Fargate (0.25 vCPU, 0.5GB) | ~$15/month |
| S3 storage (10GB) | ~$0.23/month |
| CloudWatch Logs (1GB) | ~$0.50/month |
| KMS (production only) | ~$1/month + $0.03/10k requests |

**Total:** ~$16-20/month for development, ~$17-22/month for production

## Application Configuration

Your container receives these environment variables:

```dockerfile
ENV AuditLedger__Storage__Provider=AwsS3
ENV AuditLedger__Storage__AwsS3__BucketName=<from-terraform>
ENV AuditLedger__Storage__AwsS3__Region=us-east-1
```

Example .NET configuration:

```csharp
services.AddAuditLedger(options =>
{
    // Configuration automatically loaded from environment variables
    options.Storage.Provider = StorageProvider.AwsS3;
    options.Storage.AwsS3.BucketName = Environment.GetEnvironmentVariable("AuditLedger__Storage__AwsS3__BucketName");
    options.Storage.AwsS3.Region = Environment.GetEnvironmentVariable("AuditLedger__Storage__AwsS3__Region");
});
```

## Scaling

To scale your application:

```bash
# Update desired count in main.tf
desired_count = 3  # Run 3 tasks

# Or use AWS CLI
aws ecs update-service \
  --cluster <environment>-auditledger-cluster \
  --service auditledger-service \
  --desired-count 3
```

For auto-scaling:

```hcl
resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/<cluster-name>/<service-name>"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}
```

## Troubleshooting

### Task fails to start

Check execution role permissions:
```bash
aws ecs describe-tasks --cluster <cluster-name> --tasks <task-id>
```

Common issues:
- Can't pull image from ECR → Check execution role has ECR permissions
- Can't write logs → Check execution role has CloudWatch permissions

### Task can't write to S3

Check task role:
```bash
terraform output iam_role_arn
```

Verify policy attachment:
```bash
aws iam list-attached-role-policies --role-name <role-name>
```

### High costs

1. **Right-size your tasks**: Use smallest CPU/memory that works
2. **Enable lifecycle policies**: Already configured in the module
3. **Adjust log retention**: Reduce CloudWatch retention if not needed
4. **Use Spot capacity**: Consider Fargate Spot for non-critical workloads

## Production Hardening

For production deployments, consider:

1. **Private networking**:
   ```hcl
   assign_public_ip = false
   subnets          = var.private_subnet_ids
   ```

2. **Load balancer** for multiple tasks:
   ```hcl
   resource "aws_lb" "app" {
     # ALB configuration
   }
   ```

3. **Service discovery**:
   ```hcl
   service_registries {
     registry_arn = aws_service_discovery_service.app.arn
   }
   ```

4. **Monitoring and alerts**:
   ```hcl
   resource "aws_cloudwatch_metric_alarm" "task_count" {
     # CloudWatch alarm for task failures
   }
   ```

## Cleanup

```bash
terraform destroy
```

**Note:** S3 bucket must be empty before destruction. If you have data:

```bash
aws s3 rm s3://<bucket-name> --recursive
terraform destroy
```

## Related Examples

- [EC2](../ec2/) - Traditional instance deployment
- [Lambda](../lambda/) - Serverless Python function
- [Azure App Service](../azure-app-service/) - Azure alternative

## Additional Resources

- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [Fargate Task Sizing](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-cpu-memory-error.html)
- [ECS Task IAM Roles](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-iam-roles.html)

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
| [aws_cloudwatch_log_group.auditledger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_ecs_task_definition.auditledger_app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_role.auditledger_ecs_task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.ecs_execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.auditledger_s3_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ecs_execution_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_kms_alias.audit_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.audit_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_app_image"></a> [app\_image](#input\_app\_image) | Docker image for the application | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region | `string` | `"us-east-1"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (dev, staging, production) | `string` | n/a | yes |
| <a name="input_retention_days"></a> [retention\_days](#input\_retention\_days) | Number of days to retain audit logs | `number` | `2555` | no |
| <a name="input_task_cpu"></a> [task\_cpu](#input\_task\_cpu) | CPU units for ECS task | `string` | `"256"` | no |
| <a name="input_task_memory"></a> [task\_memory](#input\_task\_memory) | Memory for ECS task | `string` | `"512"` | no |
| <a name="input_team"></a> [team](#input\_team) | Team name | `string` | `"platform"` | no |

## Outputs

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bucket_arn"></a> [bucket\_arn](#output\_bucket\_arn) | ARN of the audit logs S3 bucket |
| <a name="output_bucket_id"></a> [bucket\_id](#output\_bucket\_id) | ID of the audit logs S3 bucket |
| <a name="output_iam_task_role_arn"></a> [iam\_task\_role\_arn](#output\_iam\_task\_role\_arn) | ARN of the ECS task IAM role |
| <a name="output_immutability_verified"></a> [immutability\_verified](#output\_immutability\_verified) | Confirmation that immutability is enforced |
| <a name="output_task_definition_arn"></a> [task\_definition\_arn](#output\_task\_definition\_arn) | ARN of the ECS task definition |
<!-- END_TF_DOCS -->
