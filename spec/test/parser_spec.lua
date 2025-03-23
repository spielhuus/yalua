local assert = require("luassert")
local Lexer = require("Lexer2")
local Parser = require("Parser2")
local StringIterator = require("StringIterator")

local function load_file(file_path)
	local file = io.open(file_path, "r")
	if not file then
		return nil, "File not found"
	end
	local content = file:read("*all")
	file:close()
	return content
end

describe("Test the Parser", function()
	it("should parse a stream start #document", function()
		local doc = [[
---
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		assert(lexer)
		local parser = Parser:new(lexer)
		-- 		TODO: correct result
		-- 		local expect = [[
		-- +STR
		--  +DOC ---
		--    =VAL :
		--  -DOC
		-- -STR
		-- ]]
		local expect = [[
+STR
 +DOC ---
 -DOC
-STR
]]
		assert.are.same(expect, tostring(parser))
	end)

	it("should parse a simple value #exclude", function()
		local doc = [[
---
value
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		assert(lexer)
		local parser = Parser:new(lexer)
		local expect = [[
+STR
 +DOC ---
  =VAL :value
 -DOC
-STR
]]
		assert.are.same(expect, tostring(parser))
	end)

	it("should parse a mapping #true", function()
		local doc = [[
---
key: value
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		assert(lexer)
		local parser = Parser:new(lexer)
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
		assert.are.same(expect, tostring(parser))
	end)

	it("should parse a sequence #true", function()
		local doc = [[
---
- value1
- value2
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		assert(lexer)
		local parser = Parser:new(lexer)
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
		assert.are.same(expect, tostring(parser))
	end)

	it("should parse a nested sequence #true", function()
		local doc = [[
---
- - value1
  - value2
- value 3
]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		assert(lexer)
		local parser = Parser:new(lexer)
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
		assert.are.same(expect, tostring(parser))
	end)

	it("should parse a node with comment #true", function()
		local doc = [[
	# This is a comment
	---
	- - value1 # another comment
	  - value2
	#and a comment
	- value 3
	key: value # comment
	]]
		local iter = StringIterator:new(doc)
		local lexer = Lexer:new(iter)
		local expect = {
			{ kind = "+DOC" },
			{ kind = "DASH", indent = 0 },
			{ kind = "DASH", indent = 0 },
			{ kind = "CHARS", value = "value1" },
			{ kind = "DASH", indent = 2 },
			{ kind = "CHARS", value = "value2" },
			{ kind = "EINDENT", indent = 2 },
			{ kind = "DASH", indent = 0 },
			{ kind = "CHARS", value = "value 3" },
			{ kind = "CHARS", value = "key" },
			{ kind = "COLON", indent = 0 },
			{ kind = "CHARS", value = "value" },
		}
		assert(lexer)
		assert.are.same(expect, lexer.tokens)
	end)
	--
	-- 	it("should parse spec example 2.1", function()
	-- 		local doc = [[
	-- - Mark McGwire
	-- - Sammy Sosa
	-- - Ken Griffey
	-- ]]
	-- 		local iter = StringIterator:new(doc)
	-- 		local lexer = Lexer:new(iter)
	-- 		local expect = {
	-- 			{ kind = "DASH", indent = 0 },
	-- 			{ kind = "CHARS", value = "Mark McGwire" },
	-- 			{ kind = "DASH", indent = 0 },
	-- 			{ kind = "CHARS", value = "Sammy Sosa" },
	-- 			{ kind = "DASH", indent = 0 },
	-- 			{ kind = "CHARS", value = "Ken Griffey" },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
	--
	-- 	it("should parse spec example 2.2", function()
	-- 		local doc = [[
	-- hr:  65    # Home runs
	-- avg: 0.278 # Batting average
	-- rbi: 147   # Runs Batted In
	-- ]]
	-- 		local iter = StringIterator:new(doc)
	-- 		local lexer = Lexer:new(iter)
	-- 		local expect = {
	-- 			{ kind = "CHARS", value = "hr" },
	-- 			{ kind = "COLON", indent = 0 },
	-- 			{ kind = "CHARS", value = "65" },
	-- 			{ kind = "CHARS", value = "avg" },
	-- 			{ kind = "COLON", indent = 0 },
	-- 			{ kind = "CHARS", value = "0.278" },
	-- 			{ kind = "CHARS", value = "rbi" },
	-- 			{ kind = "COLON", indent = 0 },
	-- 			{ kind = "CHARS", value = "147" },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
	--
	-- 	it("should parse spec example 2.3", function()
	-- 		local doc = [[
	-- american:
	-- - Boston Red Sox
	-- - Detroit Tigers
	-- - New York Yankees
	-- national:
	-- - New York Mets
	-- - Chicago Cubs
	-- - Atlanta Braves
	-- ]]
	-- 		local iter = StringIterator:new(doc)
	-- 		local lexer = Lexer:new(iter)
	-- 		local expect = {
	-- 			{ kind = "CHARS", value = "american" },
	-- 			{ kind = "COLON", indent = 0 },
	-- 			{ kind = "DASH", indent = 0 },
	-- 			{ kind = "CHARS", value = "Boston Red Sox" },
	-- 			{ kind = "DASH", indent = 0 },
	-- 			{ kind = "CHARS", value = "Detroit Tigers" },
	-- 			{ kind = "DASH", indent = 0 },
	-- 			{ kind = "CHARS", value = "New York Yankees" },
	-- 			{ kind = "CHARS", value = "national" },
	-- 			{ kind = "COLON", indent = 0 },
	-- 			{ kind = "DASH", indent = 0 },
	-- 			{ kind = "CHARS", value = "New York Mets" },
	-- 			{ kind = "DASH", indent = 0 },
	-- 			{ kind = "CHARS", value = "Chicago Cubs" },
	-- 			{ kind = "DASH", indent = 0 },
	-- 			{ kind = "CHARS", value = "Atlanta Braves" },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
	--
	-- 	it("should parse spec example 2.4", function()
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
	-- 			{ kind = "DASH", indent = 0 },
	-- 			{ kind = "CHARS", value = "name" },
	-- 			{ kind = "COLON", indent = 2 },
	-- 			{ kind = "CHARS", value = "Mark McGwire" },
	-- 			{ kind = "CHARS", value = "hr" },
	-- 			{ kind = "COLON", indent = 2 },
	-- 			{ kind = "CHARS", value = "65" },
	-- 			{ kind = "CHARS", value = "avg" },
	-- 			{ kind = "COLON", indent = 2 },
	-- 			{ kind = "CHARS", value = "0.278" },
	-- 			{ kind = "EINDENT", indent = 2 },
	-- 			{ kind = "DASH", indent = 0 },
	-- 			{ kind = "CHARS", value = "name" },
	-- 			{ kind = "COLON", indent = 2 },
	-- 			{ kind = "CHARS", value = "Sammy Sosa" },
	-- 			{ kind = "CHARS", value = "hr" },
	-- 			{ kind = "COLON", indent = 2 },
	-- 			{ kind = "CHARS", value = "63" },
	-- 			{ kind = "CHARS", value = "avg" },
	-- 			{ kind = "COLON", indent = 2 },
	-- 			{ kind = "CHARS", value = "0.288" },
	-- 			{ kind = "EINDENT", indent = 2 },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
	--
	-- 	it("should parse spec example 2.5", function()
	-- 		local doc = [[
	-- - [name        , hr, avg  ]
	-- - [Mark McGwire, 65, 0.278]
	-- - [Sammy Sosa  , 63, 0.288]
	-- ]]
	-- 		local iter = StringIterator:new(doc)
	-- 		local lexer = Lexer:new(iter)
	-- 		local expect = {
	-- 			{ kind = "DASH", indent = 0 },
	-- 			{ kind = "[" },
	-- 			{ kind = "CHARS", value = "name" },
	-- 			{ kind = "CHARS", value = "hr" },
	-- 			{ kind = "CHARS", value = "avg" },
	-- 			{ kind = "]" },
	-- 			{ kind = "DASH", indent = 0 },
	-- 			{ kind = "[" },
	-- 			{ kind = "CHARS", value = "Mark McGwire" },
	-- 			{ kind = "CHARS", value = "65" },
	-- 			{ kind = "CHARS", value = "0.278" },
	-- 			{ kind = "]" },
	-- 			{ kind = "DASH", indent = 0 },
	-- 			{ kind = "[" },
	-- 			{ kind = "CHARS", value = "Sammy Sosa" },
	-- 			{ kind = "CHARS", value = "63" },
	-- 			{ kind = "CHARS", value = "0.288" },
	-- 			{ kind = "]" },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
	--
	-- 	it("should parse spec example 2.6", function()
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
	-- 			{ kind = "CHARS", value = "Mark McGwire" },
	-- 			{ kind = "COLON", indent = 0 },
	-- 			{ kind = "{" },
	-- 			{ kind = "CHARS", value = "hr" },
	-- 			{ kind = "CHARS", value = "65" },
	-- 			{ kind = "CHARS", value = "avg" },
	-- 			{ kind = "CHARS", value = "0.278" },
	-- 			{ kind = "}" },
	-- 			{ kind = "CHARS", value = "Sammy Sosa" },
	-- 			{ kind = "COLON", indent = 0 },
	-- 			{ kind = "{" },
	-- 			{ kind = "CHARS", value = "hr" },
	-- 			{ kind = "CHARS", value = "63" },
	-- 			{ kind = "CHARS", value = "avg" },
	-- 			{ kind = "CHARS", value = "0.288" },
	-- 			{ kind = "}" },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
	--
	-- 	it("should parse spec example 2.7", function()
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
	-- 			{ kind = "+DOC" },
	-- 			{ kind = "DASH", indent = 0 },
	-- 			{ kind = "CHARS", value = "Mark McGwire" },
	-- 			{ kind = "DASH", indent = 0 },
	-- 			{ kind = "CHARS", value = "Sammy Sosa" },
	-- 			{ kind = "DASH", indent = 0 },
	-- 			{ kind = "CHARS", value = "Ken Griffey" },
	-- 			{ kind = "+DOC" },
	-- 			{ kind = "DASH", indent = 0 },
	-- 			{ kind = "CHARS", value = "Chicago Cubs" },
	-- 			{ kind = "DASH", indent = 0 },
	-- 			{ kind = "CHARS", value = "St Louis Cardinals" },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
	--
	-- 	it("should parse spec example 2.8", function()
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
	-- 			{ kind = "+DOC" },
	-- 			{ kind = "CHARS", value = "time" },
	-- 			{ kind = "COLON", indent = 0 },
	-- 			{ kind = "CHARS", value = "20:03:20" },
	-- 			{ kind = "CHARS", value = "player" },
	-- 			{ kind = "COLON", indent = 0 },
	-- 			{ kind = "CHARS", value = "Sammy Sosa" },
	-- 			{ kind = "CHARS", value = "action" },
	-- 			{ kind = "COLON", indent = 0 },
	-- 			{ kind = "CHARS", value = "strike (miss)" },
	-- 			{ kind = "-DOC" },
	-- 			{ kind = "+DOC" },
	-- 			{ kind = "CHARS", value = "time" },
	-- 			{ kind = "COLON", indent = 0 },
	-- 			{ kind = "CHARS", value = "20:03:47" },
	-- 			{ kind = "CHARS", value = "player" },
	-- 			{ kind = "COLON", indent = 0 },
	-- 			{ kind = "CHARS", value = "Sammy Sosa" },
	-- 			{ kind = "CHARS", value = "action" },
	-- 			{ kind = "COLON", indent = 0 },
	-- 			{ kind = "CHARS", value = "grand slam" },
	-- 			{ kind = "-DOC" },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
	--
	-- 	it("should parse spec example 2.9", function()
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
	-- 			{ kind = "+DOC" },
	-- 			{ kind = "CHARS", value = "hr" },
	-- 			{ kind = "COLON", indent = 0 },
	-- 			{ kind = "DASH", indent = 0 },
	-- 			{ kind = "CHARS", value = "Mark McGwire" },
	-- 			{ kind = "DASH", indent = 0 },
	-- 			{ kind = "CHARS", value = "Sammy Sosa" },
	-- 			{ kind = "CHARS", value = "rbi" },
	-- 			{ kind = "COLON", indent = 0 },
	-- 			{ kind = "DASH", indent = 0 },
	-- 			{ kind = "CHARS", value = "Sammy Sosa" },
	-- 			{ kind = "DASH", indent = 0 },
	-- 			{ kind = "CHARS", value = "Ken Griffey" },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
	--
	-- 	it("should parse spec example 2.10", function()
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
	-- 			{ kind = "+DOC" },
	-- 			{ kind = "CHARS", value = "hr" },
	-- 			{ kind = "COLON", indent = 0 },
	-- 			{ kind = "DASH", indent = 0 },
	-- 			{ kind = "CHARS", value = "Mark McGwire" },
	-- 			{ kind = "DASH", indent = 0 },
	-- 			{ kind = "&", indent = 0, value = "SS" },
	-- 			{ kind = "CHARS", value = "Sammy Sosa" },
	-- 			{ kind = "CHARS", value = "rbi" },
	-- 			{ kind = "COLON", indent = 0 },
	-- 			{ kind = "DASH", indent = 0 },
	-- 			{ kind = "*", indent = 0, value = "SS" },
	-- 			{ kind = "DASH", indent = 0 },
	-- 			{ kind = "CHARS", value = "Ken Griffey" },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
	--
	-- 	it("should parse spec #example 2.11 #exclude", function()
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
	-- 	it("should parse spec example 2.12", function()
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
	-- 			{ kind = "+DOC" },
	-- 			{ kind = "DASH", indent = 0 },
	-- 			{ kind = "CHARS", value = "item" },
	-- 			{ kind = "COLON", indent = 0 },
	-- 			{ kind = "CHARS", value = "Super Hoop" },
	-- 			{ kind = "CHARS", value = "quantity" },
	-- 			{ kind = "COLON", indent = 2 },
	-- 			{ kind = "CHARS", value = "1" },
	-- 			{ kind = "EINDENT", indent = 2 },
	-- 			{ kind = "DASH", indent = 0 },
	-- 			{ kind = "CHARS", value = "item" },
	-- 			{ kind = "COLON", indent = 0 },
	-- 			{ kind = "CHARS", value = "Basketball" },
	-- 			{ kind = "CHARS", value = "quantity" },
	-- 			{ kind = "COLON", indent = 2 },
	-- 			{ kind = "CHARS", value = "4" },
	-- 			{ kind = "EINDENT", indent = 2 },
	-- 			{ kind = "DASH", indent = 0 },
	-- 			{ kind = "CHARS", value = "item" },
	-- 			{ kind = "COLON", indent = 0 },
	-- 			{ kind = "CHARS", value = "Big Shoes" },
	-- 			{ kind = "CHARS", value = "quantity" },
	-- 			{ kind = "COLON", indent = 2 },
	-- 			{ kind = "CHARS", value = "1" },
	-- 			{ kind = "EINDENT", indent = 2 },
	-- 		}
	-- 		assert(lexer)
	-- 		assert.are.same(expect, lexer.tokens)
	-- 	end)
end)
