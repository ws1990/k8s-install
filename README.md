# k8s集群安装
## 一、概述
1. 目前安装版本为官方最新版本1.11.2（截止2018-08-27）。
2. 安装脚本主要参考kubernetes官方文档，采用kubeadm来搭建集群，与官方最大的区别是使用国内镜像源替换了google。
3. 操作系统为CentOS7.5，所有脚本均使用root用户运行，如果在非root用户下，请加上sudo

## 二、环境
| 服务器 | ip | 组件 | 描述 |
| - | - | - | - |
| 虚拟IP | 192.168.56.50 | - | 虚拟IP |
| master-1 | 192.168.56.51 | kubelet,docker | 主master节点 |
| master-2 | 192.168.56.52 | kubelet,docker | 从master节点 |
| node-1 | 192.168.56.53 | kubelet,docker | 工作节点1 |
| node-2 | 192.168.56.54 | kubelet,docker | 工作节点2 |

## 三、安装步骤
### 1. 准备
1. 关闭selinux和防火墙并重启（所有服务器均执行该操作）
```shell
# 关闭selinux
vim /etc/selinux/config

SELINUX=disabled # 修改该值

# 禁用防火墙的开机自启动
systemctl disable firewalld

# 重启
reboot
```

2. master-1可以免密ssh到所有节点（master-1执行）
```shell
# 1. 生成公钥，输入命令后一直Enter
ssh-keygen -t rsa
# 2. 将公钥发布到其它节点
ssh-copy-id -i ~/.ssh/id_rsa.pub 192.168.56.52   # 其它节点命令一样，不在一一列举
```

3. 下载压缩包、修改配置文件并分发（master-1执行）
```shell
# 1. 下载压缩包到master-1节点，并解压
cd /root
curl -fSL xxx -o xxx.tar.gz
tar -xvf xxx.tar.gz
rm -f xxx.tar.gz
# 2. 修改配置文件kubernetes.conf
vim kubernetes.conf

version=v1.11.2                        # kubernetes版本
master_ip=192.168.56.51,192.168.56.52  # 所有master节点的ip，第一个为主master节点
# 3. 将整个安装目录分发到其它节点的对应目录
scp -r * root@192.168.56.52:~/         # 其它节点命令一样，不在一一列举
```

### 2. 安装docker并加载基本镜像（所有服务器执行，master-1最先执行）
```shell
./docker_install.sh
```

### 3. 安装etcd（所有master服务器执行，master-1最先执行）
```shell
./etcd_install.sh
```

### 2. 安装master节点
```shell
# 在master-1服务器执行脚本
./master_install.sh

```

### 3. 安装node节点并加入集群

## 四、错误解决
1. unable to get URL "https://dl.k8s.io/release/stable-1.11.txt": Get https://storage.googleapis.com/kubernetes-release/release/stable-1.11.txt: read tcp 10.0.2.15:43236->216.58.200.16:443: read: connection reset by peer

## 五、参考网址
[kubernetes官方安装手册](https://kubernetes.io/docs/setup/independent/high-availability/)