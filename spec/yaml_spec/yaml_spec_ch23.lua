local assert = require("luassert")
local yaml = require("yalua")

describe("2.3 Scalars", function()
	it("should parse example: #2.13 In literals, newlines are preserved", function()
		local text = [[
# ASCII Art
--- |
  \//||\/||
  // ||  ||__
]]
		local result = yaml.decode(text)
		assert.are.equal("\\//||\\/||\n// ||  ||__", result)
	end)

	it("should parse example: #2.14 In the folded scalars, newlines become spaces", function()
		local text = [[
--- >
  Mark McGwire's
  year was crippled
  by a knee injury.
]]
		local result = yaml.decode(text)
		assert.are.equal("Mark McGwire's year was crippled by a knee injury.", result)
	end)

	-- TODO
	-- 	it("should parse example: #2.15 Folded newlines are preserved for “more indented” and blank lines", function()
	-- 		local text = [[
	-- --- >
	--  Sammy Sosa completed another
	--  fine season with great stats.
	--
	--    63 Home Runs
	--    0.288 Batting Average
	--
	--  What a year!
	-- ]]
	-- 		local result = yaml.decode(text)
	-- 		assert.are.equal(
	-- 			"Sammy Sosa completed another fine season with great stats.\n\n  63 Home Runs\n  0.288 Batting Average\n\nWhat a year!",
	-- 			result
	-- 		)
	-- 	end)

	it("should parse example: #2.16 Indentation determines scope", function()
		local text = [[
name: Mark McGwire
accomplishment: >
  Mark set a major league
  home run record in 1998.
stats: |
  65 Home Runs
  0.278 Batting Average
]]
		local result = yaml.decode(text)
		assert.are.equal("Mark McGwire", result.name)
		assert.are.equal("Mark set a major league home run record in 1998.", result.accomplishment)
		assert.are.equal("65 Home Runs\n0.278 Batting Average", result.stats)
	end)

	-- TODO
	-- 	it("should parse example: #2.17 Quoted Scalars", function()
	-- 		local text = [[
	-- unicode: "Sosa did fine.\u263A"
	-- control: "\b1998\t1999\t2000\n"
	-- hex esc: "\x0d\x0a is \r\n"
	--
	-- single: '"Howdy!" he cried.'
	-- quoted: ' # Not a ''comment''.'
	-- tie-fighter: '|\-*-/|'
	-- ]]
	-- 		local result = yaml.decode(text)
	-- 		assert.are.equal("Sosa did fine.\u263A", result.unicode)
	-- 		assert.are.equal("\b1998\t1999\t2000\n", result.control)
	-- 		assert.are.equal("\r\n is \r\n", result["hex esc"])
	-- 		assert.are.equal('"Howdy!" he cried.', result.single)
	-- 		assert.are.equal(" # Not a 'comment'.", result.quoted)
	-- 		assert.are.equal("|-*-/", result.tie_fighter)
	-- 	end)

	-- TODO
	-- 	it("should parse example: #2.18 Multi-line Flow Scalars", function()
	-- 		local text = [[
	-- plain:
	--   This unquoted scalar
	--   spans many lines.
	--
	-- quoted: "So does this
	--   quoted scalar.\n"
	-- 	]]
	-- 		local result = yaml.decode(text)
	-- 		assert.are.equal("This unquoted scalar\nspans many lines.", result.plain)
	-- 		assert.are.equal("So does this\nquoted scalar.\n", result.quoted)
	-- 	end)
end)
