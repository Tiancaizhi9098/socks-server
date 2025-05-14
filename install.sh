#!/bin/bash

# 检查是否以 root 权限运行
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要以 root 权限运行，请使用 sudo 或切换到 root 用户"
    exit 1
fi

# 默认配置
LISTEN_ADDRESS="0.0.0.0"
PORT="1080"
USERNAME="socksuser"
PASSWORD="socks123"

# 提示用户输入配置
read -p "请输入监听地址（默认: ${LISTEN_ADDRESS}）： " input_address
LISTEN_ADDRESS=${input_address:-$LISTEN_ADDRESS}

read -p "请输入端口（默认: ${PORT}）： " input_port
PORT=${input_port:-$PORT}

read -p "请输入用户名（默认: ${USERNAME}）： " input_username
USERNAME=${input_username:-$USERNAME}

read -s -p "请输入密码（默认: ${PASSWORD}）： " input_password
echo
PASSWORD=${input_password:-$PASSWORD}

# 检测操作系统
OS=""
if [ -f /etc/debian_version ]; then
    OS="debian"
elif [ -f /etc/redhat-release ]; then
    OS="centos"
else
    echo "不支持的操作系统，仅支持 Debian、Ubuntu 或 CentOS"
    exit 1
fi

# 安装 Dante
if [ "$OS" = "debian" ]; then
    echo "检测到 Debian/Ubuntu 系统，正在安装 Dante..."
    apt update && apt upgrade -y
    apt install -y dante-server
elif [ "$OS" = "centos" ]; then
    echo "检测到 CentOS 系统，正在安装 Dante..."
    yum install -y epel-release
    yum install -y dante-server
fi

# 创建 Dante 配置文件
echo "正在配置 Dante..."
cat > /etc/danted.conf << EOF
logoutput: syslog
internal: ${LISTEN_ADDRESS} port = ${PORT}
external: ${LISTEN_ADDRESS}
socksmethod: username
clientmethod: none
user.privileged: root
user.unprivileged: nobody

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}

socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    command: bind connect udpassociate
    log: connect disconnect error
    socksmethod: username
}
EOF

# 创建用户并设置密码
echo "正在设置代理用户..."
useradd -r -s /bin/false ${USERNAME}
echo "${USERNAME}:${PASSWORD}" | chpasswd

# 启动并启用 Dante 服务
echo "正在启动 Dante 服务并启用开机自启..."
systemctl enable danted
systemctl restart danted

# 检查服务状态
if systemctl is-active --quiet danted; then
    echo "Socks5 代理已成功启动！"
    echo "配置详情："
    echo "监听地址: ${LISTEN_ADDRESS}"
    echo "端口: ${PORT}"
    echo "用户名: ${USERNAME}"
    echo "密码: ${PASSWORD}"
    echo "开机自启: 已启用（系统重启后自动运行）"
    echo "你可以使用以下命令检查服务状态：systemctl status danted"
else
    echo "启动 Dante 服务失败，请检查日志：journalctl -u danted"
    exit 1
fi

# 提示防火墙配置
echo "如果你的服务器启用了防火墙，请确保开放 ${PORT} 端口："
if [ "$OS" = "debian" ]; then
    echo "例如使用 ufw：sudo ufw allow ${PORT}/tcp"
elif [ "$OS" = "centos" ]; then
    echo "例如使用 firewalld："
    echo "sudo firewall-cmd --permanent --add-port=${PORT}/tcp"
    echo "sudo firewall-cmd --reload"
fi
