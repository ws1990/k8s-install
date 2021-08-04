#!/bin/bash

# 0. 读取并解析配置文件永远在最开始
source ./kubernetes.conf
# ip数组
master_ip_arr=(${master_ip//,/ })
node_ip_arr=(${node_ip//,/ })
all_ip_arr=(${master_ip_arr[@]} ${node_ip_arr[@]})
all_pwd_arr=(${master_pwd//,/ } ${node_pwd//,/ })
# 主节点IP
first_master_ip=${master_ip_arr[0]}
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
  ssh root@${node_ip_arr[$i]} "hostnamectl set-hostname node`expr ${i} + 1` | echo \"$first_master_ip master1\" >> /etc/hosts"
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
# 其余master节点远程执行
for((i=1;i<${#master_ip_arr[@]};i++))
do
  echo "其它master节点执行master-install: ${master_ip_arr[$i]}"
  ssh root@${master_ip_arr[$i]} "cd $install_path; ./master-install.sh"
done


# 5. 第一个master节点安装网络插件并生成join.sh
echo "主节点安装pod network"
# 安装网络插件calico
kubectl create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml
kubectl create -f https://docs.projectcalico.org/manifests/custom-resources.yaml

# 生成join.sh
echo "#!/bin/bash" > join.sh
grep -Pzo "kubeadm join .*\n.*--discovery-token-ca-cert-hash.*" tmp.txt >> join.sh
sed -i '2iecho "KUBELET_EXTRA_ARGS=--node-ip=$1" > /etc/sysconfig/kubelet' join.sh
  
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
  ssh root@${node_ip_arr[$i]} "cd $install_path; ./node-install.sh; chmod +x join.sh; ./join.sh ${node_ip_arr[$i]}"
done


# 6. 检查集群是否安装成功
echo "检测是否安装成功："
source ~/.bash_profile
kubectl get pods -A -o wide