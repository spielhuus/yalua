#!/usr/bin/env luajit

---lua build file

local yalua = require("yalua")

PATH_SUITE = "yaml-test-suite"
TEST_SUITE = "https://github.com/yaml/yaml-test-suite.git"
PATH_TESTS = "spec/suite"

local function get_files_in_directory(directory)
	local files = {}
	for file in io.popen("ls " .. directory):lines() do
		table.insert(files, file)
	end
	return files
end

--escape the double quotes in the string
--@param str string
--@return string
local function escape(str)
	if not str then
		return ""
	else
		return (str:gsub('"', '\\"'))
	end
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

local function get_file_content(path)
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
	local words = {}
	for word in str:gmatch("%S+") do
		table.insert(words, "#" .. word)
	end
	return table.concat(words, " ")
end

local function remove_extension(file)
	return file:match("(.+)%.%w+$") or file
end

local function spec_tree(data)
	local total_tests, total_fails, total_skip = 0, 0, 0
	if not dir_exists(PATH_TESTS) then
		print("[RUN] mkdir " .. PATH_TESTS)
		os.execute("mkdir " .. PATH_TESTS)
	end
	local result = {}
	table.insert(result, 'local assert = require("luassert")')
	table.insert(result, 'local yalua = require("yalua")')
	table.insert(result, "")
	table.insert(result, 'describe("Run the YAML test #suite, compare with test.event", function()\n')
	table.insert(result, "  local function load_file(file_path)")
	table.insert(result, '    local file = io.open(file_path, "r")')
	table.insert(result, "    if not file then")
	table.insert(result, '        return nil, "File not found"')
	table.insert(result, "    end")
	table.insert(result, '    local content = file:read("*all")')
	table.insert(result, "    file:close()")
	table.insert(result, "    return content")
	table.insert(result, "  end")
	for i, testfile in ipairs(data) do
		local test_nr = 0
		local name, the_yaml, tags
		local filename = testfile["file"]
		local skip = false
		for _, test in ipairs(testfile) do
			name = (test["name"] and test["name"] or name)
			tags = (test["tags"] and prefix_hash(test["tags"]) or tags)
			local file = string.format("%s/data/%s/in.yaml", PATH_SUITE, remove_extension(filename))
			local event = string.format("%s/data/%s/test.event", PATH_SUITE, remove_extension(filename))
			the_yaml = test["yaml"]
			if #testfile > 9 then
				file = string.format("%s/data/%s/%03d/in.yaml", PATH_SUITE, remove_extension(filename), test_nr)
				event = string.format("%s/data/%s/%03d/test.event", PATH_SUITE, remove_extension(filename), test_nr)
				the_yaml = string.format("%s/%03d", the_yaml, test_nr)
			elseif #testfile > 1 then
				file = string.format("%s/data/%s/%02d/in.yaml", PATH_SUITE, remove_extension(filename), test_nr)
				event = string.format("%s/data/%s/%02d/test.event", PATH_SUITE, remove_extension(filename), test_nr)
				the_yaml = string.format("%s/%02d", the_yaml, test_nr)
			end
			local fail = test["fail"] and true or false
			if not skip and test["skip"] then
				skip = true
			end
			if not skip then
				table.insert(result, "")
				table.insert(
					result,
					string.format(
						'  it("should parse the %s, file: #%s tags: %s", function()',
						escape(name),
						remove_extension(filename),
						tags
					)
				)
				-- table.insert(
				-- 	result,
				-- 	string.format('    print("### should parse the %s, file: %s")', escape(name), file)
				-- )
				table.insert(result, string.format('    local input = load_file("%s")', file))
				if fail then
					table.insert(result, string.format("    local result = yalua.stream(input)"))
					table.insert(result, string.format("    assert.Equal(nil, result)"))
					total_fails = total_fails + 1
				else
					table.insert(result, string.format('    local tree = load_file("%s")', event))
					table.insert(result, string.format("    local result = yalua.stream(input)"))
					table.insert(result, string.format("    assert.is.Same(tree, result)"))
					total_tests = total_tests + 1
				end
				table.insert(result, "  end)")
			else
				total_skip = total_skip + 1
			end
			test_nr = test_nr + 1
		end
	end
	table.insert(result, "end)")
	write(PATH_TESTS .. "/tree_spec.lua", result)
	print(
		"[INFO] Tests generated: Positive: "
			.. total_tests
			.. ", Negative: "
			.. total_fails
			.. ", Skipped: "
			.. total_skip
	)
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
		local test, mes = yalua.parse(filename)
		if not test then
			error("[ERROR] Can not load the testfile: " .. file .. " " .. mes)
		end
		assert(file)
		test["file"] = file
		table.insert(data, test)
	end
	spec_tree(data)
end

local function suite()
	print("[INFO] Prepare test suite.")
	prepare_suite()
	if os.execute('busted spec/suite/tree_spec.lua --exclude-tags="SM9W,2G84"') ~= 0 then
		error("Test suite did not run successfully")
	end
end

local function clean()
	print("[RUN] rm -rf " .. PATH_SUITE)
	os.execute("rm -rf " .. PATH_SUITE)
	print("[RUN] rm -rf " .. PATH_TESTS)
	os.execute("rm -rf " .. PATH_TESTS)
end

local function test()
	if os.execute("busted spec/test") ~= 0 then
		error("Tests did not run successfully")
	end
end

local function check()
	if os.execute("luacheck StringIterator.lua Lexer.lua Parser.lua yalua.lua") ~= 0 then
		error("Luacheck did not run successfully")
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

local function print_usage()
	print("Usage: ./build.lua <command>")
	print("Commands:")
	print("  test   - Run unit tests")
	print("  check  - Run luacheck")
	print("  suite  - Run YAML test suite")
	print("  clean  - Clean test suite and build files")
	print("  dump <filename> - Dump lexer output for a file")
end

if is_main(arg, ...) then
	-- print("yalua build: " .. table.concat(arg, ", "))
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
			print_usage()
		end
		local iter = require("StringIterator"):new(get_file_content(arg[2]))
		local lexer, mes = require("Lexer"):new(iter)
		if not lexer then
			print(mes)
		else
			print(tostring(lexer))
		end
	else
		print_usage()
	end
else
	error("build.lua can not be used as library")
end
