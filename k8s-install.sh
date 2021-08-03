#!/bin/bash

# 0. 读取并解析配置文件永远在最开始
source ./kubernetes.conf
# ip数组
master_ip_arr=(${master_ip//,/ })
node_ip_arr=(${node_ip//,/ })
all_ip_arr=(${master_ip_arr[@]} ${node_ip_arr[@]})
hostname_arr=(${hostname//,/ })
# 主节点IP
first_master_ip=${master_ip_arr[0]}
install_path=`pwd`

ssh-keygen -t rsa
for((i=1;i<${#all_ip_arr[@]};i++))
do
  ssh-copy-id -i ~/.ssh/id_rsa.pub ${all_ip_arr[$i]}
done


# 1. 分发安装脚本到其它服务器
for((i=1;i<${#all_ip_arr[@]};i++))
do
  scp -r $install_path root@${all_ip_arr[$i]}:$install_path
done


# 2. 所有节点设置系统配置
# 主master直接执行
./setting.sh
# 其余节点远程执行
for((i=1;i<${#all_ip_arr[@]};i++))
do
  ssh root@${all_ip_arr[$i]} "cd $install_path; ./setting.sh"
done


# 3. 所有节点安装docker
# 主master直接执行
./docker-install.sh
# 其余节点远程执行
for((i=1;i<${#all_ip_arr[@]};i++))
do
  ssh root@${all_ip_arr[$i]} "cd $install_path; ./docker-install.sh"
done


# 4. 安装主节点
# 主master直接执行
./master-install.sh
# 其余节点远程执行
for((i=1;i<${#all_ip_arr[@]};i++))
do
  ssh root@${all_ip_arr[$i]} "cd $install_path; ./master-install.sh"
done


# 5. 第一个master节点安装网络插件并生成join.sh
echo "主节点安装pod network"
# 安装网络插件calico
kubectl create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml
kubectl create -f https://docs.projectcalico.org/manifests/custom-resources.yaml

# 生成join.sh
echo "#!/bin/bash" > join.sh
grep -Pzo "kubeadm join .*\n.*--discovery-token-ca-cert-hash.*" tmp.txt >> join.sh
  
# 分发join.sh给其它node节点
for((i=0;i<${#node_ip_arr[@]};i++))
do
  scp join.sh root@${node_ip_arr[$i]}:$install_path
done


# 5. 安装工作节点
for((i=0;i<${#node_ip_arr[@]};i++))
do
  ssh root@${node_ip_arr[$i]} "cd $install_path; ./node-install.sh; chmod +x join.sh; ./join.sh"
done


# 6. 检查集群是否安装成功
echo "检测是否安装成功："
source ~/.bash_profile
kubectl get pod --all-namespaces -o wide