# kubectl Cheatsheet — Memorize This

## Core Commands

```bash
# List resources
kubectl get pods                          # pods in current namespace
kubectl get pods -n kube-system           # pods in specific namespace
kubectl get pods -A                       # pods in ALL namespaces
kubectl get pods -o wide                  # extra info: node, IP
kubectl get pods -o yaml                  # full YAML output
kubectl get pods -l app=nginx             # filter by label
kubectl get all                           # pods, services, deployments, etc.

# Detailed info
kubectl describe pod my-pod               # events, conditions, containers
kubectl describe node my-node             # capacity, allocatable, conditions
kubectl describe svc my-service           # endpoints, ports, selectors

# Logs
kubectl logs my-pod                       # stdout from pod
kubectl logs my-pod -c my-container       # specific container in multi-container pod
kubectl logs my-pod -f                    # follow (stream)
kubectl logs my-pod --previous            # logs from crashed/restarted container
kubectl logs -l app=nginx                 # logs from all pods with label

# Execute commands in pod
kubectl exec -it my-pod -- /bin/bash      # interactive shell
kubectl exec my-pod -- cat /etc/hosts     # run command, get output
kubectl exec -it my-pod -c sidecar -- sh  # exec into specific container

# Apply / Delete
kubectl apply -f manifest.yml             # create or update from file
kubectl apply -f ./manifests/             # apply all files in directory
kubectl delete -f manifest.yml            # delete resources defined in file
kubectl delete pod my-pod                 # delete specific pod
kubectl delete pods --all -n my-ns        # delete all pods in namespace

# Create resources imperatively
kubectl create namespace my-ns
kubectl create secret generic my-secret --from-literal=key=value
kubectl create configmap my-config --from-file=config.yaml
kubectl create serviceaccount my-sa -n my-ns
```

## Deployment Management

```bash
# Rollout
kubectl rollout status deployment/my-app          # watch rollout progress
kubectl rollout history deployment/my-app          # see revision history
kubectl rollout undo deployment/my-app             # rollback to previous
kubectl rollout undo deployment/my-app --to-revision=2  # rollback to specific
kubectl rollout restart deployment/my-app          # rolling restart all pods

# Scale
kubectl scale deployment/my-app --replicas=3

# Edit live (opens in $EDITOR)
kubectl edit deployment/my-app

# Patch
kubectl patch deployment my-app -p '{"spec":{"replicas":5}}'
```

## Debugging

```bash
# Events (most useful for debugging)
kubectl get events --sort-by='.lastTimestamp'       # recent events
kubectl get events -n my-ns --field-selector reason=Failed

# Resource usage
kubectl top pods                          # CPU/memory per pod
kubectl top nodes                         # CPU/memory per node

# Run a debug pod
kubectl run debug --image=busybox --rm -it --restart=Never -- sh
kubectl run debug --image=nicolaka/netshoot --rm -it --restart=Never -- bash

# Check endpoints (does service have backends?)
kubectl get endpoints my-service          # should show pod IPs

# Port forward for local testing
kubectl port-forward svc/my-service 8080:80
kubectl port-forward pod/my-pod 5432:5432

# Copy files
kubectl cp my-pod:/var/log/app.log ./app.log
kubectl cp ./config.yaml my-pod:/tmp/config.yaml

# Check permissions
kubectl auth can-i create pods                     # current user
kubectl auth can-i create pods --as=system:serviceaccount:my-ns:my-sa
```

## Output Formatting

```bash
# JSONPath
kubectl get pods -o jsonpath='{.items[*].metadata.name}'
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}'
kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'

# Custom columns
kubectl get pods -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName'

# Sort
kubectl get pods --sort-by='.status.startTime'
kubectl get pods --sort-by='.metadata.creationTimestamp'
```

## Namespace Management

```bash
kubectl get ns                            # list namespaces
kubectl create ns my-ns                   # create namespace
kubectl config set-context --current --namespace=my-ns  # switch default ns
kubectl delete ns my-ns                   # delete namespace + ALL resources in it
```

## Quick Reference

```bash
kubectl api-resources                     # list all resource types
kubectl explain deployment.spec.strategy  # docs for a field
kubectl get pod my-pod -o yaml | less     # inspect full spec
kubectl diff -f manifest.yml              # preview changes before apply
kubectl apply -f manifest.yml --dry-run=client -o yaml  # validate without applying
```

## Common Debugging Flows

### Pod won't start
```bash
kubectl get pods                          # check STATUS: Pending? CrashLoopBackOff? ImagePullBackOff?
kubectl describe pod my-pod               # check Events section at bottom
kubectl logs my-pod --previous            # if CrashLoopBackOff, check previous logs
kubectl get events --sort-by='.lastTimestamp' -n my-ns
```

### Service not reachable
```bash
kubectl get svc my-service                # check ClusterIP, ports
kubectl get endpoints my-service          # are there backend pods?
kubectl get pods -l app=my-app            # do pods match the service selector?
kubectl exec debug-pod -- nslookup my-service.my-ns.svc.cluster.local
kubectl exec debug-pod -- curl -v http://my-service:8080
```

### Node issues
```bash
kubectl get nodes                         # check STATUS: Ready?
kubectl describe node my-node             # check Conditions, Capacity, Allocatable
kubectl top nodes                         # resource pressure?
kubectl get pods --field-selector spec.nodeName=my-node  # what's running on it?
```
