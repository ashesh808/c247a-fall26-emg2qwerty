variable "project_id" {
  type        = string
  description = "ID of the Google Cloud project that will host the VM."
}

variable "zone" {
  type        = string
  description = "Supported Asian zone for the NVIDIA T4."
  default     = "asia-east1-a"

  validation {
    condition = contains([
      "asia-east1-a", "asia-east1-c",
      "asia-east2-a", "asia-east2-c",
      "asia-northeast1-a", "asia-northeast1-c",
      "asia-northeast3-b", "asia-northeast3-c",
      "asia-southeast1-a", "asia-southeast1-b", "asia-southeast1-c",
      "asia-southeast2-a", "asia-southeast2-b",
    ], var.zone)
    error_message = "Choose one of the listed T4 zones in Taiwan, Hong Kong, Tokyo, Seoul, Singapore, or Jakarta."
  }
}
