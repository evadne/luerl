-- Preprocessor: strip Lua 5.5 syntax and set portable mode
-- Usage: run this preamble before any PUC-Rio test file

-- Remove strict mode (we can't actually strip syntax from Lua,
-- but we can set the environment variables the tests check)
_port = true
_soft = true
_nomsg = true
T = nil
Message = print
