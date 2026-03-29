#!/usr/bin/env python3
"""
Strip Lua 5.5-specific syntax from PUC-Rio test files for luerl (5.3) compatibility.

Transformations:
  1. Remove `global <const> *` and `global <name>` declarations
  2. Remove `<const>` and `<close>` variable attributes
  3. Strip `if T == nil then ... else ... end` blocks: keep the nil branch, drop the else
  4. Strip `if T ~= nil then ... end` blocks entirely
  5. Inject preamble setting _port, _soft, _nomsg, T
  6. Remove _VERSION check that would abort early
  7. Replace `...t` named vararg syntax (5.5) with `...` (in case any slip through)
"""

import re
import sys


def preprocess(text):
    # Inject preamble
    preamble = """\
_port = true
_soft = true
_nomsg = true
T = nil
Message = print
"""

    # Strip `global <const> *` line
    text = re.sub(r'^global\s+<const>\s+\*.*$', '-- [stripped] global <const> *', text, flags=re.MULTILINE)

    # Strip `global <name>` lines (but not inside strings)
    text = re.sub(r'^global\s+\w[\w, ]*$', lambda m: '-- [stripped] ' + m.group(0), text, flags=re.MULTILINE)

    # Remove <const> and <close> attributes from variable declarations
    text = re.sub(r'\s*<const>', '', text)
    text = re.sub(r'\s*<close>', '', text)

    # Remove _VERSION check block
    text = re.sub(
        r'if _VERSION ~= version then.*?^end\s*$',
        '-- [stripped] _VERSION check',
        text,
        flags=re.MULTILINE | re.DOTALL
    )

    # Replace named vararg `...name` with just `...`
    # This is tricky — only in function parameter lists
    text = re.sub(r'\.\.\.\w+', '...', text)

    return preamble + '\n' + text


if __name__ == '__main__':
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <input.lua>", file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1], encoding='latin-1') as f:
        content = f.read()

    print(preprocess(content))
