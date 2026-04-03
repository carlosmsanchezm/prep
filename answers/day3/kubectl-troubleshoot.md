# Day 3 ANSWERS: kubectl Troubleshooting

---

## Scenario 1: CrashLoopBackOff

Step 1: `kubectl logs payment-api-6f8d9 --previous`
→ Look at the logs from the LAST crash (--previous shows logs from the crashed container)
→ Usually tells you exactly why: missing config, bad connection string, unhandled exception

Step 2: `kubectl describe pod payment-api-6f8d9`
→ Check Events section: OOMKilled? Liveness probe failed? Missing ConfigMap/Secret?
→ Check container exit code: 137 = OOMKilled, 1 = app error, 126 = permission denied

Step 3: `kubectl get pod payment-api-6f8d9 -o yaml | grep -A5 resources`
→ Check resource limits — is memory limit too low? (OOMKilled at limit)

Step 4: `kubectl exec -it payment-api-6f8d9 -- sh` (if pod is briefly running)
→ Check env vars, mounted configs, connectivity to dependencies
→ If it crashes too fast to exec, check the logs and events

---

## Scenario 2: Rollout stuck / ContainerCreating

Step 1: `kubectl describe pod <stuck-pod-name>`
→ Look at Events: is it pulling an image? Waiting on a volume? Scheduling issue?

Step 2: `kubectl get events --sort-by='.lastTimestamp' -n <namespace>`
→ Broader view — FailedMount? FailedScheduling? FailedAttachVolume?

Step 3: `kubectl get pvc -n <namespace>`
→ If pod needs a volume, is the PVC Bound? If Pending → no matching PV or wrong StorageClass

Step 4: `kubectl get nodes -o wide` + `kubectl top nodes`
→ If FailedScheduling: are nodes at capacity? Does the pod have nodeSelector/affinity that nothing matches?

---

## Scenario 3: Node NotReady

Step 1: `kubectl describe node <node-name>`
→ Check Conditions: MemoryPressure? DiskPressure? PIDPressure? NetworkUnavailable?
→ Check last heartbeat time — how long since it reported?

Step 2: SSH to the node (if possible): `systemctl status kubelet`
→ Is kubelet running? Check logs: `journalctl -u kubelet -f`
→ Common: kubelet can't reach API server, cert expired, disk full

Step 3: On the node: `df -h` and `free -m`
→ Is the disk full? (/var/lib/kubelet or /var/lib/containerd full = eviction pressure)
→ Is memory exhausted?

Step 4: `kubectl get pods --field-selector spec.nodeName=<node-name>`
→ What was running on this node? Can those pods be rescheduled elsewhere?
→ If the node can't recover: `kubectl drain <node-name> --ignore-daemonsets` to move workloads

---

## Scenario 4: ImagePullBackOff

Step 1: `kubectl describe pod <pod-name>`
→ Events will say exactly what failed: "Failed to pull image... unauthorized" or "not found"

Step 2: Check the image name in the pod spec: `kubectl get pod <pod-name> -o yaml | grep image:`
→ Is it spelled correctly? Does the tag exist? Is it pointing to the right registry?

Step 3: Check registry auth: `kubectl get secrets -n <namespace> | grep docker`
→ Is there an imagePullSecret? Is it configured in the pod spec?
→ Check: `kubectl get pod <pod-name> -o yaml | grep -A2 imagePullSecrets`

**3 common causes:**
1. **Wrong image name or tag** — typo, tag doesn't exist, or :latest was overwritten
2. **Auth failure** — private registry, no imagePullSecret configured, or secret has wrong credentials
3. **Registry unreachable** — DNS can't resolve registry hostname, network policy blocking, or air-gapped with no local mirror
