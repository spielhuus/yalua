local to_string = require("str").to_string
local trim = require("str").trim

local Parser = {}

function Parser:new(lexer)
	local o = {}
	self.__index = self
	setmetatable(o, self)
	o.lexer = lexer
	local res, mes = o:parse(0)
	if res == -1 then
		return res, mes
	end
	o.result = res
	return o
end

function Parser:to_value(val)
	if tonumber(val) then
		return tonumber(val)
	elseif val == "false" then
		return false
	elseif val == "true" then
		return true
	end
	return val
end

function Parser:map()
	assert(self.lexer:match("+MAP"))
	self.lexer:next()
	local res = {}
	local key = nil
	while self.lexer:peek() do
		if self.lexer:match("+MAP") then
			local child = self:map()
			assert(key)
			res[key] = child
		elseif self.lexer:match("-MAP") then
			self.lexer:next()
			return res
		elseif self.lexer:match("+SEQ") then
			local child = self:seq()
			assert(key)
			res[key] = child
		elseif self.lexer:match("KEY") then
			key = self.lexer:next().value
		elseif self.lexer:match("CHARS") then
			assert(key)
			res[key] = self:to_value(self.lexer:next().value)
		else
			print("++MAP " .. self.lexer:next().kind)
		end
	end
end

function Parser:seq()
	assert(self.lexer:match("+SEQ"))
	self.lexer:next()
	local res = {}
	while self.lexer:peek() do
		if self.lexer:match("+SEQ") then
			table.insert(res, self:seq())
		elseif self.lexer:match("-SEQ") then
			self.lexer:next()
			return res
		elseif self.lexer:match("CHARS") then
			table.insert(res, self.lexer:next().value)
		elseif self.lexer:match("+MAP") then
			table.insert(res, self:map())
		else
			print("++SEQ " .. self.lexer:next().kind)
		end
	end
end

function Parser:doc()
	local res = {}
	while self.lexer:peek() do
		if self.lexer:match("+DOC") then
			self.lexer:next()
		elseif self.lexer:match("-DOC") then
			self.lexer:next()
			return res
		elseif self.lexer:match("+SEQ") then
			res = self:seq()
		elseif self.lexer:match("+MAP") then
			res = self:map()
		else
			local node = self.lexer:next()
			-- print("++ " .. node.kind .. "='" .. node.value .. "'")
		end
	end
end

function Parser:parse()
	local res = {}
	while self.lexer:peek() do
		if self.lexer:match("+STR") then
			self.lexer:next()
		elseif self.lexer:match("-STR") then
			self.lexer:next()
			return res
		elseif self.lexer:match("+DOC") then
			res = self:doc()
		else
			print("+ " .. self.lexer:next().kind)
		end
	end
end

return Parser
