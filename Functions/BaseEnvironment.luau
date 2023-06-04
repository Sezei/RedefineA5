local env = {
	-- Version info
	NxEngine = {
		BuildId = 91;
	};

	-- In-game Data
	Data = {
		Logs = {
			Errors = {}; 	-- Template: {time, error}
			Chat = {};		-- Template: {time, playerid, message}
			Commands = {};	-- Template: {time, playerid, source, command}
			Joins = {};		-- Template: {time, playerid, followed?}
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