#!/bin/bash

# 0. 系统设置
# 禁用selinux
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=disable/' /etc/selinux/config
# 关闭防火墙
systemctl disable firewalld
systemctl stop firewalld
# 禁用swap
str_arr=(`cat /etc/fstab | grep '^/dev/mapper/.*swap'`)
str=${str_arr[0]}
str=${str//\//\\\/}
sed -i "s/${str}/#${str}/g" /etc/fstab
swapoff -a

# 1. 安装kubeadm
# 1.1 允许 iptables 检查桥接流量
modprobe br_netfilter

cat <<EOF | tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

# 1.2 安装docker
mkdir /etc/docker
cat <<EOF | tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "registry-mirrors": [
    "https://vspbbu1z.mirror.aliyuncs.com",
    "https://registry.docker-cn.com",
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com"
  ]
}
systemctl daemon-reload
EOF
if [ "`rpm -qa | grep docker-ce`" == "" ];then
  yum install -y yum-utils
  yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
  yum -y install docker-ce-20.10.7-3.el7.x86_64
  systemctl enable docker
  systemctl start docker
fi

# 1.3 安装kubelet
cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

if [ "`rpm -qa | grep kube`" == "" ];then
  version="1.21.2-0"
  yum install -y kubelet-$version.x86_64 kubeadm-$version.x86_64 kubectl-$version.x86_64 --disableexcludes=kubernetes
  systemctl enable kubelet
  systemctl daemon-reload
fi
systemctl enable --now kubelet

# 1.4 引导集群master
# coredns镜像需要特殊下载，因为阿里镜像不存在
docker pull coredns/coredns:1.8.0
docker tag coredns/coredns:1.8.0 registry.aliyuncs.com/google_containers/coredns:v1.8.0

kubeadm init --config kube-config.yaml --v=5
