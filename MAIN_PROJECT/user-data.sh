#!/bin/bash

# User data script for AWS Lightsail instance
# This script runs when the instance first starts up

# Update system
apt-get update -y
apt-get upgrade -y

# Install Docker
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up the stable repository
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Add ubuntu user to docker group
usermod -aG docker ubuntu

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Install additional useful tools
apt-get install -y htop curl wget unzip git nano

# Install AWS CLI (optional, for future management)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Create application directory
mkdir -p /home/ubuntu/landing-page
chown ubuntu:ubuntu /home/ubuntu/landing-page

# Install nginx (as backup web server)
apt-get install -y nginx

# Configure nginx as reverse proxy (optional)
cat > /etc/nginx/sites-available/landing-page << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Enable the site
ln -sf /etc/nginx/sites-available/landing-page /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
nginx -t

# Start nginx
systemctl start nginx
systemctl enable nginx

# Create a simple health check script
cat > /home/ubuntu/health-check.sh << 'EOF'
#!/bin/bash
# Simple health check script

echo "=== System Health Check ==="
echo "Date: $(date)"
echo "Uptime: $(uptime)"
echo "Disk Usage:"
df -h
echo "Memory Usage:"
free -h
echo "Docker Status:"
systemctl status docker --no-pager
echo "Docker Containers:"
docker ps
echo "Nginx Status:"
systemctl status nginx --no-pager
echo "=========================="
EOF

chmod +x /home/ubuntu/health-check.sh
chown ubuntu:ubuntu /home/ubuntu/health-check.sh

# Create a deployment script for easy updates
cat > /home/ubuntu/deploy.sh << 'EOF'
#!/bin/bash
# Deployment script for landing page updates

cd /home/ubuntu/landing-page

echo "Stopping existing containers..."
sudo docker-compose down || true

echo "Building new image..."
sudo docker-compose build

echo "Starting containers..."
sudo docker-compose up -d

echo "Checking container status..."
sudo docker-compose ps

echo "Deployment completed!"
echo "Application should be available at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
EOF

chmod +x /home/ubuntu/deploy.sh
chown ubuntu:ubuntu /home/ubuntu/deploy.sh

# Set up log rotation for Docker
cat > /etc/logrotate.d/docker << 'EOF'
/var/lib/docker/containers/*/*.log {
    rotate 7
    daily
    compress
    size=1M
    missingok
    delaycompress
    copytruncate
}
EOF

# Create a simple monitoring script
cat > /home/ubuntu/monitor.sh << 'EOF'
#!/bin/bash
# Simple monitoring script

while true; do
    # Check if Docker container is running
    if ! docker ps | grep -q landing-page-app; then
        echo "$(date): Landing page container is not running. Attempting to restart..."
        cd /home/ubuntu/landing-page
        sudo docker-compose up -d
    fi
    
    # Check if nginx is running
    if ! systemctl is-active --quiet nginx; then
        echo "$(date): Nginx is not running. Attempting to restart..."
        sudo systemctl start nginx
    fi
    
    sleep 60
done
EOF

chmod +x /home/ubuntu/monitor.sh
chown ubuntu:ubuntu /home/ubuntu/monitor.sh

# Create systemd service for monitoring
cat > /etc/systemd/system/landing-page-monitor.service << 'EOF'
[Unit]
Description=Landing Page Monitor
After=docker.service

[Service]
Type=simple
User=ubuntu
ExecStart=/home/ubuntu/monitor.sh
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable the monitoring service
systemctl daemon-reload
systemctl enable landing-page-monitor.service

# Log the completion
echo "$(date): User data script completed successfully" >> /var/log/user-data.log

# Reboot to ensure all changes take effect
# reboot
