# 轻量级Socks5服务器

这是一个轻量级、简单易用的Socks5服务器安装脚本，支持多种Linux发行版，包括Debian、Ubuntu、CentOS、RHEL和Fedora。

## 功能特点

- 一键安装部署
- 支持TCP和UDP
- 可选的用户名/密码认证
- 自定义监听地址和端口
- 系统启动时自动运行
- 自动配置防火墙规则
- 适用于多种Linux发行版

## 一键安装

使用以下命令一键安装：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Tiancaizhi9098/socks-server/main/install-socks5.sh)
```

## 安装过程

安装过程中，脚本会要求您输入以下信息：

1. 服务器监听地址（默认为0.0.0.0，监听所有网络接口）
2. 端口号（默认为1080）
3. 是否需要用户名/密码认证（默认为是）
4. 如果选择认证，需要设置用户名（默认为socks5user）和密码（默认为socks5pass）

## 手动安装

如果您不想使用一键安装命令，也可以手动下载并运行脚本：

```bash
# 下载脚本
wget https://raw.githubusercontent.com/Tiancaizhi9098/socks-server/main/install-socks5.sh

# 添加执行权限
chmod +x install-socks5.sh

# 运行脚本
sudo ./install-socks5.sh
```

## 系统要求

- 支持的操作系统：
  - Debian 8+
  - Ubuntu 16.04+
  - CentOS 7+
  - RHEL 7+
  - Fedora 30+
- 需要root权限运行脚本

## 使用方法

安装完成后，Socks5服务将自动启动。您可以使用任何支持Socks5协议的客户端连接到您的服务器。

### 连接信息

- 服务器地址：您的服务器IP地址
- 端口：您设置的端口（默认1080）
- 认证类型：无认证或用户名/密码认证（取决于您的设置）
- 如果使用认证，用户名和密码为您设置的值

### 防火墙设置

安装脚本不会自动配置防火墙，但会提醒您需要手动开放相应端口。根据您的防火墙类型，可以使用以下命令：

#### UFW (Ubuntu/Debian)

```bash
sudo ufw allow 端口号/tcp
sudo ufw allow 端口号/udp
```

#### Firewalld (CentOS/RHEL/Fedora)

```bash
sudo firewall-cmd --permanent --add-port=端口号/tcp
sudo firewall-cmd --permanent --add-port=端口号/udp
sudo firewall-cmd --reload
```

请将"端口号"替换为您实际设置的Socks5服务端口。

## 管理服务

### 查看服务状态

```bash
supervisorctl status sockd
```

### 重启服务

```bash
supervisorctl restart sockd
```

### 停止服务

```bash
supervisorctl stop sockd
```

### 启动服务

```bash
supervisorctl start sockd
```

## 卸载

如果您想卸载Socks5服务，可以运行以下命令：

```bash
# 停止并移除服务
supervisorctl stop sockd
rm -f /etc/supervisor/conf.d/sockd.conf
supervisorctl update

# 移除配置文件
rm -f /etc/sockd.conf
rm -f /etc/sockd.passwd

# 根据您的发行版卸载软件包
# Debian/Ubuntu:
apt purge -y dante-server supervisor

# CentOS/RHEL/Fedora:
yum remove -y dante-server supervisor
# 或
dnf remove -y dante-server supervisor
```

## 问题排查

如果您在安装或使用过程中遇到问题，请检查以下几点：

1. 确保您的系统防火墙已经开放了配置的端口
2. 检查服务是否正在运行：`supervisorctl status sockd`
3. 查看日志：`tail -f /var/log/supervisor/sockd.log`

## 参与贡献

欢迎提交问题报告和功能建议。如果您想贡献代码，请提交Pull Request。

## 许可证

MIT License

## 作者

[Tiancaizhi9098](https://github.com/Tiancaizhi9098)
