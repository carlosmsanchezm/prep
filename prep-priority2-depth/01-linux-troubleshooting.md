# Linux Troubleshooting Cheatsheet — Memorize This

> **Anduril runs RHEL bare-metal.** Andrew's interview was literally: "web app is down on a single host, troubleshoot it." Know these commands cold.

## The Troubleshooting Flow (memorize this order)

```
1. Is the service running?      → systemctl status / ps aux
2. What do the logs say?        → journalctl / tail logs
3. Is the host healthy?         → top / free / df
4. Is the network reachable?    → ping / curl / ss
5. Is the firewall blocking?    → firewall-cmd / iptables
6. Any recent changes?          → last / rpm -qa --last / git log
```

## Service Management (systemd)

```bash
# Check if service is running
systemctl status nginx
systemctl is-active nginx          # just "active" or "inactive"
systemctl is-enabled nginx         # starts on boot?

# Start / Stop / Restart
systemctl start nginx
systemctl stop nginx
systemctl restart nginx
systemctl reload nginx             # graceful reload (no downtime)

# Enable on boot
systemctl enable nginx
systemctl enable --now nginx       # enable AND start

# List all services
systemctl list-units --type=service
systemctl list-units --type=service --state=failed    # just failed ones

# Daemon reload (after editing unit files)
systemctl daemon-reload
```

## Logs (journalctl)

```bash
# Service logs
journalctl -u nginx                        # all nginx logs
journalctl -u nginx -n 50                  # last 50 lines
journalctl -u nginx -f                     # follow (like tail -f)
journalctl -u nginx --since "1 hour ago"   # time filter
journalctl -u nginx --since today          # today only
journalctl -u nginx -p err                 # only errors

# System-wide
journalctl -b                              # current boot
journalctl -b -1                           # previous boot
journalctl --disk-usage                    # how much space logs take

# Kernel messages
dmesg                                      # kernel ring buffer
dmesg -T                                   # with human-readable timestamps
dmesg | tail -20                           # recent kernel messages

# Traditional log files
tail -f /var/log/messages                  # RHEL system log
tail -f /var/log/secure                    # auth/SSH logs
tail -f /var/log/nginx/error.log           # app-specific
```

## Resource Monitoring

```bash
# CPU and memory — live view
top                                        # interactive (q to quit)
htop                                       # better UI (if installed)

# Memory
free -h                                    # human-readable
# Look for: available (not just free — available includes cache)

# Disk
df -h                                      # filesystem usage
df -h /                                    # just root
du -sh /var/log/*                          # what's eating disk
lsblk                                      # block devices

# CPU info
nproc                                      # number of CPUs
uptime                                     # load averages
# Load > nproc = overloaded

# Processes
ps aux                                     # all processes
ps aux | grep nginx                        # find specific
ps aux --sort=-%mem | head -10             # top memory consumers
ps aux --sort=-%cpu | head -10             # top CPU consumers

# IO
iostat -x 1                                # disk IO per second
iotop                                      # like top but for disk IO

# Open files
lsof -i :80                                # what's using port 80
lsof -p $(pgrep nginx)                     # files opened by nginx
```

## Network Troubleshooting

```bash
# Is the host reachable?
ping -c 3 10.0.1.50                        # 3 pings
ping -c 3 hostname.local                   # test DNS too

# Is the port open?
ss -tlnp                                   # TCP listening ports + process
ss -tlnp | grep 80                         # is port 80 listening?
# -t = TCP, -l = listening, -n = numeric, -p = process

# Test remote port
nc -zv 10.0.1.50 80                        # is port 80 open on remote?
curl -v http://10.0.1.50                   # HTTP test
curl -vk https://10.0.1.50                 # HTTPS (skip cert verify)

# What's my IP?
ip addr                                    # all interfaces
ip addr show eth0                          # specific interface
hostname -I                                # just IPs

# Routing
ip route                                   # routing table
ip route get 10.0.1.50                     # which route for this IP?
traceroute 10.0.1.50                       # trace path

# DNS
dig hostname.local                         # full DNS query
nslookup hostname.local                    # simple lookup
cat /etc/resolv.conf                       # DNS config

# ARP (local network)
ip neigh                                   # ARP table
arping -I eth0 10.0.1.50                   # ARP ping
```

## Firewall (RHEL uses firewalld)

```bash
# Status
firewall-cmd --state                       # running?
firewall-cmd --list-all                    # all rules

# Open ports
firewall-cmd --add-port=80/tcp --permanent
firewall-cmd --add-port=443/tcp --permanent
firewall-cmd --reload

# Open service
firewall-cmd --add-service=http --permanent
firewall-cmd --add-service=https --permanent
firewall-cmd --reload

# Rich rules (specific source)
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.0.1.0/24" port protocol="tcp" port="8080" accept'

# Remove rules
firewall-cmd --remove-port=80/tcp --permanent
firewall-cmd --reload

# Zones
firewall-cmd --get-active-zones
firewall-cmd --zone=public --list-all
```

## Package Management (RHEL)

```bash
# Install
dnf install nginx                          # RHEL 8+
yum install nginx                          # RHEL 7

# Search
dnf search podman
dnf info podman                            # details

# Update
dnf update                                 # all packages
dnf update nginx                           # specific

# List installed
rpm -qa                                    # all packages
rpm -qa --last | head -20                  # recently installed (good for "what changed?")
rpm -qi nginx                              # package info

# Check what package owns a file
rpm -qf /usr/bin/podman
```

## User & Permission Management

```bash
# Who am I?
whoami
id                                         # UID, GID, groups

# Switch user
su - username
sudo -i                                    # root shell

# Check sudo access
sudo -l                                    # what can I sudo?

# File permissions
ls -la /etc/nginx/
chmod 644 file                             # rw-r--r--
chmod 755 dir                              # rwxr-xr-x
chown nginx:nginx /var/www/html

# SELinux (RHEL enforces this!)
getenforce                                 # Enforcing, Permissive, Disabled
sestatus                                   # detailed status
ls -Z /var/www/html                        # SELinux context on files
# If "Permission denied" but file perms look fine → probably SELinux
# Quick test: setenforce 0 (temporarily disable) — if it works, SELinux was blocking
# Fix: restorecon -Rv /path/to/files (restore correct context)
```

## SELinux Troubleshooting (CRITICAL for RHEL)

```bash
# Check if SELinux is blocking something
ausearch -m AVC -ts recent                 # recent denials
sealert -a /var/log/audit/audit.log        # human-readable analysis

# Common fix: restore file context
restorecon -Rv /var/www/html

# Allow a service to do something (boolean)
getsebool -a | grep httpd                  # list httpd booleans
setsebool -P httpd_can_network_connect on  # allow Nginx to make outbound connections

# If container volume mount fails (Podman + SELinux):
# Add :Z to the volume mount in podman run or compose
```

## The "Web App Down" Troubleshooting Script (Andrew's exact scenario)

```bash
# 1. Is the service running?
systemctl status nginx

# 2. If dead, check logs
journalctl -u nginx -n 50

# 3. If running but not responding, check port
ss -tlnp | grep 80

# 4. Check resources
free -h                    # memory
df -h /                    # disk
top -bn1 | head -15        # CPU snapshot

# 5. Check firewall
firewall-cmd --list-all | grep 80

# 6. Check from outside
curl -v http://server-ip

# 7. Check DNS (if by hostname)
dig server-hostname

# 8. Recent changes?
rpm -qa --last | head -10
last -10                   # recent logins
```
