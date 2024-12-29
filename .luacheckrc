-- Only allow symbols available in all Lua versions
std = "min"

-- Get rid of "unused argument self"-warnings
self = false

-- The unit tests can use busted
files["spec"].std = "+busted"

-- The default config may set global variables
-- files["awesomerc.lua"].allow_defined_top = true

-- This file itself
files[".luacheckrc"].ignore = { "111", "112", "131" }

-- Theme files, ignore max line length
files["spec/*"].ignore = { "631" }

exclude_files = {
	".luarocks",
}
-- Global objects defined by the C code
-- read_globals = {
-- 	"vim",
-- }
