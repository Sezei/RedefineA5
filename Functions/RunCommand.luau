local function ArgSplit(str)
	local args = {};
	local inquote = false;
	local current = "";
	for i = 1,#str do
		local char = str:sub(i,i);
		if char == '"' then
			inquote = not inquote;
		elseif char == " " and not inquote then
			table.insert(args,current);
			current = "";
		else
			current = current..char;
		end
	end
	table.insert(args,current);
	return args;
end

local sortedqualifiers; -- To be sorted later.

local function FindPlayers(env, Names, Executor) -- Function that finds players by name or displayname.
	if string.len(Names) == 0 then return nil end -- If the name is empty, return nil.

	-- Check if there are any ',' in the name. If there are, split the name into multiple names.
	local names = string.split(Names,",")
	local matches = {} -- Table that will contain all the matches.
	-- Loop through all the players.
	for _,Name in pairs(names) do
		for _,v in next,game:GetService("Players"):GetPlayers() do
			local matched = false; -- If a player has been matched, this will be set to true so they won't be matched again and again.

			-- Check if the executor started the Name with #; This will use the players' Local PlayerId (#1 = First Join, #2 = Second join, etc.)
			-- The players have a 'ra_LocalId' attribute that is set when they join the game.
			if Name:sub(1,1) == "#" then
				local LocalId = v:GetAttribute("ra_LocalId");
				if LocalId then
					if tonumber(Name:sub(2)) == LocalId then
						matches[#matches+1] = v
						matched = true;
					end
				end
			end

			-- Because of the '@'; prioritise checking the username first before the displayname; Alongside that, it will also not check for the displayname.
			local s1 = string.lower("@"..v.Name)
			if s1:sub(1, #Name) == string.lower(Name) then
				if not matched then
					matches[#matches+1] = v
				end
			end

			-- Check for the displayname.
			local s1 = string.lower(v.DisplayName)
			if s1:sub(1, #Name) == string.lower(Name) then
				if not matched then
					matches[#matches+1] = v
				end
			end

			-- Check for the username.
			local s1 = string.lower(v.Name)
			if s1:sub(1, #Name) == string.lower(Name) then
				if not matched then
					matches[#matches+1] = v
				end
			end
		end

		-- Check the sortedqualifiers table for any matches; If there are any, handle them and add them to the matches table.
		for method, qualifier in pairs(sortedqualifiers) do
			if string.lower(Name) == string.lower(method) then
				local Players = game:GetService("Players"):GetPlayers();
				local MatchedPlayers = qualifier.identifier(env, Players, Executor);
				for _, Player in pairs(MatchedPlayers) do
					table.insert(matches, Player);
				end;
			end;
		end;
	end

	-- Remove duplicates.
	local newmatches = {}
	for _,v in pairs(matches) do
		if not table.find(newmatches,v) then
			table.insert(newmatches,v)
		end
	end

	return newmatches -- Return the matches.
end

return function(env, player, msg, console)
	-- Check if the player used /e for the command.
	local originalmsg = msg;
	if not console then
		env.Signals.ChatProcessed:Fire(player,originalmsg)
	end

	if msg:sub(1,2) == "/e" and env.Data.Settings.SilentEnabled then
		console = true; -- Pretend like it was sent from a command bar.
		msg = msg:sub(3);
	end

	if not console then
		table.insert(env.Data.Logs.Chat,{os.time(),player.UserId,msg})
	end
	-- Since we got access to the env, we can start sorting the qualifiers.
	if not sortedqualifiers then
		local selectedmethod = string.lower(env.Data.Settings.QualifierMethod);
		if selectedmethod == "sm" then selectedmethod = "sourcemod"; end
		if selectedmethod == "mc" then selectedmethod = "minecraft"; end
		if selectedmethod == "s" then selectedmethod = "simple"; end

		sortedqualifiers = {};
		-- Check if the qualifier method is valid.
		if not (selectedmethod == "sourcemod" or selectedmethod == "minecraft" or selectedmethod == "simple") then
			warn("Invalid qualifier method selected. Defaulting to 'sourcemod'.");
			selectedmethod = "sourcemod";
		end;

		-- Loop through all the qualifiers to check if they have the selected method.
		for _, qualifier in pairs(env.Qualifiers) do
			if qualifier.methods[selectedmethod] then
				sortedqualifiers[qualifier.methods[selectedmethod]] = qualifier;
			end;
		end;
	end;

	local success, err = pcall(function()
		if msg:sub(1,#env.Data.Settings.Prefix) == env.Data.Settings.Prefix then
			local args = ArgSplit(msg:sub(#env.Data.Settings.Prefix+1));
			local cmd = string.lower(args[1]);
			table.remove(args,1);

			for _,v in pairs(env.Hooks.Command.PreProcess) do
				local success, response = pcall(function() return v(env, player, cmd, args, console) end);

				if not success then warn('Redefine:A | PreProcess Hook error: ' .. response); table.insert(env.Data.Logs.Errors, {os.time(),`Hook Failed: PreProcess: with error; {response}`}) end;
				if type(response)=='nil' then continue end;

				if type(response) == "table" then
					if response.Cancel then -- Cancel the command.
						return
					end
					if response.Command then -- Change the command
						cmd = response.Command
					end
					if response.Arguments then -- Change the arguments
						args = tostring(response.Arguments)
					end
				elseif type(response)=='boolean' then
					if response == false then -- Cancel the command.
						return
					end
				end;
			end;

			if env.Commands[cmd] or env.Aliases[cmd] then
				local command = env.Commands[cmd] or env.Aliases[cmd];
				-- Check what level the player is
				if command.Disabled and not command.DisallowDisabling then
					-- Warn the player that the command is disabled
					env:Notify(player,"This command is disabled.",{
						Type = "error";
					})
					return
				end

				local ignorelevel = false;

				local response = command.RunCapability(env, player);
				if type(response) ~= "nil" then
					-- It's being checked, ignore the level.
					ignorelevel = true;

					if response == true then
						-- The player has permission to run the command.
					else
						-- The player doesn't have permission to run the command.
						if type(response) == "string" then
							env:Notify(player,"You can't run this command: "..response,{
								Type = "error";
							})
						elseif type(response) == "boolean" then
							env:Notify(player,"You are not allowed to run this command.",{
								Type = "error";
							})
						end
						return
					end
				end;

				if command.Level > env:GetLevel(player) and not ignorelevel then
					env:Notify(player,"You are not allowed to run this command.",{
						Type = "error";
					})
					return
				end

				if command.Cooldown > 0 then
					if not (type(command.LastRun) == "number") then command.LastRun = 0 end
					if command.LastRun + command.Cooldown > tick() then
						env:Notify(player,"This command is on cooldown. You can run it again in "..math.floor((command.LastRun + command.Cooldown) - tick()).." seconds.",{
							Type = "warning";
						})
						return
					end

				end

				if command.UserCooldown > 0 then
					if not (type(command.LastRunBy) == "table") then command.LastRunBy = {} end
					if command.LastRunBy[player.UserId] and command.LastRunBy[player.UserId] + command.UserCooldown > tick() then
						env:Notify(player,"This command is on cooldown for you. You can run it again in "..math.floor((command.LastRunBy[player.UserId] + command.UserCooldown) - tick()).." seconds.",{
							Type = "warning";
						})
						return
					end
				end

				-- Sometimes the people can also add keys (For example, --silent) to the command, which can be used to change the way the command works.
				-- We can check if a command is a key by checking if it starts with a double-dash (--)
				-- Sometimes keys can also have values, for example, --silent=true
				-- We can check if a key has a value by checking if it contains an equals sign (=); But it must be a key first.

				-- For each key added, we remove it from the arguments table, and add it to the commandkeys table.
				local commandkeys = {};

				for i,arg in pairs(args) do
					if arg:sub(1,2) == "--" then
						-- It's a key!
						local key = arg:sub(3);
						local value = true;

						-- Check if it has a value
						if key:find("=") then
							local split = key:split("=");
							key = split[1];
							value = split[2];
							-- Check to see if the key is not empty
							if key == "" then
								env:Notify(player,"You have entered an invalid key; Ignoring key.",{
									Type = "warning";
								})
								table.remove(args,i);
								continue
							end

							-- Check to see if the value is not empty
							if value == "" then
								env:Notify(player,"You have entered an invalid value; Ignoring value.",{
									Type = "warning";
								})
								table.remove(args,i);
								continue
							end
						end

						commandkeys[string.lower(key)] = tonumber(value) or value; -- Convert the value to a number if it's a number; Otherwise, just use the value.
						table.remove(args,i);
					end
				end

				local sortedarguments = {};

				if type(command.Arguments) == 'string' and command.Arguments:lower() == 'rawinput' then
					-- Just send the raw input to the command, and instead of having Args['name'], it will be Args[1], etc.
					sortedarguments = args;
				elseif type(command.Arguments) == 'table' then
					for argposition,arg in pairs(command.Arguments) do
						-- Arguments are built like this;
					--[[
						Argument = {
							Name = "Name";
							Type = "Player(s)/SafePlayer(s)/Number/String";
							Required = true/false;
							Default = "Default"; -> Only applies to Number/String (There can't be a default value for a player)
						}
					]]

						local argtype = arg.Type:lower();
						local argname = arg.Name;
						local argrequired = arg.Required;
						local argdefault = arg.Default; -- If the argument is not required, this is the default value for it
						local argtext = args[argposition]; -- The text that the player has entered for the argument

						if argtype == "player" then -- If the argument type is player, then we need to find a player and return the argument as the player instance for the command to use
							if not argtext then
								-- If no text was provided, check if this is the last argument and if it is required
								if argrequired then
									-- If it is required, then warn the player that they need to provide a player
									env:Notify(player,"You need to provide a player for argument "..argname,{
										Type = "warning";
									});
									return
								elseif command.Arguments[argposition+1] then
									-- If it is not required, but there is another argument, then warn the player that they need to provide a player
									env:Notify(player,"You need to provide a player for argument "..argname,{
										Type = "warning";
									});
									return
								else
									-- If it is not required and there is no other argument, then use the player as the argument
									sortedarguments[argname] = player;
								end
							else
								local matches = FindPlayers(env,argtext,player);
								if #matches == 0 then
									env:Notify(player,"No player was found when searching for argument "..argname,{
										Type = "warning";
									});
									return
								elseif #matches == 1 then
									sortedarguments[argname] = matches[1];
								else
									-- Warn the player that multiple players were found
									env:Notify(player,"Multiple players were found when searching for argument "..argname..": Picked the first match.",{
										Type = "warning";
									});
									sortedarguments[argname] = matches[1];
								end
							end
						elseif argtype == "safeplayer" then -- If the argument type is safeplayer, then we need to find a player whose level is below the executor and return the argument as the player instance for the command to use.
							if not argtext then
								-- If no text was provided, check if this is the last argument and if it is required
								if argrequired then
									-- If it is required, then warn the player that they need to provide a player
									env:Notify(player,"You need to provide a player for argument "..argname,{
										Type = "warning";
									});
									return
								elseif command.Arguments[argposition+1] then
									-- If it is not required, but there is another argument, then warn the player that they need to provide a player
									env:Notify(player,"You need to provide a player for argument "..argname,{
										Type = "warning";
									});
									return
								else
									-- If it is not required and there is no other argument, then use the player as the argument
									sortedarguments[argname] = player;
								end
							else
								local matches = FindPlayers(env,argtext,player);
								if #matches == 0 then
									env:Notify(player,"No player was found when searching for argument "..argname,{
										Type = "warning";
									});
									return
								elseif #matches == 1 then
									if env:GetLevel(matches[1]) >= env:GetLevel(player) then
										env:Notify(player,"You can't use this command on a player with the same or higher level than you.",{
											Type = "error";
										});
										return
									end
									sortedarguments[argname] = matches[1];
								else
									-- Check every match to see if they are below the executor
									local safematches = {};
									for _,match in pairs(matches) do
										if env:GetLevel(match) < env:GetLevel(player) then
											table.insert(safematches,match);
										end
									end
									if #safematches == 0 then
										env:Notify(player,"No safe player was found when searching for argument "..argname,{
											Type = "warning";
										});
									elseif #safematches == 1 then
										sortedarguments[argname] = safematches[1];
									else
										-- Warn the player that multiple players were found
										env:Notify(player,"Multiple players were found when searching for argument "..argname..": Picked the first match.",{
											Type = "warning";
										});
										sortedarguments[argname] = safematches[1];
									end
								end
							end
						elseif argtype == "string" then
							-- Check if this is the last argument; If it is, assume that the rest of the message is the string
							if command.Arguments[argposition+1] then -- It is not the last argument.
								if argtext and argtext ~= "" and argtext ~= " " then
									sortedarguments[argname] = argtext;
								else
									if argrequired then
										env:Notify(player,"You need to provide a valid string for argument "..argname,{
											Type = "warning";
										});
										return
									else
										sortedarguments[argname] = argdefault;
									end
								end
							else -- It is the last argument.
								-- Concatenate the rest of the message into the string
								local string = "";
								for i = argposition,#args do
									string = string..args[i].." ";
								end
								string = string:sub(1,-2); -- Remove the last space
								sortedarguments[argname] = string;
							end

							-- Check if the sortedarguments[argname] is in one of the options; If yes, autocomplete it to match the option
							if arg.Options then
								if type(arg.Options) == "function" then
									-- Since the call itself is already protected with pcall, we don't need to pcall this function.
									arg.Options = arg.Options(sortedarguments[argname]);
								elseif type(arg.Options) == 'table' then
									local found = false;
									for _,v in pairs(arg.Options) do
										-- if v (the option) starts with the sortedarguments[argname] (the argument), then it is a match; Set found to the option
										if v:sub(1,#sortedarguments[argname]):lower() == sortedarguments[argname]:lower() then
											found = v;
											break;
										end
									end
									if found then
										-- Estimate that the player is trying to autocomplete the argument; Set the argument to the option
										sortedarguments[argname] = found;
									end
								end;
							end
						elseif argtype == "number" or argtype == "slider" then
							if argtext and tonumber(argtext) then
								sortedarguments[argname] = math.clamp(tonumber(argtext),arg.Minimum,arg.Maximum);
							else
								if argrequired then
									env:Notify(player,"You need to provide a valid number for argument "..argname,{
										Type = "warning";
									});
									return
								else
									sortedarguments[argname] = argdefault;
								end
							end
						elseif argtype == "boolean" then
							if argtext then
								if string.lower(argtext) == "true" then
									sortedarguments[argname] = true;
								elseif string.lower(argtext) == "false" then
									sortedarguments[argname] = false;
								else
									if argrequired then
										env:Notify(player,"You need to provide a valid boolean for argument "..argname,{
											Type = "warning";
										});
										return
									else
										sortedarguments[argname] = argdefault;
									end
								end
							else
								if argrequired then
									env:Notify(player,"You need to provide a valid boolean for argument "..argname,{
										Type = "warning";
									});
									return
								else
									sortedarguments[argname] = argdefault;
								end
							end
						elseif argtype == "color" then -- Colors are using the env.ColorLib(color) function
							if argtext then
								local color = env.ColorLib(argtext); -- Since the library **always** returns a color, we don't need to check if it is valid
								sortedarguments[argname] = color;
							elseif argrequired then
								env:Notify(player,"You need to provide a valid color for argument "..argname,{
									Type = "warning";
								});
								return
							else
								sortedarguments[argname] = argdefault;
							end
						elseif argtype == "players" then -- Like player, except returns a table of players instead of a singular one.
							if not argtext then
								-- If no text was provided, check if this is the last argument and if it is required
								if argrequired then
									-- If it is required, then warn the player that they need to provide a player
									env:Notify(player,"You need to provide a player for argument "..argname,{
										Type = "warning";
									});
									return
								elseif command.Arguments[argposition+1] then
									-- If it is not required, but there is another argument, then warn the player that they need to provide a player
									env:Notify(player,"You need to provide a player for argument "..argname,{
										Type = "warning";
									});
									return
								else
									-- If it is not required and there is no other argument, then use the player as the argument
									sortedarguments[argname] = {player};
								end
							else
								-- Text was provided; Check if it matches players.
								local matches = FindPlayers(env,argtext,player);
								if #matches == 0 then
									env:Notify(player,"No player was found when searching for argument "..argname,{
										Type = "warning";
									});
									return
								else
									sortedarguments[argname] = matches;
								end
							end
						elseif argtype == "playerlist" then -- Like players, except returns a string of player names instead of a table of players.
							if not argtext then
								-- If no text was provided, check if this is the last argument and if it is required
								if argrequired then
									-- If it is required, then warn the player that they need to provide a player
									env:Notify(player,"You need to provide a player for argument "..argname,{
										Type = "warning";
									});
									return
								elseif command.Arguments[argposition+1] then
									-- If it is not required, but there is another argument, then warn the player that they need to provide a player
									env:Notify(player,"You need to provide a player for argument "..argname,{
										Type = "warning";
									});
									return
								else
									-- If it is not required and there is no other argument, then use the player as the argument
									sortedarguments[argname] = player.Name;
								end
							else
								-- Text was provided; Check if it matches players.
								local matches = FindPlayers(env,argtext,player);
								if #matches == 0 then
									env:Notify(player,"No player was found when searching for argument "..argname,{
										Type = "warning";
									});
									return
								else
									local string = "";
									for _,match in pairs(matches) do
										string = string..match.Name..", ";
									end
									string = string:sub(1,-3); -- Remove the last comma and space
									sortedarguments[argname] = string;
								end
							end
						elseif argtype == "safeplayers" then -- Like safeplayer, except returns a table of matched players. Ignores players who are below the player's level.
							if not argtext then
								-- If no text was provided, check if this is the last argument and if it is required
								if argrequired then
									-- If it is required, then warn the player that they need to provide a player
									env:Notify(player,"You need to provide a player for argument "..argname,{
										Type = "warning";
									});
									return
								elseif command.Arguments[argposition+1] then
									-- If it is not required, but there is another argument, then warn the player that they need to provide a player
									env:Notify(player,"You need to provide a player for argument "..argname,{
										Type = "warning";
									});
									return
								else
									-- If it is not required and there is no other argument, then use the player as the argument
									sortedarguments[argname] = {player};
								end
							else
								-- Text was provided; Check if it matches players.
								local matches = FindPlayers(env,argtext,player);
								if #matches == 0 then
									env:Notify(player,"No player was found when searching for argument "..argname,{
										Type = "warning";
									});
									return
								else
									local safematches = {};
									for _,match in pairs(matches) do
										if env:GetLevel(match) >= env:GetLevel(player) then
											table.insert(safematches,match);
										end
									end
									if #safematches == 0 then
										env:Notify(player,"No player was found when searching for argument "..argname,{
											Type = "warning";
										});
										return
									else
										sortedarguments[argname] = safematches;
									end
								end
							end
						elseif argtype == "safeplayerlist" then -- Like safeplayers, except returns a string of player names instead of a table of players. Ignores players who are below the player's level.
							if not argtext then
								-- If no text was provided, check if this is the last argument and if it is required
								if argrequired then
									-- If it is required, then warn the player that they need to provide a player
									env:Notify(player,"You need to provide a player for argument "..argname,{
										Type = "warning";
									});
									return
								elseif command.Arguments[argposition+1] then
									-- If it is not required, but there is another argument, then warn the player that they need to provide a player
									env:Notify(player,"You need to provide a player for argument "..argname,{
										Type = "warning";
									});
									return
								else
									-- If it is not required and there is no other argument, then use the player as the argument
									sortedarguments[argname] = player.Name;
								end
							else
								-- Text was provided; Check if it matches players.
								local matches = FindPlayers(env,argtext,player);
								if #matches == 0 then
									env:Notify(player,"No player was found when searching for argument "..argname,{
										Type = "warning";
									});
									return
								else
									local safematches = {};
									for _,match in pairs(matches) do
										if env:GetLevel(match) >= env:GetLevel(player) then
											table.insert(safematches,match);
										end
									end
									if #safematches == 0 then
										env:Notify(player,"No player was found when searching for argument "..argname,{
											Type = "warning";
										});
										return
									else
										local string = "";
										for _,match in pairs(safematches) do
											string = string..match.Name..", ";
										end
										string = string:sub(1,-3); -- Remove the last comma and space
										sortedarguments[argname] = string;
									end
								end
							end
						end
					end
				end

				-- Add the command run to the logs; Check to see if the player added a --silent flag
				if not commandkeys["silent"] then
					-- If they did, then don't log the command
					table.insert(env.Data.Logs.Commands, {
						os.time();
						player.UserId;
						console and "console" or "chat";
						msg;
					});
				end

				-- Check to see if the player added a --delay flag; If they did, then delay the command
				if commandkeys["delay"] then
					local delay = tonumber(commandkeys["delay"]);
					if delay then
						delay = math.clamp(delay,0,60);
						task.wait(delay);
					end
				end

				-- Last minute cooldown check
				if command.Cooldown > 0 then
					if not (type(command.LastRun) == "number") then command.LastRun = 0 end
					if command.LastRun + command.Cooldown > tick() then
						env:Notify(player,"This command is on cooldown. You can run it again in "..math.floor((command.LastRun + command.Cooldown) - tick()).." seconds.",{
							Type = "warning";
						})
						return
					end

				end

				if command.UserCooldown > 0 then
					if not (type(command.LastRunBy) == "table") then command.LastRunBy = {} end
					if command.LastRunBy[player.UserId] and command.LastRunBy[player.UserId] + command.UserCooldown > tick() then
						env:Notify(player,"This command is on cooldown for you. You can run it again in "..math.floor((command.LastRunBy[player.UserId] + command.UserCooldown) - tick()).." seconds.",{
							Type = "warning";
						})
						return
					end
				end

				for _,v in pairs(env.Hooks.Command.PostProcess) do
					local success, response = pcall(function() return v(env, player, cmd, sortedarguments, console) end);
	
					if not success then warn('Redefine:A | PostProcess Hook error: ' .. response); table.insert(env.Data.Logs.Errors, {os.time(),`Hook Failed: PostProcess: with error; {response}`}) end;
					if type(response)=='nil' then continue end;
	
					if type(response) == "table" then
						if response.Cancel then -- Cancel the command.
							return
						end
						if response.Arguments then -- Change the arguments
							sortedarguments = response.Arguments
						end
					elseif type(response)=='boolean' then
						if response == false then -- Cancel the command.
							return
						end
					end;
				end;

				-- Run the command
				-- Check if the command is ran with compatibility mode
				local success,ret
				local compatibility = false;
				if (env.NanoCommands and env.NanoCommands[command.Name:lower()]) then
					compatibility = true;
					if sortedarguments[1] then
						table.insert(sortedarguments,1,command.Name);
					end
					success,ret = pcall(function() return command.OnRun(player, sortedarguments,env); end)
				else
					success,ret = pcall(function() return command.OnRun(env, player, sortedarguments,commandkeys); end)
				end;
				if not success then
					table.insert(env.Data.Logs.Errors,{os.time(),"Command Execution Failed: "..cmd..' with error "'..ret..'"'});
					if not compatibility then
						env.RemoteEvent:FireClient(player,"Notify","An error has occured while attempting to run the command; "..ret,{
							Type = "critical";
							Image = "http://www.roblox.com/asset/?id=6031071053";
							Options = {
								"Got it";
							};
						});
					else
						env.RemoteEvent:FireClient(player,"Notify","Command is not compatible; "..ret,{
							Type = "critical";
							Image = "http://www.roblox.com/asset/?id=6026568192";
							Options = {
								"Got it";
							};
						});
					end;
					env.Signals.ErrorRaised:Fire("Command Execution Failed: "..cmd..' with error "'..ret..'"');
				else
					pcall(function() -- Those are destined to fail if the command doesn't use cooldowns, but we don't want to crash if they don't; Doesn't do anything if the command doesn't use cooldowns.
						command.LastRun = tick();
						command.LastRunBy[player.UserId] = tick();
					end)

					if ret or typeof(ret)=='boolean' then
						local runcontext = {
							Command = command;
							Compatibility = compatibility;
							Returned = ret;
							Keys = commandkeys;
							Arguments = sortedarguments;
							Executor = player;
							Source = console and "console" or "chat";
						};
						-- Deprecated; Use Hooks.Command.Ran instead
						env.Signals.Processed:Fire(player, command.Name, runcontext);

						for _,v in pairs(env.Hooks.Command.Ran) do
							local success, error = pcall(function() return v(env, runcontext) end);
		
							if not success then warn('Redefine:A | CommandRan Hook error: ' .. error); table.insert(env.Data.Logs.Errors, {os.time(),`Hook Failed: CommandRan: with error; {error}`}) end;
						end

						if typeof(ret) == 'boolean' then
							ret = {
								Success = ret;
							}
							ret.Message = ret.Success and 'Command '..command.Name..' returned a success' or 'Command '..command.Name..' returned a failure';
						end;

						if ret.Success == true then
							env.RemoteEvent:FireClient(player,"Notify",ret.Message,{
								Timeout = 10;	
							});
						elseif ret.Success == false then
							env.RemoteEvent:FireClient(player,"Notify",ret.Message,{
								Type = "warning";
								Timeout = 10;
							});
						end
					else
						env.Signals.Processed:Fire(player, command.Name, {Command = command, Returned = {Success = true; Message = "The command has not returned anything."}, Keys = commandkeys, Arguments = sortedarguments, Source = console and "console" or "chat"});

						if compatibility then
							print("Command returned without a response");
						end
					end
				end
			end
		end
	end);

	if not success then
		env:Notify(player,"An error has occured while attempting to run the command; "..err,{
			Type = "critical";
			Image = "http://www.roblox.com/asset/?id=6031071053";
			Timeout = 30;
		});
	end
end