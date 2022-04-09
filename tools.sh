#!/bin/bash
SERVICE_NAME="gostminer"
CONFIG_PATH="/etc/gostminer/config"
configFile=${CONFIG_PATH}/config.toml 
gostminer_db=${CONFIG_PATH}/gostminer.db
is_yum=`which yum | wc -c`
is_apt=`which apt | wc -c`
sqlite3_flag=`which sqlite3 | wc -c`
socat_flag=`which socat | wc -c`

function pkg_mgr_find()
{
	if [ ${is_yum} -gt "0" ] ; then
		return 1
	elif [ ${is_apt} -gt "0" ] ; then 
		return 2
	else
		echo "can not find package manager for your system,exit!"
		exit
	fi
}

function install_sqlite3()
{
	pkg_mgr_find
	case $? in
	1)
		yum -y install sqlite
		;;
	2)
		apt -y install sqlite3
		;;
	*)
		echo "error code not define!!bug!!"
		exit
		;;
	esac
}

function install_socat()
{
	pkg_mgr_find
	case $? in
	1)
		yum -y install socat
		;;
	2)
		apt -y install socat
		;;
	*)
		echo "error code not define!!bug!!"
		exit
		;;
	esac
}

function mod_listen_port()
{
	echo "开始修改web端口"
	printf "请输入端口号:"
	read new_port
	printf "新端口号是:"
	echo ${new_port}
	sed -i '/port =/d' ${configFile}
	sed -i '/tlsenable/ s/^/port = ":'${new_port}'"\n/' ${configFile}
	echo "修改完成!"
	systemctl restart ${SERVICE_NAME}
	echo "服务已重启!"
}

function reset_password()
{
	install_sqlite3
	sqlite3 ${gostminer_db} "UPDATE "admin_user" SET "password" = '69c5fcebaa65b560eaf06c3fbeb481ae44b8d618' WHERE "admin_user_id" = '1';" ".exit"
	echo "密码已重置"
	echo "新密码是: 123456"
}

function install_ssl_ca()
{
	echo "服务器需要绑定域名才能签发SSL证书"
	echo "签发证书时需要用到80端口，请确认未被其他程序占用!"
	printf "请输入本服务器绑定的域名: "
	read server_domain
	install_socat
	mkdir -p /root/.cert/
	curl https://get.acme.sh | sh
	~/.acme.sh/acme.sh --register-account -m hello@gmail.com
	~/.acme.sh/acme.sh --issue -d ${server_domain} --standalone
	~/.acme.sh/acme.sh --installcert -d ${server_domain} --key-file /root/.cert/private.key --fullchain-file /root/.cert/cert.crt
	cp /root/.cert/cert.crt ${CONFIG_PATH}/server.crt
	cp /root/.cert/private.key ${CONFIG_PATH}/server.key
}

function enable_ccban()
{
	pkg_mgr_find
	case $? in
	1)
		echo "cannot active ccban in redhat system!"
		echo "please switch to debian or ubuntu LTS"
		;;
	2)
		apt -y install ipset
		sed -i '/cc/,/proxy/ { s/false/true/g }' ${configFile}
		echo "cc防护配置已开启正在重启服务!"
		systemctl restart ${SERVICE_NAME}
		echo "服务已重启，如无法访问web请关闭cc防护并联系管理员处理!"
		;;
	*)
		echo "error code not define!!bug!!"
		exit
		;;
	esac
}

function disable_ccban()
{
	sed -i '/cc/,/proxy/ { s/true/false/g }' ${configFile}
	echo "cc防护配置已关闭正在重启服务!"
	systemctl restart ${SERVICE_NAME}
	echo "服务已重启!"
}

echo "        欢迎使用gostminer配置脚本        "
echo "************版本号V1.0.0**************"
echo "*********修复了cc功能开关问题*********"
echo "      1.修改web页面监听端口"
echo "      2.重置web密码"
echo "      3.自动签发并安装SSL证书"
echo "      4.开启cc防护"
echo "      5.关闭cc防护"
echo "***************************************"
read choice
case $choice in
1)	mod_listen_port
	;;
2)	reset_password
	;;
3)	install_ssl_ca
	;;
4)	enable_ccban
	;;
5)	disable_ccban
	;;
esac