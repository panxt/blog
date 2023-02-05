---
title: 拉取github代码，在已配置ssh密钥，仍需要输入密码--如何处理
date: 2023-02-05 16:21:52
updated: 2023-02-05 16:21:52
tags:
    - github
    - ssh
categories:
    - [ssh]
comments:
---
# 拉取github代码，在已配置ssh密钥，仍需要输入密码

<!-- more -->
## 环境

win11 + git + 代理
***

## 测试ssh连接
输入以下内容
```
$ ssh -T git@github.com
```
结果显示拒绝

[GITHUB官方参考文档](https://docs.github.com/zh/authentication/connecting-to-github-with-ssh/testing-your-ssh-connection)
***
## ssh故障排除
要测试通过 HTTPS 端口的 SSH 是否可行，请运行以下 SSH 命令：
```
$ ssh -T -p 443 git@ssh.github.com
> Hi USERNAME! You've successfully authenticated, but GitHub does not
> provide shell access.
```
[GITHUB官方参考文档](https://docs.github.com/zh/authentication/troubleshooting-ssh/using-ssh-over-the-https-port)
***
## 处理方案
修改或新建`~/.ssh/config`文件
```
Host github.com
Hostname ssh.github.com
Port 443
User git
```
成功解决
***
# 参考文档
[git clone输入密码提示 Permission denied, please try again.
](https://learnku.com/devtools/t/72153)