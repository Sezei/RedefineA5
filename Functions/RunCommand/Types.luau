local Players = game:GetService("Players");
local UserService = game:GetService("UserService");

local module = {};
local Registered = {};
local sortedqualifiers = nil;

type Qualifier = {
	name:string;
	methods:{[string]:string};
	maximumstrictness:number;
	identifier:any;
};

function module.ConnectEnv(env)
	if not sortedqualifiers then
		local selectedmethod = string.lower(env.Data.Settings.QualifierMethod);
		if selectedmethod == "sm" then selectedmethod = "sourcemod"; end
		if selectedmethod == "mc" then selectedmethod = "minecraft"; end
		if selectedmethod == "s" then selectedmethod = "simple"; end

		sortedqualifiers = {} :: {[string]: Qualifier};

		if not (selectedmethod == "sourcemod" or selectedmethod == "minecraft" or selectedmethod == "simple") then
			warn("Invalid qualifier method selected. Defaulting to 'simple'.");
			selectedmethod = "simple";
		end;

		for _, qualifier in env.Qualifiers do
			if qualifier.methods[selectedmethod] then
				sortedqualifiers[qualifier.methods[selectedmethod]] = qualifier;
			end;
		end;
	end
	
	env.ArgumentTyping = {
		Register = module.RegisterType;
		Get = module.GetType;
		Parse = module.Parse;
	};
end

function module.RegisterType(TypeName: string, Handler)
	Registered[string.lower(TypeName)] = Handler;
end

function module.GetType(TypeName: string)
	return Registered[string.lower(TypeName)];
end

function module.Parse(env, player, command, arg, args, argposition, sortedarguments, context)
	local argtype = string.lower(arg.Type);
	local handler = Registered[argtype];

	if not handler then
		return false, "Malformed Type; " .. argtype .. "; This argument type is not registered.", "critical";
	end

	return handler(env, player, command, arg, args, argposition, sortedarguments, context);
end

local function FindPlayers(env, Names, Executor) : {Player} -- Function that finds players by name or displayname.
	if string.len(Names) == 0 then return {} end

	local names = string.split(Names, ",")
	local matches: {Player} = {}

	for _, Name in names do
		local Name = Name;

		if env.Data.Settings.InterchangableIls then
			Name = string.gsub(Name, "I", "l");
		end

		for _, v in Players:GetPlayers() do
			local supposedName = v.Name;
			local supposedDName = v.DisplayName;
			local matched = false;

			if env.Data.Settings.InterchangableIls then
				supposedName = string.gsub(supposedName, "I", "l");
				supposedDName = string.gsub(supposedDName, "I", "l");
			end

			-- Local join index: #1 / #2 ...
			if Name:sub(1, 1) == "#" then
				local LocalId = v:GetAttribute("ra_LocalId");
				if LocalId and tonumber(Name:sub(2)) == LocalId then
					matches[#matches + 1] = v;
					matched = true;
				end
			end

			-- uid:123
			if not matched and Name:sub(1, 4) == "uid:" then
				if tonumber(Name:sub(5)) == v.UserId then
					matches[#matches + 1] = v;
					matched = true;
				end
			end

			-- Because of the '@'; prioritise checking the username first before the displayname; Alongside that, it will also not check for the displayname.
			local s1 = string.lower("@" .. supposedName);
			if s1:sub(1, #Name) == string.lower(Name) then
				if not matched then
					matches[#matches + 1] = v;
					matched = true;
				end
			end

			-- displayname prefix match
			s1 = string.lower(supposedDName);
			if s1:sub(1, #Name) == string.lower(Name) then
				if not matched then
					matches[#matches + 1] = v;
					matched = true;
				end
			end

			-- username prefix match
			s1 = string.lower(supposedName);
			if s1:sub(1, #Name) == string.lower(Name) then
				if not matched then
					matches[#matches + 1] = v;
				end
			end
		end

		-- Qualifier fallback ONLY if nothing matched at all
		if not matches[1] then
			for method, qualifier in (sortedqualifiers) do
				if string.lower(Name) == string.lower(method) then
					local plrs = Players:GetPlayers();
					local MatchedPlayers = qualifier.identifier(env, plrs, Executor);
					for _, Player in (MatchedPlayers) do
						matches[#matches + 1] = Player;
					end
				end
			end
		end
	end

	-- Remove duplicates.
	local newmatches: {Player} = {};
	for _, v in (matches) do
		if not table.find(newmatches, v) then
			table.insert(newmatches, v);
		end
	end

	return newmatches;
end

local function GetRestString(args: {string}, argposition: number)
	local str = "";
	for i = argposition, #args do
		str ..= args[i] .. " ";
	end
	return str:sub(1, -2);
end

local function ApplyStringOptions(arg, value)
	if arg.Options then
		if type(arg.Options) == "function" then
			arg.Options = arg.Options(value);
		elseif type(arg.Options) == "table" then
			local found = false;
			for _, v in arg.Options do
				if value then
					if v:sub(1, #value):lower() == value:lower() then
						found = v;
						break;
					end
				else
					found = v;
					break;
				end
			end
			if found then
				value = found;
			end
		end;
	end
	return value;
end

local function ParseTime(str: string, allowsSeconds: boolean?, limit: number?)
	if typeof(str) ~= "string" then
		return false, "Expected a string.";
	end;

	local raw = str:gsub("%s+", "");
	if raw == "" then
		return false, "Time is empty.";
	end;

	local units = {
		["m"] = 60;
		["h"] = 3600;
		["d"] = 86400;
		["w"] = 604800;
	};
	
	if allowsSeconds then
		units["s"] = 1;
	end

	local rawMinutes = tonumber(raw);
	if rawMinutes then
		if rawMinutes < 0 then
			return false, "Time cannot be negative.";
		end
		if limit and limit < rawMinutes then
			return false, "Input is over the limit.";
		end 
		local seconds = math.floor(rawMinutes * 60);
		return true, {
			Seconds = seconds;
			Minutes = rawMinutes;
			Time = os.time() + seconds;
		};
	end;

	local amountStr, unitStr = raw:match("^(%d*%.?%d+)([smhdwSMHDW])$");
	if not amountStr or not unitStr then
		return false, "Invalid time format. Examples: 10, 5m, 1h, 1d, 1w";
	end;

	local amount = tonumber(amountStr);
	if not amount then
		return false, "Invalid time number.";
	end
	if amount < 0 then
		return false, "Time cannot be negative.";
	end

	local unit = string.lower(unitStr);
	local mult = units[unit];

	if not mult then
		return false, "Unknown time unit '" .. tostring(unitStr) .. "'.";
	end;

	local seconds = math.floor(amount * mult);
	if seconds < 0 then
		return false, "Time cannot be negative.";
	end
	
	if limit and limit < (seconds / 60) then
		return false, "Input is over the limit.";
	end 

	return true, {
		Seconds = seconds;
		Minutes = math.round(seconds / 60);
		Time = os.time() + seconds;
	};
end

-- Player
module.RegisterType("player", function(env, player, command, arg, args, argposition, sortedarguments, context)
	local argname = arg.Name;
	local argrequired = arg.Required;
	local argtext = args[argposition];

	if not argtext then
		-- If no text was provided, check if this is the last argument and if it is required
		if argrequired or command.Arguments[argposition + 1] then
			return false, "You need to provide a player for argument " .. argname, "error";
		else
			-- If it is not required and there is no other argument, then use the player as the argument
			return true, player;
		end
	end

	local matches = FindPlayers(env, argtext, player);
	if not matches then
		return false, "An unknown error has occurred causing the command to cancel. (Reference Code: FP_RETURNEDNIL)", "critical";
	end;

	if #matches == 0 then
		return false, "No player was found when searching for argument " .. argname, "error";
	elseif #matches == 1 then
		return true, matches[1];
	else
		env:Notify(player, "Multiple players were found when searching for argument " .. argname .. ": Picked the first match.", {
			Type = "warning";
			Client = true;
		});
		return true, matches[1];
	end
end);

-- SafePlayer
module.RegisterType("safeplayer", function(env, player, command, arg, args, argposition, sortedarguments, context)
	local argname = arg.Name;
	local argrequired = arg.Required;
	local argtext = args[argposition];

	if not argtext then
		if argrequired or command.Arguments[argposition + 1] then
			return false, "You must provide a player for argument " .. argname, "error";
		else
			return true, player;
		end
	end

	local matches = FindPlayers(env, argtext, player);
	if not matches then
		return false, "An unknown error has occurred causing the command to cancel. (Reference Code: FP_RETURNEDNIL)", "critical";
	end;

	if #matches == 0 then
		return false, "No player was found when searching for argument " .. argname, "error";
	end

	-- Check every match to see if they are below the executor
	local safematches = {};
	for _, match in pairs(matches) do
		if env:GetLevel(match) < env:GetLevel(player) then
			table.insert(safematches, match);
		end
	end

	if #safematches == 0 then
		return false, "No safe player was found when searching for argument " .. argname, "error";
	elseif #safematches == 1 then
		return true, safematches[1];
	else
		-- Due to being SAFE player, we don't want 'any' match, we want a specific one.
		return false, "Multiple players were found when searching for argument " .. argname .. ": Please attempt to be more specific.", "error";
	end
end);

-- Players
module.RegisterType("players", function(env, player, command, arg, args, argposition, sortedarguments, context)
	local argname = arg.Name;
	local argrequired = arg.Required;
	local argtext = args[argposition];

	if not argtext then
		if argrequired or command.Arguments[argposition + 1] then
			return false, "You need to provide a player for argument " .. argname, "error";
		else
			return true, {player};
		end
	end

	local matches = FindPlayers(env, argtext, player);
	if not matches then
		return false, "An unknown error has occurred causing the command to cancel. (Reference Code: FP_RETURNEDNIL)", "critical";
	end;

	if #matches == 0 then
		return false, "No player was found when searching for argument " .. argname, "error";
	end

	return true, matches;
end);

-- SafePlayers
module.RegisterType("safeplayers", function(env, player, command, arg, args, argposition, sortedarguments, context)
	local argname = arg.Name;
	local argrequired = arg.Required;
	local argtext = args[argposition];

	if not argtext then
		if argrequired or command.Arguments[argposition + 1] then
			return false, "You need to provide a player for argument " .. argname, "error";
		else
			return true, {player};
		end
	end

	local matches = FindPlayers(env, argtext, player);
	if not matches then
		return false, "An unknown error has occurred causing the command to cancel.", "critical";
	end;

	if #matches == 0 then
		return false, "No player was found when searching for argument " .. argname, "error";
	end

	local safematches = {};
	for _, match in pairs(matches) do
		if env:GetLevel(match) < env:GetLevel(player) then
			table.insert(safematches, match);
		end
	end

	if #safematches == 0 then
		return false, "No safe players were found when searching for argument " .. argname, "error";
	end

	return true, safematches;
end);

-- PlayerList (returns a string)
module.RegisterType("playerlist", function(env, player, command, arg, args, argposition, sortedarguments, context)
	local argname = arg.Name;
	local argrequired = arg.Required;
	local argtext = args[argposition];

	if not argtext then
		if argrequired or command.Arguments[argposition + 1] then
			return false, "You need to provide a player for argument " .. argname, "error";
		else
			return true, player.Name;
		end
	end

	local matches = FindPlayers(env, argtext, player);
	if not matches then
		return false, "An unknown error has occurred causing the command to cancel. (Reference Code: FP_RETURNEDNIL)", "critical";
	end;

	if #matches == 0 then
		return false, "No player was found when searching for argument " .. argname, "error";
	end

	local out = "";
	for _, match in pairs(matches) do
		out ..= match.Name .. ", ";
	end

	return true, out:sub(1, -3);
end);

-- SafePlayerList (returns a string)
module.RegisterType("safeplayerlist", function(env, player, command, arg, args, argposition, sortedarguments, context)
	local argname = arg.Name;
	local argrequired = arg.Required;
	local argtext = args[argposition];

	if not argtext then
		if argrequired or command.Arguments[argposition + 1] then
			return false, "You need to provide a player for argument " .. argname, "error";
		else
			return true, player.Name;
		end
	end

	local matches = FindPlayers(env, argtext, player);
	if not matches then
		return false, "An unknown error has occurred causing the command to cancel. (Reference Code: FP_RETURNEDNIL)", "critical";
	end;

	if #matches == 0 then
		return false, "No player was found when searching for argument " .. argname, "error";
	end

	local safematches = {};
	for _, match in pairs(matches) do
		if env:GetLevel(match) < env:GetLevel(player) then
			table.insert(safematches, match);
		end
	end

	if #safematches == 0 then
		return false, "No safe players were found when searching for argument " .. argname, "error";
	end

	local out = "";
	for _, match in pairs(safematches) do
		out ..= match.Name .. ", ";
	end

	return true, out:sub(1, -3);
end);

-- String
module.RegisterType("string", function(env, player, command, arg, args, argposition, sortedarguments, context)
	local argname = arg.Name;
	local argrequired = arg.Required;
	local argdefault = arg.Default;
	local argtext = args[argposition];

	local isLast = (command.Arguments[argposition + 1] == nil);
	local value;

	if isLast then
		if argrequired then
			if argtext and argtext ~= "" and argtext ~= " " then
				value = GetRestString(args, argposition);
			else
				return false, "You need to provide a valid string for argument " .. argname, "error";
			end
		else
			if argtext and argtext ~= "" and argtext ~= " " then
				value = GetRestString(args, argposition);
			else
				value = argdefault;
			end
		end
	else
		if argtext and argtext ~= "" and argtext ~= " " then
			value = argtext;
		else
			if argrequired then
				return false, "You need to provide a valid string for argument " .. argname, "error";
			else
				value = argdefault;
			end
		end
	end

	value = ApplyStringOptions(arg, value);
	return true, value;
end);

-- Number / Slider
-- For reference if you're new; "slider" is just a number argument but made for Nano's UI commands - It uses the same stuff as a normal Number variable.
module.RegisterType("number", function(env, player, command, arg, args, argposition, sortedarguments, context)
	local argname = arg.Name;
	local argrequired = arg.Required;
	local argdefault = arg.Default;
	local argtext = args[argposition];

	if argtext and tonumber(argtext) then
		local n = tonumber(argtext);
		return true, math.clamp(n, arg.Minimum, arg.Maximum);
	end

	if argrequired then
		return false, "You need to provide a valid number for argument " .. argname, "error";
	end

	return true, argdefault;
end);

module.RegisterType("slider", module.GetType("number"));

-- Boolean
module.RegisterType("boolean", function(env, player, command, arg, args, argposition, sortedarguments, context)
	local argname = arg.Name;
	local argrequired = arg.Required;
	local argdefault = arg.Default;
	local argtext = args[argposition];

	if argtext then
		local lowered = string.lower(argtext);
		if lowered == "true" then
			return true, true;
		elseif lowered == "false" then
			return true, false;
		else
			if argrequired then
				return false, "You need to provide a valid boolean for argument " .. argname, "error";
			else
				return true, argdefault;
			end
		end
	end

	if argrequired then
		return false, "You need to provide a valid boolean for argument " .. argname, "error";
	end

	return true, argdefault;
end);

-- Color
module.RegisterType("color", function(env, player, command, arg, args, argposition, sortedarguments, context)
	local argname = arg.Name;
	local argrequired = arg.Required;
	local argdefault = arg.Default;
	local argtext = args[argposition];

	if argtext then
		-- Since the library **always** returns a color, we don't need to check if it is valid
		local color = env.ColorLib(argtext);
		return true, color;
	end

	if argrequired then
		return false, "You need to provide a valid color for argument " .. argname, "error";
	end

	return true, argdefault;
end);

-- Time
module.RegisterType("time", function(env, player, command, arg, args, argposition, sortedarguments, context)
	local argname = arg.Name;
	local argrequired = arg.Required;
	local argdefault = arg.Default;
	local argtext = args[argposition];
	local limit = arg.Limit;
	
	local allowsseconds = not arg.AllowSeconds;

	if not argtext or argtext == "" then
		if argrequired then
			return false, "You need to provide a valid time for argument " .. argname, "error";
		end

		if argdefault ~= nil then
			if type(argdefault) == "table" then
				return true, argdefault;
			else
				local ok, t = ParseTime(tostring(argdefault), allowsseconds, limit);
				if not ok then
					return false, "Invalid default time for argument " .. argname .. ": " .. tostring(t), "critical";
				end
				return true, t;
			end
		end

		return true, nil;
	end

	local ok, t = ParseTime(argtext, allowsseconds, limit);
	if not ok then
		return false, "Invalid time for argument " .. argname .. ": " .. tostring(t), "error";
	end

	return true, t;
end);

-- PlayerIdentity / PlayerIdentifier
module.RegisterType("playeridentifier", function(env, player, command, arg, args, argposition, sortedarguments, context)
	local argname = arg.Name;
	local argrequired = arg.Required;
	local argtext = args[argposition];

	if argtext == "" or (argtext and (argtext:find(" ") or argtext:find("\t"))) then
		return false, "Invalid input for argument " .. argname, "error";
	end

	if not argtext then
		if argrequired or command.Arguments[argposition + 1] then
			return false, "You need to provide an identifier for argument " .. argname, "error";
		end

		local identity = UserService:GetUserInfosByUserIdsAsync({player.UserId});
		identity[1].Player = player;

		return true, identity[1];
	end

	local identity;
	local Id = tonumber(argtext);

	if Id then
		local info = UserService:GetUserInfosByUserIdsAsync({Id});
		if not info[1] then
			return false, "User not found for argument " .. argname, "error";
		end
		identity = info[1];
	elseif FindPlayers(env, argtext, player)[1] then
		local plr = FindPlayers(env, argtext, player)[1];
		local info = UserService:GetUserInfosByUserIdsAsync({plr.UserId});
		if not info[1] then
			return false, "User not found for argument " .. argname, "error";
		end
		identity = info[1];
	else
		local ok, UserIdOrErr = pcall(function()
			return Players:GetUserIdFromNameAsync(argtext);
		end);

		if not ok then
			return false, "Failed to resolve username for argument " .. argname .. ": " .. tostring(UserIdOrErr), "error";
		end

		local info = UserService:GetUserInfosByUserIdsAsync({UserIdOrErr});
		if not info[1] then
			return false, "User not found for argument " .. argname, "error";
		end
		identity = info[1];
	end

	if not identity then
		return false, "User not found for argument " .. argname, "error";
	end
	
	identity.Name = identity.Username;
	identity.UserId = identity.Id;
	
	if Players:GetPlayerByUserId(identity.Id) then
		identity.Player = Players:GetPlayerByUserId(identity.Id);
	end;

	return true, identity;
end);

module.RegisterType("playeridentity", module.GetType("playeridentifier"));

-- Custom
module.RegisterType("custom", function(env, player, command, arg, args, argposition, sortedarguments, context)
	local argname = arg.Name;
	local argrequired = arg.Required;
	local argtext = args[argposition];

	local ValidSuccess, isValid = pcall(arg.IsValid, env, argtext, sortedarguments, player);
	if not ValidSuccess then
		return false, "Argument.IsValid error for " .. argname .. ": " .. tostring(isValid), "critical";
	end

	if not isValid then
		return false, "You need to provide a valid value for argument " .. argname, "warning";
	end

	if argtext then
		local FunctionSuccess, Output = pcall(arg.Function, env, argtext, sortedarguments, player);
		if not FunctionSuccess then
			return false, "Argument.Function error for " .. argname .. ": " .. tostring(Output), "critical";
		end
		return true, Output;
	end

	if argrequired then
		return false, "You need to provide a valid value for argument " .. argname, "warning";
	end

	local DefaultSuccess, DefaultValue = pcall(arg.Default, env, argtext, sortedarguments, player);
	if not DefaultSuccess then
		return false, "Argument.Default error for " .. argname .. ": " .. tostring(DefaultValue), "error";
	end

	return true, DefaultValue;
end);

return module;
