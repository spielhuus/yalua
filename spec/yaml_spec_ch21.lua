local assert = require("luassert")
local yaml = require("yaml")

describe("2.1 Collections", function()
	it("should parse example: #2.1 Sequence of Scalars (ball players)", function()
		local text = [[
- Mark McGwire
- Sammy Sosa
- Ken Griffey
]]
		local result = yaml.decode(text)
		assert.are.same({ "Mark McGwire", "Sammy Sosa", "Ken Griffey" }, result)
	end)

	it("should parse example: #2.2 Mapping Scalars to Scalars (player statistics)", function()
		local text = [[
hr:  65    # Home runs
avg: 0.278 # Batting average
rbi: 147   # Runs Batted In
]]
		local result = yaml.decode(text)
		assert.are.same({ hr = 65, avg = 0.278, rbi = 147 }, result)
	end)

	it("should parse example: #2.3 Mapping Scalars to Sequences (ball clubs in each league)", function()
		local text = [[
american:
- Boston Red Sox
- Detroit Tigers
- New York Yankees
national:
- New York Mets
- Chicago Cubs
- Atlanta Braves
]]
		local result = yaml.decode(text)
		assert.are.same({
			american = { "Boston Red Sox", "Detroit Tigers", "New York Yankees" },
			national = { "New York Mets", "Chicago Cubs", "Atlanta Braves" },
		}, result)
	end)

	it("should parse example: #2.4 Sequence of Mappings (players’ statistics)", function()
		local text = [[
-
  name: Mark McGwire
  hr:   65
  avg:  0.278
-
  name: Sammy Sosa
  hr:   63
  avg:  0.288
]]
		local result = yaml.decode(text)
		assert.are.same({
			{ name = "Mark McGwire", hr = 65, avg = 0.278 },
			{ name = "Sammy Sosa", hr = 63, avg = 0.288 },
		}, result)
	end)

	it("should parse example: #2.5 Sequence of Sequences", function()
		local text = [[
- [name        , hr, avg  ]
- [Mark McGwire, 65, 0.278]
- [Sammy Sosa  , 63, 0.288]
]]
		local result = yaml.decode(text)
		assert.are.same({
			{ "name", "hr", "avg" },
			{ "Mark McGwire", 65, 0.278 },
			{ "Sammy Sosa", 63, 0.288 },
		}, result)
	end)

	it("should parse example: #2.6 Mapping of Mappings", function()
		local text = [[
Mark McGwire: {hr: 65, avg: 0.278}
Sammy Sosa: {
    hr: 63,
    avg: 0.288,
 }
]]
		local result = yaml.decode(text)
		assert.are.same({
			["Mark McGwire"] = { hr = 65, avg = 0.278 },
			["Sammy Sosa"] = { hr = 63, avg = 0.288 },
		}, result)
	end)
end)
