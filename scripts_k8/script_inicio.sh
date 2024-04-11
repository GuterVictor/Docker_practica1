#!/bin/bash

# vi /etc/fstab
#
# vi /etc/selinux/config
#SELINUX=disabled
# vi /etc/ssh/sshd_config
#reboot

#swapon -> Nada
#getenforce -> Disabled


firewall-cmd --permanent --add-port={6443,2379,2380,10250,10251,10252,10257,10259,179}/tcp
firewall-cmd --permanent --add-port=4789/udp
firewall-cmd --reload
firewall-cmd --list-all

touch /etc/modules-load.d/k8s.conf
echo "overlay" >> /etc/modules-load.d/k8s.conf
echo "br_netfilter" >> /etc/modules-load.d/k8s.conf

touch /etc/sysctl.d/k8s.conf
echo "net.bridge.bridge-nf-call-iptables = 1" >> /etc/sysctl.d/k8s.conf
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.d/k8s.conf
echo "net.bridge.bridge-nf-call-ip6tables = 1" >> /etc/sysctl.d/k8s.conf
sysctl --system


echo "192.168.0.30 master" >> /etc/hosts
echo "192.168.0.31 worker01" >> /etc/hosts
echo "192.168.0.32 worker02" >> /etc/hosts

yum install -y yum-utils

yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf install containerd.io -y

cp -r /etc/containerd /etc/containerd_resp
mv /etc/containerd/config.toml /etc/containerd/config.toml.bkp

cat /etc/fstab
cat /etc/selinux/config
cat /etc/modules-load.d/k8s.conf
cat /etc/sysctl.d/k8s.conf
cat /etc/hosts
find /etc -name containerd
find /etc -name containerd_resp

#containerd config default ＞ /etc/containerd/config.toml
#vim /etc/containerd/config.toml
#SystemdCgroup = true

######################################################################################
#systemctl status containerd
systemctl enable containerd
systemctl start containerd


cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
EOF

yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

systemctl status kubelet
systemctl enable kubelet
systemctl start kubeletq

reboot

######################################################################################

kubeadm init --control-plane-endpoint=master
#touch kubeadm_resp

usuario="kube"
grupo="wheel"
contraseña="root"

useradd -G $grupo $usuario

expect <<EOF
spawn passwd $usuario
expect "New password:"
send "$contraseña\n"
expect "Retype new password:"
send "$contraseña\n"
expect eof
EOF

echo "Usuario $usuario creado con contraseña $contraseña."

su $usuario
cd 
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
cd $HOME/.kube

kubectl get nodes

########################################################################################

# vi /etc/fstab
# vi /etc/selinux/config

firewall-cmd --permanent --add-port={179,10250,30000-32767}/tcp
firewall-cmd --permanent --add-port=4789/udp
firewall-cmd --reload
firewall-cmd --list-all

touch /etc/modules-load.d/k8s.conf
echo "overlay" >> /etc/modules-load.d/k8s.conf
echo "br_netfilter" >> /etc/modules-load.d/k8s.conf

touch /etc/sysctl.d/k8s.conf
echo "net.bridge.bridge-nf-call-iptables = 1" >> /etc/sysctl.d/k8s.conf
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.d/k8s.conf
echo "net.bridge.bridge-nf-call-ip6tables = 1" >> /etc/sysctl.d/k8s.conf
sysctl --system

yum install -y yum-utils

echo "192.168.0.30 master" >> /etc/hosts
echo "192.168.0.31 worker01" >> /etc/hosts
echo "192.168.0.32 worker02" >> /etc/hosts

dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf install containerd.io -y

cp -r /etc/containerd /etc/containerd_resp
mv /etc/containerd/config.toml /etc/containerd/config.toml.bkp

cat /etc/fstab
cat /etc/selinux/config
cat /etc/modules-load.d/k8s.conf
cat /etc/sysctl.d/k8s.conf
cat /etc/hosts
find /etc -name containerd
find /etc -name containerd_resp

#containerd config default ＞ /etc/containerd/config.toml
#vim /etc/containerd/config.toml
#SystemdCgroup = true

#####################################################################
systemctl restart containerd
systemctl enable containerd
systemctl start containerd


cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
EOF

yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

systemctl status kubelet
systemctl enable kubelet
systemctl start kubelet


reboot

#######################################################################

kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.3/manifests/calico.yaml
kubectl get pods --all-namespaces
kubectl label node worker0 node-role.kubernetes.io/worker=worker


kubectl create deployment web-app01 --image nginx --replicas 2
kubectl expose deployment web-app01 --type NodePort --port 80
kubectl get deployment web-app01
kubectl get pods
kubectl get svc web-app01
curl worker0:31225

