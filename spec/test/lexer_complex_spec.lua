local assert = require("luassert")
local Lexer = require("Lexer")
local StringIterator = require("StringIterator")

describe("Test the complex key types", function()
	it("should lex simple complex key", function()
		local doc = [[
- ? key 
  : val
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		local expect = [[
+STR
+DOC
+SEQ
+MAP
=VAL :key
=VAL :val
-MAP
-SEQ
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)

	-- 	it("should lex simple complex multiline key", function()
	-- 		local doc = [[
	-- - ? key
	--      name : val
	-- ]]
	-- 		local iter = StringIterator:new(doc)
	-- 		local lexer = Lexer:new(iter)
	-- 		local expect = [[
	-- +STR
	-- +DOC
	-- +SEQ
	-- +MAP
	-- =VAL :key
	-- =VAL :
	-- =VAL :name
	-- =VAL :val
	-- -MAP
	-- -SEQ
	-- -DOC
	-- -STR
	-- ]]
	-- 		assert(lexer)
	-- 		assert.are.same(expect, tostring(lexer))
	-- 	end)

	it("should lex complex sequence", function()
		local doc = [[
- ? - list 1
    - list 2
  : - list 3
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		local expect = [[
+STR
+DOC
+SEQ
+MAP
+SEQ
=VAL :list 1
=VAL :list 2
-SEQ
+SEQ
=VAL :list 3
-SEQ
-MAP
-SEQ
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)

	it("should lex complex flow sequence", function()
		local doc = [[
- ? [list 1, list 2 ]
  : [list 3]
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		local expect = [[
+STR
+DOC
+SEQ
+MAP
+SEQ []
=VAL :list 1
=VAL :list 2
-SEQ
+SEQ []
=VAL :list 3
-SEQ
-MAP
-SEQ
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)

	it("should lex complex in map", function()
		local doc = [[
a: "double
  quotes" # lala
b: plain
 value  # lala
c  : #lala
  d
? # lala
 - seq1
: # lala
 - #lala
  seq2
e:
 &node # lala
 - x: y
block: > # lala
  abcde
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		local expect = [[
+STR
+DOC
+MAP
=VAL :a
=VAL "double quotes
=VAL :b
=VAL :plain value
=VAL :c
=VAL :d
+SEQ
=VAL :seq1
-SEQ
+SEQ
=VAL :seq2
-SEQ
=VAL :e
+SEQ &node
+MAP
=VAL :x
=VAL :y
-MAP
-SEQ
=VAL :block
=VAL >abcde\n
-MAP
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)

	-- 	it("should #lex complex with anchors, aliases and spaces", function()
	-- 		local doc = [[
	-- - &a
	-- - a
	-- -
	--   &a : a
	--   b: &b
	-- -
	--   &c : &a
	-- -
	--   ? &d
	-- -
	--   ? &e
	--   : &a
	-- ]]
	-- 		local iter = StringIterator:new(doc)
	-- 		local lexer = Lexer:new(iter)
	-- 		local expect = [[
	-- +STR
	-- +DOC
	-- +SEQ
	-- =VAL &a :
	-- =VAL :a
	-- +MAP
	-- =VAL &a :
	-- =VAL :a
	-- =VAL :b
	-- =VAL &b :
	-- -MAP
	-- +MAP
	-- =VAL &c :
	-- =VAL &a :
	-- -MAP
	-- +MAP
	-- =VAL &d :
	-- =VAL :
	-- -MAP
	-- +MAP
	-- =VAL &e :
	-- =VAL &a :
	-- -MAP
	-- -SEQ
	-- -DOC
	-- -STR
	-- ]]
	-- 		assert(lexer)
	-- 		assert.are.same(expect, tostring(lexer))
	-- 	end)
end)
