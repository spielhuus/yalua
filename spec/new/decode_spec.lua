local assert = require("luassert")
local yalua = require("yalua")

describe("Parse the simple data structure", function()
	it("should parse simple collection", function()
		local input = [[
- item list 1
- item list 2
]]
		local expect = { "item list 1", "item list 2" }
		local res = yalua.decode(input)
		assert.is.Same(expect, res)
	end)

	it("should parse testsuite file", function()
		local input = [[
---
- name: Spec Example 2.4. Sequence of Mappings
  from: http://www.yaml.org/spec/1.2/spec.html#id2760193
  tags: sequence mapping spec
  yaml: |
    -
      name: Mark McGwire
      hr:   65
      avg:  0.278
    -
      name: Sammy Sosa
      hr:   63
      avg:  0.288
  tree: |
    +STR
     +DOC
      +SEQ
       +MAP
        =VAL :name
        =VAL :Mark McGwire
        =VAL :hr
        =VAL :65
        =VAL :avg
        =VAL :0.278
       -MAP
       +MAP
        =VAL :name
        =VAL :Sammy Sosa
        =VAL :hr
        =VAL :63
        =VAL :avg
        =VAL :0.288
       -MAP
      -SEQ
     -DOC
    -STR
  json: |
    [
      {
        "name": "Mark McGwire",
        "hr": 65,
        "avg": 0.278
      },
      {
        "name": "Sammy Sosa",
        "hr": 63,
        "avg": 0.288
      }
    ]
  dump: |
    - name: Mark McGwire
      hr: 65
      avg: 0.278
    - name: Sammy Sosa
      hr: 63
      avg: 0.288
]]
		local expect = {
			{
				name = "Spec Example 2.4. Sequence of Mappings",
				from = "http://www.yaml.org/spec/1.2/spec.html#id2760193",
				tags = "sequence mapping spec",
				yaml = [[
-
  name: Mark McGwire
  hr:   65
  avg:  0.278
-
  name: Sammy Sosa
  hr:   63
  avg:  0.288
]],
				tree = [[+STR
 +DOC
  +SEQ
   +MAP
    =VAL :name
    =VAL :Mark McGwire
    =VAL :hr
    =VAL :65
    =VAL :avg
    =VAL :0.278
   -MAP
   +MAP
    =VAL :name
    =VAL :Sammy Sosa
    =VAL :hr
    =VAL :63
    =VAL :avg
    =VAL :0.288
   -MAP
  -SEQ
 -DOC
-STR
]],
				json = '[\n  {\n    "name": "Mark McGwire",\n    "hr": 65,\n    "avg": 0.278\n  },\n  {\n    "name": "Sammy Sosa",\n    "hr": 63,\n    "avg": 0.288\n  }\n]\n',
				dump = [[
- name: Mark McGwire
  hr: 65
  avg: 0.278
- name: Sammy Sosa
  hr: 63
  avg: 0.288
]],
			},
		}

		assert.is.Same(expect, yalua.decode(input))
	end)
end)
