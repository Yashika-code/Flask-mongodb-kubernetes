#!/usr/bin/env pwsh
# test-hpa-admin.ps1 - Run HPA test with admin elevation if needed

# Check if running as admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Output "This script requires Administrator privileges."
    Write-Output "Attempting to re-run as Administrator..."
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoExit", "-Command", "Set-Location '$PWD'; & '$PSCommandPath'"
    exit
}

Write-Output "==============================================="
Write-Output "Flask MongoDB - HPA Autoscaling Test (Hyper-V)"
Write-Output "==============================================="
Write-Output ""

Write-Output "[STEP 1] Starting Minikube..."
minikube start --driver=hyperv --cpus=2 --memory=4096
Start-Sleep -Seconds 15

Write-Output "[STEP 2] Enabling metrics-server..."
minikube addons enable metrics-server
Start-Sleep -Seconds 10

Write-Output "[STEP 3] Building and loading Docker image..."
docker build -t flask-mongodb-app:latest .
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

Write-Output "[STEP 5] Waiting for pods to initialize (30 seconds)..."
Start-Sleep -Seconds 30

Write-Output ""
Write-Output "========== STATUS BEFORE LOAD =========="
kubectl get hpa -n flask-mongodb -o wide
Write-Output ""
kubectl get pods -n flask-mongodb -o wide
Write-Output ""
kubectl top pods -n flask-mongodb

Write-Output ""
Write-Output "[STEP 6] Generating load (20 requests)..."
$cmd = 'i=0; while [ $i -lt 20 ]; do wget -q -O- http://flask-service:5000/ 2>/dev/null; sleep 0.2; i=$((i+1)); done'
kubectl run -n flask-mongodb load-gen --image=busybox --restart=Never -- sh -c $cmd
Start-Sleep -Seconds 40

Write-Output ""
Write-Output "========== STATUS AFTER LOAD =========="
Write-Output "HPA Status:"
kubectl get hpa -n flask-mongodb -o wide
Write-Output ""
Write-Output "HPA Details (Scaling Events):"
kubectl describe hpa -n flask-mongodb flask-hpa
Write-Output ""
Write-Output "Pod Status:"
kubectl get pods -n flask-mongodb -o wide
Write-Output ""
Write-Output "Pod CPU Metrics:"
kubectl top pods -n flask-mongodb

Write-Output ""
Write-Output "==============================================="
Write-Output "Test Complete!"
Write-Output "==============================================="
Write-Output ""
Write-Output "AUTOSCALING CHECK:"
Write-Output "  1. HPA READY should be True"
Write-Output "  2. Pod count should increase (1 -> 2-5 replicas)"
Write-Output "  3. Current CPU should be above 30%"
Write-Output "  4. HPA Events should show scaling activities"
