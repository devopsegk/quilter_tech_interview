#!/bin/bash

set -e

CLUSTER_NAME="minimal-api-cluster"
NAMESPACE="minimal-api"
APP_NAME="minimal-api"
DOCKER_IMAGE="minimal-api"
KUBE_CONTEXT="kind-$CLUSTER_NAME"

function usage() {
  echo "Usage: $0 <command> [args]"
  echo "Commands:"
  echo "  start-cluster                Spin up Kind cluster"
  echo "  teardown-cluster             Tear down Kind cluster"
  echo "  build <version>              Build Docker image with tag (e.g., v1.0.0)"
  echo "  deploy <version>             Deploy to Kubernetes via Terraform (builds if needed)"
  echo "  access-url                   Port-forward to access the API (Ctrl+C to stop)"
  echo "  logs                         View pod logs"
  echo "  versions                     List running deployment versions"
  exit 1
}

if [ $# -lt 1 ]; then
  usage
fi

COMMAND=$1
shift

case $COMMAND in
  start-cluster)
    if command -v kind &> /dev/null; then
        echo "Starting Kind cluster: $CLUSTER_NAME"
        kind create cluster --name $CLUSTER_NAME
        kubectl cluster-info --context $KUBE_CONTEXT
    else
        echo "Kind does not exist and must be installed first."
        echo "This is your architecture:"
        uname -a
        echo "Please install Kind according to your architecture, then repeat this command again."
    fi
    ;;

  teardown-cluster)
    if command -v kind &> /dev/null; then
        echo "Tearing down Kind cluster: $CLUSTER_NAME"
        kind delete cluster --name $CLUSTER_NAME
    else
        echo "Kind does not exist and must be installed first."
        echo "This is your architecture:"
        uname -a
        echo "Please install Kind according to your architecture, then repeat this command again."
    fi
    ;;

  build)
    if [ $# -lt 1 ]; then
      echo "Error: Version required (e.g., v1.0.0)"
      usage
    fi
    VERSION=$1
    if command -v docker && command -v kind &> /dev/null; then
        echo "Building Docker image: $DOCKER_IMAGE:$VERSION"
        docker build -t $DOCKER_IMAGE:$VERSION .
        kind load docker-image $DOCKER_IMAGE:$VERSION --name $CLUSTER_NAME
    else
        echo "Ensure that Docker and Kind are installed in your system."
        echo "This is your architecture:"
        uname -a
        echo "Please ensure that Docker and Kind are installed according to your architecture."
    fi
    ;;

  deploy)
    if [ $# -lt 1 ]; then
      echo "Error: Version required (e.g., v1.0.0)"
      usage
    fi
    VERSION=$1
    if command -v terraform &> /dev/null; then
        $0 build $VERSION  # Build if not already
        echo "Deploying version $VERSION via Terraform"
        cd terraform
        terraform init
        terraform apply -auto-approve -var "app_version=$VERSION"
        cd ..
    else
        echo "Terraform does not exist and must be installed first."
        echo "This is your architecture:"
        uname -a
        echo "Please install Terraform according to your architecture, then repeat this command again."
    fi
    ;;

  access-url)
    if command -v kubectl &> /dev/null; then
        echo "Port-forwarding service to http://localhost:8080"
        echo "Access /healthz or /version at http://localhost:8080/<endpoint>"
        echo "Ctrl+C to stop"
        kubectl -n $NAMESPACE port-forward svc/$APP_NAME 8080:80
    else
        echo "Kubectl does not exist and must be installed first."
        echo "This is your architecture:"
        uname -a
        echo "Please install Kubectl according to your architecture, then repeat this command again"
    fi
    ;;

  logs)
    if command -v kubectl &> /dev/null; then
        POD=$(kubectl -n $NAMESPACE get pods -l app=$APP_NAME -o jsonpath="{.items[0].metadata.name}")
        if [ -z "$POD" ]; then
            echo "No pods found"
            exit 1
        fi
        kubectl -n $NAMESPACE logs -f $POD
    else
        echo "Kubectl does not exist and must be installed first."
        echo "This is your architecture:"
        uname -a
        echo "Please install Kubectl according to your architecture, then repeat this command again."
    fi
    ;;

  versions)
    if command -v kubectl &> /dev/null; then
        kubectl -n $NAMESPACE get deployments $APP_NAME -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="APP_VERSION")].value}'
        echo ""  # Newline for readability
    else
        echo "Kubectl does not exist and must be installed first."
        echo "This is your architecture:"
        uname -a
        echo "Please install Kubectl according to your architecture, then repeat this command again."
    fi
    ;;

  *)
    usage
    ;;
esac