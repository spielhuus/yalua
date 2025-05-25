local assert = require("luassert")
local yalua = require("yalua")

describe("Test if the Lexer lexes", function()
	it("should lex a stream start document", function()
		local doc = [[
---
]]
		local expect = [[
+STR
+DOC ---
=VAL :
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a simple value", function()
		local doc = [[
---
happy mom
]]
		local expect = [[
+STR
+DOC ---
=VAL :happy mom
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a simple list", function()
		local doc = [[
---
- happy mom
- moms happy
- when dad is happy
]]
		local expect = [[
+STR
+DOC ---
+SEQ
=VAL :happy mom
=VAL :moms happy
=VAL :when dad is happy
-SEQ
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a list with newline", function()
		local doc = [[
---
- 
  happy mom
- 
  moms happy
- 
  when dad is happy
]]
		local expect = [[
+STR
+DOC ---
+SEQ
=VAL :happy mom
=VAL :moms happy
=VAL :when dad is happy
-SEQ
-DOC
-STR
]]

		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a nested list", function()
		local doc = [[
---
- happy mom
- - smile
  - drink
- moms happy
- 
  when dad is happy
]]
		local expect = [[
+STR
+DOC ---
+SEQ
=VAL :happy mom
+SEQ
=VAL :smile
=VAL :drink
-SEQ
=VAL :moms happy
=VAL :when dad is happy
-SEQ
-DOC
-STR
]]

		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex map", function()
		local doc = [[
value: key
foo: bar
]]
		local expect = [[
+STR
+DOC
+MAP
=VAL :value
=VAL :key
=VAL :foo
=VAL :bar
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a map with newlines", function()
		local doc = [[
value: 
  key
foo:
  bar
]]
		local expect = [[
+STR
+DOC
+MAP
=VAL :value
=VAL :key
=VAL :foo
=VAL :bar
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a nested map", function()
		local doc = [[
value: key
foo:
  bar: baz
]]
		local expect = [[
+STR
+DOC
+MAP
=VAL :value
=VAL :key
=VAL :foo
+MAP
=VAL :bar
=VAL :baz
-MAP
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should map with comments", function()
		local doc = [[
hr:  65    # Home runs
avg: 0.278 # Batting average
rbi: 147   # Runs Batted In
]]
		local expect = [[
+STR
+DOC
+MAP
=VAL :hr
=VAL :65
=VAL :avg
=VAL :0.278
=VAL :rbi
=VAL :147
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should map with multiple comments", function()
		local doc = [[
foo: # Home runs
  bar
avg:
  # Batting average
  147   # Runs Batted In
]]
		local expect = [[
+STR
+DOC
+MAP
=VAL :foo
=VAL :bar
=VAL :avg
=VAL :147
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should map and seq with same indent", function()
		local doc = [[
american:
- Boston Red Sox
- Detroit Tigers
- New York Yankees
national:
- New York Mets
- Chicago Cubs
- Atlanta Braves
]]
		local expect = [[
+STR
+DOC
+MAP
=VAL :american
+SEQ
=VAL :Boston Red Sox
=VAL :Detroit Tigers
=VAL :New York Yankees
-SEQ
=VAL :national
+SEQ
=VAL :New York Mets
=VAL :Chicago Cubs
=VAL :Atlanta Braves
-SEQ
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should map and seq with new lines", function()
		local doc = [[
-
  name: Mark McGwire
  hr:   65
  avg:  0.278
-
  name: Sammy Sosa
  hr:   63
  avg:  0.288
]]
		local expect = [[
+STR
+DOC
+SEQ
+MAP
=VAL :name
=VAL :Mark McGwire
=VAL :hr
=VAL :65
=VAL :avg
=VAL :0.278
-MAP
+MAP
=VAL :name
=VAL :Sammy Sosa
=VAL :hr
=VAL :63
=VAL :avg
=VAL :0.288
-MAP
-SEQ
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should parse a scalar with quotes", function()
		local doc = [[
key: "this is a quoted string"
]]
		local expect = [[
+STR
+DOC
+MAP
=VAL :key
=VAL "this is a quoted string
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should parse a multiline scalar with quotes", function()
		local doc = [[
key: "this is a quoted string
 with multiple
 lines"
]]
		local expect = [[
+STR
+DOC
+MAP
=VAL :key
=VAL "this is a quoted string with multiple lines
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should parse a document with comments", function()
		local doc = [[
---
hr: # 1998 hr ranking
- Mark McGwire
- Sammy Sosa
# 1998 rbi ranking
rbi:
- Sammy Sosa
- Ken Griffey
]]
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
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should parse a document with comments", function()
		local doc = [[
---
hr: # 1998 hr ranking
- Mark McGwire
- Sammy Sosa
# 1998 rbi ranking
rbi:
- Sammy Sosa
- Ken Griffey
]]
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
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should parse multiple documents", function()
		local doc = [[
---
hr: # 1998 hr ranking
- Mark McGwire
- Sammy Sosa
# 1998 rbi ranking
...
---
rbi:
- Sammy Sosa
- Ken Griffey
]]
		local expect = [[
+STR
+DOC ---
+MAP
=VAL :hr
+SEQ
=VAL :Mark McGwire
=VAL :Sammy Sosa
-SEQ
-MAP
-DOC ...
+DOC ---
+MAP
=VAL :rbi
+SEQ
=VAL :Sammy Sosa
=VAL :Ken Griffey
-SEQ
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should parse a YAML directive", function()
		local doc = [[
%YAML 1.2
---
Document
...
---
value
]]
		local expect = [[
+STR
+DOC ---
=VAL :Document
-DOC ...
+DOC ---
=VAL :value
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should parse multiple documents", function()
		local doc = [[
Document
---
# Empty
...
%YAML 1.2
---
value
]]
		local expect = [[
+STR
+DOC
=VAL :Document
-DOC
+DOC ---
=VAL :
-DOC ...
+DOC ---
=VAL :value
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should parse multiple documents with map", function()
		local doc = [[
Document
---
# Empty
...
%YAML 1.2
---
matches %: 20
]]

		local expect = [[
+STR
+DOC
=VAL :Document
-DOC
+DOC ---
=VAL :
-DOC ...
+DOC ---
+MAP
=VAL :matches %
=VAL :20
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a simple value", function()
		local doc = [[
---
value
]]
		local expect = [[
+STR
+DOC ---
=VAL :value
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a mapping", function()
		local doc = [[
---
key: value
]]
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
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a mapping key, with spaces", function()
		local doc = [[
"implicit block key" : [
  "implicit flow key" : value,
 ]
]]
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
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a mapping key", function()
		local doc = [[
"implicit block key": [
  "implicit flow key" : value,
 ]
]]
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
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a sequence", function()
		local doc = [[
---
- value1
- value2
]]
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
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a nested sequence", function()
		local doc = [[
---
- - value1
  - value2
- value3
]]
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
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a sequence with dash and newline", function()
		local doc = [[
---
-
  key1: value1
-
  key2: value2
]]
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
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a node with multiline scalar #skip", function()
		local doc = [[
# This is a comment
---
key:
 this is the first line
 and this is the second
]]
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
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a node with folded scalar", function()
		local doc = [[
# This is a comment
---
key: |
 this is the first line
 and this is the second
]]
		local expect = [[
+STR
+DOC ---
+MAP
=VAL :key
=VAL |this is the first line\nand this is the second\n
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a node with comment exclude", function()
		local doc = [[
# This is a comment
---
- - value1 # another comment
  - value2
# and a comment
- value 3
]]
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
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a seq and map on the same line", function()
		local doc = [[
# This is a comment
---
- key: value1 # another comment
]]
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
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
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
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a map with empty characters and tabs", function()
		local doc = [[

a: b
seq:
 - a
c: d	#X
]]
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
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a seq and map on the same line", function()
		local doc = [[
# This is a comment
---
- key: value1 # another comment
  foo: bar
]]
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
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
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
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should error on wrong indentation error", function()
		local doc = [[
key:
   - ok
   - also ok
  - wrong
]]
		local result, mes = yalua.dump(doc)
		assert.is_nil(result)
		assert.are.same("ERROR:4:0 wrong indentation: should be 0 but is 2\n  - wrong\n^", mes)
	end)

	it("should parse the Wrong indendation in mapping", function()
		local doc = [[
k1: v1
 k2: v2
]]
		local result, mes = yalua.dump(doc)
		assert.is_nil(result)
		assert.are.same("ERROR:2:3 invalid multiline plain key\n k2: v2\n   ^", mes)
	end)

	it("should lex a document with a directive", function()
		local doc = [[
%TAG ! tag:clarkevans.com,2002:
--- !shape
- circle
]]
		local expect = [[
+STR
+DOC ---
+SEQ <tag:clarkevans.com,2002:shape>
=VAL :circle
-SEQ
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a document with tag in seq", function()
		local doc = [[

%TAG ! tag:clarkevans.com,2002:
--- !shape
- !circle
  diameter: 120
]]
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
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
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
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a document with multiline comments", function()
		local doc = [[
  # Use the ! handle for presenting


]]
		local expect = [[
+STR
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a sequence with map on new line", function()
		local doc = [[
 - key: value
   key2: value2
 -
   key3: value3
]]
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
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a map with anchors and reference", function()
		local doc = [[
 - key: &a value
   key2: value2
 -
   key3: *a
]]
		local expect = [[
+STR
+DOC
+SEQ
+MAP
=VAL :key
=VAL &a :value
=VAL :key2
=VAL :value2
-MAP
+MAP
=VAL :key3
=ALI *a
-MAP
-SEQ
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a map with anchors in list", function()
		local doc = [[
---
hr:
- Mark McGwire
# Following node labeled SS
- &SS Sammy Sosa
rbi:
- *SS # Subsequent occurrence
- Ken Griffey
]]
		local expect = [[
+STR
+DOC ---
+MAP
=VAL :hr
+SEQ
=VAL :Mark McGwire
=VAL &SS :Sammy Sosa
-SEQ
=VAL :rbi
+SEQ
=ALI *SS
=VAL :Ken Griffey
-SEQ
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
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
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a map with empty values", function()
		local doc = [[
key1: val1
key2:
key3:
]]
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
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a map with values with anchor", function()
		local doc = [[
key1: val1
key2: &a val2
key3: *a
]]
		local expect = [[
+STR
+DOC
+MAP
=VAL :key1
=VAL :val1
=VAL :key2
=VAL &a :val2
=VAL :key3
=ALI *a
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a map with emty values", function()
		local doc = [[
key1: val1
key2:
key3: val3
]]
		local expect = [[
+STR
+DOC
+MAP
=VAL :key1
=VAL :val1
=VAL :key2
=VAL :
=VAL :key3
=VAL :val3
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a map with empty values with anchor #subject", function()
		local doc = [[
key1: val1
key2: &a
key3:
]]
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
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a sequence with empty entries #skip", function()
		local doc = [[
- val1
-
- val3
]]
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
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a sequence with empty entries and anchor #skip", function()
		local doc = [[
- val1
- &a
- val3
]]
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
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a map with anchor and alias #skip", function()
		local doc = [[
top3: &node3
  *alias1 : scalar3
]]
		local expect = [[
+STR
+DOC
+MAP
=VAL :top3
+MAP &node3
=ALI *alias1
=VAL :scalar3
-MAP
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex an aliased map #skip", function()
		local doc = [[
&a: key: &a value
foo:
  *a:
]]
		local expect = [[
+STR
+DOC
+MAP
=VAL &a: :key
=VAL &a :value
=VAL :foo
=ALI *a:
-MAP

-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a map with empty anchor and comment #skip", function()
		local doc = [[
---
top1: &node1
  &k1 key1: one
top2: &node2 # comment
  key2: two
]]
		local expect = [[
+STR
+DOC
+MAP
=VAL :top1
+MAP &node1
=VAL &k1 :key1
=VAL :one
-MAP
=VAL :top2
+MAP &node2
=VAL :key2
=VAL :two
-MAP
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)
end)
