# IAM - Service Account for Cloud Run
resource "google_service_account" "cloud_run_service_account" {
  account_id   = "todo-app-service-account"
  display_name = "Service Account for Todo App Cloud Run Services"
}

# Auth Service
resource "google_cloud_run_v2_service" "auth_service" {
  name     = "auth-service"
  location = var.region

  template {
    containers {
      image = "${var.image_registry}/auth-service:${var.image_tag}"
      
      resources {
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
      }

      ports {
        container_port = 3100
      }
    }

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    timeout = "600s"

    service_account = google_service_account.cloud_run_service_account.email
  }

  traffic {
    percent         = 100
    type            = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }
}

# Profile Service
resource "google_cloud_run_v2_service" "profile_service" {
  name     = "profile-service"
  location = var.region

  template {
    containers {
      image = "${var.image_registry}/profile-service:${var.image_tag}"
      
      resources {
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
      }

      ports {
        container_port = 3200
      }
    }

    timeout = "600s"

    service_account = google_service_account.cloud_run_service_account.email
  }

  traffic {
    percent         = 100
    type            = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }
}

# Task Service
resource "google_cloud_run_v2_service" "task_service" {
  name     = "task-service"
  location = var.region

  template {
    containers {
      image = "${var.image_registry}/task-service:${var.image_tag}"
      
      resources {
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
      }

      ports {
        container_port = 3300
      }
    }

    timeout = "600s"

    service_account = google_service_account.cloud_run_service_account.email
  }

  traffic {
    percent         = 100
    type            = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }
}

# Frontend
resource "google_cloud_run_v2_service" "frontend" {
  name     = "todo-fe"
  location = var.region

  template {
    containers {
      image = "${var.image_registry}/todo-fe:${var.image_tag}"
      
      resources {
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
      }

      ports {
        container_port = 80
      }
      
      # Environment variables for API endpoints
      env {
        name  = "AUTH_SERVICE_URL"
        value = google_cloud_run_v2_service.auth_service.uri
      }
      
      env {
        name  = "PROFILE_SERVICE_URL"
        value = google_cloud_run_v2_service.profile_service.uri
      }
      
      env {
        name  = "TASK_SERVICE_URL"
        value = google_cloud_run_v2_service.task_service.uri
      }
    }

    timeout = "600s"

    service_account = google_service_account.cloud_run_service_account.email
  }

  traffic {
    percent         = 100
    type            = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST" 
  }
}

# IAM - Make services public
resource "google_cloud_run_service_iam_member" "frontend_public" {
  location = google_cloud_run_v2_service.frontend.location
  service  = google_cloud_run_v2_service.frontend.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}