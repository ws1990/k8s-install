#!/bin/bash

# 0. 读取并解析配置文件永远在最开始
source ./kubernetes.conf
# ip数组
ip_arr=(${master_ip//,/ })
# 当前IP
current_ip=""
# 当前IP在数组中的索引，从1开始
current_index=0
for((i=0;i<${#ip_arr[@]};i++))
do
  ip_addr_result=`ip addr | grep ${ip_arr[$i]}`
  if [ "$ip_addr_result" != "" ];then
    current_ip=${ip_arr[$i]}
    current_index=`expr $i + 1`
  fi
done



# 1. 安装指定版本的kubelet kubectl kubeadm
if [ ! -e "/etc/yum.repos.d/kubernetes.repo" ];then
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
fi
if [ ! -e "/etc/sysctl.d/k8s.conf" ];then
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
fi
if [ "`rpm -qa | grep kube`" == "" ];then
  version="1.11.2-0"
  yum install -y kubelet-$version.x86_64 kubeadm-$version.x86_64 kubectl-$version.x86_64
  systemctl enable kubelet
  systemctl daemon-reload
fi


# 2. 修改配置文件
etcd_endpoints=""
for((i=0;i<${#ip_arr[@]};i++))
do
  current_info="- https://${ip_arr[$i]}:2379"
  if [ $i -eq 0 ];then
    etcd_endpoints=$current_info
  else
    etcd_endpoints=$etcd_endpoints,$current_info
  fi
done
etcd_endpoints=`echo $etcd_endpoints | sed 's/,/\n        /g'`
cat <<EOF > kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1alpha2
kind: MasterConfiguration
kubernetesVersion: v1.11.2
apiServerCertSANs:
- "${load_balancer_dns}"
api:
    controlPlaneEndpoint: "${load_balancer_dns}:${load_balancer_port}"
etcd:
    external:
        endpoints:
        ${etcd_endpoints}
        caFile: /etc/kubernetes/pki/etcd/ca.pem
        certFile: /etc/kubernetes/pki/etcd/etcd.pem
        keyFile: /etc/kubernetes/pki/etcd/etcd-key.pem
networking:
    podSubnet: "192.168.0.0/16"
EOF


# 3. 初始化master
# 禁用swap
sed -i 's/^\/dev\/mapper\/centos-swap/#\/dev\/mapper\/centos-swap/g' /etc/fstab
swapoff -a
kubeadm init --config kubeadm-config.yaml --ignore-preflight-errors=Port-10250


# 4. 清理
rm -f kubeadm-config.yaml
