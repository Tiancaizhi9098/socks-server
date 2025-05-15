#!/bin/bash

# ANSI颜色代码
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# 欢迎信息
echo -e "${BLUE}欢迎使用轻量级Socks5服务器安装脚本${NC}"
echo -e "${BLUE}作者: Tiancaizhi9098${NC}"
echo -e "${BLUE}Github: https://github.com/Tiancaizhi9098/socks-server${NC}"
echo ""

# 检查是否为root用户
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}错误: 请使用root权限运行此脚本${NC}" 
    exit 1
fi

# 检测系统类型
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
elif type lsb_release >/dev/null 2>&1; then
    OS=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
    VERSION=$(lsb_release -sr)
elif [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    OS=$DISTRIB_ID
    VERSION=$DISTRIB_RELEASE
else
    OS=$(uname -s)
    VERSION=$(uname -r)
fi

echo -e "${YELLOW}检测到系统: $OS $VERSION${NC}"

# 安装依赖
echo -e "${YELLOW}正在安装依赖...${NC}"
case $OS in
    debian|ubuntu)
        apt update
        apt install -y dante-server supervisor net-tools
        ;;
    centos|rhel|fedora)
        if [ "$OS" = "centos" ] && [ "${VERSION:0:1}" -lt "7" ]; then
            echo -e "${RED}不支持的CentOS版本: $VERSION${NC}"
            exit 1
        fi
        if command -v dnf >/dev/null 2>&1; then
            dnf install -y epel-release
            dnf install -y dante-server supervisor net-tools
        else
            yum install -y epel-release
            yum install -y dante-server supervisor net-tools
        fi
        ;;
    *)
        echo -e "${RED}不支持的操作系统: $OS${NC}"
        exit 1
        ;;
esac

# 配置参数
echo -e "${GREEN}请配置Socks5服务器:${NC}"
read -p "服务器监听地址 [0.0.0.0]: " SERVER_IP
SERVER_IP=${SERVER_IP:-0.0.0.0}

read -p "端口 [1080]: " SERVER_PORT
SERVER_PORT=${SERVER_PORT:-1080}

read -p "是否需要用户名密码认证? (y/n) [y]: " AUTH_NEEDED
AUTH_NEEDED=${AUTH_NEEDED:-y}

if [[ "${AUTH_NEEDED,,}" == "y" ]]; then
    read -p "用户名 [socks5user]: " USERNAME
    USERNAME=${USERNAME:-socks5user}
    
    read -p "密码 [socks5pass]: " PASSWORD
    PASSWORD=${PASSWORD:-socks5pass}
    
    # 创建用户密码文件
    if [ -f /etc/sockd.passwd ]; then
        rm -f /etc/sockd.passwd
    fi
    
    echo "$USERNAME $PASSWORD" > /etc/sockd.passwd
    chmod 600 /etc/sockd.passwd
fi

# 检查端口是否可用
if netstat -tuln | grep ":$SERVER_PORT " > /dev/null; then
    echo -e "${RED}警告: 端口 $SERVER_PORT 已被占用.${NC}"
    read -p "是否继续? (y/n) [n]: " CONTINUE
    CONTINUE=${CONTINUE:-n}
    if [[ "${CONTINUE,,}" != "y" ]]; then
        echo -e "${YELLOW}安装已取消.${NC}"
        exit 1
    fi
fi

# 配置Dante服务器
echo -e "${YELLOW}配置Socks5服务器...${NC}"
cat > /etc/sockd.conf << EOF
logoutput: stderr
internal: $SERVER_IP port = $SERVER_PORT
external: eth0
socksmethod: $(if [[ "${AUTH_NEEDED,,}" == "y" ]]; then echo "username"; else echo "none"; fi)
$(if [[ "${AUTH_NEEDED,,}" == "y" ]]; then echo "user.privileged: root"; echo "user.notprivileged: nobody"; fi)

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: error connect disconnect
}

$(if [[ "${AUTH_NEEDED,,}" == "y" ]]; then
echo "pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    protocol: tcp udp
    method: username
    log: error connect disconnect
}"
else
echo "pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    protocol: tcp udp
    log: error connect disconnect
}"
fi)
EOF

# 配置supervisor
echo -e "${YELLOW}配置自启动服务...${NC}"
cat > /etc/supervisor/conf.d/sockd.conf << EOF
[program:sockd]
command=/usr/sbin/sockd -f /etc/sockd.conf
autostart=true
autorestart=true
redirect_stderr=true
EOF

# 启动服务
echo -e "${YELLOW}启动Socks5服务...${NC}"
if [ "$OS" = "debian" ] || [ "$OS" = "ubuntu" ]; then
    systemctl enable supervisor
    systemctl restart supervisor
else
    systemctl enable supervisord
    systemctl restart supervisord
fi

# 等待服务启动
sleep 2

# 验证服务
if netstat -tuln | grep ":$SERVER_PORT " > /dev/null; then
    echo -e "${GREEN}Socks5服务部署成功!${NC}"
    echo -e "${GREEN}----------------------------------------${NC}"
    echo -e "${GREEN}服务信息:${NC}"
    echo -e "${GREEN}Server IP: $SERVER_IP${NC}"
    echo -e "${GREEN}Port: $SERVER_PORT${NC}"
    if [[ "${AUTH_NEEDED,,}" == "y" ]]; then
        echo -e "${GREEN}Username: $USERNAME${NC}"
        echo -e "${GREEN}Password: $PASSWORD${NC}"
    else
        echo -e "${GREEN}Authentication: None${NC}"
    fi
    echo -e "${GREEN}UDP Support: Enabled${NC}"
    echo -e "${GREEN}----------------------------------------${NC}"
else
    echo -e "${RED}Socks5服务启动失败，请检查日志.${NC}"
    exit 1
fi

# 防火墙提醒
echo -e "${YELLOW}防火墙提醒:${NC}"
echo -e "${YELLOW}请确保您的防火墙已开放端口 $SERVER_PORT (TCP/UDP)${NC}"
if command -v ufw >/dev/null 2>&1; then
    echo -e "${YELLOW}如需开放端口，可以运行以下命令:${NC}"
    echo -e "${BLUE}ufw allow $SERVER_PORT/tcp${NC}"
    echo -e "${BLUE}ufw allow $SERVER_PORT/udp${NC}"
elif command -v firewall-cmd >/dev/null 2>&1; then
    echo -e "${YELLOW}如需开放端口，可以运行以下命令:${NC}"
    echo -e "${BLUE}firewall-cmd --permanent --add-port=$SERVER_PORT/tcp${NC}"
    echo -e "${BLUE}firewall-cmd --permanent --add-port=$SERVER_PORT/udp${NC}"
    echo -e "${BLUE}firewall-cmd --reload${NC}"
fi

echo -e "${BLUE}----------------------------------------${NC}"
echo -e "${BLUE}安装完成!${NC}"
echo -e "${BLUE}如有问题请访问: https://github.com/Tiancaizhi9098/socks-server${NC}"
echo -e "${BLUE}----------------------------------------${NC}"
