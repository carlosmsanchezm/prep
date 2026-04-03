# Day 1 ANSWERS: kubectl Commands

### 1. List all pods in the "production" namespace
```
kubectl get pods -n production
```

### 2. Get detailed info about why pod "api-server-7d8f9" is failing
```
kubectl describe pod api-server-7d8f9
```
(Look at the Events section at the bottom)

### 3. View the logs of a crashed container (it restarted)
```
kubectl logs api-server-7d8f9 --previous
```

### 4. Open a shell inside a running pod called "debug-pod"
```
kubectl exec -it debug-pod -- /bin/bash
```
(or `-- sh` if bash isn't available)

### 5. See what's consuming the most CPU across all pods
```
kubectl top pods --sort-by=cpu
```
(or `kubectl top pods -A --sort-by=cpu` for all namespaces)

### 6. Check if a Service called "backend-svc" has any pod endpoints
```
kubectl get endpoints backend-svc
```
(If it shows `<none>`, the service selector doesn't match any pod labels)

### 7. Forward local port 8080 to port 80 on a Service called "web-app"
```
kubectl port-forward svc/web-app 8080:80
```

### 8. Roll back a Deployment called "api" to the previous version
```
kubectl rollout undo deployment/api
```

### 9. See recent events in the "staging" namespace, sorted by time
```
kubectl get events -n staging --sort-by='.lastTimestamp'
```

### 10. Check if your service account can create pods in the "app" namespace
```
kubectl auth can-i create pods -n app
```
