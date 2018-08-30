#!/bin/bash
echo "安装最新版本的docker"

# 1. 安装最新docker
if [ "`rpm -qa | grep docker-ce`" == "" ];then
  yum install -y yum-utils
  yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
  yum makecache fast
  yum -y install docker-ce
  systemctl start docker
  systemctl enable docker
fi

# 2. pull需要的images，并重新打标签
images=(etcd-amd64:3.2.18)
for imageName in ${images[@]} ; do
  docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/$imageName
  docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/$imageName k8s.gcr.io/$imageName
  docker rmi registry.cn-hangzhou.aliyuncs.com/google_containers/$imageName
done

