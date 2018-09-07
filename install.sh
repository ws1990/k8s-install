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
for((i=0;i<${#all_ip_arr[@]};i++))
do
  if [ $i -eq 0 ];then
    # 主master直接本地执行
    ./docker_install.sh "${all_ip_arr[*]}" "1"
  else
    # 其余远程执行脚本
    ssh root@${all_ip_arr[$i]} "cd /root; ./docker_install.sh \"${all_ip_arr[*]}\" \"0\""
  fi
done
#./test.sh "${all_ip_arr[*]}" "1"
