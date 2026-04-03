# Day 6: Timed Hands-On Challenge

## Instructions
- Set a timer for 45 minutes TOTAL
- Work through all 3 parts in order
- NO AI assistance. Google/docs are okay (simulates the real interview)
- Write in a text editor, not an IDE with autocomplete
- Talk through your thinking out loud as you work

---

## Part 1: Ansible (15 minutes)

Write an Ansible playbook that prepares a RHEL 8 node for joining an RKE2 cluster.

Requirements:
- Disable swap
- Load br_netfilter and overlay kernel modules
- Set net.bridge.bridge-nf-call-iptables=1 and net.ipv4.ip_forward=1
- Open firewall ports: 6443/tcp, 9345/tcp, 10250/tcp
- Copy the RKE2 binary from /opt/rke2-installer/rke2 to /usr/local/bin/rke2
- Write a config file at /etc/rancher/rke2/config.yaml with server URL and token
- Start the rke2-agent service

Write in: `day6-my-answer-ansible.yml` (create this file)

---

## Part 2: Debug K8s Manifests (15 minutes)

The following manifests are broken. Find ALL bugs and write the fixes.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: build-agent
  namespace: cicd
spec:
  replicas: 2
  selector:
    matchLabels:
      role: builder
  template:
    metadata:
      labels:
        app: build-agent
    spec:
      serviceAccountName: build-sa
      containers:
        - name: agent
          image: harbor.local/build-agent:v3.1
          ports:
            - containerPort: "8080"
          resources:
            requests:
              cpu: 500m
              memory: 512Mi
            limits:
              cpu: 250m
              memory: 1Gi
          env:
            - name: REGISTRY_URL
              valueFrom:
                configMapRef:
                  name: build-config
                  key: registry_url
          volumeMounts:
            - name: workspace
              mountPath: /workspace
      volumes:
        - name: workspace
          emptyDir:
            sizeLimit: 5G
---
apiVersion: v1
kind: Service
metadata:
  name: build-agent-svc
  namespace: cicd
spec:
  selector:
    app: builder
  ports:
    - port: 80
      targetPort: 8080
```

Write your bug list in: `day6-my-answer-debug.md` (create this file)

---

## Part 3: Network Diagnosis (15 minutes)

**Scenario:** An engineer reports that the build-agent pods can't pull images from harbor.local. The pods show ImagePullBackOff.

Write your complete diagnostic procedure:
1. What commands would you run, in what order?
2. What are you looking for at each step?
3. Name 4 possible root causes.
4. For each cause, how would you fix it?

Write in: `day6-my-answer-network.md` (create this file)

---

## After You Finish

Check your work against the answer keys:
- Ansible: answers/day4/ansible-rke2-bootstrap.yml (similar exercise)
- K8s Debug: use the patterns from k8s-resources cheatsheet
- Network: use the debugging flows from networking cheatsheet
