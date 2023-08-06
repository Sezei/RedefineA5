local mod = {}

mod.ToTime = function(minutes)
	local weeks = math.floor(minutes / 10080)
	local days = math.floor((minutes - (weeks * 10080)) / 1440)
	local hours = math.floor((minutes - (days * 1440) - (weeks * 10080)) / 60)
	local mins = math.floor(minutes - (hours * 60) - (days * 1440) - (weeks * 10080))

	local str = ""
	if weeks > 0 then
		str = str .. weeks .. "w "
	end
	if days > 0 then
		str = str .. days .. "d "
	end
	if hours > 0 then
		str = str .. hours .. "h "
	end
	if mins > 0 then
		str = str .. mins .. "m"
	end

	return str
end

mod.FromTime = function(str)
	local weeks = 0
	local days = 0
	local hours = 0
	local mins = 0

	for w in string.gmatch(str, "(%d+)w") do
		weeks = tonumber(w)
	end
	for d in string.gmatch(str, "(%d+)d") do
		days = tonumber(d)
	end
	for h in string.gmatch(str, "(%d+)h") do
		hours = tonumber(h)
	end
	for m in string.gmatch(str, "(%d+)m") do
		mins = tonumber(m)
	end

	return (weeks * 10080) + (days * 1440) + (hours * 60) + mins
end

setmetatable(mod, {
	-- For the old API, which didn't use .ToTime but just called the module as env.FormatTime(123)
	-- We need to keep this for backwards compatibility since some modules probably still use it
	__call = function(self, minutes)
		return self.ToTime(minutes)
	end
})

return mod