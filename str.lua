local str = {}

function str.to_string(obj, indent, visited)
	indent = indent or ""
	visited = visited or {}

	if type(obj) == "table" then
		if visited[obj] then
			return "<recursive table>"
		end
		visited[obj] = true

		local output = "{\n"
		for k, v in pairs(obj) do
			output = output
				.. indent
				.. "  "
				.. str.to_string(k, indent .. "  ", visited)
				.. " = "
				.. str.to_string(v, indent .. "  ", visited)
				.. ",\n"
		end
		return output .. indent .. "}"
	elseif type(obj) == "string" then
		return '"' .. obj .. '"'
	else
		return tostring(obj)
	end
end

function str.trim(s, spaces_only)
	if spaces_only then
		return (s:gsub("^ *(.-) *$", "%1"))
	else
		return (s:gsub("^%s*(.-)%s*$", "%1"))
	end
end

str.lines = function(input)
	if not input then
		return {}
	end
	local result = {}
	local index, last = 1, 1
	while index <= #input do
		local c = input:sub(index, index)
		if c == "\r" or c == "\n" then
			table.insert(result, input:sub(last, index - 1))
			if index + 1 <= #input and c == "\r" and input:sub(index + 1, index + 1) == "\n" then
				index = index + 1
			end
			last = index + 1
		end
		index = index + 1
	end
	if last <= index then
		table.insert(result, input:sub(last))
	end
	return result
end

return str
