### DNS
contact_email = "artem.lajko@iits-consulting.de"
dns_name      = "hub-dev.stackit.run"

### Global
project_id = "38867e9e-b5d4-4a85-97a8-0a944ab75b19"
stage      = "dev"
name       = "hub"

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
region = "eu02"
node_pools = [
  {
    availability_zones = ["eu02-2"]
    machine_type       = "g3i.4"
    volume_size        = 30
    maximum            = 6
    minimum            = 4
    name               = "pool-infra"
    labels = {
      "role" = "infra"
    }
    taints = []
  }
]


