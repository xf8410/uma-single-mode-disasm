#!/usr/bin/env python3
"""
把 hlpatch /il2cpp/disassemble 返回的 hex 还原成可读 ARM64 汇编。

用法:
    python3 tools/disasm.py raw/*.json raw/*.txt --base 0x7547a565e0

输入支持两种形态:
  1) JSON: {"method_addr": "0x...", "hex_dump": "0000: fe 0f 1d f8 ..."}
  2) 纯文本: 每行 "0000: fe 0f 1d f8 ..." 或直接 16 进制字节

输出:
  out/<name>.asm     逐条指令
  out/<name>.consts  所有立即数（movz/mov/cmp ... #imm），用于常量扫描
"""
import json
import re
import sys
from pathlib import Path

from capstone import Cs, CS_ARCH_ARM64, CS_MODE_ARM

OUT = Path("out")
HEXPAIR = re.compile(r"\b[0-9a-fA-F]{2}\b")


def parse_hex(text: str) -> bytes:
    """从任意格式的 hex 文本里抠出字节序列。"""
    data = bytearray()
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        # 去掉 "0000:" 这类偏移前缀
        line = re.sub(r"^[0-9a-fA-F]{4,8}\s*:\s*", "", line)
        for tok in HEXPAIR.findall(line):
            data.append(int(tok, 16))
    return bytes(data)


def load(path: Path):
    raw = path.read_text(errors="replace")
    base = 0
    if path.suffix == ".json":
        try:
            obj = json.loads(raw)
        except json.JSONDecodeError:
            obj = {}
        base = int(str(obj.get("method_addr", "0")).replace("0x", "") or 0, 16)
        body = obj.get("hex_dump", raw)
    else:
        body = raw
        m = re.search(r"@?(0x[0-9a-fA-F]{6,})", path.name)
        if m:
            base = int(m.group(1), 16)
    return base, parse_hex(body)


def main() -> int:
    args = [a for a in sys.argv[1:]]
    base_override = None
    if "--base" in args:
        i = args.index("--base")
        base_override = int(args[i + 1].replace("0x", ""), 16)
        del args[i:i + 2]

    if not args:
        print(__doc__)
        return 1

    md = Cs(CS_ARCH_ARM64, CS_MODE_ARM)
    md.detail = False
    OUT.mkdir(exist_ok=True)

    for pattern in args:
        for path in sorted(Path(".").glob(pattern)):
            base, code = load(path)
            if base_override is not None:
                base = base_override
            if not code:
                print(f"[skip] {path}: no bytes")
                continue

            asm_lines, consts = [], []
            for ins in md.disasm(code, base):
                asm_lines.append(f"{ins.address:#012x}  {ins.bytes.hex(' '):<24} {ins.mnemonic:<8} {ins.op_str}")
                if "#" in ins.op_str and ins.mnemonic in ("mov", "movz", "movn", "cmp", "add", "sub", "and"):
                    consts.append(f"{ins.address:#012x}  {ins.mnemonic} {ins.op_str}")

            stem = path.stem
            (OUT / f"{stem}.asm").write_text("\n".join(asm_lines) + "\n")
            (OUT / f"{stem}.consts").write_text("\n".join(consts) + "\n")
            print(f"{path}: {len(code)} bytes -> {len(asm_lines)} insns, {len(consts)} consts")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
