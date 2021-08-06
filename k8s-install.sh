#!/bin/bash

# 0. 读取并解析配置文件永远在最开始
source ./kubernetes.conf
# master节点IP
master_ip_arr=(${master_ip//,/ })
# 工作节点IP
node_ip_arr=(${node_ip//,/ })
# 所有节点IP
all_ip_arr=(${master_ip_arr[@]} ${node_ip_arr[@]})
# 所有节点密码
all_pwd_arr=(${master_pwd//,/ } ${node_pwd//,/ })
# 工作目录
install_path=`pwd`

yum install -y expect
echo "分发密钥，可以免密执行scp命令"
for((i=1;i<${#all_ip_arr[@]};i++))
do
  ./auto_ssh.sh root ${all_pwd_arr[$i]} ${all_ip_arr[$i]}
done

# 设置主机名
echo "设置主机名"
hostnamectl set-hostname "master1"
for((i=1;i<${#master_ip_arr[@]};i++))
do
  ssh root@${master_ip_arr[$i]} "hostnamectl set-hostname master`expr ${i} + 1`"
done
for((i=0;i<${#node_ip_arr[@]};i++))
do
  ssh root@${node_ip_arr[$i]} "hostnamectl set-hostname node`expr ${i} + 1`"
done


# 1. 分发安装脚本到其它服务器
echo "分发执行脚本"
for((i=1;i<${#all_ip_arr[@]};i++))
do
  scp -r $install_path root@${all_ip_arr[$i]}:$install_path
done


# 2. 所有节点设置系统配置
# 主master直接执行
echo "执行脚本setting.sh"
./setting.sh
# 其余节点远程执行
for((i=1;i<${#all_ip_arr[@]};i++))
do
  ssh root@${all_ip_arr[$i]} "cd $install_path; ./setting.sh"
done


# 3. 所有节点安装docker
# 主master直接执行
echo "主master节点安装docker"
./docker-install.sh
# 其余节点远程执行
for((i=1;i<${#all_ip_arr[@]};i++))
do
  echo "其它节点安装docker: ${all_ip_arr[$i]}"
  ssh root@${all_ip_arr[$i]} "cd $install_path; ./docker-install.sh"
done


# 4. 安装主节点
echo "主master节点执行master-install.sh"
./master-install.sh

if [ "`ls | grep images.tar`" == "" ];then
  # 提前下载好镜像，避免从节点重复下载镜像
  docker pull calico/apiserver:v3.20.0
  docker pull calico/node:v3.20.0
  docker pull calico/pod2daemon-flexvol:v3.20.0
  docker pull calico/cni:v3.20.0
  docker pull calico/typha:v3.20.0
  docker pull calico/kube-controllers:v3.20.0
  docker pull quay.io/tigera/operator:v1.20.0
  # 如果存在工作节点，则导出镜像，避免工作节点再从互联网下载镜像
  if [ ${#node_ip_arr[@]} -gt 0 ];then
    # 工作节点需要使用该镜像，导出后，立即删除
    echo "导出docker镜像"
    docker images | awk '{print $1}' | sed -n '2,$p' | xargs docker save -o images.tar
  fi
fi

echo "主节点安装pod network"
# 安装网络插件calico
kubectl create -f ./network/tigera-operator.yaml
kubectl create -f ./network/custom-resources.yaml

# 生成join.sh
echo "#!/bin/bash" > join.sh
grep -Pzo "kubeadm join .*\n.*--discovery-token-ca-cert-hash.*" tmp.txt >> join.sh
sed -i '2iecho "KUBELET_EXTRA_ARGS=--node-ip=$1" > /etc/sysconfig/kubelet' join.sh


# 5. 安装其它master节点，注意末尾的参数Y，表示需删除images.tar
for((i=1;i<${#master_ip_arr[@]};i++))
do
  echo "其它master节点执行master-install: ${master_ip_arr[$i]}"
  scp images.tar root@${master_ip_arr[$i]}:$install_path
  ssh root@${master_ip_arr[$i]} "cd $install_path; ./master-install.sh Y"
done


# 6. 安装工作节点
if [ ${#node_ip_arr[@]} -eq 0 ]; then
  # 如果所有的工作节点为空，则允许master节点运行pod（及单机模式）
  kubectl taint node master1 node-role.kubernetes.io/master-
else
  # 分发join.sh给其它node节点
  for((i=0;i<${#node_ip_arr[@]};i++))
  do
    echo "分发join.sh到工作节点: ${node_ip_arr[$i]}"
    scp join.sh root@${node_ip_arr[$i]}:$install_path
  done

  # 5. 安装工作节点
  for((i=0;i<${#node_ip_arr[@]};i++))
  do
    echo "安装工作节点: ${node_ip_arr[$i]}"
    # 安装所需软件并加入集群；通过--node-ip指定网卡，否则多网卡环境下会报错
    scp images.tar root@${node_ip_arr[$i]}:$install_path
    ssh root@${node_ip_arr[$i]} "cd $install_path; ./node-install.sh; chmod +x join.sh; ./join.sh ${node_ip_arr[$i]}"
  done
fi


# 7. 检查集群是否安装成功
echo "检测是否安装成功："
source ~/.bash_profile
kubectl get pods -A -o wide


# # 8. 清理
# # rm -f images.tar
# docker image prune -af
# for((i=1;i<${#all_ip_arr[@]};i++))
# do
#   # 其它节点清除不用镜像
#   ssh root@${all_ip_arr[$i]} "docker image prune -af"
# done