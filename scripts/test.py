#!/usr/bin/env python3
"""Run Lua 5.1 tests; install lupa or add its directory to PYTHONPATH."""
import os
from pathlib import Path
from lupa.lua51 import LuaRuntime
root = Path(__file__).resolve().parents[1]
os.chdir(root)
for locale in ("enUS", "zhCN", "deDE"):
    print(f"Testing locale: {locale}", flush=True)
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().TEST_LOCALE = locale
    lua.execute((root / "tests/test.lua").read_text())
