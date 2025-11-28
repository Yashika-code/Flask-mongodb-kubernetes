#!/usr/bin/env pwsh
# run-hpa-test.ps1 - Test HPA autoscaling on Minikube

Write-Output "==============================================="
Write-Output "Flask MongoDB - HPA Autoscaling Test"
Write-Output "==============================================="
Write-Output ""

# Check prerequisites
Write-Output "Checking prerequisites..."
minikube status
kubectl version --client

Write-Output ""
Write-Output "[STEP 1] Starting Minikube..."
minikube start --driver=docker --memory=4096 --cpus=2
Start-Sleep -Seconds 10

Write-Output "[STEP 2] Enabling metrics-server..."
minikube addons enable metrics-server
Start-Sleep -Seconds 10

Write-Output "[STEP 3] Building Docker image..."
docker build -t flask-mongodb-app:latest .
Write-Output "[STEP 3b] Loading image to minikube..."
minikube image load flask-mongodb-app:latest

Write-Output "[STEP 4] Applying Kubernetes manifests..."
kubectl apply -f k8s/01-namespace.yaml
kubectl apply -f k8s/02-secret.yaml
kubectl apply -f k8s/03-configmap.yaml
kubectl apply -f k8s/04-pv-pvc.yaml
kubectl apply -f k8s/05-mongodb-statefulset.yaml
Start-Sleep -Seconds 15
kubectl apply -f k8s/06-flask-deployment.yaml
kubectl apply -f k8s/07-hpa.yaml

Write-Output "[STEP 5] Waiting for pods to initialize (30 sec)..."
Start-Sleep -Seconds 30

Write-Output ""
Write-Output "==== STATUS BEFORE LOAD ===="
kubectl get hpa -n flask-mongodb
kubectl get pods -n flask-mongodb -o wide
kubectl top pods -n flask-mongodb
kubectl describe hpa -n flask-mongodb flask-hpa | head -20

Write-Output ""
Write-Output "[STEP 6] Generating load..."
$cmd = 'i=0; while [ $i -lt 15 ]; do wget -q -O- http://flask-service:5000/ > /dev/null 2>&1; sleep 0.3; i=$((i+1)); done'
kubectl run -n flask-mongodb load-generator --image=busybox --restart=Never -- sh -c $cmd
Start-Sleep -Seconds 35

Write-Output ""
Write-Output "==== STATUS AFTER LOAD ===="
kubectl get hpa -n flask-mongodb -o wide
kubectl get pods -n flask-mongodb -o wide
kubectl top pods -n flask-mongodb
kubectl describe hpa -n flask-mongodb flask-hpa

Write-Output ""
Write-Output "==== TEST COMPLETE ===="
Write-Output "RESULTS:"
Write-Output "  - Check HPA READY = True"
Write-Output "  - Check pod replicas increased (1 -> 2-5)"
Write-Output "  - Check CPU Utilization in HPA"
Write-Output "==============================================="
