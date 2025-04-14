|              |    |
|--------------|----|
| Build Status | [![unittests](https://img.shields.io/github/actions/workflow/status/spielhuus/yalua/busted.yml?branch=main&style=for-the-badge&label=Unittests)](https://github.com/spielhuus/yalua/actions/workflows/test.yml) [![luacheck](https://img.shields.io/github/actions/workflow/status/spielhuus/yalua/luacheck.yml?branch=main&style=for-the-badge&label=Luacheck)](https://github.com/spielhuus/yalua/actions/workflows/luacheck.yml) [![llscheck](https://img.shields.io/github/actions/workflow/status/spielhuus/yalua/llscheck.yml?branch=main&style=for-the-badge&label=llscheck)](https://github.com/spielhuus/yalua/actions/workflows/llscheck.yml) |
| License      | [![License-MIT](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](https://github.com/spielhuus/yalua/blob/main/LICENSE)|

> [!IMPORTANT]
> This is a work in progress project

# Lua YAML parser

this is a pure lua implentation of a YAML parser. the yaml.lua file is self contained. 

```lua
list = {1, 2, 3, 4}
print(table.concat(list, ","))
table.insert(list, #list, 99)
print(table.concat(list, ","))
end)
```

```lua
a = false
b = " s"
c = "a\n"
if not a and (b == " " or c == "\n") then
    print("YEP")
else 
    print("NOPE")
end
```


```lua

str = "foo: bar\nfoz: baz"
print(string.match(str, "^([%w-]+)(:%s)", 1))
print(string.match(str, "^(:%s)", 1))
-- res = string.match(str, "^%d", 10)
-- print(res)

```


```py
import yaml

data = """
"text 
 line \
   line
"
"""

parsed = yaml.safe_load(data)

print(parsed)

```

```py
import yaml
data  = """
aaaabc: def # comment
"""
parsed = yaml.safe_load(data)
print(parsed)
```

```py
import yaml
data  = """
aaaabc def # comment
"""
parsed = yaml.safe_load(data)
print(parsed)
```

```py
import yaml
data  = """
aaaabc def # comment: value

"""
parsed = yaml.safe_load(data)
print(parsed)
```

```py
import yaml

data  = """
- # Empty
- |
 block node
- - one # Compact
  - two # sequence
- one: two # Compact mapping
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

