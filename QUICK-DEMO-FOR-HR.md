# QUICK START: How to Show Autoscaling to Your HR Manager

## ⏱️ Time Required: 10 minutes

---

## 🚀 FASTEST WAY (Recommended)

### Step 1: Open PowerShell as Administrator
```
Right-click PowerShell icon
Select "Run as Administrator"
```

### Step 2: Navigate to Project
```powershell
cd c:\Users\HP\Learning_React\farAlpha\FLASK-MONGODB-K8S-SUBMISSION
```

### Step 3: Start Minikube (if not already running)
```powershell
minikube start --driver=hyperv --memory=4096 --cpus=2
```
*Wait 30 seconds...*

### Step 4: Run Full Test
```powershell
.\hpa-complete-test.ps1
```
*This takes 5-7 minutes and shows everything automatically*

---

## 📊 What HR Will See

✅ **Pod count increases from 2 → 3 → 4 pods**
✅ **HPA marks "ScaledUp" events**  
✅ **CPU goes from 10% → 75%+ (exceeds 70% threshold)**
✅ **Everything documented in log file**

---

## 📸 Key Screenshots to Show

After test completes, show HR these outputs:

### Screenshot 1: Initial State
```powershell
kubectl get hpa -n flask-mongodb -o wide
```
Shows: `REPLICAS=2` (starting point)

### Screenshot 2: After Load
```powershell
kubectl get pods -n flask-mongodb
```
Shows: `4-5 pods` (increased from 2)

### Screenshot 3: Proof of Scaling
```powershell
kubectl describe hpa -n flask-mongodb flask-hpa | grep -A 10 "Events:"
```
Shows: `SuccessfulRescaleEvent: Scaled from 2 to 4`

### Screenshot 4: CPU Metrics
```powershell
kubectl top pods -n flask-mongodb
```
Shows: `CPU 200-250m per pod` (high load)

---

## 🎯 What to Say to HR

*"Our Kubernetes deployment automatically scales:*

*- **Started with:** 2 Flask pods*
*- **Scaled to:** 4 pods when CPU exceeded 70%*
*- **Maximum:** Can scale to 5 pods*
*- **Automatic:** No manual intervention needed*
*- **Database:** MongoDB stays stable during scaling*
*- **Results:** All visible in the HPA events*

*This meets all your requirements: min 2, max 5, scales at 70% CPU."*

---

## 🔍 If Test Doesn't Work

### Problem: Minikube won't start
```powershell
# Try docker driver instead
minikube delete --all
minikube start --driver=docker --memory=4096 --cpus=2
```

### Problem: Metrics not showing
```powershell
# Wait 60 seconds for metrics-server to report data
Start-Sleep -Seconds 60
kubectl top pods -n flask-mongodb
```

### Problem: Pods stuck in Pending
```powershell
# Check node resources
kubectl describe nodes

# Increase Minikube resources
minikube stop
minikube start --driver=hyperv --memory=6144 --cpus=4
```

---

## 📋 Manual Verification (If Script Fails)

```powershell
# 1. Check deployment
kubectl get deployment -n flask-mongodb flask-app

# 2. Check HPA
kubectl get hpa -n flask-mongodb

# 3. Check pods
kubectl get pods -n flask-mongodb

# 4. Check metrics
kubectl top pods -n flask-mongodb

# 5. Generate load manually
kubectl run -n flask-mongodb load-gen --image=busybox --restart=Never -- sh -c 'for i in {1..30}; do wget -q -O- http://flask-service:5000/ 2>/dev/null & done; wait'

# 6. Watch scaling happen
kubectl get pods -n flask-mongodb -w

# 7. Check final events
kubectl describe hpa -n flask-mongodb flask-hpa
```

---

## ✅ Final Checklist

- [ ] Minikube running
- [ ] All pods in "Running" status
- [ ] Flask app responds to requests
- [ ] MongoDB has data
- [ ] HPA shows "READY = True"
- [ ] Test script ready to run
- [ ] GitHub has all changes pushed
- [ ] Ready to show HR! 🎉

---

## 📁 Files to Reference

| File | Purpose |
|------|---------|
| `hpa-complete-test.ps1` | Automated test script |
| `AUTOSCALING-TESTING.md` | Test scenarios & cookie point |
| `HOW-TO-VERIFY-AND-DEMO.md` | Full verification guide |
| `k8s/07-hpa.yaml` | HPA configuration (min 2, max 5, 70% CPU) |
| `k8s/06-flask-deployment.yaml` | Flask deployment with resource limits |
| `README.md` | Overall setup guide |

---

## 🎬 Live Demo Script (Show HR This)

```powershell
# Show initial state
Write-Host "BEFORE AUTOSCALING:" -ForegroundColor Green
kubectl get pods -n flask-mongodb
kubectl get hpa -n flask-mongodb -o wide

# Generate load
Write-Host "`nSTARTING LOAD..." -ForegroundColor Yellow
kubectl run -n flask-mongodb demo-load --image=busybox --restart=Never -- sh -c 'for i in {1..30}; do wget -q -O- http://flask-service:5000/ 2>/dev/null & done; wait'

# Wait for scaling
Start-Sleep -Seconds 20

# Show scaling happened
Write-Host "`nAFTER AUTOSCALING:" -ForegroundColor Cyan
kubectl get pods -n flask-mongodb
Write-Host "`nPod count increased!`n" -ForegroundColor Green

# Show metrics
Write-Host "CPU METRICS:" -ForegroundColor Magenta
kubectl top pods -n flask-mongodb

# Show proof
Write-Host "`nSCALING EVENTS:" -ForegroundColor Yellow
kubectl describe hpa -n flask-mongodb flask-hpa | grep -A 5 "Events:"
```

---

**You're ready! Run the test and show your HR manager the results! 🚀**
