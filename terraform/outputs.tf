output "auth_service_url" {
  description = "URL of the deployed Auth Service"
  value       = google_cloud_run_v2_service.auth_service.uri
}

output "profile_service_url" {
  description = "URL of the deployed Profile Service"
  value       = google_cloud_run_v2_service.profile_service.uri
}

output "task_service_url" {
  description = "URL of the deployed Task Service"
  value       = google_cloud_run_v2_service.task_service.uri
}

output "frontend_url" {
  description = "URL of the deployed Frontend"
  value       = google_cloud_run_v2_service.frontend.uri
}