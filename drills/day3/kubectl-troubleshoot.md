# Day 3: kubectl Troubleshooting Flows
# For each scenario, write your step-by-step diagnostic flow.

---

## Scenario 1: Pod is in CrashLoopBackOff

A pod called "payment-api-6f8d9" keeps restarting. Status shows CrashLoopBackOff.

**Write your diagnostic steps (commands + what you're looking for):**
```
Step 1:

Step 2:

Step 3:

Step 4:

```

---

## Scenario 2: Deployment rollout stuck

You ran `kubectl apply -f deployment.yml` but `kubectl rollout status` hangs.
Pods are stuck in "ContainerCreating" state.

**Write your diagnostic steps:**
```
Step 1:

Step 2:

Step 3:

Step 4:

```

---

## Scenario 3: Node shows NotReady

`kubectl get nodes` shows one node as "NotReady". Pods on it are being evicted.

**Write your diagnostic steps:**
```
Step 1:

Step 2:

Step 3:

Step 4:

```

---

## Scenario 4: Can't pull image — ImagePullBackOff

A new deployment's pods show "ImagePullBackOff" in status.

**Write your diagnostic steps:**
```
Step 1:

Step 2:

Step 3:

```

**Name 3 common causes of ImagePullBackOff:**
```
1.
2.
3.
```
