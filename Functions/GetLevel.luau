local Market = game:GetService("MarketplaceService");
local BadgeService = game:GetService("BadgeService");

return function(env, player)
	-- Check if the provided player is a player instance.
	if player and typeof(player) == "Instance" and player:IsA("Player") then
		-- Check if the player is the game owner.
		-- Check if the game is created by a user or a group.

		-- Attempt to fetch the player data.
		local Admins = env.Data.Ingame.Admins;

		if not Admins then
			warn(`An error has occurred attempting to get player level for {player.DisplayName}!`);
			return 0, false, false;
		end

		-- Sanity check the stuff! Sometimes people don't do stuff the intended way!!
		local HighestLevel = 0;
		for Level, _ in pairs(Admins) do
			if type(Level) ~= "number" then
				warn(`Removed an admin rank from the Admins list for being invalid; {Level}`);
				Admins[Level] = nil;
			end

			if Level > HighestLevel then
				HighestLevel = Level;
			end
		end

		if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
			return HighestLevel, true, true; -- Return the highest level and mark as a base admin.
		elseif game.CreatorType == Enum.CreatorType.Group and player:IsInGroup(game.CreatorId) then
			if player:GetRankInGroup(game.CreatorId) == 255 then
				return HighestLevel, true, true; -- Return the highest level and mark as a base admin.
			end
		end

		local FoundBase = false;
		local FoundLevel = 0;
		local IsAdmin = false;
		local Set = false;

		for Level, Data in pairs(Admins) do
			if Set then continue end;
			for key, value in pairs(Data) do

				if FoundBase == true and FoundLevel >= Level then -- Skips the entire check
					continue;
				end;

				-- Check for UserId match
				-- User overrides everything else.
				if type(value) == "number" and value == player.UserId then
					return Level, FoundBase, IsAdmin;
				end;
				-- Check for Name match
				if type(value) == "string" and value == player.Name then
					return Level, FoundBase, IsAdmin;
				end;

				-- Check Groups and Gamepasses
				if type(value) == "table" then
					if type(value.Temporary) == "number" then
						-- Added from SetLevel!
						if value.Temporary == player.UserId then
							FoundLevel = Level;
							FoundBase = false;
							IsAdmin = Data.Admin or false;
							Set = true;
							break;
						end
					end

					if type(value.GroupId) == "number" then
						-- Found a Group table! Check if the player is considered an admin within the group.
						for Rank, IsActive in pairs(value) do
							if type(Rank) == "number" and IsActive then
								if player:GetRankInGroup(value.GroupId) >= Rank then
									if FoundLevel < Level then
										FoundLevel = Level;
										FoundBase = not value.MarkAsTemporary;
										IsAdmin = Data.Admin or true;
									end;
								end;
							end
						end;
					end;

					if type(value.GamepassId) == "number" then
						-- Found a Gamepass table! Check if the player owns the gamepass.
						if Market:UserOwnsGamePassAsync(player.UserId, value.GamepassId) then
							if FoundLevel < Level then
								FoundLevel = Level;
								FoundBase = not value.MarkAsTemporary;
								IsAdmin = Data.Admin or false;
							end;
						end;
					end;

					if type(value.BadgeId) == "number" then
						-- 🐟 don't ask
						if BadgeService:UserHasBadgeAsync(player.UserId, value.BadgeId) then
							if FoundLevel < Level then
								FoundLevel = Level;
								FoundBase = not value.MarkAsTemporary;
								IsAdmin = Data.Admin or false;
							end
						end
					end
				end;

				if key == "VIPOwner" then -- Gives VIP server owners admin based on the variable.
					if game.PrivateServerOwnerId == player.UserId then
						if FoundLevel < Level then
							FoundLevel = Level;
							FoundBase = false;
							IsAdmin = Data.Admin or false;
						end;
					end;
				end;

				-- Check for premium.
				if key == "Premium" then
					if player.MembershipType == Enum.MembershipType.Premium then
						if FoundLevel < Level then
							FoundLevel = Level;
							IsAdmin = Data.Admin or false;
						end
						FoundBase = value;
					end;
				end;

				-- Check for the default flag.
				if key == "Default" then
					if FoundLevel < Level then
						FoundLevel = Level;
						IsAdmin = Data.Admin or false;
						FoundBase = false; -- default will never be a base admin.
					end;
				end;
			end;
		end;

		return FoundLevel, FoundBase, IsAdmin;
	end
end
