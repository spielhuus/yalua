local assert = require("luassert")
local yaml = require("yaml")

describe("2.2 Structures", function()
	it("should parse example: #2.7 Two Documents in a Stream (each with a leading comment)", function()
		local text = [[# Ranking of 1998 home runs 
--- 
- Mark McGwire 
- Sammy Sosa 
- Ken Griffey 
 
# Team ranking 
--- 
- Chicago Cubs 
- St Louis Cardinals]]
		local result = yaml.decode(text)
		assert.are.same(
			{ { "Mark McGwire", "Sammy Sosa", "Ken Griffey" }, { "Chicago Cubs", "St Louis Cardinals" } },
			result
		)
	end)

	it("should parse example: #2.8 Play by Play Feed from a Game", function()
		local text = [[--- 
time: 20:03:20 
player: Sammy Sosa 
action: strike (miss) 
... 
--- 
time: 20:03:47 
player: Sammy Sosa 
action: grand slam]]
		local result = yaml.decode(text)
		assert.are.same({
			{ time = "20:03:20", player = "Sammy Sosa", action = "strike (miss)" },
			{ time = "20:03:47", player = "Sammy Sosa", action = "grand slam" },
		}, result)
	end)

	it("should parse example: #2.9 Single Document with Two Comments", function()
		local text = [[--- 
hr: # 1998 hr ranking 
- Mark McGwire 
- Sammy Sosa 
# 1998 rbi ranking 
rbi: 
- Sammy Sosa 
- Ken Griffey]]
		local result = yaml.decode(text)
		assert.are.same({ hr = { "Mark McGwire", "Sammy Sosa" }, rbi = { "Sammy Sosa", "Ken Griffey" } }, result)
	end)

	it("should parse example: #2.10 Node for “Sammy Sosa” appears twice in this document", function()
		local text = [[---
hr:
- Mark McGwire
# Following node labeled SS
- &SS Sammy Sosa
rbi:
- *SS # Subsequent occurrence
- Ken Griffey]]
		local result = yaml.decode(text)
		assert.are.same({ hr = { "Mark McGwire", "Sammy Sosa" }, rbi = { "Sammy Sosa", "Ken Griffey" } }, result)
	end)

	-- 	it("should parse example: #2.11 Mapping between Sequences", function()
	-- 		local text = [[? - Detroit Tigers
	--   - Chicago cubs
	-- : - 2001-07-23
	--
	-- ? [ New York Yankees,
	--     Atlanta Braves ]
	-- : [ 2001-07-02, 2001-08-12,
	--     2001-08-14 ] ]]
	-- 		local result = yaml.decode(text)
	-- 		assert.are.same({ { "Detroit Tigers", "Chicago cubs" }, { "New York Yankees", "Atlanta Braves" } }, result)
	-- 	end)

	-- 	it("should parse example: #2.12 Compact Nested Mapping", function()
	-- 		local text = [[---
	-- # Products purchased
	-- - item    : Super Hoop
	--   quantity: 1
	-- - item    : Basketball
	--   quantity: 4
	-- - item    : Big Shoes
	--   quantity: 1]]
	-- 		local result = yaml.decode(text)
	-- 		assert.are.same({
	-- 			{ item = "Super Hoop", quantity = 1 },
	-- 			{ item = "Basketball", quantity = 4 },
	-- 			{
	-- 				item = "Big Shoes",
	-- 				quantity = 1,
	-- 			},
	-- 		}, result)
	-- 	end)
end)
