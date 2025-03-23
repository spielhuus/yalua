local StringIterator = require("StringIterator")
local Lexer = require("Lexer")
local Parser = require("Parser2")

local function value(val)
	if val == "true" then
		return true
	elseif val == false then
		return false
	else
		return (tonumber(val) and tonumber(val) or val)
	end
end

local function map(p, m, indent)
	local res = {}
	local n = p:next()
	while n do
		if string.sub(n.kind, 1, 4) == "-DOC" then
			return
		elseif string.sub(n.kind, 1, 4) == "-MAP" then
			return res
		elseif string.sub(n.kind, 1, 4) == "VAL" then
			local key = n.value.value
			n = p:next()
			if string.sub(n.kind, 1, 4) == "+MAP" then
				local sub = map(p, n, indent + 1)

				res[key] = sub
			elseif string.sub(n.kind, 1, 4) == "VAL" then
				res[key] = value(n.value.value)
			end
		end
		n = p:next()
	end
end

local function seq(p, m, indent)
	local res = {}
	local n = p:next()
	while n do
		if string.sub(n.kind, 1, 4) == "-DOC" then -- TODO
			return
		elseif string.sub(n.kind, 1, 4) == "+MAP" then
			local sub = map(p, n, indent + 1)
			table.insert(res, sub)
		elseif string.sub(n.kind, 1, 4) == "-SEQ" then
			return res
		elseif string.sub(n.kind, 1, 4) == "VAL" then
			table.insert(res, value(n.value.value))
		end
		n = p:next()
	end
end

local function doc(p)
	local res = {}
	local n = p:next()
	while n do
		if string.sub(n.kind, 1, 4) == "-DOC" then
			if #res == 1 then
				return res[1]
			else
				return res
			end
		elseif string.sub(n.kind, 1, 4) == "+SEQ" then
			local sub = seq(p, n, 1)

			-- print("SEQ>MAP: " .. require("str").to_string(sub) .. "<<")
			table.insert(res, sub)
		elseif string.sub(n.kind, 1, 4) == "+MAP" then
			local sub = map(p, n, 1)
			table.insert(res, sub)
		end
		n = p:next()
	end
end

local function decode(p)
	local res = {}
	local next = p:next()
	while next do
		if string.sub(next.kind, 1, 4) == "+DOC" then
			table.insert(res, doc(p))
		elseif string.sub(next.kind, 1, 4) ~= "+STR" and string.sub(next.kind, 1, 4) ~= "-STR" then
			error("ROOT ?? " .. next.kind)
		end
		next = p:next()
	end
	if #res == 1 then
		return res[1]
	else
		return res
	end
end

return {
	stream = function(str)
		print("'" .. str .. "'")
		local iter = StringIterator:new(str)
		local lexer, mes = Lexer:new(iter)
		if not lexer then
			return lexer, mes
		end
		return tostring(lexer)
	end,
	decode = function(str)
		local iter = StringIterator:new(str)
		local lexer = Lexer:new(iter)
		local parser = Parser:new(lexer)
		return decode(parser)
	end,
	parse = function(path)
		local file = io.open(path, "r")
		if not file then
			return nil, "can not open file " .. path
		end
		local content = file:read("*all")
		file:close()
		local iter = StringIterator:new(content)
		local lexer = Lexer:new(iter)
		local parser = Parser:new(lexer)
		return decode(parser)
	end,
}
