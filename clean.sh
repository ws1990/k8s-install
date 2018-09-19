#!/bin/sh
kubeadm reset
# 这个bug是通过仔细比对日志文件才发现的线索，哎，3天时间就浪费在这儿了
for  i in $(systemctl list-unit-files --no-legend --no-pager -l | grep  --color=never -o .*.slice | grep kubepod);do systemctl status  $i; systemctl stop $i;done
systemctl stop kubelet

