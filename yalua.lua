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

	-- if col == 0 then
	-- 	self.indent = #sep
	-- end
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
	local last_indent_no_tab = 0
	local final_indent = hint
	local empty_indent = 0
	assert(self:peek_char() == "\n")
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
			last_indent_no_tab = self:peek_sep()
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
	return token
end

---@return Token|nil
---@return string|nil
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
		elseif self.flow_level > 0 and char == ":" then
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
		elseif
			(char == "-" or char == ":")
			and (self:peek_char(2) == " " or self:peek_char(2) == "\n" or self:peek_char(2) == "\t")
		then
			local row, col = self.row, self.col
			char = self:next_char()
			-- skip whitespace
			while self:peek_char() and self:peek_char() == " " or self:peek_char() == "\t" do
				self:next_char()
			end
			-- check for comment
			if self:peek_char() == "#" then
				self:to_eol()
			end
			if char == "-" then
				self.state = "DASH"
				return self:create_token("DASH", char, row, col)
			elseif char == ":" then
				self.state = "COLON"
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
				elseif self.flow_level > 0 and self:peek_char() and match("{}[]:,", self:peek_char()) then
					break
				elseif
					self:peek_char() == ":"
					and (self:peek_char(2) == " " or self:peek_char(2) == "\n" or self:peek_char(2) == "\t")
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
		table.insert(self.tokens, token)
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
	local last_nl = false
	for i, line in ipairs(token.val) do
		if token.type == '"' and string.match(line, "\\$") then
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

function Parser:folded(token, indent, folded)
	local lines = {}
	assert(token.kind == "VAL")
	table.insert(lines, token.val)
	while self.lexer:peek() do
		if self.lexer:peek().kind == "VAL" then
			if lines[#lines] and lines[#lines] ~= "\n" then
				table.insert(lines, " " .. self.lexer:next().val)
			else
				table.insert(lines, self.lexer:next().val)
			end
			if self.lexer:peek().kind == "COLON" then
				return nil, self.lexer:error("invalid multiline plain key", self.lexer:peek())
			end
		elseif self.lexer:peek().kind == "SEP" then
			if not folded and #self.lexer:peek().val <= indent then
				if self.lexer:peek(2) and self.lexer:peek(2).kind == "NL" then
					table.insert(lines, "\n")
					self.lexer:next(2)
				elseif
					self.lexer:peek(2)
					and self.lexer:peek(2).kind == "VAL"
					and trim(self.lexer:peek(2).val) == ""
				then
				else
					break
				end
			elseif folded and #self.lexer:peek().val < indent then
				break
			end
			self.lexer:next()
		elseif self.lexer:peek().kind == "NL" then
			if not self.lexer:peek(2) then
				break
			elseif not folded and self.lexer:peek(2).kind == "SEP" and #self.lexer:peek().val <= indent then
				break
			elseif folded and self.lexer:peek(2).kind == "SEP" and #self.lexer:peek(2).val < indent then
				break
			end
			self.lexer:next()
		else
			break
		end
	end
	return table.concat(lines, "")
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
					table.insert(
						lines,
						"\n" .. string.rep(" ", line.indent - indent - self:leading_tabs(line.val)) .. line.val
					)
					first_content_line = false
					last_indent = line.indent
				elseif line.empty then
					table.insert(lines, sep .. string.sub(line.val, indent + 1))
				else
					table.insert(
						lines,
						sep .. string.rep(" ", line.indent - indent - self:leading_tabs(line.val)) .. line.val
					)
					first_content_line = false
				end
			end
		else
			lines = {}
			if line.empty then
				table.insert(lines, string.sub(line.val, line.indent + 1) .. "\n")
				last_empty = true
			else
				table.insert(lines, string.rep(" ", line.indent - indent) .. line.val)
				first_content_line = false
			end
		end
	end
	-- remove trailing newlines
	if token.chomping ~= "KEEP" then
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
		if token.chomping == "KEEP" then
			result = result .. "\n"
		elseif token.chomping ~= "STRIP" and string.sub(result, #result) ~= "\n" then
			result = result .. "\n"
		end
	end
	-- return result
	return result
end

function Parser:block_node(indent, folded)
	local state = "STATE"
	for _, s in ipairs(self.state) do
		state = state .. " > " .. s
	end
	local token = self.lexer:next()
	while token do
		if token.kind == "VAL" then
			-- self.anchor = nil
			if self.lexer:peek().kind == "COLON" then
				if self.anchor[#self.anchor] and self.anchor[#self.anchor].row == token.row then
					token.anchor = table.remove(self.anchor)
				end
				return self:map(indent, token)
			else
				local anchor = table.remove(self.anchor)
				local val = self:folded(token, indent, folded)
				local tagref = self.tagref -- TODO: tag
				self.tagref = nil
				return { { kind = "VAL", val = val, tag = tagref, anchor = anchor } }
			end
		elseif token.kind == "QUOTED" then
			local res = self:quoted(token)
			local val = { kind = "VAL", val = res, tag = self.tagref, type = token.type }
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
					val = self:literal(token),
					type = ">",
					tag = self.tagref,
					anchor = table.remove(self.anchor),
				},
			}
		elseif token.kind == "LITERAL" then
			return {
				{
					kind = "VAL",
					val = self:literal(token),
					type = "|",
					tag = self.tagref,
					anchor = table.remove(self.anchor),
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
			self.tagref.val = self:parse_tag(self.tagref.val)
		elseif token.kind == "ANCHOR" then
			-- assert(self.anchor == nil)
			table.insert(self.anchor, token)
		elseif token.kind == "ALIAS" then
			local alias = { kind = "ALIAS", val = token.val, tag = self.tagref }
			if self.lexer:peek().kind == "SEP" then
				self.lexer:next()
			end
			if self.lexer:peek().kind == "COLON" then
				return self:map(indent, token)
			else
				return { alias }
			end
		elseif token.kind == "COMPLEX" then
			assert(self.lexer:peek().kind == "SEP")
			local tagref = self.tagref
			self.tagref = nil
			local key = self:block_node(self.lexer:peek().col, false)
			return self:map(indent, key, tagref)
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

function Parser:flow_map(indent)
	local tokens = {}
	table.insert(tokens, { kind = "+MAP {}", anchor = table.remove(self.anchor) })
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
			table.insert(tokens, { kind = "VAL", val = val.val, tag = self.tagref, anchor = table.remove(self.anchor) })
			self.tagref = nil
		elseif token.kind == "NL" then
			self.lexer:next()
		elseif token.kind == "ANCHOR" then
			table.insert(self.anchor, self.lexer:next())
		elseif token.kind == "TAGREF" then
			self.tagref = self.lexer:next()
			self.tagref.val = self:parse_tag(self.tagref.val)
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
		elseif token.kind == "TAGREF" then
			self.tagref = self.lexer:next()
			self.tagref.val = self:parse_tag(self.tagref.val)
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
			while self.lexer:peek() and self.lexer:peek().kind ~= "FLOW_COLON" do
				local next_val = self.lexer:next()
				if next_val.kind == "VAL" then
					val.val = val.val .. " " .. next_val.val
				end
			end
			self.lexer:next()
			table.insert(tokens, { kind = "+MAP {}" })
			if val and val.kind == "VAL" then
				table.insert(tokens, { kind = "VAL", val = val.val })
			else
				table.insert(tokens, { kind = "VAL", val = "" })
			end
			val = self.lexer:next()
			val = self.lexer:next()
			if val and val.kind == "VAL" then
				table.insert(tokens, { kind = "VAL", val = val.val })
			else
				table.insert(tokens, { kind = "VAL", val = "" })
			end
			table.insert(tokens, { kind = "-MAP" })
		elseif token.kind == "ANCHOR" then
			table.insert(self.anchor, self.lexer:next())
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
				local child, mes = self:sequence(self.lexer:peek().col)
				if not child then
					return nil, mes
				end
				if self.lexer:peek() and self.lexer:peek().kind == "SEP" then
					if #self.lexer:peek().val < indent then
						break
					elseif #self.lexer:peek().val > indent then
						local sep = self.lexer:next()
						return nil,
							self.lexer:error("wrong indentation: should be " .. indent .. " but is " .. #sep.val, sep)
					end
				end
				self:push(tokens, child)
			elseif self.lexer:peek() and self.lexer:peek().kind == "NL" then
				self.lexer:next()
				local new_indent
				if self.lexer:peek() and self.lexer:peek().kind == "SEP" then
					new_indent = #self.lexer:next().val
					-- TODO local child = self:block_node(new_indent)
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
			table.insert(tokens, { kind = "VAL", val = "", anchor = self.lexer:next() })
		else
			local val = self:block_node(token.col, true)
			self:push(tokens, val)
		end
		token = self.lexer:peek()
	end
	table.insert(tokens, { kind = "-SEQ" })
	table.remove(self.state)
	return tokens
end

function Parser:map(indent, key_token, tag) -- TODO: is tag necessary, or could this be done with the key_token
	local tokens = {}
	table.insert(tokens, { kind = "+MAP", tag = (tag and tag or self.tagref), anchor = table.remove(self.anchor) })
	self.tagref = nil
	-- self.anchor = nil
	local token = self.lexer:next()
	if self.lexer:peek() and self.lexer:peek().kind == "SEP" then
		self.lexer:next()
	end
	if
		self.lexer:peek()
		and self.lexer:peek().kind == "ANCHOR"
		and self.lexer:peek(2)
		and self.lexer:peek(2).kind == "NL"
		and self.lexer:peek(3)
		and self.lexer:peek(3).kind == "SEP"
		and #self.lexer:peek(3).val > indent
	then
		-- assert(self.anchor == nil)
		table.insert(self.anchor, self.lexer:next())
	end
	self:push(tokens, key_token)
	local vals = 0
	while token do
		if token.kind == "VAL" then
			local val, mes = self:folded(token, indent, false)
			if not val then
				return val, mes
			end
			table.insert(tokens, { kind = "VAL", val = val, anchor = table.remove(self.anchor) })
			vals = (vals + 1) % 2
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
				local _ = self.lexer:next()
			end
			-- it is an empty key
			if vals == 1 then
				table.insert(tokens, { kind = "VAL", val = "", anchor = table.remove(self.anchor) })
				vals = (vals + 1) % 2
			end
			if
				self.lexer:peek()
				and self.lexer:peek().kind == "ANCHOR"
				and self.lexer:peek(2)
				and self.lexer:peek(2).kind == "NL"
				and self.lexer:peek(3)
				and self.lexer:peek(3).kind == "SEP"
				and #self.lexer:peek(3).val > indent
			then
				-- assert(self.anchor == nil)
				table.insert(self.anchor, self.lexer:next())
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
						vals = (vals + 1) % 2
					end
				end
				if not has_empty_val then
					local res = self:block_node(next_indent, true)
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
							vals = (vals + 1) % 2
							break
						end
						self.lexer:next()
					end
					self:push(tokens, res)
					vals = (vals + 1) % 2
				end
			end
		elseif token.kind == "COMPLEX" then
			if vals == 0 then
				table.insert(tokens, { kind = "VAL", val = "" })
			end
			-- assert(self.lexer:peek().kind == "SEP")
			self.lexer:next()
			local val = self:block_node(self.lexer:peek().col, true)
			self:push(tokens, val)
			vals = 0
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
			vals = (vals + 1) % 2
		else
			self.lexer:rewind()
			local child = self:block_node(indent)
			self:push(tokens, child)
			vals = (vals + 1) % 2
		end
		token = self.lexer:next()
	end
	if vals == 0 then
		table.insert(tokens, { kind = "VAL", val = "" })
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
			local child, mes = self:block_node(indent, false)
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
			self.primary_tag = self.lexer:next().val
		elseif token.type == "NAMED_TAG" then
			token = self.lexer:next()
			self.named_tags[token.name] = token.val
		elseif token.type == "SECOND_TAG" then
			token = self.lexer:next()
			self.second_tag = token.val
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
	--skip trailing empty lines
	while
		self.lexer:peek()
		and self.lexer:peek().kind == "SEP"
		and self.lexer:peek(2)
		and self.lexer:peek(2).kind == "NL"
	do
		self.lexer:next()
		self.lexer:next()
	end
	local token = self.lexer:peek()
	local indent = (token and #token.val or 0)
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
			self.primary_tag = nil
			self.named_tags = {}
		elseif token.kind == "NL" or token.kind == "SEP" then
			self.lexer:next()
		else
			table.insert(self.tokens, { kind = "+DOC" })
			res, mes = self:bare(indent)
			if self.lexer:peek() and self.lexer:peek().kind == "END_DOC" then
				self.lexer:next()
				table.insert(self.tokens, { kind = "-DOC ..." })
				self.primary_tag = nil
				self.named_tags = {}
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
				string.format(
					"%s%s%s",
					t.kind,
					(t.tag and " " .. t.tag.val or ""),
					(t.anchor and " &" .. t.anchor.val or "")
				)
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

return {
	html = function(content)
		local lexer = Lexer:new(content)
		local mes = lexer:lexme()
		if mes then
			return nil, mes
		end
		-- print(to_string(lexer.tokens))
		return lexer:html()
	end,
	dump = function(content)
		local lexer = Lexer:new(content)
		local mes = lexer:lexme()
		if mes then
			return nil, mes
		end
		local parser = Parser:new(lexer)
		local res, mes = parser:parse()
		if not res then
			return res, mes
		end
		return tostring(parser)
	end,
	decode = function(content)
		local lexer = Lexer:new(content)
		local mes = lexer:lexme()
		if mes then
			return nil, mes
		end
		local parser = Parser:new(lexer)
		local res, mes = parser:parse()
		if not res then
			return res, mes
		end
		return parser:decode()
	end,
	parse = function(path)
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
			return res, mes
		end
		return parser:decode()
	end,
}
