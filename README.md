# Quilter Interview

Code available in public repository: [https://github.com/devopsegk/quilter\_tech\_interview](https://github.com/devopsegk/quilter_tech_interview) 

  

In my solution I created the following folder structure:

├── app.py

├── dockerfile            

├── manage.sh 

├── requirements.txt 

├── README

├── terraform/                

│   ├── main.tf

  

This solution meets the requirements listed under Details in the “Platform Engineer Take Home Assignment” document. 

## Files explanation:

  

app.py: Python + Flask was used to build this API. The version is pulled from an environment variable APP\_VERSION. I can easily set up routes that will respond to queries for healthz and version.

  

requirements.tx: This file specifies the version of Flask to install.

  

dockerfile: This builds a Docker image for the app.

  

terraform/main.tf: Terraform was used with the Kubernetes provider to deploy a Deployment and Service to the local Kind cluster. 

  

[required\_providers](https://github.com/devopsegk/quilter_tech_interview/blob/main/terraform/main.tf#L2): Pinning the provider version prevents surprise breakages when HashiCorp releases a new version.

Only the Kubernetes provider is needed, and this helps to keep the lock file tiny and the setup fast.

kubernetes [config\_path](https://github.com/devopsegk/quilter_tech_interview/blob/main/terraform/main.tf#L11): It was setup for ease and avoidance of hard-coded host/token. This works identically on the local laptop using Kind and in CI/CD if later there is a switch to cloud clusters (we would only need to run aws eks update-kubeconfig or gcloud container clusters get-credentials first).

[kubernets\_namespace](https://github.com/devopsegk/quilter_tech_interview/blob/main/terraform/main.tf#L14): Isolates this app from everything else (pods, services, network policies, RBAC).

[replicas = 1](https://github.com/devopsegk/quilter_tech_interview/blob/main/terraform/main.tf#L27) Local clusters such as Kind usually have limited RAM/CPU. 1 pod will make the cluster respond faster.

manage.sh: This script handles the lifecycle. It’s the script that allows developers to interact with the environment. ./[manage.sh](http://manage.sh) will give a summary of what it can do.

## How to Use

1.  Download the files in this repository to your local machine.
    
2.  Ensure that manage.sh is an executable file. (chmod 750)
    
3.  Run ./manage.sh start-cluster to spin up Kind.
    
4.  Run ./manage.sh deploy v1.0.0 to build, load, and deploy.
    
5.  Run ./manage.sh access-url in another terminal to access the API (e.g., curl http://localhost:8080/healthz or curl http://localhost:8080/version).
    
6.  Check logs with ./manage.sh logs.
    
7.  View running version with ./manage.sh versions.
    
8.  Update to a new version: ./manage.sh deploy v2.0.0 (Terraform will update the deployment).
    
9.  Tear down with ./manage.sh teardown-cluster.
    

  

## Future Improvements:

#### In general:

-   Version Control and Automation: Integrate with CI/CD tools like GitHub Actions to automate build/deploy/test cycles.
    
-   Modular Design: Keep the app, Docker, Terraform, and scripts separate so that it’s easier to swap tools such as Kind for cloud providers without the need to do a lot of code rewriting.
    
-   Environment Separation: Define stages like dev (local Kind), staging (small cloud cluster), and prod (full HA cluster). Use Terraform workspaces or variables to switch between them.
    
-   Testing: Add unit/integration tests (e.g., pytest for the API) and e2e tests (e.g., using kubectl or curl against endpoints) that run in CI.
    
-   Liveness/Readiness Probes: Add to Deployment for health checks.
    
-   Cluster HA: For real clusters, use multi-master control planes and etcd clustering.
    
-   Rolling Updates: Configure strategy { type = "RollingUpdate" } with maxUnavailable=1.
    
-   Backup/Restore: Use Velero for Kubernetes resources; integrate with CI for automated backups.
    

#### For CI/CD:

  

-   Pipeline Structure: On push/merge to main, trigger: 1) Build/test Docker image, 2) Push to a registry (e.g., Docker Hub, ECR), 3) Run Terraform apply for staging/prod.
    
-   Tools: GitHub Actions workflow could include steps for docker build/push, terraform init/plan/apply (with approvals for prod), and rollout monitoring.
    
-   Rollback: Use Kubernetes rolling updates and Terraform's state management for safe deployments/rollbacks.
    
-   Use signed commits, secret scanning in repos, and OIDC for Terraform to avoid long-lived credentials.
    

#### For Terraform:

  

-   Modules and Reusability: Break the main.tf into reusable modules. For example:
    

-   A kubernetes-app module that takes inputs like image, replicas, env\_vars, and outputs like service URL.
    
-   Use Terraform Registry modules for common resources (e.g., terraform-aws-modules/eks/aws for AWS EKS).
    

-   State Management: For real clusters, store state remotely (e.g., in S3 with DynamoDB locking for AWS) to enable team collaboration and prevent state conflicts.
    
-   Variables and Outputs: Expand variables for flexibility (e.g., var.cluster\_name, var.replicas). Add outputs for easy access.
    
-   Providers: For cloud, add the AWS provider and use data sources (e.g., data.aws\_eks\_cluster to reference existing clusters instead of local kubeconfig).
    
-   Best Practices: Enable terraform fmt/validate, use pre-commit hooks for linting, and integrate with CI for automated plans.
    

#### For Security Enhancements:

-   Container Security:
    

-   Use multi-stage Docker builds to minimize image size (e.g., build in one stage, run in a slim runtime).
    
-   Scan images with tools like Trivy or Clair in CI.
    
-   Run as non-root: Add USER 1000 in Dockerfile and securityContext in Kubernetes Deployment.
    

-   Kubernetes Security:
    

-   Network Policies: Add a kubernetes\_network\_policy in Terraform to restrict traffic (e.g., only allow ingress to port 5000 from specific sources).
    
-   RBAC: Use roles/rolebindings for the app's service account. Limit to get/list on necessary resources.
    
-   Secrets Management: Store sensitive env vars (e.g., future API keys) in Kubernetes Secrets, referenced in the Deployment. Use external managers like AWS Secrets Manager for prod.
    
-   API Security: Add authentication (e.g., JWT via Flask extensions) for endpoints if needed. Use HTTPS with cert-manager in Kubernetes.
    
-   Cluster-Wide: Enable Pod Security Standards (PSS) or Admission Controllers (e.g., OPA/Gatekeeper) to enforce policies.
    

#### For Scalability:

-   Use Horizontal Pod Autoscaler (HPA) in Terraform
    
-   Resource Requests/Limits: Add to Deployment spec to prevent resource starvation:
    
-   Load Balancing: Change Service type to LoadBalancer for cloud (e.g., AWS ELB). Add Ingress (e.g., nginx-ingress) for path-based routing.
    
-   Database/Caching: If the API grows, integrate external services (e.g., Redis for caching via env vars).
    

#### For Monitoring:

-    Add Prometheus/Grafana for metrics; scale based on custom metrics like request rate.
    

#### For High Availability:

  

-   Set replicas = 3 minimum in prod.
    

#### AWS-Specific Enhancements:

-   Networking: Use VPC with private subnets for nodes; ALB Ingress Controller for external access.
    
-   Storage: EBS CSI driver for persistent volumes if needed.
    
-   Monitoring/Logging: Integrate Amazon CloudWatch, or use AWS-managed Prometheus.
    
-   Security: IAM roles for service accounts (IRSA) instead of static creds; enable EKS audit logging.
    
-   Scalability/HA: Use Cluster Autoscaler; deploy across multiple AZs (e.g., 3 subnets in different AZs).
    

#### Cost Optimization: 

-   Spot instances for non-critical workloads; Karpenter for dynamic scaling.
