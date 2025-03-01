local assert = require("luassert")
local StringIterator = require("StringIterator")
local Lexer = require("Lexer")
local Parser = require("Parser")

describe("Test the Simple Parser", function()
	it("it should parse a collection", function()
		local list = [[
- list 1
- list 2
]]
		local expect = [[
+STR
 +DOC
  +SEQ
   =VAL :list 1
   =VAL :list 2
  -SEQ
 -DOC
-STR
]]
		local iter = StringIterator:new(list)
		local lexer = Lexer:new(iter)
		local parser = Parser:new(lexer)
		assert.is.Same(expect, tostring(parser))
	end)
	it("it should parse a collection with comments", function()
		local list = [[
- list 1 # comment 1
- list 2 # comment 2
]]
		local expect = [[
+STR
 +DOC
  +SEQ
   =VAL :list 1
   =VAL :list 2
  -SEQ
 -DOC
-STR
]]
		local iter = StringIterator:new(list)
		local lexer = Lexer:new(iter)
		local parser = Parser:new(lexer)
		assert.is.Same(expect, tostring(parser))
	end)
	it("it should parse nested collections", function()
		local list = [[
- list 1
- - list 2
  - list 3
- list 4
]]
		local expect = [[
+STR
 +DOC
  +SEQ
   =VAL :list 1
   +SEQ
    =VAL :list 2
    =VAL :list 3
   -SEQ
   =VAL :list 4
  -SEQ
 -DOC
-STR
]]
		local iter = StringIterator:new(list)
		local lexer = Lexer:new(iter)
		local parser = Parser:new(lexer)
		assert.is.Same(expect, tostring(parser))
	end)
	it("it should parse map", function()
		local list = [[
foo: bar
some: other
]]
		local expect = [[
+STR
 +DOC
  +MAP
   =VAL :foo
   =VAL :bar
   =VAL :some
   =VAL :other
  -MAP
 -DOC
-STR
]]
		local iter = StringIterator:new(list)
		local lexer = Lexer:new(iter)
		local parser = Parser:new(lexer)
		assert.is.Same(expect, tostring(parser))
	end)
	it("it should parse sequence in map", function()
		local list = [[
foo:
  - item 1
  - item 2
some:
  - item 3
  - item 4
]]
		local expect = [[
+STR
 +DOC
  +MAP
   =VAL :foo
   +SEQ
    =VAL :item 1
    =VAL :item 2
   -SEQ
   =VAL :some
   +SEQ
    =VAL :item 3
    =VAL :item 4
   -SEQ
  -MAP
 -DOC
-STR
]]
		local iter = StringIterator:new(list)
		local lexer = Lexer:new(iter)
		local parser = Parser:new(lexer)
		assert.is.Same(expect, tostring(parser))
	end)
	it("it should parse flow content starting with sequence", function()
		local list = [[
- [foo, bar, baz]
- [mommy, grany, girls]
]]
		local expect = [[
+STR
 +DOC
  +SEQ
   +SEQ []
    =VAL :foo
    =VAL :bar
    =VAL :baz
   -SEQ
   +SEQ []
    =VAL :mommy
    =VAL :grany
    =VAL :girls
   -SEQ
  -SEQ
 -DOC
-STR
]]
		local iter = StringIterator:new(list)
		local lexer = Lexer:new(iter)
		local parser = Parser:new(lexer)
		assert.is.Same(expect, tostring(parser))
	end)
	it("it should parse flow content starting with sequence", function()
		local list = [[
- {foo: bar, foz: baz}
- {mommy: old, grany: older, girls: young}
]]
		local expect = [[
+STR
 +DOC
  +SEQ
   +MAP {}
    =VAL :foo
    =VAL :bar
    =VAL :foz
    =VAL :baz
   -MAP
   +MAP {}
    =VAL :mommy
    =VAL :old
    =VAL :grany
    =VAL :older
    =VAL :girls
    =VAL :young
   -MAP
  -SEQ
 -DOC
-STR
]]
		local iter = StringIterator:new(list)
		local lexer = Lexer:new(iter)
		local parser = Parser:new(lexer)
		assert.is.Same(expect, tostring(parser))
	end)
	it("it should parse flow content starting with map", function()
		local list = [[
first: {foo: bar, foz: baz}
second: {
        mommy: old, 
        grany: older, 
        girls: young
}
]]
		local expect = [[
+STR
 +DOC
  +MAP
   =VAL :first
   +MAP {}
    =VAL :foo
    =VAL :bar
    =VAL :foz
    =VAL :baz
   -MAP
   =VAL :second
   +MAP {}
    =VAL :mommy
    =VAL :old
    =VAL :grany
    =VAL :older
    =VAL :girls
    =VAL :young
   -MAP
  -MAP
 -DOC
-STR
]]
		local iter = StringIterator:new(list)
		local lexer = Lexer:new(iter)
		local parser = Parser:new(lexer)
		assert.is.Same(expect, tostring(parser))
	end)
	it("it should parse simple anchor and alias", function()
		local list = [[
foo: &anchor bar
some: other
what: *anchor
]]
		local expect = [[
+STR
 +DOC
  +MAP
   =VAL :foo
   =VAL &anchor :bar
   =VAL :some
   =VAL :other
   =VAL :what
   =ALI *anchor
  -MAP
 -DOC
-STR
]]
		local iter = StringIterator:new(list)
		local lexer = Lexer:new(iter)
		local parser = Parser:new(lexer)
		assert.is.Same(expect, tostring(parser))
	end)

	it("it should parse simple flow string", function()
		local list = [[
--- >
  Mark McGwire's
  year was crippled
  by a knee injury.
]]
		local expect = [[
+STR
 +DOC ---
  =VAL >Mark McGwire's year was crippled by a knee injury.\n
 -DOC
-STR
]]
		local iter = StringIterator:new(list)
		local lexer = Lexer:new(iter)
		local parser = Parser:new(lexer)
		assert.is.Same(expect, tostring(parser))
	end)

	it("it should parse quoted string", function()
		local list = [[
  foo: "bar"
]]
		local expect = [[
+STR
 +DOC
  +MAP
   =VAL :foo
   =VAL "bar
  -MAP
 -DOC
-STR
]]
		local iter = StringIterator:new(list)
		local lexer = Lexer:new(iter)
		local parser = Parser:new(lexer)
		assert.is.Same(expect, tostring(parser))
	end)

	it("it should parse literal string", function()
		local list = [[
name: Mark McGwire
accomplishment: >
  Mark set a major league
  home run record in 1998.
stats: |
  65 Home Runs
  0.278 Batting Average
]]
		local expect = [[
+STR
 +DOC
  +MAP
   =VAL :name
   =VAL :Mark McGwire
   =VAL :accomplishment
   =VAL >Mark set a major league home run record in 1998.\n
   =VAL :stats
   =VAL |65 Home Runs\n0.278 Batting Average\n
  -MAP
 -DOC
-STR
]]
		local iter = StringIterator:new(list)
		local lexer = Lexer:new(iter)
		local parser = Parser:new(lexer)
		assert.is.Same(expect, tostring(parser))
	end)

	it("it should parse quoted string with line break", function()
		local list = [[
plain:
  This unquoted scalar
  spans many lines.

quoted: "So does this
  quoted scalar.\n"
]]
		local expect = [[
+STR
 +DOC
  +MAP
   =VAL :plain
   =VAL :This unquoted scalar spans many lines.
   =VAL :quoted
   =VAL "So does this quoted scalar.\n
  -MAP
 -DOC
-STR
]]
		local iter = StringIterator:new(list)
		local lexer = Lexer:new(iter)
		local parser = Parser:new(lexer)
		assert.is.Same(expect, tostring(parser))
	end)

	it("it should parse tag definitions", function()
		local list = [[
%TAG !e! tag:example.com,2000:app/
---
!e!foo "bar"
]]
		local expect = [[
+STR
 +DOC ---
  =VAL <tag:example.com,2000:app/foo> "bar
 -DOC
-STR
]]
		local iter = StringIterator:new(list)
		local lexer = Lexer:new(iter)
		local parser = Parser:new(lexer)
		assert.is.Same(expect, tostring(parser))
	end)

	it("it should parse tags", function()
		local list = [[
--- !!omap
- Mark McGwire: 65
- Sammy Sosa: 63
- Ken Griffy: 58
]]
		local expect = [[
+STR
 +DOC ---
  +SEQ <tag:yaml.org,2002:omap>
   +MAP
    =VAL :Mark McGwire
    =VAL :65
   -MAP
   +MAP
    =VAL :Sammy Sosa
    =VAL :63
   -MAP
   +MAP
    =VAL :Ken Griffy
    =VAL :58
   -MAP
  -SEQ
 -DOC
-STR
]]
		local iter = StringIterator:new(list)
		local lexer = Lexer:new(iter)
		local parser = Parser:new(lexer)
		assert.is.Same(expect, tostring(parser))
	end)
end)
