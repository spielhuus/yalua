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

--- Checks if the next characters in the iterator match the given string.
---@param str string The string to compare against the current position in the iterator.
---@return boolean Returns true if the next characters match the given string, otherwise false.
function StringIterator:match(str)
	local s = string.sub(self.str, self.index + 1, self.index + #str)
	return s == str
end

return StringIterator
