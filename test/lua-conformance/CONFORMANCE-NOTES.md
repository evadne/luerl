# Lua 5.5.0 Conformance Test Suite — Luerl Adaptation Notes

## Source
- `lua-5.5.0-tests.tar.gz` from https://www.lua.org/tests/
- 35 test files, ~18k lines total

## Preprocessing Required

Lua 5.5 syntax not supported by luerl (targets 5.3):
- `global <const> *` — strict mode declaration (strip line)
- `<const>` attribute on variables — strip attribute, keep declaration
- `<close>` attribute on variables — strip attribute
- `...name` named vararg syntax — replace with `...`
- `global <name>` declarations — strip line

Runtime setup:
- `_port = true` — skip platform-specific tests
- `_soft = true` — skip resource-heavy tests
- `T = nil` — skip C API internal tests (T is the testC lib)

## Issues Found (strings.lua)

### 1. Error message mismatches
`checkerror` expects PUC-Rio error messages (e.g., "out of range").
Luerl produces different error strings (e.g., "bad argument 256 to 'char'").
**Impact:** checkerror tests fail on message matching, not functionality.
**Fix:** Override checkerror to only verify that an error occurs, not the message text.

### 2. string.rep with huge sizes hangs
`string.rep("aa", math.maxinteger // 2 + 10)` hangs instead of erroring.
Luerl's string.rep doesn't check for oversized allocations before attempting to build.
**Impact:** Test hangs instead of erroring.
**Fix needed:** Add size check to luerl_lib_string:rep before allocation.

### 3. `if T == nil then ... else ... end` blocks
The `else` branch contains T-specific code with 5.5 syntax (e.g., named varargs).
Even though `T = nil`, Lua compiles the full file — parser chokes on 5.5 syntax.
**Fix:** Preprocessor must strip `else` branches of T-guarded blocks.

## Test Files — Feasibility for Luerl

### Likely runnable (pure Lua semantics, no OS/C deps):
- `strings.lua` — string library (in progress)
- `math.lua` — math library
- `pm.lua` — pattern matching
- `sort.lua` — table.sort
- `bitwise.lua` — bit operations
- `constructs.lua` — language constructs
- `literals.lua` — literal parsing
- `closure.lua` — closures
- `calls.lua` — function calls
- `vararg.lua` — varargs
- `nextvar.lua` — tables/iterators
- `tpack.lua` — string.pack/unpack
- `utf8.lua` — utf8 library
- `events.lua` — metatables
- `goto.lua` — goto statement
- `locals.lua` — local variables

### Skip (OS/C/debug/GC dependency):
- `api.lua`, `main.lua`, `files.lua`, `db.lua`
- `gc.lua`, `gengc.lua`, `tracegc.lua`, `memerr.lua`
- `heavy.lua`, `big.lua`, `verybig.lua`, `cstack.lua`
- `attrib.lua`, `code.lua`
- `errors.lua` (error messages are implementation-specific)
- `coroutine.lua` (partially runnable, some 5.5 features)
- `bwcoercion.lua` (5.5 backward compat coercion)
