provider "google" {
  
}

resource "google_container_cluster" "w255" {
  addons_config {
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }

    horizontal_pod_autoscaling {
      disabled = true
    }

    http_load_balancing {
      disabled = true
    }

    network_policy_config {
      disabled = true
    }

    gcs_fuse_csi_driver_config {
        enabled = true
    }
  }

  database_encryption {
    state = "DECRYPTED"
  }

  default_max_pods_per_node = 110

  default_snat_status {
    disabled = false
  }

  enable_shielded_nodes = true

  location = "${var.location}-c"

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block = "${var.cloudshell_ip}/32"
    }
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]

    managed_prometheus {
      enabled = true
    }
  }

  name    = var.cluster_name
  network = "projects/${var.project_id}/global/networks/${var.network_name}"


  node_config {
    disk_size_gb = 100
    disk_type    = "pd-balanced"
    image_type   = "COS_CONTAINERD"
    machine_type = var.machine_type

   
    workload_metadata_config {
      mode          = "GKE_METADATA"
    }
  }
  
  initial_node_count = 2

  private_cluster_config {
    enable_private_endpoint = false
    enable_private_nodes    = true

    master_global_access_config {
      enabled = false
    }

    master_ipv4_cidr_block = "172.16.0.0/28"
  }

  project = var.project_id

  release_channel {
    channel = "REGULAR"
  }
  
  subnetwork = "projects/${var.project_id}/regions/${var.location}/subnetworks/${var.subnet_name}"

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  deletion_protection = false

}
