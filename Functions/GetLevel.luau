local Market = game:GetService("MarketplaceService"); 
local BadgeService = game:GetService("BadgeService"); 
local GroupService = game:GetService("GroupService"); 

local Cache = {}; -- TODO: Cache group ranks to avoid multiple calls to the Groups API.

return function(env, player)
	-- Online branch: player is a Player instance.
	if player and typeof(player) == "Instance" and player:IsA("Player") then
		if env.IsOwner(player) then
			return env.HighestLevel, true, true;
		end

		-- Attempt to fetch the player data.
		if env.Data.Settings.AutoRefresh then
			env.Data.Ingame.Admins = env.Data.Settings.Admins;
		end;
		local Admins = env.Data.Ingame.Admins;

		if not Admins then
			warn(`Redefine:A | An error has occurred attempting to get player level for ${player.DisplayName}! - No admins table was loaded.`);
			table.insert(env.Data.Logs.Errors, {os.time(),`Failed to catch {player.UserId}'s admin level - No admins table.`})
			return 0, false, false;
		end;
		local userId = player.UserId;
		local userName = player.Name;

		-- Initialize our best candidate variables.
		local bestLevel, bestBase, bestIsAdmin;
		local function updateCandidate(Level, Base, IsAdmin)
			if not bestLevel then
				bestLevel = Level; bestBase = Base; bestIsAdmin = IsAdmin;
			else
				--[[
				if Base and not bestBase then
					bestLevel = Level; bestBase = Base; bestIsAdmin = IsAdmin;
				elseif Base == bestBase and Level > bestLevel then
					bestLevel = Level; bestBase = Base; bestIsAdmin = IsAdmin;
				end;]]
				if Base then
					if not bestBase then
						bestLevel = Level;
						bestIsAdmin = IsAdmin;
					else
						if Level > bestLevel then
							bestLevel = Level;
							bestIsAdmin = IsAdmin;
						end
					end
					bestBase = true;
				else
					if bestBase then return end;
					if Level > bestLevel then
						bestLevel = Level;
						bestIsAdmin = IsAdmin;
					end
				end
			end;
		end;
		-- Process each admin rank.
		for levelStr, data in Admins do
			local level = tonumber(levelStr);
			for key, value in data do
				-- Immediate override for UserId or Name match.
				if type(value) == "number" and value == userId then
					return level, true, data.Admin or false;
				end;
				if type(value) == "string" and value == userName then
					return level, true, data.Admin or false;
				end;
				-- Process table entries (Temporary, Group, Gamepass, Badge, etc.).
				if type(value) == "table" then
					if type(value.Temporary) == "number" and value.Temporary == userId then
						updateCandidate(level, false, data.Admin or false);
						break;
					end;
					if type(value.GroupId) == "number" then
						for rank, isActive in pairs(value) do
							if type(rank) == "number" and isActive then
								local s, playerRank = pcall(player.GetRankInGroup, player, value.GroupId);
								if s and playerRank == rank then
									updateCandidate(level, not value.MarkAsTemporary, data.Admin or true);
								end;
							end;
						end;
					end;
					if type(value.GamepassId) == "number" then
						local s, ownsGamepass = pcall(Market.UserOwnsGamePassAsync, Market, userId, value.GamepassId);
						if s and ownsGamepass then
							updateCandidate(level, not value.MarkAsTemporary, data.Admin or false);
						end;
					end;
					if type(value.BadgeId) == "number" then
						local s, hasBadge = pcall(BadgeService.UserHasBadgeAsync, BadgeService, userId, value.BadgeId);
						if s and hasBadge then
							updateCandidate(level, not value.MarkAsTemporary, data.Admin or false);
						end;
					end;

					if env.Search(value, "and", true) then
						local conditionsMet = true;

						if value.VIPOwner then
							if not (game.PrivateServerOwnerId == userId) then
								conditionsMet = false;
							end;
						end;
						if value.Premium then
							if player.MembershipType ~= Enum.MembershipType.Premium then
								conditionsMet = false;
							end;
						end;
						if value.GamepassId then
							if not Market.UserOwnsGamePassAsync(userId, value.GamepassId) then
								conditionsMet = false;
							end;
						end;
						if value.BadgeId then
							if not BadgeService.UserHasBadgeAsync(userId, value.BadgeId) then
								conditionsMet = false;
							end;
						end;

						if conditionsMet then
							updateCandidate(level, not value.MarkAsTemporary, data.Admin or false);
						end;
					end
				end;
				-- Process special keys.
				if key == "VIPOwner" then
					if game.PrivateServerOwnerId == userId then
						updateCandidate(level, false, data.Admin or false);
					end;
				end;
				if key == "Premium" then
					if player.MembershipType == Enum.MembershipType.Premium then
						updateCandidate(level, false, data.Admin or false);
					end;
				end;
				if key == "Default" then
					updateCandidate(level, false, data.Admin or false);
				end;
			end;
		end;
		
		for _,v in env.Hooks.Level.Get do
			local success, response = pcall(function() return v(env, player, bestLevel or 0) end);
--																	             ^ expected level
			if not success then warn('Redefine:A | Level.Get Hook error: ' .. response); table.insert(env.Data.Logs.Errors, {os.time(),`Hook Failed: Level.Get: with error; {response}`}); continue end;
			if type(response)=='nil' then continue end;

			if type(response) == "table" then
				if not response.Level then continue end;
				if Admins[tostring(response.Level)] or Admins[response.Level] then
					bestLevel = tonumber(response.Level);
					bestBase = response.Base or bestBase;
					bestIsAdmin = response.Admin or bestIsAdmin;
				else
					warn('Redefine:A | Level.Get Hook failed: Invalid Admin Level '.. response.Level);
					table.insert(env.Data.Logs.Errors, {os.time(),`Hook Failed: Level.Get: Invalid Admin Level {response.Level}`}); continue
				end
			elseif type(response) == "number" then
				if Admins[tostring(response)] or Admins[response] then
					bestLevel = response
				else
					warn('Redefine:A | Level.Get Hook failed: Invalid Admin Level '.. response.Level);
					table.insert(env.Data.Logs.Errors, {os.time(),`Hook Failed: Level.Get: Invalid Admin Level {response.Level}`}); continue
				end
			else
				warn('Redefine:A | Level.Get Hook failed: Invalid Response Type');
				table.insert(env.Data.Logs.Errors, {os.time(),`Hook Failed: Level.Get: Invalid Response Type`}); continue
			end
		end;
		
		return bestLevel or 0, bestBase or false, bestIsAdmin or false;
		-- Offline branch: player is a string (username) or number (UserId).
	elseif player and (typeof(player) == "string" or typeof(player) == "number") then
		local s, ret = pcall(function()
			if env.IsOwner(player) then
				return {env.HighestLevel, true, true};
			end

			if typeof(player) == "string" then
				player = game.Players:GetUserIdFromNameAsync(player);
			end;
			local userId = player; -- now a numeric UserId
			-- Cache the player's group ranks.
			local PlayerGroupRanks = {};
			for _, Group in ipairs(GroupService:GetGroupsAsync(userId)) do
				PlayerGroupRanks[Group.Id] = Group.Rank;
			end;
			local Admins = env.Data.Ingame.Admins;
			if not Admins then
				warn(`Redefine:A | An error has occurred attempting to get player level for ${userId}!`);
				table.insert(env.Data.Logs.Errors, {os.time(),`Failed to catch {player.UserId}'s admin level - No admins table.`})
				return {0, false, false};
			end;
			-- Sanitize Admins table and determine the highest level.
			local userName = game.Players:GetNameFromUserIdAsync(userId);
			-- Initialize our best candidate variables.
			local bestLevel, bestBase, bestIsAdmin;
			local function updateCandidate(Level, Base, IsAdmin)
				if not bestLevel then
					bestLevel = Level; bestBase = Base; bestIsAdmin = IsAdmin;
				else
					if Base and not bestBase then
						bestLevel = Level; bestBase = Base; bestIsAdmin = IsAdmin;
					elseif Base == bestBase and Level > bestLevel then
						bestLevel = Level; bestBase = Base; bestIsAdmin = IsAdmin;
					end;
				end;
			end;
			for levelStr, data in pairs(Admins) do
				local level = tonumber(levelStr);
				for key, value in pairs(data) do
					if type(value) == "number" and value == userId then
						return {level, true, data.Admin or false};
					end;
					if type(value) == "string" and value == userName then
						return {level, true, data.Admin or false};
					end;
					if type(value) == "table" then
						if type(value.Temporary) == "number" and value.Temporary == userId then
							updateCandidate(level, false, data.Admin or false);
							break;
						end;
						if type(value.GroupId) == "number" then
							for rank, isActive in pairs(value) do
								if type(rank) == "number" and isActive then
									if PlayerGroupRanks[value.GroupId] == rank then
										updateCandidate(level, not value.MarkAsTemporary, data.Admin or true);
									end;
								end;
							end;
						end;
						if type(value.GamepassId) == "number" then
							if Market:UserOwnsGamePassAsync(userId, value.GamepassId) then
								updateCandidate(level, not value.MarkAsTemporary, data.Admin or false);
							end;
						end;
						if type(value.BadgeId) == "number" then
							if BadgeService:UserHasBadgeAsync(userId, value.BadgeId) then
								updateCandidate(level, not value.MarkAsTemporary, data.Admin or false);
							end;
						end;
					end;
					if key == "VIPOwner" then
						if game.PrivateServerOwnerId == userId then
							updateCandidate(level, false, data.Admin or false);
						end;
					end;
					if key == "Default" then
						updateCandidate(level, false, data.Admin or false);
					end;
				end;
			end;
			return {bestLevel or 0, bestBase or false, bestIsAdmin or false};
		end);
		if s then
			return unpack(ret);
		else
			warn('An error has occurred while checking for ' .. tostring(player) .. '\'s offline level:' .. tostring(ret));
			table.insert(env.Data.Logs.Errors, {os.time(),`Failed to catch {player}'s admin level - {tostring(ret)}`});
			return 0, false, false;
		end;
	end;
end;
