local to_string = require("str").to_string

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

---@class Token
---@field kind string
---@field indent integer
---@field val string
---@field row integer
---@field col integer

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
	while self:peek_char() ~= "\n" do
		table.insert(chars, self:next_char())
	end
	return table.concat(chars, "")
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
	local chars = {}
	while self:peek_char() and self:peek_char() ~= quote do
		table.insert(chars, self:next_char())
	end
	self:next_char()
	return table.concat(chars, "")
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

function Lexer:folding_attrs(type)
	local row, col = self.row, self.col
	local token = self:create_token(type, self:next_char(), row, col)
	while self:peek_char() and self:peek_char() ~= "\n" do
		local attr = self:next_char()
		if attr == "-" then
			token.chomping = "STRIP"
		elseif attr == "+" then
			token.chomping = "KEEP"
		elseif self:match("# ") then
			self:to_eol()
		else
			error("unknown literal attribute: '" .. attr .. "'")
		end
	end
	return token
end

---@return Token|nil
function Lexer:token()
	while self:peek_char() do
		local char = self:peek_char()
		if char == "%" then
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
						error("second tag")
					else
						error("named")
					end
				else
					error("TAG: '" .. self:next_char() .. "'")
				end
			else
				error("unknown directive")
			end
			return self:create_token("DIRECTIVE", "%", row, col)
		elseif char == "-" and self:peek_char(2) == "-" and self:peek_char(3) == "-" then
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
		elseif self.flow_level > 0 and char == ":" then
			local row, col = self.row, self.col
			return self:create_token("FLOW_COLON", self:next_char(), row, col)
		elseif char == "?" and (self:peek_char(2) == " " or self:peek_char(2) == "\n") then
			local row, col = self.row, self.col
			return self:create_token("COMPLEX", self:next_char(), row, col)
		elseif char == "|" then
			local row, col = self.row, self.col
			local token = self:create_token("FOLDED", self:next_char(), row, col)
			-- TODO: use folding_attrs
			while self:peek_char() ~= "\n" do
				local attr = self:next_char()
				if attr == "-" then
					token.chomping = "STRIP"
				elseif attr == "+" then
					token.chomping = "KEEP"
				else
					error("unknown literal attribute: " .. attr)
				end
			end
			return token
		elseif char == ">" then
			return self:folding_attrs("LITERAL")
		elseif char == "'" or char == '"' then
			local row, col = self.row, self.col
			local type = self:peek_char()
			return self:create_token("QUOTED", self:quoted(), row, col, type)
		elseif char == "-" or char == ":" and (self:peek_char(2) == " " or self:peek_char(2) == "\n") then
			local row, col = self.row, self.col
			char = self:next_char()
			if char == "-" then
				return self:create_token("DASH", char, row, col)
			elseif char == ":" then
				return self:create_token("COLON", char, row, col)
			end
		elseif self:peek_char() == "!" then
			local row, col = self.row, self.col
			local tag = self:to_sep()
			return self:create_token("TAGREF", tag, row, col)
		elseif char == "&" then
			local row, col = self.row, self.col
			self:next_char()
			local value = self:to_sep()
			return self:create_token("ANCHOR", value, row, col)
		elseif char == "*" then
			local row, col = self.row, self.col
			self:next_char()
			local value = self:to_sep()
			return self:create_token("ALIAS", value, row, col)
		elseif self:is_comment() then
			-- commented line
			local col = self.col
			self:to_eol()
			if col == 0 and self:peek_char() and self:peek_char() == "\n" then
				self:next_char()
			end
		elseif char == " " then
			local row, col = self.row, self.col
			local sep = { self:next_char() }
			while self:peek_char() == " " do
				-- TODO: here could be a comment
				table.insert(sep, self:next_char())
			end
			return self:create_token("SEP", table.concat(sep, ""), row, col)
		elseif char == "\n" then
			local row, col = self.row, self.col
			return self:create_token("NL", self:next_char(), row, col)
		elseif self.col == 0 and self:peek_char() == "#" then
			self:to_eol()
			self:next_char()
		else
			local row, col = self.row, self.col
			local chars = { self:next_char() }
			while self:peek_char() ~= "\n" do
				-- skip the comment
				if (self:peek_char() == " " or self:peek_char() == "\t") and self:peek_char(2) == "#" then
					while self:peek_char() and self:peek_char() ~= "\n" do
						self:next_char()
					end
					break
				elseif self.flow_level > 0 and self:peek_char() and match("{}[]:,", self:peek_char()) then
					break
				elseif self:peek_char() == ":" and (self:peek_char(2) == " " or self:peek_char(2) == "\n") then
					break
				end
				table.insert(chars, self:next_char())
			end
			return self:create_token("VAL", trim(table.concat(chars, "")), row, col)
		end
	end
end

function Lexer:lexme()
	local token = self:token()
	assert(token)
	if token.kind ~= "SEP" then
		table.insert(self.tokens, self:create_token("SEP", "", self.row, 0))
	end
	while token do
		table.insert(self.tokens, token)
		if token.kind == "NL" then
			local next_token = self:token()
			if next_token then
				if next_token.kind ~= "SEP" then
					table.insert(self.tokens, self:create_token("SEP", "", self.row, 0))
				end
				table.insert(self.tokens, next_token)
			else
				break
			end
		end
		token = self:token()
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
		.. token.row
		.. ":"
		.. token.col
		.. " "
		.. mess
		.. "\n"
		.. (self:line(token.row) or "") -- TODO last line results in nil
		.. "\n"
		.. string.rep(" ", token.col)
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
.DASH, .COLON, .START_FLOW_SEQ, .END_FLOW_SEQ, .FLOW_SEP, .START_DOC, .END_DOC, .ANCHOR, .ALIAS, .COMPLEX {
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
	o.lexer = lexer
	o.tokens = {}

	o.global_tag = GLOBAL_TAG
	o.primary_tag = nil
	o.named_tags = {}

	o.state = {}
	return o
end

function Parser:push(target, tokens)
	if not tokens then
		table.insert(target, { kind = "VAL", val = "" })
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
	for line in string.gmatch(token.val, "([^\n]*)\n?") do
		if res then
			res = res .. " " .. trim(line)
		else
			res = line
		end
	end
	return trim(res)
end

function Parser:folded(token, indent)
	local lines = {}
	assert(token.kind == "VAL")
	table.insert(lines, token.val)
	while self.lexer:peek() do
		if self.lexer:peek().kind == "VAL" then
			table.insert(lines, self.lexer:next().val)
			if self.lexer:peek().kind == "COLON" then
				return nil, self.lexer:error("invalid multiline plain key", self.lexer:peek())
			end
		elseif self.lexer:peek().kind == "SEP" then
			if #self.lexer:peek().val <= indent then
				break
			end
			self.lexer:next()
		elseif self.lexer:peek().kind == "NL" then
			if not self.lexer:peek(2) then
				break
			elseif self.lexer:peek(2).kind == "SEP" and #self.lexer:peek().val <= indent then
				break
			end
			self.lexer:next()
		else
			break
		end
	end
	return table.concat(lines, " ")
end

function Parser:literal(token, indent)
	local lines
	local next = self.lexer:next()
	assert(self.lexer:peek().kind == "SEP", self.lexer:peek().kind)
	local final_indent
	local next_indent = #self.lexer:next().val
	local sep
	if token.kind == "FOLDED" then
		sep = "\n"
	else
		sep = " "
	end
	local nl = false
	while next do
		if next.kind == "SEP" then
			if self.lexer:peek().kind == "NL" then
				-- empty lines are convered to line breaks
				table.insert(lines, "\n")
				nl = true
			elseif #next.val < final_indent then
				break
			end
			next_indent = #next.val
		elseif next.kind == "VAL" then
			if not lines then
				lines = {}
			elseif token.kind == "FOLDED" then
				table.insert(lines, sep)
			elseif not nl and next_indent <= final_indent then
				table.insert(lines, sep)
			end
			if not final_indent then
				final_indent = next_indent
			end
			nl = false
			if next_indent > final_indent then
				table.insert(lines, "\n" .. string.rep(" ", next_indent - final_indent) .. next.val)
			else
				table.insert(lines, next.val)
			end
		end
		next = self.lexer:next()
	end
	-- collect the result
	local result = table.concat(lines, "")
	if token.chomping ~= "STRIP" then
		result = result .. "\n"
	end
	return result
end

function Parser:block_node(indent)
	local state = "STATE"
	for _, s in ipairs(self.state) do
		state = state .. " > " .. s
	end
	local token = self.lexer:next()
	local act_indent = indent
	while token do
		if token.kind == "VAL" then
			local anchor = self.anchor
			self.anchor = nil
			if self.lexer:peek().kind == "COLON" then
				token.anchor = anchor
				return self:map(indent, token)
			else
				local val = self:folded(token, indent)
				return { { kind = "VAL", val = val, tag = self.tagref, anchor = anchor } }
			end
		elseif token.kind == "QUOTED" then
			local res = self:quoted(token)
			local val = { kind = "VAL", val = trim(res), tag = self.tagref, type = '"' }
			if self.lexer:peek() and self.lexer:peek().kind == "SEP" then
				self.lexer:next()
			end
			if self.lexer:peek() and self.lexer:peek().kind == "COLON" then
				return self:map(indent, val)
			else
				return { val }
			end
		elseif token.kind == "FOLDED" then
			return {
				{
					kind = "VAL",
					val = self:literal(token, indent),
					type = "|",
					tag = self.tagref,
					anchor = self.anchor,
				},
			}
		elseif token.kind == "LITERAL" then
			return {
				{
					kind = "VAL",
					val = self:literal(token, indent),
					type = ">",
					tag = self.tagref,
					anchor = self.anchor,
				},
			}
		elseif token.kind == "COLON" then
			return self:map(indent)
		elseif token.kind == "DASH" then
			self.lexer:rewind()
			return self:sequence(indent)
		elseif token.kind == "START_FLOW_SEQ" then
			self.lexer:rewind()
			return self:flow(indent)
		elseif token.kind == "START_FLOW_MAP" then
			self.lexer:rewind()
			return self:flow(indent)
		elseif token.kind == "SEP" then
			--TODO:  assert(#token.val == indent)
		elseif token.kind == "TAGREF" then
			self.tagref = token
		elseif token.kind == "ANCHOR" then
			self.anchor = token
		elseif token.kind == "ALIAS" then
			return { { kind = "ALIAS", val = token.val, tag = self.tagref } }
		elseif token.kind == "COMPLEX" then
			assert(self.lexer:peek().kind == "SEP")
			local key = self:block_node(self.lexer:peek().col)
			return self:map(indent, key)
		elseif token.kind == "NL" then
			if self.lexer:peek() and self.lexer:peek().kind == "SEP" then
				local next_indent = #self.lexer:next().val
				assert(next_indent == indent, "found indent " .. next_indent .. " expected " .. indent)
			end
		else
			error("unknown item: " .. token.kind)
		end
		token = self.lexer:next()
	end
end

function Parser:parse_tag(tag)
	if string.match(tag, "^![%a%d]*") then
		return "<" .. self.global_tag .. string.sub(tag, 2) .. ">"
	else
		error("unknwon tag")
	end
end

function Parser:flow_map(indent)
	local tokens = {}
	table.insert(tokens, { kind = "+MAP {}" })
	self.lexer:next()
	local token = self.lexer:peek()
	while token do
		if token.kind == "START_FLOW_MAP" or token.kind == "START_FLOW_SEQ" then
			self:push(tokens, self:flow(indent))
		elseif token.kind == "END_FLOW_MAP" then
			break
		elseif token.kind == "SEP" then
			self.lexer:next()
		elseif token.kind == "FLOW_SEP" then
			self.lexer:next()
		elseif token.kind == "FLOW_COLON" then
			self.lexer:next()
		elseif token.kind == "QUOTED" then
			local res = self:quoted(self.lexer:next())
			table.insert(tokens, { kind = "VAL", val = res, type = token.type })
		elseif token.kind == "VAL" then
			local val = self.lexer:next()
			table.insert(tokens, { kind = "VAL", val = val.val })
		elseif token.kind == "NL" then
			self.lexer:next()
		else
			error("unknown flow_map kind: " .. token.kind)
		end
		token = self.lexer:peek()
	end
	table.insert(tokens, { kind = "-MAP" })
	return tokens
end

function Parser:flow_seq(indent)
	local tokens = {}
	table.insert(tokens, { kind = "+SEQ []" })
	self.lexer:next()
	local token = self.lexer:peek()
	while token do
		if token.kind == "START_FLOW_MAP" or token.kind == "START_FLOW_SEQ" then
			self:push(tokens, self:flow(indent))
		elseif token.kind == "END_FLOW_SEQ" then
			break
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
				table.insert(tokens, { kind = "VAL", val = res, type = token.type })
				res = self.lexer:next()
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
			table.insert(tokens, { kind = "VAL", val = "" })
			self.lexer:next()
			local val = self.lexer:next()
			assert(val.kind == "VAL", "expected VAL  but is: " .. val.kind)
			table.insert(tokens, { kind = "VAL", val = val.val })
			table.insert(tokens, { kind = "-MAP" })
		elseif token.kind == "VAL" then
			local val = self.lexer:next()
			if self.lexer:peek().kind == "FLOW_COLON" then
				self.lexer:next()
				table.insert(tokens, { kind = "+MAP {}" })
				table.insert(tokens, { kind = "VAL", val = val.val })
				val = self.lexer:next()
				val = self.lexer:next()
				assert(val.kind == "VAL", "expected VAL  but is: " .. val.kind)
				table.insert(tokens, { kind = "VAL", val = val.val })
				table.insert(tokens, { kind = "-MAP" })
			else
				table.insert(tokens, { kind = "VAL", val = val.val })
			end
		elseif token.kind == "NL" then
			self.lexer:next()
		else
			error("unknown flow_seq kind: " .. token.kind)
		end
		token = self.lexer:peek()
	end
	table.insert(tokens, { kind = "-SEQ" })
	return tokens
end

function Parser:flow(indent)
	local tokens = {}
	local token = self.lexer:peek()
	local flow_level = 0
	local next_indent = indent
	while token do
		if token.kind == "START_FLOW_SEQ" then
			flow_level = flow_level + 1
			local childs = self:flow_seq(indent + flow_level)
			self:push(tokens, childs)
		elseif token.kind == "END_FLOW_SEQ" then
			flow_level = flow_level - 1
			self.lexer:next()
			if flow_level == 0 then
				break
			end
		elseif token.kind == "START_FLOW_MAP" then
			flow_level = flow_level + 1
			local childs = self:flow_map(indent + flow_level)
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
	return tokens
end

function Parser:sequence(indent)
	local tokens = {}
	table.insert(self.state, "SEQ")
	table.insert(tokens, { kind = "+SEQ", tag = self.tagref, anchor = self.anchor })
	self.tagref = nil
	self.anchor = nil
	local token = self.lexer:peek()
	while token do
		if token.kind == "SEP" then
			if indent > #token.val then
				break
			end
			self.lexer:next()
		elseif token.kind == "NL" then
			self.lexer:next()
			if self.lexer:peek() and self.lexer:peek().kind == "SEP" then
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
			self.lexer:next()
			if self.lexer:peek() and self.lexer:peek().kind == "SEP" then
				local _ = self.lexer:next()
			end
			if
				self.lexer:peek().kind == "NL"
				and self.lexer:peek(2).kind == "SEP"
				and #self.lexer:peek(2).val == indent
			then
				table.insert(tokens, { kind = "VAL", val = "" })
			elseif self.lexer:peek() and self.lexer:peek().kind == "DASH" then
				local child = self:sequence(self.lexer:peek().col)
				self:push(tokens, child)
			elseif self.lexer:peek() and self.lexer:peek().kind == "NL" then
				self.lexer:next()
				local new_indent
				if self.lexer:peek() and self.lexer:peek().kind == "SEP" then
					new_indent = #self.lexer:next().val
					-- TODO local child = self:block_node(new_indent)
					local child = self:block_node(new_indent)
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
			table.insert(tokens, { kind = "VAL", val = "", anchor = self.lexer:next() })
		else
			local val = self:block_node(token.col)
			self:push(tokens, val)
		end
		token = self.lexer:peek()
	end
	table.insert(tokens, { kind = "-SEQ" })
	table.remove(self.state)
	return tokens
end

function Parser:map(indent, key_token)
	local tokens = {}
	table.insert(tokens, { kind = "+MAP", tag = self.tagref })
	self.tagref = nil
	self:push(tokens, key_token)
	local token = self.lexer:next()
	while token do
		if token.kind == "VAL" then
			local val, mes = self:folded(token, indent)
			if not val then
				return val, mes
			end
			table.insert(tokens, { kind = "VAL", val = val, anchor = self.anchor })
			self.anchor = nil
		elseif token.kind == "SEP" then
			if #token.val < indent then
				self.lexer:rewind()
				break
			end
		elseif token.kind == "NL" then
			if self.lexer:peek() == "SEP" then
				self.lexer:next()
			end
		elseif token.kind == "COLON" then
			-- skip the separator after the colon
			-- TODO: validate that it is not tab
			if self.lexer:peek() and self.lexer:peek().kind == "SEP" then
				local sep = self.lexer:next()
			end
			-- when the value is on the next line
			local has_empty_val = false
			if self.lexer:peek() and self.lexer:peek().kind == "NL" then
				self.lexer:next() -- skip nl
				local next_indent = indent
				if self.lexer:peek() and self.lexer:peek().kind == "SEP" then
					local sep = self.lexer:next()
					next_indent = #sep.val
					if next_indent < indent then
						break
					elseif next_indent == indent and self.lexer:peek().kind == "VAL" then
						table.insert(tokens, { kind = "VAL", val = "" })
						has_empty_val = true
					end
				end
				if not has_empty_val then
					local res = self:block_node(next_indent)
					if self.lexer:peek() and self.lexer:peek().kind == "SEP" then
						local sep = self.lexer:peek()
						if #sep.val > indent then
							return nil,
								self.lexer:error(
									"wrong indentation: should be " .. indent .. " but is " .. #sep.val,
									sep
								)
						elseif #sep.val < indent then
							self:push(tokens, res)
							break
						end
						self.lexer:next()
					end
					self:push(tokens, res)
				end
			end
		elseif token.kind == "COMPLEX" then
			assert(self.lexer:peek().kind == "SEP")
			self.lexer:next()
			local val = self:block_node(self.lexer:peek().col)
			self:push(tokens, val)
			-- assert(self.lexer:peek().kind == "SEP")
			-- self.lexer:next()
			-- error("found complex: " .. self.lexer:peek().kind)
		elseif token.kind == "START_DOC" or token.kind == "END_DOC" then
			self.lexer:rewind()
			break
		elseif
			token.kind == "ANCHOR"
			and self.lexer:peek()
			and self.lexer:peek().kind == "NL"
			and self.lexer:peek(2)
			and self.lexer:peek(2).kind == "SEP"
			and #self.lexer:peek(2).val == indent
		then
			table.insert(tokens, { kind = "VAL", val = "", anchor = token })
		else
			self.lexer:rewind()
			local child = self:block_node(indent)
			self:push(tokens, child)
		end
		token = self.lexer:next()
	end
	table.insert(tokens, { kind = "-MAP" })
	table.remove(self.state)
	return tokens
end

function Parser:bare(indent)
	local childs = {}
	local token = self.lexer:peek()
	while token do
		if token.kind == "SEP" then
			local next = self.lexer:next()
			-- assert(#next.val == indent)
		elseif token.kind == "START_DOC" then
			break
		elseif token.kind == "END_DOC" then
			break
		elseif token.kind == "..." then
			break
		elseif token.kind == "NL" then
			self.lexer:next()
		else
			local child, mes = self:block_node(indent)
			if child then
				self:push(childs, child)
			else
				return nil, mes
			end
			-- skip empty lines
			while token and token.kind == "NL" do
				token = self.lexer:next()
			end
		end
		token = self.lexer:peek()
	end
	if #childs == 0 then
		self:push(self.tokens, { { kind = "VAL", indent = 0, val = "" } })
	else
		self:push(self.tokens, childs)
	end
	return 1
end

function Parser:directive()
	local token = self.lexer:peek()
	while token do
		if token.type == "GLOBAL_TAG" then
			self.global_tag = self.lexer:next().val
		elseif token.kind == "DIRECTIVE" then
			self.lexer:next()
			token = self.lexer:peek()
			if token.kind == "VAL" then
				token = self.lexer:peek()
				if token.kind == "NL" then
					self.lexer:next()
					break
				else
					error("unknown directive token: " .. self.lexer:peek().kind)
				end
			else
				error("unknown start directive token: " .. self.lexer:peek().kind)
			end
		else
			break
		end
		token = self.lexer:peek()
	end
end

function Parser:parse()
	table.insert(self.tokens, { kind = "+STR" })
	local token = self.lexer:peek()
	--skip trailing empty lines
	while token.kind == "NL" do
		self.lexer:next()
		token = self.lexer:peek()
	end
	assert(token.kind == "SEP")
	local indent = #token.val
	self.lexer:next()
	token = self.lexer:peek()
	local res = 1
	local mes
	while token do
		if token.kind == "DIRECTIVE" then
			self:directive()
		elseif token.kind == "YAML" then
			local version = self.lexer:next()
		elseif self.lexer:peek() and self.lexer:peek().kind == "START_DOC" then
			self.lexer:next()
			table.insert(self.tokens, { kind = "+DOC ---" })
			res, mes = self:bare(indent)
			if self.lexer:peek() and self.lexer:peek().kind == "END_DOC" then
				self.lexer:next()
				table.insert(self.tokens, { kind = "-DOC ..." })
			else
				table.insert(self.tokens, { kind = "-DOC" })
			end
		elseif token.kind == "NL" or token.kind == "SEP" then
			self.lexer:next()
		else
			table.insert(self.tokens, { kind = "+DOC" })
			res, mes = self:bare(indent)
			if self.lexer:peek() and self.lexer:peek().kind == "END_DOC" then
				self.lexer:next()
				table.insert(self.tokens, { kind = "-DOC ..." })
			else
				table.insert(self.tokens, { kind = "-DOC" })
			end
		end
		if not res then
			return res, mes
		end
		token = self.lexer:peek()
	end
	table.insert(self.tokens, { kind = "-STR" })
	return 1
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
					(t.tag and t.tag.val or ""),
					(t.anchor and "&" .. t.anchor.val .. " " or ""),
					(t.type and t.type or ":"),
					escape((t.val or ""))
				)
			)
		elseif t.kind == "ALIAS" then
			table.insert(res, string.format("=ALI *%s", t.val))
		else
			table.insert(
				res,
				string.format(
					"%s%s%s",
					t.kind,
					(t.tag and " " .. self:parse_tag(t.tag.val) or ""),
					(t.anchor and " &" .. t.anchor.val or "")
				)
			)
		end
	end
	table.insert(res, "")
	return table.concat(res, "\n")
end

return {
	html = function(content)
		local lexer = Lexer:new(content)
		lexer:lexme()
		-- print(to_string(lexer.tokens))
		return lexer:html()
	end,
	dump = function(content)
		local lexer = Lexer:new(content)
		lexer:lexme()
		local parser = Parser:new(lexer)
		local res, mes = parser:parse()
		if not res then
			return res, mes
		end
		return tostring(parser)
	end,
}
