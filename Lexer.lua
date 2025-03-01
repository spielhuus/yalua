local trim = require("str").trim

local Lexer = {}

function Lexer:new(iter)
	local o = {}
	self.__index = self
	setmetatable(o, self)
	o.iter = iter
	o.tokens = {}
	o.indent = 0
	o.chars = {}
	o.state = "STREAM"
	o.index = 0
	o.flow_level = 0
	--
	-- -- TODO: try handling anchors
	o.act_anchor = nil
	o.act_alias = nil
	-- o.act_tag = nil
	local res, mes = o:lexme()
	if res ~= 0 then
		return nil, mes
	else
		return o
	end
end

local function skipper(n)
	return function(self)
		self.iter:next(n)
		while self.iter:peek() == " " or self.iter:peek() == "\t" do
			self.iter:next()
		end
		return 0
	end
end

function Lexer:nl()
	if #self.tokens > 0 and self.tokens[#self.tokens].kind == "DASH" then
		print("EMTY ESQ")
		table.insert(self.tokens, { kind = "CHARS", value = "", indent = self.indent })
	end
	self.iter:next()
	self.indent = 0
	while self.iter:peek() == " " do
		self.indent = self.indent + 1
		self.iter:next()
	end
	return 0
end

function Lexer:collect()
	table.insert(self.chars, self.iter:next())
	return 0
end

function Lexer:comment()
	while self.iter:peek() ~= "\n" do
		self.iter:next()
	end
	return 0
end

function Lexer:quoted()
	local quote = self.iter:next()
	local chars = {}
	local first_line = true
	while not self.iter:eof() do
		if self.iter:peek() == quote then
			self.iter:next()
			if self.iter:peek() == quote then
				table.insert(chars, self.iter:next())
			else
				break
			end
		elseif self.iter:peek() == "\n" then
			self.iter:next()
			table.insert(self.tokens, {
				kind = "CHARS",
				anchor = self.act_anchor,
				alias = self.act_alias,
				tag = self.act_tag,
				indent = self.indent,
				row = self.row,
				col = self.col,
				value = (first_line and table.concat(chars, "") or trim(table.concat(chars, ""))),
				type = quote,
			})
			chars = {}
		-- TODO clear anchor, tag and shit
		elseif self.iter:peek() == "\\" then
			local bslash = self.iter:next()
			if self.iter:peek() == "n" then -- TODO
				self.iter:next()
				table.insert(chars, "\n")
				first_line = false
			else
				table.insert(chars, bslash)
				table.insert(chars, self.iter:next())
			end
		else
			table.insert(chars, self.iter:next())
		end
	end
	table.insert(self.tokens, {
		kind = "CHARS",
		anchor = self.act_anchor,
		alias = self.act_alias,
		tag = self.act_tag,
		indent = self.indent,
		row = self.row,
		col = self.col,
		value = (first_line and table.concat(chars, "") or trim(table.concat(chars, ""), true))
			.. (self.iter:peek() == "\\n" and "\n" or ""),
		type = quote,
	})
	self.tags = nil
	self.anchor = nil
	self.alias = nil
	return 0
end

function Lexer:scalar()
	local old_index = self.index
	while true do
		print("scalar loop")
		local indent = 0
		while self.iter:peek() and self.iter:peek(indent + 1) == " " do
			indent = indent + 1
		end
		-- add empty line break to tokens
		if self.iter:eol() then
			table.insert(self.tokens, {
				kind = "NL",
				indent = indent,
				row = self.row,
				col = self.col,
			})
			self.iter:next()
		elseif indent > self.indent then
			self.iter:next(indent)
			local chars = {}
			while self.iter:peek() and self.iter:peek() ~= "\n" do
				table.insert(chars, self.iter:next())
			end
			old_index = self.index
			self.iter:next()
			table.insert(self.tokens, {
				kind = "CHARS",
				anchor = self.act_anchor,
				alias = self.act_alias,
				tag = self.act_tag,
				indent = indent,
				row = self.row,
				col = self.col,
				-- TODO value = trim(table.concat(chars, "")),
				value = table.concat(chars, ""),
			})
			self.act_anchor = nil
			self.act_alias = nil
			self.act_tag = nil
		else
			self.index = old_index
			break
		end
	end
	return 0
end

function Lexer:folded()
	self.iter:next()
	print("folded")
	while not self.iter:eof() and self.iter:peek() ~= "\n" do
		print("loop")
		if self.iter:peek() == "-" then
			self.iter:next()
			self.tokens[#self.tokens].chopped = true
		elseif self.iter:peek() == "+" then
			self.iter:next()
			self.tokens[#self.tokens].chopped = false
		elseif tonumber(self.iter:peek()) then
			local number = self.iter:next()
			while tonumber(self.iter:peek()) do
				number = number .. self.iter:next()
			end
			if tonumber(number) >= 1 and tonumber(number) <= 9 then
				self.tokens[#self.tokens].indent_hint = tonumber(number)
			else
				return -1, "number must be between 0..9"
			end
		else
			print("extra character : " .. self.iter:next())
		end
	end
	while self.iter:peek() and self.iter:peek() ~= "\n" do
		print("WARN: folding extra character: " .. self.iter:next())
	end
	local nl = self.iter:next()
	-- assert(nl == "\n", "expected new line but was: '" .. nl .. "'")
	print("end '" .. (self.iter:peek() or "eof") .. "'")
	self:scalar()
	return 0
end

function Lexer:anchor()
	self.iter:next()
	local name = {}
	while self.iter:peek() ~= " " and self.iter:peek() ~= "\n" do
		table.insert(name, self.iter:next())
	end
	if self.iter:peek() == " " then
		self.iter:next()
	end
	self.act_anchor = {
		kind = "ANCHOR",
		indent = self.indent,
		row = self.row,
		col = self.col,
		value = table.concat(name, ""),
	}
	return 0
end

function Lexer:alias()
	self.iter:next()
	local name = {}
	while self.iter:peek() ~= " " and self.iter:peek() ~= "\n" do
		table.insert(name, self.iter:next())
	end
	self.iter:next()
	table.insert(self.tokens, {
		kind = "CHARS",
		anchor = self.act_anchor,
		indent = self.indent,
		tag = self.act_tag,
		row = self.row,
		col = self.col,
		alias = {
			kind = "ALIAS",
			indent = self.indent,
			row = self.row,
			col = self.col,
			value = table.concat(name, ""),
		},
	})
	self.tag = nil
	self.anchor = nil
	self.alias = nil
	return 0
end

function Lexer:tagref()
	self.iter:next()
	local tag_text = {}
	while self.iter:peek() ~= "\n" do
		table.insert(tag_text, self.iter:next())
	end
	self.iter:next()
	table.insert(self.tokens, {
		kind = "TAG",
		indent = self.indent,
		row = self.row,
		col = self.col,
		value = table.concat(tag_text, ""),
	})
	return 0
end

function Lexer:tag()
	local tag_text = {}
	while self.iter:peek() ~= "\n" and self.iter:peek() ~= " " do
		table.insert(tag_text, self.iter:next())
	end
	while self.iter:peek() == " " do
		self.iter:next()
	end
	if self.iter:eol() then
		self.act_tag = {
			kind = "TAG",
			indent = self.indent,
			row = self.row,
			col = self.col,
			value = table.concat(tag_text, ""),
			before = true,
		}
	else
		self.act_tag = {
			kind = "TAG",
			indent = self.indent,
			row = self.row,
			col = self.col,
			value = table.concat(tag_text, ""),
		}
	end
	return 0
end

local states = {
	STREAM = {
		{ "%", "", Lexer.tagref },
		{ "---", "START_DOC", skipper(3), "DOC" },
		{ "#", "", Lexer.comment },
		{ "\n", "", Lexer.nl },
		{ "", "", nil, "DOC" },
	},
	DOC = {
		{ " ", "", skipper(1) },
		{ "---", "START_DOC", skipper(3), "DOC" },
		{ "- ", "DASH", skipper(2), "BLOCK_IN" },
		{ "-\n", "DASH", skipper(1), "BLOCK_IN" },
		{ "#", "", Lexer.comment },
		{ "...", "END_DOC", skipper(3), "STREAM" },
		{ "\n", "", Lexer.nl, "DOC" },
		{ "!", "", Lexer.tag },
		{ '"', "", Lexer.quoted, "BLOCK" },
		{ "'", "", Lexer.quoted, "BLOCK" },
		{ "", "", nil, "BLOCK" },
	},
	BLOCK_IN = {
		{ "- ", "DASH", skipper(2), "BLOCK" },
		{ "\n", "", Lexer.nl, "DOC" },
		{ "[", "SEQ_START", skipper(1), "FLOW" },
		{ "{", "MAP_START", skipper(1), "FLOW" },
		{ "!", "", Lexer.tag },
		{ "*", "", Lexer.alias },
		{ "&", "", Lexer.anchor },
		{ '"', "", Lexer.quoted, "BLOCK" },
		{ "'", "", Lexer.quoted, "BLOCK" },
		{ "#", "", Lexer.comment },
		{ "", "", nil, "BLOCK" },
	},
	FLOW = {
		{ "[", "SEQ_START", skipper(1) },
		{ "]", "SEQ_END", skipper(1) },
		{ "{", "MAP_START", skipper(1) },
		{ "}", "MAP_END", skipper(1) },
		{ ",", "SEP", skipper(1) },
		{ ":", "COLON", skipper(1) },
		{ " #", "", Lexer.comment },
		{ '"', "", Lexer.quoted },
		{ "'", "", Lexer.quoted },
		{ "\n", "", skipper(1) },
		{ "_", "CHARS", Lexer.collect },
	},
	BLOCK = {
		{ ":\t", "COLON", skipper(1), "BLOCK_IN" },
		{ ":\n", "COLON", skipper(1), "BLOCK_IN" },
		{ "?", "KEY", skipper(1), "BLOCK_IN" },
		{ ": ", "COLON", skipper(2), "BLOCK_IN" },
		{ "\n", "", Lexer.nl, "DOC" },
		{ " #", "", Lexer.comment },
		{ "[", "SEQ_START", skipper(1), "FLOW" },
		{ "{", "MAP_START", skipper(1), "FLOW" },
		{ "&", "", Lexer.anchor },
		{ "*", "", Lexer.alias },
		{ ">", "FOLDED", Lexer.folded, "DOC" },
		{ "|", "LITERAL", Lexer.folded, "DOC" },
		{ "_", "CHARS", Lexer.collect },
	},
}

function Lexer:process_rules()
	for _, val in ipairs(states[self.state]) do
		local key, name, fn, next = val[1], val[2], val[3], val[4]
		if key == "" then
			-- set next state
			self.state = next or self.state
			return 0
		elseif key == "_" then
			fn(self)
			self.collect = true
			return 0
		elseif self.iter:match(key) then
			-- print(
			-- 	"MATCH: "
			-- 		.. self.state
			-- 		.. ", key:'"
			-- 		.. key
			-- 		.. "'"
			-- 		.. ", name="
			-- 		.. name
			-- 		.. ", collect="
			-- 		.. (self.collect and "true" or "false")
			-- 		.. " char='"
			-- 		.. self.iter:peek()
			-- 		.. "'"
			-- )
			if name == "SEQ_START" or name == "MAP_START" then
				self.flow_level = self.flow_level + 1
			elseif name == "SEQ_END" or name == "MAP_END" then
				self.flow_level = self.flow_level - 1
				if self.flow_level == 0 then
					next = "DOC"
					-- return
				end
			end
			if self.collect and #self.chars > 0 then
				table.insert(self.tokens, {
					kind = "CHARS",
					indent = self.indent,
					row = self.row,
					col = self.col,
					value = trim(table.concat(self.chars, "")),
					anchor = self.act_anchor,
					alias = self.act_alias,
					tag = self.act_tag,
				})
				self.chars = {}
				self.act_anchor = nil
				self.act_alias = nil
				self.act_tag = nil
				self.collect = false
			end
			if name ~= "" then
				table.insert(self.tokens, {
					kind = name,
					indent = self.indent,
					row = self.row,
					col = self.col,
					tag = self.act_tag,
					anchor = self.act_anchor,
					alias = self.act_alias,
				})
				self.act_anchor = nil
				self.act_alias = nil
				self.act_tag = nil
			end
			local res, mes = fn(self)
			if res == -1 then
				return res, mes
			end
			if next then
				self.state = next
			end
			return 0
		end
	end
	return 0
end

function Lexer:lexme()
	while not self.iter:eof() do
		if self:process_rules() < 0 then
			return -1
		end
	end
	return 0
end

function Lexer:__tostring()
	local str = {}
	table.insert(
		str,
		string.format(
			"| %-10s| %-7s| %-6s| %-6s| %-10s | %-10s | %-10s |%s",
			"kind",
			"indent",
			"row",
			"col",
			"anchor",
			"alias",
			"tag",
			"type",
			"value"
		)
	)
	table.insert(
		str,
		"|-----------|--------|-------|-------|------------|------------|------------|------------|----------------"
	)
	for _, token in ipairs(self.tokens) do
		table.insert(
			str,
			string.format(
				"| %-10s| %-7s| %-6s| %-6s| %-10s | %-10s | %-10s | %-10s |  %s",
				token.kind,
				token.indent,
				token.row,
				token.col,
				(token.anchor and token.anchor.value or ""),
				(token.alias and token.alias.value or ""),
				(token.tag and token.tag.value or ""),
				(token.type and token.type or ""),
				token.value
			)
		)
	end
	return table.concat(str, "\n")
end

function Lexer:peek(n)
	return self.tokens[self.index + (n or 1)]
end

function Lexer:next()
	self.index = self.index + 1
	return self.tokens[self.index]
end

function Lexer:match(...)
	local args = { ... }
	for i, arg in ipairs(args) do
		if self.index + i > #self.tokens or self.tokens[self.index + i].kind ~= arg then
			return false
		end
	end
	return true
end

function Lexer:skip(kind)
	if self:peek() and self:peek().kind == kind then
		self:next()
		return
	end
	if self:peek() then
		error("No " .. kind .. " found @ " .. self:peek().row .. ":" .. self:peek().col)
	end
end

return Lexer
