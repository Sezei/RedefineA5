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

function module.math.fround(num,pnt)
	return math.floor(num*(10^pnt))/(10^pnt)
end

function module.table.fullclone(t)
	local new = {}

	for k,v in pairs(t) do
		new[k] = v;
	end

	return new;
end

function module.table.median(t)
	local size = #t
	local half = math.floor(size/2)

	if size % 2 == 1 then
		return t[half]
	else
		return (t[half] + t[half+1])/2
	end
end

function module.string.placeholder(origin,placeholders)
	local s:string = tostring(origin);

	for old,new in pairs(placeholders) do
		s = s:gsub("<"..old..">",tostring(new));
	end

	return s;
end

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

function module.bool.invert(self)
	if type(self) ~= 'boolean' then
		return not module.bool.tobool(self);
	end
	return not self;
end

return module
