local assert = require("luassert")
local Lexer = require("Lexer")

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
		local iter = require("StringIterator"):new(input)
		local result = Lexer:new(iter)
		assert.is.Same(tree, tostring(result))
	end)
	it(
		"should parse the Spec Example 2.2. Mapping Scalars to Scalars, file: #SYW4 tags: #spec #scalar #comment",
		function()
			local input = load_file("./yaml-test-suite/data/SYW4/in.yaml")
			local tree = load_file("./yaml-test-suite/data/SYW4/test.event")
			local iter = require("StringIterator"):new(input)
			local result = Lexer:new(iter)
			assert.is.Same(tree, tostring(result))
		end
	)
	it(
		"should parse the Spec Example 2.3. Mapping Scalars to Sequences, file: #PBJ2 tags: #spec #mapping #sequence",
		function()
			local input = load_file("./yaml-test-suite/data/PBJ2/in.yaml")
			local tree = load_file("./yaml-test-suite/data/PBJ2/test.event")
			local iter = require("StringIterator"):new(input)
			local result = Lexer:new(iter)
			assert.is.Same(tree, tostring(result))
		end
	)
	it("should parse the Spec Example 2.4. Sequence of Mappings, file: #229Q tags: #sequence #mapping #spec", function()
		local input = load_file("./yaml-test-suite/data/229Q/in.yaml")
		local tree = load_file("./yaml-test-suite/data/229Q/test.event")
		local iter = require("StringIterator"):new(input)
		local result = Lexer:new(iter)
		assert.is.Same(tree, tostring(result))
	end)
	it("should parse the Spec Example 2.5. Sequence of Sequences, file: #YD5X tags: #spec #sequence", function()
		local input = load_file("./yaml-test-suite/data/YD5X/in.yaml")
		local tree = load_file("./yaml-test-suite/data/YD5X/test.event")
		local iter = require("StringIterator"):new(input)
		local result = Lexer:new(iter)
		assert.is.Same(tree, tostring(result))
	end)
	it("should parse the Spec Example 2.6. Mapping of Mappings, file: #ZF4X tags: #flow #spec #mapping", function()
		print("### should parse the Spec Example 2.6. Mapping of Mappings, file: #ZF4X")
		local input = load_file("./yaml-test-suite/data/ZF4X/in.yaml")
		local tree = load_file("./yaml-test-suite/data/ZF4X/test.event")
		local iter = require("StringIterator"):new(input)
		local result = Lexer:new(iter)
		assert.is.Same(tree, tostring(result))
	end)
	it("should parse the Spec Example 2.7. Two Documents in a Stream, file: #JHB9 tags: #spec #header", function()
		print("### should parse the Spec Example 2.7. Two Documents in a Stream, file: #JHB9")
		local input = load_file("./yaml-test-suite/data/JHB9/in.yaml")
		local tree = load_file("./yaml-test-suite/data/JHB9/test.event")
		local iter = require("StringIterator"):new(input)
		local result = Lexer:new(iter)
		assert.is.Same(tree, tostring(result))
	end)
	it("should parse the Spec Example 2.8. Play by Play Feed from a Game, file: #U9NS tags: #spec #header", function()
		print("### should parse the Spec Example 2.8. Play by Play Feed from a Game, file: #U9NS")
		local input = load_file("./yaml-test-suite/data/U9NS/in.yaml")
		local tree = load_file("./yaml-test-suite/data/U9NS/test.event")
		local iter = require("StringIterator"):new(input)
		local result = Lexer:new(iter)
		assert.is.Same(tree, tostring(result))
	end)
	it(
		"should parse the Spec Example 2.9. Single Document with Two Comments, file: #J9HZ tags: #mapping #sequence #spec #comment",
		function()
			print("### should parse the Spec Example 2.9. Single Document with Two Comments, file: #J9HZ")
			local input = load_file("./yaml-test-suite/data/J9HZ/in.yaml")
			local tree = load_file("./yaml-test-suite/data/J9HZ/test.event")
			local iter = require("StringIterator"):new(input)
			local result = Lexer:new(iter)
			assert.is.Same(tree, tostring(result))
		end
	)
	it(
		"should parse the Spec Example 2.10. Node for “Sammy Sosa” appears twice in this document, file: #7BUB tags: #mapping #sequence #spec #alias",
		function()
			print(
				"### should parse the Spec Example 2.10. Node for “Sammy Sosa” appears twice in this document, file: #7BUB"
			)
			local input = load_file("./yaml-test-suite/data/7BUB/in.yaml")
			local tree = load_file("./yaml-test-suite/data/7BUB/test.event")
			local iter = require("StringIterator"):new(input)
			local result = Lexer:new(iter)
			assert.is.Same(tree, tostring(result))
		end
	)
	it(
		"should parse the Spec Example 2.11. Mapping between Sequences, file: #M5DY tags: #complex-key #explicit-key #spec #mapping #sequence",
		function()
			print("### should parse the Spec Example 2.11. Mapping between Sequences, file: #M5DY")
			local input = load_file("./yaml-test-suite/data/M5DY/in.yaml")
			local tree = load_file("./yaml-test-suite/data/M5DY/test.event")
			local iter = require("StringIterator"):new(input)
			local result = Lexer:new(iter)
			assert.is.Same(tree, tostring(result))
		end
	)
	it(
		"should parse the Spec Example 2.12. Compact Nested Mapping, file: #9U5K tags: #spec #mapping #sequence",
		function()
			print("### should parse the Spec Example 2.12. Compact Nested Mapping, file: #9U5K")
			local input = load_file("./yaml-test-suite/data/9U5K/in.yaml")
			local tree = load_file("./yaml-test-suite/data/9U5K/test.event")
			local iter = require("StringIterator"):new(input)
			local result = Lexer:new(iter)
			assert.is.Same(tree, tostring(result))
		end
	)
	it(
		"should parse the Spec Example 2.13. In literals, newlines are preserved, file: #6JQW tags: #spec #scalar #literal #comment",
		function()
			print("### should parse the Spec Example 2.13. In literals, newlines are preserved, file: #6JQW")
			local input = load_file("./yaml-test-suite/data/6JQW/in.yaml")
			local tree = load_file("./yaml-test-suite/data/6JQW/test.event")
			local iter = require("StringIterator"):new(input)
			local result = Lexer:new(iter)
			assert.is.Same(tree, tostring(result))
		end
	)
	it(
		"should parse the Spec Example 2.14. In the folded scalars, newlines become spaces, file: #96L6 tags: #spec #folded #scalar",
		function()
			print("### should parse the Spec Example 2.14. In the folded scalars, newlines become spaces, file: #96L6")
			local input = load_file("./yaml-test-suite/data/96L6/in.yaml")
			local tree = load_file("./yaml-test-suite/data/96L6/test.event")
			local iter = require("StringIterator"):new(input)
			local result = Lexer:new(iter)
			assert.is.Same(tree, tostring(result))
		end
	)
	it(
		'should parse the Spec Example 2.15. Folded newlines are preserved for "more indented" and blank lines, file: #6VJK tags: #spec #folded #scalar #1.3-err',
		function()
			print(
				'### should parse the Spec Example 2.15. Folded newlines are preserved for "more indented" and blank lines, file: #6VJK'
			)
			local input = load_file("./yaml-test-suite/data/6VJK/in.yaml")
			local tree = load_file("./yaml-test-suite/data/6VJK/test.event")
			local iter = require("StringIterator"):new(input)
			local result = Lexer:new(iter)
			assert.is.Same(tree, tostring(result))
		end
	)
	it(
		"should parse the Spec Example 2.16. Indentation determines scope, file: #HMK4 tags: #spec #folded #literal",
		function()
			print("### should parse the Spec Example 2.16. Indentation determines scope, file: #HMK4")
			local input = load_file("./yaml-test-suite/data/HMK4/in.yaml")
			local tree = load_file("./yaml-test-suite/data/HMK4/test.event")
			local iter = require("StringIterator"):new(input)
			local result = Lexer:new(iter)
			assert.is.Same(tree, tostring(result))
		end
	)
	it("should parse the Spec Example 2.17. Quoted Scalars, file: #G4RS tags: #spec #scalar", function()
		print("### should parse the Spec Example 2.17. Quoted Scalars, file: #G4RS")
		local input = load_file("./yaml-test-suite/data/G4RS/in.yaml")
		local tree = load_file("./yaml-test-suite/data/G4RS/test.event")
		local iter = require("StringIterator"):new(input)
		local result = Lexer:new(iter)
		assert.is.Same(tree, tostring(result))
	end)
	it("should parse the Spec Example 2.18. Multi-line Flow Scalars, file: #4CQQ tags: #spec #scalar", function()
		print("### should parse the Spec Example 2.18. Multi-line Flow Scalars, file: #4CQQ")
		local input = load_file("./yaml-test-suite/data/4CQQ/in.yaml")
		local tree = load_file("./yaml-test-suite/data/4CQQ/test.event")
		local iter = require("StringIterator"):new(input)
		local result = Lexer:new(iter)
		assert.is.Same(tree, tostring(result))
	end)
	it(
		"should parse the Spec Example 2.24. Global Tags, file: #C4HZ tags: #spec #tag #alias #directive #local-tag",
		function()
			print("### should parse the Spec Example 2.24. Global Tags, file: #C4HZ")
			local input = load_file("./yaml-test-suite/data/C4HZ/in.yaml")
			local tree = load_file("./yaml-test-suite/data/C4HZ/test.event")
			local iter = require("StringIterator"):new(input)
			local result = Lexer:new(iter)
			assert.is.Same(tree, tostring(result))
		end
	)
	it(
		"should parse the Spec Example 2.25. Unordered Sets, file: #2XXW tags: #spec #mapping #unknown-tag #explicit-key",
		function()
			print("### should parse the Spec Example 2.25. Unordered Sets, file: #2XXW")
			local input = load_file("./yaml-test-suite/data/2XXW/in.yaml")
			local tree = load_file("./yaml-test-suite/data/2XXW/test.event")
			local iter = require("StringIterator"):new(input)
			local result = Lexer:new(iter)
			assert.is.Same(tree, tostring(result))
		end
	)
	it(
		"should parse the Spec Example 2.26. Ordered Mappings, file: #J7PZ tags: #spec #mapping #tag #unknown-tag",
		function()
			print("### should parse the Spec Example 2.26. Ordered Mappings, file: #J7PZ")
			local input = load_file("./yaml-test-suite/data/J7PZ/in.yaml")
			local tree = load_file("./yaml-test-suite/data/J7PZ/test.event")
			local iter = require("StringIterator"):new(input)
			local result = Lexer:new(iter)
			assert.is.Same(tree, tostring(result))
		end
	)
	it(
		"should parse the Spec Example 2.27. Invoice, file: #UGM3 tags: #spec #tag #literal #mapping #sequence #alias #unknown-tag",
		function()
			print("### should parse the Spec Example 2.27. Invoice, file: #UGM3")
			local input = load_file("./yaml-test-suite/data/UGM3/in.yaml")
			local tree = load_file("./yaml-test-suite/data/UGM3/test.event")
			local iter = require("StringIterator"):new(input)
			local result, _ = Lexer:new(iter)
			assert.is.Same(tree, tostring(result))
		end
	)
	it(
		"should parse the Spec Example 2.28. Log File, file: #RZT7 tags: #spec #header #literal #mapping #sequence",
		function()
			print("### should parse the Spec Example 2.28. Log File, file: #RZT7")
			local input = load_file("./yaml-test-suite/data/RZT7/in.yaml")
			local tree = load_file("./yaml-test-suite/data/RZT7/test.event")
			local iter = require("StringIterator"):new(input)
			local result, _ = Lexer:new(iter)
			assert.is.Same(tree, tostring(result))
		end
	)

	-- 	it("should lex spec example 2.1", function()
	-- 		local doc = [[
	-- - Mark McGwire
	-- - Sammy Sosa
	-- - Ken Griffey
	-- ]]
	-- 		local iter = StringIterator:new(doc)
	-- 		local lexer = Lexer:new(iter)
	-- 		local expect = {
	-- 			{ kind = "+SEQ", indent = 0 },
	-- 			{ kind = "CHARS", value = "Mark McGwire", indent = 0 },
	-- 			{ kind = "CHARS", value = "Sammy Sosa", indent = 0 },
	-- 			{ kind = "CHARS", value = "Ken Griffey", indent = 0 },
	-- 			{ kind = "-SEQ", indent = 0 },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
	--
	-- 	it("should #lex spec example 2.2", function()
	-- 		local doc = [[
	-- hr:  65    # Home runs
	-- avg: 0.278 # Batting average
	-- rbi: 147   # Runs Batted In
	-- ]]
	-- 		local iter = StringIterator:new(doc)
	-- 		local lexer = Lexer:new(iter)
	-- 		local expect = {
	-- 			{ kind = "+MAP", indent = 0 },
	-- 			{ kind = "CHARS", value = "hr", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "CHARS", value = "65", indent = 0 },
	-- 			{ kind = "CHARS", value = "avg", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "CHARS", value = "0.278", indent = 0 },
	-- 			{ kind = "CHARS", value = "rbi", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "CHARS", value = "147", indent = 0 },
	-- 			{ kind = "-MAP", indent = 0 },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
	--
	-- 	it("should lex spec example #2.3", function()
	-- 		local doc = [[
	-- american:
	--   - Boston Red Sox
	--   - Detroit Tigers
	--   - New York Yankees
	-- national:
	--   - New York Mets
	--   - Chicago Cubs
	--   - Atlanta Braves
	-- ]]
	-- 		local iter = StringIterator:new(doc)
	-- 		local lexer = Lexer:new(iter)
	-- 		local expect = {
	-- 			{ kind = "+MAP", indent = 0 },
	-- 			{ kind = "CHARS", value = "american", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "+SEQ", indent = 2 },
	-- 			{ kind = "CHARS", value = "Boston Red Sox", indent = 2 },
	-- 			{ kind = "CHARS", value = "Detroit Tigers", indent = 2 },
	-- 			{ kind = "CHARS", value = "New York Yankees", indent = 2 },
	-- 			{ kind = "-SEQ", indent = 2 },
	-- 			{ kind = "CHARS", value = "national", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "+SEQ", indent = 2 },
	-- 			{ kind = "CHARS", value = "New York Mets", indent = 2 },
	-- 			{ kind = "CHARS", value = "Chicago Cubs", indent = 2 },
	-- 			{ kind = "CHARS", value = "Atlanta Braves", indent = 2 },
	-- 			{ kind = "-SEQ", indent = 2 },
	-- 			{ kind = "-MAP", indent = 0 },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
	--
	-- 	it("should lex spec example #2.4", function()
	-- 		local doc = [[
	-- -
	--   name: Mark McGwire
	--   hr:   65
	--   avg:  0.278
	-- -
	--   name: Sammy Sosa
	--   hr:   63
	--   avg:  0.288
	-- ]]
	-- 		local iter = StringIterator:new(doc)
	-- 		local lexer = Lexer:new(iter)
	-- 		local expect = {
	-- 			{ kind = "+SEQ", indent = 0 },
	-- 			{ kind = "+MAP", indent = 2 },
	-- 			{ kind = "CHARS", value = "name", indent = 2 },
	-- 			{ kind = ":", indent = 2 },
	-- 			{ kind = "CHARS", value = "Mark McGwire", indent = 2 },
	-- 			{ kind = "CHARS", value = "hr", indent = 2 },
	-- 			{ kind = ":", indent = 2 },
	-- 			{ kind = "CHARS", value = "65", indent = 2 },
	-- 			{ kind = "CHARS", value = "avg", indent = 2 },
	-- 			{ kind = ":", indent = 2 },
	-- 			{ kind = "CHARS", value = "0.278", indent = 2 },
	-- 			{ kind = "-MAP", indent = 2 },
	-- 			{ kind = "+MAP", indent = 2 },
	-- 			{ kind = "CHARS", value = "name", indent = 2 },
	-- 			{ kind = ":", indent = 2 },
	-- 			{ kind = "CHARS", value = "Sammy Sosa", indent = 2 },
	-- 			{ kind = "CHARS", value = "hr", indent = 2 },
	-- 			{ kind = ":", indent = 2 },
	-- 			{ kind = "CHARS", value = "63", indent = 2 },
	-- 			{ kind = "CHARS", value = "avg", indent = 2 },
	-- 			{ kind = ":", indent = 2 },
	-- 			{ kind = "CHARS", value = "0.288", indent = 2 },
	-- 			{ kind = "-MAP", indent = 2 },
	-- 			{ kind = "-SEQ", indent = 0 },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
	--
	-- 	it("should lex spec example 2.5", function()
	-- 		local doc = [[
	-- - [name        , hr, avg  ]
	-- - [Mark McGwire, 65, 0.278]
	-- - [Sammy Sosa  , 63, 0.288]
	-- ]]
	-- 		local iter = StringIterator:new(doc)
	-- 		local lexer = Lexer:new(iter)
	-- 		local expect = {
	-- 			{ kind = "+SEQ", indent = 0 },
	-- 			{ kind = "[" },
	-- 			{ kind = "CHARS", value = "name", indent = 0 },
	-- 			{ kind = "CHARS", value = "hr", indent = 0 },
	-- 			{ kind = "CHARS", value = "avg", indent = 0 },
	-- 			{ kind = "]" },
	-- 			{ kind = "[" },
	-- 			{ kind = "CHARS", value = "Mark McGwire", indent = 0 },
	-- 			{ kind = "CHARS", value = "65", indent = 0 },
	-- 			{ kind = "CHARS", value = "0.278", indent = 0 },
	-- 			{ kind = "]" },
	-- 			{ kind = "[" },
	-- 			{ kind = "CHARS", value = "Sammy Sosa", indent = 0 },
	-- 			{ kind = "CHARS", value = "63", indent = 0 },
	-- 			{ kind = "CHARS", value = "0.288", indent = 0 },
	-- 			{ kind = "]" },
	-- 			{ kind = "-SEQ", indent = 0 },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
	--
	-- 	it("should lex spec example #2.6", function()
	-- 		local doc = [[
	-- Mark McGwire: {hr: 65, avg: 0.278}
	-- Sammy Sosa: {
	--     hr: 63,
	--     avg: 0.288,
	--  }
	-- ]]
	-- 		local iter = StringIterator:new(doc)
	-- 		local lexer = Lexer:new(iter)
	-- 		local expect = {
	-- 			{ kind = "+MAP", indent = 0 },
	-- 			{ kind = "CHARS", value = "Mark McGwire", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "{" },
	-- 			{ kind = "CHARS", value = "hr", indent = 0 },
	-- 			{ kind = "COLON", indent = 0 },
	-- 			{ kind = "CHARS", value = "65", indent = 0 },
	-- 			{ kind = "SEP", indent = 0 },
	-- 			{ kind = "CHARS", value = "avg", indent = 0 },
	-- 			{ kind = "COLON", indent = 0 },
	-- 			{ kind = "CHARS", value = "0.278", indent = 0 },
	-- 			{ kind = "}" },
	-- 			{ kind = "CHARS", value = "Sammy Sosa", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "{" },
	-- 			{ kind = "CHARS", value = "hr", indent = 0 },
	-- 			{ kind = "COLON", indent = 0 },
	-- 			{ kind = "CHARS", value = "63", indent = 0 },
	-- 			{ kind = "SEP", indent = 0 },
	-- 			{ kind = "CHARS", value = "avg", indent = 0 },
	-- 			{ kind = "COLON", indent = 0 },
	-- 			{ kind = "CHARS", value = "0.288", indent = 0 },
	-- 			{ kind = "SEP", indent = 0 },
	-- 			{ kind = "}" },
	-- 			{ kind = "-MAP", indent = 0 },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
	--
	-- 	it("should lex spec example 2.7", function()
	-- 		local doc = [[
	-- # Ranking of 1998 home runs
	-- ---
	-- - Mark McGwire
	-- - Sammy Sosa
	-- - Ken Griffey
	--
	-- # Team ranking
	-- ---
	-- - Chicago Cubs
	-- - St Louis Cardinals
	-- ]]
	-- 		local iter = StringIterator:new(doc)
	-- 		local lexer = Lexer:new(iter)
	-- 		local expect = {
	-- 			{ kind = "+DOC", indent = 0 },
	-- 			{ kind = "+SEQ", indent = 0 },
	-- 			{ kind = "CHARS", value = "Mark McGwire", indent = 0 },
	-- 			{ kind = "CHARS", value = "Sammy Sosa", indent = 0 },
	-- 			{ kind = "CHARS", value = "Ken Griffey", indent = 0 },
	-- 			{ kind = "-SEQ", indent = 0 },
	-- 			{ kind = "+DOC", indent = 0 },
	-- 			{ kind = "+SEQ", indent = 0 },
	-- 			{ kind = "CHARS", value = "Chicago Cubs", indent = 0 },
	-- 			{ kind = "CHARS", value = "St Louis Cardinals", indent = 0 },
	-- 			{ kind = "-SEQ", indent = 0 },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
	--
	-- 	it("should lex spec example 2.8", function()
	-- 		local doc = [[
	-- ---
	-- time: 20:03:20
	-- player: Sammy Sosa
	-- action: strike (miss)
	-- ...
	-- ---
	-- time: 20:03:47
	-- player: Sammy Sosa
	-- action: grand slam
	-- ...
	-- ]]
	-- 		local iter = StringIterator:new(doc)
	-- 		local lexer = Lexer:new(iter)
	-- 		local expect = {
	-- 			{ kind = "+DOC", indent = 0 },
	-- 			{ kind = "+MAP", indent = 0 },
	-- 			{ kind = "CHARS", value = "time", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "CHARS", value = "20:03:20", indent = 0 },
	-- 			{ kind = "CHARS", value = "player", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "CHARS", value = "Sammy Sosa", indent = 0 },
	-- 			{ kind = "CHARS", value = "action", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "CHARS", value = "strike (miss)", indent = 0 },
	-- 			{ kind = "-MAP", indent = 0 },
	-- 			{ kind = "-DOC", indent = 0 },
	-- 			{ kind = "+DOC", indent = 0 },
	-- 			{ kind = "+MAP", indent = 0 },
	-- 			{ kind = "CHARS", value = "time", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "CHARS", value = "20:03:47", indent = 0 },
	-- 			{ kind = "CHARS", value = "player", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "CHARS", value = "Sammy Sosa", indent = 0 },
	-- 			{ kind = "CHARS", value = "action", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "CHARS", value = "grand slam", indent = 0 },
	-- 			{ kind = "-MAP", indent = 0 },
	-- 			{ kind = "-DOC", indent = 0 },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
	--
	-- 	it("should lex spec example 2.9", function()
	-- 		local doc = [[
	-- ---
	-- hr: # 1998 hr ranking
	-- - Mark McGwire
	-- - Sammy Sosa
	-- # 1998 rbi ranking
	-- rbi:
	-- - Sammy Sosa
	-- - Ken Griffey
	-- ]]
	-- 		local iter = StringIterator:new(doc)
	-- 		local lexer = Lexer:new(iter)
	-- 		local expect = {
	-- 			{ kind = "+DOC", indent = 0 },
	-- 			{ kind = "+MAP", indent = 0 },
	-- 			{ kind = "CHARS", value = "hr", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "+SEQ", indent = 0 },
	-- 			{ kind = "CHARS", value = "Mark McGwire", indent = 0 },
	-- 			{ kind = "CHARS", value = "Sammy Sosa", indent = 0 },
	-- 			{ kind = "-SEQ", indent = 0 },
	-- 			{ kind = "CHARS", value = "rbi", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "+SEQ", indent = 0 },
	-- 			{ kind = "CHARS", value = "Sammy Sosa", indent = 0 },
	-- 			{ kind = "CHARS", value = "Ken Griffey", indent = 0 },
	-- 			{ kind = "-SEQ", indent = 0 },
	-- 			{ kind = "-MAP", indent = 0 },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
	--
	-- 	it("should lex spec alternate example 2.9", function()
	-- 		local doc = [[
	-- ---
	-- hr: # 1998 hr ranking
	--   - Mark McGwire
	--   - Sammy Sosa
	-- rbi:
	--   # 1998 rbi ranking
	--   - Sammy Sosa
	--   - Ken Griffey
	-- ]]
	-- 		local iter = StringIterator:new(doc)
	-- 		local lexer = Lexer:new(iter)
	-- 		local expect = {
	-- 			{ kind = "+DOC", indent = 0 },
	-- 			{ kind = "+MAP", indent = 0 },
	-- 			{ kind = "CHARS", value = "hr", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "+SEQ", indent = 2 },
	-- 			{ kind = "CHARS", value = "Mark McGwire", indent = 2 },
	-- 			{ kind = "CHARS", value = "Sammy Sosa", indent = 2 },
	-- 			{ kind = "-SEQ", indent = 2 },
	-- 			{ kind = "CHARS", value = "rbi", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "+SEQ", indent = 2 },
	-- 			{ kind = "CHARS", value = "Sammy Sosa", indent = 2 },
	-- 			{ kind = "CHARS", value = "Ken Griffey", indent = 2 },
	-- 			{ kind = "-SEQ", indent = 2 },
	-- 			{ kind = "-MAP", indent = 0 },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
	--
	-- 	it("should lex spec example #2.9space", function()
	-- 		local doc = [[
	-- ---
	-- hr: # 1998 hr ranking
	--   - Mark McGwire
	--   - Sammy Sosa
	-- # 1998 rbi ranking
	-- rbi:
	--   - Sammy Sosa
	--   - Ken Griffey
	-- ]]
	-- 		local iter = StringIterator:new(doc)
	-- 		local lexer = Lexer:new(iter)
	-- 		local expect = {
	-- 			{ kind = "+DOC", indent = 0 },
	-- 			{ kind = "+MAP", indent = 0 },
	-- 			{ kind = "CHARS", value = "hr", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "+SEQ", indent = 2 },
	-- 			{ kind = "CHARS", value = "Mark McGwire", indent = 2 },
	-- 			{ kind = "CHARS", value = "Sammy Sosa", indent = 2 },
	-- 			{ kind = "-SEQ", indent = 2 },
	-- 			{ kind = "CHARS", value = "rbi", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "+SEQ", indent = 2 },
	-- 			{ kind = "CHARS", value = "Sammy Sosa", indent = 2 },
	-- 			{ kind = "CHARS", value = "Ken Griffey", indent = 2 },
	-- 			{ kind = "-SEQ", indent = 2 },
	-- 			{ kind = "-MAP", indent = 0 },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
	--
	-- 	it("should lex spec example 2.10", function()
	-- 		local doc = [[
	-- ---
	-- hr:
	-- - Mark McGwire
	-- # Following node labeled SS
	-- - &SS Sammy Sosa
	-- rbi:
	-- - *SS # Subsequent occurrence
	-- - Ken Griffey
	-- ]]
	-- 		local iter = StringIterator:new(doc)
	-- 		local lexer = Lexer:new(iter)
	-- 		local expect = {
	-- 			{ kind = "+DOC", indent = 0 },
	-- 			{ kind = "+MAP", indent = 0 },
	-- 			{ kind = "CHARS", value = "hr", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "+SEQ", indent = 0 },
	-- 			{ kind = "CHARS", value = "Mark McGwire", indent = 0 },
	-- 			{ kind = "&", indent = 0, value = "SS" },
	-- 			{ kind = "CHARS", value = "Sammy Sosa", indent = 0 },
	-- 			{ kind = "-SEQ", indent = 0 },
	-- 			{ kind = "CHARS", value = "rbi", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "+SEQ", indent = 0 },
	-- 			{ kind = "*", indent = 0, value = "SS" },
	-- 			{ kind = "CHARS", value = "Ken Griffey", indent = 0 },
	-- 			{ kind = "-SEQ", indent = 0 },
	-- 			{ kind = "-MAP", indent = 0 },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
	--
	-- 	it("should lex spec #example 2.11 #exclude", function()
	-- 		local doc = [[
	-- ? - Detroit Tigers
	--   - Chicago cubs
	-- : - 2001-07-23
	--
	-- ? [ New York Yankees,
	--     Atlanta Braves ]
	-- : [ 2001-07-02, 2001-08-12,
	--     2001-08-14 ]
	-- ]]
	-- 		local iter = StringIterator:new(doc)
	-- 		local lexer = Lexer:new(iter)
	-- 		local expect = {
	-- 			{ kind = "?", indent = 0 },
	-- 			{ kind = "DASH", indent = 0 },
	-- 			{ kind = "CHARS", value = "Detroit Tigers" },
	-- 			{ kind = "DASH", indent = 2 },
	-- 			{ kind = "CHARS", value = "Chicago cubs" },
	-- 			{ kind = "COLON", indent = 0 },
	-- 			{ kind = "DASH", indent = 0 },
	-- 			{ kind = "CHARS", value = "2001-07-23" },
	-- 			{ kind = "?", indent = 0 },
	-- 			{ kind = "[", indent = 0 },
	-- 			{ kind = "CHARS", value = "New York Yankees" },
	-- 			{ kind = "CHARS", value = "Atlanta Braves" },
	-- 			{ kind = "]", indent = 0 },
	-- 			{ kind = "COLON", indent = 0 },
	-- 			{ kind = "[", indent = 0 },
	-- 			{ kind = "CHARS", value = "2001-07-02" },
	-- 			{ kind = "CHARS", value = "2001-08-12" },
	-- 			{ kind = "CHARS", value = "2001-07-14" },
	-- 			{ kind = "]", indent = 0 },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
	--
	-- 	it("should lex spec example #2.12", function()
	-- 		local doc = [[
	-- ---
	-- # Products purchased
	-- - item    : Super Hoop
	--   quantity: 1
	-- - item    : Basketball
	--   quantity: 4
	-- - item    : Big Shoes
	--   quantity: 1
	-- ]]
	-- 		local iter = StringIterator:new(doc)
	-- 		local lexer = Lexer:new(iter)
	-- 		local expect = {
	-- 			{ kind = "+DOC", indent = 0 },
	-- 			{ kind = "+SEQ", indent = 0 },
	-- 			{ kind = "+MAP", indent = 2 },
	-- 			{ kind = "CHARS", value = "item", indent = 2 },
	-- 			{ kind = ":", indent = 2 },
	-- 			{ kind = "CHARS", value = "Super Hoop", indent = 2 },
	-- 			{ kind = "CHARS", value = "quantity", indent = 2 },
	-- 			{ kind = ":", indent = 2 },
	-- 			{ kind = "CHARS", value = "1", indent = 2 },
	-- 			{ kind = "-MAP", indent = 2 },
	-- 			{ kind = "+MAP", indent = 2 },
	-- 			{ kind = "CHARS", value = "item", indent = 2 },
	-- 			{ kind = ":", indent = 2 },
	-- 			{ kind = "CHARS", value = "Basketball", indent = 2 },
	-- 			{ kind = "CHARS", value = "quantity", indent = 2 },
	-- 			{ kind = ":", indent = 2 },
	-- 			{ kind = "CHARS", value = "4", indent = 2 },
	-- 			{ kind = "-MAP", indent = 2 },
	-- 			{ kind = "+MAP", indent = 2 },
	-- 			{ kind = "CHARS", value = "item", indent = 2 },
	-- 			{ kind = ":", indent = 2 },
	-- 			{ kind = "CHARS", value = "Big Shoes", indent = 2 },
	-- 			{ kind = "CHARS", value = "quantity", indent = 2 },
	-- 			{ kind = ":", indent = 2 },
	-- 			{ kind = "CHARS", value = "1", indent = 2 },
	-- 			{ kind = "-MAP", indent = 2 },
	-- 			{ kind = "-SEQ", indent = 0 },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
	--
	-- 	it("should lex spec example #2.13", function()
	-- 		local doc = [[
	-- # ASCII Art
	-- --- |
	--   \//||\/||
	--   // ||  ||__
	-- ]]
	-- 		local iter = StringIterator:new(doc)
	-- 		local lexer = Lexer:new(iter)
	-- 		local expect = {
	-- 			{ kind = "+DOC", indent = 0 },
	-- 			{ kind = "+|", indent = 0 },
	-- 			{ kind = "CHARS", value = "\\//||\\/||", indent = 2 },
	-- 			{ kind = "CHARS", value = "// ||  ||__", indent = 2 },
	-- 			{ kind = "-|", indent = 0 },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
	--
	-- 	it("should lex spec example #2.14", function()
	-- 		local doc = [[
	-- --- >
	--   Mark McGwire's
	--   year was crippled
	--   by a knee injury.
	-- ]]
	-- 		local iter = StringIterator:new(doc)
	-- 		local lexer = Lexer:new(iter)
	-- 		local expect = {
	-- 			{ kind = "+DOC", indent = 0 },
	-- 			{ kind = "+>", indent = 0 },
	-- 			{ kind = "CHARS", value = "Mark McGwire's", indent = 2 },
	-- 			{ kind = "CHARS", value = "year was crippled", indent = 2 },
	-- 			{ kind = "CHARS", value = "by a knee injury.", indent = 2 },
	-- 			{ kind = "->", indent = 0 },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
	--
	-- 	it("should lex spec example #2.15a", function()
	-- 		local doc = [[
	-- --- >
	--  Sammy Sosa completed another
	--  fine season with great stats.
	--
	--    63 Home Runs
	--    0.288 Batting Average
	--
	--  What a year!
	-- ]]
	-- 		local iter = StringIterator:new(doc)
	-- 		local lexer = Lexer:new(iter)
	-- 		local expect = {
	-- 			{ kind = "+DOC", indent = 0 },
	-- 			{ kind = "+>", indent = 0 },
	-- 			{ kind = "CHARS", value = "Sammy Sosa completed another", indent = 1 },
	-- 			{ kind = "CHARS", value = "fine season with great stats.", indent = 1 },
	-- 			{ kind = "NL", indent = 0 },
	-- 			{ kind = "CHARS", value = "63 Home Runs", indent = 3 },
	-- 			{ kind = "CHARS", value = "0.288 Batting Average", indent = 3 },
	-- 			{ kind = "NL", indent = 0 },
	-- 			{ kind = "CHARS", value = "What a year!", indent = 1 },
	-- 			{ kind = "->", indent = 0 },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
	--
	-- 	it("should lex alternate spec example #2.15b", function()
	-- 		local doc = [[>
	--  Sammy Sosa completed another
	--  fine season with great stats.
	--
	--    63 Home Runs
	--    0.288 Batting Average
	--
	--  What a year!
	-- ]]
	-- 		local iter = StringIterator:new(doc)
	-- 		local lexer = Lexer:new(iter)
	-- 		local expect = {
	-- 			{ kind = "+>", indent = 0 },
	-- 			{ kind = "CHARS", value = "Sammy Sosa completed another", indent = 1 },
	-- 			{ kind = "CHARS", value = "fine season with great stats.", indent = 1 },
	-- 			{ kind = "NL", indent = 0 },
	-- 			{ kind = "CHARS", value = "63 Home Runs", indent = 3 },
	-- 			{ kind = "CHARS", value = "0.288 Batting Average", indent = 3 },
	-- 			{ kind = "NL", indent = 0 },
	-- 			{ kind = "CHARS", value = "What a year!", indent = 1 },
	-- 			{ kind = "->", indent = 0 },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
	--
	-- 	it("should lex spec example #2.16", function()
	-- 		local doc = [[
	-- name: Mark McGwire
	-- accomplishment: >
	--   Mark set a major league
	--   home run record in 1998.
	-- stats: |
	--   65 Home Runs
	--   0.278 Batting Average
	-- ]]
	-- 		local iter = StringIterator:new(doc)
	-- 		local lexer = Lexer:new(iter)
	-- 		local expect = {
	-- 			{ kind = "+MAP", indent = 0 },
	-- 			{ kind = "CHARS", value = "name", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "CHARS", value = "Mark McGwire", indent = 0 },
	-- 			{ kind = "CHARS", value = "accomplishment", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "+>", indent = 0 },
	-- 			{ kind = "CHARS", value = "Mark set a major league", indent = 2 },
	-- 			{ kind = "CHARS", value = "home run record in 1998.", indent = 2 },
	-- 			{ kind = "->", indent = 0 },
	-- 			{ kind = "CHARS", value = "stats", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "+|", indent = 0 },
	-- 			{ kind = "CHARS", value = "65 Home Runs", indent = 2 },
	-- 			{ kind = "CHARS", value = "0.278 Batting Average", indent = 2 },
	-- 			{ kind = "-|", indent = 0 },
	-- 			{ kind = "-MAP", indent = 0 },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
	--
	-- 	it("should lex spec example #2.17", function()
	-- 		local doc = [[
	-- unicode: "Sosa did fine.\u263A"
	-- control: "\b1998\t1999\t2000\n"
	-- hex esc: "\x0d\x0a is \r\n"
	--
	-- single: '"Howdy!" he cried.'
	-- quoted: ' # Not a ''comment''.'
	-- tie-fighter: '|\-*-/|'
	-- ]]
	-- 		local iter = StringIterator:new(doc)
	-- 		local lexer = Lexer:new(iter)
	-- 		local expect = {
	-- 			{ kind = "+MAP", indent = 0 },
	-- 			{ kind = "CHARS", value = "unicode", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "CHARS", value = "Sosa did fine.\\u263A", type = '"', indent = 0 },
	-- 			{ kind = "CHARS", value = "control", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "CHARS", value = "\\b1998\\t1999\\t2000\n", type = '"', indent = 0 },
	-- 			{ kind = "CHARS", value = "hex esc", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "CHARS", value = "\\x0d\\x0a is \\r\n", type = '"', indent = 0 },
	-- 			{ kind = "CHARS", value = "single", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "CHARS", value = '"Howdy!" he cried.', type = "'", indent = 0 },
	-- 			{ kind = "CHARS", value = "quoted", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "CHARS", value = " # Not a 'comment'.", type = "'", indent = 0 },
	-- 			{ kind = "CHARS", value = "tie-fighter", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "CHARS", value = "|\\-*-/|", type = "'", indent = 0 },
	-- 			{ kind = "-MAP", indent = 0 },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
	--
	-- 	it("should lex spec example #2.18", function()
	-- 		local doc = [[
	-- plain:
	--   This unquoted scalar
	--   spans many lines.
	--
	-- quoted: "So does this
	--   quoted scalar.\n"
	-- ]]
	-- 		local iter = StringIterator:new(doc)
	-- 		local lexer = Lexer:new(iter)
	-- 		local expect = {
	-- 			{ kind = "+MAP", indent = 0 },
	-- 			{ kind = "CHARS", value = "plain", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "CHARS", value = "This unquoted scalar", indent = 2 },
	-- 			{ kind = "CHARS", value = "spans many lines.", indent = 2 },
	-- 			-- { kind = "CHARS", value = "", type = "'", indent = 0 },
	-- 			{ kind = "CHARS", value = "quoted", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "CHARS", value = "So does this", type = '"', indent = 0 },
	-- 			{ kind = "CHARS", value = "quoted scalar.\n", type = '"', indent = 0 },
	-- 			{ kind = "-MAP", indent = 0 },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
	--
	-- 	it("should lex spec example #2.24", function()
	-- 		local doc = [[
	-- %TAG ! tag:clarkevans.com,2002:
	-- --- !shape
	--   # Use the ! handle for presenting
	--   # tag:clarkevans.com,2002:circle
	-- - !circle
	--   center: &ORIGIN {x: 73, y: 129}
	--   radius: 7
	-- - !line
	--   start: *ORIGIN
	--   finish: { x: 89, y: 102 }
	-- - !label
	--   start: *ORIGIN
	--   color: 0xFFEEBB
	--   text: Pretty vector drawing.
	-- ]]
	-- 		local iter = StringIterator:new(doc)
	-- 		local lexer = Lexer:new(iter)
	-- 		local expect = {
	-- 			{ kind = "%", indent = 0, value = "%TAG ! tag:clarkevans.com,2002:" },
	-- 			{ kind = "+DOC", indent = 0 },
	-- 			{ kind = "!", value = "!shape", indent = 0 },
	-- 			{ kind = "+SEQ", indent = 0 },
	-- 			{ kind = "!", value = "!circle", indent = 0 },
	-- 			{ kind = "+MAP", indent = 2 },
	-- 			{ kind = "CHARS", value = "center", indent = 2 },
	-- 			{ kind = ":", indent = 2 },
	-- 			{ kind = "&", value = "ORIGIN", indent = 2 },
	-- 			{ kind = "{" },
	-- 			{ kind = "CHARS", value = "x", indent = 0 },
	-- 			{ kind = "COLON", indent = 0 },
	-- 			{ kind = "CHARS", value = "73", indent = 0 },
	-- 			{ kind = "SEP", indent = 0 },
	-- 			{ kind = "CHARS", value = "y", indent = 0 },
	-- 			{ kind = "COLON", indent = 0 },
	-- 			{ kind = "CHARS", value = "129", indent = 0 },
	-- 			{ kind = "}" },
	-- 			{ kind = "CHARS", value = "radius", indent = 2 },
	-- 			{ kind = ":", indent = 2 },
	-- 			{ kind = "CHARS", value = "7", indent = 2 },
	-- 			{ kind = "-MAP", indent = 2 },
	--
	-- 			{ kind = "!", value = "!line", indent = 0 },
	-- 			{ kind = "+MAP", indent = 2 },
	-- 			{ kind = "CHARS", value = "start", indent = 2 },
	-- 			{ kind = ":", indent = 2 },
	-- 			{ kind = "*", value = "ORIGIN", indent = 2 },
	-- 			{ kind = "CHARS", value = "finish", indent = 2 },
	-- 			{ kind = ":", indent = 2 },
	-- 			{ kind = "{" },
	-- 			{ kind = "CHARS", value = "x", indent = 0 },
	-- 			{ kind = "COLON", indent = 0 },
	-- 			{ kind = "CHARS", value = "89", indent = 0 },
	-- 			{ kind = "SEP", indent = 0 },
	-- 			{ kind = "CHARS", value = "y", indent = 0 },
	-- 			{ kind = "COLON", indent = 0 },
	-- 			{ kind = "CHARS", value = "102", indent = 0 },
	-- 			{ kind = "}" },
	-- 			{ kind = "-MAP", indent = 2 },
	--
	-- 			{ kind = "!", value = "!label", indent = 0 },
	-- 			{ kind = "+MAP", indent = 2 },
	-- 			{ kind = "CHARS", value = "start", indent = 2 },
	-- 			{ kind = ":", indent = 2 },
	-- 			{ kind = "*", value = "ORIGIN", indent = 2 },
	-- 			{ kind = "CHARS", value = "color", indent = 2 },
	-- 			{ kind = ":", indent = 2 },
	-- 			{ kind = "CHARS", value = "0xFFEEBB", indent = 2 },
	-- 			{ kind = "CHARS", value = "text", indent = 2 },
	-- 			{ kind = ":", indent = 2 },
	-- 			{ kind = "CHARS", value = "Pretty vector drawing.", indent = 2 },
	-- 			{ kind = "-MAP", indent = 2 },
	-- 			{ kind = "-SEQ", indent = 0 },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
	--
	-- 	it("should lex spec example #2.26", function()
	-- 		local doc = [[
	-- # The !!omap tag is one of the optional types
	-- # introduced for YAML 1.1. In 1.2, it is not
	-- # part of the standard tags and should not be
	-- # enabled by default.
	-- # Ordered maps are represented as
	-- # A sequence of mappings, with
	-- # each mapping having one key
	-- --- !!omap
	-- - Mark McGwire: 65
	-- - Sammy Sosa: 63
	-- - Ken Griffy: 58
	-- ]]
	-- 		local iter = StringIterator:new(doc)
	-- 		local lexer = Lexer:new(iter)
	-- 		local expect = {
	-- 			{ kind = "+DOC", indent = 0 },
	-- 			{ kind = "!", value = "!!omap", indent = 0 },
	-- 			{ kind = "+SEQ", indent = 0 },
	-- 			{ kind = "+MAP", indent = 0 },
	-- 			{ kind = "CHARS", value = "Mark McGwire", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "CHARS", value = "65", indent = 0 },
	-- 			{ kind = "-MAP", indent = 0 },
	-- 			{ kind = "+MAP", indent = 0 },
	-- 			{ kind = "CHARS", value = "Sammy Sosa", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "CHARS", value = "63", indent = 0 },
	-- 			{ kind = "-MAP", indent = 0 },
	-- 			{ kind = "+MAP", indent = 0 },
	-- 			{ kind = "CHARS", value = "Ken Griffy", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "CHARS", value = "58", indent = 0 },
	-- 			{ kind = "-MAP", indent = 0 },
	-- 			{ kind = "-SEQ", indent = 0 },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
	--
	-- 	it("should parse invoice", function()
	-- 		local doc = [[
	-- --- !<tag:clarkevans.com,2002:invoice>
	-- invoice: 34843
	-- date   : 2001-01-23
	-- bill-to: &id001
	--   given  : Chris
	--   family : Dumars
	-- ]]
	-- 		local iter = StringIterator:new(doc)
	-- 		local lexer = Lexer:new(iter)
	-- 		local expect = {
	-- 			{ kind = "+DOC", indent = 0 },
	-- 			{ kind = "!", value = "!<tag:clarkevans.com,2002:invoice>", indent = 0 },
	-- 			{ kind = "+MAP", indent = 0 },
	-- 			{ kind = "CHARS", value = "invoice", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "CHARS", value = "34843", indent = 0 },
	-- 			{ kind = "CHARS", value = "date", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "CHARS", value = "2001-01-23", indent = 0 },
	-- 			{ kind = "CHARS", value = "bill-to", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "&", value = "id001", indent = 0 },
	-- 			{ kind = "+MAP", indent = 2 },
	-- 			{ kind = "CHARS", value = "given", indent = 2 },
	-- 			{ kind = ":", indent = 2 },
	-- 			{ kind = "CHARS", value = "Chris", indent = 2 },
	-- 			{ kind = "CHARS", value = "family", indent = 2 },
	-- 			{ kind = ":", indent = 2 },
	-- 			{ kind = "CHARS", value = "Dumars", indent = 2 },
	-- 			{ kind = "-MAP", indent = 2 },
	-- 			{ kind = "-MAP", indent = 0 },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
	--
	-- 	it("should parse #logfile", function()
	-- 		local doc = [[
	-- ---
	-- Time: 2001-11-23 15:01:42 -5
	-- User: ed
	-- Warning:
	--   This is an error message
	--   for the log file
	-- ---
	-- Time: 2001-11-23 15:02:31 -5
	-- User: ed
	-- Warning:
	--   A slightly different error
	--   message.
	-- ---
	-- Date: 2001-11-23 15:03:17 -5
	-- User: ed
	-- Fatal:
	--   Unknown variable "bar"
	-- Stack:
	-- - file: TopClass.py
	--   line: 23
	--   code: |
	--     x = MoreObject("345\n")
	-- ]]
	-- 		local iter = StringIterator:new(doc)
	-- 		local lexer = Lexer:new(iter)
	-- 		local expect = {
	-- 			{ kind = "+DOC", indent = 0 },
	-- 			{ kind = "+MAP", indent = 0 },
	-- 			{ kind = "CHARS", value = "Time", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "CHARS", value = "2001-11-23 15:01:42 -5", indent = 0 },
	-- 			{ kind = "CHARS", value = "User", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "CHARS", value = "ed", indent = 0 },
	-- 			{ kind = "CHARS", value = "Warning", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "CHARS", value = "This is an error message", indent = 2 },
	-- 			{ kind = "CHARS", value = "for the log file", indent = 2 },
	-- 			{ kind = "-MAP", indent = 0 },
	-- 			{ kind = "+DOC", indent = 0 },
	-- 			{ kind = "+MAP", indent = 0 },
	-- 			{ kind = "CHARS", value = "Time", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "CHARS", value = "2001-11-23 15:02:31 -5", indent = 0 },
	-- 			{ kind = "CHARS", value = "User", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "CHARS", value = "ed", indent = 0 },
	-- 			{ kind = "CHARS", value = "Warning", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "+LITERAL", indent = 2 },
	-- 			{ kind = "CHARS", value = "A slightly different error\nmessage.", indent = 2 },
	-- 			{ kind = "-LITERAL", indent = 2 },
	-- 			{ kind = "-MAP", indent = 0 },
	-- 			{ kind = "+DOC", indent = 0 },
	-- 			{ kind = "+MAP", indent = 0 },
	-- 			{ kind = "CHARS", value = "Date", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "CHARS", value = "2001-11-23 15:03:17 -5", indent = 0 },
	-- 			{ kind = "CHARS", value = "User", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "CHARS", value = "ed", indent = 0 },
	-- 			{ kind = "CHARS", value = "Fatal", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "+LITERAL", indent = 2 },
	-- 			{ kind = "CHARS", value = 'Unknown variable "bar"', indent = 2 },
	-- 			{ kind = "-LITERAL", indent = 2 },
	-- 			{ kind = "CHARS", value = "Stack", indent = 0 },
	-- 			{ kind = ":", indent = 0 },
	-- 			{ kind = "+SEQ", indent = 0 },
	-- 			{ kind = "+MAP", indent = 2 },
	-- 			{ kind = "CHARS", value = "file", indent = 2 },
	-- 			{ kind = ":", indent = 2 },
	-- 			{ kind = "CHARS", value = "TopClass.py", indent = 2 },
	-- 			{ kind = "CHARS", value = "line", indent = 2 },
	-- 			{ kind = ":", indent = 2 },
	-- 			{ kind = "CHARS", value = "23", indent = 2 },
	-- 			{ kind = "CHARS", value = "code", indent = 2 },
	-- 			{ kind = ":", indent = 2 },
	-- 			{ kind = "+LITERAL", indent = 4 },
	-- 			{ kind = "CHARS", value = 'x = MoreObject("345\\n")', indent = 4 },
	-- 			{ kind = "-LITERAL", indent = 4 },
	-- 			{ kind = "-MAP", indent = 2 },
	-- 			{ kind = "-SEQ", indent = 0 },
	-- 			{ kind = "-MAP", indent = 0 },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
end)
