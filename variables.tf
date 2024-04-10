variable "project_id" {
    type = string
}

variable "cluster_name" {
    type = string
    default = "w255"  
}

variable "k8s_version" {
    type = string
    default = "1.27.8-gke.1067004"  
}

variable "location" {
    type = string
    default = "us-central1"  
}

variable "machine_type" {
    type = string
    default = "e2-medium"  
}

variable "cloudshell_ip" {
    type = string  
}

variable "network_name" {
    type = string
    default = "default"
}

variable "subnet_name" {
    type = string
    default = "default"
}
