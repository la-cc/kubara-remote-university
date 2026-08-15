### DNS
contact_email = "artem.lajko@iits-consulting.de"
dns_name      = "artem-dev.stackit.run"

### Global
project_id = "38867e9e-b5d4-4a85-97a8-0a944ab75b19"
stage      = "dev"
name       = "artem"

### Secret Manager / Vault Users
users = [
  {
    description   = "vault-user-rw"
    write_enabled = true
  },
  {
    description   = "vault-user-ro"
    write_enabled = false
  }
]

### Kubernetes

### SKE
kubernetes_version_min = "1.35"
node_pools = [
  {
    availability_zones = ["eu01-2"]
    machine_type       = "c2i.8"
    volume_size        = 30
    maximum            = 4
    minimum            = 2
    name               = "pool-infra"
    labels = {
      "role" = "infra"
    }
    taints = []
  }
]


