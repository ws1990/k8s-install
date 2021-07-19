#!/bin/bash

# 系统设置
# 禁用selinux
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=disable/' /etc/selinux/config
# 关闭防火墙
systemctl disable firewalld
systemctl stop firewalld
# 禁用swap
str_arr=(`cat /etc/fstab | grep '^/dev/mapper/.*swap'`)
str=${str_arr[0]}
str=${str//\//\\\/}
sed -i "s/${str}/#${str}/g" /etc/fstab
swapoff -a