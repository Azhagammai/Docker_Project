# Modern Landing Page with Docker & AWS Lightsail

A responsive, modern landing page built with HTML, CSS, and JavaScript, containerized with Docker and ready for deployment on AWS Lightsail.

## 🌟 Features

- **Responsive Design**: Works perfectly on desktop, tablet, and mobile devices
- **Modern UI/UX**: Clean, professional design with smooth animations
- **Docker Ready**: Fully containerized for easy deployment
- **AWS Lightsail Compatible**: One-click deployment scripts included
- **Performance Optimized**: Nginx web server with gzip compression
- **SEO Friendly**: Semantic HTML structure and meta tags
- **Interactive Elements**: Smooth scrolling, form validation, and animations

## 📁 Project Structure

```
.
├── index.html              # Main HTML file
├── styles.css              # CSS styles and responsive design
├── script.js               # JavaScript functionality
├── Dockerfile              # Docker container configuration
├── docker-compose.yml      # Docker Compose for local development
├── nginx.conf              # Nginx web server configuration
├── user-data.sh            # AWS Lightsail instance setup script
├── deploy-lightsail.sh     # Linux/Mac deployment script
├── deploy-lightsail.ps1    # Windows PowerShell deployment script
├── .dockerignore           # Docker build exclusions
└── README.md               # This file
```

## 🚀 Quick Start

### Local Development

1. **Clone or download the project files**

2. **Option A: Run with Docker (Recommended)**
   ```bash
   # Build and run with Docker Compose
   docker-compose up -d
   
   # Access the site at http://localhost:8080
   ```

3. **Option B: Run directly**
   ```bash
   # Serve with any web server, for example:
   python -m http.server 8000
   # or
   npx serve .
   
   # Access the site at http://localhost:8000
   ```

### Stop the Application
```bash
docker-compose down
```

## ☁️ AWS Lightsail Deployment

### Prerequisites

1. **AWS Account**: Sign up at [aws.amazon.com](https://aws.amazon.com)
2. **AWS CLI**: Install from [AWS CLI Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
3. **Configure AWS CLI**:
   ```bash
   aws configure
   ```
   Enter your AWS Access Key ID, Secret Access Key, and preferred region.

### Deployment Options

#### Option 1: Linux/Mac Deployment
```bash
# Make the script executable
chmod +x deploy-lightsail.sh

# Run the deployment script
./deploy-lightsail.sh
```

#### Option 2: Windows PowerShell Deployment
```powershell
# Run the PowerShell script
.\deploy-lightsail.ps1
```

#### Option 3: Manual Deployment

1. **Create Lightsail Instance**:
   ```bash
   aws lightsail create-instances \
     --instance-names landing-page-server \
     --availability-zone us-east-1a \
     --blueprint-id ubuntu_22_04 \
     --bundle-id nano_2_0 \
     --user-data file://user-data.sh
   ```

2. **Create and Attach Static IP**:
   ```bash
   aws lightsail allocate-static-ip --static-ip-name landing-page-static-ip
   aws lightsail attach-static-ip --static-ip-name landing-page-static-ip --instance-name landing-page-server
   ```

3. **Open Firewall Ports**:
   ```bash
   aws lightsail open-instance-public-ports \
     --instance-name landing-page-server \
     --port-info fromPort=80,toPort=80,protocol=TCP
   ```

### Post-Deployment

1. **Get your server IP**:
   ```bash
   aws lightsail get-static-ip --static-ip-name landing-page-static-ip --query 'staticIp.ipAddress' --output text
   ```

2. **Access your site**: `http://YOUR_SERVER_IP`

3. **SSH into your server** (if needed):
   ```bash
   ssh -i landing-page-key.pem ubuntu@YOUR_SERVER_IP
   ```

## 🛠️ Customization

### Updating Content

1. **Edit the HTML**: Modify `index.html` to change content, structure, or add new sections
2. **Update Styles**: Customize `styles.css` to change colors, fonts, layout, or add new styles
3. **Add Functionality**: Extend `script.js` to add new interactive features

### Branding

- **Logo/Brand Name**: Update the navbar logo in `index.html`
- **Colors**: Modify the CSS color variables in `styles.css`
- **Content**: Replace placeholder text with your actual content
- **Images**: Add your own images and update references

### Configuration

- **Nginx Settings**: Modify `nginx.conf` for custom server configuration
- **Docker Settings**: Update `Dockerfile` or `docker-compose.yml` for container customization
- **AWS Settings**: Modify deployment scripts for different instance sizes or regions

## 📊 Monitoring & Maintenance

### Health Checks

The deployment includes automatic health monitoring:
- Docker container health checks
- Nginx status monitoring
- Automatic restart on failures

### Logs

- **Application Logs**: `docker-compose logs`
- **Nginx Logs**: `/var/log/nginx/`
- **System Logs**: `/var/log/`

### Updates

To update your deployed application:

1. **Update files locally**
2. **Upload to server**:
   ```bash
   scp -i landing-page-key.pem index.html styles.css script.js ubuntu@YOUR_SERVER_IP:~/landing-page/
   ```
3. **Redeploy**:
   ```bash
   ssh -i landing-page-key.pem ubuntu@YOUR_SERVER_IP "cd ~/landing-page && sudo docker-compose up -d --build"
   ```

## 💰 Cost Estimation

### AWS Lightsail Pricing (as of 2024)
- **Nano (512 MB RAM, 1 vCPU)**: $3.50/month
- **Micro (1 GB RAM, 1 vCPU)**: $5.00/month
- **Small (2 GB RAM, 1 vCPU)**: $10.00/month

### Additional Costs
- **Static IP**: Free with Lightsail instance
- **Data Transfer**: 1TB included with each plan
- **Backups**: $1/month per snapshot (optional)

## 🔧 Troubleshooting

### Common Issues

1. **Docker not starting**:
   ```bash
   sudo systemctl start docker
   sudo systemctl enable docker
   ```

2. **Port 80 already in use**:
   ```bash
   sudo netstat -tulpn | grep :80
   sudo systemctl stop apache2  # if Apache is running
   ```

3. **Permission denied**:
   ```bash
   sudo chown -R ubuntu:ubuntu ~/landing-page
   ```

4. **Container not accessible**:
   - Check firewall settings in AWS Lightsail console
   - Verify container is running: `docker ps`
   - Check nginx status: `sudo systemctl status nginx`

### Support

For issues or questions:
1. Check the AWS Lightsail documentation
2. Review Docker logs: `docker-compose logs`
3. Check system logs: `sudo journalctl -u docker`

## 🔍 Additional Tools

### Deployment Status Checker
```bash
# Check if your deployment is working
curl -I http://YOUR_SERVER_IP
```

### Performance Testing
```bash
# Test page load time
curl -w "@curl-format.txt" -o /dev/null -s http://YOUR_SERVER_IP
```

### SSL Certificate (Optional)
For HTTPS support, you can use Let's Encrypt:
```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com
```

## 📝 License

This project is open source and available under the [MIT License](LICENSE).

## 🤝 Contributing

Feel free to fork this project and submit pull requests for improvements!

---

**Happy Deploying! 🚀**
