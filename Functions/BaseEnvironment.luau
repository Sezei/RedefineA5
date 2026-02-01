-- This file defines the base environment for the game. It contains version information, in-game data, variables, and instances.
local GroupService = game:GetService("GroupService");
local OwnerId;

local env = {
	-- Version info
	NxEngine = {
		BuildId = 134;
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
		Ingame = {Admins = {}; Bans = {}; Gagged = {}};
	};

	-- Variables
	Commands = {};
	Aliases = {};
	Plugins = {};

	-- Instances
	MainModule = script.Parent.Parent;
}

function env.Search(targetArray: {any}, query: any, lower: boolean?)
	for k,v in (targetArray) do -- ignore key: we need the value itself
		if lower and typeof(v) == 'string' then
			if string.lower(v) == string.lower(query) then
				return k
			end
		elseif tostring(v) == tostring(query) then
			return k
		end
	end
end

function env.CloneTable(array)
	if typeof(array) == 'table' then
		local clone = {}
		for i,v in array do
			if type(v) == "table" then
				clone[i] = env.CloneTable(v)
			else
				clone[i] = v
			end
		end
		return clone
	else
		return array;
	end
end

function env.IsOwner(Player:Player|number)
	if typeof(Player) == 'Instance' then -- for some reason setting typeof()=='player' isn't valid, so 'Instance' is the only way to check
		if game.CreatorType == Enum.CreatorType.User and Player.UserId == game.CreatorId then
			return true
		elseif game.CreatorType == Enum.CreatorType.Group and Player:IsInGroupAsync(game.CreatorId) then
			local s, r = pcall(Player.GetRankInGroupAsync, Player, game.CreatorId);
			if s and r == 255 then
				return true
			end;
		end

		return false
	else
		if game.CreatorType == Enum.CreatorType.User and Player == game.CreatorId then
			return true
		elseif game.CreatorType == Enum.CreatorType.User then
			return false -- dont waste precious time
		end

		local s, r = pcall(function()
			OwnerId = OwnerId or GroupService:GetGroupInfoAsync(game.CreatorId).Owner.Id; -- query this bag of yielding piece of-- only once
			return OwnerId == Player;
		end)

		if s then
			return r;
		end;

		return false
	end
end

return env