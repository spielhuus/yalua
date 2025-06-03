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
end)
