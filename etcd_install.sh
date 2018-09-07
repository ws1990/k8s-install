#!/bin/bash
echo '开始安装etcd'

# ip数组
ip_arr=($1)
# 当前IP
current_ip=$2
# 是否主master。1 是；0 不是
is_first_master=$3
# 当前节点在所有节点中的索引，从1开始
current_index=$4


# 生成密钥文件
generate_cert_files(){
  # 下载所需工具
  install_path=`pwd`
  if [ ! -e "cfssl" ];then
    curl -o ./cfssl https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
    curl -o ./cfssljson https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
    chmod +x cfssl*
  fi

  # 替换模版文件
  cp ./template/*.json .
  ip_str=${ip_arr[*]}
  ip_json=${ip_str/ /\",\"}
  sed -i "s/HOST/\"$ip_json\"/g" etcd-csr.json
  cat etcd-csr.json

  # 生成密钥
  if [ ! -d "/etc/kubernetes/pki/etcd" ];then
    mkdir -p /etc/kubernetes/pki/etcd
  fi
  cp ca-config.json ca-csr.json etcd-csr.json /etc/kubernetes/pki/etcd/
  cd /etc/kubernetes/pki/etcd
  $install_path/cfssl gencert -initca ca-csr.json | $install_path/cfssljson -bare ca -
  $install_path/cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=server etcd-csr.json | $install_path/cfssljson -bare etcd

  # 将密钥文件分发到从master节点
  for((i=1;i<${#ip_arr[@]};i++))
  do  
    ssh root@${ip_arr[$i]} "mkdir -p /etc/kubernetes/pki/etcd"
    scp ./* root@${ip_arr[$i]}:/etc/kubernetes/pki/etcd
  done

  # 清理
  cd $install_path
  rm -f ./cfssl*
  rm -f ./*.json
}

# 1. 判断是否是主的master节点，如果是，则生成密钥文件并分发
if [ $is_first_master -eq 1 ];then
  echo "当前节点为主master节点，需要生成密钥文件"
  generate_cert_files 
fi


# 2. 替换docker运行命令脚本
check_cluster_info=""
cluster_info=""
for((i=0;i<${#ip_arr[@]};i++))
do
  current_info="etcd-`expr $i + 1`=https://${ip_arr[$i]}:2380"
  check_current_info="https://${ip_arr[$i]}:2379"
  if [ $i -eq 0 ];then
    cluster_info=$current_info
    check_cluster_info=$check_current_info
  else 
    cluster_info=$cluster_info,$current_info
    check_cluster_info=$check_cluster_info,$check_current_info
  fi
done

docker_cmd="docker run -d \
--restart always \
-v /etc/kubernetes/pki/etcd:/etc/ssl/certs \
-v /var/lib/etcd:/var/lib/etcd \
-p 4001:4001 \
-p 2380:2380 \
-p 2379:2379 \
--name etcd \
k8s.gcr.io/etcd-amd64:3.2.18 \
etcd --name=etcd-${current_index}
    --data-dir /var/lib/etcd \
    --listen-client-urls https://0.0.0.0:2379,https://0.0.0.0:4001 \
    --advertise-client-urls https://${current_ip}:2379,https://${current_ip}:4001 \
    --listen-peer-urls https://0.0.0.0:2380 \
    --initial-advertise-peer-urls https://${current_ip}:2380 \
    --cert-file=/etc/ssl/certs/etcd.pem \
    --key-file=/etc/ssl/certs/etcd-key.pem \
    --client-cert-auth \
    --trusted-ca-file=/etc/ssl/certs/ca.pem \
    --peer-cert-file=/etc/ssl/certs/etcd.pem \
    --peer-key-file=/etc/ssl/certs/etcd-key.pem \
    --peer-client-cert-auth \
    --peer-trusted-ca-file=/etc/ssl/certs/ca.pem \
    --initial-cluster $cluster_info \
    --initial-cluster-token iss-etcd-token_9477af68bbee1b9ae037d6fd9e7efefd \
    --initial-cluster-state new"


# 3. docker运行etcd
if [ "`docker ps | grep etcd`" != "" ];then
  docker stop etcd
fi
if [ "`docker ps -a | grep etcd`" != "" ];then
  docker rm etcd
fi
if [ ! -d "/var/lib/etcd" ];then
  mkdir -p /var/lib/etcd
fi
$docker_cmd

etcd_check="etcdctl --ca-file=/etc/ssl/certs/ca.pem --cert-file=/etc/ssl/certs/etcd.pem --key-file=/etc/ssl/certs/etcd-key.pem --endpoints=$check_cluster_info cluster-health"
echo "当所有节点都安装etcd完成后，请通过 docker exec -it etcd bin/sh 进入容器，并运行以下命令检查"
echo "$etcd_check"
