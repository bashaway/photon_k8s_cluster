#!/bin/bash

timeout=3
password="changeme"
newpassword="photon#pwd"

pubkey=`cat ~/.ssh/authorized_keys`
#pubkey=`curl -sSL https://github.com/[GitHub USERNAME].keys`
#pubkey='ssh-rsa AAAAB3NzaC1yc2...( paste publickey )...'

hostname=$1
address=$2
newaddress=$3
addr_gw=$4
addr_dns=$5
domain=$6

command="ssh -l root $address  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
hostname="${hostname}.${domain}"

cmd_pubkey="echo '${pubkey}' > ~/.ssh/authorized_keys "

cmd_change_ssh_login_method="sed /etc/ssh/sshd_config -i -e 's/^#PermitRootLogin prohibit-password/PermitRootLogin prohibit-password/'"
cmd_change_ssh_agent_forward="sed /etc/ssh/sshd_config -i -e 's/^#AllowAgentForwarding yes/AllowAgentForwarding yes/'"
cmd_restart_ssh="systemctl restart sshd"

cmd_ip_config="
cat > /etc/systemd/network/10-static-en.network << EOF
\[Match\]
Name=eth0
\[Network\]
Address=${newaddress}/24
Gateway=${addr_gw}
Domains=${domain}
DNS=${addr_dns}
EOF
"
cmd_chmod="chmod 644 /etc/systemd/network/10-static-en.network"
cmd_del_dhcp="rm -f /etc/systemd/network/99-dhcp-en.network"

cmd_change_hostname="hostnamectl set-hostname ${hostname}"
cmd_restart_network="systemctl restart systemd-networkd & exit"

expect -c "
    log_user 0;
    set timeout ${timeout}
    spawn -noecho ${command}

    expect \"Password:\"
    send \"${password}\n\"
    expect \"Current password:\"
    send \"${password}\n\"
    expect \"New password:\"
    send \"${newpassword}\n\"
    expect \"Retype new password:\"
    send \"${newpassword}\n\"
    expect \"root@photon-machine\"

    send \"${cmd_pubkey}\n\"
    expect \"root@photon-machine\"

    send \"${cmd_change_ssh_login_method}\n\"
    expect \"root@photon-machine\"
    send \"${cmd_change_ssh_agent_forward}\n\"
    expect \"root@photon-machine\"
    send \"${cmd_change_restart_ssh}\n\"
    expect \"root@photon-machine\"

    send \"${cmd_ip_config}\n\"
    expect \"root@photon-machine\"
    send \"${cmd_chmod}\n\"
    expect \"root@photon-machine\"
    send \"${cmd_del_dhcp}\n\"
    expect \"root@photon-machine\"

    send \"${cmd_change_hostname}\n\"
    expect \"root@${hostname}\"
    send \"${cmd_restart_network}\n\"
    expect \"root@${hostname}\"

    exit 0
"


