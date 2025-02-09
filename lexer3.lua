local to_string = require("str").to_string
local trim = require("str").trim
local Lexer = {}

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

function Lexer:new(doc)
	local o = {}
	self.__index = self
	setmetatable(o, self)
	o.str = doc
	o.index = 0
	o.tokens = {}
	o.row = 0
	o.col = 0
	o.indent = 0
	o.chars = {}
	o.state = "STREAM"
	o.flow_level = 0

	-- TODO: try handling anchors
	o.act_anchor = nil
	o.act_alias = nil
	o.act_tag = nil
	return o
end

function Lexer:match_str(str)
	local s = string.sub(self.str, self.index + 1, self.index + #str)
	return s == str
end

function Lexer:peek(n)
	n = n or 1
	if self.index + n > #self.str then
		return nil
	end
	return string.sub(self.str, self.index + n, self.index + n)
end

function Lexer:eol()
	return self:peek() == "\n" or self:peek() == "\r"
end

function Lexer:eof()
	return self.index >= #self.str
end

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
			-- TODO it should check the next char for "\n"
			if self.index + 1 > #self.str and char == "\r" and char == "\n" then
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

function Lexer:nl()
	self:next_char()
	self.indent = 0
	while self:peek() == " " do
		self.indent = self.indent + 1
		self:next_char()
	end
end

function Lexer:comment()
	while self:peek() ~= "\n" do
		self:next_char()
	end
end

function Lexer:collect()
	table.insert(self.chars, self:next_char())
end

local function skipper(n)
	return function(self)
		self:next_char(n)
	end
end

function Lexer:tag()
	local tag_text = {}
	while self:peek() ~= "\n" do
		table.insert(tag_text, self:next_char())
	end
	print("TAG: " .. table.concat(tag_text, ""))
	self.act_tag = {
		kind = "TAG",
		indent = self.indent,
		row = self.row,
		col = self.col,
		value = table.concat(tag_text, ""),
	}
end

function Lexer:tagref()
	self:next_char()
	local tag_text = {}
	while self:peek() ~= "\n" do
		table.insert(tag_text, self:next_char())
	end
	self:next_char()
	table.insert(self.tokens, {
		kind = "TAG",
		indent = self.indent,
		row = self.row,
		col = self.col,
		value = table.concat(tag_text, ""),
	})
end

function Lexer:anchor()
	self:next_char()
	local name = {}
	while self:peek() ~= " " and self:peek() ~= "\n" do
		table.insert(name, self:next_char())
	end
	if self:peek() == " " then
		self:next_char()
	end
	self.act_anchor = {
		kind = "ANCHOR",
		indent = self.indent,
		row = self.row,
		col = self.col,
		value = table.concat(name, ""),
	}
end

function Lexer:alias()
	self:next_char()
	local name = {}
	while self:peek() ~= " " and self:peek() ~= "\n" do
		table.insert(name, self:next_char())
	end
	self:next_char()
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
	-- TODO clear anchor, tag and shit
end

function Lexer:scalar()
	local old_index = self.index
	while true do
		local indent = 0
		while self:peek(indent + 1) == " " do
			indent = indent + 1
		end
		-- add empty line break to tokens
		if self:eol() then
			table.insert(self.tokens, {
				kind = "NL",
				indent = indent,
				row = self.row,
				col = self.col,
			})
			self:next_char()
		elseif indent > self.indent then
			self:next_char(indent)
			local chars = {}
			while self:peek() ~= "\n" do
				table.insert(chars, self:next_char())
			end
			old_index = self.index
			self:next_char()
			table.insert(self.tokens, {
				kind = "CHARS",
				anchor = self.act_anchor,
				alias = self.act_alias,
				tag = self.act_tag,
				indent = indent,
				row = self.row,
				col = self.col,
				value = trim(table.concat(chars, "")),
			})
			self.act_anchor = nil
			self.act_alias = nil
			self.act_tag = nil
		else
			self.index = old_index
			break
		end
	end
end

function Lexer:folded()
	self:next_char()
	if self:peek() == "-" then
		self:next_char()
		self.tokens[#self.tokens].chopped = true
	end
	while self:peek() ~= "\n" do
		print("WARN: folding extra character: " .. self:next_char())
	end
	local nl = self:next_char()
	assert(nl == "\n", "expected new line but was: '" .. nl .. "'")
	self:scalar()
end

function Lexer:quoted()
	local quote = self:next_char()
	local chars = {}
	local first_line = true
	while not self:eof() do
		if self:peek() == quote then
			self:next_char()
			if self:peek() == quote then
				table.insert(chars, self:next_char())
			else
				break
			end
		elseif self:peek() == "\n" then
			self:next_char()
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
		elseif self:peek() == "\\" then
			local bslash = self:next_char()
			if self:peek() == "n" then -- TODO
				self:next_char()
				table.insert(chars, "\n")
				first_line = false
			else
				table.insert(chars, bslash)
				table.insert(chars, self:next_char())
			end
		else
			table.insert(chars, self:next_char())
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
			.. (self:peek() == "\\n" and "\n" or ""),
		type = quote,
	})
	self.tags = nil
	self.anchor = nil
	self.alias = nil
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
		{ "", "", nil, "BLOCK" },
	},
	BLOCK_IN = {
		{ "- ", "DASH", skipper(2), "BLOCK" },
		{ "\n", "", Lexer.nl, "DOC" },
		{ "[", "SEQ_START", skipper(1), "FLOW" },
		{ "{", "MAP_START", skipper(1), "FLOW" },
		{ "!", "", Lexer.tag },
		{ "*", "", Lexer.alias },
		{ '"', "", Lexer.quoted, "BLOCK" },
		{ "'", "", Lexer.quoted, "BLOCK" },
		{ "", "", nil, "BLOCK" },
	},
	FLOW = {
		{ "[", "SEQ_START", skipper(1) },
		{ "]", "SEQ_END", skipper(1) },
		{ "{", "MAP_START", skipper(1) },
		{ "}", "MAP_END", skipper(1) },
		{ ",", "SEP", skipper(1) },
		{ ":", "COLON", skipper(1) },
		{ "_", "CHARS", Lexer.collect },
	},
	BLOCK = {
		{ ":\n", "COLON", skipper(1), "BLOCK_IN" },
		{ ": ", "COLON", skipper(2), "BLOCK_IN" },
		-- { '"', "", Lexer.quoted, "BLOCK" },
		-- { "'", "", Lexer.quoted, "BLOCK" },
		{ "\n", "", Lexer.nl, "DOC" },
		{ "#", "", Lexer.comment },
		{ "[", "SEQ_START", skipper(1), "FLOW" },
		{ "{", "MAP_START", skipper(1), "FLOW" },
		{ "&", "", Lexer.anchor },
		{ "*", "", Lexer.alias },
		{ ">", "FOLDED", Lexer.folded, "BLOCK" },
		{ "|", "LITERAL", Lexer.folded, "BLOCK_IN" },
		{ "_", "CHARS", Lexer.collect },
	},
}

function Lexer:process_rules()
	for _, val in ipairs(states[self.state]) do
		local key, name, fn, next = val[1], val[2], val[3], val[4]
		if key == "" then
			-- set next state
			self.state = next or self.state
			return
		elseif key == "_" then
			fn(self)
			return
		elseif self:match_str(key) then
			if name == "SEQ_START" or name == "MAP_START" then
				self.flow_level = self.flow_level + 1
			elseif name == "SEQ_END" or name == "MAP_END" then
				self.flow_level = self.flow_level - 1
				if self.flow_level == 0 then
					next = "DOC"
					-- return
				end
			end
			if #self.chars > 0 then
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
			fn(self)
			if next then
				self.state = next
			end
			return
		end
	end
end

function Lexer:lexme()
	while not self:eof() do
		self:process_rules()
	end
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

-- return Lexer
local Parser = {}

function Parser:new(tokens)
	local o = {}
	self.__index = self
	setmetatable(o, self)
	o.tokens = tokens
	o.index = 0
	o.result = {}
	o.global_tag = "tag:yaml.org,2002"
	return o
end

function Parser:peek(n)
	return self.tokens[self.index + (n or 1)]
end

function Parser:next()
	self.index = self.index + 1
	return self.tokens[self.index]
end

function Parser:match(...)
	local args = { ... }
	for i, arg in ipairs(args) do
		if self.index + i > #self.tokens or self.tokens[self.index + i].kind ~= arg then
			return false
		end
	end
	return true
end

function Parser:skip(kind)
	if self:peek() and self:peek().kind == kind then
		self:next()
		return
	end
	if self:peek() then
		error("No " .. kind .. " found @ " .. self:peek().row .. ":" .. self:peek().col)
	end
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

function Parser:push(kind, node)
	local the_node = node
	if node.anchor then
		print(kind .. " has anchor: " .. to_string(node) .. " NEXT: " .. to_string(self:peek()))
		if node.anchor.indent ~= node.indent then
			print("indent does differ")
			the_node = {
				indent = node.indent,
				kind = kind,
				anchor = {
					value = node.anchor.value,
				},
				value = node.value,
				row = node.row,
				col = node.col,
			}
			node.anchor = nil
			print("the node: " .. to_string(the_node))
		end
	end
	table.insert(self.result, { kind = kind, value = the_node })
end

function Parser:collection(indent)
	local node = self:peek()
	self:push("+SEQ", node)
	local act_indent = self:peek().indent
	while self:peek() and self:match("DASH") and self:peek().indent == act_indent do
		self:skip("DASH")
		if self:match("DASH") then
			self:collection(act_indent)
		elseif self:match("CHARS", "COLON") then
			self:map(indent)
		elseif self:match("CHARS") then
			self:scalar()
		elseif self:match("SEQ_START") then
			self:flow_seq()
		elseif self:match("MAP_START") then
			self:flow_map()
		elseif self:match("ANCHOR") then -- TODO remove?
			error("found anchor")
			self:flow_map()
		else
			self:parse(self:peek().indent)
		end
		if self:peek() and act_indent == indent and self:peek().indent > act_indent then
			act_indent = self:peek().indent
		end
	end
	table.insert(self.result, { kind = "-SEQ", value = node })
end

function Parser:map(indent)
	local node = self:peek()
	self:push("+MAP", node)
	local act_indent = self:peek().indent
	while self:peek() and self:match("CHARS", "COLON") and self:peek().indent == act_indent do
		table.insert(self.result, { kind = "VAL", value = self:next() })
		self:skip("COLON")
		if self:match("CHARS", "COLON") then
			self:map(act_indent)
		elseif self:peek().kind == "CHARS" then
			self:scalar()
		elseif self:peek().kind == "LITERAL" then
			self:literal()
		elseif self:peek().kind == "FOLDED" then
			self:folded()
		elseif self:match("SEQ_START") then
			self:flow_seq()
		elseif self:match("MAP_START") then
			self:flow_map()
		else
			self:parse(self:peek().indent)
		end
		if self:peek() and act_indent == indent and self:peek().indent > act_indent then
			act_indent = self:peek().indent
		end
	end
	table.insert(self.result, { kind = "-MAP", value = node })
end

function Parser:flow_map()
	local node = self:next()
	table.insert(self.result, { kind = "+MAP {}", value = node })
	while self:peek().kind ~= "MAP_END" do
		if self:match("CHARS", "COLON", "CHARS") then
			table.insert(self.result, { kind = "VAL", value = self:next() })
			self:next()
			table.insert(self.result, { kind = "VAL", value = self:next() })
			if self:peek().kind == "SEP" then
				self:next()
			end
		elseif self:match("CHARS") then
			error("what are the chars here?")
		end
	end
	self:next()
	table.insert(self.result, { kind = "-MAP", value = node })
end

function Parser:flow_seq()
	local node = self:next()
	table.insert(self.result, { kind = "+SEQ []", value = node })
	while self:peek().kind ~= "SEQ_END" do
		if self:match("CHARS") then
			table.insert(self.result, { kind = "VAL", value = self:next() })
			if self:peek().kind == "SEP" then
				self:next()
			end
		end
	end
	self:next()
	table.insert(self.result, { kind = "-SEQ", value = node })
end

function Parser:folded()
	local result = {}
	local folded_node = self:next()
	local indent = self:peek().indent
	local blank_line = false
	while self:peek() and (self:peek().kind == "CHARS" or self:peek().kind == "NL") and self:peek().indent >= indent do
		local spacer = " "
		local n = self:next()
		if self:peek() and self:peek().kind == "NL" then
			spacer = "\\n\\n"
			self:next()
			blank_line = true
		elseif self:peek() and trim(self:peek().value) == "" then
			spacer = "\\n\\n"
			self:next()
		elseif blank_line then
			spacer = "\\n"
		end
		local r = n.indent - indent
		table.insert(result, string.rep(" ", r) .. n.value .. spacer)
	end
	folded_node.kind = "VAL"
	folded_node.type = "FOLDED"
	local res = table.concat(result, "")
	if string.sub(res, #res, #res) == " " then
		res = string.sub(res, 1, #res - 1)
	end
	folded_node.value = res .. (blank_line and "" or "\\n")
	table.insert(self.result, { kind = "VAL", value = folded_node })
end

function Parser:literal()
	local result = {}
	local literal_node = self:next()
	local indent = self:peek().indent
	local blank_line = false
	while self:peek() and (self:peek().kind == "CHARS" or self:peek().kind == "NL") and self:peek().indent >= indent do
		local n = self:next()
		local r = n.indent - indent
		table.insert(result, string.rep(" ", r) .. n.value)
	end
	literal_node.kind = "VAL"
	literal_node.type = "LITERAL"
	local res = table.concat(result, "\n")
	if string.sub(res, #res, #res) == " " then
		res = string.sub(res, 1, #res - 1)
	end
	literal_node.value = res .. (blank_line or literal_node.chopped and "" or "\n")
	table.insert(self.result, { kind = "VAL", value = literal_node })
end

function Parser:scalar()
	local last_indent
	if #self.result == 1 then
		last_indent = 0
	else
		last_indent = self.result[#self.result - 1].value.indent
	end
	local indent = self:peek().indent
	if last_indent == indent then
		table.insert(self.result, { kind = "VAL", value = self:next() })
	else
		local node = self:peek()
		local result = {}
		while
			self:peek()
			and self:peek().kind == "CHARS"
			and self:peek().indent >= indent
			and not (self:peek(2) and self:peek(2).kind == "COLON")
		do
			table.insert(result, self:next().value)
		end
		node.value = table.concat(result, " ")
		table.insert(self.result, { kind = "VAL", value = node })
	end
end

function Parser:parse_tag(tag_value)
	local tag_result
	print("PARSE TAG: " .. tag_value)
	if string.match(tag_value, "^!<(.*)>$") then
		tag_result = "<" .. string.match(tag_value, "^!<(.*)>$") .. ">"
	elseif string.match(tag_value, "^!!(.*)") then
		tag_result = "<" .. self.global_tag .. ":" .. string.match(tag_value, "^!!(.*)") .. ">"
	elseif string.match(tag_value, "^!(.*)") then
		tag_result = "<" .. self.global_tag .. ":" .. string.match(tag_value, "^!(.*)") .. ">"
	end
	print("TAG RESULT: " .. tag_result)
	return tag_result
end

function Parser:parse(indent)
	indent = indent or 0
	while self:peek() do
		if self:peek().indent < indent then
			break
		elseif self:match("START_DOC") then
			table.insert(self.result, { kind = "START_DOC", value = { indent = 0 } })
			self:next()
		elseif self:match("END_DOC") then
			table.insert(self.result, { kind = "END_DOC" })
			self:next()
		elseif self:match("DASH") then
			self:collection(indent)
		elseif self:match("CHARS", "COLON") then
			self:map(indent)
		elseif self:match("CHARS") then
			table.insert(self.result, { kind = "VAL", value = self:next() })
		elseif self:match("SEQ_START") then
			self:flow_seq()
		elseif self:match("MAP_START") then
			self:flow_map()
		-- TODO: remove
		elseif self:match("ANCHOR") then
			table.insert(self.result, { kind = "ANCHOR", value = self:next() })
		elseif self:match("ALIAS") then
			table.insert(self.result, { kind = "ALIAS", value = self:next() })
		elseif self:match("FOLDED") then
			self:folded()
		elseif self:match("LITERAL") then
			self:literal()
		elseif self:match("TAG") then
			local act_tag = self:next().value
			if string.match(act_tag, "^TAG ! tag:(.*):$") then
				self.global_tag = string.match(act_tag, "^TAG ! (.*):$")
				print("GLOBAL TAG: " .. to_string(self.global_tag))
			else
				print("TAGDEF: " .. to_string(act_tag))
			end
		else
			print("Unknown token: " .. to_string(self:next()))
		end
	end
end

function Parser:__tostring()
	local str = {}
	local indent = 2
	table.insert(str, "+STR")
	local doc_started = false
	local anchor = nil
	for i, item in ipairs(self.result) do
		print("to_string: " .. to_string(item))
		if i == 1 and item.kind ~= "START_DOC" then
			table.insert(str, " +DOC")
			doc_started = true
		end
		if item.kind == "START_DOC" then
			if doc_started then
				table.insert(str, " -DOC")
			end
			table.insert(str, " +DOC ---")
			doc_started = true
		elseif item.kind == "END_DOC" then
			doc_started = false
			table.insert(str, " -DOC ...")
		elseif string.sub(item.kind, 1, 1) == "+" then
			table.insert(
				str,
				string.format(
					"%s%s%s%s",
					string.rep(" ", indent),
					item.kind,
					(item.value.tag and " " .. self:parse_tag(item.value.tag.value) or ""),
					(item.value.anchor and " &" .. item.value.anchor.value or ""),
					(item.value.alias and " *" .. item.value.alias.value or "")
				)
			)
			indent = indent + 1
		elseif string.sub(item.kind, 1, 1) == "-" then
			indent = indent - 1
			table.insert(str, string.format("%s%s", string.rep(" ", indent), item.kind))
		elseif item.kind == "ANCHOR" then
			anchor = item
		elseif item.kind == "ALIAS" then
			table.insert(str, string.format("%sALI *%s", string.rep(" ", indent), item.value.value))
		else
			if item.value.alias then
				table.insert(str, string.format("%s=ALI *%s", string.rep(" ", indent), trim(item.value.alias.value)))
				anchor = nil
			else
				if item.value.type == "FOLDED" then
					table.insert(str, string.format("%s=%s >%s", string.rep(" ", indent), item.kind, item.value.value))
				elseif item.value.type == "LITERAL" then
					table.insert(
						str,
						string.format("%s=%s |%s", string.rep(" ", indent), item.kind, escape(item.value.value))
					)
				else
					table.insert(
						str,
						string.format(
							"%s=%s %s%s%s%s",
							string.rep(" ", indent),
							item.kind,
							(item.value.anchor and "&" .. item.value.anchor.value .. " " or ""),
							(item.tag and self:parse_tag(item.tag) or ""),
							(item.value.type and item.value.type or ":"),
							(item.value.value and escape(self:value(item.value.value)) or "")
						)
					)
				end
			end
		end
	end
	if doc_started then
		table.insert(str, " -DOC")
	end
	table.insert(str, "-STR")
	table.insert(str, "")
	return table.concat(str, "\n")
end

local str = [[
--- !shape
  # Use the ! handle for presenting
  # tag:clarkevans.com,2002:circle
- !circle
  center: &ORIGIN {x: 73, y: 129}
  radius: 7
- !line
  start: *ORIGIN
  finish: { x: 89, y: 102 }
- !label
  start: *ORIGIN
  color: 0xFFEEBB
  text: Pretty vector drawing.
]]

-- local lexer = Lexer:new(str)
-- lexer:lexme()
-- print(tostring(lexer))
-- local parser = Parser:new(lexer.tokens)
-- parser:parse()
-- print("---------------------------------")
-- print(tostring(parser))

return {
	stream = function(doc)
		print(doc)
		local lexer = Lexer:new(doc)
		lexer:lexme()
		print(tostring(lexer))
		local parser = Parser:new(lexer.tokens)
		parser:parse()
		return tostring(parser)
	end,
}
