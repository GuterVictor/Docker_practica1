#!/bin/bash

hostnamectl set-hostname k8-controlplane

echo "192.168.0.30 k8-controlplane" >> /etc/hosts
echo "192.168.0.31 k8-worker01" >> /etc/hosts
echo "192.168.0.32 k8-worker02" >> /etc/hosts

# Desabilitar swap
sudo sysctl -w vm.swappiness=0
sudo sed -i '/ swap /s/^/#/g' /etc/fstab
sudo mount -a
sudo swapoff -a
sysctl vm.swappiness
cat /proc/swaps

# Poner en permisivo el SELINUX
setenforce 0
sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/sysconfig/selinux

reboot


#!/bin/bash

cat > /etc/NetworkManager/conf.d/calico.conf << EOF
[keyfile]
unmanaged-devices=interface-name:cali*;interface-name:tunl*;interface-name:vxlan.calico;interface-name:vxlan-v6.calico;interface-name:wireguard.cali;interface-name:wg-v6.cali
EOF

sysctl -w net.netfilter.nf_conntrack_max=1000000
echo "net.netfilter.nf_conntrack_max=1000000" >> /etc/sysctl.conf

dnf install kernel-devel-$(uname -r) -y

firewall-cmd --permanent --add-port={6443,2379,2380,10250,10251,10252,10257,10259,179,443,10255,5473}/tcp
firewall-cmd --permanent --add-port={4789,51820,51821}/udp
firewall-cmd --reload
firewall-cmd --list-all

modprobe br_netfilter
modprobe overlay

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

yum install -y yum-utils
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "tag": "{{.Name}}",
    "max-size": "2m",
    "max-file": "2"
  }
}
EOF

systemctl enable --now docker

mkdir -p /opt/bin/
sudo curl -fsSLo /opt/bin/flanneld https://github.com/flannel-io/flannel/releases/download/v0.19.0/flanneld-amd64
sudo chmod +x /opt/bin/flanneld

cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.28/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
systemctl enable --now kubelet
 
yum install -y make go git wget
git clone https://github.com/Mirantis/cri-dockerd.git

cd cri-dockerd && make cri-dockerd

mkdir -p /usr/local/bin && \
install -o root -g root -m 0755 cri-dockerd /usr/local/bin/cri-dockerd && \
install packaging/systemd/* /etc/systemd/system && \
sed -i -e 's,/usr/bin/cri-dockerd,/usr/local/bin/cri-dockerd,' /etc/systemd/system/cri-docker.service

systemctl daemon-reload && systemctl enable --now cri-docker

# Regenerar ID de maquina
rm -f /etc/machine-id && systemd-machine-id-setup
cat /sys/class/dmi/id/product_uuid

# cgroup = systemd --> cgroupDriver: systemd
docker info | grep -i cgroup

cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "tag": "{{.Name}}",
    "max-size": "2m",
    "max-file": "2"
  },
  "exec-opts": [
    "native.cgroupdriver=systemd"
  ]
}
EOF

systemctl restart docker

kubeadm config images pull --cri-socket unix:///var/run/cri-dockerd.sock

kubeadm init \
    --control-plane-endpoint=192.168.0.30 \
    --apiserver-advertise-address=192.168.0.30 \
    --node-name k8-controlplane \
    --apiserver-bind-port=6443 \
    --pod-network-cidr=10.244.0.0/16 \
    --cri-socket unix:///var/run/cri-dockerd.sock \
    --v=5

source <(kubectl completion bash)
kubectl completion bash > /etc/bash_completion.d/kubectl



wget https://get.helm.sh/helm-v3.13.1-linux-amd64.tar.gz
tar zxvf helm-v3.13.1-linux-amd64.tar.gz
cp linux-amd64/helm /usr/local/bin/helm

kubectl create ns kube-flannel && \
kubectl label --overwrite ns kube-flannel pod-security.kubernetes.io/enforce=privileged && \
helm repo add flannel https://flannel-io.github.io/flannel/ && \
helm install flannel --set podCidr="10.244.0.0/16" --namespace kube-flannel flannel/flannel

# kubeadm token create --print-join-command
# --cri-socket unix:///var/run/cri-dockerd.sock

kubeadm join 192.168.1.100:6443 
    --token cxxxxs.c4xxxxxxxxxxxxd0 \
    --discovery-token-ca-cert-hash sha256:103d7xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx5b1b6 \
    --cri-socket unix:///var/run/cri-dockerd.sock

# Restablecer todo el cluster
kubeadm reset -f --cri-socket unix:///var/run/cri-dockerd.sock
rm -rf /etc/cni/net.d