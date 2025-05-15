#!/bin/bash
# User data script for financial application servers

# Configure CloudWatch agent
yum update -y
yum install -y amazon-cloudwatch-agent awslogs jq

# Set up CloudWatch logging
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/secure",
            "log_group_name": "/${environment}/var/log/secure",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/${environment}/var/log/messages",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/audit/audit.log",
            "log_group_name": "/${environment}/var/log/audit",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/application.log",
            "log_group_name": "/${environment}/application",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  },
  "metrics": {
    "metrics_collected": {
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_iowait",
          "cpu_usage_user",
          "cpu_usage_system"
        ],
        "metrics_collection_interval": 60,
        "totalcpu": false
      },
      "disk": {
        "measurement": [
          "used_percent",
          "inodes_free"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "diskio": {
        "measurement": [
          "io_time"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "mem": {
        "measurement": [
          "mem_used_percent"
        ],
        "metrics_collection_interval": 60
      },
      "swap": {
        "measurement": [
          "swap_used_percent"
        ],
        "metrics_collection_interval": 60
      }
    },
    "append_dimensions": {
      "AutoScalingGroupName": "$${aws:AutoScalingGroupName}",
      "ImageId": "$${aws:ImageId}",
      "InstanceId": "$${aws:InstanceId}",
      "InstanceType": "$${aws:InstanceType}"
    }
  }
}
EOF

# Start CloudWatch agent
systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Set up security hardening
# Update all packages
yum update -y

# Configure firewall
yum install -y iptables-services
systemctl enable iptables
systemctl start iptables

# Configure basic firewall rules
iptables -F
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -p tcp --dport ${app_port} -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
service iptables save

# Set up auditd rules
cat > /etc/audit/rules.d/audit.rules << 'EOF'
# Monitor file system mounts
-a always,exit -F arch=b64 -S mount -S umount2 -k mount

# Monitor changes to authentication configuration
-w /etc/pam.d/ -p wa -k pam
-w /etc/nsswitch.conf -p wa -k nsswitch
-w /etc/ssh/sshd_config -p wa -k sshd_config

# Monitor system user and group management
-w /etc/passwd -p wa -k passwd_changes
-w /etc/shadow -p wa -k shadow_changes
-w /etc/group -p wa -k group_changes
-w /etc/sudoers -p wa -k sudoers

# Monitor network configuration changes
-w /etc/network/ -p wa -k network_changes
-w /etc/sysconfig/network -p wa -k network_changes

# Kernel module loading/unloading
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules

# Log all executed commands
-a exit,always -F arch=b64 -S execve -k exec
EOF

# Restart auditd
service auditd restart

# Create a sample application health check endpoint
mkdir -p /var/www/html
cat > /var/www/html/health << 'EOF'
OK
EOF

# Install application dependencies
yum install -y nodejs npm

# Create a sample application
mkdir -p /opt/application
cat > /opt/application/app.js << 'EOF'
const http = require('http');
const fs = require('fs');

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.statusCode = 200;
    res.setHeader('Content-Type', 'text/plain');
    res.end('OK');
    return;
  }
  
  res.statusCode = 200;
  res.setHeader('Content-Type', 'application/json');
  res.end(JSON.stringify({
    message: 'Financial Application API',
    environment: '${environment}',
    timestamp: new Date().toISOString()
  }));
});

server.listen(${app_port}, () => {
  console.log(`Server running on port ${app_port}`);
  
  // Log startup to application log
  fs.appendFileSync('/var/log/application.log', 
    `[${new Date().toISOString()}] Application started on port ${app_port}\n`);
});

// Create an application log file if it doesn't exist
if (!fs.existsSync('/var/log/application.log')) {
  fs.writeFileSync('/var/log/application.log', 
    `[${new Date().toISOString()}] Application log initialized\n`);
}
EOF

# Create a service for the application
cat > /etc/systemd/system/financial-app.service << 'EOF'
[Unit]
Description=Financial Application Service
After=network.target

[Service]
Type=simple
User=nobody
WorkingDirectory=/opt/application
ExecStart=/usr/bin/node /opt/application/app.js
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=financial-app
Environment=NODE_ENV=${environment}

[Install]
WantedBy=multi-user.target
EOF

# Start the application
systemctl enable financial-app
systemctl start financial-app

# Tag the instance (useful for finding it in logs)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=${region}

# Use IMDSv2 token for metadata access
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

aws ec2 create-tags \
  --resources $INSTANCE_ID \
  --tags Key=Name,Value=${environment}-financial-app Key=Environment,Value=${environment} \
  --region $REGION

echo "Instance configuration complete!"