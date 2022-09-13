
module "gke service account" {
source         = "tfe.gcp.db.com/PMR/cpt-sa/google"
version        = "1.3.3"
nar_id         = var.nar_id
instance_id    = var.instance_id
project_id     = module.mein_project.project_id
environment    = var.environment
account_id     = "tf-gke-cco"
display_name   = "GKE Compute Engine Service Account"
purpose        = "GKE Compute Engine Service Account"
access_level   = "Project"
used_in        = "Std"
}

resource "google_project_iam_member" "gke_iam_binding" {
  for_each = toset(
    [
      "roles/logging.logWriter",
      "roles/monitoring.metricWriter",
      "roles/monitoring.viewer",
      "roles/stackdriver.resourceMetadata.writer",
      "roles/gkehub.viewer"
    ]
 )
  project = module.main_project.project_id
  role    = each.key
  member  = "serviceAccount:${module.gke_service_account.service_account_email}"
}

resource "google_project_iam_member" "mesh_iam_binding" {
  for_each = toset(
    [
      "roles/gkehub.viewer",
      "roles/gkehub.editor"
    ]
  )
  project = module.main_project.project_id
  role    = each.key
  member  = "serviceAccount:lz-dbc-dev-115699-1-003-m@pro-sd3e-lz-seed-project.iam.gserviceaccount.com"
}


# Cloudsql service identity
 resource "google_project_service_identity" "cloudsql_sa" {
   provider = google-beta

   project  = module.main_project.project_id
   service  = "sqladmin.googleapis.com"
}
resource "google_project_iam_member" "cloudsql_sa_role" {
  project = module.main_project.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_project_service_identity.cloudsql_sa.email}"
}

locals {
  dev_permissions = toset(
    [
      "roles/cloudsql.editor",
      "${var.organization_id}/roles/container.clusterConfigurator",
      "roles/gkehub.viewer"
     ] 
  )
  uat_permissions = toset(
    [
     "roles/cloudsql.editor",
     "${var.organization_id}/roles/container.clusterConfigurator"
    ]
  )

  prd_permissions = toset(
  [
   "roles/cloudsql.editor",
      "${var.organization_id}/roles/container.clusterConfigurator"
     ]
  )

permissions = var.environment == "dev" ? local.dev_permissions : var.environment ==  "uat"  ? local.uat_permissions : local.prd_permissions

}
# GSM SA roles

 resource "google_project_iam_member" "gsm_sa_iam_binding" {

   for_each = local.permissions

   project  = module.main_project.project_id
   role     = each.key
   member   = "serviceAccount:${var.service_account_emails.secrets}"
}

# CloudeSQL pgAudit enablement
resource "google_project_iam_audit_config" "project-audit_config" {
  project = module.main_project.project_id
  service = "cloudsql.googleapis.com"
  audit_log_config {
    log_type = "ADMIN_READ"
  }
  audit_log_config {
    log_type = "DATA_READ"
    exempted_members = [
    ]

  }
  audit_log_config {
    log_type = "DATA_WRITE"
    exempted_members = [
   ]
  }
}
resource "google_project_iam_member" "cloudsql_users_iam_binding" {
  for_each = toset(
    [
      "roles/cloudsql.client",
      "roles/cloudsql.instanceUser",
      "roles/cloudsql.viewer"
    ]
  )
  project = module.main_project.project_id
  role    = each.key
  member  = var.cloudsql_database_users_group
}

# GKE Workload Identity
module "gke_wi_service_account" {
  for_each       = toset(local.wi_service_accounts)
  source         = "tfe.gcp.db.com/PMR/cpt-sa/google"
  version        = "1.3.3"
  nar_id         = var.nar_id
  instance_id    = var.instance_id
  project_id     = module.main_project.project_id
  environment    = var.environment
  account_id     = each.value
  display_name   = "gke-wi-sa-${each.value}"
  purpose        = "Service Account for GKE Workload Identity - ${each.value}"
  access_level   = "Project"
  used_in        = "Std"
}
resource "google_service_account_iam_member" "gke_wi_service_account_members" {
  for_each = {
  for member in local.wi_members : "${member.service} | ${member.namespace}"  => member
}

  service_account_id = "projects/${module.main_project.project_id}/serviceAccounts/${each.value.service}@${module.main_project.project_id}.iam.gserviceaccount.com"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${module.main_project.project_id}.svc.id.goog[${each.value.namespace}/${each.value.service}]"
  depends_on = [
  module.gke_wi_service_account
    ]
   }
resource "google_project_iam_member" "gke_wi_service_account_bindings" {
  for_each = {
    for binding in local.wi_role_bindings : "${binding.service} | ${binding.role}" => binding
}
  project = module.main_project.project_id
  role    =each.value.role

  member  =  "serviceAccount:${each.value.service}@${module.main_project.project_id}.iam.gserviceaccount.com"
  depends_on = [
  google_service_account_iam_member.gke_wi_service_account_members
  ]
}

  #Cloud SQL tableau sa accounts

resource "google_project_iam_member" "cloudsql_tableau_sa_binding" {
  for_each = toset(
    [
       "roles/cloudsql.client",
       "roles/cloudsql.instanceUser"
    ]
 )
  project = module.main_project.project_id
  role    = each.key
  member  = "serviceAccount:${var.cloudsql_tableau_sa}"
}

# Secret Manager service identity

resource "google_project_service_identity" "secretmanager_sa" {
  provider = google-beta
  project  = module.main_project.project_id
  service  = "secretmanager.googleapis.com"
}
