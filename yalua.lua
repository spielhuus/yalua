local StringIterator = require("StringIterator")

-- -------------------------------------------------------------------
-- ---                     Utility functions                       ---
-- -------------------------------------------------------------------

local function clean_key(key)
	local trimmed = require("str").trim(key)
	return trimmed
end

local function value(val)
	local trimmed = require("str").trim(val)
	if string.match(trimmed, "^['\"].*['\"]$") then
		return string.sub(trimmed, 2, #trimmed - 1)
	end
	if trimmed == "true" or trimmed == "True" or trimmed == "TRUE" then
		return true
	elseif trimmed == "false" or trimmed == "False" or trimmed == "FALSE" then
		return false
	end
	return tonumber(require("str").trim(val)) or require("str").trim(val)
end

-- -------------------------------------------------------------------
-- ---                        The States                           ---
-- -------------------------------------------------------------------

local states = {
	START = 1,
	SCALAR = 100,
	SEQUENCE_VALUE = 101,
	MAPPING_SCALAR = 102,
	SEQUENCE_ENTRY = 2, -- ”-” (x2D, hyphen) denotes a block sequence entry.
	MAPPING_KEY = 3, -- ”?” (x3F, question mark) denotes a mapping key.
	MAPPING_VALUE = 4, -- ”:” (x3A, colon) denotes a mapping value.
	MAPPING_VALUE_NL = 204, -- ”:” (x3A, colon) denotes a mapping value.
	COLLECT_ENTRY = 5, -- ”,” (x2C, comma) ends a flow collection entry.
	SEQUENCE_START = 6, -- ”[” (x5B, left bracket) starts a flow sequence.
	SEQUENCE_END = 7, -- ”]” (x5D, right bracket) ends a flow sequence.
	MAPPING_START = 8, -- ”{” (x7B, left brace) starts a flow mapping.
	MAPPING_END = 9, -- ”}” (x7D, right brace) ends a flow mapping.
	COMMENT = 10, -- ”#” (x23, octothorpe, hash, pound, number sign) denotes a comment.
	ANCHOR = 11, -- ”&” (x26, ampersand) denotes a node’s anchor property.
	ALIAS = 12, -- ”*” (x2A, asterisk) denotes an alias node.
	TAG = 13, -- ”!” (x21, exclamation) denotes a non-specific tag.
	LITERAL = 14, -- ”|” (7C, vertical bar) denotes a literal block scalar.
	FOLDED = 15, -- ”>” (x3E, greater than) denotes a folded block scalar.
	SINGLE_QUOTE = 16, -- ”'” (x27, apostrophe) surrounds a single-quoted flow scalar.
	DOUBLE_QUOTE = 17, -- ””” (x22, double quote) surrounds a double-quoted flow scalar.
	DIRECTIVE = 18, -- ”%” (x25, percent) denotes a directive line.
	RESERVED = 19, -- ”@” (x40, at) and “`” (x60, grave accent) are reserved for future use.

	ANY = 20,
	NL = 21,
	INDENT = 22,
	DOC = 23,
	CONT = 24,
	START_DOC = 25,
	END_DOC = 26,
	FLOW = 27,
	KEY = 28,
	VALUE = 29,
	STORE = 30,
	SKIP = 31,
	FLOW_KEY = 32,
	FLOW_VALUE = 33,
	FLOW_MAPPINNG_VALUE = 34,
	FLOW_COLLECT_ENTRY = 35,
	FLOW_STORE = 36,
}

local function state_to_name(state)
	for k, v in pairs(states) do
		if v == state then
			return k
		end
	end
	return nil
end

local transitions = {
	[states.START] = {
		{ "---", states.START_DOC },
		{ "...", states.END_DOC },
		{ " ", states.INDENT },
		{ "-", states.SEQUENCE_ENTRY },
		{ ": ", states.MAPPING_VALUE },
		{ ":\n", states.MAPPING_VALUE_NL }, -- TODO also support \r
		{ "\n", states.NL },
		{ "\r", states.NL },
		{ "\r\n", states.NL },
		{ "#", states.COMMENT },
		{ "[", states.SEQUENCE_START },
		{ "{", states.MAPPING_START },
		{ "|", states.LITERAL },
		{ ">", states.FOLDED },
		{ "_", states.SCALAR },
	},
	[states.SCALAR] = {
		{ ": ", states.MAPPING_VALUE },
		{ ":\n", states.MAPPING_VALUE_NL }, -- TODO also support \r
		{ "\n", states.NL },
		{ " #", states.COMMENT },
		{ "_", states.SCALAR },
	},
	[states.COMMENT] = {
		{ "\n", states.NL },
		{ "_", states.COMMENT },
	},
	[states.MAPPING_VALUE] = {
		{ "\n", states.NL },
		{ "#", states.COMMENT },
		{ "'", states.SINGLE_QUOTE },
		{ '"', states.DOUBLE_QUOTE },
		{ "&", states.ANCHOR },
		{ "*", states.ALIAS },
		{ "{", states.MAPPING_START },
		{ "[", states.SEQUENCE_START },
		{ ">", states.FOLDED },
		{ "|", states.LITERAL },
		{ " ", states.SKIP },
		{ "_", states.SCALAR },
	},
	[states.SEQUENCE_ENTRY] = {
		{ "\n", states.NL },
		{ "#", states.COMMENT },
		{ "'", states.SINGLE_QUOTE },
		{ '"', states.DOUBLE_QUOTE },
		{ "&", states.ANCHOR },
		{ "*", states.ALIAS },
		{ "-", states.SEQUENCE_ENTRY },
		{ "{", states.MAPPING_START },
		{ "[", states.SEQUENCE_START },
		{ ">", states.FOLDED },
		{ "|", states.LITERAL },
		{ " ", states.SKIP },
		{ "_", states.SCALAR },
	},
	[states.SEQUENCE_START] = {
		{ "\n", states.NL },
		{ "#", states.COMMENT },
		{ "'", states.SINGLE_QUOTE },
		{ '"', states.DOUBLE_QUOTE },
		{ "&", states.ANCHOR },
		{ "{", states.MAPPING_START },
		{ "[", states.SEQUENCE_START },
		{ "}", states.MAPPING_END },
		{ "]", states.SEQUENCE_END },
		{ ">", states.FOLDED },
		{ "|", states.LITERAL },
		{ ",", states.SKIP },
		{ " ", states.SKIP },
		{ "_", states.SEQUENCE_VALUE },
	},
	[states.MAPPING_START] = {
		{ "\n", states.NL },
		{ "#", states.COMMENT },
		{ "'", states.SINGLE_QUOTE },
		{ '"', states.DOUBLE_QUOTE },
		{ "&", states.ANCHOR },
		{ "{", states.MAPPING_START },
		{ "[", states.SEQUENCE_STAT },
		{ "}", states.MAPPING_END },
		{ "]", states.SEQUENCE_END },
		{ ">", states.FOLDED },
		{ "|", states.LITERAL },
		{ ",", states.SKIP },
		{ ":", states.SKIP },
		{ " ", states.SKIP },
		{ "_", states.MAPPING_SCALAR },
	},
	[states.SEQUENCE_VALUE] = {
		{ "\n", states.SKIP },
		{ ",", states.SEQUENCE_START },
		{ "]", states.SEQUENCE_END },
		{ "_", states.SEQUENCE_VALUE },
	},
	[states.MAPPING_SCALAR] = {
		{ "\n", states.SKIP },
		{ ",", states.MAPPING_START },
		{ ": ", states.MAPPING_START },
		{ ":\n", states.MAPPING_START }, -- TODO also support \r
		{ "}", states.MAPPING_START },
		{ "_", states.MAPPING_SCALAR },
	},
}

-- -------------------------------------------------------------------
-- ---                        The Parser                           ---
-- -------------------------------------------------------------------

local Parser = {}

function Parser:new(str)
	local o = {}
	setmetatable(o, self)
	o.index = 0
	o.state = states.START
	o.indent = 0
	self.__index = self
	o.result = {}
	o.index = 0
	o:__parse(str)
	return o
end

function Parser:__tostring()
	local str = {}
	table.insert(str, string.format("Parser result (%d)", #self.result))
	for _, item in ipairs(self.result) do
		table.insert(
			str,
			string.format("%-15s", state_to_name(item.state))
				.. string.format("%-3d", item.indent)
				.. " ["
				.. item.row
				.. ":"
				.. item.col
				.. "]"
				.. (item.value and (" '" .. item.value .. "'") or "")
		)
	end
	return table.concat(str, "\n")
end

function Parser:__next_state(iter, state)
	if not iter:peek() then
		return nil
	end
	print(">>>" .. state_to_name(state) .. " '" .. iter:peek() .. "'")
	for _, v in ipairs(transitions[state]) do
		local peek = iter:peek(1, #v[1])
		if peek and peek == v[1] then
			-- print("===" .. state_to_name(state) .. " '" .. iter:peek() .. "' " .. state_to_name(v[2]))
			return #v[1], v[2]
		elseif v[1] == "_" then
			-- print("***" .. state_to_name(state) .. " '" .. iter:peek() .. "' " .. state_to_name(v[2]))
			return 1, v[2]
		end
	end
end

function Parser:__collect(iter, next_state, chars)
	local loop_state = next_state
	local n, state
	while not iter:eof() do
		n, state = self:__next_state(iter, loop_state)
		if state == next_state then
			table.insert(chars, iter:get(n))
		elseif state == states.COMMENT then
			iter:get(n)
			loop_state = state
		else
			break
		end
	end
	self:__push(iter, next_state, chars)
end

function Parser:__push(iter, state, chars)
	if chars then
		table.insert(
			self.result,
			{ state = state, indent = self.indent, value = table.concat(chars, ""), row = iter.row, col = iter.col }
		)
	else
		table.insert(self.result, { state = state, indent = self.indent, row = iter.row, col = iter.col })
	end
end

function Parser:next_indent(iter)
	local indent = 0
	while not iter:eof() do
		local next = iter:peek(indent + 1)
		if iter:peek(indent + 1) ~= " " then
			break
		else
			indent = indent + 1
		end
	end
	return indent
end

function Parser:__parse(str)
	local flow = 0
	local iter = StringIterator:new(str)
	local next_index, next_state
	while not iter:eof() do
		next_index, next_state = self:__next_state(iter, self.state)
		local token = iter:get(next_index)
		print(
			string.format(
				"> state: %s -> %s, from: %d, to: %d, content: '%s'",
				state_to_name(self.state),
				state_to_name(next_state),
				iter.index,
				iter.index + next_index - 1,
				token
			)
		)
		if next_state == states.INDENT then
			self.indent = self.indent + 1
		elseif next_state == states.START_DOC then
			self:__push(iter, next_state)
		elseif next_state == states.SCALAR then
			self:__collect(iter, next_state, { token })
			self.state = states.START
		elseif next_state == states.SEQUENCE_VALUE then
			self:__collect(iter, next_state, { token })
			self.state = states.SEQUENCE_START
		elseif next_state == states.MAPPING_SCALAR then
			self:__collect(iter, next_state, { token })
			self.state = states.MAPPING_START
		elseif next_state == states.SEQUENCE_START then
			flow = flow + 1
			self:__push(iter, next_state)
			self.state = states.SEQUENCE_START
		elseif next_state == states.SEQUENCE_END then
			flow = flow - 1
			self:__push(iter, next_state)
			self.state = states.SEQUENCE_START
		elseif next_state == states.MAPPING_START then
			flow = flow + 1
			self:__push(iter, next_state)
			self.state = states.MAPPING_START
		elseif next_state == states.MAPPING_END then
			flow = flow - 1
			self:__push(iter, next_state)
			self.state = states.MAPPING_START
		elseif next_state == states.COMMENT then
			self.state = next_state
		elseif next_state == states.LITERAL then
			iter:to_eol()
			local chars = {}
			local indent = self:next_indent(iter)
			while not iter:eof() do
				table.insert(chars, table.concat(iter:to_eol(), "", indent + 1))
				if self:next_indent(iter) < indent then
					break
				end
			end
			self:__push(iter, states.SCALAR, { table.concat(chars, "\n") })
			self.state = states.START
		elseif next_state == states.FOLDED then
			iter:to_eol()
			local chars = {}
			local indent = self:next_indent(iter)
			while not iter:eof() do
				table.insert(chars, table.concat(iter:to_eol(), "", indent + 1))
				if self:next_indent(iter) < indent then
					break
				end
			end
			self:__push(iter, states.SCALAR, { table.concat(chars, " ") })
			self.state = states.START
		elseif next_state == states.ANCHOR or next_state == states.ALIAS then
			local key = iter:to_space_or_nl()
			assert(key)
			self:__push(iter, next_state, key)
		elseif next_state == states.DOUBLE_QUOTE then
			local chars = iter:to_quote('"')
			self:__push(iter, states.SCALAR, chars)
			next_state = states.START
		elseif next_state == states.SINGLE_QUOTE then
			local chars = iter:to_quote("'")
			self:__push(iter, states.SCALAR, chars)
			next_state = states.START
		elseif next_state == states.MAPPING_VALUE_NL then
			self:__push(iter, states.MAPPING_VALUE)
			self.state = states.START
			self.indent = 0
		elseif next_state == states.NL then
			if flow == 0 then
				self.state = states.START
				self.indent = 0
			end
		elseif next_state ~= states.SKIP then
			self:__push(iter, next_state)
			self.state = next_state
		end
	end
end

-- -------------------------------------------------------------------
-- ---                        The Lexer                            ---
-- -------------------------------------------------------------------

local nodes = {
	START_STREAM = 1,
	END_STREAM = 2,
	START_DOC = 3,
	END_DOC = 4,
	START_SEQ = 5,
	END_SEQ = 6,
	START_MAP = 7,
	END_MAP = 8,
	VAL = 9,
}

local function node_to_name(state)
	for k, v in pairs(nodes) do
		if v == state then
			return k
		end
	end
	return nil
end

local Lexer = {}

function Lexer:new(parser)
	local o = {}
	setmetatable(o, self)
	o.index = 0
	o.tokens = parser.result
	self.__index = self
	o.result = {}
	o.anchors = {}
	return o
end

function Lexer:__match(pattern)
	if self.index + #pattern > #self.tokens then
		return false
	end
	local pos = self.index + 1
	for _, p in ipairs(pattern) do
		if p ~= self.tokens[pos].state then
			return false
		end
		pos = pos + 1
	end
	return true
end

function Lexer:__tostring()
	local result = {}
	local indent = 0
	local val_type
	for _, line in ipairs(self.result) do
		if line.state == nodes.START_STREAM then
			table.insert(result, string.format("%s+STR", string.rep(" ", indent)))
			indent = indent + 1
		elseif line.state == nodes.END_STREAM then
			indent = indent - 1
			table.insert(result, string.format("%s-STR", string.rep(" ", indent)))
		elseif line.state == nodes.START_DOC then
			table.insert(result, string.format("%s+DOC", string.rep(" ", indent)))
			indent = indent + 1
		elseif line.state == nodes.END_DOC then
			indent = indent - 1
			table.insert(result, string.format("%s-DOC", string.rep(" ", indent)))
		elseif line.state == nodes.START_SEQ then
			table.insert(result, string.format("%s+SEQ", string.rep(" ", indent)))
			indent = indent + 1
		elseif line.state == nodes.END_SEQ then
			indent = indent - 1
			table.insert(result, string.format("%s-SEQ", string.rep(" ", indent)))
		elseif line.state == nodes.START_MAP then
			table.insert(result, string.format("%s+MAP", string.rep(" ", indent)))
			indent = indent + 1
			val_type = ":"
		elseif line.state == nodes.END_MAP then
			indent = indent - 1
			table.insert(result, string.format("%s-MAP", string.rep(" ", indent)))
		elseif line.state == nodes.VAL then
			table.insert(result, string.format("%s=VAL %s%s", string.rep(" ", indent), val_type, line.value))
		end
	end
	table.insert(result, "")
	return table.concat(result, "\n")
end

function Lexer:next()
	self.index = self.index + 1
	if self.index > #self.tokens then
		return nil
	else
		return self.tokens[self.index]
	end
end

function Lexer:peek()
	if self.index + 1 > #self.tokens then
		return nil
	else
		return self.tokens[self.index + 1]
	end
end

function Lexer:eof()
	if self.index >= #self.tokens then
		return true
	else
		return false
	end
end

function Lexer:__flow_map()
	table.insert(self.result, { state = nodes.START_MAP, type = "flow" })
	self:next()
	while not self:eof() do
		if self:peek().state == states.MAPPING_SCALAR then
			assert(self:peek() and self:peek().state == states.MAPPING_SCALAR)
			table.insert(self.result, { state = nodes.VAL, type = "flow", value = self:next().value })
			table.insert(self.result, { state = nodes.VAL, type = "flow", value = self:next().value })
		elseif self:peek().state == states.MAPPING_END then
			break
		else
			error("Unexpected flow sequence child: " .. state_to_name(self:peek().state))
		end
	end
	table.insert(self.result, { state = nodes.END_MAP, type = "flow" })
end

function Lexer:__flow_sequence()
	table.insert(self.result, { state = nodes.START_SEQ, type = "flow" })
	self:next()
	while not self:eof() do
		if self:peek().state == states.SEQUENCE_VALUE then
			table.insert(self.result, { state = nodes.VAL, type = "flow", value = self:next().value })
		elseif self:peek().state == states.SEQUENCE_END then
			break
		else
			error("Unexpected flow sequence child: " .. state_to_name(self:peek().state))
		end
	end
	table.insert(self.result, { state = nodes.END_SEQ, type = "flow" })
end

function Lexer:__flow()
	local depth = 0
	while not self:eof() do
		if self:peek().state == states.SEQUENCE_START then
			depth = depth + 1
			self:__flow_sequence()
		elseif self:peek().state == states.SEQUENCE_END then
			depth = depth - 1
			self:next()
		elseif self:peek().state == states.MAPPING_START then
			depth = depth + 1
			self:__flow_map()
		elseif self:peek().state == states.MAPPING_END then
			depth = depth - 1
			self:next()
		else
			print("[TRACE] unexpected flow child: " .. state_to_name(self:peek().state))
			break
		end
		if depth == 0 then
			break
		end
	end
end

function Lexer:__map()
	print("map: " .. self:peek().indent)
	local indent = self:peek().indent
	table.insert(self.result, { state = nodes.START_MAP })
	while not self:eof() do
		print(" : " .. state_to_name(self:peek().state) .. " " .. indent .. " -> " .. self:peek().indent)
		if self:peek().indent < indent then
			print("!map break")
			break
		end
		if self:__match({ states.SCALAR, states.MAPPING_VALUE, states.SCALAR, states.MAPPING_VALUE }) then
			print("Match map with map")
			table.insert(self.result, { state = nodes.VAL, value = self:next().value })
			self:next()
			self:__map()
		elseif self:__match({ states.SCALAR, states.MAPPING_VALUE, states.SCALAR }) then
			print("Match map with scalar: " .. self:peek().value)
			table.insert(self.result, { state = nodes.VAL, value = self:next().value })
			self:next()
			table.insert(self.result, { state = nodes.VAL, value = self:next().value })
		elseif self:__match({ states.SCALAR, states.MAPPING_VALUE, states.ANCHOR, states.SCALAR }) then
			print("Match map with scalar and anchor: " .. self:peek().value)
			table.insert(self.result, { state = nodes.VAL, value = self:next().value })
			self:next()
			local anchor = self:next().value
			local next = self:next()
			assert(next)
			print("Save Anchor: " .. anchor .. "=" .. next.value)
			self.anchors[clean_key(anchor)] = next.value
			table.insert(self.result, { state = nodes.VAL, value = next.value })
		elseif self:__match({ states.SCALAR, states.MAPPING_VALUE, states.SEQUENCE_ENTRY }) then
			print("Match map with sequence: " .. self:peek().value)
			table.insert(self.result, { state = nodes.VAL, value = self:next().value })
			self:next()
			self:__collection()
		elseif self:__match({ states.SCALAR, states.MAPPING_VALUE, states.MAPPING_START }) then
			print("Match map with flow")
			table.insert(self.result, { state = nodes.VAL, value = self:next().value })
			self:next()
			self:__flow()
		else
			-- TODO we must check indentation?
			-- print(
			-- 	"not match for map: "
			-- 		.. state_to_name(self:peek().state)
			-- 		.. " ["
			-- 		.. self:peek().row
			-- 		.. ":"
			-- 		.. self:peek().col
			-- 		.. "]"
			-- )
			break
		end
	end
	table.insert(self.result, { state = nodes.END_MAP })
	print("<map")
end

function Lexer:__collection()
	print("collection")
	-- local indent = self:peek().indent
	table.insert(self.result, { state = nodes.START_SEQ })
	while not self:eof() do
		print("  > " .. state_to_name(self:peek().state))
		if self:__match({ states.SEQUENCE_ENTRY, states.SCALAR, states.MAPPING_VALUE }) then
			self:next()
			self:__map()
		elseif self:__match({ states.SEQUENCE_ENTRY, states.SCALAR }) then
			self:next()
			print("Match collection with scalar: " .. self:peek().value)
			local next = self:next()
			assert(next)
			table.insert(self.result, { state = nodes.VAL, value = next.value })
		elseif self:__match({ states.SEQUENCE_ENTRY, states.ANCHOR, states.SCALAR }) then
			self:next()
			local anchor = self:next().value
			local next = self:next()
			assert(next)
			print("Save Anchor: " .. anchor .. "=" .. next.value)
			self.anchors[clean_key(anchor)] = next.value
			table.insert(self.result, { state = nodes.VAL, anchor = anchor, value = next.value })
		elseif self:__match({ states.SEQUENCE_ENTRY, states.ALIAS }) then
			self:next()
			local alias = self:next().value
			table.insert(self.result, { state = nodes.VAL, alias = alias })
		elseif self:__match({ states.SEQUENCE_ENTRY, states.SEQUENCE_ENTRY }) then
			self:next()
			self:__collection()
		elseif self:__match({ states.SEQUENCE_ENTRY, states.SEQUENCE_START }) then
			self:next()
			self:__flow()
		else
			break
		end
	end
	table.insert(self.result, { state = nodes.END_SEQ })
	print("<collection")
end

function Lexer:tree()
	print("== Lexer")
	table.insert(self.result, { state = nodes.START_STREAM })
	table.insert(self.result, { state = nodes.START_DOC })
	if self:peek().state == states.START_DOC then
		self:next()
	end
	while not self:eof() do
		if self:__match({ states.START_DOC }) then
			if self.result[#self.result].state ~= states.END_DOC then
				table.insert(self.result, { state = nodes.END_DOC })
			end
			table.insert(self.result, { state = nodes.START_DOC })
			self:next()
		elseif self:__match({ states.SCALAR, states.MAPPING_VALUE }) then
			self:__map()
		elseif self:__match({ states.SEQUENCE_ENTRY, states.SCALAR }) then
			self:__collection()
		elseif self:__match({ states.SEQUENCE_ENTRY, states.ANCHOR, states.SCALAR }) then
			self:__collection()
		elseif self:__match({ states.SEQUENCE_ENTRY, states.ALIAS }) then
			self:__collection()
		elseif self:__match({ states.SEQUENCE_ENTRY, states.SEQUENCE_START }) then
			self:__collection()
		elseif self:__match({ states.SCALAR }) then
			table.insert(self.result, { state = nodes.VAL, value = self:next().value })
		else
			error(
				"not match for tree: "
					.. state_to_name(self:peek().state)
					.. " ["
					.. self:peek().row
					.. ":"
					.. self:peek().col
					.. "]"
			)
		end
	end
	table.insert(self.result, { state = nodes.END_DOC })
	table.insert(self.result, { state = nodes.END_STREAM })
end

function Lexer:__to_sequence(i)
	local result = {}
	assert(self.result[i].state == nodes.START_SEQ, "expected START_SEQ but is " .. node_to_name(self.result[i].state))
	i = i + 1
	while true do
		if self.result[i].state == nodes.START_SEQ then
			local res
			i, res = self:__to_sequence(i)
			table.insert(result, res)
		elseif self.result[i].state == nodes.VAL then
			if not self.result[i].value then
				if self.result[i].alias and self.anchors[clean_key(self.result[i].alias)] then
					table.insert(result, value(self.anchors[clean_key(self.result[i].alias)]))
				else
					error("no value set for sequence entry")
				end
			else
				table.insert(result, value(self.result[i].value))
				if self.result[i].anchor then
					self.anchors[clean_key(self.result[i].anchor)] = self.result[i].value
				end
			end
		elseif self.result[i].state == nodes.START_MAP then
			local res
			i, res = self:__to_map(i)
			table.insert(result, res)
		elseif self.result[i].state == nodes.END_SEQ then
			return i, result
		else
			print("ureachable: " .. node_to_name(self.result[i].state))
		end
		i = i + 1
		if i > #self.result then
			break
		end
	end
	return i, result
end

function Lexer:__to_map(i)
	local result = {}
	while true do
		if self.result[i].state == nodes.VAL then
			if self.result[i + 1].state == nodes.VAL then
				result[clean_key(self.result[i].value)] = value(self.result[i + 1].value)
				i = i + 1
			elseif self.result[i + 1].state == nodes.START_SEQ then
				local key = self.result[i].value
				local res
				i, res = self:__to_sequence(i + 1)
				result[clean_key(key)] = res
			elseif self.result[i + 1].state == nodes.START_MAP then
				local key = self.result[i].value
				local res
				i, res = self:__to_map(i + 1)
				result[clean_key(key)] = res
			else
				assert(
					self.result[i + 1] and self.result[i + 1].state == nodes.VAL,
					"expected next node to be a VAL but is "
						.. node_to_name(self.result[i + 1].state)
						.. ":@"
						.. i
						.. " "
						.. require("str").to_string(self.result)
				)
			end
		elseif self.result[i].state == nodes.END_MAP then
			break
		end
		i = i + 1
		if i > #self.result then
			break
		end
	end
	return i, result
end

function Lexer:decode()
	local result = {}
	local i = 1
	while true do
		if self.result[i].state == nodes.START_STREAM then
		elseif self.result[i].state == nodes.START_DOC then
		elseif self.result[i].state == nodes.END_DOC then
		elseif self.result[i].state == nodes.END_STREAM then
		elseif self.result[i].state == nodes.VAL then
			table.insert(result, self.result[i].value)
		elseif self.result[i].state == nodes.START_SEQ then
			local res
			i, res = self:__to_sequence(i)
			table.insert(result, res)
		elseif self.result[i].state == nodes.START_MAP then
			local res
			i, res = self:__to_map(i)
			table.insert(result, res)
		else
			error("Unknwon root element " .. node_to_name(self.result[i].state))
		end
		i = i + 1
		if i > #self.result then
			break
		end
	end

	if #result == 1 then
		return result[1]
	end
	return result
end

-- -------------------------------------------------------------------
-- ---                     The Test functions                      ---
-- -------------------------------------------------------------------

-- local text =
-- 	"\"top1\" : \n  \"key1\" : &alias1 scalar1\n'top2' : \n  'key2' : &alias2 scalar2\ntop3: &node3 \n  *alias1 : scalar3\ntop4: \n  *alias2 : scalar4\ntop5   :    \n  scalar5\ntop6: \n  &anchor6 'key6' : scalar6\n"
--
-- print(text)
-- print("-----")
--
-- local parser = Parser:new(text)
-- print(tostring(parser))
-- local lexer = Lexer:new(parser)
-- lexer:tree()
-- print(tostring(lexer))
-- print("Result:" .. require("str").to_string(lexer:decode()))

return {
	stream = function(str)
		local parser = Parser:new(str)
		local lexer = Lexer:new(parser)
		lexer:tree() -- TODO: remove
		return tostring(lexer)
	end,
	decode = function(str)
		local parser = Parser:new(str)
		local lexer = Lexer:new(parser)
		lexer:tree() -- TODO: remove
		-- print(tostring(lexer))
		return lexer:decode()
	end,
}
