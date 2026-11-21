terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = "asia-east1"
}

variable "project_id" {
  type        = string
  description = "ID of the Google Cloud project that will host the VM."
}

variable "boot_image" {
  type        = string
  description = "Full resource path of a bootable Deep Learning VM M129 image with Debian 11 and Python 3.10."

  validation {
    condition     = can(regex("^(https://(www\\.googleapis\\.com|compute\\.googleapis\\.com)/compute/v1/)?projects/[^/[:space:]]+/global/images/[^/[:space:]]+$", var.boot_image))
    error_message = "Provide the exact Compute Engine image as projects/IMAGE_PROJECT/global/images/IMAGE_NAME or its self-link."
  }
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

locals {
  name = "emg2qwerty-gpu"
}

resource "google_compute_network" "vm" {
  name                    = local.name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "vm" {
  name          = local.name
  network       = google_compute_network.vm.id
  ip_cidr_range = "10.42.0.0/24"
}

resource "google_compute_firewall" "web" {
  name          = "${local.name}-web"
  network       = google_compute_network.vm.id
  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  target_tags   = [local.name]

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
}

resource "google_compute_firewall" "iap_ssh" {
  name          = "${local.name}-iap-ssh"
  network       = google_compute_network.vm.id
  direction     = "INGRESS"
  source_ranges = ["35.235.240.0/20"]
  target_tags   = [local.name]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_instance" "vm" {
  name         = local.name
  zone         = var.zone
  machine_type = "n1-standard-4"
  tags         = [local.name]

  boot_disk {
    auto_delete = true

    initialize_params {
      image = var.boot_image
      size  = 50
      type  = "pd-balanced"
    }
  }

  guest_accelerator {
    type  = "nvidia-tesla-t4"
    count = 1
  }

  scheduling {
    on_host_maintenance = "TERMINATE"
    automatic_restart   = true
  }

  metadata = {
    enable-oslogin        = "TRUE"
    install-nvidia-driver = "True"
  }

  network_interface {
    subnetwork = google_compute_subnetwork.vm.id

    # Allocate an ephemeral external IPv4 address for HTTP and HTTPS.
    access_config {}
  }
}

output "external_ip" {
  description = "Public IPv4 address of the VM."
  value       = google_compute_instance.vm.network_interface[0].access_config[0].nat_ip
}

output "ssh_command" {
  description = "Command to connect through Identity-Aware Proxy."
  value       = "gcloud compute ssh ${google_compute_instance.vm.name} --project=${var.project_id} --zone=${var.zone} --tunnel-through-iap"
}
