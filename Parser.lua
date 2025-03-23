local to_string = require("str").to_string
local trim = require("str").trim

local print = function(...) end

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

local Parser = {}

function Parser:new(lexer)
	local o = {}
	self.__index = self
	setmetatable(o, self)
	o.lexer = lexer
	o.result = {}
	o.index = 0
	o.state = nil
	o.global_tag = "yaml.org,2002:"
	o.named_tag = {}
	o.local_tag = nil
	local res, mes = o:parse(0)
	if res == -1 then
		return res, mes
	end
	return o
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
		if node.anchor.indent ~= node.indent then
			the_node = {
				indent = node.indent,
				kind = kind,
				anchor = {
					value = node.anchor.value,
				},
				tag = node.tag,
				value = node.value,
				row = node.row,
				col = node.col,
			}
			node.anchor = nil
		end
	end
	-- print("parent: " .. to_string(self.tokens[self.index]))
	if node.tag then
		if node.tag.indent ~= node.indent or node.tag.before then
			the_node = {
				indent = the_node.indent,
				kind = kind,
				tag = {
					value = the_node.tag.value,
				},
				anchor = the_node.anchor,
				alias = the_node.alias,
				value = the_node.value,
				row = the_node.row,
				col = the_node.col,
			}
			node.tag = nil
		else
			print("CHILD node matches")
			the_node = {
				indent = the_node.indent,
				kind = kind,
				anchor = the_node.anchor,
				alias = the_node.alias,
				value = the_node.value,
				row = the_node.row,
				col = the_node.col,
			}
		end
	elseif self.lexer.tokens[self.index] and self.lexer.tokens[self.index].tag then
		print("found parent node with tag")
		the_node = {
			indent = the_node.indent,
			kind = kind,
			tag = {
				value = self.lexer.tokens[self.index].tag.value,
			},
			anchor = the_node.anchor,
			alias = the_node.alias,
			value = the_node.value,
			row = the_node.row,
			col = the_node.col,
		}
	end
	table.insert(self.result, { kind = kind, value = the_node })
end

function Parser:scalar()
	local last_indent
	if #self.result == 1 then
		last_indent = 0
	else
		last_indent = self.result[#self.result - 1].value.indent
	end
	local indent = self.lexer:peek().indent
	if last_indent == indent then
		table.insert(self.result, { kind = "VAL", value = self.lexer:next() })
	else
		local node = self.lexer:peek()
		local result = {}
		while
			self.lexer:peek()
			and self.lexer:peek().kind == "CHARS"
			and self.lexer:peek().indent >= indent
			and not (self.lexer:peek(2) and self.lexer:peek(2).kind == "COLON")
		do
			table.insert(result, self.lexer:next().value)
		end
		node.value = table.concat(result, " ")
		table.insert(self.result, { kind = "VAL", value = node })
	end
end

function Parser:chars()
	local result = {}
	local literal_node = self.lexer:next()
	local indent = literal_node.indent
	local blank_line = false
	while
		self.lexer:peek()
		and (self.lexer:peek().kind == "CHARS" or self.lexer:peek().kind == "NL")
		and self.lexer:peek().indent >= indent
	do
		local n = self.lexer:next()
		if n.value == "" then
			print("EMPTY CHARS: " .. to_string(n))
			table.insert(result, "\n")
		else
			local r = n.indent - indent
			table.insert(result, string.rep(" ", r) .. trim(n.value) .. " ")
		end
	end
	literal_node.kind = "VAL"
	local res = table.concat(result, "")
	-- while string.sub(res, #res, #res) == " " do
	-- 	print("remove space " .. res)
	-- 	res = string.sub(res, 1, #res - 1)
	-- end
	-- literal_node.value = res .. (blank_line or literal_node.chopped and "" or "\n")
	literal_node.value = literal_node.value .. res
	table.insert(self.result, { kind = "VAL", value = literal_node })
end

function Parser:collection(indent)
	local node = self.lexer:peek()
	self:push("+SEQ", node)
	local act_indent = self.lexer:peek().indent
	-- print("+SEQ: " .. self.lexer:peek().indent)
	while self.lexer:peek() and self.lexer:match("DASH") and self.lexer:peek().indent == act_indent do
		self.lexer:skip("DASH")
		if self.lexer:match("DASH") then
			self:collection(act_indent)
		elseif self.lexer:match("CHARS", "COLON") then
			self:map(indent)
		elseif self.lexer:match("CHARS") then
			self:scalar()
		elseif self.lexer:match("SEQ_START") then
			self:flow_seq()
		elseif self.lexer:match("MAP_START") then
			self:flow_map()
		elseif self.lexer:match("ANCHOR") then -- TODO remove?
			error("found anchor")
			self:flow_map()
		elseif self.lexer:match("FOLDED") then
			self:folded()
		elseif self.lexer:match("LITERAL") then
			self:literal()
		else
			print("nothin found: " .. self.lexer:peek().kind)
			self:parse(self.lexer:peek().indent)
		end
		if self.lexer:peek() and act_indent == indent and self.lexer:peek().indent > act_indent then
			act_indent = self.lexer:peek().indent
		end
	end
	table.insert(self.result, { kind = "-SEQ", value = node })
end

function Parser:map(indent)
	local node = self.lexer:peek()
	self:push("+MAP", node)
	local act_indent = self.lexer:peek().indent
	-- print("+MAP: " .. indent .. "->" .. to_string(self.lexer:peek()))
	while self.lexer:peek() and self.lexer:match("CHARS", "COLON") and self.lexer:peek().indent == act_indent do
		-- print(" MAP: " .. indent .. "->" .. to_string(self.lexer:peek()))
		table.insert(self.result, { kind = "VAL", value = self.lexer:next() })
		self.lexer:skip("COLON")
		if self.lexer:match("CHARS", "COLON") then
			self:map(act_indent)
		elseif self.lexer:match("DASH") then
			self:collection(act_indent)
		elseif self.lexer:peek().kind == "CHARS" then
			self:scalar()
		elseif self.lexer:peek().kind == "LITERAL" then
			self:literal()
		elseif self.lexer:peek().kind == "FOLDED" then
			self:folded()
		elseif self.lexer:match("SEQ_START") then
			self:flow_seq()
		elseif self.lexer:match("MAP_START") then
			self:flow_map()
		elseif self.lexer:match("KEY", "CHARS", "COLON", "CHARS") then
			self:parse(self.lexer:peek().indent)
		else
			self:parse(self.lexer:peek().indent)
		end
		if self.lexer:peek() and self.lexer:peek().indent > act_indent then
			act_indent = self.lexer:peek().indent
		end
	end
	table.insert(self.result, { kind = "-MAP", value = node })
end

function Parser:flow_map()
	local node = self.lexer:next()
	table.insert(self.result, { kind = "+MAP {}", value = node })
	while self.lexer:peek().kind ~= "MAP_END" do
		if self.lexer:match("CHARS", "COLON", "CHARS") then
			table.insert(self.result, { kind = "VAL", value = self.lexer:next() })
			self.lexer:next()
			table.insert(self.result, { kind = "VAL", value = self.lexer:next() })
			if self.lexer:peek().kind == "SEP" then
				self.lexer:next()
			elseif self.lexer:peek().kind == "CHARS" then
				return -1, "separator missing"
			end
		elseif self.lexer:match("CHARS", "COLON", "SEQ_START") then
			table.insert(self.result, { kind = "VAL", value = self.lexer:next() })
			self.lexer:next()
			self:flow_seq()
			if self.lexer:peek().kind == "SEP" then
				self.lexer:next()
			end
		elseif self.lexer:match("COLON") then
			return -1, "COLON not alowed here"
		elseif self.lexer:match("CHARS") then
			error("what are the chars here?")
		end
	end
	self.lexer:next()
	table.insert(self.result, { kind = "-MAP", value = node })
end

function Parser:flow_seq()
	local node = self.lexer:next()
	table.insert(self.result, { kind = "+SEQ []", value = node })
	while self.lexer:peek().kind ~= "SEQ_END" do
		if self.lexer:match("COLON") then
			return -1, "Colon not allowed here"
		elseif self.lexer:match("SEP") then
			return -1, "Separator not allowed here"
		elseif self.lexer:match("CHARS") then
			local val = self.lexer:next()
			if val.value ~= "" then -- TODO: handle empty values
				table.insert(self.result, { kind = "VAL", value = val })
			end
			if self.lexer:peek().kind == "SEP" then
				self.lexer:next()
			end
		elseif self.lexer:match("SEQ_START") then
			local res, mes = self:flow_seq()
			if res == -1 then
				return res, mes
			end
		elseif self.lexer:match("MAP_START") then
			local res, mes = self:flow_map()
			if res == -1 then
				return res, mes
			end
		end
	end
	self.lexer:next()
	table.insert(self.result, { kind = "-SEQ", value = node })
	return 0, nil
end

function Parser:chop(str)
	while string.sub(str, #str, #str) == "\n" do
		str = string.sub(str, 0, #str - 1)
	end
	return str
end

function Parser:literal()
	local result = {}
	local literal_node = self.lexer:next()
	print("literal: " .. to_string(literal_node))
	local indent = (
		literal_node.indent_hint and literal_node.indent_int or (self.lexer:peek() and self.lexer:peek().indent or 0)
	)
	local blank_line = false
	while
		self.lexer:peek()
		and (self.lexer:peek().kind == "CHARS" or self.lexer:peek().kind == "NL")
		and (self.lexer:peek().indent >= indent or self.lexer:peek().value == "" or self.lexer:peek().kind == "NL")
	do
		print(" .. '" .. escape(self.lexer:peek().value or "nil") .. "'")
		local n = self.lexer:next()
		print("literal next: " .. to_string(n))
		local r
		r = n.indent - indent
		table.insert(result, string.rep(" ", r) .. (n.value and (n.value .. "\n") or "\n"))
	end
	print("res == " .. to_string(result))
	literal_node.kind = "VAL"
	literal_node.type = "LITERAL"
	local res
	-- if #result > 1 then
	-- 	res = table.concat(result, "\n")
	-- else
	-- 	res = result[1] .. "\n"
	-- end
	res = table.concat(result, "")
	if string.sub(res, #res, #res) == " " then
		res = string.sub(res, 1, #res - 1)
	end
	print("chopped = " .. (literal_node.chopped and "true" or "false") .. " " .. escape(res))
	if literal_node.chopped then
		literal_node.value = self:chop(res)
	elseif res ~= "" and string.sub(res, #res, #res) ~= "\n" then
		print("append nl")
		literal_node.value = res .. "\n"
	else
		print("as is")
		literal_node.value = res -- TODO: .. (blank_line and "" or "\n")
	end
	table.insert(self.result, { kind = "VAL", value = literal_node })
end

function Parser:folded()
	local result = {}
	local folded_node = self.lexer:next()
	print("folded: " .. to_string(folded_node))
	local indent = (folded_node.indent_hint and folded_node.indent_hint or self.lexer:peek().indent)
	print("folded indent hint = " .. indent)
	local blank_line = false
	while
		self.lexer:peek()
		and (self.lexer:peek().kind == "CHARS" or self.lexer:peek().kind == "NL")
		and (self.lexer:peek().indent >= indent or (self.lexer:peek() and self.lexer:peek().value == ""))
	do
		local spacer = " "
		local n = self.lexer:next()
		print("folded next = " .. to_string(n))
		if self.lexer:peek() and self.lexer:peek().kind == "NL" then
			spacer = "\n\n"
			self.lexer:next()
			blank_line = true
		elseif self.lexer:peek() and self.lexer:peek().kind == "CHARS" and trim(self.lexer:peek().value) == "" then
			spacer = "\n"
			self.lexer:next()
		elseif self.lexer:peek() and self.lexer:peek().indent > indent then
			spacer = "\n"
		end
		local r
		r = n.indent - indent
		table.insert(result, string.rep(" ", r) .. (n.value or "") .. spacer)
	end
	folded_node.kind = "VAL"
	folded_node.type = "FOLDED"
	local res
	if #result > 1 then
		res = table.concat(result, "")
	else
		res = result[1]
		if string.sub(res, #res, #res) == " " then
			res = string.sub(res, 1, #res - 1)
		end
		res = res .. (folded_node.chopped and "" or "\n") -- TODO why double backslashes
	end
	if string.sub(res, #res, #res) == " " then
		res = string.sub(res, 1, #res - 1)
	end
	if folded_node.chopped == true or string.sub(res, #res, #res) == "\n" then
		folded_node.value = res -- TODO: .. (folded_node.chopped and "" or "\\n")
	else
		folded_node.value = res .. "\n"
	end
	table.insert(self.result, { kind = "VAL", value = folded_node })
end

function Parser:parse_tag(tag_value)
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

function Parser:parse(indent)
	indent = indent or 0
	while self.lexer:peek() do
		local res, msg = 0, nil
		-- print("NEXT: " .. to_string(self.lexer:peek()))
		if self.lexer:peek().indent < indent then
			break
		elseif self.lexer:match("START_DOC") then
			table.insert(self.result, { kind = "START_DOC", value = { indent = 0 } })
			self.lexer:next()
		elseif self.lexer:match("END_DOC") then
			table.insert(self.result, { kind = "END_DOC" })
			self.lexer:next()
			self.global_tag = "yaml.org,2002:"
			self.named_tag = {}
			self.local_tag = nil
		elseif self.lexer:match("DASH") then
			self:collection(indent)
		elseif self.lexer:match("CHARS", "COLON") then
			self:map(indent)
		elseif self.lexer:match("CHARS") then
			-- table.insert(self.result, { kind = "VAL", value = self.lexer:next() })
			self:chars()
		elseif self.lexer:match("SEQ_START") then
			res, msg = self:flow_seq()
		elseif self.lexer:match("MAP_START") then
			res, msg = self:flow_map()
		elseif self.lexer:match("KEY") then
			self:explicit_key(indent)
		-- TODO: remove
		elseif self.lexer:match("ANCHOR") then
			table.insert(self.result, { kind = "ANCHOR", value = self.lexer:next() })
		elseif self.lexer:match("ALIAS") then
			table.insert(self.result, { kind = "ALIAS", value = self.lexer:next() })
		elseif self.lexer:match("FOLDED") then
			self:folded()
		elseif self.lexer:match("LITERAL") then
			self:literal()
		elseif self.lexer:match("TAG") then
			local act_tag = self.lexer:next().value
			if string.match(act_tag, "^TAG !(.+)! (.+)$") then
				local key, uri = string.match(act_tag, "^TAG !(.+)! (.+)$")
				self.named_tag[key] = uri
			elseif string.match(act_tag, "^TAG !! tag:(.*)$") then
				self.global_tag = string.match(act_tag, "^TAG !! tag:(.*)$")
			elseif string.match(act_tag, "^TAG ! tag:(.*)$") then
				self.local_tag = string.match(act_tag, "^TAG ! (.*)$")
			else
				print("TAGDEF: " .. to_string(act_tag))
			end
		else
			print("Unknown token: " .. to_string(self.lexer:next()))
		end
		if res == -1 then
			return res, msg
		end
	end
end

function Parser:next()
	if self.index == 0 and self.state == nil then
		self.state = "+STR"
		return { kind = "+STR" }
	elseif self.index == 0 and self.state == "+STR" then
		if #self.result > 0 and self.result[1].kind == "START_DOC" then
			self.state = "+DOC"
			self.index = self.index + 1
			return { kind = "+DOC ---" }
		elseif #self.result > self.index then
			self.state = "+DOC"
			return { kind = "+DOC" }
		end
	end
	self.index = self.index + 1
	if self.index > #self.result then
		if self.state ~= "+STR" and self.state ~= "-DOC" and self.state ~= "-STR" then
			self.state = "-DOC"
			return { kind = "-DOC" }
		elseif self.state == "-DOC" and self.state ~= "-STR" then
			self.state = "-STR"
			return { kind = "-STR" }
		elseif self.state == "+STR" then
			self.state = "-STR"
			return { kind = "-STR" }
		end
		return nil
	else
		if self.result[self.index].kind == "START_DOC" then
			if self.state ~= "-DOC" and self.state ~= "-DOC ..." then
				self.index = self.index - 1
				self.state = "-DOC"
				return { kind = "-DOC" }
			end
			self.state = "+DOC"
			return { kind = "+DOC ---" }
		elseif self.result[self.index].kind == "END_DOC" then
			self.state = "-DOC"
			return { kind = "-DOC ..." }
		end
		self.state = self.result[self.index]
		return self.result[self.index]
	end
end

function Parser:__tostring()
	local str = {}
	local indent = 0
	local item = self:next()
	while item do
		if string.sub(item.kind, 1, 4) == "+STR" or string.sub(item.kind, 1, 4) == "+DOC" then
			table.insert(str, string.rep(" ", indent) .. item.kind)
			indent = indent + 1
		elseif string.sub(item.kind, 1, 4) == "-STR" or string.sub(item.kind, 1, 4) == "-DOC" then
			indent = indent - 1
			table.insert(str, string.rep(" ", indent) .. item.kind)
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
		else
			if item.value.alias then
				table.insert(str, string.format("%s=ALI *%s", string.rep(" ", indent), trim(item.value.alias.value)))
				-- anchor = nil
			else
				if item.value.type == "FOLDED" then
					table.insert(
						str,
						string.format("%s=%s >%s", string.rep(" ", indent), item.kind, escape(item.value.value))
					)
				elseif item.value.type == "LITERAL" then
					table.insert(
						str,
						string.format(
							"%s=%s |%s",
							string.rep(" ", indent),
							item.kind,
							escape(self:value(item.value.value))
						)
					)
				else
					table.insert(
						str,
						string.format(
							"%s=%s %s%s%s%s",
							string.rep(" ", indent),
							item.kind,
							(item.value.anchor and "&" .. item.value.anchor.value .. " " or ""),
							(item.value.tag and self:parse_tag(item.value.tag.value) .. " " or ""),
							(item.value.type and item.value.type or ":"),
							(item.value.value and escape(self:value(item.value.value)) or "")
						)
					)
				end
			end
		end
		item = self:next()
	end
	table.insert(str, "")
	return table.concat(str, "\n")
end

return Parser
