# Day 1 ANSWERS: Network Diagnosis Scenarios

---

## Scenario 1: Pod can't reach external API

**Commands in order:**
1. `kubectl exec -it my-pod -- nslookup api.vendor.com`
   → Does DNS resolve? If not → CoreDNS issue or NetworkPolicy blocking DNS
2. `kubectl exec -it my-pod -- curl -vk https://api.vendor.com`
   → Does the connection establish? Look for: DNS resolution, TCP connect, TLS handshake
3. `kubectl get networkpolicy -n my-namespace`
   → Is there an egress policy blocking outbound traffic?
4. `kubectl exec -it my-pod -- cat /etc/resolv.conf`
   → Are the nameservers correct? Should point to CoreDNS (usually 10.96.0.10)
5. Check node-level: `iptables -L -n -v` on the node, or check if NAT Gateway / firewall is blocking

**Most likely causes:**
- NetworkPolicy blocking egress (most common in locked-down clusters)
- DNS resolution failing (CoreDNS down or misconfigured)
- Firewall/NAT gateway blocking the destination (especially in air-gap or restricted networks)
- No internet access at all (air-gapped network — expected behavior!)

---

## Scenario 2: Service returns 503

**Commands in order:**
1. `kubectl get endpoints backend`
   → Are there any endpoints? If empty → selector mismatch
2. `kubectl get pods -l <backend-service-selector> -o wide`
   → Do pods exist? Are they Running and Ready?
3. `kubectl describe svc backend`
   → Check selector, ports, targetPort
4. `kubectl logs <backend-pod>`
   → Is the app crashing? Returning errors?
5. `kubectl exec -it frontend-pod -- curl -v http://backend:8080`
   → Test connectivity directly from the calling pod

**Most likely causes:**
- Service selector doesn't match pod labels → empty endpoints → 503
- Backend pods are crashing (CrashLoopBackOff) → no healthy backends
- Backend app is returning 503 itself (overloaded, misconfigured)
- Readiness probe failing → pods not marked as Ready → removed from endpoints

---

## Scenario 3: New pod won't start — stuck in Pending

**Commands in order:**
1. `kubectl describe pod <pod-name>`
   → Look at Events section — it tells you exactly why it's Pending
2. `kubectl get events --sort-by='.lastTimestamp' -n my-ns`
   → Broader view of what's happening in the namespace
3. `kubectl get nodes -o wide`
   → Are nodes Ready? Is there capacity?
4. `kubectl top nodes`
   → Are nodes at capacity (CPU/memory)?

**Three possible causes:**
1. **Insufficient resources** — no node has enough CPU/memory to schedule the pod (check resource requests)
2. **No matching node** — nodeSelector or nodeAffinity requires a label that no node has
3. **PVC not bound** — pod requires a PersistentVolumeClaim that can't be satisfied (no matching PV, wrong storageClass)

Other causes: taints and tolerations (node is tainted, pod doesn't tolerate it), pod priority preemption, or too many pods on the node (maxPods limit).
