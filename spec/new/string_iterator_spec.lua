local assert = require("luassert")
local StringIterator = require("StringIterator")
describe("StringIterator", function()
	it("should initialize with correct values", function()
		local iterator = StringIterator:new("hello")
		assert.Equal("hello", iterator.str)
		assert.Equal(0, iterator.index)
		assert.Equal(1, iterator.row)
		assert.Equal(0, iterator.col)
	end)

	describe(":peek()", function()
		it("should return the next character", function()
			local iterator = StringIterator:new("hello")
			assert.Equal("h", iterator:peek())
		end)

		it("should return nil if at end of string", function()
			local iterator = StringIterator:new("hello")
			for _ = 1, #iterator.str do
				iterator:next()
			end
			assert.is_nil(iterator:peek())
		end)
	end)

	describe(":eol()", function()
		it("should return true if next character is newline", function()
			local iterator = StringIterator:new("hello\nworld")
			for _ = 1, #iterator.str do
				if iterator:eol() then
					break
				end
				iterator:next()
			end
			assert.is_true(iterator:eol())
		end)

		it("should return false if next character is not newline", function()
			local iterator = StringIterator:new("hello")
			for _ = 1, #iterator.str do
				if iterator:eol() then
					break
				end
				iterator:next()
			end
			assert.is_false(iterator:eol())
		end)
	end)

	describe(":eof()", function()
		it("should return true if at end of string", function()
			local iterator = StringIterator:new("hello")
			for _ = 1, #iterator.str do
				if iterator:eof() then
					break
				end
				iterator:next()
			end
			assert.is_true(iterator:eof())
		end)

		it("should return false if not at end of string", function()
			local iterator = StringIterator:new("hello")
			for _ = 1, #iterator.str - 1 do
				if iterator:eof() then
					break
				end
				iterator:next()
			end
			assert.is_false(iterator:eof())
		end)
	end)

	describe(":next()", function()
		it("should return the next character", function()
			local iterator = StringIterator:new("hello")
			assert.Equal("h", iterator:next())
		end)

		it("should handle newline correctly #act", function()
			local iterator = StringIterator:new("hello\nworld")
			for _ = 1, #iterator.str do
				if iterator:eol() then
					break
				end
				iterator:next()
			end
			iterator:next()
			assert.Equal(2, iterator.row)
			assert.Equal(0, iterator.col)
		end)

		it("should handle carriage return and newline correctly", function()
			local iterator = StringIterator:new("hello\r\nworld")
			for _ = 1, #iterator.str do
				if iterator:eol() then
					break
				end
				iterator:next()
			end
			iterator:next()
			assert.Equal(iterator.row, 2)
			assert.Equal(iterator.col, 0)
		end)

		it("should return nil if at end of string", function()
			local iterator = StringIterator:new("hello")
			for _ = 1, #iterator.str do
				if iterator:eof() then
					break
				end
				iterator:next()
			end
			assert.is_nil(iterator:next())
		end)
	end)

	describe(":match()", function()
		it("should match a single character", function()
			local iterator = StringIterator:new("hello world")
			assert.is_true(iterator:match("h"))
			assert.Equal("h", iterator:next())
			assert.is_true(iterator:match("e"))
			assert.Equal("e", iterator:next())
			assert.is_true(iterator:match("l"))
			assert.Equal("l", iterator:next())
		end)
		it("should match a word", function()
			local iterator = StringIterator:new("hello world")
			assert.is_true(iterator:match("hello"))
			assert.Equal("hello ", iterator:next(6))
			assert.is_true(iterator:match("world"))
		end)
	end)
end)
