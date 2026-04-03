# Day 5 ANSWERS: Full Network Trace

---

## Exercise 1: Packet Trace — Pod to Harbor

Step 1: build-agent pod calls `docker pull harbor.local:443/library/nginx:1.25`
  → Container runtime (containerd) initiates HTTPS connection to harbor.local:443

Step 2: Pod resolves harbor.local via CoreDNS
  → CoreDNS checks: is this a cluster service? No.
  → Forwards to upstream DNS (node's /etc/resolv.conf)
  → Resolves to Harbor server IP (e.g., 10.0.1.50)

Step 3: Pod sends TCP SYN to 10.0.1.50:443
  → Packet leaves pod via veth pair → CNI (Calico/Canal)

Step 4: CNI routes the packet
  → If Harbor is on the same network: direct routing to Harbor node
  → If different subnet: node routing table → next hop

Step 5: TLS handshake with Harbor
  → Harbor presents its TLS certificate
  → Containerd verifies against trusted CAs
  → Session established, image layers downloaded

Step 6: Image layers pulled and stored
  → Containerd stores layers in local content store
  → Pod can now use the image

---

## Exercise 2: What Breaks If...

**a) CoreDNS evicted:**
- Symptom: ALL DNS lookups fail — pods can't resolve any service names or external hosts. Services fail with "name resolution failed"
- Diagnosis: `kubectl get pods -n kube-system -l k8s-app=kube-dns` → shows Evicted or no pods
- Fix: Check node memory pressure (`kubectl describe node`). Either free memory, add nodes, or set resource requests/limits on CoreDNS to prevent eviction (PriorityClass: system-cluster-critical)

**b) Harbor TLS cert expired:**
- Symptom: Image pulls fail with "x509: certificate has expired" or "TLS handshake failure"
- Diagnosis: `openssl s_client -connect harbor.local:443 </dev/null 2>/dev/null | openssl x509 -dates -noout` → shows expired dates
- Fix: Renew the Harbor TLS certificate. If using cert-manager, check the Certificate resource. If manual, generate new cert from CA and restart Harbor.

**c) NetworkPolicy blocks egress:**
- Symptom: build-agent pods can't reach Harbor — connection times out (not refused — timeout indicates blocked)
- Diagnosis: `kubectl get networkpolicy -n build-agent-ns` → check egress rules. `kubectl exec build-agent -- curl -vk https://harbor.local:443` → times out
- Fix: Add egress rule allowing traffic to Harbor IP/port. Don't forget DNS egress (port 53) too.

**d) Calico crashes on one node:**
- Symptom: Pods on that node lose network connectivity. New pods scheduled there can't get IPs. Cross-node communication to/from that node breaks.
- Diagnosis: `kubectl get pods -n kube-system -l k8s-app=calico-node` → one pod CrashLoopBackOff. `kubectl logs calico-node-xxxx -n kube-system`
- Fix: Check Calico logs for root cause (usually: BGP peer failure, IPAM exhaustion, or config error). Restart the calico-node pod. If node is unrecoverable, drain and replace.

**e) iptables flushed on a node:**
- Symptom: kube-proxy service routing breaks — ClusterIP services stop working on that node. Pods on the node can't reach services by ClusterIP.
- Diagnosis: `iptables -t nat -L -n | grep KUBE` → no KUBE-SERVICES chain. kube-proxy recreates rules, but it might take a moment.
- Fix: Restart kube-proxy on that node (`kubectl delete pod -n kube-system -l k8s-app=kube-proxy --field-selector spec.nodeName=<node>`). It will regenerate all iptables rules.

---

## Exercise 3: RKE2 Specifics

**How RKE2 differs from vanilla K8s:**
RKE2 is a hardened Kubernetes distribution from Rancher focused on security and air-gap. It bundles all components (kubelet, kube-proxy, containerd, etcd) into a single binary. It's CIS hardened by default — SELinux, Pod Security Admission, audit logging enabled out of the box. It doesn't require an external etcd cluster — it embeds one. This makes it ideal for air-gap because you deploy ONE binary instead of managing multiple components.

**Default CNI:**
Canal (combination of Calico for network policy + Flannel for VXLAN overlay). Alternatives: Calico (full BGP routing), Cilium (eBPF-based), or custom CNI.

**Private registry config for air-gap:**
File: `/etc/rancher/rke2/registries.yaml`
```yaml
mirrors:
  docker.io:
    endpoint:
      - "https://harbor.local"
  "registry.local:5000":
    endpoint:
      - "https://harbor.local"
configs:
  "harbor.local":
    tls:
      ca_file: /etc/rancher/rke2/harbor-ca.pem
    auth:
      username: admin
      password: Harbor12345
```
This tells RKE2's containerd to redirect image pulls from docker.io to the local Harbor instance. All image pulls go to the local registry — no internet needed.
