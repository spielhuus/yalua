local assert = require("luassert")
local yalua = require("yalua")

local function load_file(file_path)
	local file = io.open(file_path, "r")
	if not file then
		return nil, "File not found"
	end
	local content = file:read("*all")
	file:close()
	return content
end

describe("Test if the Lexer lexes", function()
	it("should parse the Spec Example 2.1. Sequence of Scalars, file: #FQ7F tags: #spec #sequence", function()
		local input = load_file("./yaml-test-suite/data/FQ7F/in.yaml")
		local tree = load_file("./yaml-test-suite/data/FQ7F/test.event")
		local result = yalua.dump(input)
		assert(result)
		assert.are.same(tree, result)
	end)
	it(
		"should parse the Spec Example 2.2. Mapping Scalars to Scalars, file: #SYW4 tags: #spec #scalar #comment",
		function()
			local input = load_file("./yaml-test-suite/data/SYW4/in.yaml")
			local tree = load_file("./yaml-test-suite/data/SYW4/test.event")
			local result = yalua.dump(input)
			assert(result)
			assert.are.same(tree, result)
		end
	)
	it(
		"should parse the Spec Example 2.3. Mapping Scalars to Sequences, file: #PBJ2 tags: #spec #mapping #sequence",
		function()
			local input = load_file("./yaml-test-suite/data/PBJ2/in.yaml")
			local tree = load_file("./yaml-test-suite/data/PBJ2/test.event")
			local result = yalua.dump(input)
			assert(result)
			assert.are.same(tree, result)
		end
	)
	it("should parse the Spec Example 2.4. Sequence of Mappings, file: #229Q tags: #sequence #mapping #spec", function()
		local input = load_file("./yaml-test-suite/data/229Q/in.yaml")
		local tree = load_file("./yaml-test-suite/data/229Q/test.event")
		local result = yalua.dump(input)
		assert(result)
		assert.are.same(tree, result)
	end)
	it("should parse the Spec Example 2.5. Sequence of Sequences, file: #YD5X tags: #spec #sequence", function()
		local input = load_file("./yaml-test-suite/data/YD5X/in.yaml")
		local tree = load_file("./yaml-test-suite/data/YD5X/test.event")
		local result = yalua.dump(input)
		assert(result)
		assert.are.same(tree, result)
	end)
	it("should parse the Spec Example 2.6. Mapping of Mappings, file: #ZF4X tags: #flow #spec #mapping", function()
		local input = load_file("./yaml-test-suite/data/ZF4X/in.yaml")
		local tree = load_file("./yaml-test-suite/data/ZF4X/test.event")
		local result = yalua.dump(input)
		assert(result)
		assert.are.same(tree, result)
	end)
	it("should parse the Spec Example 2.7. Two Documents in a Stream, file: #JHB9 tags: #spec #header", function()
		local input = load_file("./yaml-test-suite/data/JHB9/in.yaml")
		local tree = load_file("./yaml-test-suite/data/JHB9/test.event")
		local result = yalua.dump(input)
		assert(result)
		assert.are.same(tree, result)
	end)
	it("should parse the Spec Example 2.8. Play by Play Feed from a Game, file: #U9NS tags: #spec #header", function()
		local input = load_file("./yaml-test-suite/data/U9NS/in.yaml")
		local tree = load_file("./yaml-test-suite/data/U9NS/test.event")
		local result = yalua.dump(input)
		assert(result)
		assert.are.same(tree, result)
	end)
	it(
		"should parse the Spec Example 2.9. Single Document with Two Comments, file: #J9HZ tags: #mapping #sequence #spec #comment",
		function()
			local input = load_file("./yaml-test-suite/data/J9HZ/in.yaml")
			local tree = load_file("./yaml-test-suite/data/J9HZ/test.event")
			local result = yalua.dump(input)
			assert(result)
			assert.are.same(tree, result)
		end
	)
	it(
		"should parse the Spec Example 2.10. Node for “Sammy Sosa” appears twice in this document, file: #7BUB tags: #mapping #sequence #spec #alias",
		function()
			local input = load_file("./yaml-test-suite/data/7BUB/in.yaml")
			local tree = load_file("./yaml-test-suite/data/7BUB/test.event")
			local result = yalua.dump(input)
			assert(result)
			assert.are.same(tree, result)
		end
	)
	it(
		"should parse the Spec Example 2.11. Mapping between Sequences, file: #M5DY tags: #complex-key #explicit-key #spec #mapping #sequence",
		function()
			local input = load_file("./yaml-test-suite/data/M5DY/in.yaml")
			local tree = load_file("./yaml-test-suite/data/M5DY/test.event")
			local result = yalua.dump(input)
			assert(result)
			assert.are.same(tree, result)
		end
	)
	it(
		"should parse the Spec Example 2.12. Compact Nested Mapping, file: #9U5K tags: #spec #mapping #sequence",
		function()
			local input = load_file("./yaml-test-suite/data/9U5K/in.yaml")
			local tree = load_file("./yaml-test-suite/data/9U5K/test.event")
			local result = yalua.dump(input)
			assert(result)
			assert.are.same(tree, result)
		end
	)
	it(
		"should parse the Spec Example 2.13. In literals, newlines are preserved, file: #6JQW tags: #spec #scalar #literal #comment",
		function()
			local input = load_file("./yaml-test-suite/data/6JQW/in.yaml")
			local tree = load_file("./yaml-test-suite/data/6JQW/test.event")
			local result = yalua.dump(input)
			assert(result)
			assert.are.same(tree, result)
		end
	)
	it(
		"should parse the Spec Example 2.14. In the folded scalars, newlines become spaces, file: #96L6 tags: #spec #folded #scalar",
		function()
			local input = load_file("./yaml-test-suite/data/96L6/in.yaml")
			local tree = load_file("./yaml-test-suite/data/96L6/test.event")
			local result = yalua.dump(input)
			assert(result)
			assert.are.same(tree, result)
		end
	)
	it(
		'should parse the Spec Example 2.15. Folded newlines are preserved for "more indented" and blank lines, file: #6VJK tags: #spec #folded #scalar #1.3-err',
		function()
			local input = load_file("./yaml-test-suite/data/6VJK/in.yaml")
			local tree = load_file("./yaml-test-suite/data/6VJK/test.event")
			local result = yalua.dump(input)
			assert(result)
			assert.are.same(tree, result)
		end
	)
	it(
		"should parse the Spec Example 2.16. Indentation determines scope, file: #HMK4 tags: #spec #folded #literal",
		function()
			local input = load_file("./yaml-test-suite/data/HMK4/in.yaml")
			local tree = load_file("./yaml-test-suite/data/HMK4/test.event")
			local result = yalua.dump(input)
			assert(result)
			assert.are.same(tree, result)
		end
	)
	it("should parse the Spec Example 2.17. Quoted Scalars, file: #G4RS tags: #spec #scalar", function()
		local input = load_file("./yaml-test-suite/data/G4RS/in.yaml")
		local tree = load_file("./yaml-test-suite/data/G4RS/test.event")
		local result = yalua.dump(input)
		assert(result)
		assert.are.same(tree, result)
	end)
	it("should parse the Spec Example 2.18. Multi-line Flow Scalars, file: #4CQQ tags: #spec #scalar", function()
		local input = load_file("./yaml-test-suite/data/4CQQ/in.yaml")
		local tree = load_file("./yaml-test-suite/data/4CQQ/test.event")
		local result = yalua.dump(input)
		assert(result)
		assert.are.same(tree, result)
	end)
	it(
		"should parse the Spec Example 2.24. Global Tags, file: #C4HZ tags: #spec #tag #alias #directive #local-tag",
		function()
			local input = load_file("./yaml-test-suite/data/C4HZ/in.yaml")
			local tree = load_file("./yaml-test-suite/data/C4HZ/test.event")
			local result = yalua.dump(input)
			assert(result)
			assert.are.same(tree, result)
		end
	)
	it(
		"should parse the Spec Example 2.25. Unordered Sets, file: #2XXW tags: #spec #mapping #unknown-tag #explicit-key",
		function()
			local input = load_file("./yaml-test-suite/data/2XXW/in.yaml")
			local tree = load_file("./yaml-test-suite/data/2XXW/test.event")
			local result = yalua.dump(input)
			assert(result)
			assert.are.same(tree, result)
		end
	)
	it(
		"should parse the Spec Example 2.26. Ordered Mappings, file: #J7PZ tags: #spec #mapping #tag #unknown-tag",
		function()
			local input = load_file("./yaml-test-suite/data/J7PZ/in.yaml")
			local tree = load_file("./yaml-test-suite/data/J7PZ/test.event")
			local result = yalua.dump(input)
			assert(result)
			assert.are.same(tree, result)
		end
	)
	it(
		"should parse the Spec Example 2.27. Invoice, file: #UGM3 tags: #spec #tag #literal #mapping #sequence #alias #unknown-tag #skip",
		function()
			local input = load_file("./yaml-test-suite/data/UGM3/in.yaml")
			local tree = load_file("./yaml-test-suite/data/UGM3/test.event")
			local result = yalua.dump(input)
			assert(result)
			assert.are.same(tree, result)
		end
	)
	it(
		"should parse the Spec Example 2.28. Log File, file: #RZT7 tags: #spec #header #literal #mapping #sequence",
		function()
			local input = load_file("./yaml-test-suite/data/RZT7/in.yaml")
			local tree = load_file("./yaml-test-suite/data/RZT7/test.event")
			local result = yalua.dump(input)
			assert(result)
			assert.are.same(tree, result)
		end
	)
end)
