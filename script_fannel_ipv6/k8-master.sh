#!/bin/bash

hostnamectl set-hostname k8-master

echo "2001:db8:85a3::1 k8-master" >> /etc/hosts
echo "2001:db8:85a3::2 k8-worker01" >> /etc/hosts

firewall-cmd --add-port=6443/tcp --permanent
firewall-cmd --add-port=2379-2380/tcp --permanent
firewall-cmd --add-port=10250/tcp --permanent
firewall-cmd --add-port=10259/tcp --permanent
firewall-cmd --add-port=10257/tcp --permanent

sudo firewall-cmd --reload
sudo firewall-cmd --list-all

sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
sestatus

modprobe overlay
modprobe br_netfilter

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

sysctl -w net.ipv6.conf.all.forwarding=1
echo "net.ipv6.conf.all.forwarding = 1" >> /etc/sysctl.conf
sudo sysctl -p

swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

dnf install dnf-utils -y

dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf install containerd.io -y

mv /etc/containerd/config.toml /etc/containerd/config.toml.bkp
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null 2>&1
sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

systemctl enable --now containerd

cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
EOF

dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
systemctl enable --now kubelet

source <(kubectl completion bash)
kubectl completion bash > /etc/bash_completion.d/kubectl

mkdir -p /opt/bin/
curl -fsSLo /opt/bin/flanneld https://github.com/flannel-io/flannel/releases/download/v0.19.0/flanneld-amd64

chmod +x /opt/bin/flanneld
lsmod |  grep br_netfilter

kubeadm config images pull

sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --control-plane-endpoint=k8-master --cri-socket=unix:///run/containerd/containerd.sock 

kubeadm init --pod-network-cidr=10.244.0.0/16,2001:db8:42:0::/56 --service-cidr=10.96.0.0/16,2001:db8:42:1::/112 --control-plane-endpoint=k8-master --cri-socket=unix:///run/containerd/containerd.sock

kubectl label node worker0 node-role.kubernetes.io/worker=worker