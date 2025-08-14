# OpenShift SQL Test Project - Commands
# Replace YOUR_DOCKERHUB_USERNAME with your actual Docker Hub username
# Replace motiwolff-dev with your actual OpenShift project name

# 1. Switch to existing OpenShift project
oc project motiwolff-dev

# 2. Deploy MySQL Database
oc new-app mysql:8.0 --name=mysql

# 3. Create MySQL PVC
oc set volume deploy/mysql --add --name=mysql-pvc --type=pvc --claim-size=1Gi --mount-path=/bitnami/mysql/data

# 4. Set MySQL environment variables
oc set env deploy/mysql \
  MYSQL_ROOT_PASSWORD=rootpass \
  MYSQL_DATABASE=appdb \
  MYSQL_USER=appuser \
  MYSQL_PASSWORD=apppass

# 5. Create MySQL service
oc expose deploy/mysql --port=3306 --target-port=3306

# 6. Wait for MySQL to be ready
oc rollout status deploy/mysql --watch=true

# 7. Initialize MySQL database
MYSQL_POD=$(oc get pod -l app=mysql -o jsonpath='{.items[0].metadata.name}')
oc exec "$MYSQL_POD" -- bash -lc "mysql -u'appuser' -p'apppass' -D 'appdb' -e \"CREATE TABLE IF NOT EXISTS data (id INT PRIMARY KEY, first_name VARCHAR(100) NOT NULL, last_name VARCHAR(100) NOT NULL); INSERT INTO data (id, first_name, last_name) VALUES (1,'Noa','Levi'),(2,'Amit','Cohen'),(3,'Yonatan','Ben-David'), (4,'Lior','Mizrahi'),(5,'Tal','Shapiro') ON DUPLICATE KEY UPDATE first_name=VALUES(first_name), last_name=VALUES(last_name);\""

# 8. Build and push Docker image
docker build --platform linux/amd64 -t data-loader:latest .
docker tag data-loader:latest YOUR_DOCKERHUB_USERNAME/openshift-sql-test:latest
docker push YOUR_DOCKERHUB_USERNAME/openshift-sql-test:latest

# 9. Deploy FastAPI application
oc new-app YOUR_DOCKERHUB_USERNAME/openshift-sql-test:latest --name=data-loader

# 10. Set MySQL connection environment variables
oc set env deploy/data-loader \
  MYSQL_HOST=mysql \
  MYSQL_PORT=3306 \
  MYSQL_USER=appuser \
  MYSQL_PASSWORD=apppass \
  MYSQL_DATABASE=appdb

# 11. Configure application runtime
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

# 12. Wait for FastAPI deployment
oc rollout status deploy/data-loader --watch=true

# 13. Create internal service
oc expose deploy/data-loader --port=8080 --target-port=8080

# 14. Create external route
oc expose svc/data-loader --name=data-loader

# 15. Get application URL
oc get route data-loader

# Useful commands for checking status
oc get pods
oc get svc
oc get route

# View logs
oc logs deploy/data-loader
oc logs deploy/mysql
