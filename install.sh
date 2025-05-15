#!/bin/bash

# Socks5服务端安装脚本
# 基于MicroSocks实现
# 作者: Tiancaizhi9098
# 项目地址: https://github.com/Tiancaizhi9098/socks-server

set -e

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
PLAIN="\033[0m"

# 检测系统架构
ARCH=$(uname -m)
case $ARCH in
    x86_64)
        ARCH="amd64"
        ;;
    aarch64)
        ARCH="arm64"
        ;;
    arm*)
        ARCH="arm"
        ;;
    *)
        echo -e "${RED}不支持的系统架构: $ARCH${PLAIN}"
        exit 1
        ;;
esac

# 检测操作系统类型
check_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        if [ "$OS" = "centos" ] && [ ! -z "$VERSION_ID" ]; then
            VERSION_NUM=$(echo "$VERSION_ID" | cut -d. -f1)
            if [ "$VERSION_NUM" -lt 7 ]; then
                echo -e "${RED}不支持CentOS 7以下版本${PLAIN}"
                exit 1
            fi
        elif [ "$OS" = "debian" ] && [ ! -z "$VERSION_ID" ]; then
            VERSION_NUM=$(echo "$VERSION_ID" | cut -d. -f1)
            if [ "$VERSION_NUM" -lt 9 ]; then
                echo -e "${RED}不支持Debian 9以下版本${PLAIN}"
                exit 1
            fi
        elif [ "$OS" = "ubuntu" ] && [ ! -z "$VERSION_ID" ]; then
            VERSION_NUM=$(echo "$VERSION_ID" | cut -d. -f1)
            if [ "$VERSION_NUM" -lt 18 ]; then
                echo -e "${RED}不支持Ubuntu 18.04以下版本${PLAIN}"
                exit 1
            fi
        fi
    else
        echo -e "${RED}不支持的操作系统${PLAIN}"
        exit 1
    fi
    
    echo -e "${GREEN}检测到操作系统: $OS ${VERSION_ID}${PLAIN}"
}

# 安装依赖
install_deps() {
    echo -e "${YELLOW}正在安装依赖...${PLAIN}"
    case $OS in
        debian|ubuntu)
            apt-get update -y
            apt-get install -y curl wget git build-essential
            ;;
        centos|fedora|rhel)
            if [ $OS = "centos" ] && [ ${VERSION_ID:0:1} -eq 7 ]; then
                yum install -y epel-release
            fi
            yum -y update
            yum install -y curl wget git gcc make
            ;;
        arch|manjaro)
            pacman -Sy --noconfirm curl wget git base-devel
            ;;
        alpine)
            apk update
            apk add --no-cache curl wget git gcc make musl-dev
            ;;
        *)
            echo -e "${RED}不支持的操作系统: $OS${PLAIN}"
            exit 1
            ;;
    esac
    echo -e "${GREEN}依赖安装完成${PLAIN}"
}

# 安装MicroSocks
install_microsocks() {
    echo -e "${YELLOW}正在安装MicroSocks...${PLAIN}"
    cd /tmp
    git clone https://github.com/rofl0r/microsocks.git
    cd microsocks
    make
    mkdir -p /usr/local/bin
    cp microsocks /usr/local/bin/
    chmod +x /usr/local/bin/microsocks
    echo -e "${GREEN}MicroSocks安装完成${PLAIN}"
}

# 生成随机字符串
random_string() {
    tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 16
}

# 配置Socks5服务
configure_socks5() {
    DEFAULT_BIND="0.0.0.0"
    DEFAULT_PORT="1080"
    DEFAULT_USER=$(random_string)
    DEFAULT_PASS=$(random_string)
    
    echo -e "${BLUE}请配置Socks5服务:${PLAIN}"
    read -p "服务地址 (默认: $DEFAULT_BIND): " BIND_ADDR
    BIND_ADDR=${BIND_ADDR:-$DEFAULT_BIND}
    
    read -p "服务端口 (默认: $DEFAULT_PORT): " BIND_PORT
    BIND_PORT=${BIND_PORT:-$DEFAULT_PORT}
    
    read -p "用户名 (默认: $DEFAULT_USER): " USERNAME
    USERNAME=${USERNAME:-$DEFAULT_USER}
    
    read -p "密码 (默认: $DEFAULT_PASS): " PASSWORD
    PASSWORD=${PASSWORD:-$DEFAULT_PASS}
    
    read -p "启用UDP转发? (y/n, 默认: y): " ENABLE_UDP
    ENABLE_UDP=${ENABLE_UDP:-y}
    
    read -p "设置开机自启? (y/n, 默认: y): " ENABLE_AUTOSTART
    ENABLE_AUTOSTART=${ENABLE_AUTOSTART:-y}
    
    # 创建配置目录
    mkdir -p /etc/socks5-server
    
    # 写入配置文件
    cat > /etc/socks5-server/config << EOF
BIND_ADDR=$BIND_ADDR
BIND_PORT=$BIND_PORT
USERNAME=$USERNAME
PASSWORD=$PASSWORD
ENABLE_UDP=$ENABLE_UDP
EOF
    
    echo -e "${GREEN}配置完成${PLAIN}"
}

# 创建systemd服务
create_service() {
    echo -e "${YELLOW}正在创建系统服务...${PLAIN}"
    
    cat > /etc/systemd/system/socks5-server.service << EOF
[Unit]
Description=MicroSocks Socks5 Server
After=network.target

[Service]
Type=simple
User=root
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/microsocks -i \${BIND_ADDR} -p \${BIND_PORT} -u \${USERNAME} -P \${PASSWORD} \${UDP_OPT}
EnvironmentFile=/etc/socks5-server/config

[Install]
WantedBy=multi-user.target
EOF

    # 修复UDP参数
    if [[ "$ENABLE_UDP" =~ ^[Yy]$ ]]; then
        sed -i 's/${UDP_OPT}/-U/g' /etc/systemd/system/socks5-server.service
    else
        sed -i 's/${UDP_OPT}//g' /etc/systemd/system/socks5-server.service
    fi
    
    systemctl daemon-reload
    
    if [[ "$ENABLE_AUTOSTART" =~ ^[Yy]$ ]]; then
        systemctl enable socks5-server
    fi
    
    systemctl start socks5-server
    
    echo -e "${GREEN}服务创建并启动成功${PLAIN}"
}

# 显示配置信息
show_config() {
    echo
    echo -e "${GREEN}========== Socks5服务已安装 ==========${PLAIN}"
    echo -e "${YELLOW}服务地址:${PLAIN} $BIND_ADDR"
    echo -e "${YELLOW}服务端口:${PLAIN} $BIND_PORT"
    echo -e "${YELLOW}用户名:${PLAIN} $USERNAME"
    echo -e "${YELLOW}密码:${PLAIN} $PASSWORD"
    echo -e "${YELLOW}UDP转发:${PLAIN} $ENABLE_UDP"
    echo -e "${YELLOW}自动启动:${PLAIN} $ENABLE_AUTOSTART"
    echo
    echo -e "${BLUE}管理命令:${PLAIN}"
    echo -e "  启动: ${GREEN}systemctl start socks5-server${PLAIN}"
    echo -e "  停止: ${GREEN}systemctl stop socks5-server${PLAIN}"
    echo -e "  重启: ${GREEN}systemctl restart socks5-server${PLAIN}"
    echo -e "  状态: ${GREEN}systemctl status socks5-server${PLAIN}"
    echo
}

# 检查服务状态
check_status() {
    if systemctl is-active --quiet socks5-server; then
        echo -e "${GREEN}服务运行状态: 正在运行${PLAIN}"
    else
        echo -e "${RED}服务运行状态: 未运行${PLAIN}"
        echo -e "${YELLOW}请检查日志获取详细信息: journalctl -u socks5-server${PLAIN}"
    fi
}

# 主函数
main() {
    echo -e "${BLUE}========== Socks5服务端安装脚本 ==========${PLAIN}"
    echo -e "${BLUE}项目地址: https://github.com/Tiancaizhi9098/socks-server${PLAIN}"
    echo
    
    check_os
    install_deps
    install_microsocks
    configure_socks5
    create_service
    show_config
    check_status
    
    echo
    echo -e "${GREEN}安装完成!${PLAIN}"
}

main
