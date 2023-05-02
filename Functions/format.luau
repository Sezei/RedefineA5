local mod = {}

local function stringfind(str,find) -- An unoptimised function to find a specific set of characters because string.find can't find some characters.
	local Spaced = str:split(" ");
	for i,v in pairs(Spaced) do
		if v == find then
			return i;
		end
	end
end

function mod:_NxWrapper() -- This is the function we use for env.format; _NxWrapper is a wrapper function that should return the function that we want to use as env.format.
	self.Placeholders = {
		-- The placeholders are stored in a table, with the key being the placeholder name, and the value being the placeholder value
		-- The value can be a string, number, boolean or a function, but not a table; The function must also return a string, number or boolean at all times
		-- The function will be called with the environment as the first argument, and the player as the second argument

		-- Example placeholder;
		-- ["placeholder"] = "value";
		-- ["placeholder"] = function(env,player) return "value" end;

		-- Environment-based placeholders
		nx_totaljoins = function(env,_)
			return #env.Data.Logs.Joins;
		end;
		nx_onlineadmins = function(env,_)
			-- Get the amount of admins online
			local admins = 0;
			for _,v in pairs(game.Players:GetPlayers()) do
				if env.Data.Ingame.Admins[v.UserId] then
					admins = admins + 1;
				end
			end
			return admins;
		end;
		nx_commands = function(env,_)
			return #env.Commands;
		end;

		-- Server-based placeholders
		game_name = function(_)
			return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name;
		end;
		game_creator = function(_)
			if game.CreatorType == Enum.CreatorType.Group then
				return game:GetService("GroupService"):GetGroupInfoAsync(game.CreatorId).Name;
			else
				return game:GetService("Players"):GetNameFromUserIdAsync(game.CreatorId);
			end
		end;
		game_creatorid = function(_)
			return game.CreatorId;
		end;
		game_onlineplayers = function(_)
			return #game.Players:GetPlayers();
		end;
		game_maxplayers = function(_)
			return game.Players.MaxPlayers;
		end;
		game_uptime = function(_)
			return math.floor(os.clock());
		end;
		game_version = function(_)
			return game.PlaceVersion;
		end;

		-- Player-based placeholders
		player_name = function(_,player)
			if not player then return "[MISSING:player]" end
			return player.Name;
		end;
		player_userid = function(_,player)
			if not player then return "[MISSING:player]" end
			return player.UserId;
		end;
		player_displayname = function(_,player)
			if not player then return "[MISSING:player]" end
			return player.DisplayName;
		end;
		player_accountage = function(_,player)
			if not player then return "[MISSING:player]" end
			return player.AccountAge;
		end;
		player_health = function(_,player)
			if not player then return "[MISSING:player]" end
			if player.Character and player.Character:FindFirstChild("Humanoid") then
				return player.Character.Humanoid.Health;
			else
				return 0;
			end
		end;
		player_maxhealth = function(_,player)
			if not player then return "[MISSING:player]" end
			if player.Character and player.Character:FindFirstChild("Humanoid") then
				return player.Character.Humanoid.MaxHealth;
			else
				return 0;
			end
		end;
		player_team = function(_,player)
			if not player then return "[MISSING:player]" end
			if player.Team then
				return player.Team.Name;
			else
				return "Neutral";
			end
		end;

		-- Player-based placeholders that use the environment
		player_level = function(env,player)
			if not player then return "[MISSING:player]" end
			return env:GetLevel(player);
		end;
		player_isadmin = function(env,player)
			if not player then return "[MISSING:player]" end
			return env:GetLevel(player) >= 2;
		end;

		-- Generic placeholders
		papi_dice = function(_)
			return math.random(1,6);
		end;
		papi_timenow = function(_)
			return os.date("%H:%M:%S");
		end;
		papi_date = function(_)
			return os.date("%d/%m/%Y");
		end;
		papi_randomnumber = function(_)
			return math.random(1,100);
		end;

		-- Static placeholders
		papi_version = "1.0.3";
		papi_engine = "NxEngine2";
		papi_engineversion = self.NxEngine.BuildId;
		nx_version = self.NxEngine.BuildId;
	};

	return function(originscript,replacementdata,player)
		local s:string = tostring(originscript);

		for old,new in pairs(replacementdata) do -- First replace the needed stuff.
			s = s:gsub("<"..old..">",tostring(new));
		end

		-- Attempt to find placeholders; They are marked with %placeholder%
		for placeholder,value in pairs(self.Placeholders) do
			if s:find("<"..placeholder..">") then
				if type(value) == "function" then
					s = s:gsub("<"..placeholder..">",tostring(value(self,player)));
				else
					s = s:gsub("<"..placeholder..">",tostring(value));
				end
			end
		end

		return s;
	end;
end

return mod
