-- Variables
local firstCall = true; -- Track if this is the first time the module is being called upon
local betabuild = false; -- Track if this is a beta build; Detected if the module contains a localscript named 'THIS IS A BETA BUILD'
local loadtime = os.clock(); -- Tracks the time it took to load the system
local loads = 5; -- 5 initial loads (errorcodes, baseenv, signal and VCSDK (twice))

-- Pre-Defined modules
local env = require(script.MainFunctions.BaseEnvironment); -- Load the base environment
local errorcodes = require(script.MainFunctions.ErrorCodes); -- Load the error codes

-- Dependencies
env.SignalHandler = require(script.Dependencies.Signal);

-- Check if we're in studio (avoid loading VCSDK)
if not game:GetService("RunService"):IsStudio() then
	local VCSDK_Source = require(script.Dependencies.VCSDK); -- Thank you AsynchronousMatrix for granting permission to use this.
	env.VCSDK = require(VCSDK_Source)
end

-- Add for dependency check
env.NotInStudio = not game:GetService("RunService"):IsStudio();
env.InStudio = game:GetService("RunService"):IsStudio();

-- Create essential signals
env.Signals = {};
env.Signals.JoinEvent = env.SignalHandler.new({Name = "JoinEvent"}) -- When a player is successfully handled, this will be fired; Event(PlayerInstance)
env.Signals.ChatProcessed = env.SignalHandler.new({Name = "ChatProcessed"}) -- When a chat message has been processed, this will be fired; Event(PlayerInstance, Message:string)
env.Signals.ErrorRaised = env.SignalHandler.new({Name = "ErrorRaised"}) -- When an error happens internally, this will be fired; Event(Error:string)

-- DEPRECATED! Warn the user that this is deprecated if they use it.
env.Signals.Processed = env.SignalHandler.new({Name = "Processed"; Deprecated = true; Supersededby = 'env.Hooks.Command.Ran'}); -- When a command has already been ran, this will be fired.


-- Hooks; Can determine the output
env.Hooks = {
	Command = {};
};

env.Hooks.Command.PreProcess = {}; -- Runs if the engine thinks this is a command (message begins with the prefix) -> Environment, Executor:Player, Command:string, Arguments:table{string}, Console:boolean
env.Hooks.Command.PostProcess = {}; -- Runs after the command arguments are parsed -> Environment, Executor:Player, Command:CommandData, Arguments:table{parsed arguments}, Console:boolean
env.Hooks.Command.Ran = {}; -- Supersedes Signals.Processed; Runs after the command has been ran -> Environment, Executor:Player, RunContext:table{CommandData, Arguments, Keys, etc.}

-- Check to see if this is a betabuild
if script:FindFirstChild("THIS IS A BETA BUILD!") then
	betabuild = true;
end;

-- Add a few Environment functions
function env.warn(code, ...)
	if tonumber(code) then
		warn("Redefine:A | Error "..code.." - "..errorcodes:ResolveCode(code).." | ",...)
	else
		warn("Redefine:A | ",...)
	end
end

-- Load the main functions
for _,v in pairs(script.MainFunctions:GetChildren()) do
	if v:IsA("ModuleScript") and v.Name ~= "BaseEnvironment" and v.Name ~= "ErrorCodes" then
		if betabuild then loads+=1 end
		local success,mod = pcall(function() return require(v) end)
		if success then
			if type(mod) == "table" and mod["_NxWrapper"] then
				env[v.Name] = mod._NxWrapper(env);
			else
				env[v.Name] = mod;
			end
		else
			warn('Redefine:A | Failed to compile module: '..v.Name..' with error "'..mod..'"');
			table.insert(env.Data.Logs.Errors,{os.time(),"Module Compilation Failed: "..v.Name..' with error "'..mod..'"'});
		end
	end
end

-- Load the Shared functions too
for _,v in pairs(script.SharedFunctions:GetChildren()) do
	if v:IsA("ModuleScript") then
		v:Clone().Parent = script.RedefineAUI.Main;

		if betabuild then loads+=1 end
		local success,mod = pcall(function() return require(v) end)
		if success then
			if type(mod) == "table" and mod["_NxWrapper"] then
				env[v.Name] = mod._NxWrapper(env);
			else
				env[v.Name] = mod;
			end
		else
			warn('Redefine:A | Failed to compile module: '..v.Name..' with error "'..mod..'"');
			table.insert(env.Data.Logs.Errors,{os.time(),"Module Compilation Failed: "..v.Name..' with error "'..mod..'"'});
		end
	end
end

-- Load the main commands
for _,v in pairs(script.MainCommands:GetChildren()) do
	if v:IsA("ModuleScript") then
		if betabuild then loads+=1 end
		local success,mod = pcall(function() return require(v) end)
		if success then
			local sanity = env:CommandSC(mod, v);
			local load = true;

			-- Sanity check the returned command data
			if not sanity then
				table.insert(env.Data.Logs.Errors,{os.time(),"Command Sanity Check Failed: "..v.Name});
				load = false;
				continue;
			end

			-- Check the dependencies
			if mod.Dependencies then
				for _,dependency in pairs(mod.Dependencies) do
					if not env[dependency] then
						warn('Redefine:A | Command "'..v.Name..'" has a dependency on "'..dependency..'" which is not loaded and/or does not exist; Skipping...');
						table.insert(env.Data.Logs.Errors,{os.time(),"Command Dependency Check Failed: "..v.Name..' with dependency "'..dependency..'"'});
						load = false;
						continue;
					end
				end
			end;

			if env.Commands[mod.Name] then
				if env.Commands[v.Name].DisallowOverwrite then
					warn('Redefine:A | Command "'..v.Name..'" has overwrite protection and cannot be overwritten; Skipping...');
					load = false;
					continue;
				else
					warn('Redefine:A | Command "'..v.Name..'" is being overwritten!')
				end
			end
			if not (type(env.Commands) == "table") then env.Commands = {} end

			if load then
				env.Commands[string.lower(mod.Name)] = mod;

				-- There is a mod.OnLoad?
				if type(mod.OnLoad) == "function" then
					mod.OnLoad(env)
				end

				-- Add the aliases
				for _,v in pairs(mod.Aliases) do
					env.Aliases[string.lower(v)] = mod;
				end
			end
		else
			warn('Redefine:A | Failed to compile command: '..v.Name..' with error "'..mod..'"');
			table.insert(env.Data.Logs.Errors,{os.time(),"Command Compilation Failed: "..v.Name..' with error "'..mod..'"'});
		end
	end
end

-- Create the events
env.RemoteEvent = Instance.new("RemoteEvent");
env.RemoteEvent.Name = "NxRemoteEvent";
env.RemoteEvent.Parent = game.ReplicatedStorage;

env.RemoteFunction = Instance.new("RemoteFunction");
env.RemoteFunction.Name = "NxRemoteFunction";
env.RemoteFunction.Parent = game.ReplicatedStorage;

env.RemoteFunction.OnServerInvoke = function(player, key, args)
	if key == "GetCommands" then
		local Commands = {};

		-- Get the commands
		for k,v in pairs(env.Commands) do
			Commands[k] = v;
		end

		-- Get the aliases
		for k,v in pairs(env.Aliases) do
			Commands[k] = v;
		end

		-- Return the commands
		return Commands;
	elseif key == "GetMethod" then
		return env.Data.Settings.QualifierMethod
	elseif key == "GetLevel" then
		return env:GetLevel(game:GetService("Players"):GetPlayerByUserId(args));
	end
end

env["☕🗿"] = "coffee moai (hi aaron)";

if firstCall then
	firstCall = false
	return function(Loader:Script,Settings:{[string]:any?})
		if not (typeof(Loader) == "Instance") then error("Loader must be an instance") end
		if not Loader:IsA("Script") then error("Loader must be a script") end
		-- Check if there's a settings module
		if Settings then
			if not env.Data then env.Data = {} end;
			if not env.Data.Settings then env.Data.Settings = {} end;
			if type(Settings) == "table" then
				for i,v in pairs(Settings) do
					env.Data.Settings[i] = v;
				end
			end

			env.Data.Ingame.Admins = env.Data.Settings.Admins;
		else
			error("Settings were not found while loading!");
		end

		env.Storage = env.Datastore(Settings.DatastoreKey, env);

		-- Load the user's functions (if there are any)
		local function LoadModules()
			if Loader:FindFirstChild("Functions") then
				for _,v in pairs(Loader.Functions:GetChildren()) do
					if v:IsA("ModuleScript") then
						if betabuild then loads+=1 end
						local success,mod = pcall(function() return require(v) end)
						if success then
							if type(mod) == "table" and mod["_NxWrapper"] then
								env[v.Name] = mod._NxWrapper(env);
							else
								env[v.Name] = mod;
							end
						else
							warn('Redefine:A | Failed to compile function: '..v.Name..' with error "'..mod..'"');
							table.insert(env.Data.Logs.Errors,{os.time(),"Function Compilation Failed: "..v.Name..' with error "'..mod..'"'});
						end
					end
				end
			end

			-- Load the user's commands (if there are any)
			if Loader:FindFirstChild("Commands") then
				local FakeCommands = Loader.Commands:Clone();
				FakeCommands.Parent = game:GetService("ReplicatedStorage");
				FakeCommands.Name = 'RA5_Commands';
				for _,v in pairs(Loader.Commands:GetChildren()) do
					if v:IsA("ModuleScript") then
						if betabuild then loads+=1 end
						local success,mod = pcall(function() return require(v) end)
						if success then

							-- WE MIGHT NEED TO CHECK FOR NANO COMPATIBILITY HERE
							do
								if type(mod.InGui) ~= "nil" then -- Nano Commands support
									-- WE ARE USING A NANO COMMAND!!
									if not (type(env.NanoCommands) == "table") then env.NanoCommands = {} end

									if env.Commands[mod.Name] then
										if env.Commands[v.Name].DisallowOverwrite then
											warn('Redefine:A | Command "'..v.Name..'" has overwrite protection and cannot be overwritten; Skipping...');
											continue;
										else
											warn('Redefine:A | Command "'..v.Name..'" is being overwritten with a compatibility-mode command!')
										end
									end

									mod.Level = 3; -- Assume it's an Admin command rather than a Moderator one; Better be safe than sorry!
									mod.Credits = mod.Credit;
									mod.Description = '(NANO); '..mod.Description.Short or '(NANO); No Description Provided.';
									mod.Arguments = mod.Fields;

									for _,v in pairs(mod.Arguments) do
										v.Name = v.Internal;
									end

									local SC = env:CommandSC(mod, v);

									if not SC then
										warn('Redefine:A | Failed to compile Nano command '..v.Name..'.');
										continue;
									end

									env.NanoCommands[string.lower(mod.Name)] = true;
									env.Commands[string.lower(mod.Name)] = mod;

									-- Add the credits
									if not (type(env.Data.Credits) == "table") then env.Data.Credits = {} end
									for _,v in pairs(mod.Credits) do
										if not env.Data.Credits[v] then
											env.Data.Credits[v] = true;
										end
									end

									continue; -- Skip the entire section that comes after this
								elseif type(mod.ModName) ~= 'nil' then -- R:A4 Backwards Compatibility
									if not (type(env.RA4C) == "table") then 
										env.RA4C = {};
									end

									if env.Commands[mod.ModName] then
										if env.Commands[v.Name].DisallowOverwrite then
											warn('Redefine:A | Command "'..v.Name..'" has overwrite protection and cannot be overwritten; Skipping...');
											continue;
										else
											warn('Redefine:A | Command "'..v.Name..'" is being overwritten with a compatibility-mode command!')
										end
									end

									mod.Name = mod.ModName;
									mod.Description = '(R:A4); ' .. mod.ModName .. " " .. mod.Usage;
									mod.Arguments = 'rawinput'; -- R:A4 didn't support argument typing, so we'll just emulate a rawinput command.
									mod.Aliases = mod.Alias;

									local SC = env:CommandSC(mod, v);

									if not SC then
										warn('Redefine:A | Failed to compile R:A4 command '..v.Name..'.');
										continue;
									end

									env.RA4C[string.lower(mod.Name)] = true;
									env.Commands[string.lower(mod.Name)] = mod;

									continue; -- Skip the entire section that comes after this
								end;
							end

							local load = true;
							local sanity = env:CommandSC(mod, v);

							-- Sanity check the returned command data
							if not sanity then
								table.insert(env.Data.Logs.Errors,{os.time(),"Command Sanity Check Failed: "..v.Name});
								load = false;
								continue;
							end

							-- Check the dependencies
							if mod.Dependencies then
								for _,dependency in pairs(mod.Dependencies) do
									if not env[dependency] then
										warn('Redefine:A | Command "'..v.Name..'" has a dependency on "'..dependency..'" which is not loaded and/or does not exist; Skipping...');
										table.insert(env.Data.Logs.Errors,{os.time(),"Command Dependency Check Failed: "..v.Name..' with dependency "'..dependency..'"'});
										load = false;
										continue;
									end
								end
							end

							if env.Commands[mod.Name] then
								if env.Commands[mod.Name].DisallowOverwrite then
									warn('Redefine:A | Command "'..mod.Name..'" has overwrite protection and cannot be overwritten; Skipping...');
									load = false;
									continue;
								else
									warn('Redefine:A | Command "'..mod.Name..'" is being overwritten!')
								end
							end
							if not (type(env.Commands) == "table") then env.Commands = {} end

							if load then
								env.Commands[string.lower(mod.Name)] = mod;
								if type(mod.OnLoad) == "function" then
									mod.OnLoad(env)
								end

								-- Add the credits
								if not (type(env.Data.Credits) == "table") then env.Data.Credits = {} end
								for _,v in pairs(mod.Credits) do
									if not env.Data.Credits[v] then
										env.Data.Credits[v] = true;
									end
								end

								-- Add the aliases
								for _,v in pairs(mod.Aliases) do
									env.Aliases[string.lower(v)] = mod;
								end
							end
						else
							warn('Redefine:A | Failed to compile command: '..v.Name..' with error "'..mod..'"');
							table.insert(env.Data.Logs.Errors,{os.time(),"Command Compilation Failed: "..v.Name..' with error "'..mod..'"'});
						end
					end
				end
			end

			if Settings.UnsafeLoading then
				print("Redefine:A | Finished UnsafeLoad; Total loads: "..loads.."; Total time; "..(os.clock()-loadtime).." seconds.")
			end

			return true;
		end

		if Settings.UnsafeLoading then
			warn("Redefine:A | Loaded "..loads.." modules so far using UnsafeLoading; Took "..(os.clock()-loadtime).." seconds!")
		else
			LoadModules();
			print("Redefine:A | Loaded "..loads.." modules in total; Took "..(os.clock()-loadtime).." seconds!");
		end

		-- RelevelCommands
		task.spawn(function()
			for _,v in pairs(env.Commands) do
				if Settings.RelevelCommands[v.Name] then
					v.Level = Settings.RelevelCommands[v.Name];
				end
			end
		end)

		env.GlobalBanlist = {};

		local LastCheck = tick(); -- Get time
		task.spawn(function()
			local suc,dat = pcall(env.CloudAPI.Get,"/redefinea/banlist");
			if suc and dat and dat.success then
				env.GlobalBanlist = dat;
			else
				warn("Failed to update the global banlist! Is HTTPService enabled?");
			end

			while task.wait() do
				if (LastCheck + 20) <= tick() then
					-- Check the banlist again to see if any bans have updated.
					local suc,dat = pcall(env.CloudAPI.Get,"/redefinea/banlist");
					if suc and dat and dat.success then
						env.GlobalBanlist = dat;
					else
						warn("Failed to update the global banlist!");
					end
					LastCheck = tick();
				end
			end
		end)

		game.Players.PlayerAdded:Connect(function(player) -- Add a join event
			env:HandleJoin(player);
		end);
		for _,player in pairs(game.Players:GetPlayers()) do -- Check for already existing players
			env:HandleJoin(player);
		end

		-- Add a few select functions to the shared environment (shared.RedefineA)
		_G.RedefineA = true; -- Mark it as true so _G users know Redefine:A is in-game.
		shared.RedefineA = { -- Create the shared environment
			GetLevel = function(player)
				return env:GetLevel(player);
			end;
			Signals = env.Signals; -- Add the signals; This might be a risky move due to the fact that it returns an unprotected table.
		};

		-- return env; -- Return the environment after the loading is done
	end
else
	return nil;
end
