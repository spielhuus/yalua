-- function print() end
local trim = require("str").trim
local rtrim = require("str").rtrim
local ltrim = require("str").ltrim

local Lexer = {}

-- local function print(...) end

-- According to YAML 1.2 Specification, Section 5.7 Escape Characters
-- These are the characters that can follow a backslash `\` within
-- double-quoted scalars to form a valid escape sequence.
local ESCAPED = {
	"0", -- \0 Null char (ASCII 0)
	"a", -- \a Bell char (ASCII 7)
	"b", -- \b Backspace char (ASCII 8)
	"t", -- \t Horizontal tab char (ASCII 9, 0x09)
	"n", -- \n Line feed char (ASCII 10, 0x0A)
	"v", -- \v Vertical tab char (ASCII 11)
	"f", -- \f Form feed char (ASCII 12)
	"r", -- \r Carriage return char (ASCII 13, 0x0D)
	"e", -- \e Escape char (ASCII 27)
	" ", -- \  Space char (ASCII 32, 0x20)
	'"', -- \" Double quote (ASCII 34)
	"/", -- \/ Forward slash (ASCII 47)
	"\\", -- \\ Backslash (ASCII 92)
	"N", -- \N Next Line char (Unicode U+0085)
	"_", -- \_ Non-breaking space char (Unicode U+00A0)
	"L", -- \L Line Separator char (Unicode U+2028)
	"P", -- \P Paragraph Separator char (Unicode U+2029)
	"x", -- \xXX 8-bit hexadecimal escape (requires 2 hex digits)
	"u", -- \uXXXX 16-bit Unicode hexadecimal escape (requires 4 hex digits)
	"U", -- \UXXXXXXXX 32-bit Unicode hexadecimal escape (requires 8 hex digits)
}

local NL = "\n"
local KEY = "KEY"
local CHARS = "CHARS"
local SEQ_START = "+SEQ"
local SEQ_END = "-SEQ"
local MAP_START = "+MAP"
local MAP_END = "-MAP"
local ALIAS = "*"
local ANCHOR = "&"
local STRIP = "-"
local CLIP = ""
local KEEP = "+"
local OK = 0
local ERR = 1

---escape the backslashes
local function escape(str)
	if type(str) == "number" then
		return str
	end
	return (str:gsub("\\", "\\\\"):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\b", "\\b"):gsub("\t", "\\t"))
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

function Lexer:new(iter)
	local o = {}
	self.__index = self
	setmetatable(o, self)
	o.iter = iter
	o.tokens = {}
	o.index = 0
	o.global_tag = "yaml.org,2002:"
	o.named_tag = {}
	local res, mes = o:lexme()
	if res ~= 0 then
		-- print(mes)
		return nil, mes
	else
		return o
	end
end

function Lexer:error(mess)
	assert(mess)
	assert(self.iter.row)
	assert(self.iter.col)
	return "ERROR:"
		.. self.iter.row
		.. ":"
		.. self.iter.col
		.. " "
		.. mess
		.. "\n"
		.. (self.iter:line(self.iter.row) or "") -- TODO last line results in nil
		.. "\n"
		.. string.rep(" ", self.iter.col)
		.. "^"
end

---Get the indentation level
---@return integer number of spaces
function Lexer:indent()
	local i = 0
	while self.iter:peek(i + 1) == " " do
		i = i + 1
	end
	return i
end

---get the indentation of the next line
---@return integer number of spaces
function Lexer:next_indent()
	local i = 1
	while self.iter:peek(i) and self.iter:peek(i) ~= "\n" do
		i = i + 1
	end
	i = i + 1
	local j = 0
	while self.iter:peek(i) and self.iter:peek(i) == " " do
		i = i + 1
		j = j + 1
	end
	return j
end

function Lexer:is_key()
	local index = 1
	while self.iter:peek(index) and self.iter:peek(index) ~= NL do
		if self.iter:peek(index) == '"' or self.iter:peek(index) == "'" then
			local quote = self.iter:peek(index)
			index = index + 1
			local found_quote = false
			while not found_quote and self.iter:peek(index) and self.iter:peek(index) ~= NL do
				if self.iter:peek(index) == quote then
					found_quote = true
					index = index + 1
					break
				elseif self.iter:peek(index) == "\\" then
					index = index + 2
				end
				index = index + 1
			end
			if not found_quote then
				return false
			end
		elseif self.iter:match(": ", index) or self.iter:match(":\t", index) or self.iter:match(":\n", index) then
			return true
		else
			index = index + 1
		end
	end
	return false
end

-- Helper function to check if a character is a valid escape character (excluding hex sequences)
-- This is less efficient than using a set/hash table but uses the list as requested.
function Lexer:is_valid_simple_escape_char(char, list)
	for _, valid_char in ipairs(list) do
		if char == valid_char then
			return true
		end
	end
	return false
end

-- Helper function to check if a character is a hexadecimal digit (0-9, a-f, A-F)
function Lexer:is_hex_digit(char)
	-- Check if char is not nil or empty before accessing byte
	if not char or #char ~= 1 then
		return false
	end
	local byte = string.byte(char)
	return (byte >= 48 and byte <= 57) -- 0-9
		or (byte >= 97 and byte <= 102) -- a-f
		or (byte >= 65 and byte <= 70) -- A-F
end

-- Helper function to check N subsequent hex digits
function Lexer:check_hex_digits(str, index_after_escape_char, count, n)
	if index_after_escape_char + count > n + 1 then -- Check if enough characters remain
		return false, "Incomplete hex escape sequence"
	end
	for i = 1, count do
		if not self:is_hex_digit(string.sub(str, index_after_escape_char + i - 1, index_after_escape_char + i - 1)) then
			return false, "Invalid hex digit in escape sequence"
		end
	end
	return true
end

---Check the escaped characters in the string.
-- Returns true if all escape sequences are valid.
-- Returns nil, error_message if an invalid sequence is found.
-- @param str The string to check (presumably content within double quotes).
-- @return boolean|nil, string|nil
function Lexer:check_escaped(str)
	local i = 1
	local n = #str
	while i <= n do
		local char = string.sub(str, i, i)

		if char == "\\" then
			-- Found an escape character start
			i = i + 1 -- Move to the character *after* the backslash
			if i > n then
				-- Backslash at the very end of the string is invalid
				return nil, "Invalid trailing backslash at position " .. (i - 1)
			end

			local escaped_char = string.sub(str, i, i)

			if escaped_char == "x" then
				local ok, err = self:check_hex_digits(str, i + 1, 2, n)
				if not ok then
					return nil, err .. " following \\x at position " .. (i - 1)
				end
				i = i + 2 -- Skip the two hex digits
			elseif escaped_char == "u" then
				local ok, err = self:check_hex_digits(str, i + 1, 4, n)
				if not ok then
					return nil, err .. " following \\u at position " .. (i - 1)
				end
				i = i + 4 -- Skip the four hex digits
			elseif escaped_char == "U" then
				local ok, err = self:check_hex_digits(str, i + 1, 8, n)
				if not ok then
					return nil, err .. " following \\U at position " .. (i - 1)
				end
				i = i + 8 -- Skip the eight hex digits
			elseif not self:is_valid_simple_escape_char(escaped_char, ESCAPED) then
				-- Check against the list of valid single-character escapes
				return nil, "Invalid escape sequence '\\" .. escaped_char .. "' at position " .. (i - 1)
			end
			-- If it was a valid simple escape (e.g., \n, \t, \\, \"),
			-- 'i' now points to the character *after* the escaped character.
			-- The main loop increment will move past it.
		end

		i = i + 1 -- Move to the next character
	end

	-- If we finished the loop without finding errors
	return true
end

function Lexer:value(str)
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

---Test if line is a comment comment
---skips all white spaces until a comment is found
---@return boolean
function Lexer:is_comment(seek)
	if self.iter:peek() == "#" then
		return true
	end
	local index = seek or 1
	if self.iter:match("\n#") then
		return true
	elseif self.iter:peek() == NL then
		index = index + 1
	end
	while self.iter:peek(index) and self.iter:peek(index) ~= "\n" do
		if self.iter:match(" #", index) then
			return true
		elseif self.iter:peek(index) ~= " " and self.iter:peek(index) ~= "\t" then
			return false
		end
		index = index + 1
	end
	return false
end

---Skip a comment
---@return integer
function Lexer:comment()
	print("consume comment: " .. (self.iter:peek() or "eof"))
	if self.iter:match("\n") then
		self.iter:next()
	end
	while self.iter:peek() ~= "\n" do
		self.iter:next()
	end
	if self:is_comment(2) then
		self.iter:next()
		self:comment()
	end
	self.iter:next()
	while not self.iter:eof() and self.iter:empty_line() do
		self.iter:skip_space()
		self.iter:next()
	end
	self.iter:rewind(1)
	return OK
end

function Lexer:expect_comment()
	if self:is_comment() then
		self:comment()
		return true
	end
	return false
end

---Skip separators like spaces, line breaks ... TODO: skip space?
function Lexer:sep()
	while true do
		if self.iter:peek() == " " then
			self.iter:next()
			if self:is_comment() then
				self:comment()
			end
		elseif self.iter:peek() == "\n" then
			self.iter:next()
		else
			return
		end
	end
end

---Push the values to the tokens
---@param kind string
---@param indent integer
---@param value_type? string
function Lexer:push(kind, indent, value, value_type)
	table.insert(self.tokens, {
		kind = kind,
		indent = indent,
		row = self.iter.row,
		col = self.iter.col,
		value = value,
		type = value_type,
	})
end

---Get the block indentation
---get the indentation of the first non empty line
---@param indent integer The content indentation level.
---@return table|nil
---@return string|nil
function Lexer:block_indent(indent, hint, floating)
	print(
		"block_indent:"
			.. (indent or "nil")
			.. ", floating: "
			.. tostring(floating or "nil")
			.. ", hint: "
			.. (hint or "nil")
			.. " '"
			.. (self.iter:peek() or "eof")
			.. "'"
	)
	local lines = {}
	local content_indentation
	if floating then
		content_indentation = indent
	elseif hint and hint > 0 then
		content_indentation = indent + hint
	end
	local longest_empty_line = 0
	while not self.iter:eof() do
		local line_indent = self:indent()
		print("line indent: " .. line_indent .. ", indent: " .. (content_indentation or "nil"))
		if not floating and not self.iter:empty_line() and line_indent <= indent then
			break
		elseif floating and not self.iter:empty_line() and line_indent < indent then
			break
		elseif content_indentation and not self.iter:empty_line() and line_indent < content_indentation then
			break
		else
			--read the line
			local chars = {}
			while not self.iter:eof() and not self.iter:eol() do
				table.insert(chars, self.iter:next())
			end
			table.insert(lines, table.concat(chars, ""))
			self.iter:next()
			if #trim(table.concat(chars, "")) == 0 then
				longest_empty_line = #chars
			elseif not content_indentation then
				content_indentation = line_indent
				print("set content indentation to: " .. line_indent .. ", longest_empty_line: " .. longest_empty_line)
				if longest_empty_line and line_indent < longest_empty_line then
					return nil, self:error("Wrong indentation, found longer empty line before")
				end
			end
		end
	end
	print("content indentation: " .. (content_indentation or "nil"))
	local fin_indent = content_indentation
	if not fin_indent then
		fin_indent = longest_empty_line
	end
	print("fin_indent:" .. fin_indent)
	-- remove the indentation spaces
	for i, line in ipairs(lines) do
		lines[i] = string.sub(line, fin_indent + 1)
	end
	return lines
end

function Lexer:scalar(indent, floating)
	print("scalar : " .. indent .. ", floating: " .. (tostring(floating)))
	local chars = {}
	while self.iter:peek() and self.iter:peek() ~= NL do
		if self.iter:match(" #") or self.iter:match("\t#") then
			self:comment()
			break
		end
		table.insert(chars, self.iter:next())
	end

	print("search for more lines: " .. indent .. " " .. self:next_indent())
	local txt = trim(table.concat(chars, ""))
	if floating and self:next_indent() >= indent then
		self.iter:next()
		local lines, mes = self:block_indent(indent, nil, floating)
		if not lines then
			return ERR, mes
		end
		print(require("str").to_string(lines))
		for _, line in ipairs(lines) do
			if line ~= "" then
				print("add line (floating) '" .. string.sub(line, indent) .. "'")
				txt = txt .. " " .. line
			end
		end
		self.iter:rewind(1)
	elseif self:next_indent() > indent then
		print("lines bigger: " .. tostring(self:is_key()) .. ". next: '" .. self.iter:peek() .. "'")
		self.iter:next()
		if self:is_key() then
			self.iter:skip_space()
			return ERR, self:error("invalid multiline plain key")
		end
		local lines, mes = self:block_indent(indent, nil, floating)
		if not lines then
			return ERR, mes
		end
		for _, line in ipairs(lines) do
			if line ~= "" then
				print("add line '" .. string.sub(line, indent) .. "'")
				txt = txt .. " " .. line
			end
		end
		self.iter:rewind(1)
	end
	print("scalar: " .. escape(txt))
	local res, mes = self:check_escaped(txt)
	if not res then
		return ERR, self:error(mes)
	end
	self:push(CHARS, indent, txt)
	return OK
end

function Lexer:scalar_lines(indent)
	print("scalar lines: " .. indent)
	local lines = {}
	while not self.iter:eof() do
		if self.iter:empty_line() then
			local line = {}
			while not self.iter:eol() do
				table.insert(line, self.iter:next())
			end
			table.insert(lines, table.concat(line, ""))
			self.iter:next()
		elseif self:indent() < indent then
			return lines
		else
			local chars = {}
			while not self.iter:eol() do
				table.insert(chars, self.iter:next())
			end
			self.iter:next()
			table.insert(lines, table.concat(chars, ""))
		end
	end
	return lines
end

function Lexer:quoted()
	local lines = {}
	local quote = self.iter:next()
	local chars = {}
	while not self.iter:eof() do
		if self.iter:peek() == quote then
			self.iter:next()
			-- quotes are escaped by repeating them
			if self.iter:peek() == quote then
				table.insert(chars, self.iter:next())
			else
				break
			end
		elseif self.iter:peek() == "\n" then
			self.iter:next()
			table.insert(lines, table.concat(chars, ""))
			chars = {}
		elseif self.iter:peek() == "\\" then
			local bslash = self.iter:next()
			if self.iter:peek() == "\n" then
				self.iter:next()
			elseif self.iter:peek() == " " then
				self.iter:next()
			elseif self.iter:peek() == "n" then
				self.iter:next()
				table.insert(chars, "\n")
			else
				table.insert(chars, bslash)
				table.insert(chars, self.iter:next())
			end
		else
			table.insert(chars, self.iter:next())
		end
	end
	table.insert(lines, table.concat(chars, ""))
	-- addup lines
	local txt
	local after_nl = false

	local function is_empty(l)
		local pos = 1
		while pos < #l do
			if string.sub(l, pos + 1, pos + 1) ~= " " and string.sub(l, pos + 1, pos + 1) ~= "\t" then
				return false
			end
			pos = pos + 1
		end
		return true
	end

	print(">>>" .. require("str").to_string(lines))
	for i, line in ipairs(lines) do
		print("quoted: " .. tostring(after_nl) .. " " .. require("str").to_string(escape(line)))
		if not txt then
			print("insert first line: '" .. rtrim(line, true) .. "'")
			txt = rtrim(line, true)
		elseif is_empty(line) then
			print("found empty line")
			if i == #lines then
				txt = txt .. " "
			else
				txt = txt .. NL
			end
		else
			print("default ")
			if string.sub(txt, #txt) == NL then
				txt = txt .. trim(line)
			elseif #lines == i then
				txt = txt .. " " .. ltrim(line)
			else
				txt = txt .. " " .. trim(line)
			end
		end
		print("='" .. escape(txt) .. "'")
	end
	local arr = {} -- TODO: is it neccessary to create an array from the string
	for char in txt:gmatch(".") do
		table.insert(arr, char)
	end
	return arr
end

---Get the folded block attributes.
---@return string|nil the chomping inddicator or nil on error
---@return number|string the indentation indicator or the error message
function Lexer:folded_attrs()
	local indent = 0
	local chopped = CLIP
	while self.iter:peek() and self.iter:peek() ~= NL do
		if self.iter:peek() == STRIP then
			chopped = STRIP
			self.iter:next()
		elseif self.iter:peek() == KEEP then
			chopped = KEEP
			self.iter:next()
		elseif tonumber(self.iter:peek()) then
			indent = tonumber(self.iter:peek()) or 0
			self.iter:next()
		elseif self:is_comment() then
			self:comment()
		else
			return nil, self:error("Unknown literal attribute: '" .. self.iter:peek() .. "'")
		end
	end
	-- assert(self.iter:peek() == NL)
	self.iter:next()
	return chopped, indent
end

---@return string|number the chomping inddicator or nil on error
---@return string|nil the indentation indicator or the error message
function Lexer:folded(indent)
	assert(self.iter:peek() == ">")
	self.iter:next()
	local chopped, indent_hint = self:folded_attrs()
	if chopped == nil then
		assert(type(indent_hint) == "string")
		return ERR, indent_hint
	end
	local lines, mes = self:block_indent(indent, indent_hint, false)
	if not lines then
		assert(type(mes) == "string")
		return ERR, mes
	end
	print(require("str").to_string(lines))
	local indented = false
	local after_first = false
	local empty_line = false
	local result = ""
	for _, line in ipairs(lines) do
		print("'" .. escape(line) .. "'" .. ", after_first: " .. tostring(after_first))
		if trim(line) == "" then
			print("is empty")
			result = result .. line .. "\n"
			empty_line = true
		elseif not after_first and (string.sub(line, 1, 1) == " " or string.sub(line, 1, 1) == "\t") then
			-- more indented line
			result = result .. line
			indented = true
		elseif string.sub(line, 1, 1) == " " or string.sub(line, 1, 1) == "\t" then
			-- more indented line
			result = result .. "\n" .. line
			indented = true
		else
			if #result == 0 then
				result = line
			else
				if indented then
					result = result .. "\n" .. line
					print("++(indented) " .. line)
					empty_line = false
				elseif empty_line then
					print("++(empty) " .. line)
					empty_line = false
					result = result .. line
				else
					print("++ " .. line)
					result = result .. " " .. line
				end
			end
			after_first = true
			indented = false
		end
	end
	if chopped == CLIP then
		-- If a block scalar consists only of empty lines, then these lines
		-- are considered as trailing lines and hence are affected by chomping.
		if string.match(result, "^\n+$") then
			result = ""
		else
			while string.sub(result, #result) == NL do
				result = string.sub(result, 1, #result - 1)
			end
			result = result .. NL
		end
	elseif chopped == STRIP then
		while string.sub(result, #result) == NL do
			result = string.sub(result, 1, #result - 1)
		end
	end
	print("folded: '" .. escape(result) .. "'")
	return result
end

---@param indent any
---@param floating any
---@return string|number
---@return string|nil
function Lexer:literal(indent, floating)
	assert(self.iter:peek() == "|")
	self.iter:next()
	local chopped, hint = self:folded_attrs()
	if chopped == nil then
		assert(type(hint) == "string")
		return ERR, hint
	end
	local lines, mes = self:block_indent(indent, hint, floating)
	if not lines then
		assert(mes)
		return ERR, mes
	end
	print("Literal Lines:" .. require("str").to_string(lines))
	local indented = false
	local after_first = false
	local empty_line = false
	local result = ""
	for _, line in ipairs(lines) do
		print("++ empty_line: " .. tostring(empty_line) .. " " .. line)
		if line == "" then
			-- TODO if after_first then
			result = result .. "\n"
			empty_line = true
			-- end
		elseif after_first and string.sub(line, 1, 1) == " " or string.sub(line, 1, 1) == "\t" then
			-- more indented line
			result = result .. line .. "\n"
			indented = true
		else
			if #result == 0 then
				result = line .. NL
			else
				if indented then
					result = result .. line .. "\n"
				elseif empty_line then
					empty_line = false
					result = result .. line .. NL
				else
					print("else")
					result = result .. line .. "\n"
				end
			end
			print("== '" .. escape(result) .. "'")
			after_first = true
			indented = false
		end
	end
	print("SUM: " .. tostring(chopped) .. " " .. escape(result))
	if chopped == STRIP then
		while string.sub(result, #result) == NL do
			result = string.sub(result, 1, #result - 1)
		end
	elseif chopped == KEEP then
		result = result
	else
		while string.sub(result, #result) == NL do
			result = string.sub(result, 1, #result - 1)
		end
		result = result .. NL
	end
	self.iter:rewind(1)
	return result
end

function Lexer:tag_anchor_alias(indent)
	local found = true
	local last_found
	while found do
		if self.iter:match("*") then
			self:alias(indent)
			last_found = "*"
		elseif self.iter:match("&") then
			self:anchor(indent)
			last_found = "&"
		elseif self.iter:match("!") then
			self:tag(indent)
			last_found = "!"
		else
			found = false
		end
		self.iter:skip_space()
	end
	return last_found
end

function Lexer:alias(indent)
	self.iter:next()
	local alias = {}
	while self.iter:peek() ~= " " and self.iter:peek() ~= NL do
		table.insert(alias, self.iter:next())
	end
	self:push(ALIAS, indent, table.concat(alias, ""))
	if self.iter:match(" #") then
		self:comment()
	end
end

function Lexer:anchor(indent)
	assert(indent)
	self.iter:next()
	local anchor = {}
	while self.iter:peek() ~= " " and self.iter:peek() ~= NL do
		table.insert(anchor, self.iter:next())
	end
	self:push(ANCHOR, indent, table.concat(anchor, ""))
end

function Lexer:tag(indent)
	local tag_text = {}
	print("start tag: " .. self.iter:peek())
	assert(self.iter:peek() == "!")
	table.insert(tag_text, self.iter:next())

	if self.iter:peek() == "!" then
		table.insert(tag_text, self.iter:next())
		local char = self.iter:peek()
		while char:match("%w") or char == "-" do
			table.insert(tag_text, self.iter:next())
			char = self.iter:peek()
		end
		print("shorthand tag: " .. table.concat(tag_text, ""))
		self:push("!", indent, table.concat(tag_text, ""))
		return OK
	else
		while self.iter:peek() ~= "\n" and self.iter:peek() ~= " " do
			table.insert(tag_text, self.iter:next())
		end
		while self.iter:peek() == " " do
			self.iter:next()
		end
		self:push("!", indent, table.concat(tag_text, ""))
	end
	return OK
end

function Lexer:check_no_content()
	while self.iter:peek() and self.iter:peek() ~= NL do
		if self.iter:match("# ") then
			return OK
		elseif self.iter:peek() ~= " " then
			return ERR, self:error("Unexpected content after flow block: " .. self.iter:peek())
		end
		self.iter:next()
	end
	return OK
end

function Lexer:flow(indent)
	local level = 0
	local res, mes = OK, nil
	while not self.iter:eof() do
		if self.iter:match("{") then
			print("start flow map")
			self.iter:next()
			self:sep()
			level = level + 1
			res, mes = self:flow_map(indent)
		elseif self.iter:match("}") then
			self.iter:next()
			level = level - 1
			if level == 0 then
				res, mes = self:check_no_content()
				return res, mes
			end
		elseif self.iter:match("[") then
			self.iter:next()
			self:sep()
			level = level + 1
			res, mes = self:flow_seq(level)
		elseif self.iter:match("]") then
			self.iter:next()
			level = level - 1
			if level == 0 then
				res, mes = self:check_no_content()
				return res, mes
			end
		else
			error("unknown character '" .. self.iter:next() .. "'")
		end
		if res == ERR then
			return res, mes
		end
	end
	error("unreachable")
end

---lookahead if the flow is a mapping key
---@return boolean
function Lexer:flow_is_key()
	local index = 0
	local count = 0
	while self.iter:peek(index) do
		if self.iter:peek(index) == "}" then
			count = count - 1
			if count == 0 then
				break
			end
		elseif self.iter:peek(index) == "]" then
			count = count - 1
			if count == 0 then
				break
			end
		elseif self.iter:peek(index) == "[" then
			count = count + 1
		elseif self.iter:peek(index) == "{" then
			count = count + 1
		end
		index = index + 1
	end
	if self.iter:peek(index + 1) == ":" then
		return true
	end
	return false
end

---Parse a flow sequence
---@param indent integer
---@return integer
---@return string|nil
function Lexer:flow_seq(indent)
	print("collection")
	local chars = {}
	local chars_type
	self:push("+SEQ []", 0, nil)
	while not self.iter:eof() do
		print("SEQ[] '" .. self.iter:peek() .. "'")
		if self.iter:match("]") then
			print("close")
			if chars and #chars > 0 then
				print("VL: " .. table.concat(chars, ""))
				if trim(table.concat(chars, "")) == "-" then
					return ERR, self:error("Unexpected character in sequence: " .. table.concat(chars, ""))
				end
				self:push(CHARS, 0, trim(table.concat(chars, "")))
			end
			self:push("-SEQ", 0, nil)
			return OK
		elseif self.iter:match(",") then
			print("sep")
			if chars then
				if #chars == 0 then
					return ERR, self:error("Empty sequence entry")
				end
				print("VL: '" .. table.concat(chars, "") .. "'")
				self:push(CHARS, 0, trim(table.concat(chars, "")), chars_type)
				chars_type = nil
			end
			self.iter:next()
			self:sep()
			chars = {}
		elseif self.iter:match("&") then
			self:anchor(indent)
			self.iter:skip_space()
		elseif self.iter:match("[") then
			self.iter:next()
			self:flow_seq(indent + 1)
			assert(self.iter:peek() == "]", "expected ] but was " .. self.iter:peek())
			self.iter:next()
			chars = nil
		elseif self.iter:match("{") then
			self.iter:next()
			self:flow_map(indent + 1)
			assert(self.iter:peek() == "}")
			self.iter:next()
			chars = nil
		elseif self.iter:match(": ") then
			print("key")
			-- map in sequence
			if self.tokens[#self.tokens].kind == "&" then
				table.insert(self.tokens, #self.tokens, { kind = "+MAP {}", indent + 1, nil })
			else
				self:push("+MAP {}", indent + 1, nil)
			end
			self:push(CHARS, indent + 1, trim(table.concat(chars, "")), chars_type)
			self.iter:next(2)
			chars_type = nil
			chars = {}
			while self.iter:peek() and self.iter:peek() ~= "]" and self.iter:peek() ~= "," do
				table.insert(chars, self.iter:next())
			end
			self:push(CHARS, indent + 1, trim(table.concat(chars, "")), chars_type)
			chars_type = nil
			chars = nil
			self:push("-MAP", 0, nil)
		elseif self.iter:match(" #") then
			self:comment()
		elseif self.iter:peek() == "'" or self.iter:peek() == '"' then
			chars_type = self.iter:peek()
			chars = self:quoted()
			self.iter:skip_space()
		else
			if chars then
				table.insert(chars, self.iter:next())
			else
				self.iter:next()
			end
		end
	end
	return ERR, self:error("End of sequence not found.")
end

---Parse a flow map
---@param indent integer
---@return integer
---@return string|nil
function Lexer:flow_map(indent)
	print("+MAP {} " .. indent)
	local chars = nil
	local char_type = nil
	self:push("+MAP {}", indent, nil)
	while not self.iter:eof() do
		if self.iter:match("}") then
			if chars and #trim(table.concat(chars, "")) > 0 then
				self:push(CHARS, indent, trim(table.concat(chars, "")), char_type)
			end
			self:push("-MAP", indent, nil)
			return OK
		elseif self.iter:match("!") then
			self:tag()
			chars = {}
		elseif self.iter:match(":,") then
			if chars then
				self:push(KEY, indent, table.concat(chars, ""))
				self:push(CHARS, indent, "")
			end
			chars = nil
			self.iter:next(2)
			self:sep()
		elseif self.iter:match(": ") or self.iter:match(":\n") then
			if chars then
				self:push(KEY, indent, trim(table.concat(chars, "")), char_type)
				char_type = nil
			end
			chars = nil
			self.iter:next()
			self:sep()
			-- is it an empty value
			if self.iter:peek() == "," or self.iter:peek() == "}" then
				self:push(CHARS, indent, "")
			end
			-- search if it contains another key, means missing comma
			local index = 1
			while self.iter:peek(index) and self.iter:peek(index) ~= "," and self.iter:peek(index) ~= "}" do
				if self.iter:match(": ", index) then
					return ERR, self:error("missing comma in flow mapping")
				end
				index = index + 1
			end
		elseif self.iter:match(",") then
			print("found sep")
			if chars then
				if self.tokens[#self.tokens].kind == KEY then
					print("insert value")
					self:push(CHARS, indent, trim(table.concat(chars, "")), char_type)
					char_type = nil
				else
					self:push(KEY, indent, trim(table.concat(chars, "")), char_type)
					self:push(CHARS, indent, "")
					char_type = nil
				end
			end
			chars = nil
			self.iter:next()
			self:sep()
		elseif self.iter:match('"') or self.iter:match("'") then
			char_type = self.iter:peek()
			chars = self:quoted()
		elseif self.iter:match("&") then
			self:anchor(indent)
			self.iter:skip_space()
		elseif self.iter:match("[") then
			self.iter:next()
			self:flow_seq(indent + 1)
			assert(self.iter:peek() == "]", "expected ] but was " .. self.iter:peek())
			self.iter:next()
			chars = nil
		else
			if not chars then
				chars = {}
			end
			if self.iter:peek() == NL then
				table.insert(chars, " ")
				self.iter:next()
				-- TODO: how can i handle this shit
				-- if self:indent() <= indent then
				-- 	return ERR, self:error("Wrong indentation in flow map")
				-- end
			else
				table.insert(chars, self.iter:next())
			end
		end
	end
	error("unreachable")
end

---@param indent integer
---@return integer
---@return string|nil
function Lexer:complex(indent)
	self:push(MAP_START, indent, nil)
	local res = OK
	local mes
	while not self.iter:eof() do
		print("complex loop: " .. self.iter:peek())
		if self.iter:match("? ") then
			self.iter:next(2)
			res, mes = self:block_node(self:next_indent())
			print("after complex key: " .. (self.iter:peek() or "eof"))
			if self.iter:peek() == NL then
				self.iter:next()
				print("after next: '" .. (self.iter:peek() or "") .. "', indent: " .. self:indent())
				assert(self:indent() == indent, "expected indent " .. indent .. " but found " .. self:indent())
				self.iter:skip_space()
				if self.iter:peek() == ":" then
					print("found dash")
					self.iter:next()
					self.iter:skip_space()
					if self.iter:peek() == NL then
						local next_indent = self:next_indent()
						self.iter:next(next_indent + 1)
						print("complex: call block_node(" .. next_indent .. ", true)")
						res, mes = self:block_node(next_indent, true)
					else
						print("complex: call block_node(" .. self:next_indent() .. ", false)")
						res, mes = self:block_node(self:next_indent())
					end
				else
					print("expected complex key character ':' but found '" .. (self.iter:peek() or "") .. "'")
					self:push(CHARS, indent, "")
				end
				print("<<<<<<<<<<<<<<<<")
			end
		elseif self.iter:peek() == NL then
			self.iter:next()
		elseif self:is_key() then
			local key = {}
			while self.iter:peek() ~= ":" do
				table.insert(key, self.iter:next())
			end
			self:push(KEY, indent, table.concat(key, ""))
			self.iter:next(2)
			res, mes = self:block_node(indent, false)
		else
			error("complex return")
			return res, mes
		end
	end
	self:push(MAP_END, indent, nil)
	return res, mes
end

function Lexer:map(indent)
	print("+MAP " .. indent)
	self:push(MAP_START, indent, nil)
	local chars = {}
	local res = OK
	local mes
	while not self.iter:eof() do
		print("cMap " .. self.iter:peek())
		if self.iter:match("-") then
			self.iter:rewind(1)
			self:push(MAP_END, indent, nil)
			return OK
		elseif self:is_key() then
			self:tag_anchor_alias(indent)
			local key = {}
			if self.iter:peek() == "[" or self.iter:peek() == "{" then
				self:flow(indent)
			elseif self.iter:peek() == '"' or self.iter:peek() == "'" then
				local quote_type = self.iter:peek()
				key = self:quoted()
				print("KEY: '" .. table.concat(key, "") .. "'")
				self:push(KEY, indent, table.concat(key, ""), quote_type)
				self.iter:skip_space()
			else
				while self.iter:peek() ~= ":" do
					table.insert(key, self.iter:next())
				end
				print("KEY: '" .. table.concat(key, "") .. "'")
				self:push(KEY, indent, table.concat(key, ""))
			end
			self.iter:next()
			self.iter:skip_space()
			print("map next char: " .. self.iter:peek())
			if self:tag_anchor_alias(indent) ~= "*" then
				if self.iter:peek() == NL then
					self.iter:next()
					local next_indent = self:indent()
					self.iter:skip_space()
					print("character after nl " .. (self.iter:peek() or "eof"))
					if self.iter:peek() == "#" then
						print("skip comment on new line")
						self:comment()
						next_indent = self:next_indent()
						self.iter:next(next_indent + 1)
					end
					res, mes = self:block_node(next_indent, true)
				elseif self.iter:peek() == "#" then
					self:comment()
					local next_indent = self:next_indent()
					print("found comment:" .. next_indent)
					self.iter:next(next_indent + 1)
					res, mes = self:block_node(next_indent, true)
				elseif self.iter:match(" -") then -- TODO: this is unchecked
					error("unreachable") -- TODO
					-- table.insert(self.tokens, { kind = MAP_END, indent = indent })
					self:push(MAP_END, indent, nil)
					return OK
				else
					print("map: enter block node: " .. indent .. ":" .. self:next_indent())
					res, mes = self:block_node(indent, false)
				end
			end
			if not self.iter:eof() then
				if self:next_indent() < indent then
					self:push(MAP_END, indent, nil)
					-- table.insert(self.tokens, { kind = MAP_END, indent = indent })
					return OK
				end
			end
		elseif self:is_comment() then
			print("root comment")
			self:comment()
		elseif self.iter:match("---") or self.iter:match("...") then
			-- table.insert(self.tokens, { kind = MAP_END, indent = indent })
			self:push(MAP_END, indent, nil)
			return OK
		elseif self.iter:peek() == NL then
			print("MAP NL" .. self.iter.row)
			self.iter:next()
			if self:is_comment() then
				self:comment()
			end
			if self:indent() < indent then
				-- table.insert(self.tokens, { kind = MAP_END, indent = indent })
				self:push(MAP_END, indent, nil)
				print("return MAP")
				return OK
			elseif self:indent() > indent then
				-- if self:is_comment() then
				-- 	self:comment()
				-- else
				local next_indent = self:indent()
				print(self:error(string.format("Wrong indentation: should be %d but is %d", indent, next_indent)))
				self.iter:next(next_indent)
				return ERR, self:error(string.format("Wrong indentation: should be %d but is %d", indent, next_indent))
				-- end
			end
			self.chars = {}
			self.iter:skip_space()
			print("map cont")
		else
			table.insert(chars, self.iter:next())
		end
		if res ~= OK then
			self:push(MAP_END, indent, nil)
			return res, mes
		end
	end
	self:push(MAP_END, indent, nil)
	return OK
end

function Lexer:sequence(indent)
	print("start sequence: " .. indent)
	self:push(SEQ_START, indent, nil)
	local res = OK
	local mes
	while not self.iter:eof() do
		print("seq next entry " .. self.iter.row .. ":" .. self.iter.col)
		if self.iter:match("- ") or self.iter:match("-\t") or self.iter:match("-\n") then
			self.iter:next()
			self.iter:skip_space()
			print("seq: NEXT val: '" .. self.iter:peek() .. "'")
			-- check for empty value
			if self.iter:peek() == NL and (not self.iter:peek(2) or self:next_indent() == indent) then
				self:push(CHARS, indent, "")
			end
			print("seq after'" .. self.iter:peek() .. "'")
			-- search for tag
			if self.iter:peek() == "!" then -- TODO replace with function
				print("tag")
				self:tag(indent)
				self.iter:skip_space()
			end
			--is it an empty value TODO: we have checked above
			if self.iter:peek() == NL and (not self.iter:peek(2) or self:next_indent() == indent) then
				self:push(CHARS, indent, "")
			end
			if self.iter:peek() == NL or self.iter:match("- ") or self.iter:match("-\t") then
				print("seq is NL")
				local next_indent = self:next_indent()
				if self.iter:peek() == NL then
					self.iter:next()
				end
				self.iter:skip_space()
				print("seq: call block node")
				res, mes = self:block_node(next_indent, false)
				print("seq: from block node")
			elseif self:is_key() then
				print("seq: found key")
				-- handle mapping on the same line
				if self:next_indent() > indent then -- TODOO: could this also be col?
					print("call map with next indent: next: " .. self:next_indent() .. ", col: " .. self.iter.col)
					res, mes = self:block_node(self.iter.col, true)
				else
					res, mes = self:block_node(indent, false)
				end
			elseif self.iter:peek() == "!" then
				error("tag")
				self:tag(indent)
			else
				res, mes = self:block_node(indent, false)
			end
		elseif self.iter:match("#") then
			self:comment()
		elseif self.iter:match("---") or self.iter:match("...") then
			self:push(SEQ_END, indent, nil)
			return OK
		elseif self.iter:match(NL) then
			print("NL: " .. self.iter.row .. ":" .. self.iter.col .. " '" .. escape(self.iter:peek()) .. "'")
			local next_indent = self:next_indent()
			print("seq nl, next_indent: " .. next_indent .. ", indent: " .. indent)
			if next_indent < indent then
				self:push(SEQ_END, indent, nil)
				return OK
			elseif next_indent > indent then
				return ERR, self:error("Wrong indentation")
			end
			self.iter:next(next_indent + 1)
		else
			self:push(SEQ_END, indent, nil)
			return OK
		end
		if res ~= OK then
			self:push(SEQ_END, indent, nil)
			return res, mes
		end
	end
	self:push(SEQ_END, indent, nil)
end

---@param indent integer
---@return integer
---@return string|nil
function Lexer:block_node(indent, floating)
	local res
	local mes
	self.iter:skip_space()
	print("block node in: indent:" .. indent .. " '" .. (self.iter:peek() or "eof") .. "'")
	if self:tag_anchor_alias(indent) == ALIAS then
		return OK
	end
	if self.iter:peek() == NL then
		self.iter:next()
		self.iter:skip_space()
	end
	print("after tag_anchor_alias: '" .. (self.iter:peek() or "nil") .. "'")
	if self:is_comment() then
		self:comment()
		self.iter:next()
	end
	while not self.iter:eof() do
		if self.iter:match("- ") or self.iter:match("-\t") or self.iter:match("-\n") then
			res, mes = self:sequence(indent)
			return res, mes
		elseif self.iter:match("[") or self.iter:match("{") then
			if self:flow_is_key() then
				self:map(indent)
			else
				res, mes = self:flow(indent)
				return res, mes
			end
		elseif self.iter:match("|") then
			local next_indent = self:next_indent()
			local literal, message = self:literal(indent, next_indent == indent)
			if literal == ERR then
				assert(type(literal) == "integer" and message)
				return literal, message
			end
			self:push(CHARS, next_indent, literal, "literal")
			return OK
		elseif self.iter:match(">") then
			local next_indent = self:next_indent()
			local folded, message = self:folded(indent)
			if folded == ERR then
				assert(type(folded) == "integer" and message)
				return folded, message
			end
			self:push(CHARS, next_indent, folded, "folded")
			print("after folded: " .. self.iter.row .. ":" .. self.iter.col)
			return OK
		elseif self:is_key() then
			print("block_node: is key")
			res, mes = self:map(indent)
			return res, mes
		elseif self.iter:match("?") then
			res, mes = self:complex(indent)
			return res, mes
		elseif self.iter:peek() == "'" or self.iter:peek() == '"' then
			local quote = self.iter:peek()
			local quoted = table.concat(self:quoted(), "")
			if quote == '"' then
				res, mes = self:check_escaped(quoted)
				if not res then
					return ERR, mes
				end
			end
			self:push(CHARS, indent, quoted, quote)
			return OK
		elseif self.iter:match("---") or self.iter:match("...") then
			return OK
		elseif self.iter:peek() == NL then
			error("no newline expected")
			local next_indent = self:indent()
			if next_indent < indent then
				return 2
			end
		else
			print("search scalar, indent: " .. indent)
			res, mes = self:scalar(indent, floating)
			return res, mes
		end
	end
	return OK
end

function Lexer:bare()
	table.insert(self.tokens, { kind = "+DOC", indent = 0 })
	local res, mes = self:block_node(0, false)
	if res == ERR then
		return res, mes
	end
	return res, mes
end

function Lexer:explicit()
	table.insert(self.tokens, { kind = "+DOC ---", indent = 0 })
	self.iter:next(3)
	if self.iter:peek() == NL then
		self.iter:next()
	end
	if self:is_comment() then
		self:comment()
		self.iter:next()
	end
	local res, mes = self:block_node(0, false)
	if res == ERR then
		return res, mes
	end
	-- check if document is closed
	if self.iter:peek() == NL then
		self.iter:next()
	end
	print("close document: '" .. (self.iter:peek() or "eof") .. "'")
	if self.iter:match("...") then
		if string.sub(self.tokens[#self.tokens].kind, 1, 4) == "+DOC" then
			print("explicit: end DOC ...")
			table.insert(self.tokens, { kind = CHARS, indent = 0, value = "" })
		end
		table.insert(self.tokens, { kind = "-DOC ...", indent = 0 })
	elseif self.tokens[#self.tokens].kind ~= "-DOC" then
		if string.sub(self.tokens[#self.tokens].kind, 1, 4) == "+DOC" then
			table.insert(self.tokens, { kind = CHARS, indent = 0, value = "" })
		end
		print("explicit: end DOC")
		table.insert(self.tokens, { kind = "-DOC", indent = 0 })
	else
		error("unreachable")
	end
	print("end explicit")
	return res, mes
end

function Lexer:directive()
	local chars = {}
	while self.iter:peek() ~= "\n" do
		table.insert(chars, self.iter:next())
	end
	table.insert(self.tokens, { kind = "%", indent = 0, value = table.concat(chars, "") })
	return OK
end

---Implement l-yaml-stream
function Lexer:stream()
	local res = OK
	local mes
	table.insert(self.tokens, { kind = "+STR", indent = 0 })
	while not self.iter:eof() do
		print("stream loop: " .. self.iter.row .. ":" .. self.iter.col .. "'" .. self.iter:peek() .. "'")
		if self.iter:match("---") then
			res, mes = self:explicit()
		elseif self.iter:match("...") then
			self.iter:next(3)
		elseif self.iter:match("\n") then
			print("skip NL")
			self.iter:next()
		elseif self.iter:match("%") then
			res, mes = self:directive()
		elseif self:is_comment() then
			print("is comment")
			res, mes = self:comment()
		else
			table.insert(self.tokens, { kind = "+DOC", indent = 0 })
			res, mes = self:block_node(self:indent(), false)
			-- skip NL
			if not self.iter:eof() and self.iter:peek() == NL then -- TODO the iter should be before the NL
				self.iter:next()
			end
			if self.iter:match("...") then
				if self.tokens[#self.tokens].kind == "+DOC" then
					table.insert(self.tokens, { kind = CHARS, indent = 0, value = "" })
				end
				table.insert(self.tokens, { kind = "-DOC ...", indent = 0 })
			else
				if self.tokens[#self.tokens].kind == "+DOC" then
					table.insert(self.tokens, { kind = CHARS, indent = 0, value = "" })
				end
				print("stream end doc '" .. (self.iter:peek() or "eof") .. "'")
				table.insert(self.tokens, { kind = "-DOC", indent = 0 })
			end
		end
		if res == ERR then
			return res, mes
		end
	end
	table.insert(self.tokens, { kind = "-STR", indent = 0 })
end

---Lex the given document
---@return integer Return On success return 0, otherwise 1
---@return string? Error message
function Lexer:lexme()
	while self.iter:peek() do
		local res, mes = self:stream()
		if res == ERR then
			return res, mes
		end
	end
	return OK
end

function Lexer:parse_tag(tag_value)
	print("parse tag: " .. tag_value)
	local tag_result
	if string.match(tag_value, "^!<!(.+)>$") then -- verbatim tag
		tag_result = string.sub(tag_value, 2)
	elseif string.match(tag_value, "^!(.+)!(.+)$") then
		local k, t = string.match(tag_value, "^!(.*)!(.*)$")
		tag_result = "<" .. self.named_tag[k] .. url_decode(t) .. ">"
	elseif string.match(tag_value, "^!<(.*)>$") then
		tag_result = "<" .. string.match(tag_value, "^!<(.*)>$") .. ">"
	elseif string.match(tag_value, "^!!(.*)") then
		tag_result = "<tag:" .. self.global_tag .. string.match(tag_value, "^!!(.*)") .. ">"
	elseif string.match(tag_value, "^!(.*)") then
		tag_result = "<" .. (self.local_tag and self.local_tag or "!") .. string.match(tag_value, "^!(.*)") .. ">"
	end
	return tag_result
end

function Lexer:__tostring()
	local str = {}
	local anchor, tag
	print(require("str").to_string(self.tokens))
	for t in self:ipairs() do
		if t.kind == CHARS then
			if t.type == "literal" then
				table.insert(
					str,
					string.format("=VAL %s|%s", (anchor and ("&" .. anchor.value .. " ") or ""), escape(t.value))
				)
			elseif t.type == "folded" then
				table.insert(
					str,
					string.format("=VAL %s>%s", (anchor and ("&" .. anchor.value .. " ") or ""), escape(t.value))
				)
			else
				table.insert(
					str,
					string.format(
						"=VAL %s%s%s%s",
						(anchor and ("&" .. anchor.value .. " ") or ""),
						(tag and (self:parse_tag(tag.value) .. " ") or ""),
						(t.type and t.type or ":"),
						escape(self:value(t.value))
					)
				)
			end
			anchor = nil
			tag = nil
		elseif t.kind == KEY then
			if t.value == nil then -- TODOO is this needed?
				table.insert(
					str,
					string.format(
						"=VAL %s%s",
						(anchor and ("&" .. anchor.value .. " ") or ""),
						(tag and (self:parse_tag(tag.value) .. " ") or "")
					)
				)
			else
				table.insert(
					str,
					string.format(
						"=VAL %s%s%s%s",
						(anchor and ("&" .. anchor.value .. " ") or ""),
						(tag and (self:parse_tag(tag.value) .. " ") or ""),
						(t.type and t.type or ":"),
						trim(t.value)
					)
				)
			end
			anchor = nil
			tag = nil
		elseif t.kind == MAP_START then
			local map_tag
			if tag and (tag.indent < t.indent or tag.row < t.row) then
				map_tag = tag.value
				tag = nil
			end
			local map_anchor
			if anchor and (anchor.indent < t.indent or anchor.row < t.row) then
				map_anchor = anchor.value
				anchor = nil
			end
			table.insert(
				str,
				string.format(
					"%s%s%s",
					t.kind,
					(map_tag and (" " .. self:parse_tag(map_tag)) or ""),
					(map_anchor and (" &" .. map_anchor) or "")
				)
			)
		elseif t.kind == ANCHOR then
			anchor = t
		elseif t.kind == ALIAS then
			table.insert(str, string.format("=ALI *%s", (t.value and t.value or "")))
		elseif t.kind == "%" then
			local act_tag = t.value
			if string.match(act_tag, "^%%TAG !(.+)! (.+)$") then
				local key, uri = string.match(act_tag, "^%%TAG !(.+)! (.+)$")
				self.named_tag[key] = uri
			elseif string.match(act_tag, "^%%TAG !! tag:(.*)$") then
				self.global_tag = string.match(act_tag, "^%%TAG !! tag:(.*)$")
			elseif string.match(act_tag, "^%%TAG ! tag:(.*)$") then
				self.local_tag = string.match(act_tag, "^%%TAG ! (.*)$")
			else
				print("TAGDEF: " .. require("str").to_string(act_tag))
			end
		elseif t.kind == "!" then
			tag = t
		else
			table.insert(
				str,
				string.format(
					"%s%s%s",
					t.kind,
					(anchor and (" &" .. anchor.value) or ""),
					(tag and (" " .. self:parse_tag(tag.value)) or "")
				)
			)
			tag = nil
			anchor = nil
		end
	end
	table.insert(str, "")
	return table.concat(str, "\n")
end

function Lexer:ipairs()
	local index = 0
	local tokens = self.tokens
	return function()
		index = index + 1
		if tokens[index] then
			return tokens[index]
		end
	end
end

function Lexer:next()
	self.index = self.index + 1
	if self.index > #self.tokens then
		return nil
	end
	return self.tokens[self.index]
end

function Lexer:match(kind)
	if self.index + 1 > #self.tokens then
		return nil
	end
	return string.sub(self.tokens[self.index + 1].kind, 1, #kind) == kind
end

function Lexer:peek()
	if self.index + 1 > #self.tokens then
		return nil
	end
	return self.tokens[self.index + 1]
end

return Lexer
