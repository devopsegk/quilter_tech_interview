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
        echo "Please install Kind according to your architecture, then repeat this command again"
    fi
    ;;

  teardown-cluster)
    echo "Tearing down Kind cluster: $CLUSTER_NAME"
    kind delete cluster --name $CLUSTER_NAME
    ;;

  build)
    if [ $# -lt 1 ]; then
      echo "Error: Version required (e.g., v1.0.0)"
      usage
    fi
    VERSION=$1
    echo "Building Docker image: $DOCKER_IMAGE:$VERSION"
    docker build -t $DOCKER_IMAGE:$VERSION .
    kind load docker-image $DOCKER_IMAGE:$VERSION --name $CLUSTER_NAME
    ;;

  deploy)
    if [ $# -lt 1 ]; then
      echo "Error: Version required (e.g., v1.0.0)"
      usage
    fi
    VERSION=$1
    $0 build $VERSION  # Build if not already
    echo "Deploying version $VERSION via Terraform"
    cd terraform
    terraform init
    terraform apply -auto-approve -var "app_version=$VERSION"
    cd ..
    ;;

  access-url)
    echo "Port-forwarding service to http://localhost:8080"
    echo "Access /healthz or /version at http://localhost:8080/<endpoint>"
    echo "Ctrl+C to stop"
    kubectl -n $NAMESPACE port-forward svc/$APP_NAME 8080:80
    ;;

  logs)
    POD=$(kubectl -n $NAMESPACE get pods -l app=$APP_NAME -o jsonpath="{.items[0].metadata.name}")
    if [ -z "$POD" ]; then
      echo "No pods found"
      exit 1
    fi
    kubectl -n $NAMESPACE logs -f $POD
    ;;

  versions)
    kubectl -n $NAMESPACE get deployments $APP_NAME -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="APP_VERSION")].value}'
    echo ""  # Newline for readability
    ;;

  *)
    usage
    ;;
esac