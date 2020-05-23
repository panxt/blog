---
title: Hexo使用和使用travis自动部署
date: 2020-05-23 20:20:54
tags: 
    - hexo
    - travis
categories:
    - [blog, hexo]
---

# 序言
本文没有太过于详细的Hexo及Travis的教程，主要记录一些笔者在用Hexo在GitHub上搭Blog，并使 用Travis自动部署博客过程中的一些记录点和踩的坑，主要还是偏个人为主，末尾会放出搭建博客过程中参考的一些Blog，写的都挺详细，就不用我再赘述了。

# 问题及解决办法
先写遇到的问题及解决方法吧！
## 运行hexo d报错
出现`TypeError [ERR_INVALID_ARG_TYPE]: The "mode" argument must be integer. Received an instance of Object`,很可能就是node_js版本问题，注意替换版本就可以了，一般使用lts,这里推荐`nvm`,是一个node_js的开发环境控制工具;
