#!/bin/bash
set -e

# Update system
yum update -y

# Install .NET Runtime
rpm -Uvh https://packages.microsoft.com/config/centos/7/packages-microsoft-prod.rpm
yum install -y dotnet-runtime-9.0

# Create application directory
mkdir -p /opt/auditledger
cd /opt/auditledger

# Configure AuditLedger (example appsettings.json)
cat > appsettings.Production.json << EOF
{
  "AuditLedger": {
    "Storage": {
      "Provider": "AwsS3",
      "AwsS3": {
        "BucketName": "${bucket_name}",
        "Region": "${region}"
      }
    }
  }
}
EOF

# Create systemd service
cat > /etc/systemd/system/auditledger.service << EOF
[Unit]
Description=AuditLedger Application
After=network.target

[Service]
Type=notify
WorkingDirectory=/opt/auditledger
ExecStart=/usr/bin/dotnet /opt/auditledger/AuditLedger.dll
Restart=always
RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=auditledger
User=www-data
Environment=ASPNETCORE_ENVIRONMENT=${environment}
Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false

[Install]
WantedBy=multi-user.target
EOF

# Enable and start service
systemctl enable auditledger.service
# systemctl start auditledger.service  # Uncomment when application is deployed

echo "AuditLedger setup complete"
