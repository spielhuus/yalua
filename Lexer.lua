-- function print() end
local trim = require("str").trim
local rtrim = require("str").rtrim
local ltrim = require("str").ltrim

local Lexer = {}

local NL = "\n"
local KEY = "KEY"
local CHARS = "CHARS"
local SEQ_START = "+SEQ"
local SEQ_END = "-SEQ"
local MAP_START = "+MAP"
local MAP_END = "-MAP"
local ALIAS = "*"
local ANCHOR = "&"

local OK = 0
local ERR = 1

---escape the backslashes
local function escape(str)
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
	print(mess)
	return "ERROR:"
		.. self.iter.row
		.. ":"
		.. self.iter.col
		.. " "
		.. mess
		.. "\n"
		.. self.iter:line(self.iter.row)
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
	while self.iter:peek(i) ~= "\n" do
		i = i + 1
	end
	i = i + 1
	local j = 0
	while self.iter:peek(i) == " " do
		i = i + 1
		j = j + 1
	end
	return j
end

function Lexer:is_key()
	print("is key?")
	local index = 1
	while self.iter:peek(index) and self.iter:peek(index) ~= NL do
		print("is_key loop: " .. index .. " '" .. self.iter:peek(index))
		if self.iter:peek(index) == '"' or self.iter:peek(index) == "'" then
			local quote = self.iter:peek(index)
			index = index + 1
			local found_quote = false
			while not found_quote and self.iter:peek(index) and self.iter:peek(index) ~= NL do
				print("is_key quote loop: " .. index .. " '" .. self.iter:peek(index) .. "'")
				if self.iter:peek(index) == quote then
					found_quote = true
					index = index + 1
					print("end quote, " .. index)
					break
				elseif self.iter:peek(index) == "\\" then
					index = index + 2
				end
				index = index + 1
			end
			if not found_quote then
				print("is_key: closing quote not found")
				return false
			end
			print("is_key: after quote: " .. self.iter:peek(index))
		elseif self.iter:match(": ", index) or self.iter:match(":\t", index) or self.iter:match(":\n", index) then
			print("is_key matches")
			return true
		else
			index = index + 1
		end
		print("is_key next: '" .. self.iter:peek(index) .. "'" .. tostring(self.iter:match(":\n", index)))
	end
	return false
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
	-- print("is_comment: '" .. self.iter:peek(seek) .. "'")
	-- local newline = self.iter:peek(-1) == NL
	-- if newline then
	-- 	error("last was newline")
	-- end
	if self.iter:peek() == "#" then
		return true
	end
	-- print("comment newline:" .. tostring(newline))
	local index = seek or 1
	while self.iter:peek(index) and self.iter:peek(index) ~= "\n" do
		print("+is_comment: '" .. self.iter:peek(index) .. "'")
		-- if self.iter:peek(index) == "#" and (newline or index > 1) then
		if self.iter:match(" #", index) then
			print("is comment return true")
			return true
		elseif self.iter:peek(index) ~= " " and self.iter:peek(index) ~= "\t" then
			print("is comment return false")
			return false
		end
		index = index + 1
	end
	print("end is comment")
	return false
end

---Skip a comment
---@return integer
function Lexer:comment()
	print("consume comment")
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
function Lexer:block_indent(indent, hint, floating)
	print(
		"block_indent:"
			.. indent
			.. ", floating: "
			.. tostring(floating)
			.. ", hint: "
			.. (hint or "nil")
			.. " '"
			.. self.iter:peek()
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
		print("line indent: " .. line_indent)
		if not floating and not self.iter:empty_line() and line_indent <= indent then
			break
		elseif floating and not self.iter:empty_line() and line_indent < indent then
			break
		else
			--read the line
			local chars = {}
			while not self.iter:eol() do
				table.insert(chars, self.iter:next())
			end
			table.insert(lines, table.concat(chars, ""))
			self.iter:next()
			if #trim(table.concat(chars, "")) == 0 then
				longest_empty_line = #chars
			elseif not content_indentation then
				content_indentation = line_indent
			end
		end
	end
	print("content indentation: " .. content_indentation)
	local fin_indent = content_indentation
	if not fin_indent then
		fin_indent = longest_empty_line
	end
	print("fin_indent:" .. fin_indent)
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
		local lines = self:block_indent(indent, nil, floating)
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
		local lines = self:block_indent(indent, nil, floating)
		for _, line in ipairs(lines) do
			if line ~= "" then
				print("add line '" .. string.sub(line, indent) .. "'")
				txt = txt .. " " .. line
			end
		end
		self.iter:rewind(1)
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

function Lexer:folded_attrs()
	local indent = 0
	local chopped = nil
	while self.iter:peek() ~= NL do
		print("next char: " .. self.iter:peek())
		if self.iter:peek() == "-" then
			chopped = "-"
			self.iter:next()
		elseif self.iter:peek() == "+" then
			chopped = "+"
			self.iter:next()
		elseif tonumber(self.iter:peek()) then
			indent = tonumber(self.iter:peek()) or 0
			self.iter:next()
		elseif self:is_comment() then
			self:comment()
		else
			error("unknown literal attribute: " .. self.iter:peek())
		end
	end
	assert(self.iter:peek() == NL)
	self.iter:next()
	print("attrs: " .. indent)
	return chopped, indent
end

function Lexer:folded(indent)
	assert(self.iter:peek() == ">")
	self.iter:next()
	local chopped, indent_hint = self:folded_attrs()
	local lines = self:block_indent(indent, indent_hint, false)
	print(require("str").to_string(lines))
	local indented = false
	local after_first = false
	local empty_line = false
	local result = ""
	for _, line in ipairs(lines) do
		if trim(line) == "" then
			-- if after_first then TODO
			result = result .. "\n"
			empty_line = true
			-- end
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
				elseif empty_line then
					empty_line = false
					result = result .. line
				else
					result = result .. " " .. line
				end
			end
			after_first = true
			indented = false
		end
	end
	if not chopped then
		result = result .. "\n"
	end
	return result
end

function Lexer:literal(indent)
	assert(self.iter:peek() == "|")
	self.iter:next()
	local chopped, hint = self:folded_attrs()
	local lines = self:block_indent(indent, hint, false)
	print("Literal Lines:" .. require("str").to_string(lines))
	local indented = false
	local after_first = false
	local empty_line = false
	local result = ""
	for _, line in ipairs(lines) do
		if line == "" then
			if after_first then
				result = result .. "\n"
				empty_line = true
			end
		elseif after_first and string.sub(line, 1, 1) == " " or string.sub(line, 1, 1) == "\t" then
			-- more indented line
			result = result .. "\n" .. line
			indented = true
		else
			if #result == 0 then
				result = line
			else
				if indented then
					result = result .. "\n" .. line
				elseif empty_line then
					empty_line = false
					result = result .. line
				else
					result = result .. "\n" .. line
				end
			end
			after_first = true
			indented = false
		end
	end
	print("SUM: " .. tostring(chopped) .. " " .. escape(result))
	if chopped == "-" then
		while string.sub(result, #result) == NL do
			result = string.sub(result, 1, #result - 1)
		end
	elseif chopped == "+" then
		result = result .. NL
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

function Lexer:flow()
	local level = 0
	while not self.iter:eof() do
		if self.iter:match("{") then
			print("start flow map")
			self.iter:next()
			self:sep()
			level = level + 1
			self:flow_map()
		elseif self.iter:match("}") then
			self.iter:next()
			level = level - 1
			if level == 0 then
				return OK
			end
		elseif self.iter:match("[") then
			self.iter:next()
			self:sep()
			level = level + 1
			self:flow_seq()
		elseif self.iter:match("]") then
			self.iter:next()
			level = level - 1
			if level == 0 then
				return OK
			end
		else
			error("unknown character '" .. self.iter:next() .. "'")
		end
	end
	error("unreachable")
end

function Lexer:flow_seq()
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
				self:push(CHARS, 0, trim(table.concat(chars, "")))
			end
			self:push("-SEQ", 0, nil)
			return
		elseif self.iter:match(",") then
			print("sep")
			if chars then
				print("VL: " .. table.concat(chars, ""))
				self:push(CHARS, 0, trim(table.concat(chars, "")), chars_type)
				chars_type = nil
			end
			self.iter:next()
			self:sep()
			chars = {}
		elseif self.iter:match(": ") then
			print("key")
			-- map in sequence
			self:push("+MAP {}", 0, nil)
			self:push(CHARS, 0, trim(table.concat(chars, "")), chars_type)
			chars_type = nil
			self.iter:next()
			chars = {}
			while self.iter:peek() and self.iter:peek() ~= "]" and self.iter:peek() ~= "," do
				print("next " .. self.iter:peek())
				table.insert(chars, self.iter:next())
			end
			self:push(CHARS, 0, trim(table.concat(chars, "")), chars_type)
			chars_type = nil
			chars = nil
			self:push("-MAP", 0, nil)
		elseif self.iter:match(" #") then
			print(" #" .. self.iter.row .. ":" .. self.iter.col)
			self:comment()
		elseif self.iter:peek() == "'" or self.iter:peek() == '"' then
			chars_type = self.iter:peek()
			chars = self:quoted()
			self.iter:skip_space()
		else
			table.insert(chars, self.iter:next())
		end
	end
	error("unreachable")
end

function Lexer:flow_map()
	local chars = nil
	self:push("+MAP {}", 0, nil)
	while not self.iter:eof() do
		if self.iter:match("}") then
			if chars then
				self:push(CHARS, 0, trim(table.concat(chars, "")))
			end
			self:push("-MAP", 0, nil)
			return OK
		elseif self.iter:match("!") then
			print("found tag")
			self:tag()
			chars = {}
		elseif self.iter:match(":") then
			if chars then
				self:push(KEY, 0, trim(table.concat(chars, "")))
			end
			chars = nil
			self.iter:next()
			self:sep()
		elseif self.iter:match(",") then
			print("found sep")
			if chars then
				print("insert value")
				self:push(CHARS, 0, trim(table.concat(chars, "")))
			end
			chars = nil
			self.iter:next()
			self:sep()
		else
			if not chars then
				chars = {}
			end
			table.insert(chars, self.iter:next())
		end
	end
	error("unreachable")
end

function Lexer:complex(indent)
	-- table.insert(self.tokens, { kind = MAP_START, indent = indent })
	self:push(MAP_START, indent, nil)
	local res = OK
	local mes
	while not self.iter:eof() do
		print("complex loop: " .. self.iter:peek())
		if self.iter:match("? ") then
			self.iter:next(2)
			res, mes = self:block_node(self:next_indent(), false)
			print("after complex key: " .. self.iter:peek())
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
						res, mes = self:block_node(self:next_indent(), false)
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
			if self.iter:peek() == '"' or self.iter:peek() == "'" then
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
			if self:tag_anchor_alias(indent) == "*" then -- TODO: combine with else
			elseif self.iter:peek() == NL then
				self.iter:next()
				local next_indent = self:indent()
				self.iter:skip_space()
				print("character after nl " .. self.iter:peek())
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
				local next_indent = self:indent()
				print(self:error(string.format("Wrong indentation: should be %d but is %d", indent, next_indent)))
				self.iter:next(next_indent)
				return ERR, self:error(string.format("Wrong indentation: should be %d but is %d", indent, next_indent))
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
	print("sequence: " .. indent)
	self:push(SEQ_START, indent, nil)
	local res = OK
	local mes
	while not self.iter:eof() do
		if self.iter:match("- ") or self.iter:match("-\t") or self.iter:match("-\n") then
			self.iter:next()
			self.iter:skip_space()
			print("seq after'" .. self.iter:peek() .. "'")
			-- search for tag
			if self.iter:peek() == "!" then -- TODO replace with function
				print("tag")
				self:tag(indent)
				self.iter:skip_space()
			end
			if self.iter:peek() == NL or self.iter:match("- ") or self.iter:match("-\t") then
				print("seq is NL")
				local next_indent = self:next_indent()
				if self.iter:peek() == NL then
					self.iter:next()
				end
				self.iter:skip_space()
				print("call block node")
				res, mes = self:block_node(next_indent)
				print("from block node")
			elseif self:is_key() then
				-- handle mapping on the same line
				if self:next_indent() > indent then
					res, mes = self:block_node(self:next_indent())
				else
					res, mes = self:block_node(indent)
				end
			elseif self.iter:peek() == "!" then
				error("tag")
				self:tag(indent)
			else
				res, mes = self:block_node(indent)
			end
		elseif self.iter:match("#") then
			self:comment()
		elseif self.iter:match("---") or self.iter:match("...") then
			self:push(SEQ_END, indent, nil)
			return OK
		elseif self.iter:match(NL) then
			local next_indent = self:next_indent()
			if next_indent < indent then
				self:push(SEQ_END, indent, nil)
				return OK
			elseif next_indent > indent then
				error("bigger indent not implemented: " .. self.iter.row .. ":" .. self.iter.col)
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
			res, mes = self:flow()
			return res, mes
		elseif self.iter:match("|") then
			local next_indent = self:next_indent()
			self:push(CHARS, next_indent, self:literal(indent), "literal")
			return OK
		elseif self.iter:match(">") then
			local next_indent = self:next_indent()
			self:push(CHARS, next_indent, self:folded(indent), "folded")
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
	local res, mes = self:block_node(0)
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
	local res, mes = self:block_node(0)
	if res == ERR then
		return res, mes
	end
	-- check if document is closed
	if self.iter:peek() == NL then
		self.iter:next()
	end
	print("close document: '" .. (self.iter:peek() or "eof") .. "'")
	if self.iter:match("...") then
		table.insert(self.tokens, { kind = "-DOC ...", indent = 0 })
	elseif self.tokens[#self.tokens].kind ~= "-DOC" then
		table.insert(self.tokens, { kind = "-DOC", indent = 0 })
	else
		error("unreachable")
	end
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
		if self.iter:match("---") then
			res, mes = self:explicit()
		elseif self.iter:match("...") then
			self.iter:next(3)
		elseif self.iter:match("\n") then
			self.iter:next()
		elseif self.iter:match("%") then
			res, mes = self:directive()
		elseif self:is_comment() then
			res, mes = self:comment()
		else
			table.insert(self.tokens, { kind = "+DOC", indent = 0 })
			res, mes = self:block_node(0)
			-- skip NL
			if not self.iter:eof() then
				self.iter:next()
			end
			if self.iter:match("...") then
				table.insert(self.tokens, { kind = "-DOC ...", indent = 0 })
			else
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

-- local doc = [[
-- plain: |
--   text
--   lines
-- ]]
-- local iter = require("StringIterator"):new(doc)
-- local lexer = Lexer:new(iter)

return Lexer
