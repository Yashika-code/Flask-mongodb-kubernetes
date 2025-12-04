# Flask MongoDB Kubernetes Project with HPA

## Overview
This project demonstrates deploying a Python Flask application connected to MongoDB on Kubernetes with **Horizontal Pod Autoscaling (HPA)**. The setup includes:

- Flask app container
- MongoDB StatefulSet with authentication
- Kubernetes Deployment and Service
- Horizontal Pod Autoscaler (HPA) based on CPU utilization
- Load testing using a BusyBox pod

## Prerequisites
- Minikube installed
- kubectl installed
- Docker installed
- Basic knowledge of Kubernetes resources

## Project Structure
```

Assignment_Chatgpt/
├─ app.py
├─ Dockerfile
├─ requirement.txt
├─ README.md
└─ k8s/
├─ flask-deployment.yaml
├─ flask-service.yaml
├─ mongo-statefulset.yaml
├─ flask-hpa.yaml

````

## Setup Instructions

### 1. Start Minikube and Configure Docker
```bash
minikube start
eval $(minikube -p minikube docker-env)
````

### 2. Build Docker Image

```bash
docker build -t flask-mongo:latest .
```

### 3. Deploy MongoDB StatefulSet

```bash
kubectl apply -f k8s/mongo-statefulset.yaml -n flask-mongo
```

### 4. Deploy Flask Application

```bash
kubectl apply -f k8s/flask-deployment.yaml -n flask-mongo
kubectl apply -f k8s/flask-service.yaml -n flask-mongo
```

### 5. Apply HPA

```bash
kubectl apply -f k8s/flask-hpa.yaml -n flask-mongo
```

### 6. Verify Deployment

Check pods and services:

```bash
kubectl get pods -n flask-mongo
kubectl get svc -n flask-mongo
kubectl get hpa -n flask-mongo
```

### 7. Test Application and HPA

* Access Flask app via NodePort:

```bash
minikube service flask-service -n flask-mongo
```

* Simulate load using BusyBox pod:

```bash
kubectl run -it load --image=busybox --restart=Never -n flask-mongo -- /bin/sh
# Inside the pod:
while true; do wget -q -O- http://flask-service; done
```

* Monitor HPA scaling:

```bash
kubectl get hpa -n flask-mongo
kubectl top pods -n flask-mongo
```

## Key Features

* MongoDB StatefulSet with authentication
* Flask app deployment with Docker image
* Horizontal Pod Autoscaler (HPA) monitoring CPU utilization
* Load testing setup to trigger autoscaling

## Screenshots

* HPA status and pod metrics (included in submission)

## Author

**Yashika Soni**

