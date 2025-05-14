# 轻量级Socks5服务器

[![GitHub license](https://img.shields.io/github/license/Tiancaizhi9098/socks-server)](https://github.com/Tiancaizhi9098/socks-server/blob/main/LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/Tiancaizhi9098/socks-server)](https://github.com/Tiancaizhi9098/socks-server/stargazers)
[![GitHub issues](https://img.shields.io/github/issues/Tiancaizhi9098/socks-server)](https://github.com/Tiancaizhi9098/socks-server/issues)

一个轻量级、易于部署的Socks5服务器，一键安装，支持自定义配置和系统服务管理。

## 功能特点

- ✅ 快速安装，简单易用
- ✅ 支持用户认证（可选）
- ✅ 自定义监听地址和端口
- ✅ 自动配置为系统服务
- ✅ 开机自启动
- ✅ 支持多种Linux发行版（CentOS、Ubuntu、Debian等）

## 一键安装

复制以下命令到终端执行即可完成安装：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Tiancaizhi9098/socks-server/main/install-socks5.sh)
```

安装过程中，脚本将提示您输入以下配置信息：
- 服务器监听地址（默认：0.0.0.0）
- 服务器端口（默认：1080）
- 是否启用身份验证
- 用户名和密码（如启用身份验证）

## 使用方法

安装完成后，服务将自动启动。您可以使用以下命令管理服务：

```bash
# 启动服务
systemctl start socks5-server

# 停止服务
systemctl stop socks5-server

# 重启服务
systemctl restart socks5-server

# 查看服务状态
systemctl status socks5-server

# 查看服务日志
journalctl -u socks5-server
```

## 客户端配置

您可以在各种支持Socks5协议的客户端中使用此服务器：

### Windows/macOS/Linux

可使用以下客户端软件：
- Proxifier
- ShadowsocksX-NG
- Clash
- v2rayN

### 浏览器配置

以Chrome为例，可使用SwitchyOmega插件配置Socks5代理：

1. 安装SwitchyOmega插件
2. 新建情景模式，选择"代理服务器"
3. 代理协议选择"SOCKS5"
4. 输入服务器地址和端口
5. 如有需要，勾选"代理服务器需要认证"并输入用户名和密码

## 卸载

如需卸载，请执行以下命令：

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Tiancaizhi9098/socks-server/main/install-socks5.sh) uninstall
```

或者直接运行本地安装脚本并加上`uninstall`参数：

```bash
bash install-socks5.sh uninstall
```

## 系统要求

- CentOS 7+/Debian 9+/Ubuntu 16.04+
- Root权限
- 基本的网络连接

## 技术原理

本项目基于[MicroSocks](https://github.com/rofl0r/microsocks)实现，是一个轻量级的SOCKS5服务器，使用C语言编写，内存占用极低，非常适合在资源受限的环境中运行。

## 常见问题

**Q: 安装后无法连接服务器怎么办？**

A: 请检查以下几点：
1. 确认服务是否正常运行：`systemctl status socks5-server`
2. 检查防火墙是否开放了对应端口
3. 检查服务器安全组设置
4. 确认客户端配置是否正确

**Q: 如何修改配置？**

A: 您可以重新运行安装脚本覆盖原有配置，或者直接编辑配置文件：`/etc/socks5/config.json`，并重启服务。

## 开源许可

本项目采用MIT许可证开源。

## 贡献指南

欢迎提交Issue和Pull Request，共同改进此项目！

## 作者

[Tiancaizhi9098](https://github.com/Tiancaizhi9098)

---

如果您觉得这个项目有用，请给项目点个⭐️吧！
