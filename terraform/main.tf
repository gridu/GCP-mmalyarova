provider "google"       {
	region     = var.region
	zone       = var.zone
	project    = var.project
}

resource "google_compute_project_metadata_item" "ssh-keys" {
  key   = "ssh-keys"
  value = "mmalyarova:${file(var.ssh_pub_key_file)}"
}

resource "google_compute_http_health_check" "http-health-check" {
  name               = "${var.base_instance_name}-http-health-check"
  request_path       = "/"
  check_interval_sec = 1
  timeout_sec        = 1
}


resource "google_compute_instance_template" "gcp" {
  name                  = "${var.base_instance_name}-template"
  machine_type          = "f1-micro"
  tags 					= ["http-server"]

  network_interface     {
    network             = "${google_compute_network.vpc_network.name}"
      access_config       {
          nat_ip = ""
      }
  }

  disk {
    source_image = "ubuntu-1604-xenial-v20170328"
    auto_delete  = true
    boot         = true
  }

  depends_on = [google_compute_project_metadata_item.ssh-keys]
}

resource "google_compute_region_autoscaler" "instance_group_manager_autoscaler" {
  name   = "region-autoscaler"
  region = "us-central1"
  target = "${google_compute_region_instance_group_manager.instance_group_manager.self_link}"

  autoscaling_policy {
    max_replicas    = 3
    min_replicas    = 3
    cooldown_period = 60
  }
}



resource "google_compute_region_instance_group_manager" "instance_group_manager" {
  name                  = "${var.base_instance_name}-instance-group-manager"

  base_instance_name         = var.base_instance_name

  version {
    name = "frontend"
    instance_template = "${google_compute_instance_template.gcp.self_link}"
  }

  region                     = "us-central1"
  distribution_policy_zones  = ["us-central1-a", "us-central1-b", "us-central1-c"]

  target_size  = 3

  named_port {
    name = "http"
    port = 80
  }

  auto_healing_policies {
    health_check        = "${var.port == "22" ? google_compute_health_check.tcp.self_link : google_compute_health_check.http.self_link }"
    initial_delay_sec = 1200
  }
}

resource "google_compute_health_check" "http" {
  name = "${var.base_instance_name}-health-check-igm-http"
  check_interval_sec  = 1
  timeout_sec         = 1
  http_health_check {
    port = 80
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_health_check" "tcp" {
  name = "${var.base_instance_name}-health-check-igm-tcp"
  //check_interval_sec  = var.readiness_check_interval
  //timeout_sec         = var.readiness_timeout
  tcp_health_check {
    port = 22
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_forwarding_rule" "backend-forwarding-rule" {
  name = "backend-forwarder"
  backend_service = "${google_compute_region_backend_service.backend.self_link}"
  load_balancing_scheme = "INTERNAL"
  ports = ["80"]
  network = "${google_compute_network.vpc_network.name}"
}

resource "google_compute_region_backend_service" "backend" {
  name             = "fd-internal-backend"
  description      = "backend load balancer"
  protocol         = "TCP"
  timeout_sec      = 10
  session_affinity = "NONE"

  backend {
    group = "${google_compute_region_instance_group_manager.instance_group_manager.instance_group}"
  }

  health_checks = ["${google_compute_health_check.http.self_link}"]
}


data "google_compute_region_instance_group" "all" {
  self_link = google_compute_region_instance_group_manager.instance_group_manager.instance_group
  depends_on = [null_resource.wait]
}

data "google_compute_instance" "sample_instance" {
  count     = "3"
  self_link = "${lookup(data.google_compute_region_instance_group.all.instances[count.index], "instance")}"
}

resource "null_resource" "wait" {
  triggers = {
    cluster_instance_ids = "${join(",", google_compute_region_instance_group_manager.instance_group_manager.*.id)}"
  }

  provisioner "local-exec" {
    command = <<-EOF
      sleep 120s
      EOF
  }
}


resource "null_resource" "server_clear" {
  triggers = {
    cluster_instance_ids = "${join(",", google_compute_region_instance_group_manager.instance_group_manager.*.id)}"
  }
  provisioner "local-exec" {
        command = <<-EOF
            echo "[gcp_hosts]" >   "../ansible/inventory/hosts"
        EOF
    }

}

resource "null_resource" "server_add_adress" {
  count = 3
  triggers = {
    cluster_instance_ids = "${join(",", google_compute_region_instance_group_manager.instance_group_manager.*.id)}"
  }
  provisioner "local-exec" {
        command = <<-EOF
            echo "${data.google_compute_instance.sample_instance[count.index].network_interface[0].access_config[0].nat_ip}" >>   "../ansible/inventory/hosts"
        EOF
    }
  depends_on = [null_resource.server_clear]
}

resource "null_resource" "run_ansible" {
  triggers = {
    cluster_instance_ids = "${join(",", google_compute_region_instance_group_manager.instance_group_manager.*.id)}"
  }

  provisioner "local-exec" {
    command = <<-EOF
      cd ../ansible
      ansible-playbook -i inventory/hosts install.yaml
      EOF
  }
  depends_on = [null_resource.server_add_adress, null_resource.wait]
}

resource "google_compute_network" "vpc_network" {
  name = "vpc-network"
  auto_create_subnetworks = true
}

resource "google_compute_firewall" "default" {
  name    = "defauls-firewall-access"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "web" {
  name    = "web-firewall"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  target_tags = ["http-server"]
}
