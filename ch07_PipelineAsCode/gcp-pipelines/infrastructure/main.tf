locals {
  services = [
    "sourcerepo.googleapis.com",
    "cloudbuild.googleapis.com",
    "run.googleapis.com",
    "iam.googleapis.com",
  ]
}

resource "google_project_service" "enabled_service" {
  for_each = toset(local.services)
  project  = var.project_id
  service  = each.key

  //invokes the command sleep 60 to wait for 60 seconds after Create() has completed but before the resource is marked as “created” by Terraform
  // usecase: inserting delays
  provisioner "local-exec" {
    command = "sleep 60"
  }

  //destruction-time provisioner waits for 15 seconds before Delete() is called.
  provisioner "local-exec" {
    when    = destroy
    command = "sleep 15"
  }
}

//This will provision a version-controlled source repository, which is the first stage of our CI/CD pipeline.
resource "google_sourcerepo_repository" "repo" {
  depends_on = [
  google_project_service.enabled_service["sourcerepo.googleapis.com"]]
  name = "${var.namespace}-repo"
}

//we need to set up a Cloud Build to trigger a run from a commit to the source repository.
resource "google_cloudbuild_trigger" "trigger" {
  depends_on = [
    google_project_service.enabled_service["cloudbuild.googleapis.com"]
  ]
  trigger_template {
    branch_name = "master"
    repo_name   = google_sourcerepo_repository.repo.name
  }
  build {
    dynamic "step" {
      for_each = local.steps
      content {
        name = step.value.name
        args = step.value.args
        env  = lookup(step.value, "env", null)
      }
    }
  }
}

locals {
  image = "gcr.io/${var.project_id}/${var.namespace}"
  steps = [
    {
      name = "gcr.io/cloud-builders/go"
      args = ["test"]
      env  = ["PROJECT_ROOT=${var.namespace}"]
    },
    {
      name = "gcr.io/cloud-builders/docker",
      args = ["build", "-t", local.image, "."]
    },
    {
      name = "gcr.io/cloud-builders/docker"
      args = ["push", local.image]
    },
    {
      name = "gcr.io/cloud-builders/gcloud"
      args = ["run", "deploy", google_cloud_run_service.service.name, "--image", local.image, "--region", var.region, "--platform", "managed", "-q"]
    }
  ]
}

data "google_project" "project" {}

//Grants the Cloud Build service account these two roles
resource "google_project_iam_member" "cloudbuild_roles" {
  depends_on = [google_cloudbuild_trigger.trigger]
  for_each   = toset(["roles/run.admin", "roles/iam.serviceAccountUser"])
  project    = var.project_id
  role       = each.key
  member     = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

//The Cloud Run service initially uses a demo image that’s already in the Container Registry.
resource "google_cloud_run_service" "service" {
  depends_on = [
  google_project_service.enabled_service["run.googleapis.com"]
  ]
  name     = var.namespace
  location = var.region
  template {
    spec {
      containers {
        image = "us-docker.pkg.dev/cloudrun/container/hello"
      }
    }
  }
}

//To expose the web application to the internet, we need to enable unauthenticated user access. We can do that with an IAM policy that grants all users the run.invoker role to the provisioned Cloud Run service.
data "google_iam_policy" "admin" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "policy" {
  location    = var.region
  project     = var.project_id
  service     = google_cloud_run_service.service.name
  policy_data = data.google_iam_policy.admin.policy_data
}




