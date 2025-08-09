# AWS Lightsail Deployment Script for Landing Page (PowerShell)
# This script automates the deployment of a Docker container to AWS Lightsail

param(
    [string]$InstanceName = "landing-page-server",
    [string]$BundleId = "nano_2_0",
    [string]$AvailabilityZone = "us-east-1a",
    [string]$KeyPairName = "landing-page-key",
    [string]$StaticIpName = "landing-page-static-ip"
)

# Colors for output
$Green = "Green"
$Red = "Red"
$Yellow = "Yellow"

Write-Host "🚀 Starting AWS Lightsail deployment..." -ForegroundColor $Green

# Check if AWS CLI is installed
try {
    $awsVersion = aws --version
    Write-Host "✅ AWS CLI is installed: $awsVersion" -ForegroundColor $Green
} catch {
    Write-Host "❌ AWS CLI is not installed. Please install it first." -ForegroundColor $Red
    Write-Host "Visit: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
}

# Check if AWS CLI is configured
try {
    $identity = aws sts get-caller-identity 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "AWS CLI not configured"
    }
    Write-Host "✅ AWS CLI is configured" -ForegroundColor $Green
} catch {
    Write-Host "❌ AWS CLI is not configured. Please run 'aws configure' first." -ForegroundColor $Red
    exit 1
}

# Create key pair if it doesn't exist
Write-Host "🔑 Creating key pair..." -ForegroundColor $Yellow
try {
    aws lightsail get-key-pair --key-pair-name $KeyPairName 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        $privateKey = aws lightsail create-key-pair --key-pair-name $KeyPairName --query 'privateKeyBase64' --output text
        $privateKey | Out-File -FilePath "$KeyPairName.pem" -Encoding ASCII
        Write-Host "✅ Key pair created: $KeyPairName.pem" -ForegroundColor $Green
    } else {
        Write-Host "⚠️  Key pair already exists" -ForegroundColor $Yellow
    }
} catch {
    Write-Host "❌ Failed to create key pair" -ForegroundColor $Red
    exit 1
}

# Create Lightsail instance
Write-Host "🖥️  Creating Lightsail instance..." -ForegroundColor $Yellow
try {
    aws lightsail get-instance --instance-name $InstanceName 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        aws lightsail create-instances `
            --instance-names $InstanceName `
            --availability-zone $AvailabilityZone `
            --blueprint-id "ubuntu_22_04" `
            --bundle-id $BundleId `
            --key-pair-name $KeyPairName `
            --user-data file://user-data.sh
        
        Write-Host "✅ Instance created: $InstanceName" -ForegroundColor $Green
        Write-Host "⏳ Waiting for instance to be running..." -ForegroundColor $Yellow
        
        # Wait for instance to be running
        do {
            Start-Sleep -Seconds 10
            $state = aws lightsail get-instance --instance-name $InstanceName --query 'instance.state.name' --output text
            Write-Host "⏳ Instance state: $state. Waiting..." -ForegroundColor $Yellow
        } while ($state -ne "running")
        
        Write-Host "✅ Instance is running" -ForegroundColor $Green
    } else {
        Write-Host "⚠️  Instance already exists" -ForegroundColor $Yellow
    }
} catch {
    Write-Host "❌ Failed to create instance" -ForegroundColor $Red
    exit 1
}

# Create and attach static IP
Write-Host "🌐 Creating static IP..." -ForegroundColor $Yellow
try {
    aws lightsail get-static-ip --static-ip-name $StaticIpName 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        aws lightsail allocate-static-ip --static-ip-name $StaticIpName
        Write-Host "✅ Static IP created" -ForegroundColor $Green
    } else {
        Write-Host "⚠️  Static IP already exists" -ForegroundColor $Yellow
    }
} catch {
    Write-Host "❌ Failed to create static IP" -ForegroundColor $Red
    exit 1
}

# Attach static IP to instance
Write-Host "🔗 Attaching static IP to instance..." -ForegroundColor $Yellow
try {
    aws lightsail attach-static-ip --static-ip-name $StaticIpName --instance-name $InstanceName
    Write-Host "✅ Static IP attached" -ForegroundColor $Green
} catch {
    Write-Host "❌ Failed to attach static IP" -ForegroundColor $Red
    exit 1
}

# Open firewall ports
Write-Host "🔥 Configuring firewall..." -ForegroundColor $Yellow
try {
    aws lightsail open-instance-public-ports `
        --instance-name $InstanceName `
        --port-info fromPort=80,toPort=80,protocol=TCP
        
    aws lightsail open-instance-public-ports `
        --instance-name $InstanceName `
        --port-info fromPort=443,toPort=443,protocol=TCP

    Write-Host "✅ Firewall configured" -ForegroundColor $Green
} catch {
    Write-Host "❌ Failed to configure firewall" -ForegroundColor $Red
    exit 1
}

# Get the static IP address
$staticIp = aws lightsail get-static-ip --static-ip-name $StaticIpName --query 'staticIp.ipAddress' --output text

Write-Host "🎉 Deployment completed!" -ForegroundColor $Green
Write-Host "📍 Your landing page will be available at: http://$staticIp" -ForegroundColor $Green
Write-Host "⏳ Please wait 2-3 minutes for the application to fully start" -ForegroundColor $Yellow
Write-Host "🔑 SSH access: ssh -i $KeyPairName.pem ubuntu@$staticIp" -ForegroundColor $Green

# Optional: Upload files to the server
$upload = Read-Host "Do you want to upload the application files now? (y/n)"
if ($upload -eq "y" -or $upload -eq "Y") {
    Write-Host "📤 Uploading application files..." -ForegroundColor $Yellow
    
    # Check if SSH client is available
    try {
        ssh -V 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "SSH not available"
        }
    } catch {
        Write-Host "❌ SSH client not found. Please install OpenSSH or use WSL." -ForegroundColor $Red
        Write-Host "You can manually upload files using WinSCP or similar tools." -ForegroundColor $Yellow
        Write-Host "Server IP: $staticIp" -ForegroundColor $Green
        Write-Host "Username: ubuntu" -ForegroundColor $Green
        Write-Host "Key file: $KeyPairName.pem" -ForegroundColor $Green
        exit 0
    }
    
    # Wait a bit more for SSH to be ready
    Write-Host "⏳ Waiting for SSH to be ready..." -ForegroundColor $Yellow
    Start-Sleep -Seconds 30
    
    try {
        # Create deployment directory on server
        ssh -i "$KeyPairName.pem" -o StrictHostKeyChecking=no ubuntu@$staticIp "mkdir -p ~/landing-page"
        
        # Upload files
        scp -i "$KeyPairName.pem" -o StrictHostKeyChecking=no `
            index.html, styles.css, script.js, Dockerfile, docker-compose.yml, nginx.conf, .dockerignore `
            ubuntu@${staticIp}:~/landing-page/
        
        # Deploy the application
        $deployCommands = @"
cd ~/landing-page
sudo docker-compose down || true
sudo docker-compose build
sudo docker-compose up -d
echo "Application deployed successfully!"
"@
        
        ssh -i "$KeyPairName.pem" -o StrictHostKeyChecking=no ubuntu@$staticIp $deployCommands
        
        Write-Host "✅ Application files uploaded and deployed" -ForegroundColor $Green
        Write-Host "🌐 Your landing page is now live at: http://$staticIp" -ForegroundColor $Green
    } catch {
        Write-Host "❌ Failed to upload files. You can upload them manually." -ForegroundColor $Red
        Write-Host "Use WinSCP or similar tools to upload to: ubuntu@$staticIp" -ForegroundColor $Yellow
    }
}

Write-Host "📋 Deployment Summary:" -ForegroundColor $Green
Write-Host "Instance Name: $InstanceName"
Write-Host "Static IP: $staticIp"
Write-Host "SSH Key: $KeyPairName.pem"
Write-Host "URL: http://$staticIp"

# Create a summary file
$summary = @"
AWS Lightsail Deployment Summary
================================
Instance Name: $InstanceName
Static IP: $staticIp
SSH Key: $KeyPairName.pem
URL: http://$staticIp
SSH Command: ssh -i $KeyPairName.pem ubuntu@$staticIp

Deployment Date: $(Get-Date)
"@

$summary | Out-File -FilePath "deployment-summary.txt" -Encoding UTF8
Write-Host "📄 Deployment summary saved to: deployment-summary.txt" -ForegroundColor $Green
