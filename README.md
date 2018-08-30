# k8s集群安装
## 一、概述
1. 目前安装版本为官方最新版本1.11.2（截止2018-08-27）。
2. 安装脚本主要参考kubernetes官方文档，采用kubeadm来搭建集群，与官方最大的区别是使用国内镜像源替换了google。

## 二、环境
| 服务器   | ip            | 组件                 | 描述        |
| - | - | - | - |
| 虚拟IP | 192.168.56.50 | - | 虚拟IP |
| master-1 | 192.168.56.51 | kubelet,docker | 主master节点 |
| master-2 | 192.168.56.52 | kubelet,docker | 从master节点 |
| node-1 | 192.168.56.53 | kubelet,docker | 工作节点1 |
| node-2 | 192.168.56.54 | kubelet,docker | 工作节点2 |

## 三、安装步骤
### 1. 准备
1. master-1可以免密ssh到所有节点
```shell
# 1. 生成公钥，输入命令后一直Enter
ssh-keygen -t rsa
# 2. 将公钥发布到其它节点
ssh-copy-id -i ~/.ssh/id_rsa.pub 192.168.56.52
ssh-copy-id -i ~/.ssh/id_rsa.pub 192.168.56.53
ssh-copy-id -i ~/.ssh/id_rsa.pub 192.168.56.54
```

### 2. 修改配置文件kubernetes.conf
```shell
version=v1.11.2                        # kubernetes版本
master_ip=192.168.56.51,192.168.56.52  # 所有master节点的ip，第一个为主master节点
```

### 2. 安装docker并加载基本镜像

### 3. 安装etcd

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