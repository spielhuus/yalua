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
	o.primary_uri = nil
	o.tags = {}
	return o
end

function Parser:create_error(row, col, message)
	return string.format("[%d:%d]\n%s\n%s^ %s", row, col, self.lexer:get_line(row), string.rep(" ", col), message)
end

local function __or(self, rules)
	local state, fn
	for _, rule in ipairs(rules) do
		state, fn = rule(self)
		if state < 0 then
			return state, fn
		elseif state > 0 then
			return state, fn
		end
	end
	return 0, nil
end

function Parser:parse_tag()
	local tag_value = self.act_tag.c
	local tag_result
	if string.match(tag_value, "!!(.+)") then
		-- print("found global tag: " .. to_string(self:peek()))
		tag_result = "<" .. self.global_uri .. string.match(tag_value, "!!(.*)") .. ">"
	elseif string.match(tag_value, "!(.*)!(.+)") then
		local key, val = string.match(tag_value, "!(.+)!(.+)")
		print("found named tag: " .. key .. " " .. val .. " -> " .. to_string(self.tags))
		tag_result = "<" .. self.tags[key] .. val .. ">"
	elseif string.match(tag_value, "!(.+)") then
		if self.primary_uri then
			tag_result = "<" .. self.primary_uri .. string.match(tag_value, "!(.*)") .. ">"
		else
			tag_result = "<!" .. string.match(tag_value, "!(.*)") .. ">"
		end
	elseif tag_value == "!" then
		tag_result = "<" .. tag_value .. ">"
	else
		tag_result = tag_value
	end
	print("TAG RESULT: " .. tag_result)
	return tag_result
end

function Parser:__while(name)
	print("ENTER WHILE: " .. name)
	-- while self:peek() and self:peek().state == name and self:peek().indent >= self.indent[#self.indent] do TODO: indent
	while self:peek() and self:peek().indent >= self.indent and self:peek().state == name do
		print("WHILE: " .. self:peek().state)
		if name == "KEY" then
			local tag_result -- TODO move more to parse_tag
			if self.act_tag then
				tag_result = self:parse_tag()
				print("tag indent: " .. self.act_tag.indent .. "<" .. self:peek().indent)
				if self.act_tag.indent < self:peek().indent then
					self.result[#self.result].tag_uri = tag_result
					tag_result = nil
				end
				self.act_tag = nil
			end
			table.insert(
				self.result,
				{ state = "VAL", value = self:peek().c, indent = self:peek().indent, tag_uri = tag_result }
			)
		end
		-- table.insert(self.indent, self:next().indent) TODO: indent
		self.indent = self:next().indent
		while self:peek().state == "NL" do
			self:next()
		end

		-- if self:peek() and self:peek().state == "ANCHOR" then
		-- 	self:anchor()
		-- end
		print(">> while >> " .. name .. " >> " .. self:peek().state .. " " .. self.indent)
		res, ret = __or(self, {
			self.tag,
			self.chars,
			self.collection,
			self.map,
			self.start_flow_seq,
			self.start_flow_map,
			self.parse_anchor,
			self.nl,
			self.__alias,
		})
		print(
			"<< while << "
				.. name
				.. ", i: "
				.. self.index
				.. ", res:"
				.. res
				.. " "
				.. (self:peek() and self:peek().state or "nil")
				.. " "
				.. (self:peek() and self:peek().c or "nil")
		)
		if res ~= 1 then
			break
		end
		self:tag() -- look for tags
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
	if self:peek() and self:peek().state == "DASH" then
		print(">> collection: " .. self.indent)
		local tag_result -- TODO move more to parse_tag
		if self.act_tag then
			tag_result = self:parse_tag()
			self.act_tag = nil
		end
		table.insert(self.result, { state = "+SEQ", tag = self:peek().tag, tag_uri = tag_result })
		self:__while("DASH")
		print("<< collection")
		table.insert(self.result, { state = "-SEQ" })
		return 1
	else
		return 0
	end
end

function Parser:cmap()
	if self:peek() and self:peek().state == "CKEY" then
		self.map_value_found = false
		print(">> cmap: " .. self.indent)
		local tag_key, tag_uri
		local tag_result -- TODO move more to parse_tag
		if self.act_tag then
			tag_result = self:parse_tag()
			self.act_tag = nil
		end
		table.insert(self.result, {
			state = "+MAP",
			tag = self:peek().tag,
			anchor = self:peek().anchor,
			alias = self:peek().alias,
			tag_uri = tag_result,
		})
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
				print("get value : " .. self:peek().state)
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
				-- first_line = false
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
		table.insert(self.result, { state = "+MAP", tag = self:peek().tag, indent = self:peek().indent })
		self:__while("KEY")
		table.insert(self.result, { state = "-MAP" })
		print("<< map")
		return 1, nil
	else
		return 0, nil
	end
end

function Parser:nl()
	if self:peek() and self:peek().state == "NL" then
		self:next()
		return 1, nil
	else
		return 0, nil
	end
end

function Parser:__alias()
	if self:peek() and self:peek().state == "ALIAS" then
		print("search alias")
		print("get alias")
		self.alias = self:next().c
		table.insert(self.result, { state = "VAL", value = nil, alias = self.alias }) -- TODO rename to ali
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
		local tag_key, tag_uri
		local tag_result -- TODO move more to parse_tag
		if self.act_tag then
			tag_result = self:parse_tag()
			print("tag indent: " .. self.act_tag.indent .. "<" .. next.indent)
			if self.act_tag.indent < next.indent then
				error("tag indent does not match")
			end
			self.act_tag = nil
		end
		table.insert(self.result, {
			state = "VAL",
			value = next.c,
			anchor = next.anchor,
			alias = next.alias,
			tag = (next.tag and string.sub(next.tag, 1, 1) or nil),
			type = (next.tag and string.sub(next.tag, 1, 1) or nil),
			tag_uri = tag_result,
			indent = next.indent,
		})
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
			local has_nl = false
			local start_indent = self:peek().indent
			while self:peek() and self:peek().state == "CHAR" and self:peek().indent >= start_indent do
				local sub = self:next()
				print("start indent: " .. start_indent .. ", act_indent: " .. sub.indent)
				if sub.indent > start_indent then
					self.result[#self.result].value = self.result[#self.result].value
						.. "\n"
						.. string.rep(" ", sub.indent - start_indent)
						.. trim(sub.c, true)
				elseif sub.c == "" then
					print("empty line")
					self.result[#self.result].value = self.result[#self.result].value .. "\\n" -- TODO
					has_nl = true
				else
					print("other line")
					if has_nl then
						self.result[#self.result].value = self.result[#self.result].value .. trim(sub.c, true)
						has_nl = false
					else
						self.result[#self.result].value = self.result[#self.result].value
							.. separator
							.. trim(sub.c, true)
					end
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
			-- self.result[#self.result].value = self.result[#self.result].value .. separator
		end
		print("tag is:" .. (next.tag or "nil"))
		if next.tag == "|" or next.tag == ">" then
			self.result[#self.result].value = self.result[#self.result].value .. "\\n" -- TODO
			-- else
			-- 	self.result[#self.result].value = self.result[#self.result].value .. separator
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
			table.insert(self.result, {
				state = "VAL",
				value = key.c,
				anchor = key.anchor,
				alias = key.alias,
				tag = key.tag,
				indent = key.indent,
			})
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
		table.insert(
			self.result,
			{ state = "+MAP", tag = "{}", anchor = next.anchor, alias = next.alias, indent = next.indent }
		)
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
		print("start flow seq")
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

function Parser:parse_anchor()
	if self:peek() and self:peek().state == "ANCHOR" then
		local anchor_node = self:next()
		print("ANCHOR " .. anchor_node.c .. ":" .. anchor_node.indent)
		local anchor_index = #self.result
		self:nl()
		res, msg = __or(self, {
			self.chars,
			self.start_flow_seq,
			self.start_flow_map,
		})
		if res == 1 then
			print("search node after anchor: " .. self.result[anchor_index].state)
			if self.result[anchor_index].indent == anchor_node.indent then
				self.result[anchor_index + 1].anchor = anchor_node.c
			end
		else
			self.result[anchor_index].anchor = anchor_node.c
			-- error("node after anchor not found: " .. anchor_node.row .. ":" .. anchor_node.col)
		end
	end
	return 0
end

function Parser:tag()
	if self:peek() and self:peek().state == "TAG" then
		print("found tag: " .. self:peek().c)
		self.act_tag = self:next()
		-- local tag_value = self:next().c
		-- local tag_result
		-- if string.match(tag_value, "!!(.+)") then
		-- 	-- print("found global tag: " .. to_string(self:peek()))
		-- 	tag_result = "<" .. self.global_uri .. string.match(tag_value, "!!(.*)") .. ">"
		-- elseif string.match(tag_value, "!(.*)!(.+)") then
		-- 	local key, val = string.match(tag_value, "!(.+)!(.+)")
		-- 	-- print("found named tag: " .. key .. " " .. val)
		-- 	tag_result = "<!" .. self.tags[key] .. val .. ">"
		-- elseif string.match(tag_value, "!(.+)") then
		-- 	if self.primary_uri then
		-- 		tag_result = "<" .. self.primary_uri .. string.match(tag_value, "!(.*)") .. ">"
		-- 	else
		-- 		tag_result = "<!" .. string.match(tag_value, "!(.*)") .. ">"
		-- 	end
		-- elseif tag_value == "!" then
		-- 	tag_result = "<" .. tag_value .. ">"
		-- else
		-- 	tag_result = tag_value
		-- end
		-- local tag_index = #self.result
		-- res, msg = __or(self, {
		-- 	self.global_tag,
		-- 	self.tag,
		-- 	self.collection,
		-- 	self.map,
		-- 	self.cmap,
		-- 	self.cvalue,
		-- 	self.start_flow_seq,
		-- 	self.chars,
		-- 	self.start_doc,
		-- 	self.end_doc,
		-- 	self.__alias,
		-- 	self.nl,
		-- })
		-- if res == 0 then
		-- 	error(
		-- 		string.format(
		-- 			"[%d:%d]\n%s\n%s^ Unexpected Token found",
		-- 			self:peek().row,
		-- 			self:peek().col,
		-- 			self.lexer:get_line(self:peek().row),
		-- 			string.rep(" ", self:peek().col)
		-- 		)
		-- 	)
		-- end
		-- if self.result[tag_index + 1].state == "+MAP" then
		-- 	self.result[tag_index + 2].tag = tag_result -- handle indentation
		-- else
		-- 	self.result[tag_index + 1].tag = tag_result -- handle indentation
		-- end
		-- print("<tag")
		return 0
	else
		return 0
	end
end

function Parser:yaml()
	if self:peek() and self:peek().state == "YAML" then
		local yaml_node = self:next()
		print("set yaml version: " .. to_string(yaml_node))
		local version = string.match(yaml_node.c, "^%%YAML (%d+%.%d+)$")
		if version then
			-- TODO: what to do with yaml version
			print("yaml version is: " .. version)
			return 1
		else
			return -1, self:create_error(yaml_node.row, yaml_node.col, "Can not parse YAML version")
		end
	else
		return 0
	end
end

function Parser:global_tag()
	if self:peek() and self:peek().state == "GLOBAL_TAG" then
		print("set global uri: " .. self:peek().c .. " " .. (self:peek().tag or "nil"))
		if self:peek().tag then
			local the_tag = self:next()
			self.tags[the_tag.tag] = the_tag.c
		else
			self.primary_uri = self:next().c
		end
		return 1
	else
		return 0
	end
end

function Parser:start_line()
	while self:peek() do
		print("start line: " .. self:peek().state)
		if self:peek().state == "NL" then
			print("start line NL")
			self:next()
		else
			local res, msg
			res, msg = __or(self, {
				self.yaml,
				self.global_tag,
				self.tag,
				self.collection,
				self.map,
				self.cmap,
				self.cvalue,
				self.start_flow_seq,
				self.start_flow_map,
				self.chars,
				self.start_doc,
				self.end_doc,
				self.__alias,
			})
			if res < 0 then
				return nil, msg
			elseif res == 0 then
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
	print(to_string(self.result))
	print("------------------------------------")
	local result = {}
	table.insert(result, "+STR")
	local indent = 1
	local doc_started = false
	local tag = nil
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
				-- if string.match(line.tag, "!(.*)") then
				-- 	line_tag = "<" .. self.global_uri .. string.match(line.tag, "!(.*)") .. ">"
				-- else
				line_tag = line.tag
				-- end
			end

			local the_tag = ""
			if line.tag_uri then
				if string.match(line.tag_uri, "!!(.*)") then
					the_tag = "<" .. self.global_uri .. string.match(line.tag_uri, "!!(.*)") .. ">"
				elseif string.match(line.tag_uri, "<.*>") then
					the_tag = line.tag_uri -- .. " "
				elseif string.match(line.tag_uri, "!(.+)") then
					if self.primary_uri then
						the_tag = "<" .. self.primary_uri .. string.match(line.tag_uri, "!(.*)") .. ">"
					else
						the_tag = "<!" .. string.match(line.tag_uri, "!(.*)") .. ">"
					end
				end
			end

			table.insert(
				result,
				string.format(
					"%s%s%s%s%s%s",
					string.rep(" ", indent),
					line.state,
					(line.tag_uri and (" " .. line.tag_uri) or ""),
					(line_tag and (" " .. line_tag) or ""),
					(line.value and (" " .. line.value) or ""),
					(line.anchor and (" &" .. line.anchor) or "")
				)
			)
			tag = nil
			indent = indent + 1
		elseif string.sub(line.state, 1, 1) == "-" then
			indent = indent - 1
			table.insert(
				result,
				string.format("%s%s%s", string.rep(" ", indent), line.state, (line.value and (" " .. line.value) or ""))
			)
		elseif line.state == "TAG" then
			tag = line.value
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

			local line_tag = ""
			if line.tag_uri then
				if string.match(line.tag_uri, "!!(.*)") then
					line_tag = "<" .. self.global_uri .. string.match(line.tag_uri, "!!(.*)") .. "> "
				elseif string.match(line.tag_uri, "<.*>") then
					line_tag = line.tag_uri .. " "
				elseif string.match(line.tag_uri, "!(.+)") then
					if self.primary_uri then
						line_tag = "<" .. self.primary_uri .. string.match(line.tag_uri, "!(.*)") .. ">"
					else
						line_tag = "<!" .. string.match(line.tag_uri, "!(.*)") .. ">"
					end
				end
			end

			local line_type = ":"
			if line.type then
				line_type = line.type
			end

			table.insert(
				result,
				string.format(
					"%s=%s %s%s%s%s%s",
					string.rep(" ", indent),
					(line.alias and "ALI" or line.state),
					(line.anchor and ("&" .. trim(line.anchor) .. " ") or ""),
					(line.alias and ("*" .. trim(line.alias)) or ""),
					(line.value and line_tag or ""),
					(line.value and line_type or ""),
					(val and self:value(val) or "")
				)
			)
			tag = nil
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
	local res, msg = self:start_line()
	if not res then
		return res, msg
	else
		return self:__tostring()
	end
end

-- local input = [[
-- %YAML 1.2 foo
-- nname: foo
-- ]]
-- print(input)
-- local lexer = Lexer:new(input)
-- print(tostring(lexer))
-- local parser = Parser:new(lexer)
-- local res, msg = parser:decode() -- TODO: remove
-- if not res then
-- 	print(msg)
-- else
-- 	print(tostring(parser))
-- end

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
