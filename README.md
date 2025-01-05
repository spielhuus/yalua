|              |    |
|--------------|----|
| Build Status | [![unittests](https://img.shields.io/github/actions/workflow/status/spielhuus/yalua/busted.yml?branch=main&style=for-the-badge&label=Unittests)](https://github.com/spielhuus/yalua/actions/workflows/test.yml)  [![documentation](https://img.shields.io/github/actions/workflow/status/spielhuus/yalua/documentation.yml?branch=main&style=for-the-badge&label=Documentation)](https://github.com/spielhuus/yalua/actions/workflows/documentation.yml) [![luacheck](https://img.shields.io/github/actions/workflow/status/spielhuus/yalua/luacheck.yml?branch=main&style=for-the-badge&label=Luacheck)](https://github.com/spielhuus/yalua/actions/workflows/luacheck.yml) [![llscheck](https://img.shields.io/github/actions/workflow/status/spielhuus/yalua/llscheck.yml?branch=main&style=for-the-badge&label=llscheck)](https://github.com/spielhuus/yalua/actions/workflows/llscheck.yml) |
| License      | [![License-MIT](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](https://github.com/spielhuus/yalua/blob/main/LICENSE)|

> [!IMPORTANT]
> This is a work in progress project

# Lua YAML parser

this is a pure lua implentation of a YAML parser. the yaml.lua file is self contained. 

```lua
chars = {1, 2, 3, 4, 5, 6}
print(table.concat(chars, ",", 4))
```

```py
import yaml

data = """
provider:
  model: qwen2.5-coder: 7b-instruct-q8_0
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
  num_ctx: 4096
"""
parsed = yaml.safe_load(data)
print(parsed)

```

# Installation

install it from source using luarocks:

```sh
git clone http://github.com/spielhuus/yaml.lua.git
cd yaml.lya

# install to the user tree
luarocks make --lua-version=5.1 --tree .luarocks
# install to a local tree
luarocks make --lua-version=5.1 --tree .luarocks
```

alternatively you can just copy the yaml.lua to a local tree.

# Usage



# Examples



```lua
yaml = require("yaml")
str = require("str")

Example23 = [[american: hurray
germans: kraut]]
print(str.to_string(yaml.decode(Example23)))
```

# Development

run test thest suite

```sh
make test
```

or run it directly with busted

```sh
eval $(luarocks path --lua-version 5.1 --tree .luarocks --bin)
busted
#select a test by tag
busted --tags "2.10"
```


# License

