#cloud-config

# set the hostname
fqdn: ${hostname}

# avoid configuring swap using mounts
mounts:
  - [swap, null]

#cloud-config
users:
  - name: yannick
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh-authorized-keys:
      - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDTC8cIlJaWgUczOJPzD0Y2ufj57Odj2xxIumjOFKLB7Qctjm+OD3HxYNTtC7ztTz18SAasKCmnrhJ6MsoTRLFW8W98KpAmWmcLLzCDo64ip6x8QRMlRH6oCzZzpGYnttH5lRD1Sd1UYr5aNwnIwHFrLYqXRXSvZ42DVIfGHM2lFXMvFkb6ZF6melRrCFnoixTfZgM0KgbOJMnEXyxCytb7NNBM2HslkFJomVSIH+AN6OcekhF2rwYeewJsa8H6IhVF7Epo7zj/VMeP5waly+e7NbCgXMhZ1R9m04EX+HyGU1le383nOSo+Yq2UxFVucGGLeYQFSXHY82PZeTvvBsUP yannickstruyf@Yannicks-MacBook-Pro.local
  - name: ${admin_vm_username}
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh-authorized-keys:
      - ${admin_vm_public_key}
