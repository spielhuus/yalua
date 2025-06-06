local assert = require("luassert")
local yalua = require("yalua")

describe("Test tag samples", function()
	it("should lex primary tag", function()
		local doc = [[
!tag "value"
]]
		local expect = [[
+STR
+DOC
=VAL <!tag> "value
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex primary str tag", function()
		local doc = [[
!str "value"
]]
		local expect = [[
+STR
+DOC
=VAL <!str> "value
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex multiple documents with one primary str tag", function()
		local doc = [[
---
!foo "value"
...
%TAG ! tag:www.example.com/foo/
---
!foo "value"
]]
		local expect = [[
+STR
+DOC ---
=VAL <!foo> "value
-DOC ...
+DOC ---
=VAL <tag:www.example.com/foo/foo> "value
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)

	it("should lex multiple documents with one primary str tag in first document", function()
		local doc = [[
%TAG ! tag:www.example.com/foo/
---
!foo "value"
...
---
!foo "value"
]]
		local expect = [[
+STR
+DOC ---
=VAL <tag:www.example.com/foo/foo> "value
-DOC ...
+DOC ---
=VAL <!foo> "value
-DOC
-STR
]]
		local result = yalua.dump(doc)
		assert(result)
		assert.are.same(expect, result)
	end)
end)
