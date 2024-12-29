rockspec_format = "3.0"
package = "yaml"
version = "scm-1"

dependencies = {
	"lua >= 5.1",
}

test_dependencies = {
	"lua >= 5.1",
	"luacheck",
	"luassert",
	"busted",
}

source = {
	url = "git://github.com/spielhuus/" .. package,
}
