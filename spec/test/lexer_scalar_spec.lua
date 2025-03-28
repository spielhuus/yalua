local assert = require("luassert")
local Lexer = require("Lexer")
local StringIterator = require("StringIterator")

describe("Test the scalar types", function()
	it("should lex empty key in map", function()
		local doc = [[
strip: |-
  text
clip: |
  text
keep: |+
  text
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		local expect = [[
+STR
+DOC
+MAP
=VAL :strip
=VAL |text
=VAL :clip
=VAL |text\n
=VAL :keep
=VAL |text\n
-MAP
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)

	it("should lex map with line #prefix", function()
		local doc = [[
plain: text
  lines
quoted: "text
  	lines"
block: |
  text
   	lines
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		local expect = [[
+STR
+DOC
+MAP
=VAL :plain
=VAL :text lines
=VAL :quoted
=VAL "text lines
=VAL :block
=VAL |text\n \tlines\n
-MAP
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)
end)
