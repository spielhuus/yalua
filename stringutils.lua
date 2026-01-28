-- stringutils.lua
local M = {}

function M.ltrim(s, spaces_only)
  local pattern = spaces_only and "^[ ]+" or "^%s+"
  return (s:gsub(pattern, ""))
end

function M.rtrim(s, spaces_only)
  local pattern = spaces_only and "[ ]+$" or "%s+$"
  return (s:gsub(pattern, ""))
end

function M.trim(s, spaces_only)
  return M.rtrim(M.ltrim(s, spaces_only), spaces_only)
end

function M.escape(str)
  if type(str) == "number" then
    return str
  end
  return (str:gsub("\\", "\\\\"):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\b", "\\b"):gsub("\t", "\\t"))
end

function M.utf8_char(codepoint)
  if codepoint <= 0x7F then
    return string.char(codepoint)
  elseif codepoint <= 0x7FF then
    return string.char(0xC0 + (codepoint / 64), 0x80 + (codepoint % 64))
  elseif codepoint <= 0xFFFF then
    return string.char(0xE0 + (codepoint / 4096), 0x80 + ((codepoint / 64) % 64), 0x80 + (codepoint % 64))
  end
  return "?"
end

function M.url_decode(str)
  str = string.gsub(str, "%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end)
  return string.gsub(str, "+", " ")
end

return M
