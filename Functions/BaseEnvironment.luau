-- This file defines the base environment for the game. It contains version information, in-game data, variables, and instances.

local env = {
	-- Version info
	NxEngine = {
		BuildId = 117;
	};

	-- In-game Data
	Data = {
		Logs = {
			Errors = {}; 	-- Template: {time, error}
			Chat = {};		-- Template: {time, playerid, message}
			Commands = {};	-- Template: {time, playerid, source, command}
			Joins = {};		-- Template: {time, playerid, followed?}
			System = {};	-- Template: {time, origin?, event}
		};
		Ingame = {Admins = {}; Bans = {}};
	};

	-- Variables
	Commands = {};
	Aliases = {};

	-- Instances
	MainModule = script.Parent.Parent;
}

return env