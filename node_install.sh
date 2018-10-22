#!/bin/bash

# 1. 安装指定版本的kubelet kubectl kubeadm
cp template/kubernetes.repo /etc/yum.repos.d/
cp template/k8s.conf /etc/sysctl.d/
sysctl --system

# 禁用swap
str_arr=(`cat /etc/fstab | grep '^/dev/mapper/.*swap'`)
str=${str_arr[0]}
str=${str//\//\\\/}
sed -i "s/${str}/#${str}/g" /etc/fstab
swapoff -a

if [ "`rpm -qa | grep kube`" == "" ];then
  version="1.11.2-0"
  yum install -y kubelet-$version.x86_64 kubeadm-$version.x86_64 kubectl-$version.x86_64
  systemctl enable kubelet
  systemctl daemon-reload
fi
