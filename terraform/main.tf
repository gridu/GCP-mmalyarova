provider "google"       {
	region     = var.region
	zone       = var.zone
	project    = var.project
}

resource "google_compute_project_metadata_item" "ssh-keys" {
  key   = "ssh-keys"
  value = "ansible:${file(var.ssh_pub_key_file)}"
}

resource "google_compute_health_check" "l3_autohealing_health_check" {
  name                  = "l3-autohealing-health-check"
  timeout_sec           = 5
  check_interval_sec    = 20
  healthy_threshold     = 1
  unhealthy_threshold   = 5
  tcp_health_check      {
    port = "80"
  }
}

resource "google_compute_http_health_check" "l7_balancing_health_check" {
  name                  = "l7-balancing-health-check"
  request_path          = "/health"
  timeout_sec           = 10
  check_interval_sec    = 20
  healthy_threshold     = 1
  unhealthy_threshold   = 5
}

resource "google_compute_firewall" "firewall" {
  name                  = "allow-health-check"
  network               = "default"
  target_tags           = ["webapp","dev"]
  allow                 {
    protocol            = "tcp"
    ports               = ["80"]
  }
}

resource "google_compute_target_pool" "tp" {
  name                  = "lb"
  health_checks         = [google_compute_http_health_check.l7_balancing_health_check.self_link]
}

resource "google_compute_instance_template" "apache" {
  name                  = "apache-cluster"
  machine_type          = "f1-micro"
  tags                  = ["webapp","dev"]
  network_interface     {
    network             = "default"
    access_config       {
    }
  }
  disk                  {
    source_image        = "ubuntu-minimal-1604-xenial-v20200317"
  }
  depends_on = [google_compute_project_metadata_item.ssh-keys]
}

resource "google_compute_instance_group_manager" "igm" {
  name                  = "instance-group-manager"
  target_pools          = [google_compute_target_pool.tp.self_link]
  version {
    name = "version"
    instance_template  = google_compute_instance_template.apache.self_link
  }
  base_instance_name    = "apache"
  zone                  = "europe-west3-b"
  target_size           = 3
  auto_healing_policies {
    health_check        = google_compute_health_check.l3_autohealing_health_check.self_link
    initial_delay_sec   = 300
  }
}

resource "google_compute_autoscaler" "autoscaler" {
  name                  = "autoscaler"
  zone                  = "europe-west3-b"
  target                = google_compute_instance_group_manager.igm.self_link
  autoscaling_policy    {
    max_replicas        = 3
    min_replicas        = 3
    cooldown_period     = 60
  }
}

resource "google_compute_forwarding_rule" "lbr" {
  name                  = "load-balancer"
  target                = google_compute_target_pool.tp.self_link
  port_range            = "80"
  network_tier          = "STANDARD"
}

resource "null_resource" "ip" {
  provisioner "local-exec" {
    command =<<EOF
      ips="$(gcloud compute instances list --format='value (EXTERNAL_IP)' | tr -s ' ' | cut -d ' ' -f 2 | tr '\n' ',' | sed 's/,$//')"
      cd ../ansible
      ansible-playbook -i $ips setup.yaml
      EOF
  }
  depends_on = [google_compute_instance_group_manager.igm]
}