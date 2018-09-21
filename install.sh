#!/bin/bash

# 0. 读取并解析配置文件永远在最开始
source ./kubernetes.conf
# ip数组
master_ip_arr=(${master_ip//,/ })
node_ip_arr=(${node_ip//,/ })
all_ip_arr=(${master_ip_arr[@]} ${node_ip_arr[@]} )
# 主节点IP
first_master_ip=${master_ip_arr[0]}
install_path=`pwd`


# 1. 分发安装脚本到其它服务器
for((i=1;i<${#all_ip_arr[@]};i++))
do
  scp -r $install_path root@node-1:$install_path
done


# 2. 所有节点安装docker
# 主master直接执行
./docker_install.sh "${all_ip_arr[*]}" "1"
# 其余节点远程执行
for((i=1;i<${#all_ip_arr[@]};i++))
do
  ssh root@${all_ip_arr[$i]} "cd $install_path; ./docker_install.sh \"${all_ip_arr[*]}\" \"0\""
done


# 3. 所有master节点安装etcd
# 主master直接执行
./etcd_install.sh "${master_ip_arr[*]}" "${master_ip_arr[0]}" "1" "1"
# 其余节点远程执行
for((i=1;i<${#master_ip_arr[@]};i++))
do
  index=`expr $i + 1`
  ssh root@${master_ip_arr[$i]} "cd $install_path; ./etcd_install.sh \"${master_ip_arr[*]}\" \"${master_ip_arr[$i]}\" \"0\" \"$index\""
done


# 4. master节点安装keepalived
uuid=`cat /proc/sys/kernel/random/uuid`
# 主master直接执行
./keepalived_install.sh "${master_ip_arr[*]}" "${master_ip_arr[0]}" "1" "$load_balancer_dns" "$uuid"
# 其余节点远程执行
for((i=1;i<${#master_ip_arr[@]};i++))
do
  ssh root@${master_ip_arr[$i]} "cd $install_path; ./keepalived_install.sh \"${master_ip_arr[*]}\" \"${master_ip_arr[$i]}\" \"0\" \"$load_balancer_dns\" \"$uuid\""
done


# 5. master节点初始化kubelet
# 主master直接执行
./master_install.sh "${master_ip_arr[*]}" "${node_ip_arr[*]}" "${master_ip_arr[0]}" "1" "$load_balancer_dns" "$load_balancer_port"
# 其余节点远程执行
for((i=1;i<${#master_ip_arr[@]};i++))
do
  index=`expr $i + 1`
  ssh root@${master_ip_arr[$i]} "cd $install_path; ./master_install.sh \"${master_ip_arr[*]}\" \"${node_ip_arr[*]}\" \"${master_ip_arr[$i]}\" \"$index\" \"$load_balancer_dns\" \"$load_balancer_port\""
done


# 6. node节点加入集群
for((i=0;i<${#node_ip_arr[@]};i++))
do
  ssh root@${node_ip_arr[$i]} "cd $install_path; ./node_install.sh; chmod +x join.sh; ./join.sh"
done


# 7. 最后验收，哇哈哈哈
echo "检测是否安装成功："
source ~/.bash_profile
kubectl get pod --all-namespaces -o wide
