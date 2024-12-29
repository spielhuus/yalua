local str = require("str")

require("tableutils")

local function clean_key(val)
	local trimmed = str.trim(val)
	if string.match(trimmed, "^['\"].*['\"]$") then
		return string.sub(trimmed, 2, #trimmed - 1)
	end
	return trimmed
end

local function value(val)
	local trimmed = str.trim(val)
	if string.match(trimmed, "^['\"].*['\"]$") then
		return string.sub(trimmed, 2, #trimmed - 1)
	end
	if trimmed == "true" or trimmed == "True" or trimmed == "TRUE" then
		return true
	elseif trimmed == "false" or trimmed == "False" or trimmed == "FALSE" then
		return false
	end
	return tonumber(str.trim(val)) or str.trim(val)
end

local lexer

local function collect_flow(tokens, indent)
	local result = {}
	local item = tokens:next().state
	local term
	if item == tokens.states.LSQUARE then
		term = tokens.states.RSQUARE
	elseif item == tokens.states.LCURLY then
		term = tokens.states.RCURLY
	else
		error("wrong start flow")
	end
	while true do
		local ntoken = tokens:peek()
		if ntoken == nil then
			break
		elseif ntoken.state == term then
			tokens:skip()
			break
		elseif tokens:match({ tokens.states.ANY, tokens.states.FCOLON, tokens.states.LCURLY }) then
			local key = tokens:next().val
			tokens:skip()
			local res = collect_flow(tokens, indent)
			result[clean_key(key)] = res
		elseif tokens:match({ tokens.states.ANY, tokens.states.FCOLON, tokens.states.ANY }) then
			local key = tokens:next().val
			tokens:skip()
			local val = tokens:next().val
			result[clean_key(key)] = value(val)
		elseif ntoken.state == tokens.states.ANY then
			local val = tokens:next()
			table.insert(result, value(val.val))
		else
			error("unknwon flow token:" .. str.to_string(ntoken))
		end
	end
	return result
end

local function collect_list(tokens, indent)
	local list = {}
	while true do
		if tokens:match({ tokens.states.DASH, tokens.states.ANY, tokens.states.COLON, tokens.states.NL }) then
			tokens:skip()
			local key = tokens:next().val
			tokens:skip()
			tokens:skip()
			local res = lexer(tokens, tokens:peek().indent)
			table.insert(list, { [str.trim(key)] = res })
		elseif tokens:match({ tokens.states.DASH, tokens.states.ANY, tokens.states.NL }) then
			tokens:skip()
			table.insert(list, value(tokens:next().val))
			tokens:skip()
		else
			return list
		end
		if tokens:eof() then
			break
		end
	end
	return list
end

lexer = function(tokens, indent)
	-- print("in lexer: " .. indent)
	local result = {}
	local documents = {}
	while true do
		-- local token = tokens:next()
		-- if not token then
		-- 	break
		-- end
		if not tokens:peek() or tokens:peek().indent < indent then
			-- print("break")
			break
		end
		if tokens:match({ tokens.states.DOC }) then
			if not table.empty(result) then
				table.insert(documents, result)
				result = {}
			end
			tokens:skip()
		elseif tokens:match({ tokens.states.LCURLY }) or tokens:match({ tokens.states.LSQUARE }) then
			result = collect_flow(tokens, 0)
		elseif tokens:match({ tokens.states.ENDDOC }) then
			if not table.empty(result) then
				table.insert(documents, result)
				result = {}
			end
			tokens:skip()
		elseif tokens:match({ tokens.states.DASH, tokens.states.ANY, tokens.states.COLON, tokens.states.NL }) then
			tokens:skip()
			local key = tokens:next().val
			tokens:skip()
			tokens:skip()
			local res = lexer(tokens, tokens:peek().indent)
			table.insert(result, { [str.trim(key)] = res })
		elseif tokens:match({ tokens.states.DASH, tokens.states.ANY, tokens.states.NL }) then
			tokens:skip()
			table.insert(result, value(tokens:next().val))
			tokens:skip()
		elseif tokens:match({ tokens.states.DASH, tokens.states.NL }) then
			tokens:skip()
			tokens:skip()
			local res = lexer(tokens, tokens:peek().indent)
			table.insert(result, res)
		elseif tokens:match({ tokens.states.ANY, tokens.states.COLON, tokens.states.NL }) then
			local key = tokens:next().val
			tokens:skip()
			tokens:skip()
			if tokens:peek().state == tokens.states.DASH then
				local list = collect_list(tokens, tokens:peek().indent)
				result[str.trim(key)] = list
			else
				local res = lexer(tokens, tokens:peek().indent)
				result[str.trim(key)] = res
			end
		elseif tokens:match({ tokens.states.ANY, tokens.states.COLON, tokens.states.PIPE }) then
			local key = tokens:next().val
			tokens:skip()
			local val = tokens:next().val
			result[str.trim(key)] = value(val)
		elseif tokens:match({ tokens.states.ANY, tokens.states.COLON, tokens.states.LCURLY }) then
			local key = tokens:next().val
			tokens:skip()
			local res = collect_flow(tokens, indent)
			result[str.trim(key)] = res
		elseif tokens:match({ tokens.states.ANY, tokens.states.COLON, tokens.states.ANY, tokens.states.NL }) then
			local key = tokens:next()
			tokens:skip()
			local val = tokens:next()
			tokens:skip()
			result[str.trim(key.val)] = value(val.val)
		-- elseif tokens:match({ tokens.states.ANY, tokens.states.COLON, tokens.states.NL }) then
		elseif tokens:match({ tokens.states.DASH, tokens.states.LSQUARE }) then
			tokens:skip()
			local res = collect_flow(tokens, indent)
			table.insert(result, res)
		else
			tokens:skip()
		end
		if tokens:eof() then
			break
		end
	end

	if not table.empty(documents) then
		table.insert(documents, result)
		return documents
	else
		return result
	end
end

return {
	decode = function(text)
		local tokens = require("tokens"):new()
		tokens:parse(text)
		print(tostring(tokens))
		return lexer(tokens, 0)
	end,
}
