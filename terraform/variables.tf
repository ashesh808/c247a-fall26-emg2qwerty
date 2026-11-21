variable "project_id" {
  type        = string
  description = "ID of the Google Cloud project that will host the VM."
}

variable "zone" {
  type        = string
  description = "Taiwan zone for the NVIDIA T4."
  default     = "asia-east1-a"

  validation {
    condition     = contains(["asia-east1-a", "asia-east1-c"], var.zone)
    error_message = "Choose asia-east1-a or asia-east1-c for the NVIDIA T4."
  }
}
