# Day 4 ANSWERS: DNS and TLS

---

## Exercise 1: DNS Resolution

**Steps for `curl https://api.example.com` from a pod:**

Step 1: Pod's libc resolver reads /etc/resolv.conf to find the DNS server
  → In K8s, this points to CoreDNS ClusterIP (typically 10.96.0.10)

Step 2: Pod sends DNS query to CoreDNS for "api.example.com"
  → CoreDNS checks: is this a cluster-internal name (*.svc.cluster.local)?
  → No — it's external

Step 3: CoreDNS forwards the query to upstream DNS
  → Upstream is usually the VPC DNS resolver (e.g., 10.0.0.2 in AWS)
  → Configured in CoreDNS Corefile under "forward . /etc/resolv.conf"

Step 4: Upstream DNS recursively resolves api.example.com
  → Root → .com TLD → example.com authoritative → A record returned

Step 5: DNS response flows back: upstream → CoreDNS → pod
  → Pod now has the IP address, proceeds with TCP connection + TLS handshake

**What file controls pod DNS?**
/etc/resolv.conf inside the pod. In K8s, this is auto-generated based on the pod's dnsPolicy.
Default: nameserver points to CoreDNS, search domains include <ns>.svc.cluster.local, svc.cluster.local, cluster.local

**CoreDNS overwhelmed symptoms:**
- DNS queries time out → pods can't resolve ANY names (internal or external)
- Intermittent "name resolution failed" errors
- High latency on service-to-service calls (DNS is the first step)
- Fix: scale CoreDNS (increase replicas), add node-local DNS cache

---

## Exercise 2: TLS Handshake

Step 1: **Client Hello** — Client sends: supported TLS versions, cipher suites, random number
Step 2: **Server Hello** — Server responds: chosen TLS version, chosen cipher suite, server's certificate, random number
Step 3: **Certificate Verification** — Client verifies server cert against its CA trust store. Checks: expiry, hostname match, chain of trust
Step 4: **Key Exchange** — Client and server agree on a shared secret using the chosen key exchange method (e.g., ECDHE). This generates the session encryption keys.
Step 5: **Encrypted Communication** — Both sides confirm with "Finished" messages encrypted with the session keys. All subsequent data is encrypted.

**Debug command:**
```bash
openssl s_client -connect api.example.com:443
```
Shows: certificate chain, expiry, cipher used, any errors

**3 common TLS failures:**
1. **Certificate expired** — server cert past its notAfter date
   → Fix: renew cert (cert-manager auto-renewal)
2. **Hostname mismatch** — cert is for "api.example.com" but you're connecting to "10.0.1.50"
   → Fix: use the hostname in the cert, or add a SAN (Subject Alternative Name)
3. **Untrusted CA** — client doesn't trust the CA that signed the server cert
   → Fix: add the CA to the client's trust store, or use --cacert flag in curl

---

## Exercise 3: mTLS in Kubernetes

**How Istio enforces mTLS:**
Istio injects an Envoy sidecar proxy into every pod (via mutating admission webhook). When pod A calls pod B, the Envoy sidecars handle the TLS automatically: A's Envoy encrypts the request with its certificate, B's Envoy verifies A's certificate before accepting. The application code doesn't know TLS is happening — it just makes a plain HTTP call, and the sidecars handle encryption transparently. Certificates are issued and rotated automatically by Istio's control plane (istiod).

**STRICT vs PERMISSIVE:**
- **STRICT:** All traffic MUST be mTLS. Non-mTLS connections are rejected. Use in production for full zero-trust.
- **PERMISSIVE:** Accept both mTLS and plaintext. Use during migration — allows non-mesh services to still communicate while you gradually add sidecars.
