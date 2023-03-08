---
title: Java本地化适配过程中字符导致报错
date: 2023-02-22 09:50:39
updated: 2023-02-22 09:50:39
tags:
    - Java
    - BUG
categories: Java
comments:
---
起因在公司测试环境中部署项目服务时，启动服务报错：can't find bundle for base name message, locale en_US
<!-- more -->

## 处理办法

检查配置和路径后，确定实际问题出在 `Malformed \uxxxx encoding` 这句错误上。

```text

将本地化文件中的 '\' 替换成 '/'，即可。
```

## 相关命令

```text
查看当前locale设置

locale

查看当前系统所有可用locale

locale -a

查看当前系统

localectl status
```

创建/etc/locale.conf文件

```shell
LANG=zh_CN.UTF-8
LC_COLLATE=C
LC_TIME=en_DK.UTF-8
```

source使其生效

## 关联问题

[Can't find bundle for base name /Bundle, locale en_US](https://stackoverflow.com/questions/12986234/cant-find-bundle-for-base-name-bundle-locale-en-us)

## 参考文档

[Malformed \uxxxx encoding in propertyfile task](https://stackoverflow.com/questions/17043037/ant-malformed-uxxxx-encoding-in-propertyfile-task)

[Malformed \uxxxx encoding error !!](https://coderanch.com/t/107014/build-tools/Malformed-uxxxx-encoding-error)

[linux下设置locale](https://cloud.tencent.com/developer/article/1671446)

[linux中的本地化](https://blog.csdn.net/shenyuflying/article/details/53244899)

[Linux 命令之 localectl -- 控制系统的本地化与键盘布局](https://blog.csdn.net/liaowenxiong/article/details/116399481)
