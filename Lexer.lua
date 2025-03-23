-- function print() end
local trim = require("str").trim

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
	local res, mes = o:lexme()
	if res ~= 0 then
		-- print(mes)
		return nil, mes
	else
		return o
	end
end

function Lexer:error(mess)
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
	local index = 1
	while self.iter:peek(index) and self.iter:peek(index) ~= NL do
		if self.iter:match(": ", index) or self.iter:match(":\t", index) or self.iter:match(":\n", index) then
			return true
		end
		index = index + 1
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
	local index = seek or 1
	while self.iter:peek(index) and self.iter:peek(index) ~= "\n" do
		if self.iter:peek(index) == "#" then
			return true
		elseif self.iter:peek(index) ~= " " and self.iter:peek() ~= "\t" then
			return false
		end
		index = index + 1
	end
	return false
end

---Skip a comment
---@return integer
function Lexer:comment()
	while self.iter:peek() ~= "\n" do
		self.iter:next()
	end
	if self:is_comment(2) then
		self.iter:next()
		self:comment()
	end
	return OK
end

---Skip separators like spaces, line breaks ... TODO: skip space?
function Lexer:sep()
	while true do
		if self.iter:peek() == " " then
			self.iter:next()
		elseif self.iter:peek() == "\n" then
			self.iter:next()
		else
			return
		end
	end
end

function Lexer:scalar(indent, floating)
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
		local lines = self:scalar_lines(indent)
		for _, line in ipairs(lines) do
			if line ~= "" then
				print("add line '" .. line .. "'")
				txt = txt .. " " .. line
			end
		end
		self.iter:rewind(1)
	end

	table.insert(self.tokens, {
		kind = CHARS,
		indent = indent,
		row = self.row,
		col = self.col,
		value = txt,
	})
	return OK
end

function Lexer:scalar_lines(indent)
	local lines = {}
	while not self.iter:eof() do
		if self.iter:empty_line() then
			table.insert(lines, "")
			self.iter:next()
		elseif self:indent() < indent then
			return lines
		else
			local chars = {}
			while not self.iter:eol() do
				table.insert(chars, self.iter:next())
			end
			self.iter:next()
			table.insert(lines, string.sub(table.concat(chars, ""), indent + 1))
		end
	end
	return lines
end

function Lexer:quoted(indent)
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
			if self.iter:peek() == "n" then -- TODO
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
	for _, line in ipairs(lines) do
		if not txt then
			txt = line
		else
			txt = txt .. " " .. trim(line, true)
		end
	end
	table.insert(self.tokens, {
		kind = "CHARS",
		indent = indent,
		value = txt,
		type = quote,
	})
	return OK
end

function Lexer:folded(indent)
	local lines = self:scalar_lines(indent)
	print(require("str").to_string(lines))
	local indented = false
	local result = ""
	for _, line in ipairs(lines) do
		if line == "" then
			result = result .. "\n"
		elseif string.sub(line, 1, 1) == " " then
			result = result .. "\n" .. line
			indented = true
		else
			if #result == 0 then
				result = line
			else
				if indented then
					result = result .. "\n" .. line
				else
					result = result .. " " .. line
				end
			end
		end
	end
	result = result .. "\n"
	return result
end

function Lexer:literal(indent)
	local chars = {}
	local lines = {}
	local chopped = false
	assert(self.iter:peek() == "|")
	self.iter:next()
	while self.iter:peek() ~= NL do
		print("next char: " .. self.iter:peek())
		if self.iter:peek() == "-" then
			chopped = true
			self.iter:next()
		elseif self.iter:peek() == "+" then
			chopped = false
			self.iter:next()
		else
			error("unknown literal attribute: " .. self.iter:peek())
		end
	end
	self.iter:next()
	while not self.iter:eof() do
		if self.iter:peek() == NL then
			if self:next_indent() < indent then
				-- conusume last line
				table.insert(lines, string.sub(table.concat(chars, ""), indent + 1))
				if not chopped then
					table.insert(lines, "")
				end
				-- create the text
				local txt = table.concat(lines, NL)
				table.insert(self.tokens, { kind = "CHARS", value = txt, type = "literal", indent = 0 })
				return OK
			else
				self.iter:next()
				table.insert(lines, string.sub(table.concat(chars, ""), indent + 1))
				chars = {}
			end
		else
			table.insert(chars, self.iter:next())
		end
	end
end

function Lexer:alias(indent)
	self.iter:next()
	local alias = {}
	while self.iter:peek() ~= " " and self.iter:peek() ~= NL do
		table.insert(alias, self.iter:next())
	end
	table.insert(self.tokens, { kind = ALIAS, value = table.concat(alias, ""), indent = indent })
	if self.iter:match(" #") then
		self:comment()
	end
end

function Lexer:anchor(indent)
	self.iter:next()
	local anchor = {}
	while self.iter:peek() ~= " " and self.iter:peek() ~= NL do
		table.insert(anchor, self.iter:next())
	end
	table.insert(self.tokens, { kind = ANCHOR, value = table.concat(anchor, ""), indent = indent })
end

function Lexer:tag(indent)
	local tag_text = {}
	print("start tag: " .. self.iter:peek())
	while self.iter:peek() ~= "\n" and self.iter:peek() ~= " " do
		table.insert(tag_text, self.iter:next())
	end
	while self.iter:peek() == " " do
		self.iter:next()
	end
	-- if self.iter:eol() then
	table.insert(self.tokens, {
		kind = "!",
		indent = indent,
		value = table.concat(tag_text, ""),
	})
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
				print("return OK }")
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
				print("return OK")
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
	table.insert(self.tokens, { kind = "+SEQ []" })
	while not self.iter:eof() do
		if self.iter:match("]") then
			if chars and #chars > 0 then
				table.insert(self.tokens, { kind = "CHARS", value = trim(table.concat(chars, "")), indent = 0 })
			end
			table.insert(self.tokens, { kind = "-SEQ" })
			return
		elseif self.iter:match(",") then
			if chars then
				table.insert(self.tokens, { kind = "CHARS", value = trim(table.concat(chars, "")), indent = 0 })
			end
			self.iter:next()
			self:sep()
			chars = {}
		elseif self.iter:match(":") then
			-- map in sequence
			table.insert(self.tokens, { kind = "+MAP {}" })
			table.insert(self.tokens, { kind = "CHARS", value = trim(table.concat(chars, "")), indent = 0 })
			self.iter:next()
			chars = {}
			while self.iter:peek() and self.iter:peek() ~= "]" and self.iter:peek() ~= "," do
				print("next " .. self.iter:peek())
				table.insert(chars, self.iter:next())
			end
			table.insert(self.tokens, { kind = "CHARS", value = trim(table.concat(chars, "")), indent = 0 })
			chars = nil
			table.insert(self.tokens, { kind = "-MAP" })
		else
			table.insert(chars, self.iter:next())
		end
	end
	error("unreachable")
end

function Lexer:flow_map()
	local chars = nil
	table.insert(self.tokens, { kind = "+MAP {}" })
	while not self.iter:eof() do
		if self.iter:match("}") then
			if chars then
				table.insert(self.tokens, { kind = "CHARS", value = trim(table.concat(chars, "")), indent = 0 })
			end
			table.insert(self.tokens, { kind = "-MAP" })
			return OK
		elseif self.iter:match(":") then
			print("dash")
			if chars then
				table.insert(self.tokens, { kind = KEY, value = trim(table.concat(chars, "")), indent = 0 })
			end
			chars = nil
			self.iter:next()
			self:sep()
		elseif self.iter:match(",") then
			if chars then
				table.insert(self.tokens, { kind = "CHARS", value = trim(table.concat(chars, "")), indent = 0 })
				-- table.insert(self.tokens, { kind = "SEP", indent = 0 })
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
	table.insert(self.tokens, { kind = MAP_START, indent = indent })
	local res = OK
	local mes
	while not self.iter:eof() do
		print("complex loop: " .. self.iter:peek())
		if self.iter:match("?") then
			self.iter:next(2)
			res, mes = self:block_node(self:next_indent(), false)
			print("after complex key: " .. self.iter:peek())
			-- print("/////////// what we got so far\n" .. tostring(self))
			if self.iter:peek() == NL then
				self.iter:next()
				print("after next: '" .. (self.iter:peek() or "") .. "', indent: " .. self:indent())
				assert(self:indent() == indent, "expected indent " .. indent .. " but found " .. self:indent())
				if self.iter:peek() == ":" then
					print("found dash")
					self.iter:next()
					self.iter:skip_space()
					if self.iter:peek() == NL then
						local next_indent = self:next_indent()
						self.iter:next(next_indent + 1)
						res, mes = self:block_node(next_indent, true)
					else
						res, mes = self:block_node(self:next_indent(), false)
					end
				else
					print("expected complex key character ':' but found '" .. (self.iter:peek() or "") .. "'")
					table.insert(self.tokens, { kind = "CHARS", value = "" })
				end
			end
		elseif self.iter:peek() == NL then
			self.iter:next()
		else
			return res, mes
		end
	end
	table.insert(self.tokens, { kind = MAP_END, indent = indent })
	return res, mes
end

function Lexer:map(indent)
	print("+MAP " .. indent)
	table.insert(self.tokens, { kind = MAP_START, indent = indent })
	local chars = {}
	local res = OK
	local mes
	while not self.iter:eof() do
		print("cMap " .. self.iter:peek())
		if self.iter:match("-") then
			self.iter:rewind(1)
			table.insert(self.tokens, { kind = MAP_END, indent = indent })
			return OK
		elseif self:is_key() then
			local key = {}
			while self.iter:peek() ~= ":" do
				table.insert(key, self.iter:next())
			end
			print("KEY: " .. table.concat(key, ""))
			table.insert(self.tokens, { kind = KEY, indent = indent, value = table.concat(key, "") })
			self.iter:next()
			self.iter:skip_space()
			if self.iter:match("&") then -- TODO: this is unchecked
				print("found anchor")
				self:anchor(indent)
				self.iter:skip_space()
			end
			print("map next char: " .. self.iter:peek())
			if self.iter:match("*") then -- TODO: this is unchecked
				self:alias(indent)
				self.iter:skip_space()
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
				table.insert(self.tokens, { kind = MAP_END, indent = indent })
				return OK
			else
				res, mes = self:block_node(indent, false)
			end
			if not self.iter:eof() then
				if self:next_indent() < indent then
					table.insert(self.tokens, { kind = MAP_END, indent = indent })
					return OK
				end
			end
		elseif self.iter:match("#") then
			print("root comment")
			self:comment()
		elseif self.iter:match("---") or self.iter:match("...") then
			table.insert(self.tokens, { kind = MAP_END, indent = indent })
			return OK
		elseif self.iter:peek() == NL then
			print("MAP NL")
			self.iter:next()
			if self:indent() < indent then
				table.insert(self.tokens, { kind = MAP_END, indent = indent })
				print("return MAP")
				return OK
			elseif self:indent() > indent then
				print("map wrong indent: " .. indent .. "->" .. self:indent() .. ", row: " .. self.iter.row)
				local next_indent = self:indent()
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
			table.insert(self.tokens, { kind = MAP_END, indent = indent })
			return res, mes
		end
	end
	table.insert(self.tokens, { kind = MAP_END, indent = indent })
	return OK
end

function Lexer:sequence(indent)
	print("sequence: " .. indent)
	table.insert(self.tokens, { kind = SEQ_START, indent = indent })
	local res = OK
	local mes
	while not self.iter:eof() do
		if self.iter:match("- ") or self.iter:match("-\n") then
			self.iter:next()
			self.iter:skip_space()
			print("seq after'" .. self.iter:peek() .. "'")
			-- search for tag
			if self.iter:peek() == "!" then
				print("tag")
				self:tag(indent)
				self.iter:skip_space()
			end
			if self.iter:peek() == NL or self.iter:match("- ") then
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
			assert(self.iter:peek() == NL or self.iter:eof(), "no newline at " .. self.iter.row .. ":" .. self.iter.col)
		elseif self.iter:match("#") then
			self:comment()
		elseif self.iter:match("---") or self.iter:match("...") then
			table.insert(self.tokens, { kind = SEQ_END, indent = indent })
			return OK
		elseif self.iter:match(NL) then
			local next_indent = self:next_indent()
			if next_indent < indent then
				table.insert(self.tokens, { kind = SEQ_END, indent = indent })
				return OK
			elseif next_indent > indent then
				error("bigger indent not implemented: " .. self.iter.row .. ":" .. self.iter.col)
			end
			self.iter:next(next_indent + 1)
		else
			-- error("not a sequence: " .. self.iter:peek())
			table.insert(self.tokens, { kind = SEQ_END, indent = indent })
			return OK
		end
		if res ~= OK then
			-- error("break here: " .. res)
			table.insert(self.tokens, { kind = SEQ_END, indent = indent })
			return res, mes
		end
	end
	table.insert(self.tokens, { kind = SEQ_END, indent = indent })
end

function Lexer:block_node(indent, floating)
	local res = OK
	local mes
	self.iter:skip_space()
	print("block node in: '" .. (self.iter:peek() or "eof") .. "'")
	if self.iter:peek() == ALIAS then
		self.iter:next()
		local alias = {}
		while self.iter:peek() ~= " " and self.iter:peek() ~= NL do
			table.insert(alias, self.iter:next())
		end
		table.insert(self.tokens, { kind = ALIAS, value = table.concat(alias, ""), indent = indent })
		if self.iter:match(" #") or self.iter:match("\t#") then
			print("comment in block node")
			self:comment()
		end
		return OK
	elseif self.iter:peek() == ANCHOR then
		self.iter:next()
		local anchor = {}
		while self.iter:peek() ~= " " and self.iter:peek() ~= NL do
			table.insert(anchor, self.iter:next())
		end
		table.insert(self.tokens, { kind = ANCHOR, value = table.concat(anchor, ""), indent = indent })
		self.iter:next()
	elseif self.iter:peek() == "!" then
		self:tag(indent)
		self.iter:next()
	end
	if self:is_comment() then
		self:comment()
		self.iter:next()
	end
	while not self.iter:eof() do
		if self.iter:match("- ") or self.iter:match("-\n") then
			res, mes = self:sequence(indent)
			return res, mes
		elseif self.iter:match("[") or self.iter:match("{") then
			res, mes = self:flow()
			return res, mes
		elseif self.iter:match("|") then
			local next_indent = self:next_indent()
			self:literal(next_indent)
			return OK
		elseif self.iter:match(">") then
			local next_indent = self:next_indent()
			self.iter:next(2)
			table.insert(
				self.tokens,
				{ kind = "CHARS", value = self:folded(next_indent), indent = next_indent, type = "folded" }
			)
			return OK
		elseif self:is_key() then
			res, mes = self:map(indent)
			return res, mes
		elseif self.iter:match("?") then
			res, mes = self:complex(indent)
			return res, mes
		elseif self.iter:peek() == "'" or self.iter:peek() == '"' then
			res, mes = self:quoted()
			return res, mes
		elseif self.iter:match("---") or self.iter:match("...") then
			return OK
		elseif self.iter:peek() == NL then
			error("no newline expected")
			local next_indent = self:indent()
			if next_indent < indent then
				return 2
			end
		else
			res, mes = self:scalar(indent, floating)
			assert(self.iter:peek() == NL)
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
		elseif self.iter:match("#") then
			res, mes = self:comment()
		else
			table.insert(self.tokens, { kind = "+DOC", indent = 0 })
			res, mes = self:block_node(0)
			table.insert(self.tokens, { kind = "-DOC", indent = 0 })
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
	print(result or "nil")
	return tag_result
end

function Lexer:__tostring()
	local str = {}
	local tags = {}
	local anchor, tag
	print(require("str").to_string(self.tokens))
	for t in self:ipairs() do
		if t.kind == CHARS then
			if t.type == "literal" then
				table.insert(
					str,
					string.format("=VAL %s|%s", (anchor and ("&" .. anchor .. " ") or ""), escape(t.value))
				)
			elseif t.type == "folded" then
				table.insert(
					str,
					string.format("=VAL %s>%s", (anchor and ("&" .. anchor .. " ") or ""), escape(t.value))
				)
			else
				table.insert(
					str,
					string.format(
						"=VAL %s%s%s%s",
						(tag and (tag .. " ") or ""),
						(anchor and ("&" .. anchor .. " ") or ""),
						(t.type and t.type or ":"),
						escape(self:value(t.value))
					)
				)
			end
			anchor = nil
		elseif t.kind == KEY then
			table.insert(str, string.format("=VAL %s%s", (t.type and t.type or ":"), trim(t.value)))
		elseif t.kind == ANCHOR then
			anchor = t.value
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
			tag = t.value
		else
			table.insert(
				str,
				string.format(
					"%s%s%s",
					t.kind,
					(anchor and (" &" .. anchor) or ""),
					(tag and (" " .. self:parse_tag(tag)) or "")
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

local doc = [[
--- >
 Sammy Sosa completed another
 fine season with great stats.

   63 Home Runs
   0.288 Batting Average

 What a year!
]]

-- local iter = require("StringIterator"):new(doc)
-- local lexer, mes = Lexer:new(iter)
-- print(tostring(lexer))
-- print(tostring(mes))

return Lexer
