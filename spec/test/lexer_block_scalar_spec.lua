local assert = require("luassert")
local Lexer = require("Lexer")
local StringIterator = require("StringIterator")

describe("Test the block scalar styles", function()
	it("should parse the content indentation indicator", function()
		local doc = [[
--- >1
 line 1
 line 2
 line 3
]]
		local iter = StringIterator:new(doc)
		local lexer, _ = Lexer:new(iter)
		local expect = [[
+STR
+DOC ---
=VAL >line 1 line 2 line 3\n
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)

	it("should create an error when indicator is 0", function()
		local doc = [[
--- >0
 line 1
 line 2
 line 3
]]
		local iter = StringIterator:new(doc)
		local lexer, mes = Lexer:new(iter)
		assert.is.Nil(lexer)
		assert.is.Equal("ERROR:1:5 indentation indicator must be between 1 and 9 but is '0'\n--- >0\n     ^", mes)
	end)

	it("should create an error when indicator is #10", function()
		local doc = [[
--- >10
 line 1
 line 2
 line 3
]]
		local iter = StringIterator:new(doc)
		local lexer, mes = Lexer:new(iter)
		assert.is.Nil(lexer)
		assert.is.Equal("ERROR:1:5 indentation indicator must be between 1 and 9 but is '10'\n--- >10\n     ^", mes)
	end)
end)
