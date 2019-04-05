#!/bin/sh

# 备份配置文件，避免每次都需要手动输入
cp kubernetes.conf ..

# 通过kubeadm重置
kubeadm reset

# 这个bug是通过仔细比对日志文件才发现的线索，哎，3天时间就浪费在这儿了
for  i in $(systemctl list-unit-files --no-legend --no-pager -l | grep  --color=never -o .*.slice | grep kubepod);do systemctl status  $i; systemctl stop $i;done

# 停止进程
systemctl stop docker kubelet keepalived

# 删除中间生成的文件
rm -rf /var/lib/docker/*
rm -rf /var/lib/etcd/*
rm -rf /var/lib/kubelet/*
rm -rf /etc/kubernetes
# cni一定要删除，否则会出现一些莫名其妙的错误。比如coredns总是从10.96.0.1读取api，从而导致coredns一直起不起来
rm -rf /opt/cni

# 删除安装目录
install_path=`pwd`
rm -rf ${install_path}
