local assert = require("luassert")
local Lexer = require("Lexer")
local Parser = require("Parser")
local StringIterator = require("StringIterator")

describe("Test the Parser", function()
	-- Helper function to reduce boilerplate
	local function parse_yaml(yaml_string)
		local iter = StringIterator:new(yaml_string)
		local lexer = Lexer:new(iter)
		assert(lexer, "Lexer creation failed")
		local parser = Parser:new(lexer)
		assert(parser, "Parser creation failed")
		-- Check for parsing errors if your parser has an error state
		-- assert.is_nil(parser.error, "Parsing generated an error: " .. tostring(parser.error))
		return parser.result
	end

	it("should parse a simple block sequence", function()
		local doc = [[ 
--- 
- item 1 
- item 2 
- item 3 
]]
		local expect = { "item 1", "item 2", "item 3" }
		assert.are.same(expect, parse_yaml(doc))
	end)

	it("should parse a simple block map", function()
		local doc = [[ 
--- 
key1: value 1 
key2: value 2 
another_key: Another Value 
]]
		local expect = {
			key1 = "value 1",
			key2 = "value 2",
			another_key = "Another Value",
		}
		assert.are.same(expect, parse_yaml(doc))
	end)

	it("should parse a nested block sequence", function()
		local doc = [[ 
--- 
- item 1 
- 
  - nested 1 
  - nested 2 
- item 3 
- 
  - nested 3 
  - 
    - double nested 1 
    - double nested 2 
]]
		local expect = {
			"item 1",
			{ "nested 1", "nested 2" },
			"item 3",
			{ "nested 3", { "double nested 1", "double nested 2" } },
		}
		assert.are.same(expect, parse_yaml(doc))
	end)

	it("should parse a nested block map", function()
		local doc = [[ 
--- 
level1_key1: value1 
level1_key2: 
  level2_key1: nested value 1 
  level2_key2: nested value 2 
level1_key3: 
  level2_another: 
    level3_key: deep value 
]]
		local expect = {
			level1_key1 = "value1",
			level1_key2 = {
				level2_key1 = "nested value 1",
				level2_key2 = "nested value 2",
			},
			level1_key3 = {
				level2_another = {
					level3_key = "deep value",
				},
			},
		}
		assert.are.same(expect, parse_yaml(doc))
	end)

	it("should parse a sequence containing maps", function()
		local doc = [[ 
--- 
- simple item 
- key1: value1 
  key2: value2 
- another simple item 
- name: Alice 
  age: 30 
]]
		local expect = {
			"simple item",
			{ key1 = "value1", key2 = "value2" },
			"another simple item",
			{ name = "Alice", age = 30 }, -- Assuming your parser handles numbers
		}
		assert.are.same(expect, parse_yaml(doc))
	end)

	it("should parse a map containing sequences", function()
		local doc = [[ 
--- 
config_name: main 
items: 
  - item 1 
  - item 2 
  - item 3 
users: 
  - user A 
  - user B 
enabled: true # Assuming your parser handles booleans 
]]
		local expect = {
			config_name = "main",
			items = { "item 1", "item 2", "item 3" },
			users = { "user A", "user B" },
			enabled = true,
		}
		assert.are.same(expect, parse_yaml(doc))
	end)

	it("should parse a flow sequence", function()
		local doc = [[ 
--- 
[flow item 1, flow item 2, flow item 3]
]]
		local expect = { "flow item 1", "flow item 2", "flow item 3" }
		assert.are.same(expect, parse_yaml(doc))
	end)

	it("should parse a flow map", function()
		local doc = [[ 
--- 
{ key1: val1, key2: val2, number: 123 }
]]
		local expect = { key1 = "val1", key2 = "val2", number = 123 }
		assert.are.same(expect, parse_yaml(doc))
	end)

	it("should parse mixed flow and block styles (map with flow sequence)", function()
		local doc = [[ 
--- 
options: [opt1, opt2, opt3] 
settings: 
  mode: active 
]]
		local expect = {
			options = { "opt1", "opt2", "opt3" },
			settings = { mode = "active" },
		}
		assert.are.same(expect, parse_yaml(doc))
	end)

	it("should parse mixed flow and block styles (sequence with flow map)", function()
		local doc = [[ 
--- 
- { name: itemA, value: 10 }
- name: itemB # Block map element
  value: 20
- { name: itemC, value: 30, tags: [tag1, tag2] } # Flow map with flow sequence
]]
		local expect = {
			{ name = "itemA", value = 10 },
			{ name = "itemB", value = 20 },
			{ name = "itemC", value = 30, tags = { "tag1", "tag2" } },
		}
		assert.are.same(expect, parse_yaml(doc))
	end)

	it("should parse an empty block sequence", function()
		-- An empty sequence in block style might be represented in different ways.
		-- Option 1: Explicit empty sequence node (less common standalone)
		-- Option 2: A key with no sequence items below it (effectively null or empty)
		-- Let's test a key mapping to an explicitly empty flow sequence
		local doc = [[ 
--- 
empty_list: [] 
]]
		local expect = { empty_list = {} }
		assert.are.same(expect, parse_yaml(doc))
		-- Alternative: Empty flow sequence as the root document
		local doc2 = [[ 
--- 
[] 
]]
		local expect2 = {}
		assert.are.same(expect2, parse_yaml(doc2))
	end)

	it("should parse an empty block map", function()
		-- Similar ambiguity as empty sequence for block style.
		-- Let's test a key mapping to an explicitly empty flow map
		local doc = [[ 
--- 
empty_map: {} 
]]
		local expect = { empty_map = {} }
		assert.are.same(expect, parse_yaml(doc))
		-- Alternative: Empty flow map as the root document
		local doc2 = [[ 
--- 
{} 
]]
		local expect2 = {}
		assert.are.same(expect2, parse_yaml(doc2))
	end)

	-- 	it("should parse #map with various scalar types", function()
	-- 		local doc = [[
	-- ---
	-- a_string: Hello World
	-- an_integer: 12345
	-- a_float: 3.14159
	-- a_boolean_true: true
	-- a_boolean_false: false
	-- a_null: null # Note: Lua 'nil' might be the target representation
	-- ]]
	-- 		local expect = {
	-- 			a_string = "Hello World",
	-- 			an_integer = 12345,
	-- 			a_float = 3.14159,
	-- 			a_boolean_true = true,
	-- 			a_boolean_false = false,
	-- 			a_null = nil, -- Or a specific null sentinel if your parser uses one
	-- 			-- e.g., cjson.null, ngx.null, or a custom object.
	-- 			-- 'nil' means the key might not exist in the resulting table.
	-- 			-- If 'a_null' should exist with a null value, use the appropriate sentinel.
	-- 		}
	-- 		-- Use are.equivalent for tables containing nil if 'nil' means key absence
	-- 		-- Use are.same if 'a_null' should exist and map to a specific null sentinel object
	-- 		assert.are.same(expect, parse_yaml(doc))
	-- 	end)
end)
