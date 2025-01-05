local assert = require("luassert")
local yalua = require("yalua")

describe("Test the YAML LLM promopts", function()
	it("it should parse a plain json file", function()
		local json = [[{
  "user": {
    "name": "John Doe",
    "email": "john.doe@example.com"
  },
  "password": "secret123",
  "credit_card": {
    "number": "4111111111111111",
    "expiry_date": "12/25",
    "cvv": "123"
  }
}]]
		local expect = {
			user = {
				name = "John Doe",
				email = "john.doe@example.com",
			},
			password = "secret123",
			credit_card = {
				number = "4111111111111111",
				expiry_date = "12/25",
				cvv = "123",
			},
		}
		local res = yalua.decode(json)
		assert.is.Same(expect, res)
	end)
	it("it should parse a plain json array", function()
		local json = [[
[
    "item1",
    "item2",
    "item3"
]
}]]
		local expect = { "item1", "item2", "item3" }
		local res = yalua.decode(json)
		assert.is.Same(expect, res)
	end)
end)
