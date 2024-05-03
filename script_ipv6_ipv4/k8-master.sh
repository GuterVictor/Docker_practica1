#!/bin/bash

hostnamectl set-hostname k8-controlplane

echo "fc00:7e57::16 k8-controlplane" >> /etc/hosts
echo "fc00:7e57::17 k8-worker01" >> /etc/hosts
echo "fc00:7e57::18 k8-worker02" >> /etc/hosts

cat > /etc/NetworkManager/conf.d/calico.conf << EOF
[keyfile]
unmanaged-devices=interface-name:cali*;interface-name:tunl*;interface-name:vxlan.calico;interface-name:vxlan-v6.calico;interface-name:wireguard.cali;interface-name:wg-v6.cali
EOF

sysctl -w net.netfilter.nf_conntrack_max=1000000
echo "net.netfilter.nf_conntrack_max=1000000" >> /etc/sysctl.conf

dnf install kernel-devel-$(uname -r) -y
dnf install iptables-services -y
systemctl restart iptables

sudo modprobe br_netfilter
sudo modprobe ip_vs
sudo modprobe ip_vs_rr
sudo modprobe ip_vs_wrr
sudo modprobe ip_vs_sh
sudo modprobe overlay

cat > /etc/modules-load.d/kubernetes.conf << EOF
br_netfilter
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
overlay
EOF

cat > /etc/sysctl.d/kubernetes.conf << EOF
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sysctl --system

sudo swapoff -a
sed -e '/swap/s/^/#/g' -i /etc/fstab

sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf makecache

sudo dnf -y install containerd.io
cat /etc/containerd/config.toml
sudo sh -c "containerd config default > /etc/containerd/config.toml" ; cat /etc/containerd/config.toml
sudo vim /etc/containerd/config.toml

sudo systemctl enable --now containerd.service
sudo systemctl reboot


#!/bin/bash

sudo firewall-cmd --zone=public --permanent --add-port=179/tcp
sudo firewall-cmd --zone=public --permanent --add-port=443/tcp
sudo firewall-cmd --zone=public --permanent --add-port=6443/tcp
sudo firewall-cmd --zone=public --permanent --add-port=2379-2380/tcp
sudo firewall-cmd --zone=public --permanent --add-port=10250/tcp
sudo firewall-cmd --zone=public --permanent --add-port=10251/tcp
sudo firewall-cmd --zone=public --permanent --add-port=10257/tcp
sudo firewall-cmd --zone=public --permanent --add-port=10259/tcp
sudo firewall-cmd --zone=public --permanent --add-port=10252/tcp
sudo firewall-cmd --zone=public --permanent --add-port=10255/tcp
sudo firewall-cmd --zone=public --permanent --add-port=5473/tcp
sudo firewall-cmd --zone=public --permanent --add-port=4789/udp
sudo firewall-cmd --zone=public --permanent --add-port=51820/udp
sudo firewall-cmd --zone=public --permanent --add-port=51821/udp
sudo firewall-cmd --reload

sudo systemctl stop firewalld
sudo systemctl disable firewalld 

echo 1 | sudo tee /proc/sys/net/ipv6/conf/default/forwarding

cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

dnf makecache; dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes


sudo kubeadm config images pull


sudo kubeadm init --pod-network-cidr=10.244.0.0/16
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

source <(kubectl completion bash)
kubectl completion bash > /etc/bash_completion.d/kubectl


kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/tigera-operator.yaml
curl -O https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/custom-resources.yaml
sed -i 's/cidr: 192\.168\.0\.0\/16/cidr: 10.244.0.0\/16/g' custom-resources.yaml
kubectl create -f custom-resources.yaml





#https://infotechys.com/install-a-kubernetes-cluster-on-rhel-9/
