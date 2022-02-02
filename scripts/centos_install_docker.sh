# Eject cloud-init
sudo eject

# Setting SELinux to permissive
sudo setenforce 0
sudo sed -i 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config

sudo sestatus | grep "Current mode"

# Disabling firewalld
sudo systemctl stop firewalld
sudo systemctl disable firewalld

# Remove any previous Docker version
sudo dnf remove docker \
  docker-client \
  docker-client-latest \
  docker-common \
  docker-latest \
  docker-latest-logrotate \
  docker-logrotate \
  docker-engine

# Use CentOS 8 Vault repo due to CentOS 8 EOL on December 31, 2021
sudo sed -i -e "s/^mirrorlist/#mirrorlist/g" -e "s/^#baseurl/baseurl/g" -e "s/mirror./vault./g" /etc/yum.repos.d/*.repo

# Install iptables but disable it (https://github.com/moby/moby/issues/41799 & https://cloud.google.com/compute/docs/troubleshooting/known-issues)
sudo dnf install -y iptables-services
sudo chkconfig iptables off

# Install iSCSI and NFS CentOS packages for Nutanix Volumes and Files CSI support
sudo dnf install -y iscsi-initiator-utils nfs-utils
sudo systemctl enable iscsid
sudo systemctl start iscsid

# Install Docker 19.03+
sudo dnf install -y yum-utils
sudo yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io
sudo systemctl enable docker
sudo systemctl start docker

# Verify you are now running version 19.03+
sudo docker version

# Add your user to the docker group
sudo usermod -aG docker $USER

# Change default cgroup driver to systemd
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
EOF

sudo systemctl restart docker
sudo docker info | grep -i cgroup
