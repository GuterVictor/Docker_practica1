dnf install nfs-utils

systemctl enable --now nfs-server rpcbind

firewall-cmd --add-service={nfs,nfs3,mountd,rpc-bind} --permanent