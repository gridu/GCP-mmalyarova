output "instance_self_link_1" {
  value = "${lookup(data.google_compute_region_instance_group.all.instances[0], "instance")}"
}
output "instance_self_link_2" {
  value = "${lookup(data.google_compute_region_instance_group.all.instances[1], "instance")}"
}
output "instance_self_link_3" {
  value = "${lookup(data.google_compute_region_instance_group.all.instances[2], "instance")}"
}
