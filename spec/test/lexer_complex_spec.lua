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
end)
