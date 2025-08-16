#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import argparse, os, re, sys, unicodedata, hashlib

ALLOWED_REPL = re.compile(r"[\\/:*?\"<>|]")  # Windows 不允许字符（跨平台稳妥）
WS_RE = re.compile(r"\s+")


def norm_base(name: str) -> str:
    # 去扩展名，仅处理基名
    base, _ = os.path.splitext(name)
    # Unicode 归一
    base = unicodedata.normalize("NFKC", base)
    # 去首尾空白，内部空白压缩为单一空格
    base = WS_RE.sub(" ", base.strip())
    # 空格→下划线
    base = base.replace(" ", "_")
    # 中间点与其它危险字符替换
    base = base.replace(".", "_")
    base = ALLOWED_REPL.sub("_", base)
    # 防空
    return base or "audio"


def sha1_8(path: str) -> str:
    h = hashlib.sha1()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()[:8]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--file', required=True, help='本地文件路径')
    ap.add_argument('--orig-name', required=True, help='原始文件名（含扩展）')
    args = ap.parse_args()

    base = norm_base(args.orig_name)
    h8 = sha1_8(args.file)
    slug = f"{base}__{h8}"
    sys.stdout.write(slug)

if __name__ == '__main__':
    main()
