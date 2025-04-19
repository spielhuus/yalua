local assert = require("luassert")
local Lexer = require("Lexer")
local Parser = require("Parser")
local StringIterator = require("StringIterator")

describe("Test Errors", function()
	it("should handle extra comma #error", function()
		local doc = [[ 
---
[ a, b, c, , ]
]]
		local iter = StringIterator:new(doc)
		local lexer, mes = Lexer:new(iter)
		assert.Equal(nil, lexer)
		assert.Equal("ERROR:3:11 empty sequence entry\n[ a, b, c, , ]\n           ^", mes)
	end)

	it("should handle, Flow mapping missing a separating comma", function()
		local doc = [[ 
---
{
foo: 1
bar: 2 }
]]
		local iter = StringIterator:new(doc)
		local lexer, mes = Lexer:new(iter)
		assert.Equal(nil, lexer)
		assert.Equal("ERROR:4:5 missing comma in flow mapping\nfoo: 1\n     ^", mes)
	end)

	it("should handle, nested key", function()
		local doc = [[ 
---
key: wrong: value
]]
		local iter = StringIterator:new(doc)
		local lexer, mes = Lexer:new(iter)
		assert.Equal(nil, lexer)
		assert.Equal("ERROR:3:5 invalid nested block mapping on the same line\nkey: wrong: value\n     ^", mes)
	end)
end)
