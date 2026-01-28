-- local M = {}

local null = {}

local null_mt = {
  __tostring = function()
    return "null"
  end,
  __newindex = function()
    error("Attempt to modify yalua.null")
  end,
  __metatable = false,
}

setmetatable(null, null_mt)

-- M.null = null_sentinel

local trim = function(s, spaces_only)
  if spaces_only then
    return (s:gsub("^[\t ]*(.-)[\t ]*$", "%1"))
  else
    return (s:gsub("^%s*(.-)%s*$", "%1"))
  end
end

local split_lines = function(input)
  if not input then
    return {}
  end
  local result = {}
  local index, last = 1, 1
  while index <= #input do
    local c = input:sub(index, index)
    if c == "\r" or c == "\n" then
      table.insert(result, input:sub(last, index - 1))
      if index + 1 <= #input and c == "\r" and input:sub(index + 1, index + 1) == "\n" then
        index = index + 1
      end
      last = index + 1
    end
    index = index + 1
  end
  if last <= index then
    table.insert(result, input:sub(last))
  end
  return result
end

-----------------------------------------------------------------------------
---                       lexer for the input string                     ---
-----------------------------------------------------------------------------

local Lexer = {}
Lexer.__index = Lexer

-- Helper to convert unicode codepoint to utf-8 string
local function codepoint_to_utf8(cp)
  if cp < 128 then
    return string.char(cp)
  end
  local suffix = cp % 64
  local c4 = 128 + suffix
  cp = (cp - suffix) / 64
  if cp < 32 then
    return string.char(192 + cp, c4)
  end
  suffix = cp % 64
  local c3 = 128 + suffix
  cp = (cp - suffix) / 64
  if cp < 16 then
    return string.char(224 + cp, c3, c4)
  end
  suffix = cp % 64
  return string.char(240 + (cp - suffix) / 64, 128 + suffix, c3, c4)
end

---@alias TokenType
---| "EOF"         # End of file
---| "NEWLINE"     # Line break
---| "DOC_START"   # Document start marker (---)
---| "DOC_END"     # Document end marker (...)
---| "DIRECTIVE"   # YAML directive (e.g., %YAML 1.2)
---| "TEXT"        # Plain scalar text
---| "D_QUOTE"     # Double quoted scalar
---| "S_QUOTE"     # Single quoted scalar
---| "TAG"         # Tag (e.g., !!map, !local)
---| "ANCHOR"      # Node anchor (&name)
---| "ALIAS"       # Node alias (*name)
---| "COMMA"       # Flow sequence delimiter (,)
---| "COLON"       # Mapping key/value separator (:)
---| "QUESTION"    # Explicit mapping key (?)
---| "DASH"        # Sequence entry (-)
---| "PIPE"        # Literal block scalar (|)
---| "GT"          # Folded block scalar (>)
---| "L_BRACKET"   # Flow sequence start ([)
---| "R_BRACKET"   # Flow sequence end (])
---| "L_BRACE"     # Flow mapping start ({)
---| "R_BRACE"     # Flow mapping end (})

---@class Token
---@field kind TokenType The type of the token
---@field row integer The line number (1-based) where the token starts
---@field col integer The physical column or indentation level (0-based)
---@field value? string The string content (present for scalars, tags, anchors, directives)
---@field indent? integer The structural indentation level (present on most content tokens)
---@field has_comment? boolean Specific to NEWLINE: true if a comment was stripped on this line
---@field adjacent? boolean Specific to COLON: true if the colon is immediately adjacent to the previous token
---@field spaced? boolean Specific to COLON: true if the colon is followed by whitespace

---@class Lexer
---@field index integer
---@field str string
---@field col integer
---@field row integer
---@field tokens Token
---@field last_scanned_token_end integer
function Lexer:new(str)
  local o = {
    str = str,
    len = #str,
    index = 1,
    line = 1,
    line_start = 1,
    -- The Token Buffer for lookahead
    token_queue = {},
    last_scanned_token = nil,
    -- Track where the last significant token ended to detect adjacency
    last_scanned_token_end = 1,
    flow_level = 0,
  }
  setmetatable(o, self)
  return o
end

---Check if current char matches a byte
function Lexer:at(char)
  if self.index > self.len then
    return false
  end
  return string.byte(self.str, self.index) == string.byte(char)
end

function Lexer:advance(n)
  n = n or 1
  for _ = 1, n do
    if self:at("\n") then
      self.line = self.line + 1
      self.line_start = self.index + 1
    end
    self.index = self.index + 1
  end
end

---Check if the lexer has reached the end of the input string.
---@return boolean True if the lexer is at or past the end of the string, false
function Lexer:is_eof()
  return self.index > self.len
end

---Check if the current character is a separator (space, newline, tab, or EOF).
---@param offset integer? The offset from the current index to check.
---@return boolean True if the character is a separator, false otherwise.
function Lexer:is_separator(offset)
  offset = offset or 0
  local c = self:peek_char(offset)
  return c == " " or c == "\n" or c == "\t" or c == nil
end

---Peek the next character(s) in the iterator.
---@param n integer? The number of characters to peek, default is 1.
---@return string|nil The character(s) or nil if end of file (eof) is reached.
function Lexer:peek_char(n)
  n = n or 0
  if self.index + n > #self.str then
    return nil
  end
  return string.sub(self.str, self.index + n, self.index + n)
end

---Consumes the next n characters from the iterator.
---@param count integer The number of characters to consume.
---@return string The consumed characters.
function Lexer:consume(count)
  if self.index + count - 1 > #self.str then
    error("string index out of bounds")
  end
  local result = string.sub(self.str, self.index, self.index + count - 1)
  self.index = self.index + count
  return result
end

---Test is the document matches a string at position
---@param index integer The index to match the pattern at.
---@param pattern string The pattern to match against.
---@return boolean
function Lexer:match(index, pattern)
  for i = 1, #pattern do
    local current_pos = self.index + index + i - 1
    if string.sub(self.str, current_pos, current_pos) ~= string.sub(pattern, i, i) then
      return false
    end
  end
  return true
end

---Calculates the physical column of the current index (0-indexed)
function Lexer:current_col()
  return self.index - self.line_start
end

---Calculates the structural indentation of the current line (spaces only)
function Lexer:get_line_indent()
  local indent = 0
  local i = self.line_start
  -- Scan from start of line
  while i < self.index and i <= #self.str do
    local c = string.sub(self.str, i, i)
    if c == " " then
      indent = indent + 1
    else
      -- Tabs or other characters stop the indentation count
      break
    end
    i = i + 1
  end
  return indent
end

---Returns the next token and advances.
---@return Token
function Lexer:next()
  if #self.token_queue > 0 then
    return table.remove(self.token_queue, 1)
  end
  return self:scan_token()
end

---Look ahead at the Nth token without consuming.
---@param n integer
---@return Token
function Lexer:peek(n)
  n = n or 1
  while #self.token_queue < n do
    local t = self:scan_token()
    table.insert(self.token_queue, t)
    if t.kind == "EOF" then
      break
    end
  end

  if n > #self.token_queue then
    return self.token_queue[#self.token_queue]
  end
  return self.token_queue[n]
end

---Reads the whole line as a literal value.
function Lexer:scan_literal_line()
  if self:at("\n") then
    self:advance()
  end

  local indent = 0
  while self:at(" ") do
    indent = indent + 1
    self:advance()
  end

  if self:is_eof() or self:at("\n") then
    return {
      kind = "TEXT",
      value = "",
      indent = indent,
      row = self.line,
      col = self:get_line_indent(),
    }
  end

  local start = self.index
  while not self:is_eof() and not self:at("\n") do
    self:advance()
  end

  local text = string.sub(self.str, start, self.index - 1)

  return {
    kind = "TEXT",
    value = text,
    indent = indent,
    row = self.line,
    col = indent,
  }
end

---Calculates the indentation of the line containing the current index
-- Identical to get_line_indent but kept for API compatibility if needed
function Lexer:get_start_line_indent()
  return self:get_line_indent()
end

---Scans a double quoted string, handling escapes and line folding rules
function Lexer:scan_double_quoted()
  local row = self.line
  -- Use get_line_indent for the start column to ensure tabs don't skew it
  local col = self:get_line_indent()

  -- Calculate indentation of the line where this scalar started.
  local start_line_indent = self:get_start_line_indent()

  -- Check if the scalar is the first token on the line (ignoring whitespace).
  local prefix = string.sub(self.str, self.line_start, self.index - 1)
  local is_multi_line_start = not prefix:match("%S")

  if not is_multi_line_start then
    if prefix:match("^%s*---%s*$") or prefix:match("^%s*%.%.%.%s*$") then
      is_multi_line_start = true
    end
  end

  self:advance() -- consume "

  local content = ""
  local closed = false

  while true do
    if self:is_eof() then
      break
    end
    local c = self:peek_char()

    if c == '"' then
      self:advance()
      closed = true
      break
    elseif c == "\\" then
      self:advance() -- Consume the backslash
      local next_c = self:peek_char()

      -- Handle Escaped Newline (Continuation)
      if next_c == "\n" then
        self:advance() -- consume newline
        -- consume leading whitespace on the continuation line
        while self:peek_char() == " " or self:peek_char() == "\t" do
          self:advance()
        end
      -- Handle Hex Escapes
      elseif next_c == "x" then
        self:advance() -- consume 'x'
        local hex = self:consume(2)
        content = content .. string.char(tonumber(hex, 16))
      -- Handle Unicode 4-digit
      elseif next_c == "u" then
        self:advance() -- consume 'u'
        local hex = self:consume(4)
        content = content .. codepoint_to_utf8(tonumber(hex, 16))
      -- Handle Unicode 8-digit
      elseif next_c == "U" then
        self:advance() -- consume 'U'
        local hex = self:consume(8)
        content = content .. codepoint_to_utf8(tonumber(hex, 16))
      else
        local escape_map = {
          ["0"] = "\0",
          ["a"] = "\7",
          ["b"] = "\8",
          ["t"] = "\t",
          ["n"] = "\n",
          ["v"] = "\11",
          ["f"] = "\12",
          ["r"] = "\r",
          ["e"] = "\27",
          ['"'] = '"',
          ["\\"] = "\\",
          ["/"] = "/",
          [" "] = " ",
          ["\t"] = "\t",
          ["_"] = "\160", -- NBSP
          ["N"] = "\133", -- NEL
          ["L"] = "\226\128\168", -- LS
          ["P"] = "\226\128\169", -- PS
        }
        local val = escape_map[next_c]
        if not val then
          error(
            string.format("ERROR:%d:%d Invalid escape sequence '\\%s'", self.line, self:current_col(), next_c or "EOF")
          )
        end
        content = content .. val
        self:advance()
      end
    elseif c == "\n" then
      local spaces_to_remove = 0
      local idx = self.index - 1
      while idx >= 1 do
        local char = string.sub(self.str, idx, idx)
        if char == " " or char == "\t" then
          local bs_count = 0
          local bs_idx = idx - 1
          while bs_idx >= 1 and string.sub(self.str, bs_idx, bs_idx) == "\\" do
            bs_count = bs_count + 1
            bs_idx = bs_idx - 1
          end

          if bs_count % 2 == 1 then
            break -- It is escaped, count as content
          end
          spaces_to_remove = spaces_to_remove + 1
          idx = idx - 1
        else
          break
        end
      end

      if spaces_to_remove > 0 then
        content = string.sub(content, 1, #content - spaces_to_remove)
      end

      local newline_count = 0
      while true do
        newline_count = newline_count + 1
        self:advance()

        if self:get_line_indent() == 0 then
          if (self:match(0, "---") and self:is_separator(3)) or (self:match(0, "...") and self:is_separator(3)) then
            error(string.format("ERROR:%d:%d invalid document-start marker in double-quoted scalar", self.line, 1))
          end
        end

        while self:peek_char() == " " or self:peek_char() == "\t" do
          self:advance()
        end
        if self:peek_char() ~= "\n" then
          if self.flow_level == 0 then
            local current_indent = self:get_line_indent()
            if is_multi_line_start then
              if current_indent < start_line_indent then
                error(string.format("ERROR:%d:%d wrongly indented double-quoted scalar", self.line, current_indent))
              end
            else
              if current_indent <= start_line_indent then
                error(string.format("ERROR:%d:%d wrongly indented double-quoted scalar", self.line, current_indent))
              end
            end
          end
          break
        end
      end
      if newline_count == 1 then
        content = content .. " "
      else
        content = content .. string.rep("\n", newline_count - 1)
      end
    else
      content = content .. c
      self:advance()
    end
  end

  if not closed then
    error(string.format("ERROR:%d:%d double-quoted scalar without closing quote", row, col))
  end

  return { kind = "D_QUOTE", value = content, row = row, col = col, indent = col }
end

---Scans a single quoted string
function Lexer:scan_single_quoted()
  local row = self.line
  local col = self:get_line_indent()

  local start_line_indent = self:get_start_line_indent()

  local prefix = string.sub(self.str, self.line_start, self.index - 1)
  local is_multi_line_start = not prefix:match("%S")

  if not is_multi_line_start then
    if prefix:match("^%s*---%s*$") or prefix:match("^%s*%.%.%.%s*$") then
      is_multi_line_start = true
    end
  end

  self:advance() -- consume '

  local content = ""
  local closed = false

  while true do
    if self:is_eof() then
      break
    end
    local c = self:peek_char()

    if c == "'" then
      if self:peek_char(1) == "'" then
        content = content .. "'"
        self:advance(2) -- consume ''
      else
        self:advance() -- consume '
        closed = true
        break
      end
    elseif c == "\n" then
      content = content:gsub("[ \t]+$", "")
      local newline_count = 0
      while true do
        newline_count = newline_count + 1
        self:advance()

        if self:get_line_indent() == 0 then
          if (self:match(0, "---") and self:is_separator(3)) or (self:match(0, "...") and self:is_separator(3)) then
            error(string.format("ERROR:%d:%d invalid document-start marker in single-quoted scalar", self.line, 1))
          end
        end

        while self:peek_char() == " " or self:peek_char() == "\t" do
          self:advance()
        end
        if self:peek_char() ~= "\n" then
          if self.flow_level == 0 then
            local current_indent = self:get_line_indent()
            if is_multi_line_start then
              if current_indent < start_line_indent then
                error(string.format("ERROR:%d:%d wrongly indented single-quoted scalar", self.line, current_indent))
              end
            else
              if current_indent <= start_line_indent then
                error(string.format("ERROR:%d:%d wrongly indented single-quoted scalar", self.line, current_indent))
              end
            end
          end
          break
        end
      end
      if newline_count == 1 then
        content = content .. " "
      else
        content = content .. string.rep("\n", newline_count - 1)
      end
    else
      content = content .. c
      self:advance()
    end
  end

  if not closed then
    error(string.format("ERROR:%d:%d single-quoted scalar without closing quote", row, col))
  end

  return { kind = "S_QUOTE", value = content, row = row, col = col, indent = col }
end

---Scans a tag (e.g. !!map, !local, !<tag:uri>)
function Lexer:scan_tag()
  local start = self.index
  local row = self.line
  -- Note: scan_tag assumes caller has set up the position.
  -- But we need correct column. scan_token_impl will patch this.
  -- We just use physical col here, expecting override if needed.
  local col = self:current_col()

  self:advance()

  if self:peek_char() == "<" then
    self:advance() -- consume <
    while not self:is_eof() do
      local c = self:peek_char()
      if c == ">" then
        self:advance()
        break
      end
      self:advance()
    end
  else
    while not self:is_eof() do
      if self:is_separator() then
        break
      end
      if self:at(",") or self:at("[") or self:at("]") or self:at("{") or self:at("}") then
        break
      end
      self:advance()
    end
  end

  local val = string.sub(self.str, start, self.index - 1)
  return { kind = "TAG", value = val, row = row, col = col, indent = col }
end

---Scans an anchor (&name) or alias (*name)
function Lexer:scan_anchor_alias(kind)
  local start = self.index
  local row = self.line
  local col = self:current_col()

  self:advance()

  while not self:is_eof() do
    if self:is_separator() then
      break
    end
    if self:at(",") or self:at("[") or self:at("]") or self:at("{") or self:at("}") then
      break
    end
    self:advance()
  end

  local val = string.sub(self.str, start + 1, self.index - 1)
  return { kind = kind, value = val, row = row, col = col, indent = col }
end

function Lexer:scan_token()
  local t = self:scan_token_impl()
  if t.kind ~= "NEWLINE" then
    self.last_scanned_token = t
    self.last_scanned_token_end = self.index
  end
  return t
end

function Lexer:scan_token_impl()
  local has_comment = false

  while true do
    while self:at(" ") do
      self:advance()
    end

    if self:at("\t") then
      local prefix = string.sub(self.str, self.line_start, self.index - 1)

      if self.flow_level == 0 then
        if prefix:match("^[%s%-?:]*$") then
          local lookahead_idx = 0
          local is_block_struct = false
          while true do
            local c = self:peek_char(lookahead_idx)
            if c == "\t" or c == " " then
              lookahead_idx = lookahead_idx + 1
            else
              if c == nil or c == "\n" or c == "#" then
                is_block_struct = false
              else
                local next_c = self:peek_char(lookahead_idx + 1)
                local is_sep = (next_c == " " or next_c == "\n" or next_c == "\t" or next_c == nil)

                local is_seq = (c == "-" and is_sep)
                local is_map_key = (c == "?" and is_sep)
                local is_map_val = (c == ":" and is_sep)

                if is_seq or is_map_key or is_map_val then
                  is_block_struct = true
                else
                  -- Check for Implicit Mapping Key
                  local scan_pos = lookahead_idx
                  while true do
                    local sc = self:peek_char(scan_pos)
                    if sc == nil or sc == "\n" or sc == "#" then
                      break
                    end
                    if sc == ":" then
                      local after_colon = self:peek_char(scan_pos + 1)
                      if after_colon == " " or after_colon == "\n" or after_colon == "\t" or after_colon == nil then
                        is_block_struct = true
                      end
                      break
                    end
                    scan_pos = scan_pos + 1
                  end
                end
              end
              break
            end
          end

          if is_block_struct then
            local row = self.line
            local col = self:current_col()
            error(string.format("ERROR:%d:%d Tabs are not allowed for indentation", row, col))
          end
        end
      end
      self:advance()
    elseif self:at("#") then
      local prev = string.sub(self.str, self.index - 1, self.index - 1)
      local is_comment = (self.index == self.line_start) or (prev == " ") or (prev == "\t")

      if is_comment then
        has_comment = true
        while not self:at("\n") and not self:is_eof() do
          self:advance()
        end
      else
        break
      end
    else
      break
    end
  end

  -- Determine the effective column for indentation logic.
  -- If we are effectively at the start of the line (only preceded by whitespace),
  -- we use structural indentation (spaces only).
  -- Otherwise, we use physical column.
  local effective_col
  local prefix_all_whitespace = string.sub(self.str, self.line_start, self.index - 1):match("^%s*$")
  if prefix_all_whitespace then
    effective_col = self:get_line_indent()
  else
    effective_col = self:current_col()
  end

  local row = self.line

  if self:is_eof() then
    return { kind = "EOF", row = row, col = effective_col }
  end

  if self:at("\n") then
    self:advance()
    return { kind = "NEWLINE", row = row, col = effective_col, has_comment = has_comment }
  end

  if self:match(0, "---") and self:is_separator(3) then
    self:advance(3)
    return { kind = "DOC_START", row = row, col = effective_col, indent = effective_col }
  end

  if self:match(0, "...") and self:is_separator(3) then
    self:advance(3)
    return { kind = "DOC_END", row = row, col = effective_col, indent = effective_col }
  end

  local c = self:peek_char()

  if c == "%" and effective_col == 0 then
    -- Check if it is a valid directive syntax (not followed by space)
    local next_char = self:peek_char(1)
    local is_directive_syntax = next_char and not (next_char == " " or next_char == "\n" or next_char == "\t")

    if is_directive_syntax then
      local start = self.index
      while not self:at("\n") and not self:is_eof() do
        self:advance()
      end

      local raw_val = string.sub(self.str, start, self.index - 1)
      local clean_val = raw_val:gsub("%s+#.*", "")
      clean_val = clean_val:gsub("%s+$", "")
      return { kind = "DIRECTIVE", value = clean_val, row = row, col = 0, indent = 0 }
    end
    -- If followed by space, fall through to treat as scalar
  end

  -- For all dispatched tokens, we set the col afterwards to ensure consistency
  local token = nil

  if c == "?" then
    if self:is_separator(1) then
      self:advance()
      token = { kind = "QUESTION", row = row, col = effective_col, indent = effective_col }
    end
  elseif c == "&" then
    token = self:scan_anchor_alias("ANCHOR")
  elseif c == "*" then
    token = self:scan_anchor_alias("ALIAS")
  elseif c == "!" then
    token = self:scan_tag()
  elseif c == "[" then
    self:advance()
    self.flow_level = self.flow_level + 1
    token = { kind = "L_BRACKET", row = row, col = effective_col, indent = effective_col }
  elseif c == "]" then
    self:advance()
    self.flow_level = self.flow_level - 1
    token = { kind = "R_BRACKET", row = row, col = effective_col, indent = effective_col }
  elseif c == "{" then
    self:advance()
    self.flow_level = self.flow_level + 1
    token = { kind = "L_BRACE", row = row, col = effective_col, indent = effective_col }
  elseif c == "}" then
    self:advance()
    self.flow_level = self.flow_level - 1
    token = { kind = "R_BRACE", row = row, col = effective_col, indent = effective_col }
  elseif c == "," then
    self:advance()
    token = { kind = "COMMA", row = row, col = effective_col, indent = effective_col }
  elseif c == ":" then
    local next_c = self:peek_char(1)
    local is_flow_indicator = (next_c == "," or next_c == "]" or next_c == "}")
    local is_sep = (self:is_separator(1) or (self.flow_level > 0 and is_flow_indicator))
    local prev_kind = self.last_scanned_token and self.last_scanned_token.kind
    local is_flow_scalar = (
      prev_kind == "D_QUOTE"
      or prev_kind == "S_QUOTE"
      or prev_kind == "R_BRACKET"
      or prev_kind == "R_BRACE"
    )
    local is_adjacent = (self.index == self.last_scanned_token_end)

    if is_sep or is_flow_scalar then
      self:advance()
      token = {
        kind = "COLON",
        row = row,
        col = effective_col,
        indent = effective_col,
        adjacent = is_adjacent,
        spaced = is_sep,
      }
    end
  elseif c == "-" then
    if self:is_separator(1) then
      self:advance()
      token = { kind = "DASH", row = row, col = effective_col, indent = effective_col }
    end
  elseif c == "|" then
    self:advance()
    token = { kind = "PIPE", row = row, col = effective_col, indent = effective_col }
  elseif c == ">" then
    self:advance()
    token = { kind = "GT", row = row, col = effective_col, indent = effective_col }
  elseif c == "#" then
    error(string.format("ERROR:%d:%d Invalid character '#' at start of plain scalar", row, effective_col))
  elseif c == '"' then
    token = self:scan_double_quoted()
  elseif c == "'" then
    token = self:scan_single_quoted()
  end

  if not token then
    -- Plain Scalar check
    if self.flow_level > 0 then
      local nc = self:peek_char(1)
      if c == "-" or c == "?" then
        if nc == "," or nc == "]" or nc == "}" or nc == "[" or nc == "{" then
          error(
            string.format(
              "ERROR:%d:%d plain scalar cannot start with '%s' followed by '%s' in flow context",
              row,
              effective_col,
              c,
              nc
            )
          )
        end
      elseif c == ":" then
        if nc == "[" or nc == "{" then
          error(
            string.format(
              "ERROR:%d:%d plain scalar cannot start with '%s' followed by '%s' in flow context",
              row,
              effective_col,
              c,
              nc
            )
          )
        end
      end
    end

    local start = self.index
    while not self:is_eof() do
      if self:at("\n") then
        break
      end
      if self:at(":") then
        local next_c = self:peek_char(1)
        local is_flow_indicator = (next_c == "," or next_c == "]" or next_c == "}")
        if self:is_separator(1) or (self.flow_level > 0 and (is_flow_indicator or next_c == "[" or next_c == "{")) then
          break
        end
      end
      if self.flow_level > 0 then
        if self:at(",") or self:at("]") or self:at("}") or self:at("[") or self:at("{") then
          break
        end
      end
      if self:at("#") then
        local prev = string.sub(self.str, self.index - 1, self.index - 1)
        if prev == " " or prev == "\t" then
          break
        end
      end
      self:advance()
    end
    local val = string.sub(self.str, start, self.index - 1)
    token = { kind = "TEXT", value = val, row = row, col = effective_col, indent = effective_col }
  end

  -- Override token column with the correctly calculated effective column
  if token then
    token.col = effective_col
    if token.indent then
      token.indent = effective_col
    end
  end
  return token
end

-----------------------------------------------------------------------------
---                             the yaml parser                           ---
-----------------------------------------------------------------------------

local Parser = {}
Parser.__index = Parser

function Parser:new(lexer)
  local o = {}
  setmetatable(o, self)
  o.lexer = lexer
  o.tokens = {}
  return o
end

---Generate a formatted error with context and halt execution
function Parser:error(msg, token)
  token = token or self.tokens[#self.tokens] or { row = self.lexer.line, col = self.lexer.col }

  -- Fetch the specific line content for context
  local lines = split_lines(self.lexer.str)
  local line_content = lines[token.row] or ""

  -- Create the pointer line (e.g. "  ^")
  local pointer = string.rep(" ", token.col) .. "^"

  -- Format: ERROR:Row:Col Message \n Line \n Pointer
  local message = string.format("ERROR:%d:%d %s\n%s\n%s", token.row, token.col, msg, line_content, pointer)

  error(message, 0)
end

---Consumes all consecutive NEWLINE tokens
function Parser:skip_newlines()
  while self.lexer:peek().kind == "NEWLINE" do
    self.lexer:next()
  end
end

---Helper to consume flow text that might span lines
function Parser:consume_flow_text(first_token)
  local val = first_token.value
  while true do
    local next_t = self.lexer:peek()
    if next_t.kind == "NEWLINE" then
      -- Check indentation of the next line
      local nl_count = 0
      local idx = 1
      local has_comment = false

      while self.lexer:peek(idx).kind == "NEWLINE" do
        if self.lexer:peek(idx).has_comment then
          has_comment = true
        end
        nl_count = nl_count + 1
        idx = idx + 1
      end

      local after_nl = self.lexer:peek(idx)

      -- Only continue if the next token is TEXT (part of the same scalar)
      -- AND we didn't see a comment
      if not has_comment and after_nl.kind == "TEXT" then
        -- Consume all the newlines
        for _ = 1, nl_count do
          self.lexer:next()
        end

        -- Apply Flow Folding Rules
        if nl_count == 1 then
          val = val .. " "
        else
          val = val .. string.rep("\n", nl_count - 1)
        end

        val = val .. after_nl.value
        self.lexer:next()
      else
        break
      end
    elseif next_t.kind == "TEXT" then
      val = val .. " " .. next_t.value
      self.lexer:next()
    else
      break
    end
  end
  return trim(val)
end

---Expands tags using registered handles
function Parser:expand_tag(token)
  local tag = token.value
  if not tag then
    return nil
  end

  -- Verbatim tags !<...> don't use handles
  local verbatim = tag:match("^!%<(.*)%>$")
  if verbatim then
    return verbatim
  end

  -- Identify the handle
  local handle = tag:match("^(![^!]+!)")
  if not handle then
    if tag:sub(1, 2) == "!!" then
      handle = "!!"
    elseif tag:sub(1, 1) == "!" then
      handle = "!"
    end
  end

  -- Resolve handle if it exists in our map
  if handle then
    if self.tag_handles and self.tag_handles[handle] then
      local prefix = self.tag_handles[handle]
      local suffix = tag:sub(#handle + 1)
      suffix = suffix:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
      end)
      return prefix .. suffix
    else
      self:error("undefined tag handle", token)
    end
  end

  return tag
end

-- Accept min_indent to validate multiline properties
function Parser:parse_properties(min_indent, context_token)
  local tag = nil
  local anchor = nil
  local first_iter = true

  while true do
    local token = self.lexer:peek()
    local is_prop = (token.kind == "TAG" or token.kind == "ANCHOR")

    if not is_prop then
      break
    end

    -- Validate indentation of the first property to ensure it belongs to this node
    if first_iter and min_indent and min_indent >= 0 then
      -- Use context_token if provided (e.g., the colon or dash preceding these properties)
      -- Otherwise fallback to the last scanned token.
      local prev = context_token or self.lexer.last_scanned_token
      local is_same_line = (prev and prev.row == token.row)

      if not is_same_line and token.col < min_indent then
        return nil, nil
      end
    end
    first_iter = false

    if token.kind == "TAG" then
      if tag then
        break
      end
      tag = self:expand_tag(self.lexer:next())
    else
      if anchor then
        break
      end
      anchor = self.lexer:next().value
    end

    -- Look ahead for the next property
    local offset = 1
    local has_newline = false
    while self.lexer:peek(offset).kind == "NEWLINE" do
      has_newline = true
      offset = offset + 1
    end

    local next_tok = self.lexer:peek(offset)
    if next_tok.kind == "TAG" or next_tok.kind == "ANCHOR" then
      -- Validate indentation for properties on subsequent lines
      if has_newline and min_indent and min_indent >= 0 then
        if next_tok.col < min_indent then
          self:error("invalid tag indent for mapping", next_tok)
        end
      end

      -- Check if properties on the new line belong to a child node (e.g. map key)
      if has_newline then
        local scan_idx = offset
        local has_content
        local content_idx = 0
        while true do
          local t = self.lexer:peek(scan_idx)
          if t.kind == "TAG" or t.kind == "ANCHOR" then
            scan_idx = scan_idx + 1
          elseif t.kind == "NEWLINE" or t.kind == "EOF" then
            has_content = false
            break
          else
            -- Found something other than props/separators on the same line
            has_content = true
            content_idx = scan_idx
            break
          end
        end

        if has_content then
          local content_token = self.lexer:peek(content_idx)
          local next_t = self.lexer:peek(content_idx + 1)

          -- Check for structural indicators that imply the property belongs to a child
          local is_key = (next_t.kind == "COLON")
          local is_struct = (
            content_token.kind == "COLON"
            or content_token.kind == "QUESTION"
            or content_token.kind == "DASH"
          )

          if is_key or is_struct then
            break
          end
        end
      end

      self:skip_newlines()
    else
      break
    end
  end
  return tag, anchor
end

---Consumes consecutive tokens (TEXT, DASH, COLON) that represent a multiline scalar
function Parser:consume_plain_scalar(base_indent, first_chunk)
  -- Helper to fix values from tokens that lose prefixes or have special meaning
  local function get_token_val(tok)
    if tok.kind == "ANCHOR" then
      return "&" .. tok.value
    elseif tok.kind == "ALIAS" then
      return "*" .. tok.value
    elseif tok.kind == "TAG" then
      return tok.value
    elseif tok.kind == "DIRECTIVE" then
      return tok.value
    elseif tok.value then
      return tok.value
    end

    -- Map separator kinds back to text
    if tok.kind == "DASH" then
      return "-"
    end
    if tok.kind == "COLON" then
      return ":"
    end
    if tok.kind == "PIPE" then
      return "|"
    end
    if tok.kind == "GT" then
      return ">"
    end
    if tok.kind == "L_BRACKET" then
      return "["
    end
    if tok.kind == "R_BRACKET" then
      return "]"
    end
    if tok.kind == "L_BRACE" then
      return "{"
    end
    if tok.kind == "R_BRACE" then
      return "}"
    end
    if tok.kind == "COMMA" then
      return ","
    end
    if tok.kind == "QUESTION" then
      return "?"
    end
    return ""
  end

  -- Helper to determine token length in source (to detect gaps)
  local function get_token_len(tok)
    if tok.kind == "ANCHOR" or tok.kind == "ALIAS" then
      return #tok.value + 1
    elseif
      tok.kind == "TAG"
      or tok.kind == "TEXT"
      or tok.kind == "D_QUOTE"
      or tok.kind == "S_QUOTE"
      or tok.kind == "DIRECTIVE"
    then
      return #tok.value
    end
    return 1
  end

  local content = get_token_val(first_chunk)
  local prev_end = first_chunk.col + get_token_len(first_chunk)

  while true do
    local t_next = self.lexer:peek(1)

    if t_next.kind == "NEWLINE" then
      -- Strip trailing whitespace from the current line before folding.
      -- This fixes issues where trailing spaces are preserved + a fold space is added.
      content = content:gsub("[ \t]+$", "")

      -- Look ahead for multiple newlines (blank lines)
      local newline_count = 0
      local idx = 1
      local comment_break = false
      while self.lexer:peek(idx).kind == "NEWLINE" do
        -- Any comment encountered during newline lookahead breaks the plain scalar.
        if self.lexer:peek(idx).has_comment then
          comment_break = true
        end
        newline_count = newline_count + 1
        idx = idx + 1
      end

      local t_after = self.lexer:peek(idx)

      -- Check for tokens that terminate a scalar at the start of a new line
      local is_terminator = (
        t_after.kind == "EOF"
        or t_after.kind == "DOC_START"
        or t_after.kind == "DOC_END"
        or t_after.kind == "R_BRACKET"
        or t_after.kind == "R_BRACE"
      )

      local stop = false

      if comment_break then
        stop = true
      elseif is_terminator then
        stop = true
      elseif t_after.col < base_indent then
        stop = true
      elseif t_after.col == base_indent then
        -- If indentation is same, check for structure indicators.
        -- If we are at root (base_indent == 0), ambiguous structure indicators (like -) start a new node.
        local k = t_after.kind
        if base_indent == 0 then
          if k == "DASH" or k == "QUESTION" or k == "TAG" or k == "ANCHOR" or k == "L_BRACKET" or k == "L_BRACE" then
            stop = true
          end
        end

        -- Always check if text is followed by colon (key indicator)
        if not stop and (k == "TEXT" or k == "D_QUOTE" or k == "S_QUOTE") then
          local t_next_next = self.lexer:peek(idx + 1)
          if t_next_next.kind == "COLON" then
            stop = true
          end
        end
      end

      if not stop then
        -- Consume all consecutive newlines
        for _ = 1, newline_count do
          self.lexer:next()
        end

        -- YAML Plain Scalar Logic
        if newline_count == 1 then
          content = content .. " "
        else
          content = content .. string.rep("\n", newline_count - 1)
        end

        local first_token_on_line = true
        while true do
          local t = self.lexer:peek()
          if t.kind == "NEWLINE" or t.kind == "EOF" then
            break
          end

          if t.kind == "COLON" then
            break
          end

          local tok = self.lexer:next()
          local val = get_token_val(tok)

          if not first_token_on_line then
            if tok.col > prev_end then
              val = " " .. val
            end
          end

          prev_end = tok.col + get_token_len(tok)
          content = content .. val
          first_token_on_line = false
        end
      else
        break
      end
    else
      -- Case: Tokens on the same line (e.g. "key: value")
      local t = self.lexer:peek()

      if t.kind == "NEWLINE" or t.kind == "EOF" then
        break
      end

      if t.kind == "COLON" then
        break
      end

      local tok = self.lexer:next()
      local val = get_token_val(tok)

      if tok.col > prev_end then
        val = " " .. val
      end

      prev_end = tok.col + get_token_len(tok)
      content = content .. val
    end
  end

  return trim(content)
end

--- Consumes a Literal (|) or Folded (>) Block Scalar
function Parser:consume_block_scalar(min_indent, is_folded)
  self.lexer:next() -- Consume PIPE or GT

  -- parse header (Chomping/Indent)
  local chomping = "clip"
  local explicit_indent = nil
  local has_indent = false
  local has_chomp = false

  while true do
    local c = self.lexer:peek_char()
    if c == "-" or c == "+" then
      if has_chomp then
        self:error("Multiple chomping indicators", self.lexer:peek())
      end
      chomping = (c == "-") and "strip" or "keep"
      has_chomp = true
      self.lexer:advance()
    elseif c and c:match("%d") then
      if has_indent then
        self:error("Multiple indentation indicators", self.lexer:peek())
      end
      explicit_indent = tonumber(c)
      if explicit_indent == 0 then
        self:error("Indentation indicator cannot be 0", self.lexer:peek())
      end
      has_indent = true
      self.lexer:advance()
    else
      break
    end
  end

  -- Check for invalid characters in header before newline
  local has_space = false
  while true do
    local c = self.lexer:peek_char()
    if c == " " or c == "\t" then
      has_space = true
      self.lexer:advance()
    elseif c == "#" then
      if not has_space then
        self:error(
          "invalid comment without whitespace after block scalar indicator",
          { row = self.lexer.line, col = self.lexer:current_indent() }
        )
      end
      -- Comment, consume until newline
      while not self.lexer:at("\n") and not self.lexer:is_eof() do
        self.lexer:advance()
      end
      break
    elseif c == "\n" or c == nil then
      break
    else
      self:error("Invalid character in block scalar header: " .. tostring(c), self.lexer:peek())
    end
  end

  if self.lexer:at("\n") then
    self.lexer:advance()
  end

  -- Determine Block Indentation
  local block_indent = nil
  if explicit_indent and explicit_indent > 0 then
    block_indent = min_indent + explicit_indent - 1
    if block_indent < min_indent then
      block_indent = min_indent
    end
  end

  -- Helper to peek line details without consuming
  local function peek_line_info(offset_idx)
    local idx = offset_idx or 0
    local spaces = 0
    while true do
      local c = self.lexer:peek_char(idx)
      if c == " " then
        spaces = spaces + 1
        idx = idx + 1
      else
        -- Return: space_count, char_after_spaces, is_newline_or_eof, next_start_idx
        local is_eol = (c == "\n" or c == "\r" or c == nil)
        return spaces, c, is_eol, idx
      end
    end
  end

  -- Auto-detect indentation if needed and VALIDATE leading empty lines
  if block_indent == nil then
    local current_idx = 0
    local max_empty_spaces = 0
    local found_content = false
    local lines_skipped = 0
    local offending_lines_count = nil

    while true do
      local c = self.lexer:peek_char(current_idx)
      if c == nil then
        break
      end

      -- Basic check for document separator at line start
      local s1 = self.lexer:peek_char(current_idx)
      local s2 = self.lexer:peek_char(current_idx + 1)
      local s3 = self.lexer:peek_char(current_idx + 2)
      local s4 = self.lexer:peek_char(current_idx + 3)
      if (s1 == "-" and s2 == "-" and s3 == "-") or (s1 == "." and s2 == "." and s3 == ".") then
        if s4 == " " or s4 == "\n" or s4 == nil then
          break
        end
      end

      local spaces, _, is_eol, next_start_rel = peek_line_info(current_idx)

      if is_eol then
        if spaces > max_empty_spaces then
          max_empty_spaces = spaces
          offending_lines_count = lines_skipped
        end
        current_idx = next_start_rel + 1 -- skip \n
        lines_skipped = lines_skipped + 1
      else
        -- Found content
        if spaces < min_indent then
          break -- Less indented than parent, block ends
        end
        block_indent = spaces
        found_content = true
        break
      end
    end

    if found_content then
      if max_empty_spaces > block_indent then
        -- Advance lexer to the offending line for accurate error reporting
        for _ = 1, offending_lines_count do
          while not self.lexer:at("\n") do
            self.lexer:advance()
          end
          self.lexer:advance() -- consume \n
        end

        local err_token = {
          row = self.lexer.line,
          col = max_empty_spaces,
        }
        self:error("Leading blank lines must not be more indented than the first non-empty line", err_token)
      end
    else
      if max_empty_spaces > min_indent then
        block_indent = max_empty_spaces
      else
        block_indent = min_indent
      end
    end
  end

  local lines = {}

  while true do
    if self.lexer:is_eof() then
      break
    end

    if self.lexer:match(0, "---") and self.lexer:is_separator(3) then
      break
    end
    if self.lexer:match(0, "...") and self.lexer:is_separator(3) then
      break
    end

    local spaces, next_char, is_empty_line, _ = peek_line_info(0)

    -- Check Block Termination
    if not is_empty_line and spaces < block_indent then
      if next_char == "\t" then
        self.lexer:advance(spaces)
        self:error("tab character may not be used as indentation")
      end
      break
    end

    local consume_count
    if is_empty_line then
      if spaces > block_indent then
        consume_count = block_indent
      else
        consume_count = spaces
      end
    else
      consume_count = block_indent
    end

    self.lexer:advance(consume_count)

    -- Capture Line Content
    local start = self.lexer.index
    while not self.lexer:at("\n") and not self.lexer:is_eof() do
      self.lexer:advance()
    end
    local line_val = string.sub(self.lexer.str, start, self.lexer.index - 1)

    if is_empty_line and #line_val == 0 and spaces <= block_indent then
      line_val = ""
    end

    table.insert(lines, line_val)

    if self.lexer:at("\n") then
      self.lexer:advance()
    end
  end

  -- Apply Chomping
  if chomping ~= "keep" then
    while #lines > 0 and lines[#lines] == "" do
      table.remove(lines)
    end
  end

  -- Join Lines
  local result = ""
  if is_folded then
    local gap = 0
    local first_content = true
    local last_was_indented = false

    for i = 1, #lines do
      local line = lines[i]
      if line == "" then
        gap = gap + 1
      else
        local is_indented = (line:sub(1, 1) == " " or line:sub(1, 1) == "\t")

        if first_content then
          if gap > 0 then
            result = result .. string.rep("\n", gap)
          end
          result = result .. line
          first_content = false
        else
          if gap == 0 then
            if is_indented or last_was_indented then
              result = result .. "\n" .. line
            else
              result = result .. " " .. line
            end
          else
            if is_indented or last_was_indented then
              result = result .. string.rep("\n", gap + 1) .. line
            else
              result = result .. string.rep("\n", gap) .. line
            end
          end
        end

        gap = 0
        last_was_indented = is_indented
      end
    end
    if gap > 0 then
      result = result .. string.rep("\n", gap)
    end
  else
    result = table.concat(lines, "\n")
  end

  if chomping == "clip" or chomping == "keep" then
    if #lines > 0 then
      result = result .. "\n"
    end
  end

  return result
end

function Parser:flow_seq(tag, anchor, min_indent)
  table.insert(self.tokens, { kind = "+SEQ", style = "[]", tag = tag, anchor = anchor })
  self.lexer:next() -- Consume '['

  while true do
    self:skip_newlines()
    local token = self.lexer:peek()

    if min_indent and token.col < min_indent and token.kind ~= "EOF" then
      self:error("Bad indentation in flow sequence", token)
    end

    if token.kind == "R_BRACKET" then
      self.lexer:next() -- Consume ']'
      break
    end
    if token.kind == "EOF" then
      self:error("Unexpected End Of File inside flow sequence", token)
    end

    if token.kind == "COMMA" then
      self:error("flow sequence with invalid comma in the beginning", token)
    end

    if token.kind == "QUESTION" then
      table.insert(self.tokens, { kind = "+MAP", style = "{}" })
      self.lexer:next()
      self:flow_node(min_indent)
      self:skip_newlines()
      if self.lexer:peek().kind == "COLON" then
        self.lexer:next()
        self:flow_node(min_indent)
      else
        table.insert(self.tokens, { kind = "VAL", val = null, style = ":" })
      end
      table.insert(self.tokens, { kind = "-MAP" })
    elseif token.kind == "COLON" then
      table.insert(self.tokens, { kind = "+MAP", style = "{}" })
      table.insert(self.tokens, { kind = "VAL", val = null, style = ":" })
      self.lexer:next()
      self:skip_newlines()
      self:flow_node(min_indent)
      table.insert(self.tokens, { kind = "-MAP" })
    else
      local start_len = #self.tokens
      self:flow_node(min_indent)

      -- NOTE: We do NOT skip newlines here.
      -- In a flow sequence, if an implicit key (flow node) is followed by a newline
      -- and then a colon, it is NOT an implicit mapping entry.
      -- Implicit keys in flow sequences must be on the same line as the colon.

      local next_tok = self.lexer:peek()
      local is_valid_colon = next_tok.kind == "COLON" and (next_tok.spaced or next_tok.adjacent)

      if is_valid_colon then
        self.lexer:next() -- Consume :

        local key_token_idx = start_len + 1

        table.insert(self.tokens, key_token_idx, { kind = "+MAP", style = "{}" })

        self:flow_node(min_indent)

        table.insert(self.tokens, { kind = "-MAP" })
      end
    end

    self:skip_newlines()
    if self.lexer:peek().kind == "COMMA" then
      self.lexer:next()
    elseif self.lexer:peek().kind ~= "R_BRACKET" then
      self:error("Expected ',' or ']' in flow sequence", self.lexer:peek())
    end
  end
  table.insert(self.tokens, { kind = "-SEQ" })
end

function Parser:flow_map(tag, anchor, min_indent)
  table.insert(self.tokens, { kind = "+MAP", style = "{}", tag = tag, anchor = anchor })
  self.lexer:next() -- Consume '{'

  while true do
    self:skip_newlines()
    local token = self.lexer:peek()

    if min_indent and token.col < min_indent and token.kind ~= "EOF" then
      self:error("Bad indentation in flow map", token)
    end

    if token.kind == "R_BRACE" then
      self.lexer:next()
      break
    end
    if token.kind == "EOF" then
      self:error("Unexpected End Of File inside flow map", token)
    end

    if token.kind == "QUESTION" then
      self.lexer:next()
      self:flow_node(min_indent)
      self:skip_newlines()
      if self.lexer:peek().kind == "COLON" then
        self.lexer:next()
        self:flow_node(min_indent)
      else
        table.insert(self.tokens, { kind = "VAL", val = null, style = ":" })
      end
    else
      self:flow_node(min_indent)

      -- Always skip newlines after the key to find the colon or next separator
      -- This is allowed in flow maps (e.g. { key \n : val })
      self:skip_newlines()

      local next_kind = self.lexer:peek().kind

      if next_kind == "COLON" then
        self.lexer:next()
        self:flow_node(min_indent)
      elseif next_kind == "COMMA" or next_kind == "R_BRACE" then
        table.insert(self.tokens, { kind = "VAL", val = null, style = ":" })
      else
        self:error("Expected ':' after key in flow map", self.lexer:peek())
      end
    end

    self:skip_newlines()
    if self.lexer:peek().kind == "COMMA" then
      self.lexer:next()
    elseif self.lexer:peek().kind ~= "R_BRACE" then
      self:error("Expected ',' or '}' in flow map", self.lexer:peek())
    end
  end
  table.insert(self.tokens, { kind = "-MAP" })
end
function Parser:flow_node(min_indent)
  local tag, anchor = self:parse_properties()
  self:skip_newlines()
  local token = self.lexer:peek()

  if token.kind == "ALIAS" then
    self.lexer:next()
    table.insert(self.tokens, { kind = "ALI", val = token.value })
    return
  end

  if token.kind == "L_BRACKET" then
    self:flow_seq(tag, anchor, min_indent)
  elseif token.kind == "L_BRACE" then
    self:flow_map(tag, anchor, min_indent)
  elseif token.kind == "D_QUOTE" then
    self.lexer:next()
    table.insert(self.tokens, { kind = "VAL", val = token.value, style = '"', tag = tag, anchor = anchor })
  elseif token.kind == "S_QUOTE" then
    self.lexer:next()
    table.insert(self.tokens, { kind = "VAL", val = token.value, style = "'", tag = tag, anchor = anchor })
  elseif token.kind == "TEXT" then
    local first = self.lexer:next()
    local val = self:consume_flow_text(first)
    table.insert(self.tokens, { kind = "VAL", val = val, style = ":", tag = tag, anchor = anchor })
  elseif token.kind == "DIRECTIVE" then
    self.lexer:next()
    table.insert(self.tokens, { kind = "VAL", val = token.value, style = ":", tag = tag, anchor = anchor })
  else
    table.insert(self.tokens, { kind = "VAL", val = null, style = ":", tag = tag, anchor = anchor })
  end
end

function Parser:seq(tag, anchor)
  local seq_indent = self.lexer:peek().col
  table.insert(self.tokens, { kind = "+SEQ", tag = tag, anchor = anchor })

  while true do
    self:skip_newlines()
    local token = self.lexer:peek()

    if token.kind == "DASH" then
      if token.col < seq_indent then
        break
      elseif token.col > seq_indent then
        self:error("Bad indentation: Sequence item is indented more than the sequence start", token)
      end
    else
      break
    end
    local dash_token = self.lexer:next() -- Consume DASH

    self:skip_newlines()
    local next_token = self.lexer:peek()

    if
      next_token.kind == "EOF"
      or next_token.kind == "DOC_START"
      or next_token.kind == "DOC_END"
      or next_token.kind == "DIRECTIVE"
      or next_token.col <= seq_indent
    then
      table.insert(self.tokens, { kind = "VAL", val = null, style = ":" })
    else
      self:block_node(seq_indent + 1, dash_token, false, nil, seq_indent)
    end
  end

  table.insert(self.tokens, { kind = "-SEQ" })
end

function Parser:map(tag, anchor, inline_key_props, explicit_indent)
  local map_indent = explicit_indent or self.lexer:peek().col
  table.insert(self.tokens, { kind = "+MAP", tag = tag, anchor = anchor })

  local is_first_key = true

  while true do
    self:skip_newlines()
    local token = self.lexer:peek()

    if
      token.col < map_indent
      or token.kind == "EOF"
      or token.kind == "DOC_END"
      or token.kind == "DOC_START"
      or token.kind == "DIRECTIVE"
    then
      break
    end

    if token.col > map_indent then
      local allowed = (is_first_key and explicit_indent ~= nil)
      if not allowed then
        self:error("Bad indentation: Map key indented more than map start", token)
      end
    end

    if token.kind == "QUESTION" then
      local q_token = self.lexer:next() -- Consume ?
      self:block_node(map_indent, q_token) -- Pass context, reverted indentation to allow zero-indented content
      self:skip_newlines()
      if self.lexer:peek().kind == "COLON" then
        local colon_token = self.lexer:next()
        self:block_node(map_indent, colon_token, true, nil, map_indent)
      else
        table.insert(self.tokens, { kind = "VAL", val = null, style = ":" })
      end
      is_first_key = false
    else
      local key_tag
      local key_anchor

      if is_first_key and inline_key_props then
        key_tag = inline_key_props.tag
        key_anchor = inline_key_props.anchor
      else
        key_tag, key_anchor = self:parse_properties(map_indent)
        token = self.lexer:peek()
      end

      if
        (
          token.kind == "TEXT"
          or token.kind == "D_QUOTE"
          or token.kind == "S_QUOTE"
          or token.kind == "ALIAS"
          or token.kind == "ANCHOR"
          or token.kind == "TAG"
        ) and self.lexer:peek(2).kind == "COLON"
      then
        if token.row ~= self.lexer:peek(2).row then
          self:error("invalid multiline scalar used as key", token)
        end
        if token.kind == "D_QUOTE" then
          local tok = self.lexer:next()
          table.insert(self.tokens, { kind = "VAL", val = tok.value, style = '"', tag = key_tag, anchor = key_anchor })
        elseif token.kind == "S_QUOTE" then
          local tok = self.lexer:next()
          table.insert(self.tokens, { kind = "VAL", val = tok.value, style = "'", tag = key_tag, anchor = key_anchor })
        elseif token.kind == "ALIAS" then
          if key_tag or key_anchor then
            self:error("Aliases cannot have tags or anchors", token)
          end
          self.lexer:next()
          table.insert(self.tokens, { kind = "ALI", val = token.value })
        elseif token.kind == "TAG" then
          -- Consume the tag as a plain scalar key if it's followed by colon
          local tok = self.lexer:next()
          table.insert(self.tokens, { kind = "VAL", val = tok.value, style = ":", tag = key_tag, anchor = key_anchor })
        else
          local first_chunk = self.lexer:next()
          local key_str = self:consume_plain_scalar(map_indent, first_chunk)
          if key_str == "" then
            key_str = null
          end
          table.insert(self.tokens, { kind = "VAL", val = key_str, style = ":", tag = key_tag, anchor = key_anchor })
        end

        local colon_token = self.lexer:next() -- Consume ':'
        self:skip_newlines()

        -- Look ahead to determine if the next value is a sequence item at the same indent
        local probe_idx = 1
        while true do
          local t = self.lexer:peek(probe_idx)
          if t.kind == "TAG" or t.kind == "ANCHOR" or t.kind == "NEWLINE" then
            probe_idx = probe_idx + 1
          else
            break
          end
        end
        local next_token = self.lexer:peek(probe_idx)
        local is_seq_item = (next_token.kind == "DASH" and next_token.col == map_indent)

        local val_indent = map_indent + 1
        if is_seq_item then
          val_indent = map_indent
        end
        self:block_node(val_indent, colon_token, false, nil, map_indent)

        is_first_key = false
      elseif token.kind == "COLON" then
        -- Implicit null key: ": value"
        table.insert(self.tokens, { kind = "VAL", val = null, style = ":", tag = key_tag, anchor = key_anchor })
        local colon_token = self.lexer:next() -- Consume ':'
        self:skip_newlines()

        local probe_idx = 1
        while true do
          local t = self.lexer:peek(probe_idx)
          if t.kind == "TAG" or t.kind == "ANCHOR" or t.kind == "NEWLINE" then
            probe_idx = probe_idx + 1
          else
            break
          end
        end
        local next_token = self.lexer:peek(probe_idx)
        local is_seq_item = (next_token.kind == "DASH" and next_token.col == map_indent)

        local val_indent = map_indent + 1
        if is_seq_item then
          val_indent = map_indent
        end
        self:block_node(val_indent, colon_token, false, nil, map_indent)
        is_first_key = false
      elseif token.kind == "L_BRACKET" or token.kind == "L_BRACE" then
        -- Check for flow key on same line
        local nesting = 0
        local lookahead_idx = 1
        local start_row = token.row
        local is_flow_key = false

        while true do
          local t = self.lexer:peek(lookahead_idx)
          if t.kind == "EOF" or t.row ~= start_row then
            break
          end

          if t.kind == "L_BRACKET" or t.kind == "L_BRACE" then
            nesting = nesting + 1
          elseif t.kind == "R_BRACKET" or t.kind == "R_BRACE" then
            nesting = nesting - 1
            if nesting == 0 then
              if self.lexer:peek(lookahead_idx + 1).kind == "COLON" then
                is_flow_key = true
              end
              break
            end
          end
          lookahead_idx = lookahead_idx + 1
        end

        if is_flow_key then
          if token.kind == "L_BRACKET" then
            self:flow_seq(key_tag, key_anchor, map_indent)
          else
            self:flow_map(key_tag, key_anchor, map_indent)
          end

          local colon_token = self.lexer:next() -- Consume COLON
          self:skip_newlines()

          local probe_idx = 1
          while true do
            local t = self.lexer:peek(probe_idx)
            if t.kind == "TAG" or t.kind == "ANCHOR" or t.kind == "NEWLINE" then
              probe_idx = probe_idx + 1
            else
              break
            end
          end
          local next_token = self.lexer:peek(probe_idx)
          local is_seq_item = (next_token.kind == "DASH" and next_token.col == map_indent)
          local val_indent = map_indent + 1
          if is_seq_item then
            val_indent = map_indent
          end

          self:block_node(val_indent, colon_token, false, nil, map_indent)
          is_first_key = false
        else
          break
        end
      else
        break
      end
    end
  end

  table.insert(self.tokens, { kind = "-MAP" })
end

function Parser:scalar(indent, tag, anchor)
  local first_chunk = self.lexer:next()
  local k = first_chunk.kind
  if k == "COMMA" or k == "R_BRACKET" or k == "R_BRACE" then
    self:error("unexpected character in block scalar", first_chunk)
  end
  local val = self:consume_plain_scalar(indent, first_chunk)
  if val == "" then
    val = null
  end
  table.insert(self.tokens, { kind = "VAL", val = val, style = ":", tag = tag, anchor = anchor })
end

function Parser:block_node(indent, context_token, is_explicit_value, doc_start_line, parent_indent)
  self:skip_newlines()

  -- Define start_col based on the first token (anchor/tag or text)
  local start_token = self.lexer:peek()
  local start_col = start_token.col
  local first_prop_row = start_token.row

  -- Pass min_indent to parse_properties
  -- If parent_indent is -1 (root), min_indent is 0.
  -- Otherwise, properties must be indented relative to parent (parent_indent + 1).
  local min_prop_indent = (parent_indent and parent_indent >= 0) and (parent_indent + 1) or 0
  local tag, anchor = self:parse_properties(min_prop_indent, context_token)

  -- IMPORTANT: Skip newlines after properties to find the start of the value (which might be indented on the next line)
  self:skip_newlines()

  local function peek_past_props()
    local idx = 1
    while true do
      local t = self.lexer:peek(idx)
      if t.kind == "TAG" or t.kind == "ANCHOR" then
        idx = idx + 1
      else
        return t, idx
      end
    end
  end

  local real_token, offset = peek_past_props()

  -- Check for termination by COLON in explicit key context (Fix for PW8X and 6PBE)
  if context_token and context_token.kind == "QUESTION" and real_token.kind == "COLON" then
    -- If the colon is at the same indentation as the block (indent) then it terminates the key
    if real_token.col <= indent then
      table.insert(self.tokens, { kind = "VAL", val = null, style = ":", tag = tag, anchor = anchor })
      return
    end
    -- If on same line, it only terminates if we have properties (e.g. ? !!str :)
    if real_token.row == context_token.row and (tag or anchor) then
      table.insert(self.tokens, { kind = "VAL", val = null, style = ":", tag = tag, anchor = anchor })
      return
    end
  end

  if real_token.col < indent and real_token.kind ~= "NEWLINE" and real_token.kind ~= "EOF" then
    table.insert(self.tokens, { kind = "VAL", val = null, style = ":", tag = tag, anchor = anchor })
    return
  end

  local is_map = false
  if
    real_token.kind == "TEXT"
    or real_token.kind == "D_QUOTE"
    or real_token.kind == "S_QUOTE"
    or real_token.kind == "ALIAS"
    or real_token.kind == "ANCHOR"
  then
    if self.lexer:peek(offset + 1).kind == "COLON" then
      is_map = true
      -- Removed: Same line map restriction. "key: nested: value" is allowed.
    end
  elseif real_token.kind == "L_BRACKET" or real_token.kind == "L_BRACE" then
    local idx = offset
    local nesting = 0
    local start_row = real_token.row
    while true do
      local t = self.lexer:peek(idx)
      if t.kind == "EOF" or t.row ~= start_row then
        break
      end

      if t.kind == "L_BRACKET" or t.kind == "L_BRACE" then
        nesting = nesting + 1
      elseif t.kind == "R_BRACKET" or t.kind == "R_BRACE" then
        nesting = nesting - 1
        if nesting == 0 then
          if self.lexer:peek(idx + 1).kind == "COLON" then
            is_map = true
          end
          break
        end
      end
      idx = idx + 1
    end
  elseif real_token.kind == "QUESTION" then
    is_map = true
  elseif real_token.kind == "COLON" then
    is_map = true
  end

  local is_seq = (real_token.kind == "DASH")
  if (is_map or is_seq) and doc_start_line and real_token.row == doc_start_line then
    self:error("Block collection cannot start on the same line as document separator", real_token)
  end
  if is_seq and (tag or anchor) and real_token.row == start_token.row then
    local prop_type = anchor and "anchor" or "tag"
    self:error("illegal block sequence on the same line as " .. prop_type, real_token)
  end
  if is_map and context_token and context_token.kind == "COLON" and not is_explicit_value then
    if real_token.row == context_token.row then
      self:error("invalid nested block mapping on the same line", real_token)
    end
  end
  if is_seq and context_token and context_token.kind == "COLON" then
    if not is_explicit_value then
      if real_token.row == context_token.row then
        self:error("Block sequence on the same line as a mapping key", real_token)
      end
    end
  end

  local token = self.lexer:peek()

  if token.kind == "EOF" or token.kind == "DOC_START" or token.kind == "DOC_END" or token.kind == "DIRECTIVE" then
    table.insert(self.tokens, { kind = "VAL", val = null, style = ":", tag = tag, anchor = anchor })
    return
  end

  if token.kind == "ALIAS" and not is_map then
    if tag then
      self:error("Aliases cannot have tags", token)
    end
    if anchor then
      self:error("Aliases cannot have anchors", token)
    end
    self.lexer:next()
    table.insert(self.tokens, { kind = "ALI", val = token.value })
    return
  end

  if token.col < indent then
    table.insert(self.tokens, { kind = "VAL", val = null, style = ":", tag = tag, anchor = anchor })
    return
  end

  if is_seq then
    self:seq(tag, anchor)
  elseif is_map then
    -- Detect if properties should apply to the Map or the First Key (Implicit Map)
    -- Rule: If implicit map (no brace) and property is on same line as start, apply to key.
    local is_implicit_map = (real_token.kind ~= "L_BRACE")
    local props_on_key = is_implicit_map and (tag or anchor) and (real_token.row == first_prop_row)

    local explicit_map_indent = nil

    if props_on_key then
      explicit_map_indent = start_col
    elseif start_col < indent then
      explicit_map_indent = start_col
    end

    if props_on_key then
      self:map(nil, nil, { tag = tag, anchor = anchor }, explicit_map_indent)
    else
      self:map(tag, anchor, nil, explicit_map_indent)
    end
  elseif token.kind == "PIPE" then
    local val = self:consume_block_scalar(indent, false)
    table.insert(self.tokens, { kind = "VAL", val = val, style = "|", tag = tag, anchor = anchor })
  elseif token.kind == "L_BRACKET" then
    self:flow_seq(tag, anchor, indent)
  elseif token.kind == "L_BRACE" then
    self:flow_map(tag, anchor, indent)
  elseif token.kind == "GT" then
    local val = self:consume_block_scalar(indent, true)
    table.insert(self.tokens, { kind = "VAL", val = val, style = ">", tag = tag, anchor = anchor })
  elseif token.kind == "D_QUOTE" then
    self.lexer:next()
    table.insert(self.tokens, { kind = "VAL", val = token.value, style = '"', tag = tag, anchor = anchor })
  elseif token.kind == "S_QUOTE" then
    self.lexer:next()
    table.insert(self.tokens, { kind = "VAL", val = token.value, style = "'", tag = tag, anchor = anchor })
  else
    -- Ensure we don't treat misplaced anchors/tags as scalar values
    if token.kind == "ANCHOR" or token.kind == "TAG" then
      self:error("unexpected anchor or tag", token)
    end
    self:scalar(indent, tag, anchor)
  end
end

function Parser:parse()
  table.insert(self.tokens, { kind = "+STR" })

  local doc_count = 0
  local last_doc_had_explicit_end = false

  while true do
    self:skip_newlines()

    self.tag_handles = {
      ["!!"] = "tag:yaml.org,2002:",
      ["!"] = "!",
    }

    if self.lexer:peek().kind == "DIRECTIVE" and doc_count > 0 and not last_doc_had_explicit_end then
      self:error("missing explicit document end marker before directive(s)", self.lexer:peek())
    end

    local has_directives = false
    local has_yaml_directive = false
    while self.lexer:peek().kind == "DIRECTIVE" do
      has_directives = true
      local dir = self.lexer:next()
      local dir_name = dir.value:match("^(%S+)")

      if dir_name == "%YAML" then
        if has_yaml_directive then
          self:error("duplicate version directive", dir)
        end
        -- Check for valid version format
        if not dir.value:match("^%%YAML%s+%d+%.%d+$") then
          self:error("garbage after version directive", dir)
        end
        has_yaml_directive = true
      elseif dir_name == "%TAG" then
        local handle, prefix = dir.value:match("^%%TAG%s+(%S+)%s+(%S+)")
        if handle and prefix then
          self.tag_handles[handle] = prefix
        end
      end
      -- Unknown directives are ignored but tokens are emitted
      table.insert(self.tokens, { kind = "DIR", val = dir.value })
      self:skip_newlines()
    end

    if self.lexer:peek().kind == "EOF" then
      if has_directives then
        self:error("stream with directives without content", self.lexer:peek())
      end
      break
    end

    local token = self.lexer:peek()

    if token.kind == "DOC_END" then
      if has_directives then
        self:error("directive(s) without a document", token)
      end
      local doc_end_token = self.lexer:next()
      last_doc_had_explicit_end = true

      local next_token = self.lexer:peek()
      if next_token.row == doc_end_token.row and next_token.kind ~= "NEWLINE" and next_token.kind ~= "EOF" then
        self:error("invalid content after document end marker", next_token)
      end
    else
      local doc_start_line = nil
      if token.kind == "DOC_START" then
        doc_start_line = token.row
        self.lexer:next()
        table.insert(self.tokens, { kind = "+DOC", val = "---" })
      elseif doc_count > 0 and not last_doc_had_explicit_end then
        self:error("Expected a new document marker '---' or EOF", token)
      else
        if has_directives then
          self:error("directive(s) without a document", token)
        end
        table.insert(self.tokens, { kind = "+DOC" })
      end

      doc_count = doc_count + 1

      self:skip_newlines()
      token = self.lexer:peek()

      if token.kind == "EOF" or token.kind == "DOC_START" or token.kind == "DOC_END" or token.kind == "DIRECTIVE" then
        table.insert(self.tokens, { kind = "VAL", val = null, style = ":" })
      else
        self:block_node(0, nil, false, doc_start_line, -1)
      end

      self:skip_newlines()
      if self.lexer:peek().kind == "DOC_END" then
        local doc_end_token = self.lexer:next()
        table.insert(self.tokens, { kind = "-DOC", val = "..." })
        last_doc_had_explicit_end = true

        local next_token = self.lexer:peek()
        if next_token.row == doc_end_token.row and next_token.kind ~= "NEWLINE" and next_token.kind ~= "EOF" then
          self:error("invalid content after document end marker", next_token)
        end
      else
        table.insert(self.tokens, { kind = "-DOC" })
        last_doc_had_explicit_end = false
      end
    end
  end

  table.insert(self.tokens, { kind = "-STR" })
  return true, nil
end

function Parser:__tostring()
  local result = {}
  for _, token in ipairs(self.tokens) do
    local tag_str = token.tag and (" <" .. token.tag .. ">") or ""
    local anchor_str = token.anchor and (" &" .. token.anchor) or ""
    local props = anchor_str .. tag_str

    if token.kind == "+STR" then
      table.insert(result, "+STR")
    elseif token.kind == "-STR" then
      table.insert(result, "-STR")
    elseif token.kind == "+DOC" then
      table.insert(result, (token.val and string.format("+DOC %s", token.val) or "+DOC"))
    elseif token.kind == "-DOC" then
      table.insert(result, (token.val and string.format("-DOC %s", token.val) or "-DOC"))
    elseif token.kind == "+MAP" then
      if token.style == "{}" then
        table.insert(result, "+MAP {}" .. props)
      else
        table.insert(result, "+MAP" .. props)
      end
    elseif token.kind == "-MAP" then
      table.insert(result, "-MAP")
    elseif token.kind == "+SEQ" then
      if token.style == "[]" then
        table.insert(result, "+SEQ []" .. props)
      else
        table.insert(result, "+SEQ" .. props)
      end
    elseif token.kind == "-SEQ" then
      table.insert(result, "-SEQ")
    elseif token.kind == "VAL" then
      local style = token.style or ":"
      local display_val
      if token.val == null then
        display_val = ""
      else
        display_val = token.val
          :gsub("\\", "\\\\")
          :gsub("%z", "\\0")
          :gsub("\b", "\\b")
          :gsub("\t", "\\t")
          :gsub("\n", "\\n")
          :gsub("\f", "\\f")
          :gsub("\r", "\\r")
      end

      table.insert(result, string.format("=VAL%s %s%s", props, style, display_val))
    elseif token.kind == "ALI" then
      table.insert(result, string.format("=ALI *%s", token.val))
    end
  end
  table.insert(result, "")
  return table.concat(result, "\n")
end

-----------------------------------------------------------------------------
---                         decode the parsed tokens                      ---
-----------------------------------------------------------------------------

-- luacheck: ignore
local unpack = unpack or table.unpack

-- resolve the scalar token to a lua value based on style, tag, and content
local resolve = function(token)
  local val = token.val

  -- handle quoted/block styles (always strings)
  if token.style == '"' or token.style == "'" or token.style == "|" or token.style == ">" then
    return val
  end

  -- handle explicit string tags
  if token.tag == "!" or token.tag == "tag:yaml.org,2002:str" then
    if val == null then
      return ""
    end
    return val
  end

  -- handle sentinel
  if val == null then
    return null
  end

  -- implicit resolution (plain style)
  if val == "true" then
    return true
  elseif val == "false" then
    return false
  elseif val == "null" or val == "~" then
    return null
  end

  local num = tonumber(val)
  if num then
    return num
  end

  return val
end

local Decoder = {}
Decoder.__index = Decoder

function Decoder:new(parser)
  local o = {}
  setmetatable(o, self)
  o.parser = parser
  o.index = 0
  o.result = {}
  o.anchors = {}
  return o
end

function Decoder:peek()
  if self.index + 1 > #self.parser.tokens then
    return nil
  else
    return self.parser.tokens[self.index + 1]
  end
end

function Decoder:next()
  self.index = self.index + 1
  if self.index > #self.parser.tokens then
    return nil
  else
    return self.parser.tokens[self.index]
  end
end

function Decoder:register_anchor(anchor, val)
  if anchor then
    self.anchors[anchor] = val
  end
end

-- Accept anchor to support recursive structures (register before content)
function Decoder:seq(anchor)
  local res = {}
  if anchor then
    self.anchors[anchor] = res
  end

  local next = self:next()
  while next do
    if next.kind == "VAL" then
      local val = resolve(next)
      self:register_anchor(next.anchor, val)
      table.insert(res, val)
    elseif next.kind == "ALI" then
      assert(self.anchors[next.val] ~= nil, "Unknown anchor: " .. tostring(next.val))
      table.insert(res, self.anchors[next.val])
    elseif next.kind == "-SEQ" then
      break
    elseif string.match(next.kind, "^+SEQ") then
      table.insert(res, self:seq(next.anchor))
    elseif string.match(next.kind, "^+MAP") then
      table.insert(res, self:map(next.anchor))
    elseif next.kind == "+DOC" or next.kind == "-DOC" or next.kind == "-STR" then
      break
    end
    next = self:next()
  end
  return res
end

-- Accept anchor to support recursive structures
function Decoder:map(anchor)
  local res = {}
  if anchor then
    self.anchors[anchor] = res
  end

  local next = self:next()
  local key = nil

  while next do
    if next.kind == "VAL" then
      local val = resolve(next)
      self:register_anchor(next.anchor, val)

      if key == nil then
        key = val
      else
        res[key] = val
        key = nil
      end
    elseif next.kind == "ALI" then
      assert(self.anchors[next.val] ~= nil, "Unknown anchor: " .. tostring(next.val))
      local val = self.anchors[next.val]
      if key == nil then
        key = val
      else
        res[key] = val
        key = nil
      end
    elseif next.kind == "-MAP" then
      break
    elseif string.match(next.kind, "^+MAP") then
      local val = self:map(next.anchor)
      if key == nil then
        key = val
      else
        res[key] = val
        key = nil
      end
    elseif string.match(next.kind, "^+SEQ") then
      local val = self:seq(next.anchor)
      if key == nil then
        key = val
      else
        res[key] = val
        key = nil
      end
    elseif next.kind == "+DOC" or next.kind == "-DOC" or next.kind == "-STR" then
      break
    end
    next = self:next()
  end
  return res
end

function Decoder:decode()
  local documents = {}
  local next = self:next()

  while next do
    local doc = nil

    -- Reset anchors for new documents to comply with spec (anchors are per-document)
    if next.kind == "+DOC" then
      self.anchors = {}
      -- +DOC might technically have a value (explicit separator), but it doesn't contain the node data itself
      -- The loop will continue to the next token which contains the data
    elseif string.match(next.kind, "^+SEQ") then
      doc = self:seq(next.anchor)
    elseif string.match(next.kind, "^+MAP") then
      doc = self:map(next.anchor)
    elseif string.match(next.kind, "^VAL") then
      doc = resolve(next)
      self:register_anchor(next.anchor, doc)
    elseif next.kind == "ALI" then
      assert(self.anchors[next.val] ~= nil, "Unknown anchor: " .. tostring(next.val))
      doc = self.anchors[next.val]
    end

    if doc ~= nil then
      table.insert(documents, doc)
    end

    next = self:next()
  end

  return unpack(documents)
end

return {
  dump = function(content)
    local lexer = Lexer:new(content)
    local parser = Parser:new(lexer)
    local status, res_or_err = pcall(function()
      return parser:parse()
    end)

    if not status then
      return nil, res_or_err
    end
    return tostring(parser)
  end,

  decode = function(content)
    local lexer = Lexer:new(content)
    local parser = Parser:new(lexer)
    local status, res_or_err = pcall(function()
      return parser:parse()
    end)

    if not status then
      return nil, res_or_err
    end

    local decoder = Decoder:new(parser)
    return decoder:decode()
  end,
  parse = function(path)
    local file = io.open(path, "r")
    if not file then
      return nil, "can not open file " .. path
    end
    local content = file:read("*all")
    file:close()

    local lexer = Lexer:new(content)
    local parser = Parser:new(lexer)
    local status, res_or_err = pcall(function()
      return parser:parse()
    end)

    if not status then
      return nil, res_or_err
    end

    local decoder = Decoder:new(parser)
    return decoder:decode()
  end,
  null = null,
}
