#!/bin/bash

# ip数组
ip_arr=($1)
# 当前IP
current_ip=$2
# 是否主master。1 是；0 不是
is_first_master=$3
# 虚拟IP
vip=$4
# 随机密码
uuid=$5


# 1. 安装keepalived
if [ "`rpm -qa | grep keepalived`" == "" ];then
  yum install keepalived -y
fi

# 2. 获取网卡
interface_arr=(`ip addr | grep $current_ip`)
last_index=`expr ${#interface_arr[@]} - 1`
current_interface=${interface_arr[$last_index]}


# 3. 替换配置文件
cp ./template/keepalived.conf /etc/keepalived/
config_file=/etc/keepalived/keepalived.conf
sed -i "s/<VIRTUAL-IP>/$vip/g" $config_file
sed -i "s/<INTERFACE>/$current_interface/g" $config_file
if [ $is_first_master -eq 1 ];then
  sed -i "s/<STATE>/MASTER/g" $config_file
  sed -i "s/<PRIORITY>/100/g" $config_file
else
  sed -i "s/<STATE>/BACKUP/g" $config_file
  sed -i "s/<PRIORITY>/90/g" $config_file
fi
sed -i "s/<UUID>/$uuid/g" $config_file
#cat $config_file


# 4. 启动服务
if [ "`systemctl status keepalived | grep running`" == "" ];then
  systemctl start keepalived
else
  systemctl restart keepalived
fi
systemctl enable keepalived
