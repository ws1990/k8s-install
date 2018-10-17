#!/bin/bash

# ip数组
ip_arr=($1)
# 是否主master。1 是；0 不是
is_first_master=$2
install_path=`pwd`

image_array=(k8s.gcr.io/etcd-amd64:3.2.18 k8s.gcr.io/kube-apiserver-amd64:v1.11.2 k8s.gcr.io/kube-controller-manager-amd64:v1.11.2 k8s.gcr.io/kube-scheduler-amd64:v1.11.2 k8s.gcr.io/kube-proxy-amd64:v1.11.2 k8s.gcr.io/pause:3.1 k8s.gcr.io/coredns:1.1.3 quay.io/calico/node:v3.1.3 quay.io/calico/cni:v3.1.3)
image_repo='registry.cn-hangzhou.aliyuncs.com/ws_k8s'

pull_image() {
  for image in ${image_array[@]} ; do
    image_name=${image%:*}
    if [ "`docker images | grep ${image_name}`" == "" ];then
      ali_image=${image_repo}/${image//\//_}
      docker pull ${ali_image}
      docker tag ${ali_image} ${image}
      docker rmi ${ali_image}
    fi
  done
}

export_image() {
  for image in ${image_array[@]} ; do
    image_name=${image%:*}
    # 如果本地没有该镜像，则不导出（一般不会出现该情况）
    if [ "`docker images | grep ${image_name}`" == "" ];then
      continue;
    fi

    image_file=${image//\//_}.tar
    echo $image_file

    docker save -o $image_file $image_name
  done
}

import_image() {
  for image in ${image_array[@]} ; do
    image_name=${image%:*}
    # 如果本地没有该镜像，则从文件导入
    if [ "`docker images | grep ${image_name}`" == "" ];then
      image_file=${image//\//_}.tar
      docker load < images/$image_file
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
    scp -r $image_path root@${ip_arr[$i]}:$install_path
  done
else 
  # 直接导入镜像
  import_image $image_path
fi


# 3. 清理
rm -rf images
