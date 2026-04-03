# Kubernetes Resource Templates — Memorize These Patterns

## Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: default
  labels:
    app: my-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app              # MUST match template labels
  template:
    metadata:
      labels:
        app: my-app            # MUST match selector above
    spec:
      containers:
        - name: my-app
          image: registry.local/my-app:v1.2.3
          ports:
            - containerPort: 8080
              name: http
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 256Mi
          livenessProbe:
            httpGet:
              path: /healthz
              port: http
            initialDelaySeconds: 10
            periodSeconds: 15
          readinessProbe:
            httpGet:
              path: /ready
              port: http
            initialDelaySeconds: 5
            periodSeconds: 5
          env:
            - name: ENV_VAR
              value: "production"
            - name: SECRET_KEY
              valueFrom:
                secretKeyRef:
                  name: my-secret
                  key: api-key
          volumeMounts:
            - name: config
              mountPath: /etc/app
      volumes:
        - name: config
          configMap:
            name: my-config
```

## Service

```yaml
# ClusterIP (internal only — default)
apiVersion: v1
kind: Service
metadata:
  name: my-app
spec:
  type: ClusterIP
  selector:
    app: my-app                # MUST match pod labels
  ports:
    - port: 80                 # service port (what clients connect to)
      targetPort: 8080         # pod port (what container listens on)
      protocol: TCP
      name: http

---
# NodePort (expose on every node)
apiVersion: v1
kind: Service
metadata:
  name: my-app-nodeport
spec:
  type: NodePort
  selector:
    app: my-app
  ports:
    - port: 80
      targetPort: 8080
      nodePort: 30080          # accessible on <any-node-ip>:30080

---
# LoadBalancer (cloud provider LB)
apiVersion: v1
kind: Service
metadata:
  name: my-app-lb
spec:
  type: LoadBalancer
  selector:
    app: my-app
  ports:
    - port: 443
      targetPort: 8443
```

### When to use each:
- **ClusterIP** — internal service-to-service communication (most common)
- **NodePort** — expose to outside without a load balancer (dev/testing, air-gap)
- **LoadBalancer** — production external access (cloud environments)

## Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
  tls:
    - hosts:
        - app.example.com
      secretName: tls-secret
```

## NetworkPolicy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: backend             # policy applies to pods with this label
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend    # allow traffic FROM frontend pods
      ports:
        - port: 8080
          protocol: TCP
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: database    # allow traffic TO database pods
      ports:
        - port: 5432
          protocol: TCP
    - to:                      # allow DNS
        - namespaceSelector: {}
      ports:
        - port: 53
          protocol: UDP
        - port: 53
          protocol: TCP
```

### Key rules:
- If NO NetworkPolicy selects a pod → all traffic allowed (default open)
- Once ANY policy selects a pod → only explicitly allowed traffic passes
- Always include DNS egress (port 53) or pods can't resolve service names

## RBAC

```yaml
# ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app-sa
  namespace: my-ns

---
# Role (namespace-scoped)
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
  namespace: my-ns
rules:
  - apiGroups: [""]            # "" = core API group
    resources: ["pods", "pods/log"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list"]

---
# RoleBinding (binds Role to ServiceAccount)
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: my-ns
subjects:
  - kind: ServiceAccount
    name: my-app-sa
    namespace: my-ns
roleRef:
  kind: Role
  name: pod-reader
  apiGroup: rbac.authorization.k8s.io

---
# ClusterRole + ClusterRoleBinding (cluster-wide)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: node-reader
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list", "watch"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: read-nodes
subjects:
  - kind: ServiceAccount
    name: my-app-sa
    namespace: my-ns
roleRef:
  kind: ClusterRole
  name: node-reader
  apiGroup: rbac.authorization.k8s.io
```

## ConfigMap & Secret

```yaml
# ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-config
data:
  config.yaml: |
    server:
      port: 8080
      log_level: info
  APP_ENV: production

---
# Secret
apiVersion: v1
kind: Secret
metadata:
  name: my-secret
type: Opaque
data:
  api-key: YWJjMTIz           # base64 encoded ("abc123")
  password: cGFzc3dvcmQ=      # base64 encoded ("password")

# Create imperatively:
# kubectl create secret generic my-secret --from-literal=api-key=abc123
# kubectl create configmap my-config --from-file=config.yaml
```

## Common Gotchas in K8s YAML

1. **Selector labels don't match template labels** — Deployment selector MUST match pod template labels
2. **Service selector doesn't match pod labels** — Service won't route traffic
3. **Wrong apiVersion** — apps/v1 for Deployments, networking.k8s.io/v1 for NetworkPolicy/Ingress
4. **containerPort vs targetPort** — containerPort is on the pod, targetPort is what the Service routes to
5. **Missing port name** — if you reference a port by name in probes or services, it must be defined
6. **Resource limits too low** — pods get OOMKilled. Check with `kubectl describe pod` for OOMKilled events
7. **Missing namespace** — resources go to `default` if not specified
8. **Secret data must be base64** — use `echo -n "value" | base64` (the -n avoids trailing newline)
