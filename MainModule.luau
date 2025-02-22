-- Variables
local firstCall = true; -- Track if this is the first time the module is being called upon
local betabuild = false; -- Track if this is a beta build; Detected if the module contains a localscript named 'THIS IS A BETA BUILD'
local loadtime = os.clock(); -- Tracks the time it took to load the system
local loads = 3; -- 3 initial loads (errorcodes, baseenv, and signal)

-- Pre-Defined modules
local env = require(script.MainFunctions.BaseEnvironment); -- Load the base environment
local errorcodes = require(script.SharedFunctions.ErrorCodes); -- Load the error codes
local serializer = require(script.SharedFunctions.Serializer); -- Custom serializer

-- Dependencies
env.SignalHandler = require(script.Dependencies.Signal);

-- Add for command dependency check (dependencies = {"InStudio"})
env.NotInStudio = not game:GetService("RunService"):IsStudio();
env.InStudio = game:GetService("RunService"):IsStudio();

-- Check if we're in studio (avoid loading VCSDK)
if not env.InStudio then
	loads+=1;
	env.VCSDK = require(script.Dependencies.VCSDK); -- Load the VCSDK
end

-- Create essential signals
env.Signals = {};
env.Signals.JoinEvent = env.SignalHandler.new({Name = "JoinEvent"}) -- When a player is successfully handled, this will be fired; Event(PlayerInstance)
env.Signals.ChatProcessed = env.SignalHandler.new({Name = "ChatProcessed"}) -- When a chat message has been processed, this will be fired; Event(PlayerInstance, Message:string)
env.Signals.ErrorRaised = env.SignalHandler.new({Name = "ErrorRaised"}) -- When an error happens internally, this will be fired; Event(Error:string)

env.Signals.CommandRegistered = env.SignalHandler.new({Name = "CommandRegistered"})

-- DEPRECATED! Warn the user that this is deprecated if they use it.
env.Signals.CommandProcessed = env.SignalHandler.new({Name = "Processed"; Deprecated = true; Supersededby = 'env.Hooks.Command.Ran'}); -- When a command has already been ran, this will be fired.

-- Hooks; Can determine the output
env.Hooks = {
	Command = {};
};

env.Hooks.Command.PreProcess = {}; -- Runs if the engine thinks this is a command (message begins with the prefix) -> Environment, Executor:Player, Command:string, Arguments:table{string}, Console:boolean
env.Hooks.Command.PostProcess = {}; -- Runs after the command arguments are parsed -> Environment, Executor:Player, Command:CommandData, Arguments:table{parsed arguments}, Console:boolean
env.Hooks.Command.Ran = {}; -- Supersedes Signals.Processed; Runs after the command has been ran -> Environment, Executor:Player, RunContext:table{CommandData, Arguments, Keys, etc.}

env.Serializer = serializer;

local PostInit = {};

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

-- Create the events
table.insert(env.Data.Logs.System, {os.time(), nil, "Handling event creations"});
env.RemoteEvent = Instance.new("RemoteEvent");
env.RemoteEvent.Name = "NxRemoteEvent";
env.RemoteEvent.Parent = game.ReplicatedStorage;

env.RemoteFunction = Instance.new("RemoteFunction");
env.RemoteFunction.Name = "NxRemoteFunction";
env.RemoteFunction.Parent = game.ReplicatedStorage;

-- Load the main functions
for _,v in script.MainFunctions:GetChildren() do
	if v:IsA("ModuleScript") and v.Name ~= "BaseEnvironment" and v.Name ~= "ErrorCodes" then
		table.insert(env.Data.Logs.System, {os.time(), nil, "Module Compilation; "..v.Name});
		if betabuild then loads+=1 end
		local success,mod = pcall(function() return require(v) end)
		if success then
			if type(mod) == "table" and mod["_NxWrapper"] then
				env[v.Name] = mod._NxWrapper(env);
			elseif type(mod) == "table" and mod["_NxWrapper_PostInit"] then
				PostInit[v.Name] = mod._NxWrapper_PostInit;
			else
				env[v.Name] = mod;
			end
		else
			warn('Redefine:A | Failed to compile module: '..v.Name..' with error "'..mod..'"');
			table.insert(env.Data.Logs.Errors,{os.time(),"Module Compilation Failed: "..v.Name..' with error "'..mod..'"'});
		end
	end;
end

-- Load the main commands
for _,v in script.MainCommands:GetChildren() do
	if v:IsA("ModuleScript") then
		table.insert(env.Data.Logs.System, {os.time(), nil, "Module Compilation; "..v.Name});
		if betabuild then loads+=1 end
		local success,mod = pcall(function() return require(v) end)
		if success then
			if mod.IsADebugCommand and game.PlaceId ~= 2413178408 then continue end
			env:RegisterCommand(mod, v);
		else
			warn('Redefine:A | Failed to compile command: '..v.Name..' with error "'..mod..'"');
			table.insert(env.Data.Logs.Errors,{os.time(),"Command Compilation Failed: "..v.Name..' with error "'..mod..'"'});
		end
	end
end

env.RemoteFunction.OnServerInvoke = function(player, key, args)
	if key == "GetCommands" then
		local Commands = {};

		-- Get the commands
		for k,v in env.Commands do
			Commands[k] = v;
		end

		-- Get the aliases
		for k,v in env.Aliases do
			Commands[k] = v;
		end

		-- Return the commands
		return Commands;
	elseif key == "GetMethod" then
		print(env.Data.Settings);
		return env.Data.Settings.QualifierMethod
	elseif key == "GetLevel" then
		return env:GetLevel(game:GetService("Players"):GetPlayerByUserId(args));
	end
end

env.RedefineAUI = env.MainModule.RedefineAUI;

if firstCall then
	return function(Loader:Script,Settings:{[string]:any?})
		if firstCall==false then return end;
		firstCall = false
		table.insert(env.Data.Logs.System, {os.time(), nil, "Handling load."});
		if not (typeof(Loader) == "Instance") then error("Loader must be an instance") end
		if not Loader:IsA("Script") then error("Loader must be a script") end
		-- Check if there's a settings module
		
		Settings.RemoteTrap = nil; -- NO NONNONONONO
		
		if Settings then
			env.Data.BaseSettings = Settings;

			if not env.Data then env.Data = {} end;
			if not env.Data.Settings then env.Data.Settings = {} end;
			if type(Settings) == "table" then
				for i,v in Settings do
					env.Data.Settings[i] = v;
				end
			end

			env.Data.Settings = env.ValidateSettings(env.Data.Settings);

			env.Data.Ingame.Admins = env.Data.Settings.Admins;
			env.HighestLevel = 1;
			for Level, _ in env.Data.Ingame.Admins do
				Level = tonumber(Level);

				if Level > env.HighestLevel then
					env.HighestLevel = Level;
				end
			end
		else
			error("Redefine:A | BaseSettings were not found while loading! Ceasing load.");
		end

		env.Storage = env.Datastore(Settings.DatastoreKey, env);
		env.PersistStorage = env.Datastore(Settings.DatastoreKey..'_persist', env, {nocache=true;nosandbox=true});

		local data = env.PersistStorage:Load('Settings'):wait().Data;

		if not data then
			local saveTime = os.clock()
			env.PersistStorage:Save('Settings', env.ValidateSettings(Settings)):wait(); -- dont continue until finished saving
			print('Settings saved in '..os.clock()-saveTime)
			env.Data.Settings = Settings;
			print(env.Data.Settings)
		else
			data = env.ValidateSettings(data);
			--merge tables (specifically the Admins table)
			for Level,LevelData in data.Admins do
				LevelData.GroupName = Settings.Admins[tonumber(Level)].GroupName;
				LevelData.Admin = Settings.Admins[tonumber(Level)].Admin;
				
				for k,v in LevelData do
					if tonumber(k) and type(v) == 'table' then
						LevelData[k] = nil;
					end
				end
				
				for k,v in Settings.Admins[tonumber(Level)] do
					if type(v) == 'number' or type(v) == 'string' then
						if not env.Search(LevelData, v) then
							table.insert(LevelData, v);
						end
					end;
					
					if type(v) == 'table' then
						LevelData[k] = v;
					end;
				end
			end
			
			env.Data.Settings = data;
			print(env.Data.Settings);
		end


		-- Load the user's functions (if there are any)
		local function LoadModules()
			if Loader:FindFirstChild("Functions") then
				for _,v in Loader.Functions:GetChildren() do
					if v:IsA("ModuleScript") then
						table.insert(env.Data.Logs.System, {os.time(), nil, "Module Compilation; "..v.Name});
						if betabuild then loads+=1 end
						local success,mod = pcall(function() return require(v) end)
						if success then
							if type(mod) == "table" and mod["_NxWrapper"] then
								env[v.Name] = mod._NxWrapper(env);
							elseif type(mod) == "table" and mod["_NxWrapper_PostInit"] then
								PostInit[v.Name] = mod._NxWrapper_PostInit;
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

			-- Load the MAIN shared functions
			for _,v in script.SharedFunctions:GetChildren() do
				if v:IsA("ModuleScript") then
					table.insert(env.Data.Logs.System, {os.time(), nil, "Module Compilation; "..v.Name});
					v:Clone().Parent = env.RedefineAUI.Main;

					if betabuild then loads+=1 end
					local success,mod = pcall(function() return require(v) end)
					if success then
						if type(mod) == "table" and mod["_NxWrapper"] then
							env[v.Name] = mod._NxWrapper(env);
						elseif type(mod) == "table" and mod["_NxWrapper_PostInit"] then
							PostInit[v.Name] = mod._NxWrapper_PostInit;
						else
							env[v.Name] = mod;
						end
					else
						warn('Redefine:A | Failed to compile module: '..v.Name..' with error "'..mod..'"');
						table.insert(env.Data.Logs.Errors,{os.time(),"Module Compilation Failed: "..v.Name..' with error "'..mod..'"'});
					end
				end
			end

			if Loader:FindFirstChild("Themes") then
				for _,Theme in Loader.Themes:GetChildren() do
					if script.Themes:FindFirstChild(Theme.Name) then
						warn("Redefine:A | Overwritten a theme! - "..Theme.Name);

						script.Themes:FindFirstChild(Theme.Name):Destroy();
					end

					Theme.Parent = script.Themes;

					if Theme:FindFirstChild("_Server") then
						if Theme['_Server']:IsA("ModuleScript") then
							local success,mod = pcall(function() return require(Theme['_Server']) end)
							if success then
								if type(mod) == "table" and mod["_NxWrapper"] then
									mod._NxWrapper(env);
								elseif type(mod) == "table" and mod["_NxWrapper_PostInit"] then
									warn("Redefine:A | PostInit is not supported for Theme modules.");
								end
							else
								warn('Redefine:A | Failed to compile module: _Server (Server-side Theme module) with error "'..mod..'"');
								table.insert(env.Data.Logs.Errors,{os.time(),"Module Compilation Failed: _Server (Server-side Theme module) with error \""..mod..'"'});
							end
						end
					end
				end
			end

			-- Load the user's commands (if there are any)
			if Loader:FindFirstChild("Commands") then
				--Meta-Categories
				if Loader.Commands:FindFirstChild("_VIPOnly") then
					if game.PrivateServerOwnerId ~= 0 then
						for _,Module in Loader.Commands._VIPOnly do
							Module:Clone().Parent = Loader.Commands;
						end
					end;
					Loader.Commands._VIPOnly:Destroy();
				end
				if Loader.Commands:FindFirstChild("_Disabled") then
					Loader.Commands._Disabled:Destroy();
				end

				--Support for actual categories will be added eventually. I promise. ;p

				local FakeCommands = Loader.Commands:Clone();
				FakeCommands.Parent = game:GetService("ReplicatedStorage");
				FakeCommands.Name = 'RA5_Commands';
				
				-- clone main commands too
				for _,Command in script.MainCommands:GetChildren() do
					Command:Clone().Parent = FakeCommands;
				end
				
				for _,v in Loader.Commands:GetChildren() do
					if v:IsA("ModuleScript") then
						table.insert(env.Data.Logs.System, {os.time(), nil, "Module Compilation; "..v.Name});
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
									mod.Description = '(NANO); '..(mod.Description.Short or 'No Description Provided.');
									mod.Arguments = mod.Fields;

									for _,v in mod.Arguments do
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
									for _,v in mod.Credits do
										if not env.Data.Credits[v] then
											env.Data.Credits[v] = true;
										end
									end

									continue; -- Skip the entire section that comes after this
								end;
							end

							env:RegisterCommand(mod, v);
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

		-- PostInit modules
		for k,mod in PostInit do
			env[k] = mod(env);
		end

		-- RelevelCommands
		task.spawn(function()
			for _,v in env.Commands do
				if Settings.RelevelCommands[v.Name] then
					v.Level = Settings.RelevelCommands[v.Name];
				end
			end
		end)

		env.GlobalBanlist = {};

		task.spawn(function()
			table.insert(env.Data.Logs.System, {os.time(), nil, "Updating banlist"});

			local suc,dat = pcall(env.CloudAPI.Get,"/redefinea/banlist");
			if suc and dat and dat.success then
				env.GlobalBanlist = dat;
			else
				warn("Failed to update the global banlist! Is HTTPService enabled?");
			end

			while task.wait(30) do
				-- Check the banlist again to see if any bans have updated.
				table.insert(env.Data.Logs.System, {os.time(), nil, "Updating banlist"});
				local suc,dat = pcall(env.CloudAPI.Get,"/redefinea/banlist");
				if suc and dat and dat.success then
					env.GlobalBanlist = dat;
				else
					warn("Failed to update the global banlist!");
				end
			end
		end)

		game.Players.PlayerAdded:Connect(function(player) -- Add a join event
			table.insert(env.Data.Logs.System, {os.time(), nil, "Handling "..player.UserId});
			env:HandleJoin(player);
		end);
		for _,player in game.Players:GetPlayers() do -- Check for already existing players
			table.insert(env.Data.Logs.System, {os.time(), nil, "Handling "..player.UserId});
			env:HandleJoin(player);
		end

		-- Add a few select functions to the shared environment (shared.RedefineA)
		_G.RedefineA = true; -- Mark it as true so _G users know Redefine:A is in-game.
		shared.RedefineA = { -- Create the shared environment
			GetLevel = function(player)
				return env:GetLevel(player);
			end;
			Notify = function(Player, Text, Options)
				return env:Notify(Player, Text, Options);
			end;
			Signals = env.Signals; -- Add the signals; This might be a risky move due to the fact that it returns an unprotected table.
		};

		-- return env; -- Return the environment after the loading is done; Not recommended for the vanilla build but do whatever if you're forking this. It's your game/system.
	end
else
	return shared.RedefineA;
end
