# Day 6 ANSWERS: Hands-On Challenge

---

## Part 2 Bugs (the Ansible answer is in day4 answers):

1. **Selector doesn't match template labels**
   - selector.matchLabels: role: builder
   - template.labels: app: build-agent
   - Fix: make them match (both should be app: build-agent)

2. **containerPort should be integer, not string**
   - containerPort: "8080" → containerPort: 8080

3. **CPU limit (250m) < CPU request (500m)**
   - Limits must be >= requests
   - Fix: limits.cpu: 1000m (or at least 500m)

4. **Wrong env valueFrom syntax**
   - configMapRef is for envFrom (loads all keys). For a single key, use configMapKeyRef
   - Fix:
     ```yaml
     valueFrom:
       configMapKeyRef:
         name: build-config
         key: registry_url
     ```

5. **emptyDir sizeLimit uses "G" instead of "Gi"**
   - sizeLimit: 5G → sizeLimit: 5Gi

6. **Service selector doesn't match pod labels**
   - Service: app: builder
   - Pod labels: app: build-agent
   - Fix: Service selector should be app: build-agent

---

## Part 3: Network Diagnosis — ImagePullBackOff

### Diagnostic Procedure:

**Step 1:** `kubectl describe pod <build-agent-pod> -n cicd`
→ Look at Events section. It will say something like:
  - "Failed to pull image: unauthorized" → auth issue
  - "Failed to pull image: connection refused" → Harbor down or wrong URL
  - "Failed to pull image: timeout" → network issue
  - "Failed to pull image: x509" → TLS issue

**Step 2:** `kubectl exec -it <any-running-pod> -n cicd -- nslookup harbor.local`
→ Can the pod resolve Harbor's hostname? If not → DNS issue

**Step 3:** `kubectl exec -it <any-running-pod> -n cicd -- curl -vk https://harbor.local/v2/`
→ Can the pod reach Harbor? What does the TLS handshake look like?

**Step 4:** Check imagePullSecrets: `kubectl get pod <pod> -n cicd -o yaml | grep -A3 imagePullSecrets`
→ Is there a pull secret? Is it correct?

**Step 5:** Check the actual secret: `kubectl get secret <secret-name> -n cicd -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d`
→ Does it have the right registry URL, username, password?

### 4 Root Causes:

1. **No imagePullSecret configured** — pod doesn't have credentials to authenticate with Harbor
   - Fix: create the secret and add imagePullSecrets to the pod spec or service account

2. **Harbor TLS certificate not trusted** — containerd rejects the self-signed cert
   - Fix: add Harbor CA to the node's trust store, or configure `/etc/rancher/rke2/registries.yaml` with the CA

3. **DNS can't resolve harbor.local** — CoreDNS doesn't know about this hostname
   - Fix: add harbor.local to CoreDNS configmap (custom DNS entry) or to /etc/hosts on nodes

4. **NetworkPolicy blocking egress** — pods can't reach Harbor IP on port 443
   - Fix: add egress rule allowing traffic to Harbor's IP on TCP/443
