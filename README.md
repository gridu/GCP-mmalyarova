# Capstone GCP

**Utils version**

To prevent automatic upgrades to new major versions that may contain breaking
changes, it is recommended to add version with the constraint strings
suggested below.

- Google Cloud SDK: 286.0.0
- Terrafrom: 0.12.24
- Ansible: 2.9.6
- Bash: 3.2.57
------------

**Prerequisites**

- Create the Google Cloud Project; 
- By path `./terraform/variables.tf` in variable `project` set your project name as default;
- Create and setup deploy service account `<name>@<gcp_project_name>.iam.gserviceaccount.com`
- Download and place .json service account key by path `./creds/terraform-admin.json`
- In order to gain ssh access for instances after deployment, provide the path to your public key 
in the `ssh_pub_key_file` variable or create a separate public key by `./creds/public_rsa` path without changing the 
`ssh_pub_key_file` variable;

**Ansible setup**

The Ansible will configure resources after completing the terraforms process 
using `ansible` user who uses the private key from `~/.ssh/id_rsa` path. To change this configuration use the file 
`./ansible/setup.yaml`.

**Note!** The public key has been added to the instance metadata from the private key above. To change the public key, return to the prerequisites' 
section  and change the necessary data.



**Placed GCP resources**

`google_compute_health_check`
`google_compute_http_health_check`
`google_compute_firewall`
`google_compute_target_pool`
`google_compute_instance_template`
`google_compute_instance_group_manager`
`google_compute_autoscaler`
`google_compute_forwarding_rule`

and some `null_resource`

------------
**How to use:**

deploy.sh script is a init entry for setup Google Cloud SDK, 
activate service account for deployment, deploy Google Cloud resources via terraform and
configure the environment with Ansible.
```
./deploy.sh
```

In order to clean the environment, use cleanup.sh script.
```
./cleanup.sh
```