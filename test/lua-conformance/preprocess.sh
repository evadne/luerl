#!/bin/bash
# Strip Lua 5.5 syntax from PUC-Rio test files for luerl (5.3) compatibility.
# Usage: ./preprocess.sh input.lua > output.lua

PREAMBLE='
_port = true
_soft = true
_nomsg = true
T = nil
Message = print
'

echo "$PREAMBLE"

sed \
  -e 's/global <const> \*/-- [stripped] global <const> */' \
  -e 's/<const>//g' \
  -e 's/^global .*$/-- [stripped] &/' \
  -e '/^if _VERSION ~= /,/^end$/d' \
  "$1"
