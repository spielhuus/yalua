local assert = require("luassert")
local Lexer = require("Lexer")
local StringIterator = require("StringIterator")

describe("Test the flow types", function()
	it("should lex empty key in map", function()
		local doc = [[
- [ : empty key ]
- [: another empty key]
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		local expect = [[
+STR
+DOC
+SEQ
+SEQ []
+MAP {}
=VAL :
=VAL :empty key
-MAP
-SEQ
+SEQ []
+MAP {}
=VAL :
=VAL :another empty key
-MAP
-SEQ
-SEQ
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)

	it("should lex empty key in map", function()
		local doc = [[
implicit block key : [
  implicit flow key : value,
 ]
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		local expect = [[
+STR
+DOC
+MAP
=VAL :implicit block key
+SEQ []
+MAP {}
=VAL :implicit flow key
=VAL :value
-MAP
-SEQ
-MAP
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)
end)
