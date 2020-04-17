#!/bin/bash
#此脚本目前只是为了方便centos7下安装vsftp,其他版本后期集成。
#ftp数据存放目录
# by liwentong 20191219
ftp_data=/home/ftp
chcek_friewalld(){
    echo "开始检查防火墙设置"
    systemctl status firewalld |grep runing & >/dev/null
    if [ $? -ne 0 ]
    then
        firewall-cmd --add-port=21/tcp --zone=public --permanent
        firewall-cmd --add-service=ftp
        firewall-cmd --reload
    fi
    if [ $? -eq 0 ]
    then
        echo "防火墙开启成功"
    fi
    useradd -s /sbin/nologin ftp
}
#搭建ftp
install_vsftp(){
    echo "开始安装vsftp 并且检查环境" 
    yum -y install vsftpd libdb-utils
    if [ $? -ne 0 ]
    then
        echo "请检查你的yum源情况，是否出现无法用，可单独在终端执行 yum makecache 测试"
        exit 1
    fi
    #检查防火墙,开放21端口
    chcek_friewalld
    echo "开始配置ftp"
    mv /etc/vsftpd/vsftpd.conf /etc/vsftpd/vsftpd.conf_bak
    #配置数据写入到配置文件

    cat >/etc/vsftpd/vsftpd.conf<<LWT
listen=yes
anonymous_enable=no
dirmessage_enable=YES
xferlog_enable=YES
xferlog_file=/var/log/vsftpd.log
xferlog_std_format=YES
chroot_list_enable=YES
chroot_list_file=/etc/vsftpd/chroot_list
chroot_local_user=yes
guest_enable=YES
guest_username=ftp
user_config_dir=/etc/vsftpd/vsftpd_user_conf
pam_service_name=vsftpd.vu
allow_writeable_chroot=YES
local_enable=YES
LWT

    read -p "输入ftp用户:" ftp_user
    if [ ! -n "$ftp_user" ];then
        ftp_user=test
    fi
    read -p "输入ftp用户密码:" ftp_passwd
    if [ ! -n "$ftp_passwd" ];then
        ftp_passwd=123456
    fi
    cd /etc/vsftpd
    echo $ftp_user >/etc/vsftpd/user.txt
    echo $ftp_passwd >>/etc/vsftpd/user.txt
    db_load -T -t hash -f user.txt vsftpd_login.db
    chmod 600 /etc/vsftpd/vsftpd_login.db
    touch /etc/pam.d/vsftpd.vu
    echo "判断此系统是32位操作系统还是64位"
    #判断centos系统位64位还是32位
    xd=`getconf LONG_BIT`
    if [ $xd  -eq '64' ];then
        echo "此系统为64位"
        echo "auth required /lib64/security/pam_userdb.so db=/etc/vsftpd/vsftpd_login" >  /etc/pam.d/vsftpd.vu
        echo "account required /lib64/security/pam_userdb.so db=/etc/vsftpd/vsftpd_login" >> /etc/pam.d/vsftpd.vu
    else
        echo "auth required /lib/security/pam_userdb.so db=/etc/vsftpd/vsftpd_login" > /etc/pam.d/vsftpd.vu
        echo "account required /lib/security/pam_userdb.so db=/etc/vsftpd/vsftpd_login" >> /etc/pam.d/vsftpd.vu
    fi
    #限制用户切换工作目录
    touch /etc/vsftpd/chroot_list
    echo $ftp_user >>/etc/vsftpd/chroot_list
    #配置虚拟用户的配置文件
    mkdir -p /etc/vsftpd/vsftpd_user_conf
    cd /etc/vsftpd/vsftpd_user_conf
    #写入用户权限配置
    cat >$ftp_user <<LWT
write_enable=YES
anon_world_readable_only=NO
anon_upload_enable=YES
anon_mkdir_write_enable=YES
anon_other_write_enable=YES
LWT
    echo "local_root="$ftp_data/$ftp_user>>$ftp_user
    mkdir -p $ftp_data
    chown -R ftp:root $ftp_data
    chmod o+rw $ftp_data
    mkdir -p $ftp_data/$ftp_user
    chmod -R 777 $ftp_data/$ftp_user
    systemctl restart vsftpd.service
}
#创建虚拟用户
create_user(){
    ftp_passwd=123456
    read -p "输入你要创建的用户名:" ftp_user
    if [ ! -n  "$ftp_user" ];then
        echo "你没有输入用户名,退出"
        exit 1
    else
        read -p "输入密码:" ftp_pass
        if [ ! -n "$ftp_pass" ];then
            echo "密码没有输入,默认123456"
        else
            ftp_passwd=$ftp_pass
        fi
    fi
    cd /etc/vsftpd
    echo $ftp_user >>/etc/vsftpd/user.txt
    echo $ftp_passwd >>/etc/vsftpd/user.txt
    db_load -T -t hash -f user.txt /etc/vsftpd/vsftpd_login.db
    chmod 600 /etc/vsftpd/vsftpd_login.db
    echo $ftp_user >>/etc/vsftpd/chroot_list
    cd /etc/vsftpd/vsftpd_user_conf
    cat >$ftp_user<<LWT 
write_enable=YES
anon_world_readable_only=NO
anon_upload_enable=YES
anon_mkdir_write_enable=YES
anon_other_write_enable=YES
LWT
    echo "local_root="$ftp_data/$ftp_user>>$ftp_user
    mkdir -p $ftp_data/$ftp_user
    chmod -R 777 $ftp_data/$ftp_user
}


echo "输入你要操作的内容"
select var in install_vsftpd create_user quit
do
    
    case $var in 
    install_vsftpd)
        install_vsftp;
        ;;
    create_user)
        create_user
        ;;
    quit)
        exit 1
        ;;
    esac
done
