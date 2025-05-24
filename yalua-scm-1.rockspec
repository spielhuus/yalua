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
	"rapidjson",
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
		["Lexer"] = "Lexer.lua",
		["Parser"] = "Parser.lua",
		["str"] = "str.lua",
		["StringIterator"] = "StringIterator.lua",
		["yalua"] = "yalua.lua",
	},
}
