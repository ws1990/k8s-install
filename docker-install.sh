#!/bin/bash

# 安装docker
mkdir /etc/docker
cat <<EOF | tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "registry-mirrors": [
    "https://vspbbu1z.mirror.aliyuncs.com",
    "https://docker.mirrors.ustc.edu.cn",
    "https://reg-mirror.qiniu.com",
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