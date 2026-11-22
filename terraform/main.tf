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
  region  = local.region
}

locals {
  name   = "emg2qwerty-gpu"
  region = substr(var.zone, 0, length(var.zone) - 2)
}

resource "google_compute_network" "vm" {
  name                    = local.name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "vm" {
  name          = local.name
  region        = local.region
  network       = google_compute_network.vm.id
  ip_cidr_range = "10.42.0.0/24"
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
      image = "projects/deeplearning-platform-release/global/images/family/common-cu129-ubuntu-2204-nvidia-580"
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
    enable-oslogin = "TRUE"
  }

  network_interface {
    subnetwork = google_compute_subnetwork.vm.id

    # Allow outbound internet access for Git and package downloads.
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
