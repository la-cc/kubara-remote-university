module "iam" {
  source = "../../../../platform-components/terraform/stackit/modules/iam"

  project_id = var.project_id
  name       = "sa-${substr(var.name, 0, 8)}-${substr(var.stage, 0, 8)}" # iam only allows for 20 characters

  sa_key_ttl_days                 = var.sa_key_ttl_days
  sa_key_ttl_rotation_buffer_days = var.sa_key_ttl_rotation_buffer_days

  role_assignment_role = var.role_assignment_role
}

module "dns_zone" {
  source = "../../../../platform-components/terraform/stackit/modules/dns-zone"

  project_id    = var.project_id
  name          = "${var.name}-${var.stage}"
  dns_name      = var.dns_name
  contact_email = var.contact_email
}


module "secretsmanager" {
  source = "../../../../platform-components/terraform/stackit/modules/secretsmanager"

  project_id = var.project_id
  name       = "${var.name}-${var.stage}"
  acls       = var.acls

  users = var.users
}


module "ske_cluster" {
  source = "../../../../platform-components/terraform/stackit/modules/ske-cluster"

  project_id             = var.project_id
  name                   = "${local.ske_name_prefix}-${random_string.ske_name_suffix.result}"
  region                 = var.region
  kubernetes_version_min = var.kubernetes_version_min

  node_pools = var.node_pools

  ske_maintenance = var.ske_maintenance

  ### kubeconfig
  expiration = var.expiration

  # Destroy the cluster before the IAM service account. In-cluster workloads
  # (external-dns, cert-manager, ...) keep requesting tokens with the SA key,
  # so the service account must outlive the cluster on teardown.
  depends_on = [module.iam]
}

locals {
  ske_name_prefix        = substr(var.name, 0, 5)
  ske_name_suffix_length = 10 - length(local.ske_name_prefix)
}

resource "random_string" "ske_name_suffix" {
  length  = local.ske_name_suffix_length # ske only allows for 11 characters
  lower   = true
  upper   = false
  special = false
}




