#!/usr/bin/env luajit
---lua build file

local yalua = require("yalua")

PATH_SUITE = "spec/suite"
PATH_SUITE = "yaml_test_suite"
TEST_SUITE = "https://github.com/yaml/yaml-test-suite.git"

local function get_files_in_directory(directory)
	local files = {}
	for file in io.popen("ls " .. directory):lines() do
		table.insert(files, file)
	end
	return files
end

local function dir_exists(path)
	local file = io.open(path, "r")
	if file then
		file:close()
		return true
	else
		return false
	end
end

function get_file_content(path)
	local file = io.open(path, "r")
	if not file then
		return nil, "can not open file " .. path
	end
	local content = file:read("*all")
	file:close()
	return content
end

---write a table with text lines to a file
---@param path string the output file path
---@param data table[string]
local function write(path, data)
	local file = io.open(path, "w")
	if file then
		for _, line in ipairs(data) do
			file:write(line .. "\n")
		end
		file:close()
	else
		error("Could not open file for writing: " .. path)
	end
end

---split a string by words and prefix each word with a hash
---@param str any
local function prefix_hash(str)
	print("prefix: " .. (str or "nil"))
	local words = {}
	for word in str:gmatch("%S+") do
		table.insert(words, "#" .. word)
	end
	return table.concat(words, " ")
end

local function spec_tree(data)
	local result = {}
	table.insert(result, 'local assert = require("luassert")\n')
	table.insert(result, 'local yalua = require("yalua")\n')

	table.insert(result, "\nlocal function load_file(file_path)\n")
	table.insert(result, '    local file = io.open(file_path, "r")\n')
	table.insert(result, "    if not file then\n")
	table.insert(result, '        return nil, "File not found"\n')
	table.insert(result, "    end\n")
	table.insert(result, '    local content = file:read("*all")\n')
	table.insert(result, "    file:close()\n")
	table.insert(result, "    return content\n")
	table.insert(result, "end\n\n")

	table.insert(result, "local function remove_trailing_spaces(str)\n")
	table.insert(result, '  return str:gsub("^%s+", "")\n')
	table.insert(result, "end\n")
	table.insert(result, "\n")
	table.insert(result, "local function remove_all_trailing_spaces(multiline_str)\n")
	table.insert(result, "  local lines = {}\n")
	table.insert(result, '  for line in multiline_str:gmatch("[^\\r\\n]+") do\n')
	table.insert(result, "    local res = remove_trailing_spaces(line)\n")
	table.insert(result, "    table.insert(lines, res)\n")
	table.insert(result, "  end\n")
	table.insert(result, '  table.insert(lines, "")')
	table.insert(result, '  return table.concat(lines, "\\n")\n')
	table.insert(result, "end\n\n")

	table.insert(result, 'describe("Run the YAML test #suite, compare with TREE", function()\n')
	for i, testfile in ipairs(data) do
		print("TEST: " .. i .. " " .. testfile["file"])
		local test_nr = 0
		local name, the_yaml, tags
		for _, test in ipairs(testfile) do
			print(require("str").to_string(test))
			name = test["name"]
			tags = prefix_hash(test["tags"] or tags)
			local filename = test["file"]
			file = test["file"]
			the_yaml = test["yaml"]
			if #testfile > 1 then
				file = string.format("{%s}/{%d:02d}", file, test_nr)
				the_yaml = string.format("%s/%s:02d", the_yaml, test_nr)
			end
			local fail = test["fail"] and true or false
			local tree = test["tree"]
			table.insert(
				result,
				string.format(
					'  it("should parse the {escape(name)}, file: #%s tags: %s", function()\n',
					filename,
					tags
				)
			)
			table.insert(result, string.format('    print("### should parse the %s, file: #%s")\n', name, filename))
			table.insert(result, string.format('    local input = load_file("{temp_dir}/data/{file}/in.yaml")\n'))
			-- if fail:
			--     f.write("    local result = yalua.stream(input)\n")
			--     f.write("    assert.Equal(nil, result)\n")
			--     f.write(f"  end)\n")
			-- else:
			--     f.write(
			--         f'    local tree = load_file("{temp_dir}/data/{file}/test.event")\n'
			--     )
			--     f.write("    local result = yalua.stream(input)\n")
			--     f.write(
			--         "    assert.is.Same(tree, remove_all_trailing_spaces(result))\n"
			--     )
			--     f.write(f"  end)\n")

			test_nr = test_nr + 1
		end
		table.insert(result, "end)\n\n")
	end
	write("spec/suite/tree_spec.lua", result)
end

local function prepare_suite()
	if not dir_exists(PATH_SUITE) then
		os.execute("git clone " .. TEST_SUITE .. " " .. PATH_SUITE)
		os.execute("make -C " .. PATH_SUITE .. " data")
	end
	-- read all the test files
	local data = {}
	for _, file in ipairs(get_files_in_directory(string.format("%s/src", PATH_SUITE))) do
		local filename = string.format("%s/src/%s", PATH_SUITE, file)
		print("Process file: " .. filename)
		local test, mes = yalua.parse(filename)
		if not test then
			error("[ERROR] Can not load thestfile: " .. file .. " " .. mes)
		end
		print(string.format("Parse: %s: %s", file, test[1].name))
		test["file"] = file
		table.insert(data, test)
	end
	spec_tree(data)
end

local function suite()
	prepare_suite()
end

local function clean()
	os.execute("rm -rf " .. PATH_SUITE)
end

local function test()
	if os.execute("busted spec/test") ~= 0 then
		error("test suite did not run successfully")
	end
end

local function check()
	if os.execute("luacheck StringIterator.lua Lexer.lua Parser.lua") ~= 0 then
		error("luacheck did not run successfully")
	end
end

local function is_main(_arg, ...)
	local n_arg = _arg and #_arg or 0
	if n_arg == select("#", ...) then
		for i = 1, n_arg do
			if _arg[i] ~= select(i, ...) then
				return false
			end
		end
		return true
	end
	return false
end

if is_main(arg, ...) then
	print("yalua build: " .. table.concat(arg, ", "))
	if arg[1] == "test" then
		return test()
	elseif arg[1] == "check" then
		check()
	elseif arg[1] == "suite" then
		suite()
	elseif arg[1] == "clean" then
		clean()
	elseif arg[1] == "dump" then
		if not arg[2] then
			error("no filename for dump.")
		end
		local iter = require("StringIterator"):new(get_file_content(arg[2]))
		local lexer, mes = require("Lexer"):new(iter)
		if not lexer then
			print(mes)
		else
			print(tostring(lexer))
		end
	end
else
	error("build.lua can not be used as library")
end
