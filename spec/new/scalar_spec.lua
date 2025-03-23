local assert = require("luassert")
local Lexer = require("Lexer")
local Parser = require("Parser")
local StringIterator = require("StringIterator")

describe("Test Scalars", function()
	describe("Test Scalar value in Lexer", function()
		-- 	it("", function()
		-- 		local doc = [[
		-- --- |0
		-- ]]
		-- 		local iter = StringIterator:new(doc)
		-- 		local lexer = Lexer:new(iter)
		-- 		print(tostring(lexer))
		-- 		assert.Equal("CHARS", lexer.tokens[1].kind)
		-- 		assert.Equal("foo", lexer.tokens[1].value)
		-- 		assert.Equal("COLON", lexer.tokens[2].kind)
		-- 		assert.Equal("CHARS", lexer.tokens[3].kind)
		-- 		assert.Equal("bar", lexer.tokens[3].value)
		-- 	end)

		it("should handle ", function()
			local doc = [[ 
--- |+
 ab
 
  
...
]]
			local iter = StringIterator:new(doc)
			local lexer = Lexer:new(iter)

			assert.Equal("START_DOC", lexer.tokens[1].kind)
			assert.Equal("LITERAL", lexer.tokens[2].kind)
			assert.Equal("CHARS", lexer.tokens[3].kind)
			assert.Equal("ab", lexer.tokens[3].value)
			assert.Equal("CHARS", lexer.tokens[4].kind)
			assert.Equal("", lexer.tokens[4].value)
			assert.Equal("CHARS", lexer.tokens[5].kind)
			assert.Equal("END_DOC", lexer.tokens[6].kind)
		end)

		it("should handle [] in content #subject", function()
			local doc = [[ 
- key: value with [brackets]
]]
			local iter = StringIterator:new(doc)
			local lexer = Lexer:new(iter)
			print(tostring(lexer))
			assert(lexer)

			assert.Equal("DASH", lexer.tokens[1].kind)
			assert.Equal("CHARS", lexer.tokens[2].kind)
			assert.Equal("key", lexer.tokens[2].value)
			assert.Equal("COLON", lexer.tokens[3].kind)
			assert.Equal("CHARS", lexer.tokens[4].kind)
			assert.Equal("value with [brackets]", lexer.tokens[4].value)
		end)
	end)
	describe("Test Scalar value in Parser", function()
		it("should handle #exclude", function()
			local doc = [[ 
--- |+
 ab
 
  
...
]]
			local expect = [[
+STR
 +DOC ---
  =VAL |ab\n\n \n
 -DOC ...
-STR
]]
			local iter = StringIterator:new(doc)
			local lexer = Lexer:new(iter)
			local parser = Parser:new(lexer)
			assert.is.Same(expect, tostring(parser))
		end)
	end)

	describe("Test Scalar value in Parser", function()
		it("should handle Block Scalar Header", function()
			local doc = [[ 
- | # Empty header↓
 literal
- >1 # Indentation indicator↓
  folded
- |+ # Chomping indicator↓
 keep

- >1- # Both indicators↓
  strip
]]
			local expect = [[
+STR
 +DOC
  +SEQ
   =VAL |literal\n
   =VAL > folded\n
   =VAL |keep\n\n
   =VAL > strip
  -SEQ
 -DOC
-STR
]]
			local iter = StringIterator:new(doc)
			local lexer = Lexer:new(iter)
			local parser = Parser:new(lexer)
			assert.is.Same(expect, tostring(parser))
		end)
	end)
end)
