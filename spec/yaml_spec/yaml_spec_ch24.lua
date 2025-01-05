local assert = require("luassert")
local yaml = require("yalua")

describe("2.4 Tags", function()
	it("should parse example: #2.19 Integers", function()
		local text = [[ 
canonical: 12345 
decimal: +12345 
octal: 0o14 
hexadecimal: 0xC 
]]
		local result = yaml.decode(text)
		assert.are.equal(12345, result.canonical)
		assert.are.equal(12345, result.decimal)
		assert.are.equal(12, result.octal)
		assert.are.equal(12, result.hexadecimal)
	end)

	it("should parse example: #2.20 Floating Point", function()
		local text = [[ 
canonical: 1.23015e+3 
exponential: 12.3015e+02 
fixed: 1230.15 
negative infinity: -.inf 
not a number: .nan 
]]
		local result = yaml.decode(text)
		assert.are.equal(1230.15, result.canonical)
		assert.are.equal(1230.15, result.exponential)
		assert.are.equal(1230.15, result.fixed)
		assert.is_true(math.huge == -result["negative infinity"])
		assert.is_true(math.isnan(result["not a number"]))
	end)

	it("should parse example: #2.21 Miscellaneous", function()
		local text = [[ 
null: 
booleans: [ true, false ] 
string: '012345' 
]]
		local result = yaml.decode(text)
		assert.is_nil(result.null)
		assert.are.same({ true, false }, result.booleans)
		assert.are.equal("012345", result.string)
	end)

	it("should parse example: #2.22 Timestamps", function()
		local text = [[ 
canonical: 2001-12-15T02:59:43.1Z 
iso8601: 2001-12-14t21:59:43.10-05:00 
spaced: 2001-12-14 21:59:43.10 -5 
date: 2002-12-14 
]]
		local result = yaml.decode(text)
		assert.are.equal("2001-12-15T02:59:43.1Z", result.canonical)
		assert.are.equal("2001-12-14t21:59:43.10-05:00", result.iso8601)
		assert.are.equal("2001-12-14 21:59:43.10 -5", result.spaced)
		assert.are.equal("2002-12-14", result.date)
	end)

	it("should parse example: #2.23 Various Explicit Tags", function()
		local text = [[ 
--- 
not-date: !!str 2002-04-28 
 
picture: !!binary | 
 R0lGODlhDAAMAIQAAP//9/X 
 17unp5WZmZgAAAOfn515eXv 
 Pz7Y6OjuDg4J+fn5OTk6enp 
 56enmleECcgggoBADs= 
 
application specific tag: !something | 
 The semantics of the tag 
 above may be different for 
 different documents. 
]]
		local result = yaml.decode(text)
		assert.are.equal("2002-04-28", result["not-date"])
		assert.is_true(type(result.picture) == "string")
		assert.is_true(type(result["application specific tag"]) == "string")
	end)

	it("should parse example: #2.24 Global Tags", function()
		local text = [[ 
%TAG ! tag:clarkevans.com,2002: 
--- !shape 
  # Use the ! handle for presenting 
  # tag:clarkevans.com,2002:circle 
- !circle 
  center: &ORIGIN {x: 73, y: 129} 
  radius: 7 
- !line 
  start: *ORIGIN 
  finish: { x: 89, y: 102 } 
- !label 
  start: *ORIGIN 
  color: 0xFFEEBB 
  text: Pretty vector drawing. 
]]
		local result = yaml.decode(text)
		assert.is_true(type(result) == "table")
	end)

	it("should parse example: #2.25 Unordered Sets", function()
		local text = [[ 
# Sets are represented as a 
# Mapping where each key is 
# associated with a null value 
--- !!set 
? Mark McGwire 
? Sammy Sosa 
? Ken Griffey 
]]
		local result = yaml.decode(text)
		assert.is_true(result["Mark McGwire"])
		assert.is_true(result["Sammy Sosa"])
		assert.is_true(result["Ken Griffey"])
	end)

	it("should parse example: #2.26 Ordered Mappings", function()
		local text = [[ 
# Ordered maps are represented as 
# A sequence of mappings, with 
# each mapping having one key 
--- !!omap 
- Mark McGwire: 65 
- Sammy Sosa: 63 
- Ken Griffey: 58 
]]
		local result = yaml.decode(text)
		assert.are.equal(65, result[1]["Mark McGwire"])
		assert.are.equal(63, result[2]["Sammy Sosa"])
		assert.are.equal(58, result[3]["Ken Griffey"])
	end)
end)
