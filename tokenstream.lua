local TokenStream = {}
TokenStream.__index = TokenStream

---@param lexer Lexer The fully lexed lexer instance
function TokenStream:new(lexer)
  local o = {}
  setmetatable(o, self)
  o.lexer = lexer
  o.tokens = lexer.tokens
  o.pos = 1 -- Current position in tokens array
  return o
end

--- Returns the current token without advancing
---@param offset integer? (Optional) Lookahead offset (default 0)
function TokenStream:peek(offset)
  return self.tokens[self.pos + (offset or 0)]
end

--- Returns the current token and advances the stream
function TokenStream:next()
  local token = self.tokens[self.pos]
  if token then
    self.pos = self.pos + 1
  end
  return token
end

--- Backups or restores position (for lookahead checks)
function TokenStream:mark()
  return self.pos
end

function TokenStream:rewind(pos)
  self.pos = pos
end

--------------------------------------------------------------------------------
-- Semantic Checks (The "Reader" Pattern)
--------------------------------------------------------------------------------

--- Checks if the current token matches the kind.
--- If yes, consumes and returns it. If no, returns nil.
---@param kind string
function TokenStream:accept(kind)
  local token = self:peek()
  if token and token.kind == kind then
    self.pos = self.pos + 1
    return token
  end
  return nil
end

--- Checks if the current token matches the kind.
--- If yes, consumes it. If no, raises a formatted error.
---@param kind string
function TokenStream:expect(kind)
  local token = self:peek()
  if not token or token.kind ~= kind then
    local got = token and token.kind or "EOF"
    error(self.lexer:error("Expected " .. kind .. " but got " .. got, token))
  end
  self.pos = self.pos + 1
  return token
end

--- Checks if the current token matches ANY of the provided kinds
---@param ... string List of kinds
function TokenStream:match_any(...)
  local token = self:peek()
  if not token then
    return false
  end
  for _, kind in ipairs({ ... }) do
    if token.kind == kind then
      return true
    end
  end
  return false
end

--------------------------------------------------------------------------------
-- Whitespace & Noise Handling
--------------------------------------------------------------------------------

--- Skips Newlines and Separators (useful for flow context or finding the next node)
function TokenStream:skip_ignorable()
  while true do
    local token = self:peek()
    if not token then
      break
    end
    if token.kind == "NL" or token.kind == "SEP" or token.kind == "COMMENT" then
      self:next()
    else
      break
    end
  end
end

--- Skips only Newlines (useful when looking for the start of a block item)
function TokenStream:skip_newlines()
  while self:peek() and self:peek().kind == "NL" do
    self:next()
  end
end

--- Gets the indentation level of the *current* position.
--- If currently on a SEP, returns its length.
--- If on a value, returns its column.
function TokenStream:current_indent()
  local token = self:peek()
  if not token then
    return 0
  end
  if token.kind == "SEP" then
    return #token.val
  end
  return token.col
end

--- Checks indentation against a requirement without consuming tokens.
---@param required_indent integer
---@return string "LESS", "EQUAL", or "MORE"
function TokenStream:check_indent(required_indent)
  local token = self:peek()
  -- If we are explicitly at a separator, check its length
  if token and token.kind == "SEP" then
    if #token.val < required_indent then
      return "LESS"
    end
    if #token.val == required_indent then
      return "EQUAL"
    end
    return "MORE"
  end

  -- If we are not at a separator (e.g., Start of Line, or directly at a val)
  -- We assume standard indentation rules based on column
  if token and token.col < required_indent then
    return "LESS"
  end
  if token and token.col == required_indent then
    return "EQUAL"
  end
  return "MORE" -- Default assumption if col > required
end

--------------------------------------------------------------------------------
-- Advanced Utilities
--------------------------------------------------------------------------------

--- Helper to determine if we are looking at a scalar value
function TokenStream:is_scalar()
  return self:match_any("VAL", "QUOTED", "LITERAL", "FOLDED")
end

--- Helper to consume a scalar, normalizing it
function TokenStream:consume_scalar()
  local t = self:peek()
  if t and t.kind == "VAL" then
    return self:next()
  end
  if t and t.kind == "QUOTED" then
    return self:next()
  end
  -- You can add logic here to automatically unwrap quoted values
  -- or delegate that to the parser
  return nil
end

--- Checks if the next significant token (ignoring horizontal whitespace) matches the kind.
--- Useful for determining "key: value" vs "value" without consuming tokens.
---@param kind string The kind to look for (e.g., "COLON")
function TokenStream:is_followed_by(kind)
  local offset = 1
  local token = self:peek(offset)

  -- Skip horizontal whitespace (SEP), but STOP at Newlines (NL)
  -- Implicit keys generally require the colon to be on the same line.
  while token and token.kind == "SEP" do
    offset = offset + 1
    token = self:peek(offset)
  end

  return token and token.kind == kind
end

return TokenStream
