local StringIterator = {}

---String Iterator
---@class StringIterator
---@field str string the yaml string being iterated over
---@field index integer current position in the string
---@field row integer current row number in the string
---@field col integer current column number in the string
---@return StringIterator
function StringIterator:new(str)
	local o = {}
	setmetatable(o, self)
	o.str = str
	o.index = 0
	o.row = 1
	o.col = 0
	self.__index = self
	return o
end

---Peek the next character(s) in the iterator.
---@param n integer? The number of characters to peek, default is 1.
---@return string|nil The character(s) or nil if end of file (eof) is reached.
function StringIterator:peek(n)
	n = n or 1
	if self.index + n > #self.str then
		return nil
	end
	return string.sub(self.str, self.index + n, self.index + n)
end

--- Checks if the end of a line has been reached.
---@return boolean Returns `true` if the current position is at the end of a line, otherwise `false`.
function StringIterator:eol()
	return self:peek() == "\n" or self:peek() == "\r"
end

--- Checks if the end of the file has been reached.
---@return boolean Returns `true` if the end of the file (EOF) is reached, otherwise `false`.
function StringIterator:eof()
	return self.index >= #self.str
end

--- Advances the iterator by `n` characters and returns the next `n` characters.
---@param self StringIterator The iterator instance.
---@param n? integer The number of characters to advance. Defaults to 1 if not provided.
---@return string|nil The next `n` characters as a string, or nil if the end of the string is reached.
function StringIterator:next(n)
	local chars = {}
	for _ = 1, (n or 1) do
		self.index = self.index + 1
		if self.index > #self.str then
			return nil
		end
		self.col = self.col + 1
		local char = string.sub(self.str, self.index, self.index)
		if char == "\n" or char == "\r" then
			if
				self.index + 1 <= #self.str
				and char == "\r"
				and string.sub(self.str, self.index + 1, self.index + 1) == "\n"
			then
				self.index = self.index + 1
			end
			self.col = 0
			self.row = self.row + 1
			table.insert(chars, "\n")
		else
			table.insert(chars, char)
		end
	end
	return table.concat(chars, "")
end

---Test if the line is empty, or only has spaces
function StringIterator:empty_line(seek)
	local index = seek or 1
	while self:peek(index) and self:peek(index) ~= "\n" do
		if self:peek(index) ~= " " and self:peek(index) ~= "\n" then
			return false
		else
			index = index + 1
		end
	end
	return true
end

---Skip all the spaces
function StringIterator:skip_space()
	while self:peek() and self:peek() == " " do
		self:next()
	end
end

---Rewind n characters in the iterator
---@param n integer Number of characters to rewind
---@return nil
function StringIterator:rewind(n)
	if self.index == 1 then
		return
	end
	self.index = self.index - (n or 1)
	self.col = self.col - (n or 1)
	if self.col <= 0 then
		self.row = self.row - 1
		local cursor = self.index
		self.col = 0
		while string.sub(self.str, cursor, cursor) ~= "\n" and cursor > 0 do
			cursor = cursor - 1
			self.col = self.col + 1
		end
	end
end

--- Checks if the next characters in the iterator match the given string.
---@param str string The string to compare against the current position in the iterator.
---@param pos integer? position from where the string should match
---@return boolean Returns true if the next characters match the given string, otherwise false.
function StringIterator:match(str, pos)
	local s = string.sub(self.str, self.index + 1 + (pos or 0), self.index + #str + (pos or 0))
	return s == str
end

--- Get a line from the YAML by number
---@param nr integer The line number
---@return string|nil Returns the content of the line
function StringIterator:line(nr)
	local lines = {}
	for s in string.gmatch(self.str, "[^\n]+") do
		table.insert(lines, s)
	end
	if nr >= 1 and nr <= #lines then
		return lines[nr]
	else
		return nil
	end
end

return StringIterator
