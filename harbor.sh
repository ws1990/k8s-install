#!/bin/bash
ca_dir="/data/cert"
ca_hostname=$1
install_dir=`pwd`
all_ip_arr=($2)
harbor_ip=${all_ip_arr[0]}


# 创建证书
generate_ca() {
  if [ ! -d "${ca_dir}" ];then
    mkdir -p ${ca_dir}
  fi

  cd ${ca_dir}
  openssl req -newkey rsa:4096 -nodes -sha256 -keyout ca.key -x509 -days 3650 -out ca.crt -subj "/C=CN/L=ChengDu/O=lisea/CN=harbor-registry"
  openssl req -newkey rsa:4096 -nodes -sha256 -keyout ${ca_hostname}.key -out server.csr -subj "/C=CN/L=ChengDu/O=lisea/CN=${ca_hostname}"
  openssl x509 -req -days 3650 -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out ${ca_hostname}.crt

  if [ "`cat /etc/hosts | grep ${ca_hostname}`" == "" ];then
    echo "${harbor_ip} ${ca_hostname}" >> /etc/hosts
  fi

  # 复制证书到docker目录下
  client_crt_dir="/etc/docker/certs.d/${ca_hostname}"
  mkdir -p ${client_crt_dir}
  cp ${ca_dir}/ca.crt ${client_crt_dir}
  # 复制证书和hosts到其它客户端
  for((i=1;i<${#all_ip_arr[@]};i++))
  do
    client_ip=${all_ip_arr[$i]}
    ssh root@${client_ip} "mkdir -p ${client_crt_dir}"
    scp ${ca_dir}/ca.crt root@${client_ip}:${client_crt_dir}
    scp /etc/hosts root@${client_ip}:/etc
  done
}


# 安装harbor
install_harbor() {
  cd ${install_dir}  

  # 安装docker-compose
  if [ "`docker-compose -v`" == "" ];then
    curl -L "https://github.com/docker/compose/releases/download/1.22.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
  fi

  # 替换配置文件
  tar -xvf harbor-offline-installer-v1.5.3.tgz
  cd harbor
  sed -i "s/hostname = reg.mydomain.com/hostname = ${ca_hostname}/g" harbor.cfg
  sed -i "s/ui_url_protocol = http/ui_url_protocol = https/g" harbor.cfg
  sed -i "s/ssl_cert = \/data\/cert\/server.crt/ssl_cert = \/data\/cert\/${ca_hostname}.crt/g" harbor.cfg
  sed -i "s/ssl_cert_key = \/data\/cert\/server.key/ssl_cert_key = \/data\/cert\/${ca_hostname}.key/g" harbor.cfg

  # 执行安装脚本
  ./install.sh
}



generate_ca
install_harbor
