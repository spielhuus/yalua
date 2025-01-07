local StringIterator = require("StringIterator")
local to_string = require("str").to_string

local debug = true
local log = {
	debug = function(...)
		if debug then
			local result = {}
			for i = 1, select("#", ...) do
				local x = select(i, ...)
				if type(x) == "table" then
					table.insert(result, to_string(x))
				elseif type(x) == "string" then
					table.insert(result, "'" .. x .. "'")
				elseif x == nil then
					table.insert(result, "nil")
				else
					table.insert(result, x)
				end
			end
			print(table.concat(result))
		end
	end,
}
-- -------------------------------------------------------------------
-- ---                     Utility functions                       ---
-- -------------------------------------------------------------------

local yalua_debug = true
local function log(msg)
	if yalua_debug then
		print(msg)
	end
end

local function clean_key(key)
	local trimmed = require("str").trim(key)
	return trimmed
end

local function value(val, tag)
	if tag == "|" or tag == ">" then
		return val
	else
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
	SEQUENCE_ENTRY_NL = 202, -- ”-” (x2D, hyphen) denotes a block sequence entry.
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
	FLOW_SINGLE_QUOTE = 37,
	FLOW_DOUBLE_QUOTE = 38,
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
		{ "- ", states.SEQUENCE_ENTRY },
		{ "-\n", states.SEQUENCE_ENTRY_NL },
		{ ": ", states.MAPPING_VALUE },
		{ ":\n", states.MAPPING_VALUE_NL }, -- TODO also support \r
		{ "\n", states.NL },
		{ "\r", states.NL },
		{ "\r\n", states.NL },
		{ "'", states.SINGLE_QUOTE },
		{ '"', states.DOUBLE_QUOTE },
		{ "#", states.COMMENT },
		{ "[", states.SEQUENCE_START },
		{ "{", states.MAPPING_START },
		{ "|", states.LITERAL },
		{ ">", states.FOLDED },
		{ "&", states.ANCHOR },
		{ "*", states.ALIAS },
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
		{ "!!", states.TAG },
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
		{ "- ", states.SEQUENCE_ENTRY },
		{ "{", states.MAPPING_START },
		{ "[", states.SEQUENCE_START },
		{ ">", states.FOLDED },
		{ "|", states.LITERAL },
		{ "!!", states.TAG },
		{ " ", states.SKIP },
		{ "_", states.SCALAR },
	},
	[states.SEQUENCE_START] = {
		{ "\n", states.NL },
		{ "#", states.COMMENT },
		{ "'", states.FLOW_SINGLE_QUOTE },
		{ '"', states.FLOW_DOUBLE_QUOTE },
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
	o.anchor = nil
	o.alias = nil
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
				.. (item.anchor and (" _&'" .. item.anchor .. "'") or "")
				.. (item.alias and (" _*'" .. item.alias .. "'") or "")
		)
	end
	return table.concat(str, "\n")
end

function Parser:__next_state(iter, state)
	if not iter:peek() then
		return nil
	end
	log(">>>" .. state_to_name(state) .. " '" .. iter:peek() .. "'")
	for _, v in ipairs(transitions[state]) do
		local peek = iter:peek(1, #v[1])
		if peek and peek == v[1] then
			return #v[1], v[2]
		elseif v[1] == "_" then
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

function Parser:__push(iter, state, chars, tag)
	if chars then
		table.insert(self.result, {
			state = state,
			indent = self.indent,
			anchor = self.anchor,
			value = table.concat(chars, ""),
			row = iter.row,
			tag = tag or self.tag,
			col = iter.col,
		})
		self.anchor = nil
		self.tag = nil
	else
		table.insert(self.result, {
			state = state,
			indent = self.indent,
			alias = self.alias,
			self.anchor,
			tag = (tag or self.tag),
			row = iter.row,
			col = iter.col,
		})
		self.alias = nil
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
		log(
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
		elseif next_state == states.END_DOC then
			self:__push(iter, next_state)
			self.state = states.START
		elseif next_state == states.SCALAR then
			self:__collect(iter, next_state, { token })
			self.state = states.START
		elseif next_state == states.SEQUENCE_VALUE then
			self:__collect(iter, next_state, { token })
			self.state = states.SEQUENCE_START
		elseif next_state == states.FLOW_DOUBLE_QUOTE then
			local chars = iter:to_quote('"')
			self:__push(iter, states.SEQUENCE_VALUE, chars, '"')
			next_state = states.SEQUENCE_START
		elseif next_state == states.FLOW_SINGLE_QUOTE then
			local chars = iter:to_quote("'")
			self:__push(iter, states.SEQUENCE_VALUE, chars, "'")
			next_state = states.SEQUENCE_START
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
			table.insert(chars, "")
			self:__push(iter, states.SCALAR, { table.concat(chars, "\n") }, "|")
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
			local res = table.concat(chars, " ")
			res = res .. "\n"
			self:__push(iter, states.SCALAR, { res }, ">")
			self.state = states.START
		elseif next_state == states.TAG then
			self.tag = table.concat(iter:to_space_or_nl(), "")
			assert(self.tag)
		elseif next_state == states.ANCHOR then
			self.anchor = table.concat(iter:to_space_or_nl(), "")
			assert(self.anchor)
		elseif next_state == states.ALIAS then
			self.alias = table.concat(iter:to_space_or_nl(), "")
			assert(self.alias)
			self:__push(iter, states.SCALAR)
		elseif next_state == states.DOUBLE_QUOTE then
			local chars = iter:to_quote('"')
			self:__push(iter, states.SCALAR, chars, '"')
			next_state = states.START
		elseif next_state == states.SINGLE_QUOTE then
			local chars = iter:to_quote("'")
			self:__push(iter, states.SCALAR, chars, "'")
			next_state = states.START
		elseif next_state == states.MAPPING_VALUE_NL then
			self:__push(iter, states.MAPPING_VALUE)
			self.state = states.START
			self.indent = 0
		elseif next_state == states.SEQUENCE_ENTRY_NL then
			self:__push(iter, states.SEQUENCE_ENTRY)
			self.state = states.START
			self.indent = 0
		elseif next_state == states.NL then
			if self.tag or self.alias then -- store tags without scalar
				self:__push(iter, states.SCALAR)
			end
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
	for i, p in ipairs(pattern) do
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
		log(require("str").to_string(line))
		if line.state == nodes.START_STREAM then
			table.insert(result, string.format("%s+STR", string.rep(" ", indent)))
			indent = indent + 1
		elseif line.state == nodes.END_STREAM then
			indent = indent - 1
			table.insert(result, string.format("%s-STR", string.rep(" ", indent)))
		elseif line.state == nodes.START_DOC then
			table.insert(
				result,
				string.format("%s+DOC%s", string.rep(" ", indent), (line.tag and (" " .. line.tag) or ""))
			)
			indent = indent + 1
		elseif line.state == nodes.END_DOC then
			indent = indent - 1
			table.insert(
				result,
				string.format("%s-DOC%s", string.rep(" ", indent), (line.tag and (" " .. line.tag) or ""))
			)
		elseif line.state == nodes.START_SEQ then
			table.insert(
				result,
				string.format("%s+SEQ%s", string.rep(" ", indent), (line.tag and ("" .. line.tag) or ""))
			)
			indent = indent + 1
		elseif line.state == nodes.END_SEQ then
			indent = indent - 1
			table.insert(result, string.format("%s-SEQ", string.rep(" ", indent)))
		elseif line.state == nodes.START_MAP then
			table.insert(
				result,
				string.format("%s+MAP%s", string.rep(" ", indent), (line.tag and (" " .. line.tag) or ""))
			)
			indent = indent + 1
			val_type = ":"
		elseif line.state == nodes.END_MAP then
			indent = indent - 1
			table.insert(result, string.format("%s-MAP", string.rep(" ", indent)))
		elseif line.state == nodes.VAL then
			if line.alias then
				table.insert(result, string.format("%s=ALI *%s", string.rep(" ", indent), line.alias))
			elseif line.anchor then
				table.insert(
					result,
					string.format(
						"%s=VAL &%s %s%s",
						string.rep(" ", indent),
						line.anchor,
						line.tag or ":",
						(line.value and value(line.value, line.tag) or "")
					)
				)
			else
				table.insert(
					result,
					string.format(
						"%s=VAL %s%s",
						string.rep(" ", indent),
						(line.tag or ":"),
						(line.value and value(line.value, line.tag) or "")
					)
				)
			end
		else
			error("unknown element:" .. line.state)
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

function Lexer:__copy(node, state, t)
	log("copy: " .. to_string(node))
	table.insert(self.result, {
		state = state,
		type = t,
		value = node.value,
		alias = node.alias,
		anchor = node.anchor,
		row = node.row,
		col = node.col,
		tag = node.tag,
	})
end

function Lexer:__flow_map()
	table.insert(self.result, { state = nodes.START_MAP, type = "flow", tag = "{}" })
	self:next()
	while not self:eof() do
		if self:peek().state == states.MAPPING_SCALAR then
			assert(self:peek() and self:peek().state == states.MAPPING_SCALAR)
			self:__copy(self:next(), nodes.VAL, "flow")
			self:__copy(self:next(), nodes.VAL, "flow")
		elseif self:peek().state == states.MAPPING_END then
			break
		else
			error("Unexpected flow sequence child: " .. state_to_name(self:peek().state))
		end
	end
	table.insert(self.result, { state = nodes.END_MAP, type = "flow" })
end

function Lexer:__flow_sequence()
	log(">FLOW SEQUENCE")
	table.insert(self.result, { state = nodes.START_SEQ, type = "flow", tag = "[]" })
	self:next()
	while not self:eof() do
		if self:peek().state == states.SEQUENCE_VALUE then
			self:__copy(self:next(), nodes.VAL, "flow")
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
			log("[TRACE] unexpected flow child: " .. state_to_name(self:peek().state))
			break
		end
		if depth == 0 then
			break
		end
	end
end

function Lexer:__map()
	log(
		">map: "
			.. self:peek().indent
			.. " "
			.. state_to_name(self:peek().state)
			.. ">"
			.. state_to_name(self.tokens[self.index + 1].state)
			.. ">"
			.. state_to_name(self.tokens[self.index + 2].state)
	)
	-- yalua dirty hack to detect failure when MAP_ENTRY is the last value in the stream
	if self.index + 3 > #self.tokens then
		error("break")
	end
	local indent = self:peek().indent
	table.insert(self.result, { state = nodes.START_MAP })
	while not self:eof() do
		log(" : " .. state_to_name(self:peek().state) .. " " .. indent .. " -> " .. self:peek().indent)
		if self:peek().indent < indent then
			log("!map break")
			break
		end
		if self:__match({ states.SCALAR, states.MAPPING_VALUE, states.SCALAR, states.MAPPING_VALUE }) then
			log("Match map with map")
			self:__copy(self:next(), nodes.VAL)
			self:next()
			self:__map()
		elseif self:__match({ states.SCALAR, states.MAPPING_VALUE, states.SCALAR }) then
			log("Match map with scalar: " .. (self:peek().value or "nil"))
			self:__copy(self:next(), nodes.VAL)
			self:next()
			self:__copy(self:next(), nodes.VAL)
		elseif self:__match({ states.SCALAR, states.MAPPING_VALUE, states.SEQUENCE_ENTRY }) then
			log("Match map with sequence: " .. self:peek().value)
			self:__copy(self:next(), nodes.VAL)
			self:next()
			self:__collection()
		elseif self:__match({ states.SCALAR, states.MAPPING_VALUE, states.MAPPING_START }) then
			log("Match map with flow")
			self:__copy(self:next(), nodes.VAL)
			self:next()
			self:__flow()
		elseif self:__match({ states.SCALAR, states.MAPPING_VALUE, states.SEQUENCE_START }) then
			log("Match map with flow sequence")
			self:__copy(self:next(), nodes.VAL)
			self:next()
			self:__flow()
		-- elseif self.tokens[self.index + 2] == states.MAPPING_VALUE and self.index + 3 > #self.tokens then
		-- 	error(
		-- 		"unknown match for map: "
		-- 			.. state_to_name(self:peek().state)
		-- 			.. " ["
		-- 			.. self:peek().row
		-- 			.. ":"
		-- 			.. self:peek().col
		-- 			.. "]"
		-- 	)
		else
			log(
				"unknown match for map: "
					.. state_to_name(self:peek().state)
					.. "/"
					.. state_to_name(self.tokens[2].state)
					.. " ["
					.. self:peek().row
					.. ":"
					.. self:peek().col
					.. "]"
					.. self.index + 3
					.. ">"
					.. #self.tokens
			)
			break
		end
	end
	table.insert(self.result, { state = nodes.END_MAP })
	log("<map")
end

function Lexer:__collection()
	log("collection")
	local indent = -1 -- TODO self:peek().indent
	log("SEQUENCE_INDENT: " .. indent)
	table.insert(self.result, { state = nodes.START_SEQ })
	while not self:eof() do
		log("  > " .. state_to_name(self:peek().state) .. " " .. indent .. " > " .. self:peek().indent)
		if indent == -1 and self:peek().indent > 0 then
			indent = self:peek().indent
		elseif indent > self:peek().indent then
			print("break")
			break
		end
		if self:__match({ states.SEQUENCE_ENTRY, states.SCALAR, states.MAPPING_VALUE }) then
			self:next()
			self:__map()
		elseif self:__match({ states.SEQUENCE_ENTRY, states.SCALAR }) then
			self:next()
			log("Match collection with scalar: " .. (self:peek().value or "nil"))
			self:__copy(self:next(), nodes.VAL)
		elseif self:__match({ states.SEQUENCE_ENTRY, states.SEQUENCE_ENTRY }) then
			self:next()
			self:__collection()
		elseif self:__match({ states.SEQUENCE_ENTRY, states.SEQUENCE_START }) then
			self:next()
			self:__flow()
		elseif self:__match({ states.SEQUENCE_ENTRY, states.MAPPING_START }) then
			self:next()
			self:__flow()
		else
			break
		end
	end
	table.insert(self.result, { state = nodes.END_SEQ })
	log("<collection")
end

function Lexer:tree()
	log("== Lexer")
	table.insert(self.result, { state = nodes.START_STREAM })
	if self:peek().state ~= states.START_DOC then
		table.insert(self.result, { state = nodes.START_DOC })
	end
	while not self:eof() do
		if self:__match({ states.START_DOC }) then
			if self.result[#self.result].state ~= nodes.END_DOC and #self.result > 1 then
				table.insert(self.result, { state = nodes.END_DOC })
			end
			table.insert(self.result, { state = nodes.START_DOC, tag = "---" })
			self:next()
		elseif self:__match({ states.END_DOC }) then
			table.insert(self.result, { state = nodes.END_DOC, tag = "..." })
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
		elseif self:__match({ states.SEQUENCE_ENTRY, states.SEQUENCE_SEQUENCE_ENTRY }) then
			self:__collection()
		elseif self:__match({ states.SCALAR }) then
			self:__copy(self:next(), nodes.VAL)
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

	if self.result[#self.result].state ~= nodes.END_DOC and #self.result then
		table.insert(self.result, { state = nodes.END_DOC })
	end
	table.insert(self.result, { state = nodes.END_STREAM })
end

-- create the lua table
function Lexer:scalar_or_alias(node)
	if node.value then
		if node.anchor then
			log("STORE ANCHOR: " .. node.anchor)
			self.anchors[clean_key(node.anchor)] = node.value
		end
		return node.value
	elseif node.alias and self.anchors[node.alias] then
		return self.anchors[node.alias]
	elseif node.tag then
		return "" -- TODO handle types
	else
		error("no value found for node: " .. require("str").to_string(node))
	end
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
			table.insert(result, value(self:scalar_or_alias(self.result[i])))
		elseif self.result[i].state == nodes.START_MAP then
			local res
			i, res = self:__to_map(i)
			table.insert(result, res)
		elseif self.result[i].state == nodes.END_SEQ then
			return i, result
		else
			log("ureachable: " .. node_to_name(self.result[i].state))
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
				log(require("str").to_string(self.result[i]))
				result[clean_key(self:scalar_or_alias(self.result[i]))] =
					value(self:scalar_or_alias(self.result[i + 1]))
				i = i + 1
			elseif self.result[i + 1].state == nodes.START_SEQ then
				local key = self:scalar_or_alias(self.result[i])
				local res
				i, res = self:__to_sequence(i + 1)
				result[clean_key(key)] = res
			elseif self.result[i + 1].state == nodes.START_MAP then
				local key = self:scalar_or_alias(self.result[i])
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
			table.insert(result, self:scalar_or_alias(self.result[i]))
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

-- if yalua_debug then
-- 	local input = "? a\n? b\nc:\n"
-- 	print("-----")
-- 	print(input)
-- 	local parser = Parser:new(input)
-- 	print(tostring(parser))
-- 	local lexer = Lexer:new(parser)
-- 	lexer:tree()
-- 	print(tostring(lexer))
-- 	print("Result:" .. require("str").to_string(lexer:decode()))
-- end

return {
	stream = function(str)
		-- log.debug(str)
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
