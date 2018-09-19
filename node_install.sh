#!/bin/bash

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
