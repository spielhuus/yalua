local assert = require("luassert")
local Lexer = require("Lexer")
local StringIterator = require("StringIterator")

describe("Test the flow types", function()
	it("should lex flow sequence as root", function()
		local doc = [[
[a, b, c]
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		local expect = [[
+STR
+DOC
+SEQ []
=VAL :a
=VAL :b
=VAL :c
-SEQ
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)

	it("should lex flow sequence after doc start", function()
		local doc = [[
--- 
[flow item 1, flow item 2, flow item 3]
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		local expect = [[
+STR
+DOC ---
+SEQ []
=VAL :flow item 1
=VAL :flow item 2
=VAL :flow item 3
-SEQ
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)

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

	it("should lex map nested in sequence", function()
		local doc = [[
seq: [ 1, 2, 3, { a: b, c: d } ]
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		local expect = [[
+STR
+DOC
+MAP
=VAL :seq
+SEQ []
=VAL :1
=VAL :2
=VAL :3
+MAP {}
=VAL :a
=VAL :b
=VAL :c
=VAL :d
-MAP
-SEQ
-MAP
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)

	it("should lex map nested in sequence, with traling content", function()
		local doc = [[
seq: [ 1, 2, 3, { a: b, c: d }, 5, 6, 7 ]
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		local expect = [[
+STR
+DOC
+MAP
=VAL :seq
+SEQ []
=VAL :1
=VAL :2
=VAL :3
+MAP {}
=VAL :a
=VAL :b
=VAL :c
=VAL :d
-MAP
=VAL :5
=VAL :6
=VAL :7
-SEQ
-MAP
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)

	it("should lex map nested in sequence with anchors", function()
		local doc = [[
seq: [ &a 1, 2, 3, { a: b, c: d }, 5, 6, 7 ]
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		local expect = [[
+STR
+DOC
+MAP
=VAL :seq
+SEQ []
=VAL &a :1
=VAL :2
=VAL :3
+MAP {}
=VAL :a
=VAL :b
=VAL :c
=VAL :d
-MAP
=VAL :5
=VAL :6
=VAL :7
-SEQ
-MAP
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)

	it("should lex map nested in sequence with anchors in #map", function()
		local doc = [[
seq: [ &a 1, 2, 3, { &b a: b, c: d }, 5, 6, 7 ]
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		local expect = [[
+STR
+DOC
+MAP
=VAL :seq
+SEQ []
=VAL &a :1
=VAL :2
=VAL :3
+MAP {}
=VAL &b :a
=VAL :b
=VAL :c
=VAL :d
-MAP
=VAL :5
=VAL :6
=VAL :7
-SEQ
-MAP
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)
end)
