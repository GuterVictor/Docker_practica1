#!/bin/bash

hostnamectl set-hostname k8-worker01

echo "192.168.0.30 k8-controlplane" >> /etc/hosts
echo "192.168.0.31 k8-worker01" >> /etc/hosts

sudo sysctl -w vm.swappiness=0
sudo sed -i '/ swap /s/^/#/g' /etc/fstab
sudo mount -a
sudo swapoff -a
sysctl vm.swappiness
cat /proc/swaps

setenforce 0
sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/sysconfig/selinux

reboot

#!/bin/bash

sysctl -w net.netfilter.nf_conntrack_max=1000000
echo "net.netfilter.nf_conntrack_max=1000000" >> /etc/sysctl.conf
sysctl -w net.ipv6.conf.all.forwarding=1
echo "net.ipv6.conf.all.forwarding = 1" >> /etc/sysctl.conf
sudo sysctl -p

dnf install tar -y

firewall-cmd --permanent --add-port={6443,2379,2380,2381,10250,10251,10252,10257,10259,179,443,10255,5473}/tcp
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
user.max_user_namespaces            = 28633
EOF

sysctl --system
sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward user.max_user_namespaces 

curl -O -L https://github.com/containerd/containerd/releases/download/v1.7.16/containerd-1.7.16-linux-amd64.tar.gz
tar Czxvf /usr/local/ containerd-1.7.16-linux-amd64.tar.gz

mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

cat<<EOF | tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target local-fs.target

[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/containerd

Type=notify
Delegate=yes
KillMode=process
Restart=always
RestartSec=5

# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNPROC=infinity
LimitCORE=infinity
LimitNOFILE=1048576

# Comment TasksMax if your systemd version does not supports it.
# Only systemd 226 and above support this version.
TasksMax=infinity
OOMScoreAdjust=-999

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now containerd

sed -i '/SystemdCgroup/s/false/true/' /etc/containerd/config.toml
systemctl restart containerd

curl -O -L https://github.com/opencontainers/runc/releases/download/v1.1.12/runc.amd64
install -m 755 runc.amd64 /usr/local/sbin/runc

mkdir -p /opt/cni/bin
curl -O -L https://github.com/containernetworking/plugins/releases/download/v1.4.1/cni-plugins-linux-amd64-v1.4.1.tgz
tar -C /opt/cni/bin -xzf cni-plugins-linux-amd64-v1.4.1.tgz

curl -O -L https://github.com/containerd/nerdctl/releases/download/v1.7.6/nerdctl-1.7.6-linux-amd64.tar.gz
tar xf nerdctl-1.7.6-linux-amd64.tar.gz
cp nerdctl /usr/local/bin/

cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

yum clean all && yum makecache

yum install -y kubelet-1.29.5 kubeadm-1.29.5 kubectl-1.29.5 --disableexcludes=kubernetes
systemctl enable --now kubelet

cat <<EOF | tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
EOF

