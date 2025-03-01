local StringIterator = {}

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

---Peek characters from the input
---n int|nil number of characters, default is 1
function StringIterator:peek(n)
	n = n or 1
	if self.index + n > #self.str then
		return nil
	end
	return string.sub(self.str, self.index + n, self.index + n)
end

function StringIterator:eol()
	return self:peek() == "\n" or self:peek() == "\r"
end

function StringIterator:eof()
	return self.index >= #self.str
end

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

function StringIterator:match(str)
	local s = string.sub(self.str, self.index + 1, self.index + #str)
	return s == str
end

return StringIterator
