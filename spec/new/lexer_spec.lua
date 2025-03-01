local assert = require("luassert")
local Lexer = require("Lexer")
local StringIterator = require("StringIterator")

describe("Lexer", function()
	it("should lex a simple key-value pair", function()
		local doc = [[ 
foo: bar
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)

		assert.Equal("CHARS", lexer.tokens[1].kind)
		assert.Equal("foo", lexer.tokens[1].value)
		assert.Equal("COLON", lexer.tokens[2].kind)
		assert.Equal("CHARS", lexer.tokens[3].kind)
		assert.Equal("bar", lexer.tokens[3].value)
	end)

	it("should lex a simple collection", function()
		local doc = [[ 
- list 1 # comment 1
- list 2 # comment 2
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)

		assert.Equal("DASH", lexer.tokens[1].kind)
		assert.Equal("CHARS", lexer.tokens[2].kind)
		assert.Equal("list 1", lexer.tokens[2].value)
		assert.Equal("DASH", lexer.tokens[3].kind)
		assert.Equal("CHARS", lexer.tokens[4].kind)
		assert.Equal("list 2", lexer.tokens[4].value)
	end)

	it("should handle document start and end", function()
		local doc = [[ 
--- 
foo: bar
... 
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)

		assert.Equal("START_DOC", lexer.tokens[1].kind)
		assert.Equal("CHARS", lexer.tokens[2].kind)
		assert.Equal("foo", lexer.tokens[2].value)
		assert.Equal("COLON", lexer.tokens[3].kind)
		assert.Equal("CHARS", lexer.tokens[4].kind)
		assert.Equal("bar", lexer.tokens[4].value)
		assert.Equal("END_DOC", lexer.tokens[5].kind)
	end)

	it("should handle comments", function()
		local doc = [[ 
# This is a comment
foo: bar # inline comment
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)

		assert.Equal("CHARS", lexer.tokens[1].kind)
		assert.Equal("foo", lexer.tokens[1].value)
		assert.Equal("COLON", lexer.tokens[2].kind)
		assert.Equal("CHARS", lexer.tokens[3].kind)
		assert.Equal("bar", lexer.tokens[3].value)
	end)

	it("should handle block sequences", function()
		local doc = [[ 
- item1
- item2
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)

		assert.Equal("DASH", lexer.tokens[1].kind)
		assert.Equal("CHARS", lexer.tokens[2].kind)
		assert.Equal("item1", lexer.tokens[2].value)
		assert.Equal("DASH", lexer.tokens[3].kind)
		assert.Equal("CHARS", lexer.tokens[4].kind)
		assert.Equal("item2", lexer.tokens[4].value)
	end)

	it("should handle quoted strings", function()
		local doc = [[ 
foo: "bar" 
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)

		assert.Equal("CHARS", lexer.tokens[1].kind)
		assert.Equal("foo", lexer.tokens[1].value)
		assert.Equal("COLON", lexer.tokens[2].kind)
		assert.Equal("CHARS", lexer.tokens[3].kind)
		assert.Equal("bar", lexer.tokens[3].value)
	end)

	it("should handle next and peek", function()
		local doc = [[ 
- item1
- item2
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)

		assert.Equal("DASH", lexer:peek().kind)
		assert.Equal("DASH", lexer:next().kind)
		assert.Equal("CHARS", lexer:peek().kind)
		assert.Equal("CHARS", lexer:next().kind)
		assert.Equal("DASH", lexer:peek().kind)
		assert.Equal("DASH", lexer:next().kind)
		assert.Equal("CHARS", lexer:peek().kind)
		assert.Equal("CHARS", lexer:next().kind)
	end)

	it("should handle list in list", function()
		local doc = [[
- [foo, bar, baz]
- [mommy, grany, girls]
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)

		assert.Equal("DASH", lexer:next().kind)
		assert.Equal("SEQ_START", lexer:next().kind)
		assert.Equal("CHARS", lexer:peek().kind)
		assert.Equal("foo", lexer:next().value)
		assert.Equal("SEP", lexer:next().kind)
		assert.Equal("CHARS", lexer:peek().kind)
		assert.Equal("bar", lexer:next().value)
		assert.Equal("SEP", lexer:next().kind)
		assert.Equal("CHARS", lexer:peek().kind)
		assert.Equal("baz", lexer:next().value)
		assert.Equal("SEQ_END", lexer:next().kind)

		assert.Equal("DASH", lexer:next().kind)
		assert.Equal("SEQ_START", lexer:next().kind)
		assert.Equal("CHARS", lexer:peek().kind)
		assert.Equal("mommy", lexer:next().value)
		assert.Equal("SEP", lexer:next().kind)
		assert.Equal("CHARS", lexer:peek().kind)
		assert.Equal("grany", lexer:next().value)
		assert.Equal("SEP", lexer:next().kind)
		assert.Equal("CHARS", lexer:peek().kind)
		assert.Equal("girls", lexer:next().value)
		assert.Equal("SEQ_END", lexer:next().kind)
		assert.is_nil(lexer:next())
	end)

	it("should handle anchor", function()
		local doc = [[
foo: &anchor bar
some: other
what: *anchor
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)

		assert.Equal("CHARS", lexer:peek().kind)
		assert.Equal("foo", lexer:next().value)
		assert.Equal("COLON", lexer:next().kind)
		assert.Equal("CHARS", lexer:peek().kind)
		assert.Equal("anchor", lexer:peek().anchor.value)
		assert.Equal("bar", lexer:next().value)

		assert.Equal("CHARS", lexer:peek().kind)
		assert.Equal("some", lexer:next().value)
		assert.Equal("COLON", lexer:next().kind)
		assert.Equal("CHARS", lexer:peek().kind)
		assert.Equal("other", lexer:next().value)

		assert.Equal("CHARS", lexer:peek().kind)
		assert.Equal("what", lexer:next().value)
		assert.Equal("COLON", lexer:next().kind)
		assert.Equal("CHARS", lexer:peek().kind)
		assert.Equal("anchor", lexer:next().alias.value)
		assert.is_nil(lexer:next())
	end)

	it("should handle folded string", function()
		local doc = [[
--- >
  Mark McGwire's
  year was crippled
  by a knee injury.
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)

		assert.Equal("START_DOC", lexer:next().kind)
		assert.Equal("FOLDED", lexer:next().kind)
		assert.Equal("CHARS", lexer:peek().kind)
		assert.Equal("Mark McGwire's", lexer:next().value)

		assert.Equal("CHARS", lexer:peek().kind)
		assert.Equal("year was crippled", lexer:next().value)
		assert.Equal("CHARS", lexer:peek().kind)
		assert.Equal("by a knee injury.", lexer:next().value)
		assert.is_nil(lexer:next())
	end)

	it("should handle literal string", function()
		local doc = [[
name: Mark McGwire
accomplishment: >
  Mark set a major league
  home run record in 1998.
stats: |
  65 Home Runs
  0.278 Batting Average
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)

		assert.Equal("CHARS", lexer:peek().kind)
		assert.Equal("name", lexer:next().value)
		assert.Equal("COLON", lexer:next().kind)
		assert.Equal("CHARS", lexer:peek().kind)
		assert.Equal("Mark McGwire", lexer:next().value)

		assert.Equal("CHARS", lexer:peek().kind)
		assert.Equal("accomplishment", lexer:next().value)
		assert.Equal("COLON", lexer:next().kind)
		assert.Equal("FOLDED", lexer:next().kind)
		assert.Equal("CHARS", lexer:peek().kind)
		assert.Equal("Mark set a major league", lexer:next().value)
		assert.Equal("CHARS", lexer:peek().kind)
		assert.Equal("home run record in 1998.", lexer:next().value)

		assert.Equal("CHARS", lexer:peek().kind)
		assert.Equal("stats", lexer:next().value)
		assert.Equal("COLON", lexer:next().kind)
		assert.Equal("LITERAL", lexer:next().kind)
		assert.Equal("CHARS", lexer:peek().kind)
		assert.Equal("65 Home Runs", lexer:next().value)
		assert.Equal("CHARS", lexer:peek().kind)
		assert.Equal("0.278 Batting Average", lexer:next().value)
		assert.is_nil(lexer:next())
	end)

	it("should handle tag definitions", function()
		local doc = [[
%TAG !e! tag:example.com,2000:app/
---
!e!foo "bar"
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)

		assert.Equal("TAG", lexer:peek().kind)
		assert.Equal("TAG !e! tag:example.com,2000:app/", lexer:next().value)
		assert.Equal("START_DOC", lexer:next().kind)
		assert.Equal("CHARS", lexer:peek().kind)
		assert.Equal("!e!foo", lexer:peek().tag.value)
		assert.Equal("bar", lexer:next().value)
		assert.is_nil(lexer:next())
	end)

	it("should handle tags", function()
		local doc = [[
--- !!omap
- Mark McGwire: 65
- Sammy Sosa: 63
- Ken Griffy: 58
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)

		assert.Equal("START_DOC", lexer:next().kind)
		assert.Equal("!!omap", lexer:peek().tag.value)
		assert.Equal("DASH", lexer:next().kind)
		assert.Equal("CHARS", lexer:peek().kind)
		assert.Equal("Mark McGwire", lexer:next().value)
		assert.Equal("COLON", lexer:next().kind)
		assert.Equal("CHARS", lexer:peek().kind)
		assert.Equal("65", lexer:next().value)

		assert.Equal("DASH", lexer:next().kind)
		assert.Equal("CHARS", lexer:peek().kind)
		assert.Equal("Sammy Sosa", lexer:next().value)
		assert.Equal("COLON", lexer:next().kind)
		assert.Equal("CHARS", lexer:peek().kind)
		assert.Equal("63", lexer:next().value)

		assert.Equal("DASH", lexer:next().kind)
		assert.Equal("CHARS", lexer:peek().kind)
		assert.Equal("Ken Griffy", lexer:next().value)
		assert.Equal("COLON", lexer:next().kind)
		assert.Equal("CHARS", lexer:peek().kind)
		assert.Equal("58", lexer:next().value)
	end)
end)
