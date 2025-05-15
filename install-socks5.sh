#!/bin/bash

# socks5-server 安装脚本
# 作者: Tiancaizhi9098
# GitHub: https://github.com/Tiancaizhi9098/socks-server

set -e

# 文字颜色
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
PLAIN="\033[0m"

# 默认配置
DEFAULT_PORT="1080"
DEFAULT_USER="sockuser"
DEFAULT_PASS="sockpass"
DEFAULT_BIND="0.0.0.0"
DAEMON_USER="socks5"
SOCKS_SERVICE="/etc/systemd/system/socks5-server.service"
SOCKS_CONFIG="/etc/socks5/config.json"
SOCKS_BIN="/usr/local/bin/microsocks"

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}错误: 必须使用root用户运行此脚本!${PLAIN}"
        exit 1
    fi
}

# 检测系统类型
check_sys() {
    if [ -f /etc/redhat-release ]; then
        release="centos"
    elif grep -Eqi "debian" /etc/issue; then
        release="debian"
    elif grep -Eqi "ubuntu" /etc/issue; then
        release="ubuntu"
    elif grep -Eqi "centos|red hat|redhat" /etc/issue; then
        release="centos"
    elif grep -Eqi "debian" /proc/version; then
        release="debian"
    elif grep -Eqi "ubuntu" /proc/version; then
        release="ubuntu"
    elif grep -Eqi "centos|red hat|redhat" /proc/version; then
        release="centos"
    else
        echo -e "${RED}未检测到系统版本，请联系脚本作者!${PLAIN}" && exit 1
    fi
    
    # 检测系统位数
    if [ $(uname -m) = "x86_64" ]; then
        arch="amd64"
    elif [ $(uname -m) = "aarch64" ]; then
        arch="arm64"
    else
        arch="386"
    fi
}

# 安装依赖
install_dependencies() {
    echo -e "${GREEN}安装依赖包...${PLAIN}"
    if [ "${release}" == "centos" ]; then
        yum update -y
        yum install -y gcc make wget curl tar git
    else
        apt-get update -y
        apt-get install -y gcc make wget curl tar git
    fi
}

# 安装MicroSocks
install_microsocks() {
    echo -e "${GREEN}安装MicroSocks...${PLAIN}"
    TMP_DIR=$(mktemp -d)
    cd $TMP_DIR
    
    git clone https://github.com/rofl0r/microsocks.git
    cd microsocks
    make
    mkdir -p $(dirname $SOCKS_BIN)
    
    # 停止现有MicroSocks服务（如果运行）
    if systemctl is-active --quiet socks5-server; then
        echo -e "${YELLOW}检测到正在运行的MicroSocks服务，正在停止...${PLAIN}"
        systemctl stop socks5-server || true
        sleep 1
    fi
    
    # 检查是否有进程占用microsocks二进制文件
    if lsof $SOCKS_BIN >/dev/null 2>&1; then
        echo -e "${YELLOW}MicroSocks二进制文件被占用，正在终止相关进程...${PLAIN}"
        fuser -k $SOCKS_BIN || true
        sleep 1
    fi
    
    # 尝试复制二进制文件，最多重试3次
    retries=3
    for ((i=1; i<=retries; i++)); do
        if cp microsocks $SOCKS_BIN 2>/dev/null; then
            echo -e "${GREEN}MicroSocks二进制文件复制成功${PLAIN}"
            break
        else
            echo -e "${YELLOW}复制MicroSocks二进制文件失败，重试 $i/$retries...${PLAIN}"
            sleep 2
        fi
        if [ $i -eq $retries ]; then
            echo -e "${RED}错误: 无法复制MicroSocks二进制文件，可能是文件仍被占用${PLAIN}"
            exit 1
        fi
    done
    
    chmod +x $SOCKS_BIN
    
    # 创建配置目录
    mkdir -p $(dirname $SOCKS_CONFIG)
    
    # 创建服务用户
    id -u $DAEMON_USER > /dev/null 2>&1 || useradd -r -s /bin/false $DAEMON_USER
    
    # 清理临时目录
    cd / && rm -rf $TMP_DIR
}

# 配置Socks5服务
configure_socks() {
    echo -e "${GREEN}配置Socks5服务...${PLAIN}"
    
    # 提示用户输入配置信息
    read -p "请输入服务监听地址 [$DEFAULT_BIND]: " bind_address
    bind_address=${bind_address:-$DEFAULT_BIND}
    
    read -p "请输入端口号 [$DEFAULT_PORT]: " port
    port=${port:-$DEFAULT_PORT}
    
    read -p "是否启用UDP支持? (y/n): " udp_enabled
    if [[ "${udp_enabled,,}" == "y" ]]; then
        UDP_ARGS="-U"
    else
        UDP_ARGS=""
    fi
    
    read -p "是否需要身份验证? (y/n): " auth_needed
    if [[ "${auth_needed,,}" == "y" ]]; then
        read -p "请输入用户名 [$DEFAULT_USER]: " username
        username=${username:-$DEFAULT_USER}
        
        read -p "请输入密码 [$DEFAULT_PASS]: " password
        password=${password:-$DEFAULT_PASS}
        
        AUTH_ARGS="-u $username -P $password"
    else
        AUTH_ARGS=""
        username=""
        password=""
    fi
    
    # 创建systemd服务文件
    cat > $SOCKS_SERVICE << EOF
[Unit]
Description=MicroSocks Socks5 Server
After=network.target

[Service]
User=$DAEMON_USER
ExecStart=$SOCKS_BIN -i $bind_address -p $port $UDP_ARGS $AUTH_ARGS
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    
    # 保存配置信息(用于后续更新或显示)
    cat > $SOCKS_CONFIG << EOF
{
    "bind_address": "$bind_address",
    "port": "$port",
    "udp_enabled": "${udp_enabled,,}",
    "auth": "${auth_needed,,}",
    "username": "$username",
    "password": "$password"
}
EOF

    # 设置服务自启动
    systemctl daemon-reload
    systemctl enable socks5-server
    systemctl start socks5-server
    
    # 检查服务状态
    if systemctl is-active --quiet socks5-server; then
        echo -e "${GREEN}Socks5服务已成功启动!${PLAIN}"
    else
        echo -e "${RED}Socks5服务启动失败，请检查日志: journalctl -u socks5-server${PLAIN}"
        exit 1
    fi
}

# 显示安装信息
show_info() {
    echo -e "\n${BLUE}-------- Socks5服务器信息 --------${PLAIN}"
    echo -e "${GREEN}服务状态:${PLAIN} $(systemctl is-active socks5-server)"
    echo -e "${GREEN}服务地址:${PLAIN} $bind_address"
    echo -e "${GREEN}服务端口:${PLAIN} $port"
    echo -e "${GREEN}UDP支持:${PLAIN} ${udp_enabled:-n}"
    
    if [[ "${auth_needed,,}" == "y" ]]; then
        echo -e "${GREEN}需要认证:${PLAIN} 是"
        echo -e "${GREEN}用户名:${PLAIN} $username"
        echo -e "${GREEN}密码:${PLAIN} $password"
    else
        echo -e "${GREEN}需要认证:${PLAIN} 否"
    fi
    
    echo -e "\n${YELLOW}使用方法:${PLAIN}"
    echo -e "- 启动服务: ${GREEN}systemctl start socks5-server${PLAIN}"
    echo -e "- 停止服务: ${GREEN}systemctl stop socks5-server${PLAIN}"
    echo -e "- 重启服务: ${GREEN}systemctl restart socks5-server${PLAIN}"
    echo -e "- 查看状态: ${GREEN}systemctl status socks5-server${PLAIN}"
    echo -e "- 查看日志: ${GREEN}journalctl -u socks5-server${PLAIN}"
    echo -e "\n${BLUE}--------------------------------${PLAIN}"
    
    echo -e "\n${GREEN}Socks5服务器安装完成!${PLAIN}"
    echo -e "${GREEN}作者:${PLAIN} Tiancaizhi9098"
    echo -e "${GREEN}GitHub:${PLAIN} https://github.com/Tiancaizhi9098/socks-server"
}

# 卸载Socks5服务
uninstall_socks() {
    read -p "确定要完全卸载Socks5服务及其所有相关组件吗? (y/n): " confirm
    if [[ "${confirm,,}" == "y" ]]; then
        echo -e "${GREEN}开始卸载Socks5服务...${PLAIN}"
        
        # 停止并禁用服务
        systemctl stop socks5-server 2>/dev/null || true
        systemctl disable socks5-server 2>/dev/null || true
        
        # 删除服务文件和配置
        rm -f $SOCKS_SERVICE
        rm -f $SOCKS_BIN
        rm -rf $(dirname $SOCKS_CONFIG)
        
        # 删除服务用户
        if id -u $DAEMON_USER > /dev/null 2>&1; then
            userdel -r $DAEMON_USER 2>/dev/null || true
        fi
        
        # 删除安装的依赖包
        if [ "${release}" == "centos" ]; then
            yum remove -y gcc make wget curl tar git 2>/dev/null || true
            yum autoremove -y 2>/dev/null || true
        else
            apt-get remove -y gcc make wget curl tar git 2>/dev/null || true
            apt-get autoremove -y 2>/dev/null || true
            apt-get purge -y gcc make wget curl tar git 2>/dev/null || true
        fi
        
        # 清理系统
        systemctl daemon-reload 2>/dev/null || true
        systemctl reset-failed 2>/dev/null || true
        
        echo -e "${GREEN}Socks5服务及其所有相关组件已成功卸载!${PLAIN}"
    else
        echo -e "${YELLOW}取消卸载操作${PLAIN}"
    fi
}

# 主函数
main() {
    if [ "$1" == "uninstall" ]; then
        check_root
        uninstall_socks
        exit 0
    fi
    
    clear
    echo -e "${BLUE}=====================================================${PLAIN}"
    echo -e "${BLUE}                  Socks5服务器安装脚本               ${PLAIN}"
    echo -e "${BLUE}=====================================================${PLAIN}"
    echo -e "${GREEN}作者:${PLAIN} Tiancaizhi9098"
    echo -e "${GREEN}GitHub:${PLAIN} https://github.com/Tiancaizhi9098/socks-server"
    echo -e "${BLUE}=====================================================${PLAIN}"
    
    check_root
    check_sys
    install_dependencies
    install_microsocks
    configure_socks
    show_info
}

main "$@"
