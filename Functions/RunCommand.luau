local Types = require(script:WaitForChild("Types"));

local function ArgSplit(str: string) : {string}
	local args: {string} = {};
	local inquote = false;
	local current = "";

	for i = 1, #str do
		local char = str:sub(i, i);
		if char == '"' then
			inquote = not inquote;
		elseif char == " " and not inquote then
			table.insert(args, current);
			current = "";
		else
			current ..= char;
		end
	end

	table.insert(args, current);
	return args;
end

local sortedqualifiers; -- To be sorted later.

local function Fail(env, player: Player, Message: string, Options: {[any]: any}?)
	env:Notify(player, Message, Options or {
		Type = "error";
		Client = true;
	});
	return false;
end

type Chatlog = {
	Time:number;
	UserId:number;
	Message:string;
};

type Qualifier = {
	name:string;
	methods:{[string]:string};
	maximumstrictness:number;
	identifier:any;
};

export type Command = {
	Disabled:boolean?;
};

local function ParseCommandKeys(env, player: Player, args: {string})
	local commandkeys = {};

	for i = #args, 1, -1 do
		local arg = args[i];
		if arg:sub(1, 2) == "--" then
			local key = arg:sub(3);
			local value: any = true;

			if key == "" then
				env:Notify(player, "You have entered an invalid key; Ignoring key.", {
					Type = "warning";
					Client = true;
				});
				table.remove(args, i);
				continue
			end

			if key:find("=") then
				local split = key:split("=");
				key = split[1];
				value = split[2];

				if key == "" then
					env:Notify(player, "You have entered an invalid key; Ignoring key.", {
						Type = "warning";
						Client = true;
					});
					table.remove(args, i);
					continue
				end

				if value == "" then
					env:Notify(player, "You have entered an invalid value for key " .. key .. "; Ignoring value.", {
						Type = "warning";
						Client = true;
					});
					table.remove(args, i);
					continue
				end
			end

			commandkeys[string.lower(key)] = tonumber(value) or value;
			table.remove(args, i);
		end
	end

	return commandkeys, args;
end

local function CooldownCheck(env, player: Player, command)
	if command.Cooldown > 0 then
		if not (type(command.LastRun) == "number") then command.LastRun = 0 end;
		if command.LastRun + command.Cooldown > tick() then
			env:Notify(player, "This command is on cooldown. You can run it again in " .. math.floor((command.LastRun + command.Cooldown) - tick()) .. " seconds.", {
				Type = "warning";
				Client = true;
			});
			return false;
		end
	end

	if command.UserCooldown > 0 then
		if not (type(command.LastRunBy) == "table") then command.LastRunBy = {} end;
		if command.LastRunBy[player.UserId] and command.LastRunBy[player.UserId] + command.UserCooldown > tick() then
			env:Notify(player, "This command is on cooldown for you. You can run it again in " .. math.floor((command.LastRunBy[player.UserId] + command.UserCooldown) - tick()) .. " seconds.", {
				Type = "warning";
				Client = true;
			});
			return false;
		end
	end

	return true;
end

local function BuildSortedArguments(env, player: Player, command, args: {string})
	local sortedarguments = {};

	if type(command.Arguments) == "string" and command.Arguments:lower() == "rawinput" then
		-- Just send the raw input to the command, and instead of having Args['name'], it will be Args[1], etc.
		if env.Data.Settings.EnableDebug then
			print(`Redefine:A Debug | {command.Name} is a RAWINPUT type command.`)
		end
		return true, args;
	end

	if type(command.Arguments) ~= "table" then
		return true, sortedarguments;
	end

	for argposition, arg in command.Arguments do
		local context = {}; -- Prepare a context thing for when we might need it.
		local ok, value, errType, errProps = Types.Parse(env, player, command, arg, args, argposition, sortedarguments, context);
		if not ok then
			return Fail(env, player, tostring(value), errProps or {
				Type = errType or "error";
				Client = true;
			});
		end

		sortedarguments[arg.Name] = value;
	end

	return true, sortedarguments;
end

local function runCommand(env, player, msg, console)
	local success: boolean, err: string? = pcall(function()
		if msg:sub(1, #env.Data.Settings.Prefix) ~= env.Data.Settings.Prefix and msg:sub(1, 4) ~= "r:a_" then
			return;
		end

		local args;
		if msg:sub(1, 4) == "r:a_" then
			args = ArgSplit(msg:sub(5));
		else
			args = ArgSplit(msg:sub(#env.Data.Settings.Prefix + 1));
		end;

		local cmd = string.lower(args[1] or "");
		table.remove(args, 1);

		-- PreProcess hooks
		for _, v in env.Hooks.Command.PreProcess do
			local ok, response = pcall(function()
				return v(env, player, cmd, args, console);
			end);

			if not ok then
				warn("Redefine:A | PreProcess Hook error: " .. tostring(response));
				table.insert(env.Data.Logs.Errors, {os.time(), `Hook Failed: PreProcess: with error; {response}`});
				continue;
			end

			if type(response) == "nil" then continue end;

			if type(response) == "table" then
				if response.Cancel then
					return;
				end
				if response.Command then
					cmd = response.Command;
				end
				if response.Arguments then
					args = response.Arguments; -- keep it a table
				end
			elseif type(response) == "boolean" then
				if response == false then
					return;
				end
			end
		end

		if not (env.Commands[cmd] or env.Aliases[cmd]) then
			return;
		end

		local command = env.Commands[cmd] or env.Aliases[cmd];

		if command.Disabled and not command.DisallowDisabling then
			return Fail(env, player, "This command is disabled.", {
				Type = "error";
				Client = true;
			});
		end

		local ignorelevel = false;
		local response = command.RunCapability and command.RunCapability(env, player);

		if type(response) ~= "nil" then
			ignorelevel = true;

			if response ~= true then
				if type(response) == "string" then
					return Fail(env, player, "You are not allowed to run this command: " .. response, {Type = "error"; Client = true;});
				else
					return Fail(env, player, "You are not allowed to run this command.", {Type = "error"; Client = true;});
				end
			end
		end

		if command.Level > env:GetLevel(player) and not ignorelevel then
			return Fail(env, player, "You are not allowed to run this command.", {Type = "error"; Client = true;});
		end

		-- Early cooldown check
		if not CooldownCheck(env, player, command) then
			return;
		end

		local commandkeys;
		commandkeys, args = ParseCommandKeys(env, player, args);

		if env.Data.Settings.EnableDebug then
			print(`Redefine:A Debug | Processing {command.Name}'s argument type`)
		end

		local okArgs, sortedarguments = BuildSortedArguments(env, player, command, args);
		if not okArgs then
			return;
		end

		if env.Data.Settings.EnableDebug then
			print(`Redefine:A Debug | Processed {command.Name}`)
		end

		-- KEEP LOGGING AS IS!
		if not commandkeys["silent"] then
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
				delay = math.clamp(delay, 0, 60);
				task.wait(delay);
			else
				env:Notify(player, "Couldn't delay the command due to the value being a non-number.", {
					Type = "warning";
					Client = true;
				});
			end
		end

		-- Last minute cooldown check
		if not CooldownCheck(env, player, command) then
			return;
		end

		for _, v in env.Hooks.Command.PostProcess do
			local ok, response2 = pcall(function()
				return v(env, player, cmd, sortedarguments, console);
			end);

			if not ok then
				warn("Redefine:A | PostProcess Hook error: " .. tostring(response2));
				table.insert(env.Data.Logs.Errors, {os.time(), `Hook Failed: PostProcess: with error; {response2}`});
				continue;
			end

			if type(response2) == "nil" then continue end;

			if type(response2) == "table" then
				if response2.Cancel then
					return;
				end
				if response2.Arguments then
					sortedarguments = response2.Arguments;
				end
			elseif type(response2) == "boolean" then
				if response2 == false then
					return;
				end
			end
		end

		if env.Data.Settings.EnableDebug then
			print(`Redefine:A Debug | Attempting to run thread with command {command.Name}, with ArgumentsType {type(command.Arguments)=='string' and string.lower(command.Arguments)=='rawinput' and 'RAWINPUT' or 'NORMAL'}`)
		end

		task.spawn(function()
			local successRun, ret;
			local clientsuccess, clientret;
			local compatibility = false;

			if (env.NanoCommands and env.NanoCommands[command.Name:lower()]) then
				compatibility = true;
				if sortedarguments[1] then
					table.insert(sortedarguments, 1, command.Name);
				end
				successRun, ret = pcall(function()
					return command.OnRun(player, sortedarguments, env);
				end)
			else
				if command.OnRun then
					successRun, ret = pcall(function()
						return command.OnRun(env, player, sortedarguments, commandkeys);
					end)
				end

				if command.OnClientRun then
					local okInvoke, r1, r2 = pcall(function()
						return env.RemoteFunction:InvokeClient(player, "RunClientCommand", command.Name:lower(), sortedarguments, commandkeys);
					end)

					if okInvoke then
						clientsuccess, clientret = r1, r2;
					else
						clientsuccess = false;
						clientret = tostring(r1);
					end
				end
			end

			if clientsuccess ~= nil then
				if not clientsuccess and clientret then
					env.RemoteEvent:FireClient(player, "Notify", "Client-sided error while running " .. cmd .. "; " .. tostring(clientret), {
						Type = "error";
						Image = "http://www.roblox.com/asset/?id=6031071053";
						Options = {"Got it"};
					});
				end
			end

			if successRun == false then
				table.insert(env.Data.Logs.Errors, {os.time(), "Command Execution Failed: " .. cmd .. ' with error "' .. tostring(ret) .. '"'});
				if not compatibility then
					env.RemoteEvent:FireClient(player, "Notify", "An error has occured while attempting to run the command; " .. tostring(ret), {
						Type = "critical";
						Image = "http://www.roblox.com/asset/?id=6031071053";
						Options = {"Got it"};
					});
				else
					env.RemoteEvent:FireClient(player, "Notify", "Command is not compatible; " .. tostring(ret), {
						Type = "error";
						Image = "http://www.roblox.com/asset/?id=6026568192";
						Options = {"Got it"};
					});
				end;
				env.Signals.ErrorRaised:Fire("Command Execution Failed: " .. cmd .. ' with error "' .. tostring(ret) .. '"');
				return;
			end

			pcall(function()
				command.LastRun = tick();
				command.LastRunBy[player.UserId] = tick();
			end)

			if ret or typeof(ret) == "boolean" then
				local runcontext = {
					Command = command;
					Compatibility = compatibility;
					Returned = ret;
					Keys = commandkeys;
					Arguments = sortedarguments;
					Executor = player;
					Source = console and "console" or "chat";
				};

				env.Signals.CommandProcessed:Fire(player, command.Name, runcontext);

				for _, v in env.Hooks.Command.Ran do
					local okHook, hookErr = pcall(function()
						return v(env, runcontext);
					end);

					if not okHook then
						warn("Redefine:A | CommandRan Hook error: " .. tostring(hookErr));
						table.insert(env.Data.Logs.Errors, {os.time(), `Hook Failed: CommandRan: with error; {hookErr}`});
					end
				end

				if typeof(ret) == "boolean" then
					ret = {
						Success = ret;
						Message = ret and ("Command " .. command.Name .. " returned a success") or ("Command " .. command.Name .. " returned a failure");
					};
				end;

				if ret.Success == true then
					env.RemoteEvent:FireClient(player, "Notify", ret.Message, {Timeout = 10;});
				elseif ret.Success == false then
					env.RemoteEvent:FireClient(player, "Notify", ret.Message, {Type = "warning"; Timeout = 10;});
				end
			else
				env.Signals.CommandProcessed:Fire(player, command.Name, {
					Command = command;
					Returned = {Success = true; Message = "The command has not returned anything."};
					Keys = commandkeys;
					Arguments = sortedarguments;
					Source = console and "console" or "chat";
				});

				if compatibility then
					print("Command returned without a response");
				end
			end
		end);

		return true;
	end);

	if not success then
		env:Notify(player, "An error has occured while attempting to run the command; " .. tostring(err), {
			Type = "critical";
			Image = "http://www.roblox.com/asset/?id=6031071053";
			Timeout = 30;
		});
	end
end

return function(env, player: Player, msg: string, console: boolean)
	Types.ConnectEnv(env);
	
	if env.Data.Settings.EnableDebug then
		print(`Redefine:A Debug | Received {msg} as CONSOLE={tostring(console==true)}`)
	end

	msg = env.BetterBasics.string.fixnewchat(msg);

	local originalmsg = msg;
	if not console then
		env.Signals.ChatProcessed:Fire(player, originalmsg);
	end

	if msg:sub(1, 2) == "/e" and env.Data.Settings.SilentEnabled then
		console = true;
		msg = msg:sub(4) :: string;
	end

	if not console then
		table.insert(
			env.Data.Logs.Chat,
			{Time = os.time(); UserId = player.UserId; Message = msg} :: Chatlog
		);
	end

	if env.Data.Settings.Splitter and not console then
		local Splits = string.split(msg, env.Data.Settings.Splitter);
		for _, Command in Splits do
			runCommand(env, player, Command, console);
		end
	else
		runCommand(env, player, msg, console);
	end
end
