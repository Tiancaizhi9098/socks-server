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
        yum install -y gcc make wget curl tar git unzip
    else
        apt-get update -y
        apt-get install -y gcc make wget curl tar git unzip
    fi
}

# 安装3proxy (支持UDP的Socks5服务器)
install_3proxy() {
    echo -e "${GREEN}安装3proxy...${PLAIN}"
    TMP_DIR=$(mktemp -d)
    cd $TMP_DIR
    
    # 下载3proxy
    wget https://github.com/z3APA3A/3proxy/archive/0.9.4.tar.gz
    tar -xzf 0.9.4.tar.gz
    cd 3proxy-0.9.4
    
    # 编译安装
    make -f Makefile.Linux
    mkdir -p $(dirname $SOCKS_BIN)
    cp bin/3proxy $SOCKS_BIN
    chmod +x $SOCKS_BIN
    
    # 创建配置目录
    mkdir -p $SOCKS_CONFIG_DIR
    
    # 创建服务用户
    id -u $DAEMON_USER > /dev/null 2>&1 || useradd -r -s /bin/false $DAEMON_USER
    
    # 清理临时文件
    cd $HOME
    rm -rf $TMP_DIR
}

# 配置Socks5服务
configure_socks() {
    echo -e "${GREEN}配置Socks5服务...${PLAIN}"
    
    # 检查是否存在配置文件，如果存在则读取配置
    if [ -f $SOCKS_CONFIG ]; then
        source_config
    else
        # 提示用户输入配置信息
        read -p "请输入服务监听地址 [$DEFAULT_BIND]: " bind_address
        bind_address=${bind_address:-$DEFAULT_BIND}
        
        read -p "请输入端口号 [$DEFAULT_PORT]: " port
        port=${port:-$DEFAULT_PORT}
        
        read -p "是否需要身份验证? (y/n): " auth_needed
        if [[ "${auth_needed,,}" == "y" ]]; then
            read -p "请输入用户名 [$DEFAULT_USER]: " username
            username=${username:-$DEFAULT_USER}
            
            read -p "请输入密码 [$DEFAULT_PASS]: " password
            password=${password:-$DEFAULT_PASS}
        else
            auth_needed="n"
            username=""
            password=""
        fi
        
        read -p "是否启用UDP支持? (y/n): " udp_enabled
        udp_enabled=${udp_enabled:-y}
    fi
    
    # 创建3proxy配置文件
    cat > $SOCKS_CONFIG_DIR/3proxy.cfg << EOF
#!/usr/bin/3proxy
daemon
pidfile /var/run/3proxy.pid
nscache 65536
timeouts 1 5 30 60 180 1800 15 60

# 日志设置
log /var/log/3proxy.log D
logformat "- +_L%t.%. %N.%p %E %U %C:%c %R:%r %O %I %h %T"
rotate 30

# 用户配置
EOF

    # 添加用户认证配置
    if [[ "${auth_needed,,}" == "y" ]]; then
        echo "users $username:CL:$password" >> $SOCKS_CONFIG_DIR/3proxy.cfg
    fi

    # 添加SOCKS服务配置
    cat >> $SOCKS_CONFIG_DIR/3proxy.cfg << EOF

# SOCKS服务配置
socks -p$port -i$bind_address 
EOF

    # 添加UDP支持(如果启用)
    if [[ "${udp_enabled,,}" == "y" ]]; then
        echo "udppm" >> $SOCKS_CONFIG_DIR/3proxy.cfg
    fi
    
    # 创建systemd服务文件
    cat > $SOCKS_SERVICE << EOF
[Unit]
Description=3Proxy Socks5 Server
After=network.target

[Service]
User=$DAEMON_USER
ExecStart=$SOCKS_BIN $SOCKS_CONFIG_DIR/3proxy.cfg
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
    "auth": "${auth_needed,,}",
    "username": "$username",
    "password": "$password",
    "udp": "${udp_enabled,,}",
    "version": "$VERSION"
}
EOF

    # 确保日志文件存在并设置权限
    touch /var/log/3proxy.log
    chown $DAEMON_USER:$DAEMON_USER /var/log/3proxy.log
    
    # 设置服务自启动
    systemctl daemon-reload
    systemctl enable socks5-server
    systemctl restart socks5-server
    
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
    
    if [[ "${auth_needed,,}" == "y" ]]; then
        echo -e "${GREEN}需要认证:${PLAIN} 是"
        echo -e "${GREEN}用户名:${PLAIN} $username"
        echo -e "${GREEN}密码:${PLAIN} $password"
    else
        echo -e "${GREEN}需要认证:${PLAIN} 否"
    fi
    
    if [[ "${udp_enabled,,}" == "y" ]]; then
        echo -e "${GREEN}UDP支持:${PLAIN} 已启用"
    else
        echo -e "${GREEN}UDP支持:${PLAIN} 未启用"
    fi
    
    echo -e "\n${YELLOW}使用方法:${PLAIN}"
    echo -e "- 启动服务: ${GREEN}systemctl start socks5-server${PLAIN}"
    echo -e "- 停止服务: ${GREEN}systemctl stop socks5-server${PLAIN}"
    echo -e "- 重启服务: ${GREEN}systemctl restart socks5-server${PLAIN}"
    echo -e "- 查看状态: ${GREEN}systemctl status socks5-server${PLAIN}"
    echo -e "- 查看日志: ${GREEN}journalctl -u socks5-server${PLAIN}"
    echo -e "- 实时日志: ${GREEN}tail -f /var/log/3proxy.log${PLAIN}"
    echo -e "\n${BLUE}--------------------------------${PLAIN}"
    
    echo -e "\n${GREEN}Socks5服务器安装完成!${PLAIN}"
    echo -e "${GREEN}版本:${PLAIN} $VERSION"
    echo -e "${GREEN}作者:${PLAIN} Tiancaizhi9098"
    echo -e "${GREEN}GitHub:${PLAIN} https://github.com/Tiancaizhi9098/socks-server"
}

# 卸载Socks5服务
uninstall_socks() {
    echo -e "${YELLOW}正在卸载Socks5服务...${PLAIN}"
    
    systemctl stop socks5-server 2>/dev/null || true
    systemctl disable socks5-server 2>/dev/null || true
    rm -f $SOCKS_SERVICE
    rm -f $SOCKS_BIN
    rm -rf $SOCKS_CONFIG_DIR
    rm -f /var/log/3proxy.log
    
    echo -e "${GREEN}Socks5服务已成功卸载!${PLAIN}"
    exit 0
}

# 升级Socks5服务
upgrade_socks() {
    echo -e "${YELLOW}正在升级Socks5服务...${PLAIN}"
    
    # 备份当前配置
    source_config
    
    # 卸载旧版本（保留配置文件）
    systemctl stop socks5-server 2>/dev/null || true
    systemctl disable socks5-server 2>/dev/null || true
    rm -f $SOCKS_SERVICE
    rm -f $SOCKS_BIN
    
    # 安装新版本
    install_dependencies
    install_3proxy
    configure_socks
    
    echo -e "${GREEN}Socks5服务已成功升级!${PLAIN}"
}

# 重启Socks5服务
restart_socks() {
    echo -e "${YELLOW}正在重启Socks5服务...${PLAIN}"
    
    systemctl restart socks5-server
    
    if systemctl is-active --quiet socks5-server; then
        echo -e "${GREEN}Socks5服务已成功重启!${PLAIN}"
    else
        echo -e "${RED}Socks5服务重启失败，请检查日志: journalctl -u socks5-server${PLAIN}"
        exit 1
    fi
}

# 查看服务状态
check_status() {
    echo -e "${YELLOW}查看Socks5服务状态...${PLAIN}"
    
    if systemctl is-active --quiet socks5-server; then
        echo -e "${GREEN}Socks5服务正在运行${PLAIN}"
        source_config
        show_info
    else
        echo -e "${RED}Socks5服务未运行${PLAIN}"
        exit 1
    fi
}

# 主函数
main() {
    clear
    echo -e "${BLUE}=====================================================${PLAIN}"
    echo -e "${BLUE}                  Socks5服务器安装脚本               ${PLAIN}"
    echo -e "${BLUE}                      版本: $VERSION                 ${PLAIN}"
    echo -e "${BLUE}=====================================================${PLAIN}"
    echo -e "${GREEN}作者:${PLAIN} Tiancaizhi9098"
    echo -e "${GREEN}GitHub:${PLAIN} https://github.com/Tiancaizhi9098/socks-server"
    echo -e "${BLUE}=====================================================${PLAIN}"
    
    check_root
    
    # 检查是否已安装
    if [ -f $SOCKS_BIN ] && [ -f $SOCKS_CONFIG ]; then
        installed=true
        source_config
    else
        installed=false
    fi
    
    # 参数处理
    case "$1" in
        uninstall)
            uninstall_socks
            ;;
        upgrade)
            upgrade_socks
            show_info
            ;;
        restart)
            restart_socks
            show_info
            ;;
        status)
            check_status
            ;;
        *)
            if [ "$installed" = true ]; then
                echo -e "${YELLOW}检测到已安装Socks5服务，请选择操作:${PLAIN}"
                echo -e "1. ${GREEN}卸载服务${PLAIN}"
                echo -e "2. ${GREEN}重新配置${PLAIN}"
                echo -e "3. ${GREEN}升级服务${PLAIN}"
                echo -e "4. ${GREEN}重启服务${PLAIN}"
                echo -e "5. ${GREEN}查看状态${PLAIN}"
                echo -e "0. ${GREEN}退出脚本${PLAIN}"
                
                read -p "请输入选项 [0-5]: " option
                case $option in
                    1)
                        uninstall_socks
                        ;;
                    2)
                        check_sys
                        configure_socks
                        show_info
                        ;;
                    3)
                        check_sys
                        upgrade_socks
                        show_info
                        ;;
                    4)
                        restart_socks
                        show_info
                        ;;
                    5)
                        check_status
                        ;;
                    0)
                        exit 0
                        ;;
                    *)
                        echo -e "${RED}无效选项!${PLAIN}"
                        exit 1
                        ;;
                esac
            else
                check_sys
                install_dependencies
                install_3proxy
                configure_socks
                show_info
            fi
            ;;
    esac
}

main "$@"
