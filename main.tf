terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.13.1"
    }
  }
}

locals {
  match_labels = {
    "app.kubernetes.io/instance" = "homepage"
    "app.kubernetes.io/name"     = "homepage"
  }
  labels = merge({
    "app.kubernetes.io/version" = "v0.6.7"
  }, local.match_labels)
}

resource "kubernetes_service_account" "homepage" {
  metadata {
    name      = "homepage"
    namespace = var.namespace
    labels    = local.labels
  }
  secret {
    name = "homepage-sa-token"
  }
}

resource "kubernetes_secret" "homepage" {
  type = "kuberneetes.io/service-account-token"
  metadata {
    name      = "homepage"
    namespace = var.namespace
    labels    = local.labels
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.homepage.metadata.0.name
    }
  }
}

resource "kubernetes_secret" "homepage_sa_token" {
  type = "kuberneetes.io/service-account-token"
  metadata {
    name      = "homepage-sa-token"
    namespace = var.namespace
    labels    = local.labels
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.homepage.metadata.0.name
    }
  }
}

resource "kubernetes_cluster_role" "homepage" {
  metadata {
    name   = "homepage"
    labels = local.labels
  }
  rule {
    api_groups = [""]
    resources  = ["namespaces", "pods", "nodes"]
    verbs      = ["get", "list"]
  }
  rule {
    api_groups = ["extensions", "networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list"]
  }
  rule {
    api_groups = ["metrics.k8s.io"]
    resources  = ["nodes", "pods"]
    verbs      = ["get", "list"]
  }
}

resource "kubernetes_cluster_role_binding" "homepage" {
  metadata {
    name   = "homepage"
    labels = local.labels
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.homepage.metadata.0.name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.homepage.metadata.0.name
    namespace = var.namespace
  }
}

resource "kubernetes_deployment" "homepage" {
  metadata {
    name      = "homepage"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    replicas = 1

    selector {
      match_labels = local.match_labels
    }

    template {
      metadata {
        labels = local.labels
        annotations = {
          "ravianand.me/config-hash" = sha1(jsonencode(merge(
            kubernetes_config_map.homepage_config.data,
          )))
        }
      }

      spec {
        service_account_name            = kubernetes_service_account.homepage.metadata.0.name
        automount_service_account_token = true
        container {
          image = "ghcr.io/benphelps/homepage:latest"
          name  = "homepage"
          port {
            container_port = 3000
          }
          volume_mount {
            name       = "config"
            mount_path = "/app/config"
          }
          volume_mount {
            name       = "logs"
            mount_path = "/app/config/logs"
          }
          dynamic "volume_mount" {
            for_each = toset(var.volumes)
            content {
              name       = volume_mount.value.name
              mount_path = volume_mount.value.mount_path
              read_only  = volume_mount.value.read_only
            }
          }
          liveness_probe {
            failure_threshold     = 3
            initial_delay_seconds = 0
            period_seconds        = 10
            tcp_socket {
              port = 3000
            }
            timeout_seconds = 1
          }
          readiness_probe {
            failure_threshold     = 3
            initial_delay_seconds = 0
            period_seconds        = 10
            tcp_socket {
              port = 3000
            }
            timeout_seconds = 1
          }
          startup_probe {
            failure_threshold     = 30
            initial_delay_seconds = 0
            period_seconds        = 5
            tcp_socket {
              port = 3000
            }
            timeout_seconds = 1
          }
        }
        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.homepage_config.metadata.0.name
          }
        }
        dynamic "volume" {
          for_each = toset(var.volumes)
          content {
            name = volume.value.name
            dynamic "persistent_volume_claim" {
              for_each = toset(volume.value.persistent_volume_claim != "" ? [volume.value.persistent_volume_claim] : [])
              content {
                claim_name = persistent_volume_claim.value
              }
            }
            dynamic "host_path" {
              for_each = toset(volume.value.host_path.path != "" ? [volume.value.host_path] : [])
              content {
                path = host_path.value.path
                type = host_path.value.type
              }
            }
          }
        }
        volume {
          name = "logs"
          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_service" "homepage" {
  metadata {
    name      = "homepage"
    namespace = var.namespace
  }
  spec {
    type     = "ClusterIP"
    selector = local.match_labels
    port {
      port = 3000
    }
  }
}

resource "kubernetes_ingress_v1" "homepage" {
  metadata {
    name        = "homepage"
    namespace   = var.namespace
    annotations = var.ingress_annotations
  }
  spec {
    rule {
      host = var.host
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.homepage.metadata.0.name
              port {
                number = kubernetes_service.homepage.spec.0.port.0.port
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_config_map" "homepage_config" {
  metadata {
    name      = "homepage-config"
    namespace = var.namespace
  }
  data = {
    "services.yaml" = yamlencode(var.services_config)
    "widgets.yaml"  = yamlencode(var.widgets_config)
    "settings.yaml" = <<-EOT
    ${yamlencode(
    merge({ for k, v in var.settings : k => v if k != "layout" }, {
      base = var.settings.base == null ? "https://${var.host}" : var.settings.base
    }))}
    layout:
    ${join("\n", [for layout in var.settings.layout : "  \"${layout.name}\": ${jsonencode(layout)}"])}
    EOT
  "bookmarks.yaml"  = yamlencode(var.bookmarks)
  "docker.yaml"     = yamlencode(var.docker_config)
  "kubernetes.yaml" = yamlencode(var.kubernetes_config)
  }
}
