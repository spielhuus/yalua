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

	it("should lex a double quoted scalar with empty line", function()
		local doc = [[
quoted: "quoted scalar
   
   second line"
]]
		local expect = [[
+STR
+DOC
+MAP
=VAL :quoted
=VAL "quoted scalar\nsecond line
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

	it("should lex a quoted multiline scalar", function()
		local doc = [[
quoted: "first line
 continues
 
 second line"
]]
		local expect = [[
+STR
+DOC
+MAP
=VAL :quoted
=VAL "first line continues\nsecond line
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a quoted multiline scalar, with spaces at the end", function()
		local doc = [[
quoted: "first line
 continues
 
 second line "
]]
		local expect = [[
+STR
+DOC
+MAP
=VAL :quoted
=VAL "first line continues\nsecond line 
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

	it("should lex a folded multiline scalar with trailing empty lines", function()
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

	it("should lex a literal multiline scalar with leading empty lines", function()
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
=VAL >\ntext\n\nanother line\n
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a folded string with no indentation", function()
		local doc = [[
--- >
text
# no comment
another line
]]
		local expect = [[
+STR
+DOC ---
=VAL >text # no comment another line\n
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a folded string with bigger empty line indentation", function()
		local doc = [[
--- 
text: >
  
   
  text
  # no comment
  another line
]]
		local result, mes = yalua.dump(doc)
		assert.is.Nil(result)
		assert.are.same(mes, "ERROR:5:2 block scalar with wrongly indented line after spaces only\n  text\n  ^")
	end)

	it("should lex a folded string with empty line in more indented", function()
		local doc = [[
--- 
text: >
  text
  
    * entry

    * other
    
    * last
  another line
]]
		local expect = [[
+STR
+DOC ---
+MAP
=VAL :text
=VAL >text\n\n  * entry\n\n  * other\n  \n  * last\nanother line\n
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a folded string with empty line indentation spaces", function()
		local doc = [[
--- 
- >
 
  
  # comment
]]
		local expect = [[
+STR
+DOC ---
+SEQ
=VAL >\n\n# comment\n
-SEQ
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a folded string with empty line indentation spaces and tab #xxx", function()
		local doc = [[
--- 
- >
 	
 detected
]]
		local expect = [[
+STR
+DOC ---
+SEQ
=VAL >\t\ndetected\n
-SEQ
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a folded string with empty line in more indented with tab", function()
		local doc = [[
--- 
text: >
  text
  	* entry
   * other
   * last
]]
		local expect = [[
+STR
+DOC ---
+MAP
=VAL :text
=VAL >text\n\t* entry\n * other\n * last\n
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a folded string with empty line in more indented and hint", function()
		local doc = [[
--- 
text: >2
    text
  another line
]]
		local expect = [[
+STR
+DOC ---
+MAP
=VAL :text
=VAL >  text\nanother line\n
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex a folded string with empty line in more indented and hint from suite #subject", function()
		local doc = [[
---
a: >2
   more indented
  regular
b: >2


   more indented
  regular
]]
		local expect = [[
+STR
+DOC ---
+MAP
=VAL :a
=VAL > more indented\nregular\n
=VAL :b
=VAL >\n\n more indented\nregular\n
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

	it("should lex folded multiline scalar", function()
		local doc = [[
foo: >
  content
  lines

    other lines
  end
]]
		local expect = [[
+STR
+DOC
+MAP
=VAL :foo
=VAL >content lines\n\n  other lines\nend\n
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex multiline literal with empty line", function()
		local doc = [[
yaml: |
  foo: 1

  bar: 2
]]
		local expect = [[
+STR
+DOC
+MAP
=VAL :yaml
=VAL |foo: 1\n\nbar: 2\n
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex multiline literal", function()
		local doc = [[
foo: |
  content
  lines

    other lines
  end
]]
		local expect = [[
+STR
+DOC
+MAP
=VAL :foo
=VAL |content\nlines\n\n  other lines\nend\n
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex multiline literal with indentation hint", function()
		local doc = [[
foo: |2
    content
    lines

      other lines
    end
]]
		local expect = [[
+STR
+DOC
+MAP
=VAL :foo
=VAL |  content\n  lines\n\n    other lines\n  end\n
-MAP
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex literal with literal content", function()
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

	it("should lex literal with yaml content and special characters", function()
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

	it("should lex literal with yaml content", function()
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
