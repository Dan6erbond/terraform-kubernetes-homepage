variable "host" {
  description = "Hostname for Hompeage"
  type        = string
}

variable "namespace" {
  description = "Namespace to deploy Homepage to"
  type        = string
  default     = "default"
}

variable "volumes" {
  description = "Additional volumes to mount to the pod, useful to display storage"
  type = list(object({
    name                    = string
    persistent_volume_claim = optional(string, "")
    host_path = optional(object({
      path = string
      type = optional(string, "Directory")
    }), { path = "", type = "Directory" })
    mount_path = string
    read_only  = optional(bool, true)
  }))
  default = []
}

variable "ingress_annotations" {
  description = "Annotations to add to the Ingress"
  type        = map(string)
  default     = {}
}

variable "services_config" {
  description = "Configuration file for services"
  type = list(
    map(
      list(
        map(
          object({
            icon        = string
            href        = optional(string)
            namespace   = optional(string)
            app         = optional(string)
            podSelector = optional(string, "")
            widget = optional(object({
              type     = optional(string)
              url      = optional(string)
              key      = optional(string)
              username = optional(string)
              password = optional(string)
            }))
          })
        )
      )
    )
  )
  default = []
}

variable "widgets_config" {
  description = "Configuration for widgets"
  type = list(map(object({
    // resources
    label  = optional(string)
    cpu    = optional(bool, false)
    memory = optional(bool, false)
    disk   = optional(string)
    // kubernetes
    cluster = optional(object({
      show      = optional(bool, false)
      cpu       = optional(bool, false)
      memory    = optional(bool, false)
      showLabel = optional(bool, false)
      label     = optional(string, "")
    }))
    nodes = optional(object({
      show      = optional(bool, false)
      cpu       = optional(bool, false)
      memory    = optional(bool, false)
      showLabel = optional(bool, false)
    }))
    // datetime
    text_size = optional(string)
    format = optional(object({
      timeStyle = optional(string)
      hour12    = optional(bool, false)
    }))
  })))
  default = []
}

variable "settings" {
  description = "General Homepage settings"
  type = object({
    title             = optional(string)
    base              = optional(string)
    background        = optional(string)
    backgroundOpacity = optional(string)
    theme             = optional(string)
    layout = list(
      object({
        name    = string
        icon    = optional(string)
        style   = optional(string)
        columns = optional(number)
      })
    )
  })
}

variable "bookmarks" {
  description = "Bookmarks to show in Homepage"
  type        = list(map(any))
  default     = []
}

variable "docker_config" {
  description = "Homepage Docker config (for reusability of configuration)"
  type        = map(any)
  default     = {}
}

variable "kubernetes_config" {
  description = "Kubernetes service config"
  type = object({
    mode = string
  })
  default = { mode = "cluster" }
}
