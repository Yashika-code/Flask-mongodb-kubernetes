# Flask MongoDB Kubernetes Project with HPA

This repository contains a **Flask application** backed by **MongoDB**, fully deployed on **Kubernetes using Minikube**. It demonstrates containerization, Kubernetes resources (Deployments, StatefulSets, Services, Secrets), and **Horizontal Pod Autoscaling (HPA)** based on CPU utilization.

---

## 🧠 Overview

The architecture includes:

- A **Flask REST API** serving HTTP requests
- A **MongoDB StatefulSet** to persist data
- Kubernetes **Deployments**, **Services**, and **Secrets**
- **Horizontal Pod Autoscaler (HPA)** to scale the Flask app
- Load testing setup using a BusyBox pod

This project is ideal for learning Kubernetes fundamentals and autoscaling behavior with a real application.

---

## 📦 Repository Structure

```

Flask-mongodb-kubernetes/
├── Final_Assignment/
│   ├── app.py
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── k8s/
│   │   ├── flask-deployment.yaml
│   │   ├── flask-service.yaml
│   │   ├── mongo-statefulset.yaml
│   │   ├── flask-hpa.yaml
│   │   ├── mongo-secret.yaml
│   │   └── mongo-service.yaml
│   └── README.md
└── README.md

````

---

## 🚀 Getting Started

### 🔧 Prerequisites

Install the following tools before running the project:

- **Minikube** (for local Kubernetes cluster)
- **kubectl** (Kubernetes CLI)
- **Docker** (for building images locally)

---

## 🛠️ One‑Run Setup

Follow these steps to deploy the entire project on Minikube:

### 1. Start Minikube

```bash
minikube start --driver=docker
````

Enable the metrics server (required for HPA):

```bash
minikube addons enable metrics-server
```

---

### 2. Build the Flask Docker Image

Make sure Docker context is pointed to Minikube:

```bash
eval $(minikube -p minikube docker-env)
docker build -t flask-mongo:latest .
```

Confirm the image is listed:

```bash
minikube image ls
```

---

### 3. Create Kubernetes Namespace (optional)

```bash
kubectl create namespace flask-mongo
kubectl config set-context --current --namespace=flask-mongo
```

---

### 4. Deploy MongoDB

```bash
kubectl apply -f k8s/mongo-secret.yaml
kubectl apply -f k8s/mongo-statefulset.yaml
kubectl apply -f k8s/mongo-service.yaml
```

Verify pods:

```bash
kubectl get pods -n flask-mongo
```

---

### 5. Deploy the Flask App

```bash
kubectl apply -f k8s/flask-deployment.yaml
kubectl apply -f k8s/flask-service.yaml
```

---

### 6. Deploy Horizontal Pod Autoscaler

```bash
kubectl apply -f k8s/flask-hpa.yaml
```

---

## 📊 Verify Deployment

Check Pods:

```bash
kubectl get pods -n flask-mongo -o wide
```

Check Services:

```bash
kubectl get svc -n flask-mongo
```

Check HPA:

```bash
kubectl get hpa -n flask-mongo -w
```

---

## 🌐 Access the Flask App

Expose the Flask service externally:

```bash
minikube service flask-service -n flask-mongo
```

💡 On Windows with Docker driver, a localhost tunnel will be shown.

---

## 🔥 Simulate Load to Trigger HPA

Use a BusyBox pod to generate load:

```bash
kubectl run -it load-generator --image=busybox -n flask-mongo --restart=Never -- /bin/sh
# Inside the pod
while true; do wget -q -O- http://flask-service; done
```

Then watch HPA scale:

```bash
kubectl get hpa -n flask-mongo
kubectl top pods -n flask-mongo
```

---

## 🧾 Useful Commands

* **Restart pods:**

```bash
kubectl delete pod -l app=flask-app -n flask-mongo
```

* **View logs:**

```bash
kubectl logs -f <pod-name> -n flask-mongo
```

* **Check metrics:**

```bash
kubectl top pods -n flask-mongo
```

---

## 📌 Key Features

✔ Flask application running on Kubernetes
✔ MongoDB with persistent storage
✔ Secure credentials using Kubernetes Secrets
✔ Horizontal autoscaling with HPA
✔ Load generation for testing scalability

---

## 👩‍💻 Author

**Yashika Soni** — *This project was developed as part of a Kubernetes assignment demonstration.*

---
