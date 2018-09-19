#!/bin/bash

# 0. 读取并解析配置文件永远在最开始
source ./kubernetes.conf
# ip数组
master_ip_arr=(${master_ip//,/ })
node_ip_arr=(${node_ip//,/ })
all_ip_arr=(${master_ip_arr[@]} ${node_ip_arr[@]} )
# 主节点IP
first_master_ip=${master_ip_arr[0]}


# 1. 分发安装脚本到其它服务器
for((i=1;i<${#all_ip_arr[@]};i++))
do
  scp -r * root@${all_ip_arr[$i]}:/root/
done


# 2. 所有节点安装docker
#for((i=0;i<${#all_ip_arr[@]};i++))
#do
#  if [ $i -eq 0 ];then
#    # 主master直接本地执行
#    ./docker_install.sh "${all_ip_arr[*]}" "1"
#  else
#    # 其余远程执行脚本
#    ssh root@${all_ip_arr[$i]} "cd /root; ./docker_install.sh \"${all_ip_arr[*]}\" \"0\""
#  fi
#done


# 3. 所有master节点安装etcd
for((i=0;i<${#master_ip_arr[@]};i++))
do
  index=`expr $i + 1`
  if [ $i -eq 0 ];then
    # 主master直接本地执行
    ./etcd_install.sh "${master_ip_arr[*]}" "${master_ip_arr[$i]}" "1" "$index"
  else
    # 其余远程执行脚本
    ssh root@${master_ip_arr[$i]} "cd /root; ./etcd_install.sh \"${master_ip_arr[*]}\" \"${master_ip_arr[$i]}\" \"0\" \"$index\""
  fi
done


# 4. master节点安装keepalived
#uuid=`cat /proc/sys/kernel/random/uuid`
#for((i=0;i<${#master_ip_arr[@]};i++))
#do
#  if [ $i -eq 0 ];then
#    # 主master直接本地执行
#    ./keepalived_install.sh "${master_ip_arr[*]}" "${master_ip_arr[$i]}" "1" "$load_balancer_dns" "$uuid"
#  else
#    # 其余远程执行脚本
#    ssh root@${master_ip_arr[$i]} "cd /root; ./keepalived_install.sh \"${master_ip_arr[*]}\" \"${master_ip_arr[$i]}\" \"0\" \"$load_balancer_dns\" \"$uuid\""
#  fi
#done


# 5. master节点初始化kubelet
for((i=0;i<${#master_ip_arr[@]};i++))
do
  index=`expr $i + 1`
  if [ $i -eq 0 ];then
    # 主master直接本地执行
    ./master_install.sh "${master_ip_arr[*]}" "${node_ip_arr[*]}" "${master_ip_arr[$i]}" "$index" "$load_balancer_dns" "$load_balancer_port"
  else
    # 其余远程执行脚本
    ssh root@${master_ip_arr[$i]} "cd /root; ./master_install.sh \"${master_ip_arr[*]}\" \"${node_ip_arr[*]}\" \"${master_ip_arr[$i]}\" \"$index\" \"$load_balancer_dns\" \"$load_balancer_port\""
  fi
done


# 6. node节点加入集群
for((i=0;i<${#node_ip_arr[@]};i++))
do
  ssh root@${node_ip_arr[$i]} "cd /root; ./node_install.sh; chmod +x join.sh; ./join.sh"
done
