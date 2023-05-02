return function(Time)
	-- This function converts time from minutes to a string. (eg; 1 => 1m, 60 => 1h, 1440 => 1d, 1441 => 1d1m);
	local Time = math.floor(Time);
	local Months = math.floor(Time / 43200);
	local Weeks = math.floor((Time - Months * 43200) / 10080);
	local Days = math.floor((Time - Months * 43200 - Weeks * 10080) / 1440);
	local Hours = math.floor((Time - Months * 43200 - Weeks * 10080 - Days * 1440) / 60);
	local Minutes = math.floor(Time - Months * 43200 - Weeks * 10080 - Days * 1440 - Hours * 60);
	local TimeString = "";
	if Months > 0 then
		TimeString ..= Months .. "mo";
	end
	if Weeks > 0 then
		TimeString ..= Weeks .. "w";
	end
	if Days > 0 then
		TimeString ..= Days .. "d";
	end
	if Hours > 0 then
		TimeString ..= Hours .. "h";
	end
	if Minutes > 0 then
		TimeString ..= Minutes .. "m";
	end
	return TimeString:sub(1,-2);
end;