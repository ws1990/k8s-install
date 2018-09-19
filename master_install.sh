#!/bin/bash

# master的ip数组
master_ip_arr=($1)
# node的ip数组
node_ip_arr=($2)
# 当前IP
current_ip=$3
# 当前IP在数组中的索引，其实位置为1
current_index=$4
# 负载均衡IP
load_balancer_dns=$5
# 负载均衡端口
load_balancer_port=$6
# 是否是主master节点
is_first_master=0
if [ $current_index -eq 1 ];then
  is_first_master=1
fi


# 1. 安装指定版本的kubelet kubectl kubeadm
if [ ! -e "/etc/yum.repos.d/kubernetes.repo" ];then
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
fi
if [ ! -e "/etc/sysctl.d/k8s.conf" ];then
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
fi
if [ "`rpm -qa | grep kube`" == "" ];then
  version="1.11.2-0"
  yum install -y kubelet-$version.x86_64 kubeadm-$version.x86_64 kubectl-$version.x86_64
  systemctl enable kubelet
  systemctl daemon-reload
fi


# 2. 修改配置文件
etcd_endpoints=""
for((i=0;i<${#master_ip_arr[@]};i++))
do
  current_info="- https://${master_ip_arr[$i]}:2379"
  if [ $i -eq 0 ];then
    etcd_endpoints=$current_info
  else
    etcd_endpoints=$etcd_endpoints,$current_info
  fi
done
etcd_endpoints=`echo $etcd_endpoints | sed 's/,/\n    /g'`
cat <<EOF > kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1alpha2
kind: MasterConfiguration
kubernetesVersion: v1.11.2
apiServerCertSANs:
- "${load_balancer_dns}"
api:
  controlPlaneEndpoint: "${load_balancer_dns}:${load_balancer_port}"
etcd:
  external:
    endpoints:
    ${etcd_endpoints}
    caFile: /etc/kubernetes/pki/etcd/ca.pem
    certFile: /etc/kubernetes/pki/etcd/etcd.pem
    keyFile: /etc/kubernetes/pki/etcd/etcd-key.pem
networking:
  podSubnet: "10.244.0.0/16"
EOF
cat kubeadm-config.yaml

# 3. 初始化master
# 禁用swap
sed -i 's/^\/dev\/mapper\/centos-swap/#\/dev\/mapper\/centos-swap/g' /etc/fstab
swapoff -a
touch tmp.txt
echo "执行kubeadm init"
if [ "`cat ~/.bash_profile | grep KUBECONFIG`" == "" ];then
  echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> ~/.bash_profile
fi
export KUBECONFIG=/etc/kubernetes/admin.conf
kubeadm init --config kubeadm-config.yaml --ignore-preflight-errors Port-10250 | tee tmp.txt

# 如果是主的master节点
if [ $is_first_master -eq 1 ];then
  echo "主节点安装pod network"
  kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

  # 生成join.sh
  echo "#!/bin/bash" > join.sh
  echo "swapoff --all" >> join.sh
  cat tmp.txt | grep "kubeadm join" >> join.sh

  # 分发key到其它master节点
  for((i=1;i<${#master_ip_arr[@]};i++))
  do
    scp /etc/kubernetes/pki/ca.crt root@${master_ip_arr[$i]}:/etc/kubernetes/pki/
    scp /etc/kubernetes/pki/ca.key root@${master_ip_arr[$i]}:/etc/kubernetes/pki/
    scp /etc/kubernetes/pki/sa.key root@${master_ip_arr[$i]}:/etc/kubernetes/pki/
    scp /etc/kubernetes/pki/sa.pub root@${master_ip_arr[$i]}:/etc/kubernetes/pki/
  done
  
  # 分发join.sh给其它node节点
  for((i=0;i<${#node_ip_arr[@]};i++))
  do
    scp join.sh root@${node_ip_arr[$i]}:/root/
  done
fi


# 4. 清理
rm -f kubeadm-config.yaml
rm -f tmp.txt

