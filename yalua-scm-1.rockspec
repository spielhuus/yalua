rockspec_format = "3.0"
package = "yalua"
version = "scm-1"

dependencies = {
  "lua >= 5.1",
}

test_dependencies = {
  "lua >= 5.1",
  "luacheck",
  "luassert",
  "busted",
  "dkjson",
  "busted-htest",
  "luacov",
  "luacov-reporter-lcov",
  "llscheck",
}

source = {
  url = "git://github.com/spielhuus/" .. package,
}

build = {
  type = "builtin",
  modules = {
    ["yalua"] = "yalua.lua",
  },
}
