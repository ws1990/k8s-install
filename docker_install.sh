#!/bin/bash

# ip数组
ip_arr=($1)
# 是否主master。1 是；0 不是
is_first_master=$2


pull_image() {
  #image_repo='registry.cn-hangzhou.aliyuncs.com/ws_k8s'
  image_repo='mirrorgooglecontainers'
  images=(etcd-amd64:3.2.18 kube-apiserver-amd64:v1.11.2 kube-controller-manager-amd64:v1.11.2 kube-scheduler-amd64:v1.11.2 kube-proxy-amd64:v1.11.2 pause:3.1)
  for imageName in ${images[@]} ; do
    if [ "`docker images | grep ${imageName%:*}`" == "" ];then
      docker pull $image_repo/$imageName
      docker tag $image_repo/$imageName k8s.gcr.io/$imageName
      docker rmi $image_repo/$imageName
    fi
  done

  # coredns 特殊处理，因为mirrorgooglecontainers这个源没有该镜像。懒惰的家伙！！！
  if [ "`docker images | grep coredns`" == "" ];then
    docker pull coredns/coredns:1.1.3
    docker tag coredns/coredns:1.1.3 k8s.gcr.io/coredns:1.1.3
    docker rmi coredns/coredns:1.1.3
  fi

  # quay.io 单独处理
  quayio_images=(quay.io/calico/node:v3.1.3 quay.io/calico/cni:v3.1.3 quay.io/coreos/flannel:v0.10.0-amd64)
  for imageName in ${quayio_images[@]} ; do
    if [ "`docker images | grep ${imageName%:*}`" == "" ];then
      docker pull $imageName
    fi
  done
}

export_image() {
  images=(`docker images | awk '{print $1}'`)
  versions=(`docker images | awk '{print $2}'`)

  for i in $(seq 0 ${#images[*]}); do
    currentImage=${images[$i]}
    currentVersion=${versions[$i]}

    if [ "$currentImage" == "REPOSITORY" ] || [ "$currentImage" == "" ];then
      continue
    fi

    imgFile=$1/${currentImage//\//_}-$currentVersion.tar
    echo $imgFile

    docker save -o $imgFile $currentImage
  done
}

import_image() {
  for img in `ls images`; do
    imageName=${img#*_}
    imageName=k8s.gcr.io/${imageName%-*}
    if [ "`docker images | grep ${imageName%:*}`" == "" ];then
      echo "导入镜像 $imageName"
      docker load < images/$img
    fi
  done
}


# 1. 安装最新docker
if [ "`rpm -qa | grep docker-ce`" == "" ];then
  yum install -y yum-utils
  yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
  yum makecache fast
  yum -y install docker-ce
  systemctl start docker
  systemctl enable docker
fi


# 2. pull镜像
image_path="images"
if [ ! -d "$image_path" ];then
  mkdir $image_path
fi
if [ $is_first_master -eq 1 ];then
  # 如果是主master，则从云服务器下载镜像
  pull_image

  # 导出镜像
  export_image $image_path
  
  # 分发镜像，ip地址从第二个开始，自己不需要分发
  for((i=1;i<${#ip_arr[@]};i++))
  do
    scp -r $image_path root@${ip_arr[$i]}:/root/
  done
else 
  # 直接导入镜像
  import_image $image_path
fi


# 3. 清理
rm -rf images
