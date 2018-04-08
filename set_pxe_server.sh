#!/bin/bash

# Created by xiaofan.
#PS4='+${BASH_SOURCE}:${LINENO}:${FUNCNAME[0]}: '

# Define global variable

# DHCP variable
subnet=1.1.1.0
netmask=255.255.255.0
range_min=1.1.1.61
range_max=1.1.1.69
subnet_mask=255.255.255.0
next_server=1.1.1.110
pxelinux0="/pxelinux.0"


# tftp variable
# tftpboot means tftp's root directory
# Focus on:
#  if pxe server system version is different from pxe client $isolinux ,
# you need to copy pxelinux.0 to $tftpboot from other places by manual .
tftpboot="/var/lib/tftpboot/"

# HTTP variable
# Public user should be able to access http server 
#  by public_http_ip and var public_http_port.
# DocumentRoot default is /var/www/html/ .

public_http_ip=1.1.1.110
public_http_port=80
DocumentRoot="/var/www/html/"


function check_pkg
{
    # pxe depends on httpd dhcp xinetd tftp-server syslinux ,you can run 
    #    yum install httpd dhcp xinetd tftp-server syslinux -y
    # to install these services

    local pkgs="syslinux httpd dhcpd xinetd"
    for pkg in ${pkgs[*]};
    do
        which $pkg &> /dev/null
        if [[ $? -ne 0 ]];then
            echo "Please install $pkg service"
            exit 1
        fi
    done

    rpm -qa | grep tftp-server &> /dev/null
    if [[ $? -ne 0 ]];then
        echo "Please install tftp-server"
        exit 1
    fi

    # After xinetd installed, check tftpd config file 

    local tftp_conf="/etc/xinetd.d/tftp"
    ls $tftp_conf &> /dev/null
    if [[ $? -ne 0 ]];then
        echo "Not found tftpd config file ,exit 1"
        exit 1
    fi

}
#check_pkg


function check_service_status
{

    # Check httpd status. 
    # PS, httpd work in port 80(tcp),normally.
    netstat -nltp | grep httpd &> /dev/null
    if [[ $? -ne 0 ]];then
        echo "Not found httpd service, exit 1"
        exit 1
    fi

    # Check dhcpd status. 
    # PS. dhcpd work in port 67(udp)
    netstat -nlup | grep dhcpd &> /dev/null
    if [[ $? -ne 0 ]];then
        echo "Not found dhcpd service, exit 1"
        exit 1
    fi

    # Check xinetd status. tftp based on this service
    # xinetd work in port 69(udp)
    netstat -nlup | grep xinetd &> /dev/null
    if [[ $? -ne 0 ]];then
        echo "Not found xinetd service, exit 1"
        exit 1
    fi
}
#check_service_status


function config_dhcpd
{
    # when new insatll dhcpd ,
    # dhcpd.conf will be created in /etc/dhcp/
    # and it is a empty file ,normally
    
    local subnet=$subnet
    local netmask=$netmask
    local range_min=$range_min
    local range_max=$range_max
    local subnet_mask=$subnet_mask
    local next_server=$next_server
    local pxelinux0=$pxelinux0

    local dhcpd_conf="/etc/dhcp/dhcpd.conf"
    ls $dhcpd_conf &> /dev/null
    if [[ $? -ne 0 ]];then
        echo "Not found dhcpd.conf ,exit 1"
        exit 1
    fi

    #backup dhcp config file
    ls $dhcpd_conf.pxebak &> /dev/null
    if [[ $? -ne 0 ]];then
        mv $dhcpd_conf $dhcpd_conf.pxebak
        if [[ $? -ne 0 ]];then
            echo "Failed to backup $dhcpd_conf"
        fi
    fi

    cat <<EOF > $dhcpd_conf
subnet $subnet netmask $netmask {
        range $range_min $range_max;
        option subnet-mask $subnet_mask;
        default-lease-time 21600;
        max-lease-time 43200;
        next-server $next_server;
        filename "$pxelinux0";
}
EOF
    
    
}

function config_tftp
{
    # when new install xinetd ,it will contain tftp, normally.
    # backup tftp config file as ./tftp.pxebak 
    # and create a new tftp config file

    local tftpboot=$tftpboot
    local tftp_conf="/etc/xinetd.d/tftp"

    local pxelinux_cfg_dir=$tftpboot/pxelinux.cfg/
    local pxe_default_file=$pxelinux_cfg_dir/default
    
    local public_http_ip=$public_http_ip
    local public_http_port=$public_http_port


    ls $tftp_conf &> /dev/null
    if [[ $? -ne 0 ]];then
        echo "Not found $tftp_conf exit 1"
        exit 1
    fi
    
    #backup tftp config file
    ls $tftp_conf.pxebak &> /dev/null
    if [[ $? -ne 0 ]];then
        mv $tftp_conf $tftp_conf.pxebak
        if [[ $? -ne 0 ]];then
            echo "Failed to backup $tftp_conf"
        fi
    fi

    # Create pxe default file 
    # $pxelinux_cfg_dir/pxelinux.cfg/default .
    if [ ! -d $pxelinux_cfg_dir ];then
        mkdir $pxelinux_cfg_dir &> /dev/null
        if [[ $? -ne 0 ]];then
            echo "Failed to create $pxelinux_cfg_dir ,exit 1"
            exit 1
        fi
    fi

    # when pxelinux default backup file not exist ,
    # try to create a new backup file.
    ls $pxe_default_file &> /dev/null
    if [[ $? -eq 0 ]];then
        ls $pxe_default_file.pxebak &> /dev/null
        if [[ $? -ne 0 ]];then
            mv $pxe_default_file $pxe_default_file.pxebak
            if [[ $? -ne 0 ]];then
                echo "Failed to backup $pxe_default_file ,exit 1"
                exit 1
            fi
        fi
    fi

    # create pxelinux defafult ,
    # if it exist , overwrite it.
    cat <<EOF > $pxe_default_file
default ks
prompt 0

label ks
  kernel vmlinuz
  append initrd=initrd.img ks=http://$public_http_ip:$public_http_port/kickstart/ks.cfg net.ifnames=0 biosdevname=0 ksdevice=eth0

EOF


    cat <<EOF > $tftp_conf

service tftp
{
        socket_type             = dgram
        protocol                = udp
        wait                    = yes
        user                    = root
        server                  = /usr/sbin/in.tftpd
        server_args             = -s $tftpboot
        disable                 = no
        per_source              = 11
        cps                     = 100 2
        flags                   = IPv4
}
EOF


}

function config_ks_cfg
{
    local public_http_ip=$public_http_ip
    local DocumentRoot=$DocumentRoot

    local ks_cfg_dir=$DocumentRoot/kickstart/
    local ks_cfg_path=$ks_cfg_dir/ks.cfg

    local public_http_ip=$public_http_ip
    local public_http_port=$public_http_port

    if [ ! -d $DocumentRoot ];then
        echo "Dir $DocumentRoot not exist ,exit 1" 
        exit 1
    fi

    # Create ks_cfg_dir
    if [ ! -d $ks_cfg_dir ];then
        mkdir -p $ks_cfg_dir &> /dev/null
        if [[ $? -ne 0 ]];then
            echo "Failed to create dir $ks_cfg_dir ,exit 1"
            exit 1
        fi
    fi


    cat <<EOF > $ks_cfg_path

#plattform=x86, AMD64, or Intel EM64T
# System authorization information
auth  --useshadow  --enablemd5
# System bootloader configuration
bootloader --location=mbr
# Clear the Master Boot Record
zerombr
# Partition clearing information
clearpart --all --initlabel
# Use text mode install
text
# Firewall configuration
firewall --disabled
# Run the Setup Agent on first boot
firstboot --disable
# System keyboard
keyboard us
# System language
lang en_US
# Installation logging level
logging --level=info
# Use network installation
url --url=http://$public_http_ip:$public_http_port/kickstart/iso
# Network information
network --bootproto=dhcp --device=eth0 --onboot=on
# Reboot after installation
reboot
#Root password
rootpw --iscrypted \$1\$uGFO11lh\$MvMKhsLi9R98G0dHw4QwU/

# SELinux configuration
selinux --disabled
# Do not configure the X Window System
skipx
# System timezone
timezone --isUtc Asia/Harbin
# Install OS instead of upgrade
install
# Disk partitioning information
part /boot --bytes-per-inode=4096 --fstype="ext3" --size=128
part swap --bytes-per-inode=4096 --fstype="swap" --size=1024
part / --bytes-per-inode=4096 --fstype="ext3" --grow --size=1

%packages --nobase
%end
EOF
    
}
#config_ks_cfg

function config_sys_boot
{
    local DocumentRoot=$DocumentRoot
    local isolinux=$DocumentRoot/kickstart/iso/isolinux/
    local pxelinux_0="/usr/share/syslinux/pxelinux.0"

    local tftpboot=$tftpboot

    local iso_mnt_dir=`echo $DocumentRoot/kickstart/iso | tr -s /`
    local fstab=/etc/fstab


    # if pxe server system version is different from pxe client $isolinux ,
    # you need to copy pxelinux.0 to $tftpboot from other places by manual
    \cp $pxelinux_0 $tftpboot &> /dev/null
    if [[ $? -ne 0 ]];then
        echo "Faile to copy $pxelinux_0 to $tftpboot ,exit 1"
        exit 1
    fi

    # Create iso_mnt_dir
    if [ ! -d $iso_mnt_dir ];then
        mkdir -p $iso_mnt_dir &> /dev/null
        if [[ $? -ne 0 ]];then
            echo "Failed to create dir $iso_mnt_dir ,exit 1"
            exit 1
        fi
    fi

    # mount cdrom to $iso_mnt_dir
    mount | grep $iso_mnt_dir &> /dev/null
    if [[ $? -ne 0 ]];then
        mount /dev/sr0 $iso_mnt_dir &> /dev/null
        if [[ $? -ne 0 ]];then
            echo "Failed to mount cdrom on $iso_mnt_dir ,exit 1."
            exit 1
        fi
    fi

    # Add auto mount cdrom when system start on
    cat $fstab | grep $iso_mnt_dir &> /dev/null
    if [[ $? -ne 0 ]];then
        echo "/dev/sr0  $iso_mnt_dir iso9660 \
              defaults,ro,loop 0 0" >> $fstab
    fi

    # copy isolinux files to $tftpboot
    \cp $isolinux/* $tftpboot &> /dev/null
    if [[ $? -ne 0 ]];then
        echo "Faile to copy $isolinux list to $tftpboot ,exit 1"
        exit 1
    fi

}

function run_service
{
    chkconfig httpd on
    chkconfig dhcpd on
    chkconfig xinetd on

    service httpd restart 2> /dev/null
    service dhcpd restart 2> /dev/null
    service xinetd restart 2> /dev/null
}

function set_pxe_server
{
    echo -ne "Run check_pkg...\t\t"
    check_pkg
    echo "Done"
    echo -ne "Run config_dhcpd...\t\t"
    config_dhcpd
    echo "Done"
    echo -ne "Run config_tftp...\t\t"
    config_tftp
    echo "Done"
    echo -ne "Run config_ks_cfg...\t\t"
    config_ks_cfg 
    echo "Done"
    echo -ne "Run config_sys_boot...\t\t"
    config_sys_boot
    echo "Done"
    echo -e "Run run_service...\t\t"
    run_service
    echo "Done"
    echo -ne "Run check_service_status...\t"
    check_service_status
    echo "Done"
    echo "Config finished"
}


#set_pxe_server



