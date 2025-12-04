terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.33.0"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"  # Assumes kubeconfig from Kind
}

resource "kubernetes_namespace" "app" {
  metadata {
    name = "minimal-api"
  }
}

resource "kubernetes_deployment" "app" {
  metadata {
    name      = "minimal-api"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "minimal-api"
      }
    }

    template {
      metadata {
        labels = {
          app = "minimal-api"
        }
      }

      spec {
        container {
          image = "minimal-api:${var.app_version}"  # Image tag matches version
          name  = "api"

          port {
            container_port = 5000
          }

          env {
            name  = "APP_VERSION"
            value = var.app_version
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "app" {
  metadata {
    name      = "minimal-api"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    selector = {
      app = "minimal-api"
    }

    port {
      port        = 80
      target_port = 5000
    }

    type = "ClusterIP"  # Use port-forward for local access
  }
}

variable "app_version" {
  description = "The application version (used for image tag and env var)"
  type        = string
  default     = "v1.0.0"
}