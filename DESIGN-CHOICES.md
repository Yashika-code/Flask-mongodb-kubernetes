# Design Choices and Architecture Documentation

## Overview

This document details architectural decisions made for the Flask-MongoDB Kubernetes deployment, including rationale, alternatives considered, and trade-offs.

---

## 1. Namespace Design

### Decision: Dedicated `flask-mongodb` Namespace

### Rationale
- **Isolation**: Separates application from system components and other workloads
- **RBAC**: Easier to apply role-based access control policies
- **Naming**: Prevents conflicts with other deployments
- **Resource Quotas**: Can apply quotas per namespace
- **Multi-tenancy**: Better multi-team management

### Implementation
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: flask-mongodb
```

### Alternatives Considered

| Alternative | Pros | Cons | Decision |
|------------|------|------|----------|
| Default namespace | No extra setup | Namespace pollution, conflicts | ❌ Rejected |
| Per-service namespace | Maximum isolation | Over-engineering, complexity | ❌ Rejected |
| Custom namespace | Clean organization | ✅ Selected |

---

## 2. MongoDB Deployment Strategy

### Decision: StatefulSet with Authentication

### Why StatefulSet?

```
Requirement: Persistent database with stable identity
```

#### StatefulSet Advantages
- ✅ Stable pod hostnames (`mongodb-0.mongodb-service`)
- ✅ Stable network identity
- ✅ Ordered pod startup/shutdown
- ✅ Persistent storage binding per replica
- ✅ Headless Service for DNS-based discovery

#### StatefulSet Architecture
```
mongodb-0 (primary)
  ├── Pod: mongodb container
  ├── Volume: PVC -> PV -> /mnt/data/mongodb
  └── Network: mongodb-0.mongodb-service.flask-mongodb.svc.cluster.local
```

### Authentication Implementation

**Password-Based Authentication**:
```yaml
MONGO_INITDB_ROOT_USERNAME: admin        # Root user
MONGO_INITDB_ROOT_PASSWORD: admin123     # Root password
mongo-username: flaskuser                # App user
mongo-password: flaskpass123             # App password
```

**Connection URI with Auth**:
```
mongodb://flaskuser:flaskpass123@mongodb-service.flask-mongodb.svc.cluster.local:27017/flask_db?authSource=admin
```

### Alternatives Considered

| Approach | Pros | Cons | Selected |
|----------|------|------|----------|
| Deployment + Deployment | Simpler | Data loss on restart, not stable | ❌ |
| StatefulSet | Stable identity, persistent | More complex | ✅ |
| Helm MongoDB | Production-ready | Overkill for learning | ❌ |
| MongoDB Atlas | Managed, easy | External dependency, not local | ❌ |

---

## 3. Storage Architecture

### Decision: PersistentVolume + PersistentVolumeClaim

### Storage Class Hierarchy
```
Storage Class
    ↓
PersistentVolume (5Gi at /mnt/data/mongodb)
    ↓
PersistentVolumeClaim (requests 5Gi)
    ↓
StatefulSet Pod Volume Mount (/data/db)
```

### Data Persistence Guarantee
```
Pod Restart → Data survives
Pod Deletion → Data survives (mounted PVC)
PVC Deletion → Data deleted (set reclaimPolicy: Retain for data recovery)
```

### Configuration
```yaml
# PersistentVolume
hostPath: /mnt/data/mongodb
accessModes: ReadWriteOnce
capacity: 5Gi
persistentVolumeReclaimPolicy: Retain

# PersistentVolumeClaim  
accessModes: ReadWriteOnce
resources: 5Gi
```

### Alternatives Considered

| Storage Type | Use Case | Pros | Cons | Selected |
|-------------|----------|------|------|----------|
| emptyDir | Temporary data | Fast, simple | Data lost on restart | ❌ |
| hostPath | Development, single node | Local, fast | Not portable, single node | ✅ For Minikube |
| NFS | Multi-node | Portable | Higher latency, complex | ❌ |
| Cloud Volume | Production | Managed, replicated | Vendor lock-in, cost | ❌ |

---

## 4. Flask Application Deployment

### Decision: Deployment with 2+ Replicas and RollingUpdate Strategy

### High Availability Setup
```
Deployment (flask-app)
├── Replica 1 (flask-app-xyz1)
├── Replica 2 (flask-app-xyz2)
└── Up to 5 (with HPA scaling)
```

### Rolling Update Strategy
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1           # Allow 1 extra pod during update
    maxUnavailable: 0     # Keep all pods available
```

### Update Sequence
```
Initial: [Pod1, Pod2]
Step 1:  [Pod1, Pod2, Pod_new1]  (maxSurge: +1)
Step 2:  [Pod2, Pod_new1, Pod_new2]  (Pod1 terminated)
Final:   [Pod_new1, Pod_new2]
```

### Benefits
- ✅ Zero downtime during updates
- ✅ Quick rollback capability
- ✅ Gradual traffic shifting
- ✅ Health check validation per pod

### Alternatives Considered

| Strategy | Description | Downtime | Rollback | Selected |
|----------|-------------|----------|----------|----------|
| Recreate | Delete all, create new | High (full restart) | Slow | ❌ |
| RollingUpdate | Gradual replacement | None | Fast | ✅ |
| Blue-Green | Duplicate entire deployment | None | Instant | ❌ Over-complex |
| Canary | Gradual traffic shift | None | Medium | ❌ Requires traffic control |

---

## 5. Service Networking

### Decision: NodePort for Flask, Headless for MongoDB

#### Flask Service: NodePort
```yaml
type: NodePort
port: 5000           # Internal port
targetPort: 5000     # Container port
nodePort: 30000      # External access port (30000-32767 range)
```

**Why NodePort?**
- ✅ Works with Minikube easily
- ✅ External access to test
- ✅ No cloud provider needed
- ✅ Good for development/testing

**Access Method**:
```bash
curl http://<MINIKUBE_IP>:30000/
```

#### MongoDB Service: Headless (ClusterIP: None)
```yaml
type: ClusterIP
clusterIP: None      # Headless Service
```

**Why Headless?**
- ✅ Direct pod IP resolution
- ✅ No load balancing wrapper
- ✅ StatefulSet can reference pods by hostname
- ✅ Better for database-like services

**DNS Resolution**:
```
mongodb-0.mongodb-service.flask-mongodb.svc.cluster.local
```

### Alternatives Considered

| Service Type | Use | Pros | Cons | Selected |
|-------------|-----|------|------|----------|
| ClusterIP | Internal communication | Stable, simple | Not accessible externally | ❌ For Flask |
| NodePort | Development | Easy, no cloud provider | Limited to 30000-32767 | ✅ For Flask |
| LoadBalancer | Production | Cloud-native | Requires cloud provider, cost | ❌ For this setup |
| Ingress | Production routing | Multi-service routing | Complex, requires ingress controller | ❌ For this setup |
| Headless | StatefulSet discovery | Direct pod access, DNS | No VIP | ✅ For MongoDB |

---

## 6. Autoscaling Strategy

### Decision: HorizontalPodAutoscaler with CPU-based Scaling

### Scaling Configuration
```yaml
minReplicas: 2
maxReplicas: 5
targetCPUUtilization: 70%
```

### Scaling Behavior

**Scale Up**:
- Trigger: CPU > 70% for 1 minute
- Rate: +100% per minute (double pods)
- Max: 5 replicas

**Scale Down**:
- Trigger: CPU < 70% for 5 minutes  
- Rate: -50% per minute
- Min: 2 replicas

### Scaling Example
```
T=0:   Load starts, 2 pods, CPU increasing
T=30:  CPU reaches 80%, HPA triggered
T=60:  Scale to 3 pods (1 new pod starts)
T=120: Another pod, scale to 4
T=300: Load decreases, scale back to 2
```

### Why CPU-based Scaling?
1. **Available**: CPU metrics always available
2. **Predictable**: Correlates with request load
3. **Responsive**: Quick to scale up under load
4. **Simple**: No custom metrics needed

### Alternatives Considered

| Metric | Pros | Cons | Use Case |
|--------|------|------|----------|
| CPU | Available, reliable | Doesn't measure memory pressure | ✅ Selected |
| Memory | Measures RAM usage | Slower to respond, less predictable | ❌ |
| Custom metrics | Business-aware | Requires additional setup | ❌ For basic setup |
| Requests/sec | Direct metric | Requires monitoring stack | ❌ |

---

## 7. Health Checks (Probes)

### Decision: HTTP Probes on /health Endpoint

#### Liveness Probe
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 5000
  initialDelaySeconds: 15
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```

**Purpose**: Detect if pod is dead
**Action**: Kill pod → Kubernetes restarts

#### Readiness Probe
```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 5000
  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 2
```

**Purpose**: Detect if pod can handle traffic
**Action**: Remove from service endpoints if failing

### Health Check Implementation
```python
@app.route('/health', methods=['GET'])
def health_check():
    if client is not None and collection is not None:
        try:
            client.admin.command('ping')
            return jsonify({"status": "healthy"}), 200
        except Exception as e:
            return jsonify({"status": "unhealthy"}), 500
    return jsonify({"status": "unhealthy"}), 503
```

### Timing Rationale

| Parameter | Flask | MongoDB | Rationale |
|-----------|-------|---------|-----------|
| initialDelaySeconds | 15 | 30 | Startup time |
| periodSeconds | 10 | 10 | Check frequency |
| timeoutSeconds | 5 | 5 | Response time limit |
| failureThreshold | 3 | 3 | Before restart |

### Alternatives Considered

| Type | Method | Pros | Cons |
|------|--------|------|------|
| HTTP | GET /health | Application-aware | Requires endpoint |
| TCP | Port 5000 | Network-level | Doesn't validate app logic |
| Exec | Shell command | Flexible | Resource-intensive |

---

## 8. Resource Management

### Decision: Requests 0.2 CPU + 250Mi Memory, Limits 0.5 CPU + 500Mi

### Sizing Rationale

**Request Values** (Minimum guaranteed):
- CPU: 0.2 (20% of 1 core) → Can run 5 pods per core
- Memory: 250Mi → Can run 16 pods on 4GB Minikube

**Limit Values** (Maximum allowed):
- CPU: 0.5 (50% of 1 core) → 2.5x request
- Memory: 500Mi → 2x request

### Capacity Planning

**Minikube Node**: 4 CPU, 4GB RAM

**Flask Pods**:
```
Requests: 0.2 CPU × 5 pods = 1 CPU total
Requests: 250Mi × 5 pods = 1.25Gi total
→ Safe with 4 CPU, 4GB available
```

**MongoDB Pod**:
```
Requests: 0.2 CPU
Requests: 250Mi
→ Leaves room for Flask pods
```

### Resource Settings Justification

| Component | Request | Limit | Justification |
|-----------|---------|-------|---------------|
| Flask CPU | 0.2 | 0.5 | Light HTTP serving |
| Flask Mem | 250Mi | 500Mi | Python Flask overhead |
| MongoDB CPU | 0.2 | 0.5 | Depends on queries |
| MongoDB Mem | 250Mi | 500Mi | WiredTiger cache |

### Alternatives Considered

| Approach | Pros | Cons | Selected |
|----------|------|------|----------|
| No limits | Simple, flexible | Resource overcommit, crashes | ❌ |
| Low values (100m, 128Mi) | Resource efficient | Pod gets killed frequently | ❌ |
| High values (1, 1Gi) | Never killed | Wastes resources, fewer pods | ❌ |
| Measured approach | Balanced, reliable | Requires tuning | ✅ |

---

## 9. Secret and Configuration Management

### Decision: Kubernetes Secrets + ConfigMap

#### Secrets for Sensitive Data
```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: mongodb-secret
type: Opaque
stringData:
  mongo-root-username: admin
  mongo-root-password: admin123secure
  mongo-username: flaskuser
  mongo-password: flaskpass123
```

**Features**:
- ✅ Encrypted in etcd (with proper configuration)
- ✅ RBAC-controlled access
- ✅ Easy rotation
- ✅ Not in source code

#### ConfigMap for Non-Sensitive Configuration
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mongodb-config
data:
  init-mongo.js: |
    db.createUser({...})
```

**Features**:
- ✅ Non-sensitive data
- ✅ Easy to modify without rebuild
- ✅ Can mount as files

### Reference in Pod
```yaml
env:
- name: MONGO_ROOT_PASSWORD
  valueFrom:
    secretKeyRef:
      name: mongodb-secret
      key: mongo-root-password
```

### Alternatives Considered

| Method | Pros | Cons | Security |
|--------|------|------|----------|
| Hardcoded | Simple | In source code | ❌ Bad |
| Environment file | Flexible | File storage | Medium |
| ConfigMap | Easy, mounted | Plaintext storage | Low |
| Secret | Protected, RBAC | Requires etcd encryption | ✅ High |
| External Vault | Secure, rotating | Complex, external service | ✅ Best |

---

## 10. Authentication Approach

### Decision: Database-Level Authentication

### MongoDB Authentication Layers
```
1. Root User (admin): Full admin access
   - Username: admin
   - Password: admin123secure
   
2. App User (flaskuser): Limited access to flask_db
   - Username: flaskuser
   - Password: flaskpass123
   - Role: readWrite on flask_db
```

### Connection String with Auth
```
mongodb://flaskuser:flaskpass123@mongodb-service:27017/flask_db?authSource=admin
```

### Benefits
- ✅ Different credentials for different access levels
- ✅ Flask uses limited permissions
- ✅ Audit trail of which user did what
- ✅ Easy revocation of app user

### Alternatives Considered

| Approach | Pros | Cons | Selected |
|----------|------|------|----------|
| No auth | Simple | Insecure | ❌ |
| Same creds | All-powerful | No isolation, risky | ❌ |
| Root user for app | Works | Dangerous, over-privileged | ❌ |
| App-specific user | Least privilege | Extra setup | ✅ |
| LDAP/SASL | Enterprise | Complex, overkill | ❌ |

---

## Summary of Design Choices

| Component | Choice | Primary Reason |
|-----------|--------|----------------|
| Namespace | flask-mongodb | Isolation |
| MongoDB | StatefulSet | Persistence + stable identity |
| Storage | PV/PVC with hostPath | Data persistence |
| Flask | Deployment + RollingUpdate | HA + zero downtime |
| Scaling | HPA with CPU target | Responsive to load |
| Services | NodePort + Headless | Access + discovery |
| Health | HTTP probes | Application-aware |
| Resources | 0.2-0.5 CPU, 250-500Mi | Balanced for Minikube |
| Secrets | Kubernetes Secret | Secure, RBAC |
| Auth | App-specific user | Least privilege |

---

## Key Trade-offs

### Performance vs Simplicity
- **Choice**: Simpler architecture (easier to understand and maintain)
- **Trade-off**: Not optimal performance for production load

### Security vs Complexity
- **Choice**: Authentication enabled, but locally stored credentials
- **Trade-off**: Production would use vaults and encryption

### Portability vs Optimization
- **Choice**: Works across different Kubernetes clusters
- **Trade-off**: Minikube-specific setup (hostPath volume)

### Cost vs Reliability
- **Choice**: 2 minimum Flask replicas (cost-conscious but redundant)
- **Trade-off**: Single MongoDB (could scale with more setup)

---

## Lessons and Recommendations

### For Learning/Development
✅ This setup is excellent because:
- All components demonstrable locally
- Covers key Kubernetes concepts
- Secure practices included
- Auto-scaling working end-to-end

### For Production Deployment
🔄 Should consider:
- Cloud storage instead of hostPath
- MongoDB replica set (not single pod)
- Ingress instead of NodePort
- TLS for communication
- Proper secret management (Vault)
- Distributed database strategy
- Backup and disaster recovery

