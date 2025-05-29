local assert = require("luassert")
local yalua = require("yalua")

describe("Test the scalar types", function()
	it("should lex a double quoted scalar", function()
		local doc = [[
quoted: "quoted scalar"
]]
		local expect = [[
+STR
+DOC
+MAP
=VAL :quoted
=VAL "quoted scalar
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a sinlge quoted scalar", function()
		local doc = [[
quoted: 'quoted scalar'
]]
		local expect = [[
+STR
+DOC
+MAP
=VAL :quoted
=VAL 'quoted scalar
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a sinlge quoted scalar with escaped quote", function()
		local doc = [[
quoted: 'quoted ''scalar'''
]]
		local expect = [[
+STR
+DOC
+MAP
=VAL :quoted
=VAL 'quoted 'scalar'
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a folded scalar", function()
		local doc = [[
strip: |
  text
]]
		local expect = [[
+STR
+DOC
+MAP
=VAL :strip
=VAL |text\n
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a folded multiline scalar", function()
		local doc = [[
strip: |
  text
  another line
]]
		local expect = [[
+STR
+DOC
+MAP
=VAL :strip
=VAL |text\nanother line\n
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a folded multiline scalar with empty lines", function()
		local doc = [[
strip: |
  text
  another line

  
  last line
]]
		local expect = [[
+STR
+DOC
+MAP
=VAL :strip
=VAL |text\nanother line\n\n\nlast line\n
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex folded with attribute", function()
		local doc = [[
strip: |-
  text
clip: |
  text
keep: |+
  text
]]
		local expect = [[
+STR
+DOC
+MAP
=VAL :strip
=VAL |text
=VAL :clip
=VAL |text\n
=VAL :keep
=VAL |text\n
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a literal multiline scalar", function()
		local doc = [[
strip: >
  text
  another line
]]
		local expect = [[
+STR
+DOC
+MAP
=VAL :strip
=VAL >text another line\n
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a literal multiline scalar with empty lines", function()
		local doc = [[
strip: >
  text

  
  another line
]]
		local expect = [[
+STR
+DOC
+MAP
=VAL :strip
=VAL >text\n\nanother line\n
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a literal multiline scalar with more indented lines", function()
		local doc = [[
strip: >
  text
  another line

    list
    items
]]
		local expect = [[
+STR
+DOC
+MAP
=VAL :strip
=VAL >text another line\n\n  list\n  items\n
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex map with line prefix", function()
		local doc = [[
plain: text
  lines
quoted: "text
  	lines"
block: |
  text
   	lines
]]
		local expect = [[
+STR
+DOC
+MAP
=VAL :plain
=VAL :text lines
=VAL :quoted
=VAL "text lines
=VAL :block
=VAL |text\n \tlines\n
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex wrong literal attribute #skip", function()
		local doc = [[
plain: |
  plain: |x
    content
]]
		local expect = [[
+STR
+DOC
+MAP
=VAL :plain
=VAL |plain: |x\n  content\n
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex literal with yaml content and special characters #skip", function()
		local doc = [[
- yaml: |
    --- |1-∎
  another: value
]]
		local expect = [[
+STR
+DOC
+SEQ
+MAP
=VAL :yaml
=VAL |--- |1-∎\n
=VAL :another
=VAL :value
-MAP
-SEQ
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex literal with yaml content, #subject", function()
		local doc = [[
yaml: |
  yodl: question ? mark
  lufl: [question ? mark]
]]
		local expect = [[
+STR
+DOC
+MAP
=VAL :yaml
=VAL |yodl: question ? mark\nlufl: [question ? mark]\n
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex scalar with question marks", function()
		local doc = [[
yaml: question?mark
yodl: question ? mark
lufl: [question ? mark]
]]
		local expect = [[
+STR
+DOC
+MAP
=VAL :yaml
=VAL :question?mark
=VAL :yodl
=VAL :question ? mark
=VAL :lufl
+SEQ []
=VAL :question ? mark
-SEQ
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)
end)
