local assert = require("luassert")
local Lexer = require("Lexer")
local Parser = require("Parser")
local StringIterator = require("StringIterator")

describe("Test Errors", function()
	describe("Test errors in Lexer", function()
		it("should handle ", function()
			local doc = [[ 
---
[ a, b, c, , ]
]]
			local iter = StringIterator:new(doc)
			local lexer = Lexer:new(iter)
			-- assert.Equal("START_DOC", lexer.tokens[1].kind)
			-- assert.Equal("LITERAL", lexer.tokens[2].kind)
			-- assert.Equal("CHARS", lexer.tokens[3].kind)
			-- assert.Equal("ab", lexer.tokens[3].value)
			-- assert.Equal("CHARS", lexer.tokens[4].kind)
			-- assert.Equal("", lexer.tokens[4].value)
			-- assert.Equal("CHARS", lexer.tokens[5].kind)
			-- assert.Equal("END_DOC", lexer.tokens[6].kind)
			local parser, mes = Parser:new(lexer)
			assert.Equal(-1, parser)
			-- if parser == -1 then
			-- 	print(mes)
			-- end
		end)
		it("should handle, Flow mapping missing a separating comma", function()
			local doc = [[ 
---
{
foo: 1
bar: 2 }
]]
			local iter = StringIterator:new(doc)
			local lexer = Lexer:new(iter)
			print(tostring(lexer))
			-- assert.Equal("START_DOC", lexer.tokens[1].kind)
			-- assert.Equal("LITERAL", lexer.tokens[2].kind)
			-- assert.Equal("CHARS", lexer.tokens[3].kind)
			-- assert.Equal("ab", lexer.tokens[3].value)
			-- assert.Equal("CHARS", lexer.tokens[4].kind)
			-- assert.Equal("", lexer.tokens[4].value)
			-- assert.Equal("CHARS", lexer.tokens[5].kind)
			-- assert.Equal("END_DOC", lexer.tokens[6].kind)
			local parser, mes = Parser:new(lexer)
			assert.Equal(-1, parser)
			-- if parser == -1 then
			-- 	print(mes)
			-- end
		end)
	end)
	describe("Test errors in Parser", function() end)
end)
