local Lexer = require("lexer")
local to_string = require("str").to_string
local trim = require("str").trim

-- local print = function(...) end

local URI_CORE_SCHEMA = "tag:yaml.org,2002:"

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

local function utf8(codepoint)
	if codepoint <= 0x7F then
		return string.char(codepoint)
	elseif codepoint <= 0x7FF then
		return string.char(0xC0 + (codepoint / 64), 0x80 + (codepoint % 64))
	elseif codepoint <= 0xFFFF then
		return string.char(0xE0 + (codepoint / 4096), 0x80 + ((codepoint / 64) % 64), 0x80 + (codepoint % 64))
	end
end

-- local function schema(node)
-- 	print("GetValue:" .. to_string(node))
-- 	if node.tag == "!!int" then
-- 		return tonumber(node.value)
-- 	else
-- 		return node.value
-- 	end
-- end

local Parser = {}

function Parser:new(lexer)
	local o = {}
	self.__index = self
	setmetatable(o, self)
	o.lexer = lexer
	o.index = 0
	o.indent = 0
	o.result = {}
	o.anchors = {}
	o.anchor = nil
	o.alias = nil
	o.global_uri = URI_CORE_SCHEMA
	return o
end

local function __or(self, rules)
	local state, fn
	for _, rule in ipairs(rules) do
		state, fn = rule(self)
		if state > 0 then
			return state, fn
		end
	end
	return 0, nil
end

local function __while(self, name)
	-- while self:peek() and self:peek().state == name and self:peek().indent >= self.indent[#self.indent] do TODO: indent
	while self:peek() and self:peek().state == name and self:peek().indent >= self.indent do
		print(to_string(self:peek()))
		if name == "KEY" then
			table.insert(self.result, { state = "VAL", value = self:peek().c })
		end
		-- table.insert(self.indent, self:next().indent) TODO: indent
		self.indent = self:next().indent
		while self:peek().state == "NL" do
			self:next()
		end

		if self:peek() and self:peek().state == "ANCHOR" then
			self:anchor()
		end
		print(">> while >> " .. self:peek().state .. " " .. self.indent)
		res, ret = __or(self, {
			self.chars,
			self.collection,
			self.map,
			self.start_flow_seq,
			self.start_flow_map,
			-- self.start_flow_value,
			self.nl,
			self.alias,
		})
		print("<< while << i: " .. self.index .. ", res:" .. res .. " " .. (self:peek() and self:peek().state or "nil"))
		-- table.remove(self.indent, #self.indent) TODO: indent
		if res ~= 1 then
			break
		end

		while self:peek() and self:peek().state == "NL" do
			self:next()
		end
	end

	self.indent = self:peek() and self:peek().indent or 0
	print("<while")
end

function Parser:next()
	self.index = self.index + 1
	return self.lexer.tokens[self.index]
end

function Parser:peek()
	return self.lexer.tokens[self.index + 1]
end

function Parser:collection()
	local res, ret
	if self:peek() and self:peek().state ~= "DASH" then
		return 0, nil
	end

	print(">> collection: " .. self.indent)
	table.insert(self.result, { state = "+SEQ", tag = self:peek().tag })
	__while(self, "DASH")
	print("<< collection")
	table.insert(self.result, { state = "-SEQ" })
	return 1, nil
end

function Parser:cmap()
	if self:peek() and self:peek().state == "CKEY" then
		self.map_value_found = false
		print(">> cmap: " .. self.indent)
		table.insert(
			self.result,
			{ state = "+MAP", tag = self:peek().tag, anchor = self:peek().anchor, alias = self:peek().alias }
		)
		local key = self:next()
		local first_line = true
		while self:peek() do
			print(
				"ckey line: "
					.. (first_line and "True" or "False")
					.. " "
					.. self:peek().indent
					.. ":"
					.. self:peek().state
			)
			if
				not first_line
				and self:peek().indent <= key.indent
				and self:peek().state ~= "CVALUE"
				and self:peek().state ~= "CKEY"
				and self:peek().state ~= "NL"
			then
				print("cmap break")
				break
			elseif self:peek().state == "CKEY" then
				if not self.map_value_found then
					table.insert(self.result, { state = "VAL", value = "NaN" })
				end
				self.map_value_found = false
				self:next()
				first_line = true
			elseif self:peek().state == "NL" then
				self:next()
				first_line = true
			else
				local res, msg
				res, msg = __or(self, {
					self.collection,
					self.map,
					self.cvalue,
					self.start_flow_seq,
					self.chars,
					self.start_doc,
					self.end_doc,
				})
				if res == 0 then
					error(
						string.format(
							"[%d:%d]\n%s\n%s^ Unexpected Token found",
							self:peek().row,
							self:peek().col,
							self.lexer:get_line(self:peek().row),
							string.rep(" ", self:peek().col)
						)
					)
				end
				first_line = false
			end
		end
		print("end cmap")
		if not self.map_value_found then
			table.insert(self.result, { state = "VAL", value = "NaN" })
		end
		table.insert(self.result, { state = "-MAP" })
		return 1, nil
	else
		return 0, nil
	end
end

function Parser:cvalue()
	if self:peek() and self:peek().state == "CVALUE" then
		self.map_value_found = true
		print(">> cvalue: " .. self.indent)
		self:next()
		return 1, nil
	else
		return 0, nil
	end
end

function Parser:map()
	if self:peek() and self:peek().state == "KEY" then
		print(">> map: " .. self.indent)
		table.insert(self.result, { state = "+MAP", tag = self:peek().tag })
		__while(self, "KEY")
		table.insert(self.result, { state = "-MAP" })
		print("<< map")
		return 1, nil
	else
		return 0, nil
	end
end

function Parser:nl()
	if self:peek() and self:peek().state == "NL" then
		return 1, nil
	else
		return 0, nil
	end
end

function Parser:anchor()
	if self:peek() and self:peek().state == "ANCHOR" then
		-- self.anchors[trim(self:next().c)] = self:peek().c
		print("ANCHOR")
		self.anchor = self:next().c
		return 1, nil
	else
		return 0, nil
	end
end

function Parser:alias()
	if self:peek() and self:peek().state == "ALIAS" then
		self.alias = self:next().c
		return 1, nil
	else
		return 0, nil
	end
end

function Parser:start_doc()
	if self:peek() and self:peek().state == "START_DOC" then
		print("start doc")
		table.insert(self.result, { state = "+DOC", value = self:next().c })
		return 1, nil
	else
		return 0, nil
	end
end

function Parser:end_doc()
	if self:peek() and self:peek().state == "END_DOC" then
		table.insert(self.result, { state = "-DOC", value = self:next().c })
		return 1, nil
	else
		return 0, nil
	end
end

function Parser:chars()
	if self:peek() and self:peek().state == "CHAR" then
		print(">> CHARS " .. (self:peek() and self:peek().state or "none") .. " " .. (self:peek().c or "nil"))
		local next = self:next()
		table.insert(
			self.result,
			{ state = "VAL", value = next.c, anchor = next.anchor, alias = next.alias, tag = next.tag }
		)
		self.anchor = nil
		self.alias = nil
		if self:peek() and self:peek().state == "NL" then
			self:next()
		end

		local separator = " "
		if next.tag and next.tag == "|" then
			separator = "\n"
		end
		-- search for indent strings
		if self:peek() and self:peek().state == "CHAR" then
			local start_indent = self:peek().indent
			while self:peek() and self:peek().state == "CHAR" and self:peek().indent >= start_indent do
				local sub = self:next()
				print("start indent: " .. start_indent .. ", act_indent: " .. sub.indent)
				if sub.indent > start_indent then
					self.result[#self.result].value = self.result[#self.result].value
						.. "\n"
						.. string.rep(" ", sub.indent - start_indent)
						.. trim(sub.c, true)
				else
					self.result[#self.result].value = self.result[#self.result].value .. separator .. trim(sub.c, true)
				end
				if self:peek() and self:peek().state == "NL" then
					self:next()
					if self:peek() and self:peek().state == "NL" then
						print("empty line")
						self.result[#self.result].value = self.result[#self.result].value .. "\n"
						separator = "\n"
						self:next()
					end
				end
			end
		end
		if next.tag == "|" or next.tag == ">" then
			self.result[#self.result].value = self.result[#self.result].value .. "\n"
		end
		return 1, nil
	else
		return 0, nil
	end
end

function Parser:start_flow_value()
	if self:peek() and self:peek().state == "VAL" then
		print(">> flow seq: " .. self.indent)
		while self:peek() and self:peek().state == "VAL" do
			local next = self:next()
			table.insert(
				self.result,
				{ state = "VAL", value = next.c, anchor = next.anchor, alias = next.alias, tag = next.tag }
			)
		end
		print("<< flow seq")
		return 1, nil
	else
		return 0, nil
	end
end

function Parser:start_flow_map_value()
	if self:peek() and self:peek().state == "KEY" then
		print("flow map value")
		while self:peek() and self:peek().state == "KEY" do
			local key = self:next()
			table.insert(
				self.result,
				{ state = "VAL", value = key.c, anchor = key.anchor, alias = key.alias, tag = key.tag }
			)
			assert(self:peek().state == "VAL")
			local val = self:next()
			table.insert(
				self.result,
				{ state = "VAL", value = val.c, anchor = val.anchor, alias = val.alias, tag = val.tag }
			)
			print("next entry:" .. self:peek().state)
		end

		return 1, nil
	else
		return 0, nil
	end
end

function Parser:start_flow_map()
	if self:peek() and self:peek().state == "START_FLOW_MAP" then
		print("start flow map")
		local next = self:next()
		table.insert(self.result, { state = "+MAP", tag = "{}", anchor = next.anchor, alias = next.alias })
		local res, msg
		res, msg = __or(self, {
			-- self.collection,
			-- self.map,
			self.start_flow_seq,
			self.start_flow_map_value,
			self.start_flow_map,
			-- self.chars,
			-- self.start_doc,
			-- self.end_doc,
		})

		if self:peek().state == "END_FLOW_MAP" then
			self:next()
		end
		if self:peek() and self:peek().state == "NL" then
			self:next()
		end

		table.insert(self.result, { state = "-MAP" })
		print("end flow map")
		return 1, nil
	else
		return 0, nil
	end
end

function Parser:start_flow_seq()
	if self:peek() and self:peek().state == "START_FLOW_SEQ" then
		self:next()
		table.insert(self.result, { state = "+SEQ", tag = "[]" })
		local res = 1
		while self:peek() and self:peek().state ~= "END_FLOW_SEQ" and res == 1 do
			res = __or(self, {
				self.start_flow_seq,
				self.start_flow_value,
			})
		end
		if self:peek().state == "END_FLOW_SEQ" then
			self:next()
		end
		table.insert(self.result, { state = "-SEQ" })
		return 1, nil
	else
		return 0, nil
	end
end

function Parser:global_tag()
	if self:peek() and self:peek().state == "GLOBAL_TAG" then
		print("set global uri: " .. self:peek().c)
		self.global_uri = self:next().c
		return 1
	else
		return 0
	end
end

function Parser:start_line()
	while self:peek() do
		print("start line: " .. self:peek().state)
		if self:peek().state == "NL" then
			self:next()
		else
			local res, msg
			res, msg = __or(self, {
				self.global_tag,
				self.collection,
				self.map,
				self.cmap,
				self.cvalue,
				self.start_flow_seq,
				self.chars,
				self.start_doc,
				self.end_doc,
			})
			if res == 0 then
				error(
					string.format(
						"[%d:%d]\n%s\n%s^ Unexpected Token found",
						self:peek().row,
						self:peek().col,
						self.lexer:get_line(self:peek().row),
						string.rep(" ", self:peek().col)
					)
				)
			end
		end
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

function Parser:__tostring()
	print("----------------------------------")
	print(to_string(self.result))
	print("----------------------------------")
	local result = {}
	table.insert(result, "+STR")
	local indent = 1
	local doc_started = false
	if self.result[1].state ~= "+DOC" then
		table.insert(result, " +DOC")
		doc_started = true
		indent = indent + 1
	end
	for _, line in ipairs(self.result) do
		if line.state == "+DOC" then
			if doc_started then
				indent = indent - 1
				table.insert(result, string.format("%s%s%s", string.rep(" ", indent), "-DOC", ""))
			end
			table.insert(result, string.format("%s%s", string.rep(" ", indent), "+DOC ---"))
			indent = indent + 1
			doc_started = true
		elseif line.state == "-DOC" then
			indent = indent - 1
			table.insert(result, string.format("%s%s", string.rep(" ", indent), "-DOC ..."))
			doc_started = false
		elseif string.sub(line.state, 1, 1) == "+" then
			local line_tag = nil
			if line.tag then
				if string.match(line.tag, "!!(.*)") then
					line_tag = "<" .. self.global_uri .. string.match(line.tag, "!!(.*)") .. ">"
				elseif string.match(line.tag, "!(.*)") then
					line_tag = "<" .. self.global_uri .. string.match(line.tag, "!(.*)") .. ">"
				else
					line_tag = line.tag
				end
			end
			print("Anchor: " .. (line.anchor or "nil"))
			table.insert(
				result,
				string.format(
					"%s%s%s%s%s",
					string.rep(" ", indent),
					line.state,
					(line_tag and (" " .. line_tag) or ""),
					(line.value and (" " .. line.value) or ""),
					(line.anchor and (" &" .. line.anchor) or "")
				)
			)
			indent = indent + 1
		elseif string.sub(line.state, 1, 1) == "-" then
			indent = indent - 1
			table.insert(
				result,
				string.format("%s%s%s", string.rep(" ", indent), line.state, (line.value and (" " .. line.value) or ""))
			)
		else
			local val = nil -- TODO: move this to schema
			if line.value then
				if line.tag == "|" or line.tag == ">" or line.tag == '"' or line.tag == "'" then
					val = line.value
				elseif line.value == "NaN" then
					val = ""
				elseif line.value then
					val = trim(line.value)
				end
			end

			local line_tag = ":"
			if line.tag then
				if string.match(line.tag, "!!(.*)") then
					line_tag = "<" .. self.global_uri .. string.match(line.tag, "!!(.*)") .. "> :"
				elseif line.tag then
					line_tag = line.tag
				end
			end

			table.insert(
				result,
				string.format(
					"%s=%s %s%s%s%s",
					string.rep(" ", indent),
					(line.alias and "ALI" or line.state),
					(line.anchor and ("&" .. trim(line.anchor) .. " ") or ""),
					(line.alias and ("*" .. trim(line.alias)) or ""),
					(line.value and line_tag or ""),
					(val and self:value(val) or "")
				)
			)
		end
	end
	if doc_started then
		indent = indent - 1
		table.insert(result, string.format("%s%s%s", string.rep(" ", indent), "-DOC", ""))
	end
	table.insert(result, "-STR")
	table.insert(result, "")
	return table.concat(result, "\n")
end

function Parser:decode()
	self:start_line()
	return self:__tostring()
end

return {
	stream = function(doc)
		print("Document:\n" .. doc .. "----------------\n")
		local lexer = Lexer:new(doc)
		print(tostring(lexer))
		local parser = Parser:new(lexer)
		local res = parser:decode() -- TODO: remove
		return tostring(parser)
	end,
}
