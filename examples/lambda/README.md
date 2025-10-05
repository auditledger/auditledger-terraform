# Lambda Deployment Example

This example demonstrates how to deploy AuditLedger as an AWS Lambda function with S3 storage for audit logs.

## Architecture

```
API Gateway / EventBridge
    ↓
Lambda Function
├── Execution Role (from module) → S3 access
└── Writes to → S3 Bucket (audit logs)
```

## Features

- ✅ Serverless deployment (pay per invocation)
- ✅ S3 bucket with versioning and encryption
- ✅ IAM role with least-privilege S3 access
- ✅ Automatic lifecycle policies for cost optimization
- ✅ CloudWatch Logs integration

## Prerequisites

- AWS account with appropriate permissions
- Lambda deployment package (.zip file with your function)
- .NET 6 runtime support

## Usage

### 1. Build Your Lambda Package

```bash
# Build and package your .NET Lambda function
dotnet publish -c Release -o publish/
cd publish
zip -r ../function.zip .
cd ..
```

### 2. Configure Variables

Create a `terraform.tfvars` file:

```hcl
aws_region         = "us-east-1"
environment        = "production"
lambda_zip_path    = "./function.zip"  # Path to your Lambda package
lambda_memory_size = 512               # MB
lambda_timeout     = 30                # seconds
retention_days     = 2555              # 7 years for HIPAA
```

### 3. Deploy

```bash
terraform init
terraform plan
terraform apply
```

### 4. Test Your Function

```bash
# Invoke the function
aws lambda invoke \
  --function-name <environment>-auditledger \
  --payload '{"test": "data"}' \
  response.json

# View the response
cat response.json

# Check logs
aws logs tail /aws/lambda/<environment>-auditledger --follow
```

## Configuration Options

### Lambda Runtime

Currently using .NET 6 (dotnet6):

```hcl
runtime = "dotnet6"
```

**Note:** AWS Lambda supports .NET 6, but .NET 8 support is coming soon. Update the runtime when available.

### Memory and Timeout

Lambda pricing is based on memory allocated and execution time:

```hcl
# Small workload (cheap)
lambda_memory_size = 256   # MB
lambda_timeout     = 10    # seconds

# Medium workload (balanced)
lambda_memory_size = 512   # MB
lambda_timeout     = 30    # seconds

# Large workload (higher cost)
lambda_memory_size = 1024  # MB
lambda_timeout     = 60    # seconds
```

**Tip:** More memory = more CPU power. Sometimes increasing memory reduces execution time and overall cost.

### S3 Bucket Configuration

The S3 bucket includes:
- Server-side encryption (AES256)
- Versioning enabled
- Public access blocked
- Lifecycle policies for cost optimization

## Outputs

| Name | Description |
|------|-------------|
| `function_name` | Lambda function name |
| `function_arn` | Lambda function ARN |
| `bucket_name` | S3 bucket for audit logs |
| `bucket_arn` | S3 bucket ARN |
| `iam_role_arn` | Lambda execution role ARN |

## Environment Variables

Your Lambda function automatically receives:

```json
{
  "AuditLedger__Storage__Provider": "AwsS3",
  "AuditLedger__Storage__AwsS3__BucketName": "<from-terraform>",
  "AuditLedger__Storage__AwsS3__Region": "us-east-1"
}
```

Example .NET Lambda handler:

```csharp
public class Function
{
    private readonly IAuditLedgerService _auditLedger;

    public Function()
    {
        var services = new ServiceCollection();

        services.AddAuditLedger(options =>
        {
            // Configuration automatically loaded from environment variables
            options.Storage.Provider = StorageProvider.AwsS3;
        });

        var serviceProvider = services.BuildServiceProvider();
        _auditLedger = serviceProvider.GetRequiredService<IAuditLedgerService>();
    }

    public async Task<APIGatewayProxyResponse> FunctionHandler(
        APIGatewayProxyRequest request,
        ILambdaContext context)
    {
        // Log audit event
        await _auditLedger.LogEventAsync(new AuditEvent
        {
            EventType = "api.request",
            UserId = request.RequestContext.Identity.User,
            // ... other fields
        });

        return new APIGatewayProxyResponse
        {
            StatusCode = 200,
            Body = JsonSerializer.Serialize(new { message = "Success" })
        };
    }
}
```

## Triggers

This example deploys the Lambda function without triggers. Add triggers based on your use case:

### API Gateway (REST API)

```hcl
resource "aws_api_gateway_rest_api" "api" {
  name = "${var.environment}-auditledger-api"
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auditledger.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}
```

### EventBridge (CloudWatch Events)

```hcl
resource "aws_cloudwatch_event_rule" "schedule" {
  name                = "${var.environment}-auditledger-schedule"
  description         = "Trigger Lambda on schedule"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.schedule.name
  target_id = "lambda"
  arn       = aws_lambda_function.auditledger.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auditledger.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule.arn
}
```

### SQS Queue

```hcl
resource "aws_sqs_queue" "events" {
  name = "${var.environment}-auditledger-events"
}

resource "aws_lambda_event_source_mapping" "sqs" {
  event_source_arn = aws_sqs_queue.events.arn
  function_name    = aws_lambda_function.auditledger.function_name
  batch_size       = 10
}
```

## Cost Estimate

**Monthly cost (us-east-1):**

| Resource | Usage | Cost |
|----------|-------|------|
| Lambda (512MB) | 1M requests, 1s avg | ~$4.17/month |
| S3 storage | 10GB | ~$0.23/month |
| S3 requests | 1M PUTs | ~$5/month |
| CloudWatch Logs | 1GB | ~$0.50/month |

**Total:** ~$10/month for 1 million requests

**Free tier:**
- 1 million free requests per month
- 400,000 GB-seconds of compute time per month

## Performance Optimization

### Cold Starts

Lambda cold starts can add latency. To reduce:

1. **Increase memory**: More memory = faster initialization
   ```hcl
   lambda_memory_size = 1024  # Faster cold starts
   ```

2. **Use Provisioned Concurrency** (additional cost):
   ```hcl
   resource "aws_lambda_provisioned_concurrency_config" "example" {
     function_name                     = aws_lambda_function.auditledger.function_name
     provisioned_concurrent_executions = 2
     qualifier                         = aws_lambda_function.auditledger.version
   }
   ```

3. **Keep functions warm** (scheduled invocations):
   ```hcl
   # EventBridge rule to ping Lambda every 5 minutes
   ```

### Timeout Configuration

Set timeout based on your workload:

```hcl
lambda_timeout = 30  # Default
lambda_timeout = 900 # Maximum (15 minutes)
```

**Tip:** Shorter timeouts fail faster and cost less if there's an error.

## Security Considerations

### VPC Configuration (Optional)

For accessing resources in a VPC:

```hcl
vpc_config {
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.lambda.id]
}
```

**Note:** VPC configuration can increase cold start time.

### Environment Variable Encryption

For sensitive configuration:

```hcl
kms_key_arn = aws_kms_key.lambda.arn

environment {
  variables = {
    SENSITIVE_VALUE = "encrypted-value"
  }
}
```

### Reserved Concurrency

Prevent runaway costs:

```hcl
reserved_concurrent_executions = 10  # Max 10 concurrent executions
```

## Monitoring

### CloudWatch Metrics

Lambda automatically provides:
- Invocations
- Duration
- Errors
- Throttles

### CloudWatch Alarms

```hcl
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.environment}-auditledger-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "60"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "Lambda function errors"

  dimensions = {
    FunctionName = aws_lambda_function.auditledger.function_name
  }
}
```

## Troubleshooting

### Function can't write to S3

Check IAM role:
```bash
terraform output iam_role_arn
aws iam get-role --role-name <role-name>
```

### Function times out

1. Increase timeout:
   ```hcl
   lambda_timeout = 60
   ```

2. Check function logs:
   ```bash
   aws logs tail /aws/lambda/<function-name> --follow
   ```

3. Increase memory (also increases CPU):
   ```hcl
   lambda_memory_size = 1024
   ```

### High costs

1. **Check invocation count**:
   ```bash
   aws cloudwatch get-metric-statistics \
     --namespace AWS/Lambda \
     --metric-name Invocations \
     --dimensions Name=FunctionName,Value=<function-name> \
     --start-time 2024-01-01T00:00:00Z \
     --end-time 2024-01-31T23:59:59Z \
     --period 86400 \
     --statistics Sum
   ```

2. **Set reserved concurrency** to limit costs:
   ```hcl
   reserved_concurrent_executions = 10
   ```

3. **Optimize function duration**: Faster execution = lower cost

## Production Hardening

For production deployments:

1. **Enable X-Ray tracing**:
   ```hcl
   tracing_config {
     mode = "Active"
   }
   ```

2. **Use versioning and aliases**:
   ```hcl
   publish = true  # Create version on each deploy
   ```

3. **Dead Letter Queue**:
   ```hcl
   dead_letter_config {
     target_arn = aws_sqs_queue.dlq.arn
   }
   ```

4. **Configure retries**:
   ```hcl
   resource "aws_lambda_function_event_invoke_config" "example" {
     function_name          = aws_lambda_function.auditledger.function_name
     maximum_retry_attempts = 2
   }
   ```

## Cleanup

```bash
terraform destroy
```

**Note:** S3 bucket must be empty before destruction:

```bash
aws s3 rm s3://<bucket-name> --recursive
terraform destroy
```

## Related Examples

- [EC2](../ec2/) - Traditional instance deployment
- [ECS Fargate](../ecs-fargate/) - Containerized deployment
- [Azure App Service](../azure-app-service/) - Azure alternative

## Additional Resources

- [AWS Lambda Developer Guide](https://docs.aws.amazon.com/lambda/latest/dg/)
- [Lambda Pricing Calculator](https://aws.amazon.com/lambda/pricing/)
- [.NET on AWS Lambda](https://docs.aws.amazon.com/lambda/latest/dg/lambda-csharp.html)
- [Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)

## License

MIT
