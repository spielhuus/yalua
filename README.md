

> [!IMPORTANT]
> This is a work in progress project

# Lua YAML parser

this is a pure lua implentation of a YAML parser. the yaml.lua file is self contained. 


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


# License

