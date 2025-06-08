# IAM - Service Account for Cloud Run
resource "google_service_account" "cloud_run_service_account" {
  account_id   = "todo-app-service-account"
  display_name = "Service Account for Todo App Cloud Run Services"
}

# MySQL Database
resource "google_sql_database_instance" "mysql_instance" {
  name             = "todo-mysql-instance"
  database_version = "MYSQL_8_0"
  region           = var.region

  settings {
    tier = "db-f1-micro"  # Smallest instance, adjust as needed
    
    backup_configuration {
      enabled = false
    }
    
    ip_configuration {
      ipv4_enabled = true
      authorized_networks {
        name  = "all"
        value = "0.0.0.0/0"  # Chỉ cho môi trường test, KHÔNG sử dụng trong production!
      }
    }
  }

  deletion_protection = false  # Set to true in production
}

resource "google_sql_database" "auth_database" {
  name     = "todo-auth"
  instance = google_sql_database_instance.mysql_instance.name
}

resource "google_sql_database" "user_database" {
  name     = "todo-user"
  instance = google_sql_database_instance.mysql_instance.name
}

resource "google_sql_database" "task_database" {
  name     = "todo-task"
  instance = google_sql_database_instance.mysql_instance.name
}

resource "google_sql_user" "mysql_user" {
  name     = "root"
  instance = google_sql_database_instance.mysql_instance.name
  password = "root_password_secret_tcp"  # Use secret manager in production
}

# Redis Container on Cloud Run (replacing Memorystore)
resource "google_cloud_run_v2_service" "redis_service" {
  name     = "redis-service"
  location = var.region

  template {
    containers {
      image = "redis:7.4-alpine"
      
      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      ports {
        container_port = 6379
      }
      
      # Set Redis to only accept connections from our services
      args = [
        "redis-server", 
        "--protected-mode", "no"
      ]
    }

    service_account = google_service_account.cloud_run_service_account.email
  }

  traffic {
    percent         = 100
    type            = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }
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

      # Add environment variables for MySQL and Redis
      env {
        name  = "DB_DSN"
        value = "root:root_password_secret_tcp@tcp(${google_sql_database_instance.mysql_instance.public_ip_address}:3306)/todo-list?charset=utf8mb4&parseTime=True&loc=Local"
      }
      
      env {
        name  = "GIN_PORT"
        value = "3100"
      }
      
      env {
        name  = "GRPC_PORT"
        value = "3101"
      }
      
      env {
        name  = "GRPC_USER_ADDRESS"
        value = "profile-service:3201"
      }
      
      env {
        name  = "JWT_SECRET"
        value = "very-important-please-change-it!"  # Use secret manager in production
      }
    }

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

      # Add environment variables for MySQL
      env {
        name  = "DB_DSN"
        value = "root:root_password_secret_tcp@tcp(${google_sql_database_instance.mysql_instance.public_ip_address}:3306)/todo-list?charset=utf8mb4&parseTime=True&loc=Local"
      }
      
      env {
        name  = "GIN_PORT"
        value = "3200"
      }
      
      env {
        name  = "GRPC_PORT" 
        value = "3201"
      }
      
      env {
        name  = "GRPC_AUTH_ADDRESS"
        value = "auth-service:3101"
      }
    }

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

      # Add environment variables for MySQL
      env {
        name  = "DB_DSN"
        value = "root:root_password_secret_tcp@tcp(${google_sql_database_instance.mysql_instance.public_ip_address}:3306)/todo-list?charset=utf8mb4&parseTime=True&loc=Local"
      }
    }

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

      env {
        name  = "GATEWAY_URL"
        value = google_cloud_run_v2_service.gateway.uri
      }
    }

    service_account = google_service_account.cloud_run_service_account.email
  }

  traffic {
    percent         = 100
    type            = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST" 
  }
}

# Tyk API Gateway
resource "google_cloud_run_v2_service" "gateway" {
  name     = "api-gateway"
  location = var.region

  template {
    containers {
      image = "docker.tyk.io/tyk-gateway/tyk-gateway:latest"
      
      resources {
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
      }

      ports {
        container_port = 8080
      }
      
      # Environment variables for gateway
      env {
        name  = "REDIS_HOST"
        value = google_cloud_run_v2_service.redis_service.uri
      }
      
      env {
        name  = "REDIS_PORT"
        value = "6379" 
      }
      
      # You may need to add additional configuration as needed
      env {
        name  = "TYK_GW_LISTENPORT"
        value = "8080"
      }
      
      # You'll need to add volume mounts for configuration files
      # In Cloud Run, you may need to use Cloud Storage or build these into your container
    }

    service_account = google_service_account.cloud_run_service_account.email
  }

  traffic {
    percent         = 100
    type            = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
  }
}

# Make gateway public
resource "google_cloud_run_service_iam_member" "gateway_public" {
  location = google_cloud_run_v2_service.gateway.location
  service  = google_cloud_run_v2_service.gateway.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Allow Gateway to access Redis
resource "google_cloud_run_service_iam_member" "redis_service_invoker" {
  location = google_cloud_run_v2_service.redis_service.location
  service  = google_cloud_run_v2_service.redis_service.name
  role     = "roles/run.invoker" 
  member   = "serviceAccount:${google_service_account.cloud_run_service_account.email}"
}

# IAM - Make services public
resource "google_cloud_run_service_iam_member" "frontend_public" {
  location = google_cloud_run_v2_service.frontend.location
  service  = google_cloud_run_v2_service.frontend.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# IAM - Add SQL Client role to service account
resource "google_project_iam_member" "cloud_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloud_run_service_account.email}"
}