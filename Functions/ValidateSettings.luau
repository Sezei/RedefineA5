local Template = require(script.SettingsTemplate)

local function CloneTable(array)
	if typeof(array) == 'table' then
		local clone = {}
		for i,v in array do
			if type(v) == "table" then
				clone[i] = CloneTable(v)
			else
				clone[i] = v
			end
		end
		return clone
	else
		return array;
	end
end

return function(Settings)
	if not Settings then return nil end;
	
	local ReturnedSettings = {};
	-- Check for missing keys, and add them with default values.
	-- For matching references;
	-- If a key does not exist, add the key from the template
	-- If a key does exist, verify the type; if type mismatches, set the type from template

	-- template; [Key]={type:string,defaultValue:[typeRelative]}
	-- settings; [Key]=Value

	for Key,Data in Template do
		if not Settings[Key] then
			ReturnedSettings[Key] = CloneTable(Data[2]);
		else
			if type(Settings[Key]) ~= Data[1] then
				ReturnedSettings[Key] = CloneTable(Data[2]);
			else
				ReturnedSettings[Key] = CloneTable(Settings[Key]);
			end
		end
	end

	-- sanitary thing for the admins thing because mixing strings and numbers does NOT go well for json.
	for Level, AdminData in Settings.Admins do
		if not tonumber(Level) then
			-- it can't be a string. warn the user and remove from the table.
			warn("Settings.Admins[\"" .. Level .. "\"] : Invalid type for Level in Admins; expected number, got string")
		else
			ReturnedSettings.Admins[Level] = nil -- clear the previous iteration
			ReturnedSettings.Admins[tonumber(Level)] = CloneTable(AdminData)

			-- CHECK IF THE ADMIN WAS TEMPORARY!!
			for k, v in ReturnedSettings.Admins[tonumber(Level)] do
				if type(v) == "table" then
					if v.Temporary then
						ReturnedSettings.Admins[tonumber(Level)][k] = nil;
					end
				end
			end
		end
	end
	
	-- add stuff that isnt already in the templates
	for Key, Value in Settings do
		if not Template[Key] then
			ReturnedSettings[Key] = Value;
		end
	end

	return ReturnedSettings;
end;