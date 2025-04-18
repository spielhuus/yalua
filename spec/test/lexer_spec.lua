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
=VAL :
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

	it("should lex a mapping key, with spaces", function()
		local doc = [[
"implicit block key" : [
  "implicit flow key" : value,
 ]
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		local expect = [[
+STR
+DOC
+MAP
=VAL "implicit block key
+SEQ []
+MAP {}
=VAL "implicit flow key
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

	it("should lex a mapping key", function()
		local doc = [[
"implicit block key": [
  "implicit flow key" : value,
 ]
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		local expect = [[
+STR
+DOC
+MAP
=VAL "implicit block key
+SEQ []
+MAP {}
=VAL "implicit flow key
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

	it("should lex a node with multiline scalar", function()
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
# and a comment
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

	it("should lex a map with empty characters and tabs", function()
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

	it("should lex a seq and map on the same line", function()
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

	it("should parse the Wrong indendation in mapping error", function()
		local doc = [[
k1: v1
 k2: v2
]]
		local iter = StringIterator:new(doc)
		local lexer, mes = Lexer:new(iter)
		assert.is_nil(lexer)
		assert.are.same("ERROR:2:1 invalid multiline plain key\n k2: v2\n ^", mes)
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

	it("should lex a document with multiline comments", function()
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

	it("should lex a document with multiline comments", function()
		local doc = [[
  # Use the ! handle for presenting


]]
		local iter = StringIterator:new(doc)
		local lexer, _ = Lexer:new(iter)
		local expect = [[
+STR
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)

	it("should lex a sequence with map on new line", function()
		local doc = [[
 - key: value
   key2: value2
 - 
   key3: value3
]]
		local iter = StringIterator:new(doc)
		local lexer, _ = Lexer:new(iter)
		local expect = [[
+STR
+DOC
+SEQ
+MAP
=VAL :key
=VAL :value
=VAL :key2
=VAL :value2
-MAP
+MAP
=VAL :key3
=VAL :value3
-MAP
-SEQ
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)

	it("should lex a map with anchors and comments", function()
		local doc = [[
a: "double
  quotes" # lala
b: plain
 value  # lala
c  : #lala
  d
e:
 &node # lala
 - x: y
block: > # lala
  abcde
]]
		local iter = StringIterator:new(doc)
		local lexer, _ = Lexer:new(iter)
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

	it("should lex a map with empty values", function()
		local doc = [[
key1: val1
key2:
key3:
]]
		local iter = StringIterator:new(doc)
		local lexer, _ = Lexer:new(iter)
		local expect = [[
+STR
+DOC
+MAP
=VAL :key1
=VAL :val1
=VAL :key2
=VAL :
=VAL :key3
=VAL :
-MAP
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)

	it("should lex a map with empty values with anchor", function()
		local doc = [[
key1: val1
key2: &a
key3:
]]
		local iter = StringIterator:new(doc)
		local lexer, _ = Lexer:new(iter)
		local expect = [[
+STR
+DOC
+MAP
=VAL :key1
=VAL :val1
=VAL :key2
=VAL &a :
=VAL :key3
=VAL :
-MAP
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)

	it("should lex a sequence with empty entries", function()
		local doc = [[
- val1
- 
- val3
]]
		local iter = StringIterator:new(doc)
		local lexer, _ = Lexer:new(iter)
		local expect = [[
+STR
+DOC
+SEQ
=VAL :val1
=VAL :
=VAL :val3
-SEQ
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)

	it("should lex a sequence with #empty entries and anchor", function()
		local doc = [[
- val1
- &a
- val3
]]
		local iter = StringIterator:new(doc)
		local lexer, _ = Lexer:new(iter)
		local expect = [[
+STR
+DOC
+SEQ
=VAL :val1
=VAL &a :
=VAL :val3
-SEQ
-DOC
-STR
]]
		assert(lexer)
		assert.are.same(expect, tostring(lexer))
	end)
end)
