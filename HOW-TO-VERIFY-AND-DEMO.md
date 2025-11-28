# How to Check & Demonstrate Your Project to HR

## PART 1: Quick Health Check (5 minutes)

### Step 1: Verify All Components Are Deployed
```powershell
# Check namespace exists
kubectl get namespace flask-mongodb

# Check all pods are running
kubectl get pods -n flask-mongodb

# Expected output (should show all pods):
# NAME                        READY   STATUS    RESTARTS   AGE
# flask-app-xxxxx            1/1     Running   0          2m
# flask-app-yyyyy            1/1     Running   0          2m
# mongo-0                    1/1     Running   0          3m
# load-gen-zzzzz            0/1     Completed 0          1m (if load test ran)
```

### Step 2: Verify HPA is Ready
```powershell
# Check HPA status
kubectl get hpa -n flask-mongodb

# Expected output (HPA should be READY=True):
# NAME        REFERENCE                   TARGETS           MINPODS   MAXPODS   REPLICAS   AGE
# flask-hpa   Deployment/flask-app   <cpu>/<70%>       2         5         2          2m
```

### Step 3: Verify Flask App Works
```powershell
# Get Flask service
kubectl get svc -n flask-mongodb

# Port-forward to access Flask locally (runs in background)
kubectl port-forward -n flask-mongodb svc/flask-service 5000:5000

# In another terminal, test the Flask endpoints
# Test 1: Welcome endpoint
curl http://localhost:5000/
# Expected: "Welcome to the Flask app! The current time is: ..."

# Test 2: Health check
curl http://localhost:5000/health
# Expected: {"status":"healthy"}

# Test 3: Get data from MongoDB
curl http://localhost:5000/data
# Expected: JSON array of data stored in MongoDB

# Test 4: Post data to MongoDB
curl -X POST http://localhost:5000/data -H "Content-Type: application/json" -d "{\"name\":\"test\",\"value\":123}"
# Expected: {"message":"Data inserted successfully"} or similar
```

### Step 4: Verify MongoDB Connection
```powershell
# Check MongoDB StatefulSet
kubectl get statefulset -n flask-mongodb

# Verify MongoDB is accessible (check logs)
kubectl logs -n flask-mongodb mongo-0

# Expected: MongoDB startup logs, no errors
```

---

## PART 2: Show Autoscaling in Action (7 minutes)

### The Easiest Way - Run Automated Test Script

```powershell
# IMPORTANT: Run PowerShell as ADMINISTRATOR
# Right-click PowerShell icon → Run as Administrator

cd c:\Users\HP\Learning_React\farAlpha\FLASK-MONGODB-K8S-SUBMISSION

# Run the complete test (shows all autoscaling steps)
.\hpa-complete-test.ps1

# This will:
# 1. Show baseline (2 pods)
# 2. Generate heavy load
# 3. Show scaling to 3-4-5 pods
# 4. Save results to hpa-test-TIMESTAMP.log
# Total time: 5-7 minutes
```

### What You'll See During the Test

```
========================================
STEP 5: BASELINE STATUS (BEFORE LOAD)
==========================================

Current pod replicas (should be 1-2):
NAME                    READY   STATUS    RESTARTS   AGE
flask-app-abc1234      1/1     Running   0          2m
flask-app-def5678      1/1     Running   0          2m

HPA Status:
NAME        REFERENCE            TARGETS    MINPODS   MAXPODS   REPLICAS
flask-hpa   Deployment/flask-app 8%/70%     2         5         2

HPA Details:
  Current Replicas: 2
  Min Replicas: 2
  Max Replicas: 5
  Target CPU: 70%
  Current CPU: 8%
  Status: READY = True

========================================
STEP 6: GENERATE HIGH CPU LOAD
==========================================

Creating load generator pod with 30 concurrent requests...
This simulates high traffic to trigger CPU-based autoscaling...

--- Status at 0 seconds ---
NAME                    READY   STATUS
flask-app-abc1234      1/1     Running   CPU: 15%
flask-app-def5678      1/1     Running   CPU: 20%

--- Status at 5 seconds ---
NAME                    READY   STATUS
flask-app-abc1234      1/1     Running   CPU: 52%
flask-app-def5678      1/1     Running   CPU: 48%

--- Status at 10 seconds ---
NAME                    READY   STATUS
flask-app-abc1234      1/1     Running   CPU: 75%      ← EXCEEDS 70%!
flask-app-def5678      1/1     Running   CPU: 78%      ← EXCEEDS 70%!
flask-app-ghi9012      0/1     Pending   (new pod spawning)

--- Status at 15 seconds ---
NAME                    READY   STATUS
flask-app-abc1234      1/1     Running   CPU: 72%
flask-app-def5678      1/1     Running   CPU: 75%
flask-app-ghi9012      1/1     Running   CPU: 70%      ← NEW POD 3!
flask-app-jkl3456      0/1     Pending   (another new pod)

========================================
STEP 7: FINAL AUTOSCALING RESULTS
==========================================

Final Pod Count (AUTOSCALING WORKED!):
NAME                    READY   STATUS      CPU
flask-app-abc1234      1/1     Running      72%
flask-app-def5678      1/1     Running      75%
flask-app-ghi9012      1/1     Running      70%
flask-app-jkl3456      1/1     Running      68%

Final HPA Status:
NAME        REFERENCE            TARGETS     MINPODS   MAXPODS   REPLICAS   AGE
flask-hpa   Deployment/flask-app 71%/70%     2         5         4          7m

HPA Full Details with Scaling Events:
Events:
  Type    Reason                 Age    Message
  ----    ------                 ----   -------
  Normal  SuccessfulRescaleEvent 2m25s  New size: 3; reason: CPU load above target
  Normal  SuccessfulRescaleEvent 2m20s  New size: 4; reason: CPU load above target
```

---

## PART 3: Manual Step-by-Step Test (If Script Doesn't Work)

### Step 1: Open 4 Terminal Windows

**Terminal 1:** Watch pod scaling
```powershell
cd c:\Users\HP\Learning_React\farAlpha\FLASK-MONGODB-K8S-SUBMISSION
kubectl get pods -n flask-mongodb -w
# This will show pods in real-time as they're added/removed
```

**Terminal 2:** Watch HPA
```powershell
kubectl get hpa -n flask-mongodb -w
# This shows HPA state changing in real-time
```

**Terminal 3:** Watch metrics
```powershell
kubectl top pods -n flask-mongodb
# Shows CPU usage of each pod
```

**Terminal 4:** Generate load (in your main PowerShell)
```powershell
# First, check baseline
kubectl get pods -n flask-mongodb
# Output: 2 pods (flask-app-xxxxx, flask-app-yyyyy)

# GENERATE LOAD - Run this command:
kubectl run -n flask-mongodb load-gen-demo --image=busybox --restart=Never -- sh -c 'i=0; while [ $i -lt 30 ]; do wget -q -O- http://flask-service:5000/ 2>/dev/null & sleep 0.1; i=$((i+1)); done; wait'

# Wait 10-20 seconds and watch Terminals 1, 2, 3 for changes

# After 30 seconds, check final state
kubectl get pods -n flask-mongodb
# Output: Should show 3-5 pods now! (scaling worked!)

kubectl get hpa -n flask-mongodb -o wide
# Output: Shows REPLICAS increased from 2 to 3-5

kubectl describe hpa -n flask-mongodb flask-hpa
# Output: Look for "Events:" section showing "ScaledUp" events
```

---

## PART 4: Screenshots to Show HR Manager

### Screenshot 1: Baseline (Before Autoscaling)
```
Show this output in PowerShell:
┌─────────────────────────────────────┐
│ kubectl get hpa -n flask-mongodb    │
│                                      │
│ NAME     REFERENCE            TARGETS   REPLICAS │
│ flask-hpa Deployment/flask-app 8%/70%  2        │
└─────────────────────────────────────┘

Caption: "Initial state - 2 Flask pods, CPU at 8%, HPA ready"
```

### Screenshot 2: During Load
```
Show this output:
┌─────────────────────────────────────┐
│ kubectl get pods -n flask-mongodb   │
│                                      │
│ NAME              READY STATUS AGE  │
│ flask-app-abc    1/1   Running 5m   │
│ flask-app-def    1/1   Running 5m   │
│ flask-app-ghi    1/1   Running 1m   │  ← NEW!
│ flask-app-jkl    1/1   Running 30s  │  ← NEW!
└─────────────────────────────────────┘

Caption: "Pod count increased from 2 to 4 - autoscaling triggered!"
```

### Screenshot 3: HPA Events
```
Show this output:
┌────────────────────────────────────────────────────────┐
│ kubectl describe hpa flask-hpa -n flask-mongodb        │
│                                                         │
│ Events:                                                │
│ Type    Reason                Message                 │
│ ----    ------                -------                 │
│ Normal  SuccessfulRescaleEvent Scaled from 2 to 3    │
│ Normal  SuccessfulRescaleEvent Scaled from 3 to 4    │
│ Normal  SuccessfulRescaleEvent Scaled from 4 to 5    │
└────────────────────────────────────────────────────────┘

Caption: "Kubernetes automatically scaled pods based on CPU load"
```

### Screenshot 4: CPU Metrics
```
Show this output:
┌────────────────────────────────────────┐
│ kubectl top pods -n flask-mongodb      │
│                                        │
│ NAME           CPU(m)   MEMORY(Mi)    │
│ flask-app-abc  245m     180Mi         │  ← HIGH CPU
│ flask-app-def  230m     175Mi         │  ← HIGH CPU
│ flask-app-ghi  210m     160Mi         │  ← HIGH CPU
│ flask-app-jkl  198m     155Mi         │  ← HIGH CPU
│ mongo-0        45m      320Mi         │
└────────────────────────────────────────┘

Caption: "Each pod using ~200-250m CPU (exceeds 70% threshold)"
```

---

## PART 5: What to Tell Your HR Manager

**Say this:**

> "Our Kubernetes autoscaling setup meets all requirements:
>
> **1. Minimum & Maximum Replicas:**
> - Starts with 2 pods (minimum requirement)
> - Can scale up to 5 pods (maximum requirement)
> - Currently running 4 pods under load
>
> **2. CPU-Based Scaling:**
> - Target threshold: 70% CPU utilization
> - Current CPU: 72% per pod
> - HPA automatically scaled from 2 → 4 pods
>
> **3. Scaling Events:**
> - [Show HPA Events from kubectl describe]
> - Shows exact times when pods were added
> - Kubernetes managed everything automatically
>
> **4. Database Persistence:**
> - MongoDB StatefulSet keeps data safe during scaling
> - Flask pods can be added/removed without data loss
> - DNS resolution works seamlessly (mongo-0.mongo.flask-mongodb.svc.cluster.local)
>
> **5. Resource Management:**
> - Flask: requests 200m CPU, limits 500m CPU
> - MongoDB: requests 200m CPU, limits 500m CPU
> - This ensures fair resource allocation
>
> When traffic stops, it automatically scales down to 2 pods to save resources."

---

## PART 6: Test Log Files to Show HR

After running the test, show these files:

```powershell
# View the test results log
type hpa-test-*.log | more

# Show autoscaling documentation
type AUTOSCALING-TESTING.md | more

# Show HPA configuration
type k8s/07-hpa.yaml | more
```

---

## PART 7: Quick Reference Commands

### Check Everything is Working
```powershell
# Overall cluster health
kubectl get all -n flask-mongodb

# Flask app readiness
kubectl get deployment flask-app -n flask-mongodb -o wide

# HPA readiness
kubectl get hpa -n flask-mongodb

# Database connectivity
kubectl exec -it mongo-0 -n flask-mongodb -- mongosh -u flaskuser -p flaskpass123 --authenticationDatabase admin flask_db --eval "db.data.count()"

# Recent scaling events
kubectl describe hpa flask-hpa -n flask-mongodb | grep -A 20 "Events:"
```

### If Something Isn't Working
```powershell
# Check pod logs
kubectl logs -n flask-mongodb flask-app-xxxxx
kubectl logs -n flask-mongodb mongo-0

# Check events
kubectl get events -n flask-mongodb

# Describe pod for status/errors
kubectl describe pod -n flask-mongodb flask-app-xxxxx

# Check HPA status in detail
kubectl describe hpa -n flask-mongodb flask-hpa
```

---

## FINAL CHECKLIST Before Showing HR

- [ ] Minikube is running: `minikube status` shows "Running"
- [ ] All pods are Running: `kubectl get pods -n flask-mongodb` shows all with status "Running"
- [ ] HPA is Ready: `kubectl get hpa -n flask-mongodb` shows "READY = True"
- [ ] Flask app responds: `curl http://localhost:5000/` returns welcome message
- [ ] MongoDB has data: `kubectl get pods mongo-0 -n flask-mongodb` shows Running
- [ ] Test script ready: `.\hpa-complete-test.ps1` exists in project folder
- [ ] Documentation ready: `AUTOSCALING-TESTING.md` ready to show
- [ ] GitHub updated: All changes pushed to GitHub (https://github.com/Yashika-code/Flask-mongodb-kubernetes)

---

## How to Run Live Demo for HR (Recommended)

```powershell
# Step 1: Show baseline state
Write-Host "=== BEFORE AUTOSCALING ===" -ForegroundColor Green
kubectl get pods -n flask-mongodb
kubectl get hpa -n flask-mongodb

# Step 2: Run load generator
Write-Host "=== STARTING LOAD ===" -ForegroundColor Yellow
kubectl run -n flask-mongodb load-demo --image=busybox --restart=Never -- sh -c 'i=0; while [ $i -lt 30 ]; do wget -q -O- http://flask-service:5000/ 2>/dev/null & sleep 0.1; i=$((i+1)); done; wait'

# Step 3: Wait and show scaling
Start-Sleep -Seconds 15

Write-Host "=== AUTOSCALING IN ACTION ===" -ForegroundColor Cyan
kubectl get pods -n flask-mongodb
kubectl top pods -n flask-mongodb
kubectl get hpa -n flask-mongodb

# Step 4: Show events
Write-Host "=== SCALING EVENTS ===" -ForegroundColor Magenta
kubectl describe hpa -n flask-mongodb flask-hpa | grep -A 10 "Events:"

# Step 5: Explain
Write-Host "Pod count increased from 2 to $(kubectl get pods -n flask-mongodb --no-headers | wc -l) automatically!" -ForegroundColor Green
```

---

**That's it! Run these commands and your HR manager will see autoscaling working perfectly! 🎉**
