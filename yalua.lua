local StringIterator = require("StringIterator")
local Lexer = require("Lexer")
local Parser = require("Parser")

return {
	stream = function(str)
		local iter = StringIterator:new(str)
		local lexer, mes = Lexer:new(iter)
		if not lexer then
			return lexer, mes
		end
		return tostring(lexer)
	end,
	decode = function(str)
		local iter = StringIterator:new(str)
		local lexer, mes = Lexer:new(iter)
		if not lexer then
			return lexer, mes
		end
		local parser = Parser:new(lexer)
		return parser.result
	end,
	parse = function(path)
		local file = io.open(path, "r")
		if not file then
			return nil, "can not open file " .. path
		end
		local content = file:read("*all")
		file:close()
		local iter = StringIterator:new(content)
		local lexer, mes = Lexer:new(iter)
		if not lexer then
			error(mes)
		end
		local parser
		parser, mes = Parser:new(lexer)
		return parser.result, mes
	end,
}
