#cloud-config

# set the hostname
fqdn: ${hostname}

# avoid configuring swap using mounts
mounts:
  - [swap, null]

#cloud-config
users:
  - name: ${admin_vm_username}
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh-authorized-keys:
      - ${admin_vm_public_key}
