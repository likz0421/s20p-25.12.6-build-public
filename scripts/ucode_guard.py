#!/usr/bin/env python3
"""Build-time guard for ucode sources.

ucode's global function table has only 71 builtins; JS-style names such as
String(), Number(), parseInt(), JSON.parse, Date.now and Math.* do not exist.
Calling them throws "left-hand side is not a function" and takes the whole
LuCI page (or an rpcd method) down.

Scans .ut templates, .uc controllers and extensionless rpcd ucode scripts.
Also patches the bare getspnam() call in Argon's header template.

Usage: python3 ucode_guard.py <dir-or-file> [...]
"""
import os
import re
import sys

BANNED = [
    (r"(?<![\w$.])String\s*\(", "String() — ucode has no such global, use a template literal"),
    (r"(?<![\w$.])Number\s*\(", "Number() — ucode has no such global, use int()"),
    (r"(?<![\w$.])Boolean\s*\(", "Boolean() — ucode has no such global, use !!x"),
    (r"(?<![\w$.])Array\.isArray", "Array.isArray — use type(x) == 'array'"),
    (r"(?<![\w$.])JSON\.(parse|stringify)", "JSON.* — ucode uses json()"),
    (r"(?<![\w$.])unixtime\s*\(", "unixtime() — use time()"),
    (r"(?<![\w$.])parseInt\s*\(", "parseInt() — use int()"),
    (r"(?<![\w$.])parseFloat\s*\(", "parseFloat() — use `s * 1`"),
    (r"(?<![\w$.])Object\.(keys|values|entries|assign)", "Object.* — use keys()/values()"),
    (r"(?<![\w$.])Date\.now", "Date.now — use time()"),
    (r"(?<![\w$.])Math\.(max|min|round|floor|abs|pow)", "Math.* — use max()/min() or arithmetic"),
]

CODE_SPAN = re.compile(r"\{%(-?)(.*?)(-?)%\}|\{\{(.*?)\}\}", re.S)

GSP_OLD = "{% if (getuid() == 0 && getspnam('root')?.pwdp === ''): %}"
GSP_NEW = ("{% if (type(getuid) == 'function' && getuid() == 0 "
           "&& type(getspnam) == 'function' && (getspnam('root')?.pwdp ?? '') === ''): %}")


def strip_comments(s):
    out = []
    i, n = 0, len(s)
    while i < n:
        c = s[i]
        if c == "/" and i + 1 < n and s[i + 1] == "*":
            j = s.find("*/", i + 2)
            i = (j + 2) if j >= 0 else n
            continue
        if c == "/" and i + 1 < n and s[i + 1] == "/":
            j = s.find("\n", i)
            i = (j if j >= 0 else n)
            continue
        if c in "\"'`":
            q = c
            i += 1
            while i < n:
                if s[i] == "\\":
                    i += 2
                    continue
                if s[i] == q:
                    i += 1
                    break
                i += 1
            out.append('""')
            continue
        if c == "/":
            k = len(out) - 1
            while k >= 0 and out[k].strip() == "":
                k -= 1
            prev = out[k][-1] if k >= 0 else ""
            if prev in "(,=:[!&|?{;" or prev == "":
                i += 1
                incls = False
                while i < n:
                    if s[i] == "\\":
                        i += 2
                        continue
                    if s[i] == "[":
                        incls = True
                    elif s[i] == "]":
                        incls = False
                    elif s[i] == "/" and not incls:
                        i += 1
                        while i < n and s[i].isalpha():
                            i += 1
                        break
                    i += 1
                out.append("RE")
                continue
        out.append(c)
        i += 1
    return "".join(out)


def ucode_of(path, src):
    if path.endswith(".ut"):
        return "\n".join((m.group(2) or "") + "\n" + (m.group(4) or "")
                         for m in CODE_SPAN.finditer(src))
    return src


def iter_ucode(roots):
    for root in roots:
        if os.path.isdir(root):
            walker = os.walk(root)
        elif os.path.isfile(root):
            yield root, "file"
            continue
        else:
            continue
        for dirpath, _, files in walker:
            norm = dirpath.replace(os.sep, "/")
            is_rpcd = norm.endswith("usr/share/rpcd/ucode")
            for fn in files:
                p = os.path.join(dirpath, fn)
                if is_rpcd and "." not in fn:
                    yield p, "rpcd"
                elif fn.endswith(".ut"):
                    yield p, ".ut"
                elif fn.endswith(".uc"):
                    yield p, ".uc"


def main(roots):
    stats = {".ut": 0, ".uc": 0, "rpcd": 0, "file": 0}
    fails = []
    patched = []
    for p, kind in iter_ucode(roots):
        try:
            src = open(p, encoding="utf-8").read()
        except Exception:
            continue
        stats[kind] += 1
        code = strip_comments(ucode_of(p, src))
        for pat, why in BANNED:
            m = re.search(pat, code)
            if m:
                line = code.count("\n", 0, m.start()) + 1
                fails.append(f"{p}:{line}  {why}")
        if p.endswith(".ut") and GSP_OLD in src:
            open(p, "w", encoding="utf-8").write(src.replace(GSP_OLD, GSP_NEW))
            patched.append(p)

    print(f"[ucode-guard] {stats['.ut']} .ut + {stats['.uc']} .uc + {stats['rpcd']} rpcd")
    for p in patched:
        print(f"  patched getspnam guard: {p}")
    if fails:
        print("::error::ucode sources call functions that do not exist:")
        for f in fails:
            print("   ", f)
        return 1
    print("  OK: no unregistered ucode function calls")
    return 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(sys.argv[1:]))
