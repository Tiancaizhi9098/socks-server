Socks5 代理服务器
一个轻量、稳定的 Socks5 代理服务器部署脚本，基于 Dante 开发，支持一键安装和配置，适用于 Linux 系统。脚本允许你设置带用户名/密码认证的 Socks5 代理，并自定义端口和监听地址。
功能

一键部署：自动安装和配置 Socks5 代理服务器。
跨平台支持：兼容 Debian、Ubuntu 和 CentOS。
自定义配置：可设置监听地址、端口、用户名和密码。
开机自启：确保系统重启后代理服务自动运行。
轻量稳定：使用 Dante，性能优异，运行可靠。

支持的系统

Debian 10、11、12
Ubuntu 18.04、20.04、22.04
CentOS 7、8

前置条件

一台干净的 Linux 服务器，需具备 root 或 sudo 权限。
服务器需能访问互联网以安装软件包。
确保目标端口（默认 1080）未被其他服务占用。

安装
一键安装
运行以下命令，直接从本仓库下载并执行安装脚本：
wget -O install.sh https://raw.githubusercontent.com/Tiancaizhi9098/socks-server/main/install.sh && chmod +x install.sh && bash install.sh

此命令会：

从仓库下载 install.sh 脚本。
赋予脚本执行权限。
运行脚本以设置 Socks5 代理。

手动安装

克隆仓库：git clone https://github.com/Tiancaizhi9098/socks-server.git
cd socks5


赋予脚本执行权限：chmod +x install.sh


以 root 权限运行脚本：sudo ./install.sh



使用方法

安装过程中，脚本会提示你配置：
监听地址：默认 0.0.0.0（监听所有接口）。若仅限本地访问，可设为 127.0.0.1。
端口：默认 1080。可选择未占用的端口。
用户名：默认 socksuser。
密码：默认 socks123。


按回车使用默认值，或输入自定义值。
安装完成后，脚本会显示配置详情并启动代理服务。

测试代理
在另一台机器或本地使用 curl 测试代理是否正常：
curl --socks5 <服务器IP>:<端口> --proxy-user <用户名>:<密码> https://ipinfo.io

示例：
curl --socks5 203.0.113.1:1080 --proxy-user socksuser:socks123 https://ipinfo.io

输出应显示服务器的公网 IP 地址。
防火墙配置
如果服务器启用了防火墙，需开放指定端口（默认 1080）。示例：

Debian/Ubuntu (ufw)：sudo ufw allow 1080/tcp


CentOS (firewalld)：sudo firewall-cmd --permanent --add-port=1080/tcp
sudo firewall-cmd --reload



故障排查

检查 Dante 服务状态：systemctl status danted


查看日志以排查错误：journalctl -u danted


确认端口是否开放：netstat -tuln | grep <端口>



贡献
欢迎贡献代码！请按照以下步骤：

Fork 本仓库。
创建新分支以开发功能或修复问题。
提交 Pull Request 并清晰描述更改内容。

许可证
本项目采用 MIT 许可证，详情见 LICENSE 文件。
致谢

Dante 提供了强大的 Socks5 服务器。
感谢社区驱动的代理部署脚本的启发。

