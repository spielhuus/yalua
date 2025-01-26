local Lexer = {}

local Token = {}

-- local print = function(...) end

---@class Token
function Token:new(state, row, col, indent, c, anchor, alias, tag)
	return setmetatable({
		state = state,
		row = row,
		col = col,
		indent = indent,
		c = c,
		anchor = anchor,
		alias = alias,
		tag = tag,
	}, { __index = Token })
end

function Lexer:new(doc)
	local o = {}
	self.__index = self
	setmetatable(o, self)
	o.str = doc
	o.tokens = {}
	o.index = 0
	o.row = 1
	o.col = 0
	o.line_start = true
	o.indent = 0
	o.chars = {}
	o.anchor = nil
	o.alias = nil
	o.tag = nil
	o.flow_level = 0
	o.state = nil
	o:parse()
	return o
end

-- ---------------------------------------------------------------------------------
-- ---                          utility functions                                ---
-- ---------------------------------------------------------------------------------

local function __or(self, rules)
	for _, rule in ipairs(rules) do
		local state, fn = rule(self)
		if state > 0 then
			return state, fn
		end
	end
	return 0, nil
end

function Lexer:__peek_char(n)
	n = n or 1
	if self.index + n > #self.str then
		return nil
	end
	return string.sub(self.str, self.index + n, self.index + n)
end

function Lexer:__nl()
	if self:__peek_char() == "\n" then
		self:__next_char()
		-- self:__push("NL", "")
		return 1
	end
	return 0
end

function Lexer:__next_char()
	self.index = self.index + 1
	if self.index > #self.str then
		return nil
	end
	self.col = self.col + 1
	local char = string.sub(self.str, self.index, self.index)
	if char == "\n" or char == "\r" then
		if self.index + 1 > #self.str and char == "\r" and char == "\n" then
			self.index = self.index + 1
		end
		self.col = 0
		self.row = self.row + 1
		return "\n"
	end
	return char
end

function Lexer:__push(state, c)
	local token = Token:new(state, self.row, self.col, self.indent, c, self.anchor, self.alias, self.tag)
	if state ~= "NL" then
		self.anchor = nil
		self.alias = nil
		self.tag = nil
	end
	table.insert(self.tokens, token)
end

function Lexer:__match(...)
	local s = string.sub(self.str, self.index + 1, self.index + select("#", ...))
	return s == table.concat({ ... })
end

function Lexer:__eof()
	return self.index >= #self.str
end

function Lexer:__eol()
	return self:__peek_char() == "\n" or self:__peek_char() == "\r"
end

-- ---------------------------------------------------------------------------------
-- ---                       the parser functions                                ---
-- ---------------------------------------------------------------------------------

function Lexer:add_char()
	if self:__eol() or self:__eof() then
		return 0
	elseif #self.chars == 0 and (self:__peek_char() == '"' or self:__peek_char() == "'") then
		self.tag = self:__peek_char()
		self:quote()
		return 0
	else
		table.insert(self.chars, self:__next_char())
		return 0
	end
end

function Lexer:__anchor()
	if self:__match("&") then
		print("anchor:" .. self:__peek_char())
		local anchor = {}
		self:__next_char()
		while not self:__eol() and not self:__eof() and self:__peek_char() ~= " " do
			table.insert(anchor, self:__next_char())
		end
		self:__next_char()
		self.anchor = table.concat(anchor, "")
		self:__push("ANCHOR", table.concat(anchor, ""))
		local res = __or(self, {
			self.line_comment,
			self.flow,
			self.scalar,
		})
		print("end flow in anchor: " .. self:__peek_char())
		return 1
	else
		return 0
	end
end

function Lexer:__alias()
	if self:__match("*") then
		local alias = {}
		self:__next_char()
		while not self:__eol() and not self:__eof() and self:__peek_char() ~= " " do
			table.insert(alias, self:__next_char())
		end
		self.alias = table.concat(alias, "")
		self:__push("ALIAS", table.concat(alias, ""))
		-- self:__push("CHAR", nil)
		local res = __or(self, {
			self.line_comment,
		})
		return 1
	else
		return 0
	end
end

function Lexer:quote()
	if self:__match('"') or self:__match("'") then
		local quote = self:__next_char()
		print("quote is : " .. quote .. "->" .. self:__peek_char())
		self.chars = {}
		while not self:__eof() do
			if self:__peek_char() == quote then
				self:__next_char()
				if self:__peek_char() == quote then
					table.insert(self.chars, self:__next_char())
				else
					break
				end
			elseif self:__peek_char() == "\n" then
				self:__next_char()
				self.tag = quote
				self:__push("CHAR", table.concat(self.chars, ""))
				self.chars = {}
			elseif self:__peek_char() == "\\" then
				local bslash = self:__next_char()
				if self:__peek_char() == "n" then -- TODO
					print("found nl")
					self:__next_char()
					table.insert(self.chars, "\n")
				else
					table.insert(self.chars, bslash)
					table.insert(self.chars, self:__next_char())
				end
			else
				table.insert(self.chars, self:__next_char())
			end
		end
		self.tag = quote
		self:__push("CHAR", table.concat(self.chars, ""))
		self.chars = {}
		-- self:__next_char()
		return 1
	else
		return 0
	end
end

function Lexer:__tag()
	print("MATCH TAG")
	if self:__match("!", "<") then
		self:__next_char()
		local tag = {}
		table.insert(tag, self:__next_char())
		while not self:__eof() and self:__peek_char() ~= ">" do
			table.insert(tag, self:__next_char())
		end
		table.insert(tag, self:__next_char())
		self:__push("TAG", table.concat(tag))
		-- self.tag = table.concat(tag)
		self:ws(true)
		return 1
	elseif self:__match("!", "!") then -- TODO match also other tags
		local _tag = {}
		while self:__peek_char() ~= " " and self:__peek_char() ~= "\n" do
			table.insert(_tag, self:__next_char())
		end
		-- self.tag = table.concat(_tag, "")
		self:__push("TAG", table.concat(_tag, ""))
		local res = __or(self, {
			self.scalar,
		})
		return 1
	elseif self:__match("!") then
		local _tag = {}
		while self:__peek_char() ~= " " and self:__peek_char() ~= "\n" do
			table.insert(_tag, self:__next_char())
		end
		self.tag = table.concat(_tag, "")
		self:__push("TAG", table.concat(_tag, ""))
		return 1
	else
		return 0
	end
end

function Lexer:folded()
	if self:__match(">") then
		print("folded")
		self:__next_char()
		self.tag = ">"
		self:ws(false)
		return 1
	elseif self:__match(" ", ">") then -- TODO: space handling
		error("old folded style")
		print("old folded")
		self:__next_char()
		self:__next_char()
		self.tag = ">"
		return 1
	else
		return 0
	end
end

function Lexer:literal()
	if self:__match("|", "-") then
		print("literal")
		self:__next_char()
		self:__next_char()
		self.tag = "|-"
		return 1
	elseif self:__match("|") then
		print("literal")
		self:__next_char()
		self.tag = "|"
		return 1
	elseif self:__match(" ", "|") then -- TODO: space handling
		print("literal")
		self:__next_char()
		self:__next_char()
		self.tag = "|"
		return 1
	else
		return 0
	end
end

function Lexer:directive()
	if self:__match("%") then
		while not self:__eof() and not self:__eol() do
			self:__next_char()
		end
		return 1
	else
		return 0
	end
end

--------------------------------------------------------------------------------
---                            The utils functions                           ---
--------------------------------------------------------------------------------

--- While function that detects infinite loops
---@param f function the function, must return 0, 1
---@return integer the value passed by the callback function
function Lexer:__while(f)
	local res = 0
	while not self:__eof() and res == 0 do
		local old_col = self.col
		local old_row = self.row
		res = f()
		if res == 0 and self.col == old_col and self.row == old_row then
			error("nothing found @ " .. self.row .. ":" .. self.col .. " '" .. self:__peek_char() .. "'") -- TODO
		end
	end
	return res
end

---Remove all white space characters
---@param nl boolean if true it will also remove the line breaks
function Lexer:ws(nl)
	while not self:__eof() do
		if self:__peek_char() == " " then
			self:__next_char()
		elseif nl and self:__peek_char() == "\n" then
			self:__next_char()
		else
			break
		end
	end
end

--------------------------------------------------------------------------------
---                           The parser functions                           ---
--------------------------------------------------------------------------------

--- flow type

function Lexer:flow()
	if self:__match("{") or self:__match("[") then
		print("start flow")
		self.flow_level = 0
		local res = self:__while(function()
			local inner_res = __or(self, {
				self.flow_seq_start,
				self.flow_map_start,
				self.add_char,
			})
			print("end flow: " .. inner_res .. " " .. self.flow_level)
			if inner_res == 1 and self.flow_level == 0 then
				return 1
			else
				return 0
			end
		end)
		return res
	else
		return 0
	end
end

function Lexer:flow_sep()
	if self:__match(",") then
		print(string.rep(" ", self.flow_level) .. "SEP +FLOW VALUE=" .. table.concat(self.chars, "") .. "'")
		self:__push("VAL", table.concat(self.chars, ""))
		self.chars = {}
		self:__next_char()
		self:ws(true)
		return 1
	else
		return 0
	end
end

function Lexer:flow_map_start()
	if self:__match("{") then
		self.flow_level = self.flow_level + 1
		print("map start: " .. self.flow_level .. "'" .. self:__peek_char() .. "'")
		self.tag = "{}"
		self:__push("START_FLOW_MAP")
		self:__next_char()
		self:ws(true)
		local res = 0
		self:__while(function()
			print("next: '" .. self:__peek_char() .. "'")
			res = __or(self, {
				self.flow_map_start,
				self.flow_map_end,
				self.flow_seq_start,
				self.flow_map_value,
				self.add_char,
				self.__nl,
			})
			print("flow map start res: " .. res .. "-> '" .. (self:__peek_char() or "nil") .. "'")
			return res
		end)
		print("MAP RES: " .. self.flow_level .. " " .. table.concat(self.chars, ""))
		if res == 1 and self.flow_level == 0 then
			return 1
		else
			return 0
		end
	else
		return 0
	end
end

function Lexer:flow_map_value()
	if self:__match(":", " ") then
		print("KEY: " .. table.concat(self.chars, ""))
		self:__push("KEY", table.concat(self.chars, ""))
		self.chars = {}
		self:__next_char()
		local res = self:__while(function()
			print("start_flow_map_value_loop ->'" .. self:__peek_char() .. "'")
			local res = __or(self, {
				self.flow_sep,
				self.flow_seq_start,
				self.flow_map_start,
				self.flow_map_end,
				self.add_char,
			})
			print("inside flow map value: " .. res .. "->" .. (self:__peek_char() or "nil"))
			if self:__peek_char() == "\n" then
				self:__next_char()
			end
			return res
		end)
		if res == 1 and self.flow_level == 0 then
			print("flow map value close: " .. res .. "->'" .. (self:__peek_char() or "nil") .. "'")
			return 1
		else
			-- self:ws(true)
			print("flow map value: " .. res .. "/>" .. self:__peek_char())
			return 0
		end
	else
		return 0
	end
end

function Lexer:flow_map_end()
	print("FLOW MAP end : " .. self:__peek_char() .. ":" .. (self:__match("}") and "true" or "false"))
	if self:__match("}") then
		self.flow_level = self.flow_level - 1
		print(" map end")
		if #self.chars > 0 then
			self:__push("VAL", table.concat(self.chars, ""))
		end
		self.chars = {}
		self.tag = "{}"
		self:__push("END_FLOW_MAP")
		self:__next_char()
		self:ws(true)
		return 1
	else
		return 0
	end
end

function Lexer:flow_seq_value()
	print(string.rep(" ", self.flow_level) .. "flow_seq_value: " .. self:__peek_char())
	self:ws(true)
	local res = 0
	self:__while(function()
		res = __or(self, {
			self.flow_seq_end,
			self.flow_sep,
			self.add_char,
			self.__nl,
		})
		return res
	end)
	print(string.rep(" ", self.flow_level) .. "flow_seq_value: --> " .. res)
	return res
end

function Lexer:flow_seq_start()
	if self:__match("[") then
		print(string.rep(" ", self.flow_level) .. "flow_seq_start(" .. self:__peek_char() .. ")")
		self.flow_level = self.flow_level + 1
		self.tag = "[]"
		self:__push("START_FLOW_SEQ")
		self:__next_char()
		self:ws(true)
		local res = 0
		self:__while(function()
			print(string.rep(" ", self.flow_level) .. "flow_seq_start>>loop" .. self:__peek_char())
			res = __or(self, {
				self.flow_map_start,
				self.flow_seq_start,
				self.flow_seq_end,
				self.flow_seq_value,
			})

			if res == 1 and self.flow_level == 0 then
				return 2
			else
				return 0
			end
		end)
		print(string.rep(" ", self.flow_level) .. "<flow_seq_start -> " .. res)
		return res
	else
		return 0
	end
end

function Lexer:flow_seq_end()
	if self:__match("]") then
		self.flow_level = self.flow_level - 1
		print("seq end")
		if #self.chars > 0 then
			self:__push("VAL", table.concat(self.chars, ""))
		end
		self.chars = {}
		self.tag = "[]"
		self:__push("END_FLOW_SEQ")
		self:__next_char()
		self:ws(true)
		return 1
	else
		return 0
	end
end

--- ---                                       YAML types                                            ---

function Lexer:line_comment()
	if (self.col == 0 and self:__match("#")) or (self:__peek_char(0) == " " and self:__peek_char() == "#") then
		self:__while(function()
			self:__next_char()
			return (not self:__eol() and 0 or 1)
		end)
		return 1
	else
		return 0
	end
end

function Lexer:mapping_value()
	if self:__match(":", " ") or self:__match(":", "\n") then
		self:__next_char()
		self:ws(false)
		local res = 0
		self:__push("KEY", table.concat(self.chars, ""))
		self.chars = {}

		-- res = __or(self, {
		-- 	self.__anchor,
		-- 	self.__alias,
		-- })
		print("found anchor: " .. res)
		self:__while(function()
			res = __or(self, {
				self.__anchor,
				self.__alias,
				self.literal,
				self.folded,
				self.line_comment,
				self.flow,
				self.add_char,
				self.__nl,
			})
			return res
		end)
		return 1
	else
		return 0
	end
end

function Lexer:scalar()
	print("scalar: indent:" .. self.indent)
	self:__while(function()
		local _res = __or(self, {
			self.mapping_value,
			self.line_comment,
			self.__nl,
			self.add_char,
		})
		return _res
	end)
	if #self.chars > 0 then
		print("SCALAR:" .. self.indent .. "'" .. table.concat(self.chars, "") .. "'")
		self:__push("CHAR", table.concat(self.chars, ""))
		self:__push("NL")
		self.chars = {}
		-- add the empty lines
		while self:__peek_char() == "\n" do
			self:__next_char()
			self:__push("NL")
		end
	end
	return 1
end

function Lexer:mapping_key()
	if self:__match("?", " ") then
		self:__next_char()
		self:__next_char()
		self:__push("CKEY")
		self.state = "CKEY"
		self.old_indent = self.indent
		return 1
	else
		return 0
	end
end

function Lexer:cmapping_value()
	if
		self.state == "CKEY"
		and self.old_indent <= self.indent
		and (self:__match(":", " ") or self:__match(":", "\n"))
	then
		self:__push("CVALUE")
		self.state = nil
		self.old_indent = nil
		self:__next_char()
		return 1
	else
		return 0
	end
end

function Lexer:sequence()
	if self:__match("-", "\n") then
		self:__next_char()
		self:__push("DASH")
		return 1
	elseif self:__match("-", " ") then
		self:__next_char()
		self:__next_char()
		self:__push("DASH")
		return 1
	else
		return 0
	end
end

function Lexer:start_doc()
	if self:__match("-", "-", "-") then
		self:__next_char()
		self:__next_char()
		self:__next_char()
		self:__push("START_DOC")
		self:ws(true)
		return 1
	else
		return 0
	end
end

function Lexer:end_doc()
	if self:__match(".", ".", ".") then
		self:__next_char()
		self:__next_char()
		self:__next_char()
		self:__push("END_DOC")
		self:ws(false)
		return 1
	else
		return 0
	end
end

function Lexer:parse()
	if self:__peek_char() == "%" then
		local tag_chars = {}
		while not self:__eol() do
			table.insert(tag_chars, self:__next_char())
		end
		local tag = table.concat(tag_chars, "")
		print("'" .. (string.match(tag, "^%%TAG ! (.-)$") or "nil") .. "'")
		if string.match(tag, "^%%TAG ! (.-)$") then
			local tag_uri = string.match(tag, "^%%TAG ! (.-)$")
			self:__push("GLOBAL_TAG", tag_uri)
			print("found global tag definition: " .. tag_uri)
		else
			print("found other tag definition: '" .. tag .. "'")
		end
	end
	local res = 0
	while not self:__eof() do
		print(
			"start line row:"
				.. self.row
				.. ", col:"
				.. self.col
				.. ", indent:"
				.. self.indent
				.. ", first char:'"
				.. (self:__peek_char() or "nil")
				.. "'"
		)
		self:ws(false)
		res = __or(self, {
			self.start_doc,
			self.end_doc,
			self.sequence,
			self.line_comment,
			self.directive,
			self.literal,
			self.folded,
			self.flow,
			self.__tag,
			self.__anchor,
			self.__alias,
			self.mapping_key,
			self.cmapping_value,
			self.scalar,
			self.__nl,
		})
		if self.col == 0 then
			self.indent = 0
			while not self:__eof() and self:__peek_char() == " " do
				self.indent = self.indent + 1
				self:__next_char()
			end
		end
		print(
			"LINE loop res : "
				.. res
				.. "->"
				.. (self:__peek_char() == "\n" and "\\n" or (self:__peek_char() and self:__peek_char() or "nil"))
		)
	end
	return res
end

--- Get the line from the docment
--- @param line_num integer number 1 based
function Lexer:get_line(line_num)
	local lines = {}
	for line in self.str:gmatch("[^\r?\n]+") do
		table.insert(lines, line)
	end
	if line_num < 1 or line_num > #lines then
		return nil
	end
	return lines[line_num]
end

function Lexer:__tostring()
	local str = {}
	table.insert(str, "state           | tag       | anchor    | alias     | indent | row | col | value")
	table.insert(str, "----------------|-----------|-----------|-----------|--------|-----|-----|----------------")
	for _, item in ipairs(self.tokens) do
		table.insert(
			str,
			string.format(
				"%-15s | %-8s  | %-8s  | %-8s  | %-6d | %-3d | %-3d | '%s'",
				item.state,
				(item.tag or ""),
				(item.anchor or ""),
				(item.alias or ""),
				item.indent,
				item.row,
				item.col,
				item.c or ""
			)
		)
	end
	return table.concat(str, "\n")
end

return Lexer
