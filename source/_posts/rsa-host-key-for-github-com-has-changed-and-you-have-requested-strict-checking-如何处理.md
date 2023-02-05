---
title: >-
  rsa host key for github.com has changed and you have requested strict
  checking.--如何处理
date: 2023-02-05 16:03:29
updated: 2023-02-05 16:03:29
tags:
    - bug
    - ssh
    - github
categories:
    - [bug]
comments:
---
# github拉取代码时遇到的一些问题
git pull时报错：rsa host key for github.com has changed and you have requested strict checking.
<!-- more -->
***
## Method 1: Remove keys
```
ssh-keygen -R <server_name>
(or)
ssh-keygen -R <ip_address>

-R含义：从 known_hosts 文件中删除所有属于 hostname 的密钥
这个选项主要用于删除经过散列的主机(参见 -H 选项)的密钥。
```
## Method 2: Delete key from /home/user/.ssh/known_hosts
```
vim /home/user/.ssh/known_hosts +linenumber
dd
wq
```

# 参考文档
[RSA Host Key has been changed.](https://gist.github.com/fizerkhan/41f9c525db5b3b16bfcb)