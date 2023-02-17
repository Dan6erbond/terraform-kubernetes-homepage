# Homepage on Kubernetes

Terraform module to deploy the [Homepage](https://gethomepage.dev/en/installation/) dashboard on Kubernetes.

## Features

- Deploys Homepage to Kubernetes using standard conventions for Kubernetes labels and selectors.
- Creates a ServiceAccount with the required permissions for service discovery.
- Enables `cluster` mode in Homepage config to use the ServiceAccount.
- Deploys an Ingress resource with user-configurable annotations (e.g. for Nginx/Traefik).
- Automatically sets the Homepage `base` setting with `https://` for common configurations.
- Uses Types for all Homepage configs to improve DX.

## Usage

The following variables can be configured:

- `host` - Host under which Homepage is served.
- `namespace` - Namesplace to deploy Homepage to. `default` is the standard.
- `volumes` - Additional volumes to mount to the container. Can be useful to mount additional drives and display available storage.
- `ingress_annotations` - Annotations to add to the ingress. Useful to configure Traefik/Nginx certificates or entrypoints.
- `services_config` - List of groups and services to show in Homepage. Supports Kubernetes `namespace`, `app` and `podSelector`.
- `widgets_config` - List of widgets to show in Homepage.
- `settings` - Homepage settings configuration.
- `bookmarks` - List of bookmarks to show in Homepage.
- `docker_config` - Enabled for compatibility with a future Docker module.
- `kubernetes_config` - Configuration for Kubernetes service discovery, using either Kubeconfig or default ServiceAccount with `mode` set to `cluster`.

Add the module like this:

```hcl
module "homepage" {
  source = "Dan6erbond/homepage/kubernetes"
  version = "1.0.0"
  namespace = "homepage"
  volumes = [
    {
      name                    = "ssd"
      persistent_volume_claim = local.homepage_ssd_pvc
      mount_path              = "/mnt/ssd"
      read_only               = false
    },
    {
      name = "media"
      host_path = {
        path = "/mnt/media"
      }
      mount_path = "/mnt/media"
    }
  ]
  ingress_annotations = {
    "traefik.ingress.kubernetes.io/router.entrypoints"      = "websecure"
    "traefik.ingress.kubernetes.io/router.tls.certresolver" = "letsencrypt"
  }
  services_config = [
    { Admin = [
      { Grafana = {
        icon      = "grafana.png"
        href      = "https://grafana.ravianand.me"
        namespace = "monitoring"
        app       = "grafana"
      } },
    }
  ]
  widgets_config = [
    {
      resources = {
        label  = "System"
        cpu    = true
        memory = true
        disk   = "/mnt/ssd"
      }
    },
    {
      resources = {
        label = "Media"
        disk  = "/mnt/media"
      }
    },
    {
      datetime = {
        text_size = "xl"
        format = {
          timeStyle = "short"
          hour12    = false
        }
      }
    }
  ]
  settings = {
    title             = "Dan6erbond Homelab"
    background        = "https://images.unsplash.com/photo-1579567761406-4684ee0c75b6?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=987&q=80"
    backgroundOpacity = "0.15"
    theme             = "dark"
    layout = {
      Media = {
        icon    = "mdi-filmstrip"
        style   = "row"
        columns = 4
      }
    }
  }
}
```

## Homepage Configuration

All the available Homepage configuration objects are stored under Homepage's `/app/config` directory as YAML files. For more about Homepage's configuration see their [docs](https://gethomepage.dev/en/configs/services/).

### Kubernetes Integration

This module provisions a ServiceAccount with `ClusterRoleBinding` to allow Homepage to get and list ingresses, pods, namespaces, etc. You can configure the `app` and `namespace` properties in `service_config` widgets to automatically show the health status of a pod.

Homepage will look for pods in the configured namespace, with a `app.kubernetes.io/name` label matching the value of `app`.

If a more complex selector is required, this module also supports [Homepage's `podSelector`](https://gethomepage.dev/en/configs/kubernetes/#services).

For more about Homepage's Kubernetes integration see their [docs](https://gethomepage.dev/en/configs/kubernetes/).

# Authors

- RaviAnand Mohabir (moravrav@gmail.com)
