local Module = {}

---------------------------------
-- JSON Encoding Implementation
---------------------------------

-- Escapes special characters in a string for JSON output.
local function encodeJSONString(str)
	str = string.gsub(str, '\\', '\\\\')
	str = string.gsub(str, '"', '\\"')
	str = string.gsub(str, "\n", "\\n")
	str = string.gsub(str, "\r", "\\r")
	str = string.gsub(str, "\t", "\\t")
	return '"' .. str .. '"'
end

-- Checks if a table is a "pure array" (i.e. its numeric keys form a contiguous sequence starting at 1).
local function isArray(t)
	local maxIndex = 0
	local count = 0
	for k, _ in pairs(t) do
		if type(k) == "number" and k > 0 and math.floor(k) == k then
			if k > maxIndex then
				maxIndex = k
			end
			count = count + 1
		else
			return false  -- Found a non‑numeric or non‑positive key.
		end
	end
	return maxIndex == count
end

-- Recursive helper to find a unique candidate key.
local function getUniqueCandidate(candidate, usedKeys, iteration)
	iteration = iteration or 0
	if not usedKeys[candidate] then
		return candidate
	else
		local candidateNumber = tonumber(candidate)
		if candidateNumber then
			local newCandidate = tostring(candidateNumber + 1)
			if iteration < 100 then
				return getUniqueCandidate(newCandidate, usedKeys, iteration + 1)
			else
				local randomCandidate = tostring(math.random(100000, 999999))
				if usedKeys[randomCandidate] then
					return getUniqueCandidate(randomCandidate, usedKeys, iteration + 1)
				else
					return randomCandidate
				end
			end
		else
			local newCandidate = candidate .. "1"
			if iteration < 100 then
				return getUniqueCandidate(newCandidate, usedKeys, iteration + 1)
			else
				local randomCandidate = tostring(math.random(100000, 999999))
				if usedKeys[randomCandidate] then
					return getUniqueCandidate(randomCandidate, usedKeys, iteration + 1)
				else
					return randomCandidate
				end
			end
		end
	end
end

-- Recursively encodes Lua values into JSON strings.
local function encodeJSON(value)
	local t = type(value)
	if t == "nil" then
		return "null"
	elseif t == "number" or t == "boolean" then
		return tostring(value)
	elseif t == "string" then
		return encodeJSONString(value)
	elseif t == "table" then
		local result = {}
		if isArray(value) then
			-- Encode as a JSON array.
			for i = 1, #value do
				table.insert(result, encodeJSON(value[i]))
			end
			return "[" .. table.concat(result, ",") .. "]"
		else
			-- Encode as a JSON object.
			-- First, partition the keys: string keys first, then non‑string keys.
			local usedKeys = {}
			local keyCount = 0
			local stringPairs = {}
			local nonStringPairs = {}
			for k, v in pairs(value) do
				keyCount = keyCount + 1
				if type(k) == "string" then
					table.insert(stringPairs, {k, v})
				else
					table.insert(nonStringPairs, {k, v})
				end
			end

			-- Process string keys first (they have precedence).
			for _, pair in ipairs(stringPairs) do
				local key, val = pair[1], pair[2]
				local candidate = tostring(key)  -- This should be identical to the original.
				usedKeys[candidate] = true
				table.insert(result, encodeJSONString(candidate) .. ":" .. encodeJSON(val))
			end

			-- Process non‑string keys.
			for _, pair in ipairs(nonStringPairs) do
				local key, val = pair[1], pair[2]
				local candidate = tostring(key)
				if usedKeys[candidate] then
					-- Conflict detected: use (#keys + 1) as the starting candidate.
					candidate = getUniqueCandidate(tostring(keyCount + 1), usedKeys, 0)
				end
				usedKeys[candidate] = true
				table.insert(result, encodeJSONString(candidate) .. ":" .. encodeJSON(val))
			end

			return "{" .. table.concat(result, ",") .. "}"
		end
	else
		error("Unsupported data type: " .. t)
	end
end

Module.encode = encodeJSON

---------------------------------
-- JSON Decoding Implementation
---------------------------------

-- Internal error handler for decode errors.
local function decodeError(msg, pos)
	error("JSON decode error at position " .. pos .. ": " .. msg)
end

-- Skips whitespace characters and returns the next non‑whitespace position.
local function skipWhitespace(str, pos)
	local pattern = "[ \n\r\t]*"
	local s, e = string.find(str, pattern, pos)
	return e + 1
end

-- Forward declaration for recursive descent.
local parseValue

-- Parses a JSON string (handles escapes; minimal Unicode support).
local function parseString(str, pos)
	if string.sub(str, pos, pos) ~= '"' then
		decodeError("Expected '\"' at beginning of string", pos)
	end
	pos = pos + 1
	local result = {}
	while pos <= #str do
		local char = string.sub(str, pos, pos)
		if char == '"' then
			pos = pos + 1
			return table.concat(result), pos
		elseif char == '\\' then
			pos = pos + 1
			if pos > #str then
				decodeError("Unexpected end of string", pos)
			end
			local escapeChar = string.sub(str, pos, pos)
			if escapeChar == '"' then
				table.insert(result, '"')
			elseif escapeChar == '\\' then
				table.insert(result, '\\')
			elseif escapeChar == '/' then
				table.insert(result, '/')
			elseif escapeChar == 'b' then
				table.insert(result, '\b')
			elseif escapeChar == 'f' then
				table.insert(result, '\f')
			elseif escapeChar == 'n' then
				table.insert(result, '\n')
			elseif escapeChar == 'r' then
				table.insert(result, '\r')
			elseif escapeChar == 't' then
				table.insert(result, '\t')
			elseif escapeChar == 'u' then
				-- Minimal Unicode handling: read the next 4 hex digits.
				local hex = string.sub(str, pos+1, pos+4)
				if not hex:find("^%x%x%x%x$") then
					decodeError("Invalid unicode escape", pos)
				end
				local code = tonumber(hex, 16)
				table.insert(result, utf8.char(code))
				pos = pos + 4
			else
				decodeError("Invalid escape character: " .. escapeChar, pos)
			end
			pos = pos + 1
		else
			table.insert(result, char)
			pos = pos + 1
		end
	end
	decodeError("Unterminated string", pos)
end

-- Parses a JSON number.
local function parseNumber(str, pos)
	local numberPattern = "^%-?%d+%.?%d*[eE]?[+-]?%d*"
	local s, e = string.find(str, numberPattern, pos)
	if s then
		local numStr = string.sub(str, s, e)
		local num = tonumber(numStr)
		if not num then
			decodeError("Invalid number: " .. numStr, pos)
		end
		return num, e + 1
	else
		decodeError("Expected number", pos)
	end
end

-- Parses literals: true, false, or null.
local function parseLiteral(str, pos)
	local literals = {
		["true"] = true,
		["false"] = false,
		["null"] = nil
	}
	for lit, value in pairs(literals) do
		if string.sub(str, pos, pos + #lit - 1) == lit then
			return value, pos + #lit
		end
	end
	decodeError("Unexpected literal", pos)
end

-- Parses a JSON array.
local function parseArray(str, pos)
	local result = {}
	pos = pos + 1  -- skip '['
	pos = skipWhitespace(str, pos)
	if string.sub(str, pos, pos) == ']' then
		return result, pos + 1
	end
	local index = 1
	while pos <= #str do
		local value
		value, pos = parseValue(str, pos)
		result[index] = value
		index = index + 1
		pos = skipWhitespace(str, pos)
		local char = string.sub(str, pos, pos)
		if char == ',' then
			pos = pos + 1
			pos = skipWhitespace(str, pos)
		elseif char == ']' then
			pos = pos + 1
			break
		else
			decodeError("Expected ',' or ']'", pos)
		end
	end
	return result, pos
end

-- Parses a JSON object.
local function parseObject(str, pos)
	local result = {}
	pos = pos + 1  -- skip '{'
	pos = skipWhitespace(str, pos)
	if string.sub(str, pos, pos) == '}' then
		return result, pos + 1
	end
	while pos <= #str do
		if string.sub(str, pos, pos) ~= '"' then
			decodeError("Expected string for object key", pos)
		end
		local key
		key, pos = parseString(str, pos)
		pos = skipWhitespace(str, pos)
		if string.sub(str, pos, pos) ~= ':' then
			decodeError("Expected ':' after object key", pos)
		end
		pos = pos + 1
		pos = skipWhitespace(str, pos)
		local value
		value, pos = parseValue(str, pos)
		result[key] = value
		pos = skipWhitespace(str, pos)
		local char = string.sub(str, pos, pos)
		if char == ',' then
			pos = pos + 1
			pos = skipWhitespace(str, pos)
		elseif char == '}' then
			pos = pos + 1
			break
		else
			decodeError("Expected ',' or '}'", pos)
		end
	end
	return result, pos
end

-- Parses any JSON value.
parseValue = function(str, pos)
	pos = skipWhitespace(str, pos)
	local char = string.sub(str, pos, pos)
	if char == '{' then
		return parseObject(str, pos)
	elseif char == '[' then
		return parseArray(str, pos)
	elseif char == '"' then
		return parseString(str, pos)
	elseif char == '-' or char:match("%d") then
		return parseNumber(str, pos)
	else
		return parseLiteral(str, pos)
	end
end

-- Main decoder function: converts a JSON string into a Lua table/value.
local function decodeJSON(str)
	if type(str) ~= "string" then
		error("Expected JSON string for decode")
	end
	local result, pos = parseValue(str, 1)
	pos = skipWhitespace(str, pos)
	if pos <= #str then
		decodeError("Unexpected trailing characters", pos)
	end
	return result
end

Module.decode = decodeJSON

---------------------------------
-- Return the Module
---------------------------------

return Module
