# Networking Debug Cheatsheet — Memorize This

## DNS

```bash
# Quick lookup
dig example.com +short                   # A record
dig example.com MX +short                # MX record
dig @8.8.8.8 example.com                 # use specific DNS server
dig example.com +trace                   # trace full resolution path

# nslookup
nslookup example.com
nslookup example.com 10.0.0.2            # use specific DNS server

# host (simple)
host example.com

# Check DNS config
cat /etc/resolv.conf                     # nameservers and search domains

# From inside a K8s pod
kubectl exec debug-pod -- nslookup my-service
kubectl exec debug-pod -- nslookup my-service.my-namespace.svc.cluster.local
# K8s DNS format: <service>.<namespace>.svc.cluster.local
```

## HTTP / Connectivity

```bash
# curl (verbose shows TLS, headers, etc.)
curl -v https://example.com              # verbose output
curl -vk https://example.com             # verbose + skip TLS verify
curl -o /dev/null -s -w "%{http_code}" https://example.com  # just status code
curl -H "Authorization: Bearer $TOKEN" https://api.example.com/v1/resource
curl --connect-timeout 5 --max-time 10 https://example.com

# wget
wget -q -O - https://example.com        # quiet, output to stdout

# Test TCP connectivity (no HTTP)
nc -zv hostname 443                      # netcat: check if port is open
timeout 3 bash -c '</dev/tcp/hostname/443 && echo open || echo closed'
```

## Connections & Ports

```bash
# What's listening on what port
ss -tlnp                                 # TCP listening ports with process names
ss -ulnp                                 # UDP listening ports
netstat -tlnp                            # same (older tool)

# All connections
ss -tn                                   # all TCP connections
ss -tn state established                 # only established

# Filter by port
ss -tlnp sport = :6443                   # what's listening on 6443
ss -tn dport = :443                      # connections to port 443
```

## IP / Routes

```bash
# IP addresses
ip addr                                  # all interfaces + IPs
ip addr show eth0                        # specific interface
hostname -I                              # just IPs, no interface info

# Routes
ip route                                 # routing table
ip route get 10.0.1.50                   # which route would be used for this IP

# Links
ip link                                  # interface status (UP/DOWN)
ip link set eth0 up                      # bring interface up

# ARP
ip neigh                                 # ARP table (MAC addresses)
```

## Firewall (iptables)

```bash
# View rules
iptables -L -n -v                        # all rules, numeric, with counters
iptables -L INPUT -n -v                  # just INPUT chain
iptables -t nat -L -n -v                 # NAT table (K8s service routing lives here)

# Add rules
iptables -A INPUT -p tcp --dport 6443 -j ACCEPT       # allow incoming on 6443
iptables -A INPUT -s 10.0.1.0/24 -j ACCEPT            # allow from subnet
iptables -A INPUT -p tcp --dport 22 -j DROP            # block SSH
iptables -A OUTPUT -d 0.0.0.0/0 -j DROP               # block all outbound

# Delete rules
iptables -D INPUT -p tcp --dport 22 -j DROP            # delete specific rule
iptables -F                                            # flush all rules (CAREFUL)

# Save/restore
iptables-save > /etc/iptables/rules.v4
iptables-restore < /etc/iptables/rules.v4

# firewalld (RHEL/CentOS)
firewall-cmd --list-all                                # show all rules
firewall-cmd --add-port=6443/tcp --permanent           # open port
firewall-cmd --reload                                  # apply changes
```

## TLS / Certificates

```bash
# Check remote certificate
openssl s_client -connect hostname:443 </dev/null 2>/dev/null | openssl x509 -text -noout

# Quick check: expiry and subject
openssl s_client -connect hostname:443 </dev/null 2>/dev/null | openssl x509 -dates -subject -noout

# Check local cert file
openssl x509 -in cert.pem -text -noout

# Verify cert chain
openssl verify -CAfile ca.pem cert.pem

# Generate self-signed cert (for testing)
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes -subj "/CN=test"
```

## Packet Capture

```bash
# tcpdump
tcpdump -i eth0                          # all traffic on interface
tcpdump -i eth0 port 443                 # only port 443
tcpdump -i eth0 host 10.0.1.50           # only to/from specific host
tcpdump -i eth0 -w capture.pcap          # write to file (read with Wireshark)
tcpdump -i eth0 -n -c 100               # numeric (no DNS), capture 100 packets
tcpdump -i any port 6443                 # all interfaces, K8s API port
```

## K8s Network Debugging

```bash
# DNS from inside a pod
kubectl exec -it debug-pod -- nslookup my-service
kubectl exec -it debug-pod -- nslookup my-service.default.svc.cluster.local
kubectl exec -it debug-pod -- cat /etc/resolv.conf

# Connectivity from inside a pod
kubectl exec -it debug-pod -- curl -v http://my-service:8080
kubectl exec -it debug-pod -- wget -qO- http://my-service:8080
kubectl exec -it debug-pod -- nc -zv my-service 8080

# Check service → pod mapping
kubectl get svc my-service                    # shows selector
kubectl get endpoints my-service              # shows pod IPs that match
kubectl get pods -l app=my-app -o wide        # verify pods exist with matching labels

# Check network policies
kubectl get networkpolicy -n my-ns
kubectl describe networkpolicy my-policy -n my-ns

# CoreDNS status
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs -n kube-system -l k8s-app=kube-dns
```

## Packet Flow: Pod to External Service

```
1. Pod generates request (e.g., curl https://api.example.com)
2. Pod DNS lookup → CoreDNS (kube-system) → upstream DNS → IP
3. Packet leaves pod via veth pair → CNI bridge (Calico/Flannel)
4. kube-proxy / iptables NAT rules (if going to a Service ClusterIP)
5. Packet hits node NIC (eth0)
6. Node routing table → next hop (gateway/router)
7. If VPC: VPC route table → NAT Gateway (for internet) or TGW (for cross-VPC)
8. If firewall: Network Firewall inspects → allow/drop
9. If internet: IGW → public internet → destination
10. Response follows reverse path
```

## Reverse Proxy — What It Is and Why It Matters

> Taylor asked: "Could you describe what a reverse proxy is and what are some of the benefits?"

### What It Is

A reverse proxy sits **in front of backend servers** and handles all incoming client requests. The client talks to the proxy, the proxy talks to the backend. The client never talks directly to the backend.

```
WITHOUT reverse proxy:
  Client → Backend Server (exposed directly)

WITH reverse proxy:
  Client → Reverse Proxy → Backend Server(s) (hidden)
```

### Forward Proxy vs Reverse Proxy

```
FORWARD PROXY (protects clients):
  Client → Forward Proxy → Internet
  "Client hides behind the proxy"
  Example: corporate proxy, Squid — employees browse through it

REVERSE PROXY (protects servers):
  Internet → Reverse Proxy → Backend Servers
  "Servers hide behind the proxy"
  Example: Nginx, HAProxy, Envoy, Istio ingress gateway
```

### Benefits

| Benefit | How it works |
|---------|-------------|
| **Load balancing** | Distributes traffic across multiple backend servers (round-robin, least connections, IP hash) |
| **Security** | Hides internal server IPs and architecture from clients. Attacker sees the proxy, not your backends. |
| **TLS termination** | Proxy handles HTTPS (decrypt/encrypt). Backends can run plain HTTP internally — simpler cert management. |
| **Caching** | Proxy caches static content (images, CSS, JS). Backends handle fewer requests → better performance. |
| **Compression** | Proxy compresses responses (gzip/brotli) before sending to client → less bandwidth. |
| **Rate limiting** | Proxy can limit requests per IP — protects backends from abuse or DDoS. |
| **Centralized logging** | All traffic flows through one point — single place for access logs, metrics, auditing. |

### Real Examples

```bash
# Nginx as reverse proxy
# /etc/nginx/conf.d/myapp.conf
server {
    listen 443 ssl;
    server_name myapp.dev.internal;

    ssl_certificate /etc/nginx/certs/myapp.crt;
    ssl_certificate_key /etc/nginx/certs/myapp.key;

    location / {
        proxy_pass http://localhost:8080;    # forward to backend
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}

# HAProxy as load-balancing reverse proxy
# /etc/haproxy/haproxy.cfg
frontend web
    bind *:443 ssl crt /etc/haproxy/certs/myapp.pem
    default_backend app_servers

backend app_servers
    balance roundrobin
    server app1 10.0.1.10:8080 check
    server app2 10.0.1.11:8080 check
    server app3 10.0.1.12:8080 check
```

### In Kubernetes Context

```
Istio Ingress Gateway = reverse proxy for the cluster
  Client → Ingress Gateway (Envoy) → Service → Pod

K8s Ingress resource = reverse proxy config
  - Routes by hostname and path
  - TLS termination
  - Load balancing across pods
```

**How to explain:** "A reverse proxy sits in front of your backend servers and handles client requests. Benefits: load balancing across multiple servers, security by hiding internal architecture, TLS termination so backends don't manage certs, caching for performance, and centralized logging. In K8s, the Istio ingress gateway is essentially a reverse proxy for the cluster."

---

## Common Network Problems and Diagnosis

| Symptom | Likely Cause | Check With |
|---------|-------------|-----------|
| Pod can't resolve DNS | CoreDNS down or misconfigured | `kubectl get pods -n kube-system -l k8s-app=kube-dns` |
| Service has no endpoints | Pod labels don't match service selector | `kubectl get endpoints svc-name` |
| Connection refused | Target port wrong or app not listening | `kubectl exec -- ss -tlnp` inside target pod |
| Connection timeout | NetworkPolicy blocking, firewall, or route missing | `kubectl get networkpolicy`, `iptables -L` |
| TLS handshake failure | Cert expired, wrong CA, hostname mismatch | `openssl s_client -connect host:port` |
| Intermittent failures | DNS caching, connection limits, or health check issues | Check pod restarts, events, resource limits |
