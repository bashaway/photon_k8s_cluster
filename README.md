# Photon OS kubernetes cluster deployment tool

work on ubuntu 20.04

## Pre-Settings at ansible server

### login with ssh private key on ansible server

This privkey will be copied to the photon os machines.

```shell-session
$ ls ~/.ssh/authorized_keys
/home/USER/.ssh/authorized_keys
```

or `pubkey` variable to specific public key / github username.([setup.sh](esxi_photon_deployer/setup.sh))


### install packages

```console
sudo apt-get install -y ansible expect
```

### PowerShell
https://docs.microsoft.com/ja-jp/powershell/scripting/install/installing-powershell-core-on-linux?view=powershell-7.1

```console
sudo apt-get update
sudo apt-get install -y wget apt-transport-https software-properties-common
wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update
sudo add-apt-repository universe
sudo apt-get install -y powershell
```

### PowerCLI
https://docs.vmware.com/jp/VMware-Horizon-7/7.13/horizon-integration/GUID-0D876863-BD3E-4947-A305-5A2AB7CBD26A.html

```powershell
pwsh
Install-Module -Name VMware.PowerCLI -Force
Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false
```

connecting test to esxi host

```powershell
$ pwsh
PS /home/USER> Connect-VIServer [ESXI_HOST] -Force

Specify Credential
Please specify server credential
User: [USERNAME]
Password for user [USERNAME]: [PASSWORD]


Name                           Port  User
----                           ----  ----
[ESXI_HOST]                    443   root

```


### OVF tool

Download Linux64 bundle file

https://customerconnect.vmware.com/jp/downloads/details?downloadGroup=OVFTOOL441&productId=1166

install OVF Tool

```console
chmod 755 VMware-ovftool-4.4.1-16812187-lin.x86_64.bundle
sudo ./VMware-ovftool-4.4.1-16812187-lin.x86_64.bundle --eulas-agreed
```

## Download resouces

### git clone

```console
git clone https://github.com/bashaway/photon_k8s_cluster
cd photon_k8s_cluster
```

### Photon OS
https://github.com/vmware/photon/wiki/Downloading-Photon-OS

Download Photon OS ova file ( Photon OS 4.0 Rev1 )

```console
curl -L https://packages.vmware.com/photon/4.0/Rev1/ova/photon-ova-4.0-ca7c9e9330.ova -o esxi_photon_deployer/photon-ova-4.0-ca7c9e9330.ova
```

## Deploy kubernetes cluster

### pre-configuration

esxi guest os parameters

```shell-session
$ vi esxi_photon_deployer/config.ps1

# photon01.example.com : 192.168.0.101
# photon02.example.com : 192.168.0.102
# photon03.example.com : 192.168.0.103
# photon04.example.com : 192.168.0.104
$num_guests=4
$host_prefix="photon"
$domain_name = "example.com"
$address_prefix = "192.168.0."
$new_host_address = 101

# default gw : 192.168.0.254
# DNS server : 192.168.0.254
$address_gw="192.168.0.254"
$address_dns="192.168.0.254"

# guest machine spec
$cpu=2
$memory=4096

# ESXi Host
$port_group="VM Network"
$datastore="datastore01"
```


kubernetes parametes

```shell-session
$ vi group_vars/all.yml

# set ingress parameters
ingress_address: "192.168.0.181-192.168.0.199"
domain_name: "example.com"


##### if needed #####

# set network parameters
pod_network_cidr: 10.244.0.0/16

# set resource directory name ( playbook temporary files )
dir_resources: "./photon_k8s"

# https://github.com/containernetworking/plugins/releases/
VERSION_CNI: "v1.0.1"

# https://github.com/kubernetes-sigs/cri-tools/releases
VERSION_CRICTL: "v1.22.0"

# https://dl.k8s.io/release/stable.txt
VERSION_K8S: "v1.22.2"
```


### deploy photon os on ESXi host

This script will configure guest os environment settings using to config.ps file.  
Root password will set to "photon#pwd" and login method is set to ssh pubkey. If you want change parameters , edit esxi_photon_deployer/setup.sh file.  

```shell-session
$ pwsh esxi_photon_deployer/esxi_deploy.ps1
ESXi server name or address : <- input esxi hostname or eddress
ESXi server login username  : <- input esxi username
ESXi root password : <- input password
Connecting ESXi host...

#################################
# deploy photon os guest machine
#################################
photon01 : now deploying...
photon02 : now deploying...
photon03 : now deploying...
( ... nodes ... )

#################################
# configure guest machine
#################################
photon01 : now configuring...
photon02 : now configuring...
photon03 : now configuring...
( ... nodes ... )

#################################
# output hosts.ini file
#################################
[master]
photon01.example.com ansible_python_interpreter=/usr/bin/python3

[worker]
photon02.example.com ansible_python_interpreter=/usr/bin/python3
photon03.example.com ansible_python_interpreter=/usr/bin/python3
( ... nodes ... )
```

### deployment kubernetes cluster

check hosts.ini

```ini
[master]
photon01.example.com ansible_python_interpreter=/usr/bin/python3

[worker]
photon02.example.com ansible_python_interpreter=/usr/bin/python3
photon03.example.com ansible_python_interpreter=/usr/bin/python3
( ... nodes ... )
```

play ansible playbook

```console
ansible-playbook playbook_k8s_photon_cluster.yml
```


### reset kubernetes cluster

```console
ansible-playbook playbook_k8s_photon_reset.yml
```


# kubernetes cluster

## dashboard

get infos ( at k8s master node )

```shell-session
# kubectl get pod,deployment,service,ingress -n kubernetes-dashboard
NAME                                             READY   STATUS    RESTARTS   AGE
pod/dashboard-metrics-scraper-856586f554-wkzdr   1/1     Running   0          22m
pod/kubernetes-dashboard-67484c44f6-hvqnw        1/1     Running   0          22m

NAME                                        READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/dashboard-metrics-scraper   1/1     1            1           22m
deployment.apps/kubernetes-dashboard        1/1     1            1           22m

NAME                                TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/dashboard-metrics-scraper   ClusterIP   10.100.66.126   <none>        8000/TCP   22m
service/kubernetes-dashboard        ClusterIP   10.109.30.136   <none>        443/TCP    22m

NAME                                          CLASS    HOSTS                   ADDRESS         PORTS     AGE
ingress.networking.k8s.io/dashboard-ingress   <none>   dashboard.example.com   192.168.0.181   80, 443   22m
```

configure /etc/hosts file ( at test client )

```
---- 8< ---- 8< ----
# for connect check only
192.168.0.181 dashboard.example.com
---- 8< ---- 8< ----
```

dashboard certificate ( test client )

```shell-session
$  openssl s_client -connect dashboard.example.com:443 -quiet
depth=0
verify error:num=18:self signed certificate
verify return:1
depth=0
verify return:1
^C
```


login token ( at k8s master node )

```shell-session
# cat photon_k8s/dashboard_login_token
eyJhbiJSUzI1NiIsIm.....
```

access dashboard ( test client )

https://dashboard.example.com/


## sample ingress

get infos ( at k8s master node )

```shell-session
# kubectl get pod,deployment,service,ingress
NAME                                   READY   STATUS    RESTARTS   AGE
pod/nginx-deployment-db749865c-6j98p   1/1     Running   0          19m
pod/nginx-deployment-db749865c-b5cgs   1/1     Running   0          19m

NAME                               READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/nginx-deployment   2/2     2            2           19m

NAME                    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/kubernetes      ClusterIP   10.96.0.1       <none>        443/TCP   23m
service/nginx-service   ClusterIP   10.102.243.87   <none>        80/TCP    19m

NAME                                      CLASS    HOSTS             ADDRESS         PORTS     AGE
ingress.networking.k8s.io/nginx-ingress   <none>   www.example.com   192.168.0.181   80, 443   19m
```

configure /etc/hosts file ( test client )

```
---- 8< ---- 8< ----
# for connect check only
192.168.0.181 www.example.com
---- 8< ---- 8< ----
```

self-sign certificate ( test client )

```shell-session
$ openssl s_client -connect www.example.com:443 -quiet
depth=0 C = JP, ST = Tokyo, O = example.com, CN = www.example.com
verify error:num=18:self signed certificate
verify return:1
depth=0 C = JP, ST = Tokyo, O = example.com, CN = www.example.com
verify return:1
^C
```

https page info ( test client )

```shell-session
$ curl -Ik https://www.example.com/
HTTP/2 200
date: Thu, 23 Sep 2021 05:18:44 GMT
content-type: text/html
content-length: 612
last-modified: Tue, 14 Apr 2020 14:19:26 GMT
etag: "5e95c66e-264"
accept-ranges: bytes
strict-transport-security: max-age=15724800; includeSubDomains
```

## workaround
re-clustering if ingress page is not accessible.

```console
ansible-playbook playbook_k8s_photon_reset.yml
ansible-playbook playbook_k8s_photon_cluster.yml
```
