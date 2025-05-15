#!/bin/bash

# Socks5服务端卸载脚本
# 作者: Tiancaizhi9098
# 项目地址: https://github.com/Tiancaizhi9098/socks-server

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
PLAIN="\033[0m"

echo -e "${YELLOW}正在卸载Socks5服务端...${PLAIN}"

# 停止并禁用服务
if systemctl is-active --quiet socks5-server; then
    echo -e "${YELLOW}停止socks5-server服务...${PLAIN}"
    systemctl stop socks5-server
fi

if systemctl is-enabled --quiet socks5-server; then
    echo -e "${YELLOW}禁用socks5-server自启动...${PLAIN}"
    systemctl disable socks5-server
fi

# 删除服务文件
if [ -f /etc/systemd/system/socks5-server.service ]; then
    echo -e "${YELLOW}删除服务文件...${PLAIN}"
    rm -f /etc/systemd/system/socks5-server.service
    systemctl daemon-reload
fi

# 删除可执行文件
if [ -f /usr/local/bin/microsocks ]; then
    echo -e "${YELLOW}删除MicroSocks可执行文件...${PLAIN}"
    rm -f /usr/local/bin/microsocks
fi

# 删除配置文件
if [ -d /etc/socks5-server ]; then
    echo -e "${YELLOW}删除配置文件...${PLAIN}"
    rm -rf /etc/socks5-server
fi

echo -e "${GREEN}卸载完成!${PLAIN}"
