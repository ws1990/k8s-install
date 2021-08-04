#!/bin/bash

# 允许 iptables 检查桥接流量
modprobe br_netfilter

cat <<EOF | tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

# 安装kubelet、kubeadm
cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

# coredns镜像需要特殊下载，因为阿里镜像不存在
docker pull coredns/coredns:1.8.0
docker tag coredns/coredns:1.8.0 registry.aliyuncs.com/google_containers/coredns:v1.8.0

if [ "`rpm -qa | grep kube`" == "" ];then
  version="1.21.2-0"
  yum install -y kubelet-$version.x86_64 kubeadm-$version.x86_64 --disableexcludes=kubernetes
  systemctl enable kubelet
  systemctl daemon-reload
fi
systemctl enable --now kubelet