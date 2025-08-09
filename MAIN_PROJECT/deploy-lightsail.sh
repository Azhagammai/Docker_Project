#!/bin/bash

# AWS Lightsail Deployment Script for Landing Page
# This script automates the deployment of a Docker container to AWS Lightsail

set -e

# Configuration
INSTANCE_NAME="landing-page-server"
BLUEPRINT_ID="ubuntu_22_04"
BUNDLE_ID="nano_2_0"  # $3.50/month - adjust as needed
AVAILABILITY_ZONE="us-east-1a"  # Change to your preferred region
KEY_PAIR_NAME="landing-page-key"
STATIC_IP_NAME="landing-page-static-ip"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Starting AWS Lightsail deployment...${NC}"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI is not installed. Please install it first.${NC}"
    echo "Visit: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ AWS CLI is not configured. Please run 'aws configure' first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ AWS CLI is configured${NC}"

# Create key pair if it doesn't exist
echo -e "${YELLOW}🔑 Creating key pair...${NC}"
if ! aws lightsail get-key-pair --key-pair-name $KEY_PAIR_NAME &> /dev/null; then
    aws lightsail create-key-pair --key-pair-name $KEY_PAIR_NAME --query 'privateKeyBase64' --output text > ${KEY_PAIR_NAME}.pem
    chmod 600 ${KEY_PAIR_NAME}.pem
    echo -e "${GREEN}✅ Key pair created: ${KEY_PAIR_NAME}.pem${NC}"
else
    echo -e "${YELLOW}⚠️  Key pair already exists${NC}"
fi

# Create Lightsail instance
echo -e "${YELLOW}🖥️  Creating Lightsail instance...${NC}"
if ! aws lightsail get-instance --instance-name $INSTANCE_NAME &> /dev/null; then
    aws lightsail create-instances \
        --instance-names $INSTANCE_NAME \
        --availability-zone $AVAILABILITY_ZONE \
        --blueprint-id $BLUEPRINT_ID \
        --bundle-id $BUNDLE_ID \
        --key-pair-name $KEY_PAIR_NAME \
        --user-data file://user-data.sh
    
    echo -e "${GREEN}✅ Instance created: $INSTANCE_NAME${NC}"
    echo -e "${YELLOW}⏳ Waiting for instance to be running...${NC}"
    
    # Wait for instance to be running
    while true; do
        STATE=$(aws lightsail get-instance --instance-name $INSTANCE_NAME --query 'instance.state.name' --output text)
        if [ "$STATE" = "running" ]; then
            break
        fi
        echo -e "${YELLOW}⏳ Instance state: $STATE. Waiting...${NC}"
        sleep 10
    done
    
    echo -e "${GREEN}✅ Instance is running${NC}"
else
    echo -e "${YELLOW}⚠️  Instance already exists${NC}"
fi

# Create and attach static IP
echo -e "${YELLOW}🌐 Creating static IP...${NC}"
if ! aws lightsail get-static-ip --static-ip-name $STATIC_IP_NAME &> /dev/null; then
    aws lightsail allocate-static-ip --static-ip-name $STATIC_IP_NAME
    echo -e "${GREEN}✅ Static IP created${NC}"
else
    echo -e "${YELLOW}⚠️  Static IP already exists${NC}"
fi

# Attach static IP to instance
echo -e "${YELLOW}🔗 Attaching static IP to instance...${NC}"
aws lightsail attach-static-ip --static-ip-name $STATIC_IP_NAME --instance-name $INSTANCE_NAME
echo -e "${GREEN}✅ Static IP attached${NC}"

# Open firewall ports
echo -e "${YELLOW}🔥 Configuring firewall...${NC}"
aws lightsail open-instance-public-ports \
    --instance-name $INSTANCE_NAME \
    --port-info fromPort=80,toPort=80,protocol=TCP
    
aws lightsail open-instance-public-ports \
    --instance-name $INSTANCE_NAME \
    --port-info fromPort=443,toPort=443,protocol=TCP

echo -e "${GREEN}✅ Firewall configured${NC}"

# Get the static IP address
STATIC_IP=$(aws lightsail get-static-ip --static-ip-name $STATIC_IP_NAME --query 'staticIp.ipAddress' --output text)

echo -e "${GREEN}🎉 Deployment completed!${NC}"
echo -e "${GREEN}📍 Your landing page will be available at: http://$STATIC_IP${NC}"
echo -e "${YELLOW}⏳ Please wait 2-3 minutes for the application to fully start${NC}"
echo -e "${GREEN}🔑 SSH access: ssh -i ${KEY_PAIR_NAME}.pem ubuntu@$STATIC_IP${NC}"

# Optional: Upload files to the server
read -p "Do you want to upload the application files now? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}📤 Uploading application files...${NC}"
    
    # Wait a bit more for SSH to be ready
    echo -e "${YELLOW}⏳ Waiting for SSH to be ready...${NC}"
    sleep 30
    
    # Create deployment directory on server
    ssh -i ${KEY_PAIR_NAME}.pem -o StrictHostKeyChecking=no ubuntu@$STATIC_IP "mkdir -p ~/landing-page"
    
    # Upload files
    scp -i ${KEY_PAIR_NAME}.pem -o StrictHostKeyChecking=no \
        index.html styles.css script.js Dockerfile docker-compose.yml nginx.conf .dockerignore \
        ubuntu@$STATIC_IP:~/landing-page/
    
    # Deploy the application
    ssh -i ${KEY_PAIR_NAME}.pem -o StrictHostKeyChecking=no ubuntu@$STATIC_IP << 'EOF'
        cd ~/landing-page
        sudo docker-compose down || true
        sudo docker-compose build
        sudo docker-compose up -d
        echo "Application deployed successfully!"
EOF
    
    echo -e "${GREEN}✅ Application files uploaded and deployed${NC}"
    echo -e "${GREEN}🌐 Your landing page is now live at: http://$STATIC_IP${NC}"
fi

echo -e "${GREEN}📋 Deployment Summary:${NC}"
echo -e "Instance Name: $INSTANCE_NAME"
echo -e "Static IP: $STATIC_IP"
echo -e "SSH Key: ${KEY_PAIR_NAME}.pem"
echo -e "URL: http://$STATIC_IP"
