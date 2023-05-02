return function (env, mod, v)
	if not (type(mod) == "table") then
		env.warn(3,v.Name.." is not a valid command: Expected table, got "..typeof(mod));
		return false;
	elseif not (type(mod.Level) == "number") then
		env.warn(3,v.Name.." is not a valid command: Missing Level value; Use 'Disabled = true' to disable the command");
		return false;
	elseif not (type(mod.OnRun) == "function") then
		env.warn(3,v.Name.." is not a valid command: Missing OnRun function");
		return false;
	elseif not (type(mod.Arguments) == "table" or (type(mod.Arguments) == "string" and mod.Arguments == 'rawinput')) then
		env.warn(3,v.Name.." is not a valid command: Missing Arguments table; Use an empty table if you don't expect arguments");
		return false;
	end

	-- Sanity check the arguments;
	if type(mod.Arguments)=='table' then
		for argkey,argument in pairs(mod.Arguments) do
			if not (type(argument) == "table") then
				env.warn(3,v.Name.." is not a valid command: Argument "..argkey.." is not a table");
				return false;
			elseif not (type(argument.Type) == "string") then
				env.warn(3,v.Name.." is not a valid command: Argument "..argkey.." needs to be a string value, got "..typeof(argument.Type));
				return false;
			elseif not (type(argument.Name) == "string") then
				env.warn(3,v.Name.." is not a valid command: Argument "..argkey.." needs to be a string value, got "..typeof(argument.Name));
				return false;
			elseif not (type(argument.Required) == "boolean") then
				env.warn(3,v.Name.." is not a valid command: Argument "..argkey.." is missing a Required value");
				return false;
			end

			-- Check argument types validity
			-- Valid types: string, number, boolean, player, safeplayer, players, safeplayers and color.
			local typeofcommand = string.lower(argument.Type);
			local matchingtypes = {
				"string";
				"number";
				"boolean";
				"player";
				"safeplayer";
				"players";
				"safeplayers";
				"color";
			};
			if not (table.find(matchingtypes, typeofcommand)) then
				env.warn(v.Name.." might error: Argument "..argkey.." has an invalid type.");
			end

			-- Check string sanity
			-- Strings might have an .Options table which contains a list of valid options
			-- They aren't necessarily required, but if they are present, they need to be a table, and each value needs to be a string
			if (typeofcommand == "string") then
				if (type(argument.Options) == "table") then
					for optionkey,optionvalue in pairs(argument.Options) do
						if not (type(optionvalue) == "string") then
							env.warn(v.Name.." might error: Argument "..argkey.."'s "..optionkey.." option is not a string.");
						end
					end
				end
			end

			-- Check number sanity
			-- Numbers is special since it contains a Min and Max value
			-- We need to check if the Min and Max values are numbers, the numbers are NOT NaN and the Min value is less than the Max value
			if (typeofcommand == "number") then
				-- Check if Min and Max are present (they are not required)
				if not (type(argument.Minimum) == "number") then
					argument.Minimum = -math.huge;
				end
				if not (type(argument.Maximum) == "number") then
					argument.Maximum = math.huge;
				end

				-- Check if Min and Max are not NaN
				if (argument.Minimum ~= argument.Minimum) then
					env.warn(v.Name.." might error: Argument "..argkey.." has a NaN value in the Minimum value.");
				elseif (argument.Maximum ~= argument.Maximum) then
					env.warn(v.Name.." might error: Argument "..argkey.." has a NaN value in the Maximum value.");
				end

				-- Check if Min is less than Max
				if (argument.Minimum > argument.Maximum) then
					env.warn(v.Name.." might error: Argument "..argkey.."'s Minimum value is greater than the Maximum value.");
				end
			end
		end
	end

	-- Sanity check for optional values
	if not (type(mod.Name) == "string") then -- Name
		mod.Name = v.Name
	end
	if not (type(mod.Description) == "string") then -- Description
		mod.Description = "No description provided";
	end
	if not (type(mod.Keys) == "table") then -- Keys are like arguments, but they do are not called as arguments; Example; !command argument --key:value / !command --key / !command --key:"multi word value"
		mod.Keys = {};
	end
	if not (type(mod.Aliases) == "table") then -- Alternative ways to call the command
		mod.Aliases = {};
	end
	if not (type(mod.Credits) == "table") then -- Cosmetic, it will show the users in !credits if they are in the table
		mod.Credits = {};
	end
	if not (type(mod.Visible) == "boolean") then -- If Visible is false, the command will only show up if the user can run it
		mod.Visible = false;
	end
	if not (type(mod.Cooldown) == "number") then -- This will prevent the same command from being run more than once every X seconds by any user (Global cooldown)
		mod.Cooldown = 0;
	end
	if not (type(mod.UserCooldown) == "number") then -- This will prevent the same command from being run more than once every X seconds by the same user (User cooldown)
		mod.UserCooldown = 0;
	end
	if not (type(mod.Disabled) == "boolean") then -- If Disabled is true, the command will not be able to be ran in-game and will not show up in the command list
		mod.Disabled = false;
	end
	if not (type(mod.Dependencies) == "table") then -- Dependencies are env variables that are required to be present for the command to run; Example; {GetLevel = true} will require the env variable GetLevel (env.GetLevel) to be present
		mod.Dependencies = {};
	end
	if not (type(mod.DisallowOverwrite) == "boolean") then -- Disallows other commands from overwriting this command; Mainly used only for the core commands but can be used for other commands
		mod.DisallowOverwrite = false;
	end
	if not (type(mod.DisallowDisabling) == "boolean") then -- Disallows the command from being disabled; Mainly used only for the core commands but can be used for other commands
		mod.DisallowDisabling = false;
	end
	if not (type(mod.OnLoad) == "function") then
		mod.OnLoad = function() end;
	end
	if not (type(mod.RunCapability) == "function") then
		mod.RunCapability = function() end;
	end

	mod.Name = string.lower(mod.Name);

	for _,v in pairs(mod.Aliases) do
		v = string.lower(tostring(v));
	end

	return true;
end