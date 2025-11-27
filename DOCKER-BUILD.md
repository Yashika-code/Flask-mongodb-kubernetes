# Docker Build and Push Instructions

## Building the Docker Image

### Step 1: Prerequisites

Ensure you have:
- Docker installed and running
- Docker CLI configured
- Access to container registry (Docker Hub, ECR, GCR, or private registry)

### Step 2: Build Locally

```bash
# Navigate to project directory
cd flask-mongodb-app

# Build Docker image
docker build -t flask-mongodb-app:latest .

# Build with specific tag (versioning)
docker build -t flask-mongodb-app:v1.0 .

# Build for specific platform (if needed)
docker build --platform linux/amd64 -t flask-mongodb-app:latest .
docker build --platform linux/arm64 -t flask-mongodb-app:latest .

# Build with build arguments
docker build \
  --build-arg PYTHON_VERSION=3.11 \
  -t flask-mongodb-app:latest .
```

### Step 3: Test Image Locally

```bash
# Run container locally with port mapping
docker run -p 5000:5000 \
  -e MONGODB_URI=mongodb://localhost:27017/ \
  -e MONGO_INITDB_DATABASE=flask_db \
  flask-mongodb-app:latest

# Test endpoints
curl http://localhost:5000/
curl http://localhost:5000/health

# Run with environment file
docker run -p 5000:5000 \
  --env-file .env \
  flask-mongodb-app:latest

# Run with MongoDB in Docker Compose (for testing)
docker-compose up --build
```

### Step 4: Tag Image for Registry

#### Docker Hub
```bash
# Tag for Docker Hub
docker tag flask-mongodb-app:latest <your-dockerhub-username>/flask-mongodb-app:latest
docker tag flask-mongodb-app:latest <your-dockerhub-username>/flask-mongodb-app:v1.0

# Login to Docker Hub
docker login

# Push to Docker Hub
docker push <your-dockerhub-username>/flask-mongodb-app:latest
docker push <your-dockerhub-username>/flask-mongodb-app:v1.0
```

#### AWS ECR (Elastic Container Registry)
```bash
# Get login token
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Tag for ECR
docker tag flask-mongodb-app:latest \
  <account-id>.dkr.ecr.us-east-1.amazonaws.com/flask-mongodb-app:latest

# Push to ECR
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/flask-mongodb-app:latest
```

#### Google Container Registry (GCR)
```bash
# Configure Docker authentication
gcloud auth configure-docker

# Tag for GCR
docker tag flask-mongodb-app:latest \
  gcr.io/<project-id>/flask-mongodb-app:latest

# Push to GCR
docker push gcr.io/<project-id>/flask-mongodb-app:latest
```

#### Azure Container Registry (ACR)
```bash
# Login to ACR
az acr login --name <registry-name>

# Tag for ACR
docker tag flask-mongodb-app:latest \
  <registry-name>.azurecr.io/flask-mongodb-app:latest

# Push to ACR
docker push <registry-name>.azurecr.io/flask-mongodb-app:latest
```

#### Private Registry
```bash
# Tag for private registry
docker tag flask-mongodb-app:latest \
  <registry-host>:5000/flask-mongodb-app:latest

# Push to private registry
docker push <registry-host>:5000/flask-mongodb-app:latest
```

### Step 5: For Minikube Development

```bash
# Build image for Minikube
docker build -t flask-mongodb-app:latest .

# Load image into Minikube (preferred method)
minikube image load flask-mongodb-app:latest

# Alternative: Build directly in Minikube
eval $(minikube docker-env)
docker build -t flask-mongodb-app:latest .
eval $(minikube docker-env -u)  # Reset Docker context
```

## Dockerfile Optimization

The provided Dockerfile uses best practices:

### Security
- ✅ Non-root user (appuser)
- ✅ Minimal base image (python:3.9-slim)
- ✅ No unnecessary privileges

### Performance
- ✅ Multi-stage build considerations
- ✅ Layer caching optimization
- ✅ Minimal layer count

### Reliability
- ✅ Health checks defined
- ✅ Proper signal handling
- ✅ Environment variable configuration

## Dockerfile Contents

```dockerfile
FROM python:3.9-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy and install requirements
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Create non-root user
RUN useradd -m appuser && chown -R appuser /app
USER appuser

# Copy application code
COPY --chown=appuser:appuser . .

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Run application
CMD ["python", "app.py"]
```

## Image Size Optimization

```bash
# Check image size
docker images flask-mongodb-app

# Analyze layers
docker history flask-mongodb-app:latest

# Expected size: ~200-300MB
# - Base image (python:3.9-slim): ~150MB
# - Dependencies: ~50-100MB
# - Application code: ~1MB
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Build and Push Docker Image

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v1
    
    - name: Login to Docker Hub
      uses: docker/login-action@v1
      with:
        username: ${{ secrets.DOCKERHUB_USERNAME }}
        password: ${{ secrets.DOCKERHUB_TOKEN }}
    
    - name: Build and push
      uses: docker/build-push-action@v2
      with:
        context: .
        push: true
        tags: |
          ${{ secrets.DOCKERHUB_USERNAME }}/flask-mongodb-app:latest
          ${{ secrets.DOCKERHUB_USERNAME }}/flask-mongodb-app:${{ github.sha }}
```

## Troubleshooting

### Build Fails with "pip install" Error

```bash
# Clean build cache
docker build --no-cache -t flask-mongodb-app:latest .

# Check requirements.txt syntax
cat requirements.txt
```

### Image Too Large

```bash
# Use alpine instead of slim (if compatible)
# FROM python:3.9-alpine

# Or remove unnecessary dependencies from requirements.txt
# Or use multi-stage build for production
```

### Container Doesn't Start

```bash
# Check logs
docker run -it flask-mongodb-app:latest

# Verify app.py exists
docker run -it flask-mongodb-app:latest ls -la /app/

# Check Python installation
docker run -it flask-mongodb-app:latest python --version
```

## Summary

✅ **Build Process**:
1. Build Docker image locally
2. Test image with local container
3. Tag for target registry
4. Push to registry
5. Use in Kubernetes deployment

✅ **Best Practices**:
- Use specific base image versions
- Run as non-root user
- Include health checks
- Minimize layer count
- Cache dependencies
- Use .dockerignore for cleanup

