local assert = require("luassert")
local yaml = require("yalua")

describe("Test the YAML LLM promopts", function()
	it("it should parse the lua prompt", function()
		local prompt = [[provider:
  model: qwen2.5-coder:7b-instruct-q8_0
  name: Ollama
stream: true
name: Lua
icon:
  character: 󰢱
  highlight: DevIconBlueprint
system_prompt: |
  You are a senior Lua programmer specializing in Neovim plugins.
  Only answer the users question. be precise and concise.
  Do not add any examples, usages, outputs and for sure no introduction.
context: |
  return function(buf, line1, line2)
    local code = ""
    if line2 > line1 then
        code = require("lungan.utils").GetBlock(buf, line1, line2)
    end
    return {
            code = code
    }
  end
preview: return function(args, data) require("lungan.nvim.diff").preview(args, data) end
options:
  temperature: 0.01
  num_ctx: 4096]]

		local expect = {
			provider = {
				model = "qwen2.5-coder:7b-instruct-q8_0",
				name = "Ollama",
			},
			stream = true,
			name = "Lua",
			icon = {
				character = "󰢱",
				highlight = "DevIconBlueprint",
			},
			system_prompt = [[You are a senior Lua programmer specializing in Neovim plugins.
Only answer the users question. be precise and concise.
Do not add any examples, usages, outputs and for sure no introduction.]],
			context = [[return function(buf, line1, line2)
  local code = ""
  if line2 > line1 then
      code = require("lungan.utils").GetBlock(buf, line1, line2)
  end
  return {
          code = code
  }
end]],
			preview = 'return function(args, data) require("lungan.nvim.diff").preview(args, data) end',
			options = {
				temperature = 0.01,
				num_ctx = 4096,
			},
		}
		assert.same(expect, yaml.decode(prompt))
	end)
end)
