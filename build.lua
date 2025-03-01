#!/usr/bin/env luajit
---lua build file

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

local function prepare_suite()
	if not dir_exists(PATH_SUITE) then
		os.execute("git clone " .. TEST_SUITE .. " " .. PATH_SUITE)
		os.execute("make -C " .. PATH_SUITE .. " data")
	end
	-- read all the test files
	for _, file in ipairs(get_files_in_directory(string.format("%s/src", PATH_SUITE))) do
		print(file)
	end
end

local function suite()
	prepare_suite()
end

local function clean()
	os.execute("rm -rf " .. PATH_SUITE)
end

local function test()
	if os.execute("busted spec/new --exclude-tags='exclude'") ~= 0 then
		error("test suite did not run successfully")
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
	elseif arg[1] == "suite" then
		suite()
	elseif arg[1] == "clean" then
		clean()
	end
else
	error("build.lua can not be used as library")
end
