local TokenStream = require("tokenstream")
local StringUtils = require("stringutils")

local function log(...)
  print(...)
end

local function to_string(obj, indent, visited)
  indent = indent or ""
  visited = visited or {}

  if type(obj) == "table" then
    if visited[obj] then
      return "<recursive table>"
    end
    visited[obj] = true

    local output = "{\n"
    for k, v in pairs(obj) do
      output = output
        .. indent
        .. "  "
        .. to_string(k, indent .. "  ", visited)
        .. " = "
        .. to_string(v, indent .. "  ", visited)
        .. ",\n"
    end
    return output .. indent .. "}"
  elseif type(obj) == "string" then
    return '"' .. obj .. '"'
  else
    return tostring(obj)
  end
end

local GLOBAL_TAG = "tag:yaml.org,2002:"

-----------------------------------------------------------------------------------------
---                               String Utilities                                    ---
-----------------------------------------------------------------------------------------

local function ltrim(s, spaces_only)
  while #s > 0 do
    local char = string.sub(s, 1, 1)
    if char == " " then
      s = string.sub(s, 2, #s)
    elseif not spaces_only and char == "\t" then
      s = string.sub(s, 2, #s)
    else
      break
    end
  end
  return s
end

local function rtrim(s, spaces_only)
  while #s > 0 do
    local char = string.sub(s, #s, #s)
    if char == " " then
      s = string.sub(s, 1, #s - 1)
    elseif not spaces_only and char == "\t" then
      if string.sub(s, #s - 1, #s - 1) == "\\" then
        break
      end
      s = string.sub(s, 1, #s - 1)
    else
      break
    end
  end
  return s
end

local function trim(s, spaces_only)
  return rtrim(ltrim(s, spaces_only), spaces_only)
end

---escape the backslashes
local function escape(str)
  if type(str) == "number" then
    return str
  end
  return (str:gsub("\\", "\\\\"):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\b", "\\b"):gsub("\t", "\\t"))
end

local function match(str, char)
  if char == nil then
    return false
  end
  for i = 1, #str do
    if string.sub(str, i, i) == char then
      return true
    end
  end
  return false
end

local function utf8(codepoint)
  if codepoint <= 0x7F then
    return string.char(codepoint)
  elseif codepoint <= 0x7FF then
    return string.char(0xC0 + (codepoint / 64), 0x80 + (codepoint % 64))
  elseif codepoint <= 0xFFFF then
    return string.char(0xE0 + (codepoint / 4096), 0x80 + ((codepoint / 64) % 64), 0x80 + (codepoint % 64))
  end
end

---decode the url encoded string
local function url_decode(str)
  str = string.gsub(str, "%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end)
  str = string.gsub(str, "+", " ")
  return str
end

---@class Token
---@field kind string
---@field indent integer
---@field val string
---@field row integer
---@field col integer

-----------------------------------------------------------------------------------------
---                                      Lexer                                        ---
-----------------------------------------------------------------------------------------

local Lexer = {}

---@class Lexer
---@field index integer
---@field str string
---@field col integer
---@field row integer
---@field tokens Token
function Lexer:new(str)
  local o = {}
  self.__index = self
  setmetatable(o, self)
  o.str = str
  o.index = 0
  o.row = 1
  o.col = 0
  o.tokens = {}
  o.t_index = 0
  o.flow_level = 0
  o.indent = 0
  o.state = "START"
  o.last_seq = nil
  return o
end

function Lexer:create_token(kind, val, row, col, type)
  return { kind = kind, val = val, row = row, col = col, type = type }
end

---@param index integer
---@return string
function Lexer:char(index)
  return string.sub(self.str, index, index)
end

---@param char string
---@param index integer
---@return boolean
function Lexer:expect(char, index)
  return self:char(index) == char
end

--- Checks if the next characters in the iterator match the given string.
---@param str string The string to compare against the current position in the iterator.
---@param pos integer? position from where the string should match
---@return boolean Returns true if the next characters match the given string, otherwise false.
function Lexer:match(str, pos)
  local s = string.sub(self.str, self.index + (pos or 1), self.index + #str + (pos and (pos - 1) or 0))
  return s == str
end

function Lexer:to_sep()
  local chars = {}
  local char = self:peek_char()
  while char ~= " " and char ~= "\t" and char ~= "\n" do
    table.insert(chars, self:next_char())
    char = self:peek_char()
  end
  return table.concat(chars, "")
end

function Lexer:to_eol()
  local chars = {}
  while self:peek_char() and self:peek_char() ~= "\n" do
    table.insert(chars, self:next_char())
  end
  return table.concat(chars, "")
end

function Lexer:word_char()
  local res = {}
  local char = self:peek_char()
  while char and string.match(char, "^[%a%d-!]$") do
    table.insert(res, self:next_char())
    char = self:peek_char()
  end
  return table.concat(res, "")
end

function Lexer:anchor_char()
  local res = {}
  local char = self:peek_char()
  while char and char ~= " " and char ~= "\n" do
    if self.flow_level > 0 and (char == "," or char == "]" or char == "") then
      break
    end
    table.insert(res, self:next_char())
    char = self:peek_char()
  end
  return table.concat(res, "")
end

---Peek the next character(s) in the iterator.
---@param n integer? The number of characters to peek, default is 1.
---@return string|nil The character(s) or nil if end of file (eof) is reached.
function Lexer:peek_char(n)
  n = n or 1
  if self.index + n > #self.str then
    return nil
  end
  return string.sub(self.str, self.index + n, self.index + n)
end

---Peek the next indicator character(s) in the iterator.
---@param n integer? The number of characters to peek, default is 1.
---@return string|nil The character(s) or nil if end of file (eof) is reached.
function Lexer:peek_indicator(n)
  n = n or 1
  while self:peek_char(n) == " " and self:peek_char(n) == "\n" and self:peek_char(n) == "\t" do
    n = n + 1
  end
  return string.sub(self.str, self.index + n, self.index + n)
end

function Lexer:is_sep(index)
  return self:peek_char(index or 1) == " " or self:peek_char(index or 1) == "\n" or self:peek_char(index or 1) == "\t"
end

--- Advances the iterator by `n` characters and returns the next `n` characters.
---@param self Lexer The iterator instance.
---@param n? integer The number of characters to advance. Defaults to 1 if not provided.
---@return string|nil The next `n` characters as a string, or nil if the end of the string is reached.
function Lexer:next_char(n)
  local chars = {}
  for _ = 1, (n or 1) do
    self.index = self.index + 1
    if self.index > #self.str then
      return nil
    end
    self.col = self.col + 1
    local char = string.sub(self.str, self.index, self.index)
    if char == "\n" or char == "\r" then
      if
        self.index + 1 <= #self.str
        and char == "\r"
        and string.sub(self.str, self.index + 1, self.index + 1) == "\n"
      then
        self.index = self.index + 1
      end
      self.col = 0
      self.row = self.row + 1
      table.insert(chars, "\n")
    else
      table.insert(chars, char)
    end
  end
  return table.concat(chars, "")
end

function Lexer:quoted()
  local quote = self:next_char()
  local lines = {}
  local chars = {}
  while self:peek_char() do -- and self:peek_char() ~= quote do
    local char = self:next_char()
    if quote == "'" and char == "'" and self:peek_char() == "'" then
      table.insert(chars, self:next_char())
    elseif char == quote then
      break
    elseif char == "\n" then
      table.insert(lines, table.concat(chars, ""))
      chars = {}
    else
      table.insert(chars, char)
    end
    -- end
  end
  table.insert(lines, table.concat(chars, ""))
  return lines
end

function Lexer:is_comment()
  local index = 1
  while self:peek_char(index) and self:peek_char(index) == " " do
    index = index + 1
    if self:peek_char(index) and self:peek_char(index) == "#" then
      return true
    end
  end
  return false
end

function Lexer:directive_tag_uri()
  local tag_uri = {}
  if self:match("tag:") then
    for _ = 1, 4 do
      table.insert(tag_uri, self:next_char())
    end
  end

  while self:peek_char() ~= "\n" and self:peek_char() ~= ":" do
    table.insert(tag_uri, self:next_char())
  end
  if self:peek_char() == ":" then
    table.insert(tag_uri, self:next_char())
  end

  while self:peek_char() and self:peek_char() ~= " " and self:peek_char() ~= "\n" do
    table.insert(tag_uri, self:next_char())
  end

  -- TODO: where to do this?
  -- self:skip_space_or_comment()
  -- if not self.iter:match(NL) then
  --   return nil, self:error("content after tag is not allowed")
  -- end
  -- return url_decode(table.concat(tag_uri, ""))
  return table.concat(tag_uri, "")
end

function Lexer:peek_sep()
  local index
  local start_index
  if self:peek_char() == "\n" then
    index = 2
    start_index = 2
  else
    index = 1
    start_index = 1
  end
  while self:peek_char(index) and self:peek_char(index) == " " do
    index = index + 1
  end
  return index - start_index
end

function Lexer:sep()
  local row, col = self.row, self.col

  local indent = 1
  while self:peek_char(indent) and (self:peek_char(indent) == " " or self:peek_char(indent) == "\t") do
    indent = indent + 1
  end

  local sep = { self:next_char() }
  while self:peek_char() and self:peek_char() == " " do
    -- TODO: here could be a comment
    if self:peek_char() == " " then
      table.insert(sep, self:next_char())
    end
  end
  return { kind = "SEP", val = table.concat(sep, ""), indent = indent - 1, row = row, col = col }
end

---checks if the next char after a linebreak is an empty line
---@return boolean
function Lexer:is_empty_line()
  local index
  if self:peek_char() == "\n" then
    index = 2
  else
    index = 1
  end
  while self:peek_char(index) do
    if self:peek_char(index) == " " or self:peek_char(index) == "\t" then
      index = index + 1
    elseif self:peek_char(index) == "\n" then
      return true
    else
      return false
    end
  end
  return false
end

function Lexer:folded(hint)
  local lines = {}
  local last_indent = 0
  local final_indent = (hint and (self.indent + hint) or nil)
  local empty_indent = 0
  if self:peek_char() == nil then
    return self.indent, lines
  end
  assert(
    self:peek_char() == "\n",
    "folded: first char is: '" .. (self:peek_char() and self:peek_char() or "eof") .. "'"
  )
  -- read the first empty line
  if self:is_empty_line() then
    self:next_char() -- skip NL
    if self:peek_char() == " " then
      last_indent = self:peek_sep() -- #sep.val
      local sep = self:sep()
      table.insert(lines, { indent = #sep.val, val = sep.val .. self:to_eol(), empty = true })
    else
      table.insert(lines, { indent = 0, val = "", empty = true })
    end
  else
    self:next_char()
  end
  while self:peek_char() do
    if self:peek_char() == " " then
      local sep = self:sep()
      last_indent = sep.indent -- TODO: #sep.val
    elseif self:peek_char() == "\n" then
      if self:is_empty_line() then
        if self:peek_char(2) == " " then
          self:next_char() -- skip NL
          local sep = self:sep()
          empty_indent = #sep.val
          table.insert(lines, { indent = sep.indent, val = sep.val, empty = true })
          assert(self:peek_char() == "\n")
        else
          assert(self:peek_char() == "\n")
          self:next_char()
          table.insert(lines, { indent = 0, val = "", empty = true })
        end
      elseif
        self:peek_char()
        and self:peek_sep() <= self.indent
        and (self.state == "DASH" or self.state == "COLON")
      then
        break
      elseif self:peek_char() and final_indent and self:peek_sep() < final_indent then
        break
      else
        self:next_char()
      end
    else
      if not final_indent then
        if empty_indent > last_indent then
          return nil, self:error("block scalar with wrongly indented line after spaces only")
        end
        final_indent = last_indent
      end
      table.insert(lines, { indent = last_indent, val = self:to_eol() })
    end
  end
  if not final_indent then
    final_indent = self.indent
  end

  return final_indent, lines
end

function Lexer:folding_attrs(type)
  local row, col = self.row, self.col
  local token = self:create_token(type, self:next_char(), row, col)
  while self:peek_char() and self:peek_char() ~= "\n" do
    local attr = self:next_char()
    if not attr then
      break
    elseif attr == "-" then
      token.chomping = "STRIP"
    elseif attr == "+" then
      token.chomping = "KEEP"
    elseif string.match(attr, "[%d]") then
      token.hint = tonumber(attr)
    elseif attr == " " and self:peek_char() == "#" then
      self:to_eol()
    elseif attr == "#" then
      return nil, self:error("invalid comment without whitespace after block scalar indicator")
    else
      return nil, self:error("unknown literal attribute")
    end
  end
  if self:peek_char() ~= "\n" then
    return nil, self:error("block scalar no linebreak found")
  end
  return token
end

---@return Token|nil
---@return string|nil
function Lexer:token()
  while self:peek_char() do
    local char = self:peek_char()
    if char == "%" and self:peek_char(2) ~= " " then
      local row, col = self.row, self.col
      self:next_char()
      local name = self:to_sep()
      if name == "YAML" then
        self:next_char()
        local version = self:to_sep()
        return self:create_token("YAML", version, row, col)
      elseif name == "TAG" then
        self:next_char()
        if self:peek_char() == "!" then
          self:next_char()
          if self:peek_char() == " " then
            self:next_char()
            local uri = self:directive_tag_uri()
            return { kind = "DIRECTIVE", type = "GLOBAL_TAG", val = uri, row = row, col = col }
          elseif self:peek_char() == "!" then
            self:next_char()
            local uri = self:directive_tag_uri()
            return { kind = "DIRECTIVE", type = "SECOND_TAG", val = uri, row = row, col = col }
          else
            local tag_name = ""
            while self:peek_char() and self:peek_char() ~= "!" do
              tag_name = tag_name .. self:next_char()
            end
            self:next_char(2)
            local uri = self:directive_tag_uri()
            return {
              kind = "DIRECTIVE",
              type = "NAMED_TAG",
              name = tag_name,
              val = uri,
              row = row,
              col = col,
            }
          end
        else
          error("TAG: '" .. self:next_char() .. "'")
        end
      else
        error("unknown directive")
      end
      return self:create_token("DIRECTIVE", "%", row, col)
    elseif self.col == 0 and self:match("---") then
      local row, col = self.row, self.col
      self:next_char(3)
      return self:create_token("START_DOC", "---", row, col)
    elseif char == "." and self:peek_char(2) == "." and self:peek_char(3) == "." then
      local row, col = self.row, self.col
      self:next_char(3)
      return self:create_token("END_DOC", "...", row, col)
    elseif char == "[" then
      local row, col = self.row, self.col
      self.flow_level = self.flow_level + 1
      return self:create_token("START_FLOW_SEQ", self:next_char(), row, col)
    elseif self.flow_level > 0 and char == "]" then
      local row, col = self.row, self.col
      self.flow_level = self.flow_level - 1
      return self:create_token("END_FLOW_SEQ", self:next_char(), row, col)
    elseif char == "{" then
      local row, col = self.row, self.col
      self.flow_level = self.flow_level + 1
      return self:create_token("START_FLOW_MAP", self:next_char(), row, col)
    elseif self.flow_level > 0 and char == "}" then
      local row, col = self.row, self.col
      self.flow_level = self.flow_level - 1
      return self:create_token("END_FLOW_MAP", self:next_char(), row, col)
    elseif self.flow_level > 0 and char == "," then
      local row, col = self.row, self.col
      return self:create_token("FLOW_SEP", self:next_char(), row, col)
    elseif self.flow_level > 0 and char == ":" and self:peek_char(0) == " " then
      local row, col = self.row, self.col
      return self:create_token("FLOW_COLON", self:next_char(), row, col)
    elseif self.flow_level > 0 and char == ":" and self:peek_char(0) == "}" then
      local row, col = self.row, self.col
      return self:create_token("FLOW_COLON", self:next_char(), row, col)
    elseif self.flow_level > 0 and char == ":" and self:peek_char(0) == '"' then
      local row, col = self.row, self.col
      return self:create_token("FLOW_COLON", self:next_char(), row, col)
    elseif
      self.flow_level > 0
      and char == ":"
      and (self:peek_char(2) == " " or self:peek_char(2) == "\n" or self:peek_char(2) == ",")
    then
      local row, col = self.row, self.col
      return self:create_token("FLOW_COLON", self:next_char(), row, col)
    elseif char == "?" and (self:peek_char(2) == " " or self:peek_char(2) == "\n") then
      local row, col = self.row, self.col
      return self:create_token("COMPLEX", self:next_char(), row, col)
    elseif char == "|" then
      local token, mes = self:folding_attrs("LITERAL")
      if not token then
        return nil, mes
      end
      local indent, lines = self:folded(token.hint)
      if not indent then
        return nil, lines
      end
      token.indent = indent
      token.lines = lines
      return token
    elseif char == ">" then
      local token, mes = self:folding_attrs("FOLDED")
      if not token then
        return nil, mes
      end
      local indent, lines = self:folded(token.hint)
      if not indent then
        return nil, lines
      end
      token.indent = indent
      token.lines = lines
      return token
    elseif char == "'" or char == '"' then
      local row, col = self.row, self.col
      local type = self:peek_char()
      return self:create_token("QUOTED", self:quoted(), row, col, type)
    elseif char == "-" and self:is_sep(2) and (not self.last_seq or self.col <= self.last_seq) then
      local row, col = self.row, self.col
      local tokens = {}
      while self:peek_indicator() == "-" do
        while self:peek_char() do
          if self:peek_char() == " " then
            -- TODO: use sep function
            local sep_row, sep_col = self.row, self.col
            local sep = { self:next_char() }
            while self:peek_char() and self:peek_char() == " " do
              -- TODO: here could be a comment
              table.insert(sep, self:next_char())
            end
            if sep_col == 0 then
              self.indent = #sep
            else
              self.indent = self.indent + #sep
            end
            if self:peek_char() ~= "\n" then
              table.insert(tokens, self:create_token("SEP", table.concat(sep, ""), sep_row, sep_col))
            end
          elseif self:peek_char() == "#" then
            self:to_eol()
          elseif self:peek_char() == "\n" then
            local row, col = self.row, self.col
            table.insert(tokens, self:create_token("NL", self:next_char(), row, col))
            if self:peek_char() ~= " " then
              table.insert(tokens, self:create_token("SEP", "", self.row, self.col))
            end
          elseif
            self:peek_char(3)
            and self:peek_char(1) == "-"
            and self:peek_char(2) == "-"
            and self:peek_char(3) == "-"
          then
            break
          elseif self:peek_char() == "-" then
            self.last_seq = self.col
            local row, col = self.row, self.col
            table.insert(tokens, self:create_token("DASH", self:next_char(), row, col))
          else
            break
          end
        end
      end
      -- self.last_seq = self.col

      -- char = self:next_char()
      -- skip whitespace TODO: create skip ws and comment
      -- while self:peek_char() and self:peek_char() == " " or self:peek_char() == "\t" do
      -- 	self:next_char()
      -- end
      -- -- check for comment
      -- if self:peek_char() == "#" then
      -- 	self:to_eol()
      -- end
      -- self.state = "DASH"
      -- self.indent = (self.col == 2 and 0 or self.col)
      -- return self:create_token("DASH", char, row, col)
      return tokens
    elseif char == ":" and self:is_sep(2) then
      local row, col = self.row, self.col
      char = self:next_char()
      -- skip whitespace TODO: create skip ws and comment
      while self:peek_char() and self:peek_char() == " " or self:peek_char() == "\t" do
        self:next_char()
      end
      -- check for comment
      if self:peek_char() == "#" then
        self:to_eol()
      end
      self.state = "COLON"
      self.indent = self.tokens[#self.tokens].col
      return self:create_token("COLON", char, row, col)
    elseif self:peek_char() == "!" then
      local row, col = self.row, self.col
      local tag
      if self:peek_char(2) and self:peek_char(2) == "!" then
        -- local t_tag = {}
        -- while self:peek_char() and string.match(self:peek_char(), "^[%a%d-!]$") do
        -- 	table.insert(t_tag, self:next_char())
        -- end
        tag = self:word_char()
      else
        tag = self:to_sep()
      end
      return self:create_token("TAGREF", tag, row, col)
    elseif char == "&" then
      local row, col = self.row, self.col
      self:next_char()
      local value = self:anchor_char()
      -- local value = self:to_sep()
      return self:create_token("ANCHOR", value, row, col)
    elseif char == "*" then
      local row, col = self.row, self.col
      self:next_char()
      local value = self:anchor_char()
      -- local value = self:to_sep()
      return self:create_token("ALIAS", value, row, col)
    elseif self:is_comment() then
      -- commented line
      local col = self.col
      self:to_eol()
      if col == 0 and self:peek_char() and self:peek_char() == "\n" then
        self:next_char()
      end
    elseif char == " " then
      self.state = "SEP"
      -- TODO: use sep function
      local row, col = self.row, self.col
      local sep = { self:next_char() }
      while self:peek_char() and self:peek_char() == " " do
        -- TODO: here could be a comment
        table.insert(sep, self:next_char())
      end
      if col == 0 then
        self.indent = #sep
      else
        self.indent = self.indent + #sep
      end
      if self.last_seq and self.last_seq > #sep then
        last_seq = nil
      end

      return self:create_token("SEP", table.concat(sep, ""), row, col)
    elseif char == "\n" then
      local row, col = self.row, self.col
      if self.state ~= "DASH" and self.state ~= "COLON" then
        self.state = 0
      end
      return self:create_token("NL", self:next_char(), row, col)
    elseif self.col == 0 and self:peek_char() == "#" then
      self:to_eol()
      self:next_char()
    else
      local row, col = self.row, self.col
      local chars = { self:next_char() }
      while self:peek_char() and self:peek_char() ~= "\n" do
        -- skip the comment
        if (self:peek_char() == " " or self:peek_char() == "\t") and self:peek_char(2) == "#" then
          while self:peek_char() and self:peek_char() ~= "\n" do
            self:next_char()
          end
          break
        elseif self.flow_level > 0 and self:peek_char() and self:peek_char() == ":" and self:peek_char(2) == " " then
          break
        elseif self.flow_level > 0 and self:peek_char() and match("{}[],", self:peek_char()) then
          break
        elseif
          self:peek_char() == ":"
          and (
            self:peek_char(2) == " "
            or self:peek_char(2) == "\n"
            or self:peek_char(2) == "\t"
            or self:peek_char(2) == ","
          )
        then
          break
        end
        table.insert(chars, self:next_char())
      end
      self.state = "VAL"
      return self:create_token("VAL", rtrim(table.concat(chars, "")), row, col)
    end
  end
  return { kind = "END" }
end

function Lexer:lexme()
  local token, mes = self:token()
  if not token then
    return mes
  end
  assert(token)
  if token.kind ~= "SEP" then
    self.indent = 0
    table.insert(self.tokens, self:create_token("SEP", "", self.row, 0))
  end
  while token and token.kind ~= "END" do
    if token[1] then
      for _, t in ipairs(token) do
        table.insert(self.tokens, t)
      end
    else
      table.insert(self.tokens, token)
      -- TODO: why this?
      if token.kind == "NL" then
        if self:peek_char() then
          if self:peek_char() ~= " " then
            self.indent = 0
            table.insert(self.tokens, self:create_token("SEP", "", self.row, 0))
          end
        else
          break
        end
      end
    end
    token, mes = self:token()
    if not token then
      return mes
    end
  end
end

function Lexer:peek(n)
  return self.tokens[self.t_index + (n and n or 1)]
end

--- Get a line from the YAML by number
---@param nr integer The line number
---@return string|nil Returns the content of the line
function Lexer:line(nr)
  local lines = {}
  for s in string.gmatch(self.str, "[^\n]+") do
    table.insert(lines, s)
  end
  if nr >= 1 and nr <= #lines then
    return lines[nr]
  else
    return nil
  end
end

function Lexer:error(mess, token)
  return "ERROR:"
    .. (token and token.row or self.row)
    .. ":"
    .. (token and token.col or self.col)
    .. " "
    .. mess
    .. "\n"
    .. (self:line(token and token.row or self.row) or "") -- TODO last line results in nil
    .. "\n"
    .. string.rep(" ", (token and token.col or self.col))
    .. "^"
end

function Lexer:next()
  self.t_index = self.t_index + 1
  if self.t_index > #self.tokens then
    return nil
  end
  return self.tokens[self.t_index]
end

function Lexer:rewind(n)
  local i = (n or 1)
  assert(self.t_index - i > 0)
  self.t_index = self.t_index - i
end

function Lexer:html()
  local body = {
    [[
  <html><head>
<style>
.BOX {
  padding: 2px;
  margin: 3px;
  line-height: 40px;
  border-radius: 5px;
  color: #fff;
  text-decoration: none;
}
.DASH, .COLON, .START_FLOW_SEQ, .END_FLOW_SEQ, .START_FLOW_MAP, .END_FLOW_MAP, .FLOW_SEP, .FLOW_COLON, .START_DOC, .END_DOC, .ANCHOR, .ALIAS, .COMPLEX {
  background-color: #4C0000;
  }

.GLOBAL_TAG, .TAGREF {
  background-color: #00AA00;
}

.NL, .VAL {
  background-color: #343434;
}

.SEP {
  background-color: #004C00;
}

.POS {
  color: #afafaf;
}
</style>
  </head><body>
  ]],
  }
  local token = self:next()
  while token do
    if not token.val then
      table.insert(
        body,
        "<span class='BOX "
          .. token.kind
          .. "'>"
          .. "<span class='POS'>["
          .. token.row
          .. ":"
          .. token.col
          .. "]</span>"
          .. token.kind
          .. "</span>"
      )
    elseif token.kind == "NL" then
      table.insert(body, "<span class='BOX " .. token.kind .. "'>↓</span><br>")
    elseif token.kind == "SEP" then
      table.insert(
        body,
        "<span class='SEP BOX'><span class='POS'>["
          .. token.row
          .. ":"
          .. token.col
          .. "] </span>SEP "
          .. #token.val
          .. "</span>"
      )
    elseif token.kind == "LITERAL" or token.kind == "FOLDED" then
      table.insert(
        body,
        "<span class='BOX "
          .. token.kind
          .. "'><span class='POS'>["
          .. token.row
          .. ":"
          .. token.col
          .. "] </span><pre>"
          .. token.val
          .. "  "
          .. to_string(token.lines)
          .. "</pre></span>"
      )
    elseif token.kind == "QUOTED" then
      table.insert(
        body,
        "<span class='BOX "
          .. token.kind
          .. "'><span class='POS'>["
          .. token.row
          .. ":"
          .. token.col
          .. "] </span><pre>"
          .. table.concat(token.val, "\n")
          .. "</pre></span>"
      )
    else
      table.insert(
        body,
        "<span class='BOX "
          .. token.kind
          .. "'><span class='POS'>["
          .. token.row
          .. ":"
          .. token.col
          .. "] </span>"
          .. token.val
          .. "</span>"
      )
    end
    token = self:next()
  end
  table.insert(body, "</body></html>")
  return table.concat(body, "\n")
end

local Parser = {}
Parser.__index = Parser

---@class Parser
---@field lexer Lexer
---@return Lexer
function Parser:new(lexer)
  local o = {}
  setmetatable(o, self)
  o.stream = TokenStream:new(lexer)
  o.lexer = lexer
  o.tokens = {}

  o.global_tag = GLOBAL_TAG
  o.primary_tag = nil
  o.named_tags = {}

  o.state = {}
  o.anchor = {}

  o.index = 0
  return o
end

function Parser:value(str)
  if string.match(str, "\\x%x%x") then
    str = string.gsub(str, "\\x(%x%x)", function(hex)
      return string.char(tonumber(hex, 16))
    end)
  end
  if string.find(str, "\\u%x%x%x%x") then
    str = string.gsub(str, "\\u(%x%x%x%x)", function(hex)
      return utf8(tonumber(hex, 16))
    end)
  end
  if string.find(str, "\\([b|t|r])") then
    str = string.gsub(str, "\\([b|t|r])", function(hex)
      if hex == "b" then
        return utf8(tonumber("08", 16))
      elseif hex == "t" then
        return utf8(tonumber("09", 16))
      elseif hex == "r" then
        return utf8(tonumber("0D", 16))
      else
        error("unknown character: " .. hex)
      end
    end)
  end
  return str
end

function Parser:scalar_type(str)
  if str == "true" then
    return true
  elseif str == "false" then
    return false
  elseif str.match(str, "^0x") then
    return str
  elseif tonumber(str) then
    return tonumber(str)
  else
    return str
  end
end

function Parser:push(target, tokens)
  if not tokens then
    table.insert(target, { kind = "VAL", val = "", tag = self.tagref, anchor = table.remove(self.anchor) })
    self.tagref = nil
  elseif tokens[1] and type(tokens[1]) == "table" then
    for _, t in ipairs(tokens) do
      table.insert(target, t)
    end
  else
    table.insert(target, tokens)
  end
end

function Parser:quoted(token)
  local res
  local last_nl = false
  for i, line in ipairs(token.val) do
    if token.type == '"' and string.match(line, "\\$") then
      if not res then
        res = {}
      end
      table.insert(res, ltrim(string.sub(line, 1, #line - 1)))
    elseif token.type == '"' and string.match(line, "^( +\\)(.*)$") then
      local content = string.match(line, "^ +\\(.*)$")
      table.insert(res, content)
    elseif trim(line) == "" then
      if not res then
        res = {}
        table.insert(res, " ")
      elseif i == #token.val then
        table.insert(res, " ")
      else
        table.insert(res, "\n")
      end
      last_nl = true
    elseif res then
      if not last_nl then
        table.insert(res, " ")
      else
        last_nl = false
      end
      if i == #token.val then
        table.insert(res, ltrim(line))
      else
        table.insert(res, trim(line))
      end
    else
      res = {}
      table.insert(res, rtrim(line))
    end
  end
  if token.type == '"' then
    return string.gsub(table.concat(res, ""), "\\n", "\n")
  else
    return table.concat(res, "")
  end
end

function Parser:folded(token, indent, is_folded_block)
  local parts = { token.val }

  while self.stream:peek() do
    local lookahead = self.stream:peek()

    -- Case 1: Separator (Colon)
    if lookahead.kind == "COLON" then
      break

    -- Case 2: Continuation Value
    elseif lookahead.kind == "VAL" then
      local next_val = self.stream:next()
      table.insert(parts, next_val.val)

    -- Case 3: Spaces (SEP)
    elseif lookahead.kind == "SEP" then
      self.stream:next() -- consume the space
      if table.concat(parts) ~= "" then
        table.insert(parts, " ")
      end

    -- Case 4: Newline (Multiline Scalar)
    elseif lookahead.kind == "NL" then
      local next_sep = self.stream:peek(2)
      local next_token = self.stream:peek(3)

      -- Determine indentation length of the next line
      local next_indent = 0
      if next_sep and next_sep.kind == "SEP" then
        next_indent = #next_sep.val
      end

      -- CHECK: If next line is less OR EQUAL indented to the parent block,
      -- it implies a new key or end of block. Stop.
      if next_indent <= indent then
        break
      end

      -- Stop if the next line looks like a structural element (List or Map Key)
      if next_token and (next_token.kind == "DASH" or next_token.kind == "COLON") then
        break
      end

      -- Consume the NL and the Indentation
      self.stream:next() -- NL
      if next_sep and next_sep.kind == "SEP" then
        self.stream:next() -- SEP
      end

      table.insert(parts, " ")

    -- Case 5: Any other token ends the scalar
    else
      break
    end
  end

  return table.concat(parts, "")
end

function Parser:leading_tabs(str)
  local i = 1
  while string.sub(str, i, i) == "\t" do
    i = i + 1
  end
  return i - 1
end

function Parser:literal(token)
  local lines
  local sep
  if token.kind == "LITERAL" then
    sep = "\n"
  else
    sep = " "
  end
  local indent = (token.hint and token.hint or token.indent)
  local last_empty = false
  local last_indent = (token.lines[1] and token.lines[1].indent or 0)
  local is_more_indented = false
  local first_content_line = true
  for _, line in ipairs(token.lines) do
    if lines then
      if line.empty and token.kind == "FOLDED" then
        if last_indent > indent then
          table.insert(lines, "\n")
        end
        table.insert(lines, string.sub(line.val, indent + 1) .. "\n")
        last_empty = true
        last_indent = line.indent
      elseif line.indent > indent and token.kind == "FOLDED" then
        if not first_content_line and not (last_empty and is_more_indented) then
          if string.sub(line.val, 1, 1) == "\t" then
            table.insert(lines, "\n" .. line.val)
          else
            -- TODO: use begin_tab
            table.insert(lines, "\n" .. string.rep(" ", line.indent - indent) .. line.val)
          end
        else
          table.insert(lines, string.rep(" ", line.indent - indent) .. line.val)
        end
        first_content_line = false
        last_empty = false
        last_indent = line.indent
        is_more_indented = true
      elseif last_empty and token.kind == "FOLDED" then
        table.insert(lines, string.rep(" ", line.indent - indent) .. line.val)
        first_content_line = false
        is_more_indented = false
        last_empty = false
      else
        if last_indent > indent then
          table.insert(lines, "\n" .. string.rep(" ", line.indent - indent - self:leading_tabs(line.val)) .. line.val)
          first_content_line = false
          last_indent = line.indent
        elseif line.empty then
          table.insert(lines, sep .. string.sub(line.val, indent + 1))
        elseif first_content_line then
          table.insert(lines, line.val)
          first_content_line = false
        else
          table.insert(lines, sep .. string.rep(" ", line.indent - indent - self:leading_tabs(line.val)) .. line.val)
          first_content_line = false
        end
      end
    else
      lines = {}
      if line.empty then
        table.insert(lines, string.sub(line.val, line.indent + 1) .. "\n")
        last_empty = true
      else
        table.insert(lines, string.rep(" ", line.indent - token.indent) .. line.val)
        first_content_line = false
      end
    end
  end
  -- remove trailing newlines
  if lines and token.chomping ~= "KEEP" then
    while lines[#lines] == "\n" do
      table.remove(lines, #lines)
    end
  end
  -- collect the result
  local result
  -- corner case when the folded contnet is an empty line
  if not lines or (#lines == 0) then
    if token.chomping == "KEEP" then
      result = "\n"
    else
      result = ""
    end
  else
    -- normal case
    result = table.concat(lines, "")
    if token.chomping == "KEEP" and not first_content_line then
      result = result .. "\n"
    elseif token.chomping ~= "STRIP" and string.sub(result, #result) ~= "\n" then
      result = result .. "\n"
    end
  end
  -- return result
  return result
end

function Parser:parse_scalar_token(indent)
  local token = self.stream:next()
  local val
  local type_char = nil -- for quoted

  if token.kind == "VAL" then
    -- Handle multi-line plain scalars using your existing logic or simplified
    val = self:folded(token, indent, false)
    print("value: " .. val)
  elseif token.kind == "QUOTED" then
    val = self:quoted(token)
    type_char = token.type
  elseif token.kind == "LITERAL" then
    val = self:literal(token)
    type_char = "|"
  elseif token.kind == "FOLDED" then
    val = self:literal(token)
    type_char = ">"
  end

  print("SCALAR: " .. to_string(val))
  local evt = {
    kind = "VAL",
    val = val,
    type = type_char,
    tag = self.tagref,
    anchor = table.remove(self.anchor),
  }

  self.tagref = nil
  print("value: " .. to_string(val))
  return evt
end

function Parser:block_node(indent, is_sequence_entry)
  self.stream:skip_ignorable()

  -- 2. Check Indentation
  -- If we dropped below the required indent, we are done with this block.
  -- Exception: If we are inside a sequence entry (is_sequence_entry=true),
  -- the indent rules are slightly more relaxed in some YAML specs,
  -- but strictly checking is safer for now.
  if self.stream:check_indent(indent) == "LESS" then
    return nil
  end

  local token = self.stream:peek()
  if not token then
    return nil
  end

  -- 3. Dispatch based on Token Kind

  -- === Decorators (Anchors & Tags) ===
  -- Store the data and RECURSE to parse the actual node
  if token.kind == "ANCHOR" then
    table.insert(self.anchor, self.stream:next())
    return self:block_node(indent, is_sequence_entry)
  elseif token.kind == "TAGREF" then
    self.tagref = self.stream:next()
    self.tagref.val = self:parse_tag(self.tagref.val)
    return self:block_node(indent, is_sequence_entry)

  -- === Alias ===
  elseif token.kind == "ALIAS" then
    local alias = self.stream:next()
    return { { kind = "ALIAS", val = alias.val, tag = self.tagref } }

  -- === Block Sequence ===
  elseif token.kind == "DASH" then
    -- It is a sequence starting here
    -- Note: We generally shouldn't hit this inside block_node unless
    -- it's a nested sequence.
    return self:sequence(indent)

  -- === Flow Structures ===
  elseif token.kind == "START_FLOW_SEQ" or token.kind == "START_FLOW_MAP" then
    return self:flow(indent)

  -- === Scalars (Literals, Folded, Quoted, Plain) ===
  elseif self.stream:is_scalar() then
    -- Critical decision: Is this a Key or a Value?
    if self.stream:is_followed_by("COLON") then
      -- It's a map starting with this key
      local key_token = self:parse_scalar_token(indent)
      log("found map: " .. to_string(key_token))
      return self:map(indent, key_token)
    else
      -- It's just a value
      local scalar_event = self:parse_scalar_token(indent)
      -- Wrap in a table because your Parser expects lists of events
      return { scalar_event }
    end

  -- === Explicit Map Key (?) ===
  elseif token.kind == "COMPLEX" then
    -- '?' indicates an explicit complex key
    -- We consume '?', parse the node, then expect a map
    self.stream:next()
    local key_node = self:block_node(indent + 1)
    -- Complex map logic is tricky, usually hands off to map()
    -- with the parsed node as the key
    return self:map(indent, key_node, self.tagref)

  -- === Explicit Map Value (:) ===
  -- This happens if the key was implicit/empty, e.g.:
  -- : value
  elseif token.kind == "COLON" then
    log("explicit map")
    return self:map(indent)

  -- === Document Boundaries ===
  elseif token.kind == "START_DOC" or token.kind == "END_DOC" then
    return nil -- Let the main loop handle this
  else
    return nil, self.lexer:error("Unexpected token in block: " .. token.kind, token)
  end
end

function Parser:parse_tag(tag)
  if string.match(tag, "^!<.*>") then
    return string.sub(tag, 2)
  elseif string.match(tag, "^![%a%d]+![%%%a%d]*") then
    local name, uri = string.match(tag, "^!([%a%d]*)!([%%%a%d]*)")
    return "<" .. self.named_tags[name] .. url_decode(uri) .. ">"
  elseif string.match(tag, "^!![%a%d]*") then
    if self.second_tag then
      return "<" .. trim(self.second_tag) .. string.sub(tag, 3) .. ">"
    else
      return "<" .. self.global_tag .. string.sub(tag, 3) .. ">"
    end
  elseif string.match(tag, "^![%a%d]*") then
    if self.primary_tag then
      return "<" .. self.primary_tag .. string.sub(tag, 2) .. ">"
    else
      return "<!" .. string.sub(tag, 2) .. ">"
    end
  else
    error("unknwon tag")
  end
end

function Parser:peek_val()
  local index = 1
  while self.lexer:peek(index) do
    if self.lexer:peek(index).kind == "VAL" then
      return true
    elseif self.lexer:peek(index).kind ~= "NL" and self.lexer:peek(index).kind ~= "SEP" then
      return false
    end
    index = index + 1
  end
end

function Parser:flow_map(indent, flow_indent)
  local tokens = {}
  table.insert(tokens, { kind = "+MAP {}", tag = self.tagref, anchor = table.remove(self.anchor) })
  self.tagref = nil
  local start_token = self.lexer:next()
  local token = self.lexer:peek()
  local is_key = 0 -- 0 when it is a key 1 is value
  while token do
    if token.kind == "START_FLOW_MAP" or token.kind == "START_FLOW_SEQ" then
      is_key = (is_key + 1) % 2
      self:push(tokens, self:flow(indent, flow_indent))
    elseif token.kind == "END_FLOW_MAP" then
      if is_key == 1 then
        table.insert(
          tokens,
          { kind = "VAL", val = "", type = token.type, tag = self.tagref, anchor = table.remove(self.anchor) }
        )
        self.tagref = nil
      end
      table.insert(tokens, { kind = "-MAP" })
      return tokens
    elseif token.kind == "SEP" then
      local sep = self.lexer:next()
      if #sep.val < indent and sep.col == 0 then
        return nil, self.lexer:error("wrongly indented flow mapping", sep)
      end
    elseif token.kind == "FLOW_SEP" then
      if is_key == 1 then
        table.insert(tokens, {
          kind = "VAL",
          val = "",
          type = token.type,
          tag = self.tagref,
          anchor = table.remove(self.anchor),
        })
        self.tagref = nil
        is_key = 0
      end
      self.lexer:next()
    elseif token.kind == "FLOW_COLON" then
      if is_key == 0 then
        is_key = (is_key + 1) % 2
        table.insert(tokens, {
          kind = "VAL",
          val = "",
          type = token.type,
          tag = self.tagref,
          anchor = table.remove(self.anchor),
        })
        self.tagref = nil
      end
      self.lexer:next()
    elseif token.kind == "QUOTED" then
      local res = self:quoted(self.lexer:next())
      table.insert(
        tokens,
        { kind = "VAL", val = res, type = token.type, tag = self.tagref, anchor = table.remove(self.anchor) }
      )
      self.tagref = nil
      is_key = (is_key + 1) % 2
    elseif token.kind == "COMPLEX" then
      -- TODO: this is a mess
      self.lexer:next()
      -- TODO: this is used in different places
      while self.lexer:peek() and self.lexer:peek().kind == "SEP" or self.lexer:peek().kind == "NL" do
        self.lexer:next()
      end
      assert(self.lexer:peek().kind == "VAL", "expected VAL but is: " .. self.lexer:peek().kind)
      local val = self.lexer:next()
      log("key val: " .. to_string(val))
      while self.lexer:peek() and self.lexer:peek().kind ~= "FLOW_COLON" and self.lexer:peek().kind ~= "END_FLOW_SEQ" do
        local next_val = self.lexer:next()
        if next_val.kind == "VAL" then
          val.val = val.val .. " " .. next_val.val
        end
      end
    elseif token.kind == "VAL" then
      local val = self.lexer:next()
      while self:peek_val() do
        log("peek_val")
        local val_token = self.lexer:peek()
        while val_token do
          log(" val: " .. val_token.kind)
          if val_token.kind == "VAL" then
            val.val = val.val .. val_token.val
          elseif val_token.kind == "NL" then
            val.val = val.val .. " "
          elseif val_token.kind ~= "SEP" then
            break
          end
          self.lexer:next()
          val_token = self.lexer:peek()
        end
      end
      log("VAL: " .. is_key .. " " .. val.val)
      table.insert(tokens, { kind = "VAL", val = val.val, tag = self.tagref, anchor = table.remove(self.anchor) })
      self.tagref = nil
      is_key = (is_key + 1) % 2
    elseif token.kind == "NL" then
      self.lexer:next()
    elseif token.kind == "ANCHOR" then
      table.insert(self.anchor, self.lexer:next())
    elseif token.kind == "ALIAS" then
      self.lexer:next()
      table.insert(tokens, { kind = "ALIAS", val = token.val, tag = self.tagref })
      is_key = (is_key + 1) % 2
    elseif token.kind == "TAGREF" then
      self.tagref = self.lexer:next()
      self.tagref.val = self:parse_tag(self.tagref.val)
    else
      error("unknown flow_map kind: " .. token.kind)
    end
    token = self.lexer:peek()
  end
  return nil, self.lexer:error("flow map without a closing bracket", start_token)
end

function Parser:flow_seq(indent, flow_indent)
  local tokens = {}
  table.insert(tokens, { kind = "+SEQ []", tag = self.tagref, anchor = table.remove(self.anchor) })
  self.tagref = nil
  local start_token = self.lexer:next()
  local token = self.lexer:peek()
  while token do
    if token.kind == "START_FLOW_MAP" or token.kind == "START_FLOW_SEQ" then
      local children = self:flow(indent, flow_indent)
      if self.lexer:peek().kind == "FLOW_COLON" then
        self.lexer:next()
        table.insert(tokens, { kind = "+MAP {}" })
        self:push(tokens, children)
        if self.lexer:peek().kind == "SEP" then
          self.lexer:next()
        end
        local res = self.lexer:next()
        assert(res.kind == "VAL", "expected VAL  but is: " .. res.kind)
        table.insert(tokens, { kind = "VAL", val = res.val })
        table.insert(tokens, { kind = "-MAP" })
      else
        self:push(tokens, children)
      end
    elseif token.kind == "END_FLOW_SEQ" then
      table.insert(tokens, { kind = "-SEQ" })
      return tokens
    elseif token.kind == "SEP" then
      self.lexer:next()
    elseif token.kind == "FLOW_SEP" then
      self.lexer:next()
    elseif token.kind == "QUOTED" then
      local res = self:quoted(self.lexer:next())
      if self.lexer:peek() and self.lexer:peek().kind == "SEP" then
        self.lexer:next()
      end
      if self.lexer:peek().kind == "FLOW_COLON" then
        self.lexer:next()
        table.insert(tokens, { kind = "+MAP {}" })
        log("VAL: " .. res)
        table.insert(tokens, { kind = "VAL", val = res, type = token.type })
        if self.lexer:peek().kind == "SEP" then
          self.lexer:next()
        end
        res = self.lexer:next()
        assert(res.kind == "VAL", "expected VAL  but is: " .. res.kind)
        table.insert(tokens, { kind = "VAL", val = res.val })
        table.insert(tokens, { kind = "-MAP" })
      else
        table.insert(tokens, { kind = "VAL", val = res, type = token.type })
      end
    elseif token.kind == "FLOW_COLON" then
      self.lexer:next()
      table.insert(tokens, { kind = "+MAP {}" })
      table.insert(tokens, { kind = "VAL", val = "", anchor = table.remove(self.anchor) })
      self.lexer:next()
      local val = self.lexer:next()
      assert(val.kind == "VAL", "expected VAL  but is: " .. val.kind)
      table.insert(tokens, { kind = "VAL", val = val.val })
      table.insert(tokens, { kind = "-MAP" })
    elseif token.kind == "TAGREF" then
      self.tagref = self.lexer:next()
      self.tagref.val = self:parse_tag(self.tagref.val)
    elseif token.kind == "VAL" then
      local val = self.lexer:next()
      if self.lexer:peek().kind == "FLOW_COLON" then
        self.lexer:next()
        table.insert(tokens, { kind = "+MAP {}" })
        table.insert(tokens, { kind = "VAL", val = val.val, anchor = table.remove(self.anchor) })
        val = self.lexer:next()
        val = self.lexer:next()
        assert(val.kind == "VAL", "expected VAL  but is: " .. val.kind)
        table.insert(tokens, { kind = "VAL", val = val.val, anchor = table.remove(self.anchor) })
        table.insert(tokens, { kind = "-MAP" })
      else
        local value = {}
        table.insert(value, val.val)
        while self.lexer:peek() do
          if self.lexer:peek().kind == "VAL" then
            table.insert(value, trim(self.lexer:next().val))
          elseif self.lexer:peek().kind == "NL" then
            if self.lexer:peek(2).kind == "SEP" and self.lexer:peek(3).kind == "VAL" then
              self.lexer:next()
              self.lexer:next()
            else
              break
            end
          else
            break
          end
        end
        table.insert(tokens, {
          kind = "VAL",
          val = trim(table.concat(value, " ")),
          tag = self.tagref,
          anchor = table.remove(self.anchor),
        })
      end
    elseif token.kind == "NL" then
      self.lexer:next()
    elseif token.kind == "COMPLEX" then
      -- TODO: this is a mess
      self.lexer:next()
      assert(self.lexer:peek().kind == "SEP", "expected SEP but is: " .. self.lexer:peek().kind)
      self.lexer:next()
      assert(self.lexer:peek().kind == "VAL", "expected VAL but is: " .. self.lexer:peek().kind)
      local val = self.lexer:next()
      log("key val: " .. to_string(val))
      while self.lexer:peek() and self.lexer:peek().kind ~= "FLOW_COLON" and self.lexer:peek().kind ~= "END_FLOW_SEQ" do
        local next_val = self.lexer:next()
        if next_val.kind == "VAL" then
          val.val = val.val .. " " .. next_val.val
        end
      end
      log("after key: " .. to_string(self.lexer:peek()))
      if self.lexer:peek().kind == "END_FLOW_SEQ" then
        table.insert(tokens, { kind = "+MAP {}" })
        if val and val.kind == "VAL" then
          table.insert(tokens, { kind = "VAL", val = val.val })
        else
          table.insert(tokens, { kind = "VAL", val = "" })
        end
        table.insert(tokens, { kind = "VAL", val = "" })
        table.insert(tokens, { kind = "-MAP" })
      else
        self.lexer:next()
        table.insert(tokens, { kind = "+MAP {}" })
        if val and val.kind == "VAL" then
          table.insert(tokens, { kind = "VAL", val = val.val })
        else
          table.insert(tokens, { kind = "VAL", val = "" })
        end
        val = self.lexer:next()
        log("first val: " .. to_string(val))
        val = self.lexer:next()
        log("second val: " .. to_string(val))
        if val and val.kind == "VAL" then
          table.insert(tokens, { kind = "VAL", val = val.val })
        else
          table.insert(tokens, { kind = "VAL", val = "" })
        end
        table.insert(tokens, { kind = "-MAP" })
      end
    elseif token.kind == "ANCHOR" then
      table.insert(self.anchor, self.lexer:next())
    elseif token.kind == "ALIAS" then
      self.lexer:next()
      table.insert(tokens, { kind = "ALIAS", val = token.val, tag = self.tagref })
    else
      error("unknown flow_seq kind: " .. token.kind)
    end
    token = self.lexer:peek()
  end
  return nil, self.lexer:error("flow sequence without a closing bracket", start_token)
end

function Parser:flow(indent, flow_indent)
  if #self.state > 0 then
    indent = indent + 1
  end
  local tokens = {}
  local token = self.lexer:peek()
  local flow_level = 0
  local next_indent = indent
  while token do
    if token.kind == "START_FLOW_SEQ" then
      flow_level = flow_level + 1
      local childs, mes = self:flow_seq(indent, indent + flow_level)
      if not childs then
        return nil, mes
      end
      self:push(tokens, childs)
    elseif token.kind == "END_FLOW_SEQ" then
      flow_level = flow_level - 1
      self.lexer:next()
      if flow_level == 0 then
        break
      end
    elseif token.kind == "START_FLOW_MAP" then
      flow_level = flow_level + 1
      local childs, mes = self:flow_map(indent, indent + flow_level)
      if not childs then
        return nil, mes
      end
      self:push(tokens, childs)
    elseif token.kind == "END_FLOW_MAP" then
      flow_level = flow_level - 1
      self.lexer:next()
      if flow_level == 0 then
        break
      end
    else
      error("unknown flow kind: " .. token.kind)
    end
    token = self.lexer:peek()
  end
  assert(flow_level == 0, "flow level is " .. flow_level)
  return tokens
end

function Parser:sequence(indent)
  log("sequence " .. indent)
  local act_indent = indent
  local tokens = {}
  table.insert(self.state, "SEQ")
  table.insert(tokens, { kind = "+SEQ", tag = self.tagref, anchor = table.remove(self.anchor) })
  self.tagref = nil
  -- self.anchor = nil
  local token = self.lexer:peek()
  while token do
    if token.kind == "SEP" then
      if indent > #token.val then
        break
      end
      self.lexer:next()
      self.indent = token.indent
    elseif token.kind == "NL" then
      self.lexer:next()
      log("found NL: after: " .. (self.lexer:peek(2) and self.lexer:peek(2).kind or "eof"))
      if self.lexer:peek() and self.lexer:peek().kind == "SEP" then
        log("found sep: next:" .. self.lexer:peek(2).kind)
        local sep = self.lexer:peek()
        -- check sep
        if #sep.val < indent then
          break
        elseif self.lexer:peek(2) and self.lexer:peek(2).kind ~= "DASH" then
          break
        end
        self.lexer:next()
      end
    elseif token.kind == "DASH" then
      act_indent = self.lexer:next().col
      log("found dash")
      if self.lexer:peek() and self.lexer:peek().kind == "SEP" then
        log("skip sep")
        local _ = self.lexer:next()
      end
      if
        self.lexer:peek().kind == "NL"
        and self.lexer:peek(2)
        and self.lexer:peek(2).kind == "SEP"
        and #self.lexer:peek(2).val == indent
      then
        table.insert(tokens, { kind = "VAL", val = "", tag = self.tagref })
        self.tagref = nil
      elseif self.lexer:peek() and self.lexer:peek().kind == "DASH" then
        local child, mes = self:sequence(self.lexer:peek().col)
        if not child then
          return nil, mes
        end
        if self.lexer:peek() and self.lexer:peek().kind == "SEP" then
          if #self.lexer:peek().val < indent then
            break
          elseif #self.lexer:peek().val > indent then
            local sep = self.lexer:next()
            return nil, self.lexer:error("wrong indentation: should be " .. indent .. " but is " .. #sep.val, sep)
          end
        end
        self:push(tokens, child)
      elseif self.lexer:peek() and self.lexer:peek().kind == "END_DOC" then
        break
      elseif self.lexer:peek() and self.lexer:peek().kind == "NL" then
        self.lexer:next()
        local new_indent
        if self.lexer:peek() and self.lexer:peek().kind == "SEP" then
          new_indent = #self.lexer:next().val
          local child = self:block_node(new_indent, false)
          self:push(tokens, child)
        else
          error("no sep found")
        end
      end
    elseif
      token.kind == "ANCHOR"
      and self.lexer:peek(2)
      and self.lexer:peek(2).kind == "NL"
      and self.lexer:peek(3)
      and self.lexer:peek(3).kind == "SEP"
      and #self.lexer:peek(3).val == indent
    then
      table.insert(tokens, { kind = "VAL", val = "", tag = self.tagref, anchor = self.lexer:next() })
      self.tagref = nil
    elseif token.kind == "END_DOC" or token.kind == "START_DOC" then
      break
    else
      log("seq: call block node: " .. act_indent .. " type: " .. self.lexer:peek().kind)
      local val = self:block_node(act_indent, true)
      log("= call block node: " .. to_string(val))
      -- assert(self.lexer:peek().kind == "NL")
      self:push(tokens, val)
    end
    token = self.lexer:peek()
  end
  table.insert(tokens, { kind = "-SEQ" })
  table.remove(self.state)
  log("end sequence " .. indent)
  return tokens
end

-- function Parser:sequence(indent)
--   log("sequence " .. indent)
--   local act_indent = indent
--   local tokens = {}
--   table.insert(self.state, "SEQ")
--   table.insert(tokens, { kind = "+SEQ", tag = self.tagref, anchor = table.remove(self.anchor) })
--   self.tagref = nil
--
--   -- This new loop correctly processes all items in a sequence.
--   while true do
--     -- Peek ahead, skipping over any whitespace or newlines between items.
--     local p_index = 1
--     while self.lexer:peek(p_index) and (self.lexer:peek(p_index).kind == "NL" or self.lexer:peek(p_index).kind == "SEP") do
--       p_index = p_index + 1
--     end
--
--     local token = self.lexer:peek(p_index)
--     log(" - " .. to_string(token))
--     -- **Termination Condition:** The sequence ends if there are no more tokens,
--     -- or if the next significant token is NOT a dash, or if its indentation is too low.
--     if not token or token.kind ~= "DASH" or token.col < indent then
--       log("break no dash")
--       break
--     end
--
--     -- Now that we know it's a valid list item, consume the whitespace we just peeked over.
--     for _ = 1, p_index - 1 do
--       self.lexer:next()
--     end
--
--     -- We are now at the DASH. Process the item.
--     act_indent = self.lexer:next().col -- Consume the DASH
--     if self.lexer:peek() and self.lexer:peek().kind == "SEP" then
--       self.lexer:next()                -- Consume separator after dash
--     end
--
--     -- Check for an empty item (e.g., just a dash followed by a newline)
--     if not self.lexer:peek() or self.lexer:peek().kind == "NL" then
--       self:push(tokens, nil) -- A nil value will be converted to an empty VAL node.
--     else
--       -- Otherwise, parse the actual value of the item
--       local val, mes = self:block_node(act_indent, true)
--       if not val then return nil, mes end
--       self:push(tokens, val)
--     end
--   end
--
--   table.insert(tokens, { kind = "-SEQ" })
--   table.remove(self.state)
--   log("end sequence " .. indent)
--   return tokens
-- end

function Parser:map(indent, first_key_token, tag)
  -- 1. Emit the Start Map Event
  table.insert(self.tokens, { kind = "+MAP", tag = tag, anchor = table.remove(self.anchor) })
  self.stream:skip_ignorable()
  print("inside tag: " .. to_string(self.stream:peek()))
  -- self.tagref = nil
  --
  -- -- 2. Handle the first key if it was passed from block_node
  -- if first_key_token then
  --   self:push(self.tokens, first_key_token)
  --
  --   local next_tok = self.stream:peek()
  --   if next_tok and next_tok.kind == "COLON" then
  --     self.stream:next() -- Consume ':'
  --
  --     local val = self:block_node(indent + 1)
  --     if val then
  --       self:push(self.tokens, val)
  --     else
  --       table.insert(self.tokens, { kind = "VAL", val = "" })
  --     end
  --   else
  --     return nil, self.lexer:error("Expected colon after implicit map key")
  --   end
  -- end
  --
  -- -- 3. Loop for subsequent entries in the map
  -- while true do
  --   self.stream:skip_ignorable()
  --
  --   -- Check indentation to see if map block ended
  --   if self.stream:check_indent(indent) == "LESS" then
  --     break
  --   end
  --
  --   local token = self.stream:peek()
  --   if not token or token.kind == "END_DOC" or token.kind == "START_DOC" then
  --     break
  --   end
  --
  --   -- === Handle Newlines explicitly ===
  --   -- This fixes the infinite loop where NL tokens sit in the stream
  --   if token.kind == "NL" then
  --     self.stream:next()
  --
  --   -- === Parse KEY ===
  --   elseif token.kind == "COMPLEX" then
  --     self.stream:next() -- Consume '?'
  --     local key_node = self:block_node(indent + 1)
  --     self:push(self.tokens, key_node)
  --     self:parse_map_value(indent)
  --   elseif self.stream:is_scalar() then
  --     if self.stream:is_followed_by("COLON") then
  --       local key_node = self:parse_scalar_token(indent)
  --       self:push(self.tokens, key_node)
  --       self:parse_map_value(indent)
  --     else
  --       return nil, self.lexer:error("Implicit map key must be followed by a colon", token)
  --     end
  --   else
  --     return nil, self.lexer:error("Unexpected token in map: " .. token.kind, token)
  --   end
  -- end

  table.insert(self.tokens, { kind = "-MAP" })
  return self.tokens
end

-- Helper to reduce code duplication in map
function Parser:parse_map_value(indent)
  local next_tok = self.stream:peek()
  if next_tok and next_tok.kind == "COLON" then
    self.stream:next() -- Consume ':'
    local val_node = self:block_node(indent + 1)
    if val_node then
      self:push(self.tokens, val_node)
    else
      table.insert(self.tokens, { kind = "VAL", val = "" })
    end
  else
    table.insert(self.tokens, { kind = "VAL", val = "" })
  end
end

function Parser:bare(indent)
  -- local childs = {}
  -- local token = self.lexer:peek()
  -- while token do
  --   if token.kind == "SEP" then
  --     local next = self.lexer:next()
  --     -- assert(#next.val == indent)
  --   elseif token.kind == "START_DOC" then
  --     break
  --   elseif token.kind == "END_DOC" then
  --     break
  --   elseif token.kind == "..." then
  --     break
  --   elseif token.kind == "NL" then
  --     self.lexer:next()
  --   else
  --     local child, mes = self:block_node(indent, false)
  --     if child then
  --       self:push(childs, child)
  --     else
  --       return nil, mes
  --     end
  --     -- skip empty lines
  --     while token and token.kind == "NL" do
  --       token = self.lexer:next()
  --     end
  --   end
  --   token = self.lexer:peek()
  -- end
  -- if #childs == 0 then
  --   self:push(self.tokens, { { kind = "VAL", indent = 0, val = "" } })
  -- else
  --   self:push(self.tokens, childs)
  -- end
  -- return 1
end

function Parser:directive()
  -- local token = self.lexer:peek()
  -- while token do
  --   if token.type == "GLOBAL_TAG" then
  --     self.primary_tag = self.lexer:next().val
  --   elseif token.type == "NAMED_TAG" then
  --     token = self.lexer:next()
  --     self.named_tags[token.name] = token.val
  --   elseif token.type == "SECOND_TAG" then
  --     token = self.lexer:next()
  --     self.second_tag = token.val
  --   elseif token.kind == "DIRECTIVE" then
  --     self.lexer:next()
  --     token = self.lexer:peek()
  --     if token.kind == "VAL" then
  --       token = self.lexer:peek()
  --       if token.kind == "NL" then
  --         self.lexer:next()
  --         break
  --       else
  --         error("unknown directive token: " .. self.lexer:peek().kind)
  --       end
  --     else
  --       error("unknown start directive token: " .. self.lexer:peek().kind)
  --     end
  --   else
  --     break
  --   end
  --   token = self.lexer:peek()
  -- end
end

function Parser:parse()
  table.insert(self.tokens, { kind = "+STR" })

  while true do
    self.stream:skip_ignorable()
    -- eof?
    if not self.stream:peek() then
      break
    end

    local has_directives = false
    if self.stream:peek().kind == "DIRECTIVE" then
      has_directives = true
      self:consume_directives()
    end

    -- 4. Handle Document Separator (---)
    local explicit_start = false
    if self.stream:accept("START_DOC") then
      explicit_start = true
    elseif has_directives then
      -- If directives exist, '---' is mandatory in YAML.
      -- You can choose to error here or be permissive.
      return nil, self.lexer:error("Missing '---' after directives")
    end

    table.insert(self.tokens, { kind = "+DOC" .. (explicit_start and " ---" or "") })

    -- 6. Parse the Root Node
    -- The root node is essentially a block node at indent 0.
    -- We check if we are hitting a document end or EOF before trying to parse content.
    local next_k = self.stream:peek() and self.stream:peek().kind
    if next_k and next_k ~= "END_DOC" and next_k ~= "START_DOC" then
      -- *** Entry point to the logic structure ***
      -- We pass 0 (or -1 depending on preference) as the indent.
      local root, err = self:block_node(0)

      if not root and err then
        return nil, err
      elseif root then
        self:push(self.tokens, root)
      end
    end

    -- TODO: 7. Handle Document End (...)
    local explicit_end = false
    if self.stream:accept("END_DOC") then
      explicit_end = true
      table.insert(self.tokens, { kind = "-DOC ..." })
    else
      table.insert(self.tokens, { kind = "-DOC" })
    end

    -- 8. Reset Context for the next document
    self.primary_tag = nil
    self.named_tags = {}
    self.tagref = nil
    self.anchor = {}
  end

  table.insert(self.tokens, { kind = "-STR" })
  return true
end

function Parser:__tostring()
  local res = {}
  for _, t in ipairs(self.tokens) do
    if t.kind == "VAL" then
      table.insert(
        res,
        string.format(
          "=%s %s%s%s%s",
          t.kind,
          (t.anchor and "&" .. t.anchor.val .. " " or ""),
          (t.tag and t.tag.val .. " " or ""),
          (t.type and t.type or ":"),
          escape(self:value((t.val or "")))
        )
      )
    elseif t.kind == "ALIAS" then
      table.insert(res, string.format("=ALI *%s", t.val))
    else
      table.insert(
        res,
        string.format("%s%s%s", t.kind, (t.tag and " " .. t.tag.val or ""), (t.anchor and " &" .. t.anchor.val or ""))
      )
    end
  end
  table.insert(res, "")
  return table.concat(res, "\n")
end

--- crewate the object

function Parser:next()
  self.index = self.index + 1
  if self.index > #self.tokens then
    return nil
  else
    return self.tokens[self.index]
  end
end

function Parser:decode_map()
  local next = self:next()
  local res = {}
  local key
  while next do
    if next.kind == "VAL" then
      if not key then
        key = self:scalar_type(self:value(next.val))
      else
        res[key] = self:scalar_type(self:value(next.val))
        key = nil
      end
    elseif next.kind == "-MAP" then
      break
    elseif string.match(next.kind, "^+MAP") then
      local val = self:decode_map()
      if not key then
        key = val
      else
        res[key] = val
        key = nil
      end
    elseif string.match(next.kind, "^+SEQ") then
      local val = self:decode_seq()
      if not key then
        key = val
      else
        res[key] = val
        key = nil
      end
    end
    next = self:next()
  end
  return res
end

function Parser:decode_seq()
  local next = self:next()
  local res = {}
  while next do
    if next.kind == "VAL" then
      table.insert(res, self:scalar_type(self:value(next.val)))
    elseif next.kind == "-SEQ" then
      break
    elseif string.match(next.kind, "^+SEQ") then
      table.insert(res, self:decode_seq())
    elseif string.match(next.kind, "^+MAP") then
      table.insert(res, self:decode_map())
    end
    next = self:next()
  end
  return res
end

function Parser:decode()
  local res
  local next = self:next()
  while next do
    if string.match(next.kind, "^+SEQ") then
      res = self:decode_seq()
    elseif string.match(next.kind, "^+MAP") then
      res = self:decode_map()
    end
    next = self:next()
  end
  return res
end

local path = "test.yaml"
local file = io.open(path, "r")
if not file then
  return nil, "can not open file " .. path
end
local content = file:read("*all")
file:close()
local lexer = Lexer:new(content)
lexer:lexme()
local parser = Parser:new(lexer)
local res, mes = parser:parse()
if not res then
  print("Error: " .. to_string(mes))
else
  log("Result:" .. tostring(parser))
end

-- local content = "foo: bar\n"
--
-- local lexer = Lexer:new(content)
-- print(to_string(lexer))
-- local mes = lexer:lexme()
-- if mes then
--   return nil, mes
-- end
-- local parser = Parser:new(lexer)
-- local res, mes = parser:parse()
-- print("RES: " .. res(" ") .. mes)

-- return {
--   html = function(content)
--     local lexer = Lexer:new(content)
--     local mes = lexer:lexme()
--     if mes then
--       return nil, mes
--     end
--     -- log(to_string(lexer.tokens))
--     return lexer:html()
--   end,
--   dump = function(content)
--     local lexer = Lexer:new(content)
--     local mes = lexer:lexme()
--     log(to_string(lexer.tokens))
--     if mes then
--       return nil, mes
--     end
--     local parser = Parser:new(lexer)
--     local res, mes = parser:parse()
--     if not res then
--       return res, mes
--     end
--     return tostring(parser)
--   end,
--   decode = function(content)
--     local lexer = Lexer:new(content)
--     local mes = lexer:lexme()
--     if mes then
--       return nil, mes
--     end
--     local parser = Parser:new(lexer)
--     local res, mes = parser:parse()
--     if not res then
--       return res, mes
--     end
--     return parser:decode()
--   end,
--   parse = function(path)
--     local file = io.open(path, "r")
--     if not file then
--       return nil, "can not open file " .. path
--     end
--     local content = file:read("*all")
--     file:close()
--     local lexer = Lexer:new(content)
--     lexer:lexme()
--     local parser = Parser:new(lexer)
--     local res, mes = parser:parse()
--     if not res then
--       return res, mes
--     end
--     return parser:decode()
--   end,
-- }
