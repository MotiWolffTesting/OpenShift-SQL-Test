# OpenShift SQL Test Project

## Project Overview
This project demonstrates a complete FastAPI application deployed on OpenShift with MySQL database integration. The service exposes a GET endpoint that returns data from a MySQL table.

## Architecture
- **Frontend**: OpenShift Route exposing the FastAPI service
- **Backend**: FastAPI application (Python) 
- **Database**: MySQL 8.0 with persistent storage
- **Platform**: OpenShift Container Platform
- **Build Strategy**: Docker image from Docker Hub

## Prerequisites
- OpenShift CLI (`oc`) installed and configured
- Access to an OpenShift cluster
- Docker installed locally (for building and pushing)
- Docker Hub account
- Access to existing OpenShift project (e.g., `motiwolff-dev`)
- **Important**: macOS users must use `--platform linux/amd64` when building images

## Step-by-Step Setup Guide

### 1. Project Structure Setup
```bash
# Navigate to project root
cd "/Users/mordechaywolff/Desktop/IDF/8200 Training/Data/Week_7/OpenShift-SQL-Test"

# Verify project structure
ls -la
# Should show: Dockerfile, requirements.txt, services/, infrastructure/
```

### 2. OpenShift Project Selection
```bash
# Use existing project (you must have access)
export PROJECT_NAME=motiwolff-dev
oc project "$PROJECT_NAME"

# Verify access
oc get projects
```

### 3. MySQL Database Deployment

#### 3.1 Create MySQL Secret
```bash
# Create secret with database credentials
oc create secret generic mysql-secret \
  --from-literal=MYSQL_ROOT_PASSWORD=rootpass \
  --from-literal=MYSQL_USER=appuser \
  --from-literal=MYSQL_PASSWORD=apppass \
  --from-literal=MYSQL_DATABASE=appdb \
  --dry-run=client -o yaml | oc apply -f -
```

#### 3.2 Deploy MySQL
```bash
# Deploy MySQL using Bitnami image (OpenShift-friendly)
oc new-app --docker-image=bitnami/mysql:8.0 --name=mysql

# Set environment variables from secret
oc set env deploy/mysql --from=secret/mysql-secret

# Add persistent storage (creates PVC automatically)
oc set volume deploy/mysql --add --name=mysql-data --type=pvc --claim-size=1Gi --mount-path=/bitnami/mysql || true

# Wait for deployment to complete
oc rollout status deploy/mysql --watch=true

# Create service for internal communication
oc get svc mysql >/dev/null 2>&1 || oc expose deploy/mysql --port=3306 --target-port=3306 --name=mysql
```

#### 3.3 Verify MySQL Deployment
```bash
# Check pod status
oc get pods | grep mysql

# Should show: mysql-xxxxx-xxxxx 1/1 Running
```

### 4. FastAPI Application Deployment

#### 4.1 Build and Push Docker Image
```bash
# Build the image from your Dockerfile (IMPORTANT: use --platform linux/amd64)
docker build --platform linux/amd64 -t data-loader:latest .

# Tag it with your Docker Hub username
docker tag data-loader:latest YOUR_DOCKERHUB_USERNAME/openshift-sql-test:latest

# Login to Docker Hub (if not already logged in)
docker login

# Push to Docker Hub
docker push YOUR_DOCKERHUB_USERNAME/openshift-sql-test:latest
```

#### 4.2 Deploy FastAPI Application
```bash
# Deploy from Docker Hub image
oc new-app YOUR_DOCKERHUB_USERNAME/openshift-sql-test:latest --name=data-loader

# Set MySQL connection environment variables
oc set env deploy/data-loader \
  MYSQL_HOST=mysql \
  MYSQL_PORT=3306 \
  MYSQL_USER=appuser \
  MYSQL_PASSWORD=apppass \
  MYSQL_DATABASE=appdb

# Wait for deployment to complete
oc rollout status deploy/data-loader --watch=true
```

#### 4.3 Configure Application Runtime
```bash
# Set working directory and command for proper app execution
oc patch deploy data-loader --type='json' --patch='
[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/workingDir",
    "value": "/app/services/data_loader"
  },
  {
    "op": "add", 
    "path": "/spec/template/spec/containers/0/command",
    "value": ["uvicorn"]
  },
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args", 
    "value": ["app:app", "--host", "0.0.0.0", "--port", "8080"]
  }
]'
```

#### 4.4 Create Service and Route
```bash
# Create internal service
oc get svc data-loader >/dev/null 2>&1 || oc expose deploy/data-loader --port=8080 --target-port=8080 --name=data-loader

# Create external route
oc get route data-loader >/dev/null 2>&1 || oc expose svc/data-loader
```

### 5. Database Initialization

#### 5.1 Create Data Table
```bash
# Get current MySQL pod name
oc get pods | grep mysql

# Create table and insert sample data
oc exec mysql-5987f5d557-jz5c6 -- /opt/bitnami/mysql/bin/mysql -u'appuser' -p'apppass' -D 'appdb' -e "
CREATE TABLE IF NOT EXISTS data (
  id INT PRIMARY KEY,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL
);
INSERT INTO data (id, first_name, last_name) VALUES
 (1,'Noa','Levi'),(2,'Amit','Cohen'),(3,'Yonatan','Ben-David'),
 (4,'Lior','Mizrahi'),(5,'Tal','Shapiro')
ON DUPLICATE KEY UPDATE first_name=VALUES(first_name), last_name=VALUES(last_name);
"
```

**Note**: Use the actual current MySQL pod name from `oc get pods | grep mysql`

### 6. Application Testing

#### 6.1 Test Endpoint
```bash
# Get the route URL
oc get route data-loader

# Test the endpoint
curl "http://data-loader-motiwolff-dev.apps.rm3.7wse.p1.openshiftapps.com/data"
```

**Expected Response**:
```json
[
  {"id":1,"first_name":"Noa","last_name":"Levi"},
  {"id":2,"first_name":"Amit","last_name":"Cohen"},
  {"id":3,"first_name":"Yonatan","last_name":"Ben-David"},
  {"id":4,"first_name":"Lior","last_name":"Mizrahi"},
  {"id":5,"first_name":"Tal","last_name":"Shapiro"}
]
```

### 7. Application Configuration

### 8. Redeployment After Code Changes

```bash
# Rebuild and push new image (IMPORTANT: use --platform linux/amd64)
docker build --platform linux/amd64 -t data-loader:latest .
docker tag data-loader:latest YOUR_DOCKERHUB_USERNAME/openshift-sql-test:latest
docker push YOUR_DOCKERHUB_USERNAME/openshift-sql-test:latest

# Update deployment to use new image
oc set image deploy/data-loader data-loader=YOUR_DOCKERHUB_USERNAME/openshift-sql-test:latest

# Restart deployment
oc rollout restart deploy/data-loader
oc rollout status deploy/data-loader --watch=true
```

### 9. Useful Commands

#### 9.1 Check Status
```bash
# Check all resources
oc get all

# Check pods
oc get pods

# Check services
oc get svc

# Check routes
oc get route
```

#### 9.2 View Logs
```bash
# Get pod name first
oc get pods | grep data-loader

# View logs
oc logs <pod-name>

# Follow logs
oc logs -f <pod-name>
```

#### 9.3 Environment Variables
```bash
# List environment variables
oc set env deploy/data-loader --list

# Set environment variables
oc set env deploy/data-loader KEY=value
```

### 10. Project Structure
```
OpenShift-SQL-Test/
├── Dockerfile                    # Container definition
├── requirements.txt              # Python dependencies
├── README.md                     # This documentation
├── services/
│   └── data_loader/
│       ├── app.py               # FastAPI application
│       ├── base_model.py        # Pydantic models
│       └── data_loader.py       # Database access layer
└── infrastructure/
    └── k8s/                     # Kubernetes manifests (exported)
```

## Key Features

1. **Docker Hub Integration**: Standard container registry workflow
2. **Cross-Platform Builds**: `--platform linux/amd64` ensures OpenShift compatibility
3. **Persistent Storage**: PVCs provide data persistence across pod restarts
4. **Service Discovery**: Internal services enable pod-to-pod communication
5. **External Access**: Routes provide public access to services
6. **Environment Configuration**: Secure credential management via secrets
7. **Version Control**: Easy image versioning and rollback capabilities

## Next Steps

- Add health checks and readiness probes
- Implement proper error handling and logging
- Add authentication and authorization
- Set up monitoring and alerting
- Create CI/CD pipeline for automated deployments
- Add database migrations and backup strategies

## Verification Commands

To verify your deployment is working correctly:
1. Check pod status: `oc get pods`
2. View application logs: `oc logs <pod-name>`
3. Check environment variables: `oc set env deploy/<name> --list`
4. Verify resource status: `oc get all`
5. Test the endpoint: `curl <route-url>/data`
