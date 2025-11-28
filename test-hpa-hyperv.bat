@echo off
REM Run autoscaling test with Hyper-V driver
REM Must run as Administrator

echo ===============================================
echo Flask MongoDB - HPA Autoscaling Test (Hyper-V)
echo ===============================================
echo.

echo [STEP 1] Starting Minikube with Hyper-V driver...
minikube start --driver=hyperv --cpus=2 --memory=4096
if errorlevel 1 (
    echo ERROR: Minikube start failed. Ensure Hyper-V is enabled.
    pause
    exit /b 1
)
echo OK: Minikube started
echo.

echo [STEP 2] Enabling metrics-server addon...
minikube addons enable metrics-server
timeout /t 10 /nobreak
echo OK: Metrics-server enabled
echo.

echo [STEP 3] Building Docker image...
docker build -t flask-mongodb-app:latest .
if errorlevel 1 (
    echo ERROR: Docker build failed.
    pause
    exit /b 1
)
echo OK: Image built
echo.

echo [STEP 3b] Loading image into Minikube...
minikube image load flask-mongodb-app:latest
echo OK: Image loaded
echo.

echo [STEP 4] Applying Kubernetes manifests...
kubectl apply -f k8s/01-namespace.yaml
kubectl apply -f k8s/02-secret.yaml
kubectl apply -f k8s/03-configmap.yaml
kubectl apply -f k8s/04-pv-pvc.yaml
kubectl apply -f k8s/05-mongodb-statefulset.yaml
timeout /t 15 /nobreak
kubectl apply -f k8s/06-flask-deployment.yaml
kubectl apply -f k8s/07-hpa.yaml
echo OK: Manifests applied
echo.

echo [STEP 5] Waiting for pods to initialize (30 seconds)...
timeout /t 30 /nobreak
echo OK: Initialization complete
echo.

echo ========== STATUS BEFORE LOAD ==========
echo.
echo HPA Status:
kubectl get hpa -n flask-mongodb -o wide
echo.
echo Pod Status:
kubectl get pods -n flask-mongodb -o wide
echo.
echo Pod Metrics:
kubectl top pods -n flask-mongodb 2>nul || echo (metrics not available yet)
echo.

echo [STEP 6] Generating in-cluster load (20 requests)...
kubectl run -n flask-mongodb load-gen --image=busybox --restart=Never -- sh -c "i=0; while [ $i -lt 20 ]; do wget -q -O- http://flask-service:5000/ 2>/dev/null; sleep 0.2; i=$((i+1)); done"
timeout /t 40 /nobreak
echo OK: Load generation complete
echo.

echo ========== STATUS AFTER LOAD (AUTOSCALING RESULTS) ==========
echo.
echo HPA Status:
kubectl get hpa -n flask-mongodb -o wide
echo.
echo HPA Details:
kubectl describe hpa -n flask-mongodb flask-hpa
echo.
echo Pod Status:
kubectl get pods -n flask-mongodb -o wide
echo.
echo Pod Metrics:
kubectl top pods -n flask-mongodb 2>nul || echo (metrics not available)
echo.

echo ===============================================
echo Test Complete!
echo ===============================================
echo.
echo AUTOSCALING VERIFICATION:
echo Look for:
echo   1. HPA READY = True
echo   2. Pod count increased (1 to 2-5 replicas)
echo   3. CPU Utilization in HPA Details
echo   4. Scaling events in HPA Events section
echo.
pause
