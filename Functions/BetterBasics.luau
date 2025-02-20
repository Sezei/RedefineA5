-- Better Basics is an extended library for a few of the LuaU libraries, such as math, string and table, while also
-- adding new functions to them.
--
-- Notorious for being extremely useless. :troll:
--
-- Created by Sezei (@0bBinary)

local module = {}

module.math = {}
module.string = {}
module.table = {}
module.bool = {}

-- Rounds a number to a specified number of decimal places.
-- @param num The number to round.
-- @param pnt The number of decimal places to round to.
-- @return The rounded number.
function module.math.fround(num,pnt)
	return math.floor(num*(10^pnt))/(10^pnt)
end

-- Creates a deep copy of a table.
-- @param t The table to clone.
-- @return The cloned table.
function module.table.fullclone(t)
	local new = {}

	for k,v in pairs(t) do
		new[k] = v;
	end

	return new;
end

-- Calculates the median value of a numeric table.
-- @param t The numeric table.
-- @return The median value.
function module.table.median(t)
	local size = #t
	local half = math.floor(size/2)

	if size % 2 == 1 then
		return t[half]
	else
		return (t[half] + t[half+1])/2
	end
end

-- Inverts the order of elements in a table.
-- @param t The table to invert.
-- @return The inverted table.
function module.table.invert(t)
	local new = {}

	for i,v in ipairs(t) do
		new[#t-i+1] = v
	end

	return new;
end

-- Merges 2 tables into a single table, without overwriting any values.
-- @param t1 The table to merge into (prioritized).
-- @param t2 The table to merge the keys from.
-- @return The merged table.
function module.table.merge(t1, t2)
	local result = {}
	local seenTables = {}

	local function add(value)
		if type(value) == "table" then
			if seenTables[value] then
				return
			end
			seenTables[value] = true
			table.insert(result, value)
		else
			for _, v in result do
				if v == value then
					return
				end
			end
			table.insert(result, value)
		end
	end

	for i = 1, #t1 do
		add(t1[i])
	end

	for i = 1, #t2 do
		add(t2[i])
	end

	return result
end

-- Replaces placeholders in a string with their corresponding values.
-- @param origin The original string.
-- @param placeholders A table of placeholders and their values.
-- @return The string with placeholders replaced.
function module.string.placeholder(origin,placeholders)
	local s:string = tostring(origin);

	for old,new in pairs(placeholders) do
		s = s:gsub("<"..old..">",tostring(new));
	end

	return s;
end

-- Fixes special characters in a string used in the new chat system in Roblox.
-- @param str The string to fix.
-- @return The fixed string.
function module.string.fixnewchat(str)
	return str:gsub("&#39;","'"):gsub("&quot;",'"'):gsub("&lt;","<"):gsub("&gt;",">"):gsub("&amp;","&")
end

-- Converts a value to a boolean.
-- @param self The value to convert.
-- @return The boolean representation of the value.
function module.bool.tobool(self)
	if type(self) == 'nil' then
		return false;
	elseif type(self) == 'table' then
		return true;
	elseif type(self) == 'boolean' then
		return self;
	elseif type(self) == 'number' then
		return (self ~= 0);
	elseif type(self) == 'string' then
		self = self:lower();
		if self == "false" or self == '' or self == 'no' or self == '0' then
			return false;
		end;
		return true;
	elseif type(self) == 'userdata' then
		return true;
	end;
end

-- Inverts the boolean value.
-- @param self The boolean value to invert.
-- @return The inverted boolean value.
function module.bool.invert(self)
	if type(self) ~= 'boolean' then
		return not module.bool.tobool(self);
	end
	return not self;
end

return module
