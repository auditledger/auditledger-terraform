# AWS Lambda Deployment Example (Python)

This example demonstrates how to deploy AuditLedger as an AWS Lambda function with Python runtime and S3 immutable storage for audit logs.

## Architecture

```
Lambda Function (Python 3.12)
├── IAM Role → S3 access
├── X-Ray Tracing enabled
├── CloudWatch Logs
└── S3 Bucket (immutable audit logs)

Optional: API Gateway → Lambda
```

## Features

- ✅ Serverless deployment with Python 3.12 (latest runtime)
- ✅ S3 bucket with Object Lock immutability
- ✅ X-Ray tracing for observability
- ✅ IAM roles with least-privilege access
- ✅ CloudWatch Logs integration
- ✅ Optional API Gateway HTTP endpoint
- ✅ Automatic lifecycle policies for cost optimization

## Prerequisites

- AWS account with appropriate permissions
- Python 3.12+ for local development
- Lambda deployment package (zip file with your code)

## Example Python Lambda Handler

Create a simple Python Lambda function that uses AuditLedger:

**`lambda_function.py`:**
```python
import json
import boto3
import os
from datetime import datetime

s3_client = boto3.client('s3')

def lambda_handler(event, context):
    """
    Example Lambda handler that writes audit logs to S3
    """
    bucket_name = os.environ['AUDITLEDGER_S3_BUCKET_NAME']

    # Create audit log entry
    audit_entry = {
        'timestamp': datetime.utcnow().isoformat(),
        'event': event,
        'context': {
            'function_name': context.function_name,
            'request_id': context.request_id
        }
    }

    # Write to S3 (immutable storage)
    key = f"audit-logs/{datetime.utcnow().date()}/{context.request_id}.json"

    s3_client.put_object(
        Bucket=bucket_name,
        Key=key,
        Body=json.dumps(audit_entry),
        ContentType='application/json'
    )

    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Audit log written',
            'log_key': key
        })
    }
```

**Package it:**
```bash
# Create deployment package
zip lambda.zip lambda_function.py

# Or with dependencies
pip install -r requirements.txt -t .
zip -r lambda.zip .
```

## Usage

### 1. Configure Variables

Create a `terraform.tfvars` file:

```hcl
aws_region       = "us-east-1"
environment      = "dev"
lambda_zip_path  = "./lambda.zip"  # Path to your deployment package
retention_days   = 2555             # 7 years for SOC 2
create_api_gateway = true           # Optional HTTP endpoint
```

### 2. Deploy

```bash
terraform init
terraform plan
terraform apply
```

### 3. Test Your Function

```bash
# Invoke directly
aws lambda invoke \
  --function-name dev-auditledger \
  --payload '{"test": "data"}' \
  response.json

# Or via API Gateway (if enabled)
curl -X POST https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/audit \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'
```

### 4. View Audit Logs

```bash
# List logs in S3
aws s3 ls s3://dev-auditledger-logs/audit-logs/ --recursive

# Download a specific log
aws s3 cp s3://dev-auditledger-logs/audit-logs/2024-01-15/abc-123.json .
```

## Configuration Options

### Memory and Timeout

Adjust based on your workload:

```hcl
lambda_memory_size = 1024  # MB (128-10240)
lambda_timeout     = 60    # seconds (1-900)
```

### Immutability Mode

```hcl
# For production - strictest protection
environment = "production"  # Uses COMPLIANCE mode

# For development - allows cleanup
environment = "dev"         # Uses GOVERNANCE mode
```

### API Gateway

```hcl
create_api_gateway = true  # Enables HTTP endpoint
```

## Monitoring

### CloudWatch Logs

```bash
# View logs
aws logs tail /aws/lambda/dev-auditledger --follow

# Filter errors
aws logs filter-pattern /aws/lambda/dev-auditledger --filter-pattern "ERROR"
```

### X-Ray Tracing

View traces in AWS Console:
- Navigate to X-Ray → Traces
- Filter by function name
- Analyze performance and errors

### Metrics

Key CloudWatch metrics:
- `Invocations` - Total function calls
- `Duration` - Execution time
- `Errors` - Failed invocations
- `Throttles` - Rate limit hits

## Cost Optimization

### Lambda Pricing

- **Requests**: $0.20 per 1M requests
- **Duration**: $0.0000166667 per GB-second

Example monthly cost (100K invocations):
- Requests: $0.02
- Duration (512MB, 500ms avg): $0.42
- **Total**: ~$0.44/month

### S3 Storage

Lifecycle policies automatically tier logs:
- 90 days: Hot → IA (46% savings)
- 180 days: IA → Glacier IR (71% savings)
- 365 days: Glacier IR → Glacier (83% savings)

## Security Best Practices

1. ✅ **Least Privilege IAM** - Lambda role has minimal S3 permissions
2. ✅ **Immutable Storage** - Object Lock prevents log tampering
3. ✅ **Encryption** - S3 encryption at rest (AES256/KMS)
4. ✅ **TLS in Transit** - All S3 API calls use HTTPS
5. ✅ **X-Ray Tracing** - Full observability of function execution
6. ✅ **CloudWatch Logs** - Centralized logging

## Cleanup

```bash
# Remove API Gateway first (if created)
terraform destroy -target=aws_apigatewayv2_api.auditledger

# Then destroy everything
terraform destroy
```

**⚠️ Note:** S3 bucket with COMPLIANCE mode cannot be destroyed until all objects pass retention period.

## Related Examples

- [EC2](../ec2/) - Traditional instance deployment
- [ECS Fargate](../ecs-fargate/) - Containerized deployment
- [Azure App Service](../azure-app-service/) - Azure alternative

## Additional Resources

- [AWS Lambda Python Runtime](https://docs.aws.amazon.com/lambda/latest/dg/lambda-python.html)
- [Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [Python boto3 S3 Documentation](https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/s3.html)

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
| [aws_apigatewayv2_api.auditledger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_api) | resource |
| [aws_apigatewayv2_integration.auditledger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_integration) | resource |
| [aws_apigatewayv2_route.auditledger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_route) | resource |
| [aws_apigatewayv2_stage.auditledger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/apigatewayv2_stage) | resource |
| [aws_cloudwatch_log_group.auditledger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role.auditledger_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.auditledger_s3_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.lambda_basic_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.lambda_xray](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.auditledger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.api_gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |

## Inputs

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region | `string` | `"us-east-1"` | no |
| <a name="input_create_api_gateway"></a> [create\_api\_gateway](#input\_create\_api\_gateway) | Whether to create API Gateway for HTTP access | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name | `string` | n/a | yes |
| <a name="input_lambda_memory_size"></a> [lambda\_memory\_size](#input\_lambda\_memory\_size) | Lambda memory size in MB | `number` | `512` | no |
| <a name="input_lambda_timeout"></a> [lambda\_timeout](#input\_lambda\_timeout) | Lambda timeout in seconds | `number` | `30` | no |
| <a name="input_lambda_zip_path"></a> [lambda\_zip\_path](#input\_lambda\_zip\_path) | Path to Lambda deployment package (Python .zip file) | `string` | n/a | yes |
| <a name="input_retention_days"></a> [retention\_days](#input\_retention\_days) | Number of days to retain audit logs (minimum 365 days for compliance) | `number` | `2555` | no |

## Outputs

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_gateway_endpoint"></a> [api\_gateway\_endpoint](#output\_api\_gateway\_endpoint) | API Gateway endpoint URL |
| <a name="output_bucket_arn"></a> [bucket\_arn](#output\_bucket\_arn) | ARN of the audit logs S3 bucket |
| <a name="output_bucket_id"></a> [bucket\_id](#output\_bucket\_id) | ID of the audit logs S3 bucket |
| <a name="output_immutability_verified"></a> [immutability\_verified](#output\_immutability\_verified) | Confirmation that immutability is enforced |
| <a name="output_lambda_function_arn"></a> [lambda\_function\_arn](#output\_lambda\_function\_arn) | ARN of the Lambda function |
| <a name="output_lambda_function_name"></a> [lambda\_function\_name](#output\_lambda\_function\_name) | Name of the Lambda function |
| <a name="output_lambda_role_arn"></a> [lambda\_role\_arn](#output\_lambda\_role\_arn) | ARN of the Lambda IAM role |
<!-- END_TF_DOCS -->
