#!/bin/bash

hexo cl

git add --all

git commit -m"$1"

git push

