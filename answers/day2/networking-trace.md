# Day 2 ANSWERS: Packet Trace

---

## Scenario: Pod-to-Pod via Service

**frontend → http://backend-svc.api.svc.cluster.local:8080**

Step 1: Frontend pod makes DNS query for backend-svc.api.svc.cluster.local
Step 2: CoreDNS (kube-system) resolves to ClusterIP (e.g., 10.96.45.12)
Step 3: Frontend pod sends TCP SYN to 10.96.45.12:8080
Step 4: kube-proxy iptables/IPVS rules on the node translate ClusterIP → actual pod IP (DNAT)
        (iptables in the nat table rewrites destination to a real backend pod IP, e.g., 10.244.2.15:8080)
Step 5: Packet traverses CNI network (Calico/Flannel) to reach the backend pod's node
        - If same node: stays on the bridge
        - If different node: encapsulated (VXLAN/IPIP) or routed via BGP (Calico)
Step 6: Packet arrives at backend pod via veth pair. Backend processes request and responds.
        Response follows reverse path.

**If timing out, check:**
1. `kubectl get endpoints backend-svc -n api` — does the service have endpoints?
2. `kubectl get pods -n api -l <selector>` — are backend pods Running + Ready?
3. `kubectl exec frontend -- nslookup backend-svc.api.svc.cluster.local` — DNS working?
4. `kubectl get networkpolicy -n api` — is a NetworkPolicy blocking traffic?
5. Check if the backend pod is actually listening: `kubectl exec backend-pod -- ss -tlnp`

---

## Scenario: Pod-to-External

**worker pod → https://packages.vendor.com**

Step 1: Worker pod makes DNS query for packages.vendor.com
Step 2: CoreDNS forwards to upstream DNS (VPC DNS resolver at .2 address, e.g., 10.0.0.2)
Step 3: DNS resolves to external IP (e.g., 203.0.113.50)
Step 4: Worker pod sends HTTPS request. Packet leaves pod via veth pair → CNI bridge → node NIC
Step 5: Node routing table → default route → VPC router
Step 6: VPC route table → 0.0.0.0/0 → NAT Gateway (in public subnet)
Step 7: NAT Gateway performs SNAT (source NAT): replaces pod's private IP with NAT Gateway's public IP
Step 8: Packet goes through Internet Gateway → public internet → packages.vendor.com
        Response follows reverse path: IGW → NAT (reverse SNAT) → VPC → node → pod

**If NAT Gateway is removed:**
- Pod can still resolve DNS (CoreDNS → VPC DNS still works)
- TCP connection to external IP will TIME OUT — no route to internet
- Anything requiring external access fails: package downloads, API calls, image pulls
- Internal cluster traffic (pod-to-pod, pod-to-service) still works fine

**If CoreDNS is down:**
- Pod CANNOT resolve ANY hostname — not even internal services
- `nslookup backend-svc` fails
- `curl http://backend-svc:8080` fails (can't resolve)
- `curl http://10.96.45.12:8080` STILL WORKS (IP directly, no DNS needed)
- External DNS also fails (CoreDNS handles upstream forwarding)
- Check: `kubectl get pods -n kube-system -l k8s-app=kube-dns`
