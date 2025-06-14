# Orange Pi 5 Setup Guide for Pi-LMS

This guide provides step-by-step instructions for setting up your Orange Pi 5 for Pi-LMS classroom deployment.

## 📋 Prerequisites

### Hardware Requirements

- **Orange Pi 5** with 8GB RAM (minimum 4GB)
- **128GB eMMC** or high-speed microSD card (Class 10 U3)
- **Gigabit Ethernet** connection
- **Wi-Fi 6** capability (built-in)
- **15W USB-C** power supply with backup power

### Network Requirements

- **Classroom router** with DHCP capability
- **Internet connection** (optional for AI features)
- **Static IP reservation** recommended

## 🔧 Initial Orange Pi 5 Setup

### Step 1: Install Ubuntu 22.04 LTS ARM64

```bash
# Download Ubuntu 22.04 LTS for Orange Pi 5
wget https://github.com/Joshua-Riek/ubuntu-rockchip/releases/download/v1.33/ubuntu-22.04.3-preinstalled-server-arm64-orangepi-5.img.xz

# Flash to eMMC/SD card using balenaEtcher or dd
# Insert storage into Orange Pi 5 and boot
```

### Step 2: Initial System Configuration

```bash
# Connect via SSH or direct terminal
ssh ubuntu@<orange-pi-ip>

# Update system packages
sudo apt update && sudo apt upgrade -y

# Install essential packages
sudo apt install -y curl wget git htop iotop net-tools

# Set timezone for your classroom
sudo timedatectl set-timezone Asia/Manila  # Adjust for your location

# Configure hostname
sudo hostnamectl set-hostname pi-lms-classroom-01
```

### Step 3: Network Configuration

#### Option A: Static IP Configuration (Recommended)

```bash
# Edit netplan configuration
sudo nano /etc/netplan/01-network-manager-all.yaml

# Add this configuration:
network:
  version: 2
  renderer: networkd
  ethernets:
    end0:  # Orange Pi 5 ethernet interface
      dhcp4: false
      addresses:
        - 192.168.1.100/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
          - 192.168.1.1

# Apply network configuration
sudo netplan apply
```

#### Option B: DHCP with Router Reservation

```bash
# Find MAC address
ip addr show end0 | grep ether

# Configure router DHCP reservation:
# MAC: <orange-pi-mac> → IP: 192.168.1.100
# Hostname: pilms.local
```

### Step 4: Install Docker and Docker Compose

```bash
# Install Docker using official script
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker ubuntu
newgrp docker

# Install Docker Compose plugin
sudo apt install -y docker-compose-plugin

# Verify installation
docker --version
docker compose version
```

### Step 5: Optimize Orange Pi 5 for Classroom Use

```bash
# Create optimization script
sudo nano /etc/systemd/system/pi-lms-optimize.service

# Add this content:
[Unit]
Description=Pi-LMS Orange Pi 5 Optimizations
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/pi-lms-optimize.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

```bash
# Create optimization script
sudo nano /usr/local/bin/pi-lms-optimize.sh

# Add this content:
#!/bin/bash

# GPU and memory optimizations
echo 'SUBSYSTEM=="mali", KERNEL=="mali*", MODE="0666", GROUP="video"' > /etc/udev/rules.d/50-mali.rules

# Memory management for 8GB system
echo 'vm.swappiness=10' >> /etc/sysctl.conf
echo 'vm.vfs_cache_pressure=50' >> /etc/sysctl.conf
echo 'vm.dirty_ratio=15' >> /etc/sysctl.conf
echo 'vm.dirty_background_ratio=5' >> /etc/sysctl.conf

# Network optimizations for classroom
echo 'net.core.rmem_max = 16777216' >> /etc/sysctl.conf
echo 'net.core.wmem_max = 16777216' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_rmem = 4096 87380 16777216' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_wmem = 4096 65536 16777216' >> /etc/sysctl.conf

# Apply settings
sysctl -p

# Make script executable
sudo chmod +x /usr/local/bin/pi-lms-optimize.sh

# Enable optimization service
sudo systemctl enable pi-lms-optimize.service
sudo systemctl start pi-lms-optimize.service
```

## 🚀 Pi-LMS Deployment

### Step 1: Transfer Project Files

#### Method A: Git Clone (Recommended)

```bash
# Clone from your repository
cd /opt
sudo mkdir pi-lms
sudo chown ubuntu:ubuntu pi-lms
git clone <your-repo-url> pi-lms
cd pi-lms
```

#### Method B: SCP Transfer from Windows

```bash
# From Windows PowerShell
scp -r D:\Files\Capstone\pi-lms\ ubuntu@192.168.1.100:/opt/pi-lms/
```

#### Method C: USB Transfer

```bash
# Mount USB drive
sudo mkdir /mnt/usb
sudo mount /dev/sda1 /mnt/usb

# Copy files
sudo cp -r /mnt/usb/pi-lms /opt/
sudo chown -R ubuntu:ubuntu /opt/pi-lms

# Unmount USB
sudo umount /mnt/usb
```

### Step 2: Configure Environment

```bash
cd /opt/pi-lms

# Copy production environment template
cp .env.production .env

# Edit environment file
nano .env

# Update these critical values:
# GEMINI_API_KEY=your-actual-api-key
# YOUTUBE_API_KEY=your-actual-api-key
# SESSION_SECRET=generate-secure-random-string
# PAYLOAD_SECRET=generate-secure-random-string
# JWT_SECRET=generate-secure-random-string
```

### Step 3: Deploy with Single Command

```bash
# Make deployment script executable
chmod +x deploy.sh

# Run deployment
./deploy.sh deploy

# The script will:
# ✅ Check system requirements
# ✅ Create directory structure
# ✅ Build Docker containers
# ✅ Start all services
# ✅ Initialize Ollama with 3B model
# ✅ Run health checks
# ✅ Display access information
```

## 🌐 Classroom Network Setup

### Router Configuration

```bash
# DHCP Settings
Start IP: 192.168.1.201
End IP: 192.168.1.250
Lease Time: 24 hours

# Static Reservations
Orange Pi 5: 192.168.1.100 (MAC: <pi-mac-address>)

# DNS Settings (Optional)
Local Domain: classroom.local
Custom DNS Entry: pilms.local → 192.168.1.100
```

### Wi-Fi Access Point Setup

```bash
# If using Orange Pi 5 as access point
sudo apt install -y hostapd dnsmasq

# Configure hostapd
sudo nano /etc/hostapd/hostapd.conf

# Add configuration:
interface=wlan0
driver=nl80211
ssid=Pi-LMS-Classroom
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=ClassroomLMS2024
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
```

## 📱 Student Device Configuration

### Android Tablets

```bash
# Network Settings
Wi-Fi: Pi-LMS-Classroom
Password: ClassroomLMS2024

# Browser Settings
Homepage: http://pilms.local
Bookmarks:
- Pi-LMS: http://pilms.local
- Health Check: http://pilms.local/health
```

### iOS Devices

```bash
# Wi-Fi Configuration Profile (optional)
# Create .mobileconfig file for easy setup

# Manual Setup
Wi-Fi: Pi-LMS-Classroom
DNS: 192.168.1.100
```

## 🔧 System Monitoring

### Real-time Monitoring

```bash
# System resources
htop

# Docker containers
docker stats

# Service logs
./deploy.sh logs

# Network connections
netstat -tulpn | grep :80
```

### Performance Optimization

```bash
# Monitor memory usage
free -h

# Check disk space
df -h

# Monitor network traffic
iftop

# Check temperature (if sensors available)
cat /sys/class/thermal/thermal_zone0/temp
```

## 🛠️ Maintenance Commands

### Daily Operations

```bash
# Check service status
./deploy.sh status

# View recent logs
./deploy.sh logs

# Restart specific service
docker compose restart frontend

# Health check
./deploy.sh health
```

### Weekly Maintenance

```bash
# Update containers
docker compose pull
docker compose up -d

# Clean up unused images
docker image prune -f

# Check disk usage
du -sh data/*
```

### Backup and Recovery

```bash
# Manual backup
./deploy.sh stop
tar -czf pi-lms-backup-$(date +%Y%m%d).tar.gz data/
./deploy.sh deploy

# Restore from backup
./deploy.sh stop
tar -xzf pi-lms-backup-YYYYMMDD.tar.gz
./deploy.sh deploy
```

## 🔍 Troubleshooting

### Common Issues

#### Services Won't Start

```bash
# Check Docker daemon
sudo systemctl status docker

# Check container logs
docker compose logs <service-name>

# Restart Docker
sudo systemctl restart docker
```

#### Network Issues

```bash
# Check network configuration
ip addr show
ip route show

# Test internal connectivity
docker compose exec frontend ping backend
```

#### Performance Issues

```bash
# Check resource usage
docker stats
free -h
iostat 1

# Optimize if needed
docker compose restart
```

#### Ollama Model Issues

```bash
# Re-download model
docker compose exec ollama ollama pull llama3.2:3b

# Check model status
docker compose exec ollama ollama list
```

## 📞 Support Information

### System Information

- **Orange Pi 5**: ARM64 architecture
- **Ubuntu**: 22.04 LTS
- **Docker**: Latest stable
- **Pi-LMS**: Containerized deployment

### Log Locations

- **Application logs**: `./data/logs/`
- **System logs**: `/var/log/`
- **Docker logs**: `docker compose logs`

### Contact Information

- **Technical Support**: [Your contact information]
- **Documentation**: [Your documentation URL]
- **Repository**: [Your repository URL]

---

This setup guide ensures your Orange Pi 5 is optimally configured for Pi-LMS classroom deployment with maximum performance and reliability.
