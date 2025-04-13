local assert = require("luassert")
local yaml = require("yalua")

-- tutorial at: https://spacelift.io/blog/yaml
describe("Test the YAML parser with the YAML tutorial", function()
	it("should parse #simple example", function()
		local Example1 = [[---
# key: value [mapping]
company: spacelift
# key: value is an array [sequence]
domain:
 - devops
 - devsecops
tutorial:
  - yaml:
      name: "YAML Ain't Markup Language" #string [literal]
      type: awesome #string [literal]
      born: 2001 #number [literal]
  - json:
      name: JavaScript Object Notation #string [literal]
      type: great #string [literal]
      born: 2001 #number [literal]
  - xml:
      name: Extensible Markup Language #string [literal]
      type: good #string [literal]
      born: 1996 #number [literal]
author: omkarbirade
published: true
]]
		local expected = {
			company = "spacelift",
			domain = { "devops", "devsecops" },
			tutorial = {
				{
					yaml = {
						name = "YAML Ain't Markup Language",
						type = "awesome",
						born = 2001,
					},
				},
				{
					json = {
						name = "JavaScript Object Notation",
						type = "great",
						born = 2001,
					},
				},
				{
					xml = {
						name = "Extensible Markup Language",
						type = "good",
						born = 1996,
					},
				},
			},
			author = "omkarbirade",
			published = true,
		}
		print(yaml.stream(Example1))
	end)

	it("should parse simple example", function()
		local Example1 = [[---
# key: value [mapping]
company: spacelift
# key: value is an array [sequence]
domain:
 - devops
 - devsecops
tutorial:
  - yaml:
      name: "YAML Ain't Markup Language" #string [literal]
      type: awesome #string [literal]
      born: 2001 #number [literal]
  - json:
      name: JavaScript Object Notation #string [literal]
      type: great #string [literal]
      born: 2001 #number [literal]
  - xml:
      name: Extensible Markup Language #string [literal]
      type: good #string [literal]
      born: 1996 #number [literal]
author: omkarbirade
published: true]]
		local expected = {
			company = "spacelift",
			domain = { "devops", "devsecops" },
			tutorial = {
				{
					yaml = {
						name = "YAML Ain't Markup Language",
						type = "awesome",
						born = 2001,
					},
				},
				{
					json = {
						name = "JavaScript Object Notation",
						type = "great",
						born = 2001,
					},
				},
				{
					xml = {
						name = "Extensible Markup Language",
						type = "good",
						born = 1996,
					},
				},
			},
			author = "omkarbirade",
			published = true,
		}
		local result = yaml.decode(Example1)
		assert.same(expected, result)
	end)
end)
