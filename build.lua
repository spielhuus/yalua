#!/usr/bin/env luajit

---lua build file

local yalua = require("yalua")

-- luacheck: push max-line-length
local EXCLUDE_TESTS = '--exclude-tags="96NN,SM9W,ZXT5"'
-- '--exclude-tags="Y79Y,SKE5,PW8X,M5C3,M2N8,EB22,4FJ6,ZXT5,X38W,VJP3,V9D5,UV7Q,UKK6,U3XV,SY6V,SU74,SR86,SM9W,NKF9,NHX8,NB6Z,N782,KK5P,JTV5,JR7V,J3BT,HU3P,H7J7,GDY7,G9HC,FP8R,FH7J,FBC9,F8F9,EXG3,EHF6,DK95,DK4H,DK3J,DBG4,CXX2,CVW2,CML9,C2SP,BU8L,BS4K,BF9H,AVM7,A984,9MMW,9KAX,82AN,7ZZ5,7BMT,6CA3,6BFJ,652Z,5U3A,565N,4V8U,4JVG,3HFZ,6PBE"'
-- luacheck: pop

local PATH_SUITE = "yaml-test-suite"
local TEST_SUITE = "https://github.com/yaml/yaml-test-suite.git"
local PATH_TESTS = "spec/suite"
local PATH_TREE = ".luarocks"
local COVERAGE_HTML = "coverage"
local CMD_LUAROCKS = "CMAKE_POLICY_VERSION_MINIMUM=3.5 luarocks --tree " .. PATH_TREE .. " --lua-version 5.1 "

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
		word = word:gsub("-", "_")
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
	for _, testfile in ipairs(data) do
		local test_nr = 0
		local name, tags
		local filename = testfile["file"]
		local skip = false
		for _, test in ipairs(testfile) do
			name = (test["name"] and test["name"] or name)
			tags = (test["tags"] and prefix_hash(test["tags"]) or tags)
			local file = string.format("%s/data/%s/in.yaml", PATH_SUITE, remove_extension(filename))
			local event = string.format("%s/data/%s/test.event", PATH_SUITE, remove_extension(filename))
			if #testfile > 9 then
				file = string.format("%s/data/%s/%03d/in.yaml", PATH_SUITE, remove_extension(filename), test_nr)
				event = string.format("%s/data/%s/%03d/test.event", PATH_SUITE, remove_extension(filename), test_nr)
			elseif #testfile > 1 then
				file = string.format("%s/data/%s/%02d/in.yaml", PATH_SUITE, remove_extension(filename), test_nr)
				event = string.format("%s/data/%s/%02d/test.event", PATH_SUITE, remove_extension(filename), test_nr)
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
						'  it("should parse the %s, file: <%s> tags: #%s %s", function()',
						escape(name),
						file,
						remove_extension(filename),
						tags
					)
				)
				table.insert(
					result,
					string.format('    print("### should parse the %s, file: %s")', escape(name), file)
				)
				table.insert(result, string.format('    local input = load_file("%s")', file))
				if fail then
					table.insert(result, string.format("    local result = yalua.dump(input)"))
					table.insert(result, string.format("    assert.Equal(nil, result)"))
					total_fails = total_fails + 1
				else
					table.insert(result, string.format('    local tree = load_file("%s")', event))
					table.insert(result, string.format("    local result = yalua.dump(input)"))
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

local function clone_test_suite()
	if not dir_exists(PATH_SUITE) then
		print("[INFO] Clone the yaml test suite")
		os.execute("git clone " .. TEST_SUITE .. " " .. PATH_SUITE)
		os.execute("make -C " .. PATH_SUITE .. " data")
	end
end

local function prepare_suite()
	clone_test_suite()
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

local function coverage()
	print("[INFO] create the test coverage.")
	prepare_suite()
	if os.execute(CMD_LUAROCKS .. "test spec/ -- -c") ~= 0 then
		print("[ERROR] Test coverage did not run successfully")
	end
	if os.execute("luacov -r lcov") ~= 0 then
		error("converting coverage to lcov failed")
	end
	if os.execute("genhtml luacov.report.out -o " .. COVERAGE_HTML) ~= 0 then
		error("generating html files from coverage stats failed.")
	end
end

local function html(filename)
	print("[INFO] create html tokenized stream.")
	local res = require("yalua").html(get_file_content(filename))
	if not res then
		error("generating html files from token stream failed.")
	end
	write(filename .. ".html", { res })
end

local function suite()
	print("[INFO] Prepare test suite.")
	prepare_suite()
	if os.execute(CMD_LUAROCKS .. "test spec/suite/tree_spec.lua -- " .. EXCLUDE_TESTS) ~= 0 then
		error("Test suite did not run successfully")
	end
end

local function clean()
	print("[RUN] rm -rf " .. PATH_SUITE)
	os.execute("rm -rf " .. PATH_SUITE)
	print("[RUN] rm -rf " .. PATH_TESTS)
	os.execute("rm -rf " .. PATH_TESTS)
	print("[RUN] rm -rf " .. PATH_TREE)
	os.execute("rm -rf " .. PATH_TREE)
	print("[RUN] rm -rf " .. COVERAGE_HTML)
	os.execute("rm -rf " .. COVERAGE_HTML)
	print("[RUN] rm -f luacov.stats.out")
	os.execute("rm -f luacov.stats.out")
	print("[RUN] rm -f luacov.report.out")
	os.execute("rm -f luacov.report.out")
end

local function test()
	clone_test_suite()
	if os.execute(CMD_LUAROCKS .. " test spec/test -- --defer-print") ~= 0 then
		error("Tests did not run successfully")
	end
end

local function check()
	if os.execute("luacheck yalua.lua") ~= 0 then
		error("Luacheck did not run successfully")
	end
end

local function lls()
	if os.execute("llscheck --configpath .luarc.json") ~= 0 then
		error("LLS checks did not run successfully")
	end
end

local function is_main(arg, ...)
	local n_arg = arg and #arg or 0
	if n_arg == select("#", ...) then
		for i = 1, n_arg do
			if arg[i] ~= select(i, ...) then
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
	print("  test      - Run unit tests")
	print("  check     - Run luacheck")
	print("  lls       - Run lls checks")
	print("  suite     - Run YAML test suite")
	print("  coverage  - Run test coverage")
	print("  clean     - Clean test suite and build files")
	print("  all       - Run all targets (test, suite, check , lls)")
	print("  html <filename> - Dump lexer output as html file")
	print("  dump <filename> - Dump lexer output for a file")
end

if is_main(arg, ...) then
	-- print("yalua build: " .. table.concat(arg, ", "))
	if arg[1] == "test" then
		return test()
	elseif arg[1] == "check" then
		check()
	elseif arg[1] == "lls" then
		lls()
	elseif arg[1] == "suite" then
		suite()
	elseif arg[1] == "coverage" then
		coverage()
	elseif arg[1] == "clean" then
		clean()
	elseif arg[1] == "html" then
		if not arg[2] then
			error("no filename for dump.")
			print_usage()
		end
		html(arg[2])
	elseif arg[1] == "all" then
		check()
		lls()
		test()
		suite()
	elseif arg[1] == "dump" then
		if not arg[2] then
			error("no filename for dump.")
			print_usage()
		end
		local stream, mes = require("yalua").dump(get_file_content(arg[2]))
		if not stream then
			print(mes)
		else
			print(stream)
		end
	else
		print_usage()
	end
else
	error("build.lua can not be used as library")
end
