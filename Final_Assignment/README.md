# Flask + MongoDB + Kubernetes (Minikube) — Complete Project

## Overview
This project demonstrates deploying a Flask app that uses MongoDB on a Kubernetes cluster (Minikube).
Includes: StatefulSet for MongoDB (with authentication), PV/PVC, Flask Deployment (2+ replicas),
Service (ClusterIP/NodePort), and HPA (autoscale CPU 70%, min 2 max 5).

## Prerequisites
- Docker installed
- Minikube installed and running
- kubectl installed
- (Optional) Docker Hub account if you want to push image
- (Optional) `hey` or `ab` for load testing; else use busybox wget loops

## 1) Start minikube
minikube start --driver=docker

## 2) Use minikube's docker daemon (so you can build image local without pushing)
# Bash:
eval $(minikube -p minikube docker-env)
# Windows PowerShell:
# & minikube -p minikube docker-env --shell powershell | Invoke-Expression

## 3) Build Docker image (local in minikube's docker)
docker build -t flask-mongo:latest .

## 4) Create namespace (optional)
kubectl apply -f k8s/namespace.yaml

## 5) Create secret (if you prefer kubectl to create it directly)
kubectl create secret generic mongo-root-credentials \
  --from-literal=mongo-root-username=root \
  --from-literal=mongo-root-password=example123 \
  -n flask-mongo

# or apply the provided YAML:
kubectl apply -f k8s/mongo-secret.yaml

## 6) Deploy MongoDB StatefulSet + Services + (optional PV)
kubectl apply -f k8s/mongo-service.yaml
kubectl apply -f k8s/mongo-statefulset.yaml
# If you want a hostPath PV for data persist (minikube), apply:
kubectl apply -f k8s/mongo-pv-pvc.yaml

# Wait for mongo to be ready:
kubectl get pods -n flask-mongo -w

## 7) Deploy Flask app
# Edit `flask-deployment.yaml` image field if you pushed to DockerHub (e.g. yourdockeruser/flask-mongo:latest).
kubectl apply -f k8s/flask-deployment.yaml
kubectl apply -f k8s/flask-service.yaml

# Check deployments
kubectl get deployments,rs,pods -n flask-mongo

## 8) Install metrics-server (required for HPA)
# metrics-server is not usually installed in minikube, install it:
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Wait a few seconds then verify metrics-server starts:
kubectl get pods -n kube-system | grep metrics-server

# Also verify node metrics are available:
kubectl top nodes

## 9) Deploy HPA
kubectl apply -f k8s/flask-hpa.yaml

# Check HPA:
kubectl get hpa -n flask-mongo

## 10) Access the Flask app
# Option A: NodePort - find port:
kubectl get svc -n flask-mongo flask-service
# If NodePort is used, run:
minikube service flask-service -n flask-mongo --url

# Option B: port-forward:
kubectl port-forward svc/flask-service 8080:80 -n flask-mongo
# then open http://localhost:8080/

## 11) Test endpoints
# GET /
curl http://<MINIKUBE_URL_OR_LOCAL>/ or curl http://localhost:8080/

# POST /data
curl -X POST -H "Content-Type: application/json" -d '{"sampleKey":"sampleValue"}' http://<...>/data

# GET /data
curl http://<...>/data

## 12) Trigger load (to cause HPA to scale)
# Option 1: use hey (recommended)
# install hey: https://github.com/rakyll/hey
hey -z 120s -q 10 -c 50 http://<MINIKUBE_URL_OR_LOCAL>/  # 2 minutes of steady requests

# Option 2: busybox pod doing wget loop (simpler, may not create sufficient CPU pressure)
kubectl run load-generator -n flask-mongo --image=busybox --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://flask-service.flask-mongo.svc.cluster.local/; done"

# Now watch HPA and pods:
kubectl get hpa -n flask-mongo -w
kubectl get pods -n flask-mongo -w

## 13) Check HPA details & CPU usage
kubectl describe hpa flask-app-hpa -n flask-mongo
kubectl top pods -n flask-mongo

## Expected HPA behavior
- When average CPU across pods > 70%, HPA will increase replicas (up to 5).
- When CPU falls below the target, HPA will scale down (minimum 2 replicas).

## Notes on building/pushing image to Docker Hub (if not using minikube docker)
docker build -t yourdockerhubuser/flask-mongo:latest .
docker login
docker push yourdockerhubuser/flask-mongo:latest
# Then edit flask-deployment.yaml image to that name and apply.

## Cleanup
kubectl delete namespace flask-mongo
# Or individually:
kubectl delete -f k8s/flask-hpa.yaml
kubectl delete -f k8s/flask-service.yaml
kubectl delete -f k8s/flask-deployment.yaml
kubectl delete -f k8s/mongo-statefulset.yaml
kubectl delete -f k8s/mongo-service.yaml
kubectl delete secret mongo-root-credentials -n flask-mongo

