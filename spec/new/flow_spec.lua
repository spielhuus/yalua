local assert = require("luassert")
local Lexer = require("Lexer")
local Parser = require("Parser")
local StringIterator = require("StringIterator")

describe("Test Flow", function()
	describe("Test Flow node in Lexer", function()
		it("should handle simple collection", function()
			local doc = [[ 
[a, b, c, d]
]]
			local iter = StringIterator:new(doc)
			local lexer = Lexer:new(iter)

			assert.Equal("SEQ_START", lexer.tokens[1].kind)
			assert.Equal("CHARS", lexer.tokens[2].kind)
			assert.Equal("a", lexer.tokens[2].value)
			assert.Equal("SEP", lexer.tokens[3].kind)
			assert.Equal("CHARS", lexer.tokens[4].kind)
			assert.Equal("b", lexer.tokens[4].value)
			assert.Equal("SEP", lexer.tokens[5].kind)
			assert.Equal("CHARS", lexer.tokens[6].kind)
			assert.Equal("c", lexer.tokens[6].value)
			assert.Equal("SEP", lexer.tokens[7].kind)
			assert.Equal("CHARS", lexer.tokens[8].kind)
			assert.Equal("d", lexer.tokens[8].value)
			assert.Equal("SEQ_END", lexer.tokens[9].kind)
			assert.is_nil(lexer.tokens[10])
		end)
		it("should handle simple map", function()
			local doc = [[ 
{a: b, c: d}
]]
			local iter = StringIterator:new(doc)
			local lexer = Lexer:new(iter)

			assert.Equal("MAP_START", lexer.tokens[1].kind)
			assert.Equal("CHARS", lexer.tokens[2].kind)
			assert.Equal("a", lexer.tokens[2].value)
			assert.Equal("COLON", lexer.tokens[3].kind)
			assert.Equal("CHARS", lexer.tokens[4].kind)
			assert.Equal("b", lexer.tokens[4].value)
			assert.Equal("SEP", lexer.tokens[5].kind)
			assert.Equal("CHARS", lexer.tokens[6].kind)
			assert.Equal("c", lexer.tokens[6].value)
			assert.Equal("COLON", lexer.tokens[7].kind)
			assert.Equal("CHARS", lexer.tokens[8].kind)
			assert.Equal("d", lexer.tokens[8].value)
			assert.Equal("MAP_END", lexer.tokens[9].kind)
			assert.is_nil(lexer.tokens[10])
		end)
		it("should handle nested map and collection", function()
			local doc = [[ 
{ a: [b, c, { d: [e, f] } ] }
]]
			local iter = StringIterator:new(doc)
			local lexer = Lexer:new(iter)

			assert.Equal("MAP_START", lexer.tokens[1].kind)
			assert.Equal("CHARS", lexer.tokens[2].kind)
			assert.Equal("a", lexer.tokens[2].value)
			assert.Equal("COLON", lexer.tokens[3].kind)
			assert.Equal("SEQ_START", lexer.tokens[4].kind)
			assert.Equal("b", lexer.tokens[5].value)
			assert.Equal("SEP", lexer.tokens[6].kind)
			assert.Equal("CHARS", lexer.tokens[7].kind)
			assert.Equal("c", lexer.tokens[7].value)
			assert.Equal("SEP", lexer.tokens[8].kind)
			assert.Equal("MAP_START", lexer.tokens[9].kind)
			assert.Equal("CHARS", lexer.tokens[10].kind)
			assert.Equal("d", lexer.tokens[10].value)
			assert.Equal("COLON", lexer.tokens[11].kind)
			assert.Equal("SEQ_START", lexer.tokens[12].kind)
			assert.Equal("CHARS", lexer.tokens[13].kind)
			assert.Equal("e", lexer.tokens[13].value)
			assert.Equal("SEP", lexer.tokens[14].kind)
			assert.Equal("CHARS", lexer.tokens[15].kind)
			assert.Equal("f", lexer.tokens[15].value)

			assert.Equal("SEQ_END", lexer.tokens[16].kind)
			assert.Equal("MAP_END", lexer.tokens[17].kind)
			assert.Equal("SEQ_END", lexer.tokens[18].kind)
			assert.Equal("MAP_END", lexer.tokens[19].kind)
			assert.is_nil(lexer.tokens[20])
		end)
		it("should handle Single Pair Implicit Entries, #exclude", function()
			local doc = [[
- [ YAML : separate ]
- [ "JSON like":adjacent ]
- [ {JSON: like}:adjacent ]
      ]]

			local iter = StringIterator:new(doc)
			local lexer = Lexer:new(iter)
			print(tostring(lexer))
			assert.Equal("DASH", lexer.tokens[1].kind)
			assert.Equal("SEQ_START", lexer.tokens[2].kind)
			assert.Equal("a", lexer.tokens[2].value)
			assert.Equal("SEP", lexer.tokens[3].kind)
			assert.Equal("CHARS", lexer.tokens[4].kind)
			assert.Equal("b", lexer.tokens[4].value)
			assert.Equal("SEP", lexer.tokens[5].kind)
			assert.Equal("SEQ_START", lexer.tokens[6].kind)
			assert.Equal("CHARS", lexer.tokens[7].kind)
			assert.Equal("c", lexer.tokens[7].value)
			assert.Equal("SEP", lexer.tokens[8].kind)
			assert.Equal("CHARS", lexer.tokens[9].kind)
			assert.Equal("d", lexer.tokens[9].value)
			assert.Equal("SEQ_END", lexer.tokens[10].kind)
			assert.Equal("SEQ_END", lexer.tokens[11].kind)
			assert.is_nil(lexer.tokens[12])
		end)
		it("should handle collection in collection", function()
			local doc = "[a, b, [c, d]]"
			local iter = StringIterator:new(doc)
			local lexer = Lexer:new(iter)

			assert.Equal("SEQ_START", lexer.tokens[1].kind)
			assert.Equal("CHARS", lexer.tokens[2].kind)
			assert.Equal("a", lexer.tokens[2].value)
			assert.Equal("SEP", lexer.tokens[3].kind)
			assert.Equal("CHARS", lexer.tokens[4].kind)
			assert.Equal("b", lexer.tokens[4].value)
			assert.Equal("SEP", lexer.tokens[5].kind)
			assert.Equal("SEQ_START", lexer.tokens[6].kind)
			assert.Equal("CHARS", lexer.tokens[7].kind)
			assert.Equal("c", lexer.tokens[7].value)
			assert.Equal("SEP", lexer.tokens[8].kind)
			assert.Equal("CHARS", lexer.tokens[9].kind)
			assert.Equal("d", lexer.tokens[9].value)
			assert.Equal("SEQ_END", lexer.tokens[10].kind)
			assert.Equal("SEQ_END", lexer.tokens[11].kind)
			assert.is_nil(lexer.tokens[12])
		end)
		it("should handle nested collections #exclude", function()
			local doc = [[
    { key: [ [ [
      value
     ] ] ]   
     }
]]
			local iter = StringIterator:new(doc)
			local lexer = Lexer:new(iter)
			print(tostring(lexer))
			assert.Equal("MAP_START", lexer.tokens[1].kind)
			assert.Equal("CHARS", lexer.tokens[2].kind)
			assert.Equal("COLON", lexer.tokens[3].kind)
			assert.Equal("SEQ_START", lexer.tokens[4].kind)
			assert.Equal("SEQ_START", lexer.tokens[5].kind)
			assert.Equal("SEQ_START", lexer.tokens[6].kind)
			assert.Equal("value", lexer.tokens[7].value)
			assert.Equal("SEQ_END", lexer.tokens[8].kind)
			assert.Equal("SEQ_END", lexer.tokens[9].kind)
			assert.Equal("SEQ_END", lexer.tokens[10].kind)
			assert.Equal("MAP_END", lexer.tokens[11].kind)
			assert.is_nil(lexer.tokens[12])
		end)
		it("should handle flow map with comment", function()
			local doc = [[
{ "foo" # comment
   :bar }
]]
			local iter = StringIterator:new(doc)
			local lexer = Lexer:new(iter)
			print(tostring(lexer))
			assert.Equal("MAP_START", lexer.tokens[1].kind)
			assert.Equal("CHARS", lexer.tokens[2].kind)
			assert.Equal("foo", lexer.tokens[2].value)
			assert.Equal("COLON", lexer.tokens[3].kind)
			assert.Equal("CHARS", lexer.tokens[4].kind)
			assert.Equal("bar", lexer.tokens[4].value)
			assert.Equal("MAP_END", lexer.tokens[5].kind)
			assert.is_nil(lexer.tokens[6])
		end)
	end)

	describe("Test Scalar value in Parser", function()
		it("should handle simple collection", function()
			local doc = [[
[a, b, c, d]
	]]
			local expect = [[
+STR
 +DOC
  +SEQ []
   =VAL :a
   =VAL :b
   =VAL :c
   =VAL :d
  -SEQ
 -DOC
-STR
]]
			local iter = StringIterator:new(doc)
			local lexer = Lexer:new(iter)
			local parser = Parser:new(lexer)
			assert.is.Same(expect, tostring(parser))
		end)
		it("should handle collection in collection", function()
			local doc = "[a, b, [c, d]]"
			local expect = [[
+STR
 +DOC
  +SEQ []
   =VAL :a
   =VAL :b
   +SEQ []
    =VAL :c
    =VAL :d
   -SEQ
  -SEQ
 -DOC
-STR
]]
			local iter = StringIterator:new(doc)
			local lexer = Lexer:new(iter)
			local parser = Parser:new(lexer)
			assert.is.Same(expect, tostring(parser))
		end)
		it("should handle nested map and collection", function()
			local doc = [[
---
{ a: [b, c, { d: [e, f] } ] }
]]
			local expect = [[
+STR
 +DOC ---
  +MAP {}
   =VAL :a
   +SEQ []
    =VAL :b
    =VAL :c
    +MAP {}
     =VAL :d
     +SEQ []
      =VAL :e
      =VAL :f
     -SEQ
    -MAP
   -SEQ
  -MAP
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
