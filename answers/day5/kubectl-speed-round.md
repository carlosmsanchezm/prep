# Day 5 ANSWERS: kubectl Speed Round

1. `kubectl get pods -A`
2. `kubectl get pods -n web -l app=nginx`
3. `kubectl describe deployment api -n production`
4. `kubectl logs worker-abc123 -f`
5. `kubectl exec -it debug -- /bin/bash`
6. `kubectl apply -f ./manifests/`
7. `kubectl delete pod stuck-pod -n default`
8. `kubectl scale deployment api --replicas=5`
9. `kubectl rollout status deployment/api`
10. `kubectl rollout undo deployment/api`
11. `kubectl get events -n staging --sort-by='.lastTimestamp'`
12. `kubectl port-forward svc/prometheus 9090:9090`
13. `kubectl create secret generic db-creds --from-literal=username=admin --from-literal=password=secret`
14. `kubectl get pod api-server-0 -o yaml`
15. `kubectl auth can-i create deployments -n prod`
16. `kubectl top pods`
17. `kubectl run debug --image=busybox --rm -it --restart=Never -- sh`
18. `kubectl get endpoints backend-svc`
19. `kubectl rollout restart deployment/api`
20. `kubectl get ns`
