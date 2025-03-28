local assert = require("luassert")
local Lexer = require("Lexer")
local StringIterator = require("StringIterator")

describe("Test if the Lexer lexes", function()
	it("should lex a stream start document", function()
		local doc = [[
---
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		local expect = [[
+STR
+DOC ---
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)

	it("should lex a simple value", function()
		local doc = [[
---
value
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		local expect = [[
+STR
+DOC ---
=VAL :value
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)

	it("should lex a mapping", function()
		local doc = [[
---
key: value
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		local expect = [[
+STR
+DOC ---
+MAP
=VAL :key
=VAL :value
-MAP
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)

	it("should lex a sequence", function()
		local doc = [[
---
- value1
- value2
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		local expect = [[
+STR
+DOC ---
+SEQ
=VAL :value1
=VAL :value2
-SEQ
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)

	it("should lex a nested sequence", function()
		local doc = [[
---
- - value1
  - value2
- value3
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		local expect = [[
+STR
+DOC ---
+SEQ
+SEQ
=VAL :value1
=VAL :value2
-SEQ
=VAL :value3
-SEQ
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)

	it("should lex a sequence with dash and newline", function()
		local doc = [[
---
-
  key1: value1
-
  key2: value2
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		local expect = [[
+STR
+DOC ---
+SEQ
+MAP
=VAL :key1
=VAL :value1
-MAP
+MAP
=VAL :key2
=VAL :value2
-MAP
-SEQ
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)

	it("should lex a node with #multiline scalar", function()
		-- TODO invalid Yaml
		local doc = [[
# This is a comment
---
key:
 this is the first line
 and this is the second
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		local expect = [[
+STR
+DOC ---
+MAP
=VAL :key
=VAL :this is the first line and this is the second
-MAP
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)

	it("should lex a node with comment exclude", function()
		-- TODO invalid Yaml
		local doc = [[
# This is a comment
---
- - value1 # another comment
  - value2
#and a comment
- value 3
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		local expect = [[
+STR
+DOC ---
+SEQ
+SEQ
=VAL :value1
=VAL :value2
-SEQ
=VAL :value 3
-SEQ
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)

	it("should lex a seq and map on the same line", function()
		local doc = [[
# This is a comment
---
- key: value1 # another comment
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		local expect = [[
+STR
+DOC ---
+SEQ
+MAP
=VAL :key
=VAL :value1
-MAP
-SEQ
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)

	it("should lex a nested map", function()
		local doc = [[
# This is a comment
---
key: value1
foo:
  foz: baz
  boz:
    hoz: hoy
mom: happy
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		local expect = [[
+STR
+DOC ---
+MAP
=VAL :key
=VAL :value1
=VAL :foo
+MAP
=VAL :foz
=VAL :baz
=VAL :boz
+MAP
=VAL :hoz
=VAL :hoy
-MAP
-MAP
=VAL :mom
=VAL :happy
-MAP
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)

	it("should lex a map with empty characters and #tabs", function()
		local doc = [[

a: b	
seq:	
 - a	
c: d	#X
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		local expect = [[
+STR
+DOC
+MAP
=VAL :a
=VAL :b
=VAL :seq
+SEQ
=VAL :a
-SEQ
=VAL :c
=VAL :d
-MAP
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)

	it("should lex a seq and map on the same #line", function()
		local doc = [[
# This is a comment
---
- key: value1 # another comment
  foo: bar
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		local expect = [[
+STR
+DOC ---
+SEQ
+MAP
=VAL :key
=VAL :value1
=VAL :foo
=VAL :bar
-MAP
-SEQ
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)

	it("should lex a seq in map with same indentation", function()
		local doc = [[
---
hr: # 1998 hr ranking
- Mark McGwire
- Sammy Sosa
rbi:
# 1998 rbi ranking
- Sammy Sosa
- Ken Griffey
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		local expect = [[
+STR
+DOC ---
+MAP
=VAL :hr
+SEQ
=VAL :Mark McGwire
=VAL :Sammy Sosa
-SEQ
=VAL :rbi
+SEQ
=VAL :Sammy Sosa
=VAL :Ken Griffey
-SEQ
-MAP
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)

	it("should error on wrong indentation error", function()
		local doc = [[
key:
   - ok
   - also ok
  - wrong
	]]
		local iter = StringIterator:new(doc)
		local lexer, mes = Lexer:new(iter)
		assert.is_nil(lexer)
		assert.are.same("ERROR:4:2 Wrong indentation: should be 0 but is 2\n  - wrong\n  ^", mes)
	end)

	it("should parse the Wrong indendation in mapping", function()
		local doc = [[
k1: v1
 k2: v2
]]
		local iter = StringIterator:new(doc)
		local lexer, mes = Lexer:new(iter)
		assert.is_nil(lexer)
		assert.are.same("ERROR:2:1 Wrong indentation: should be 0 but is 1\n k2: v2\n ^", mes)
	end)

	it("should lex a document with a directive", function()
		local doc = [[
%TAG ! tag:clarkevans.com,2002:
--- !shape
- circle
]]
		local iter = StringIterator:new(doc)
		local lexer, _ = Lexer:new(iter)
		local expect = [[
+STR
+DOC ---
+SEQ <tag:clarkevans.com,2002:shape>
=VAL :circle
-SEQ
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)

	it("should lex a document with tag in seq", function()
		local doc = [[

%TAG ! tag:clarkevans.com,2002:
--- !shape
- !circle
  diameter: 120
]]
		local iter = StringIterator:new(doc)
		local lexer, _ = Lexer:new(iter)
		local expect = [[
+STR
+DOC ---
+SEQ <tag:clarkevans.com,2002:shape>
+MAP <tag:clarkevans.com,2002:circle>
=VAL :diameter
=VAL :120
-MAP
-SEQ
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)

	it("should lex a document with multiline #comments", function()
		local doc = [[
%TAG ! tag:clarkevans.com,2002:
--- !shape
  # Use the ! handle for presenting
  # tag:clarkevans.com,2002:circle
- !circle
  diameter: 120
]]
		local iter = StringIterator:new(doc)
		local lexer, _ = Lexer:new(iter)
		local expect = [[
+STR
+DOC ---
+SEQ <tag:clarkevans.com,2002:shape>
+MAP <tag:clarkevans.com,2002:circle>
=VAL :diameter
=VAL :120
-MAP
-SEQ
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)
end)
