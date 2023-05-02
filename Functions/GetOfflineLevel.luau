local Market = game:GetService("MarketplaceService");

return function(env, userid)
	-- Check if the provided player is a player instance.
	if userid and typeof(userid) == "number" then
		-- Check if the player is the game owner.
		-- Check if the game is created by a user or a group.
		if game.CreatorType == Enum.CreatorType.User and userid == game.CreatorId then
			return #env.Data.Settings.Admins, true; -- Return the highest level and mark as a base admin.
		elseif game.CreatorType == Enum.CreatorType.Group then
			local group = game:GetService("GroupService"):GetGroupInfoAsync(game.CreatorId);
			if group and group.Owner.Id == userid then
				return #env.Data.Settings.Admins, true; -- Return the highest level and mark as a base admin.
			end
		end

		local FoundBase = false;
		local FoundLevel = 0;
		local Set = false;


		local function GetLevel(DataTable)
			for Level, Data in pairs(DataTable) do
				if Set then continue end;
				for key, value in pairs(Data) do
					-- Check for UserId match
					if type(value) == "number" and value == userid then
						if FoundLevel < Level then
							FoundLevel = Level;
						end;
						FoundBase = true;
					end;
					-- Check for Name match
					if type(value) == "string" and value == game:GetService("Players"):GetNameFromUserIdAsync(userid) then
						if FoundLevel < Level then
							FoundLevel = Level;
						end;
						FoundBase = true;
					end;

					-- Check Groups and Gamepasses
					if type(value) == "table" then
						if type(value.Temporary) == "number" then
							-- Added from SetLevel!
							if value.Temporary == userid then
								FoundLevel = Level;
								FoundBase = false;
								Set = true;
								break;
							end
						end

						if type(value.GamepassId) == "number" then
							-- Found a Gamepass table! Check if the player owns the gamepass.
							if Market:UserOwnsGamePassAsync(userid, value.GamepassId) then
								if FoundLevel < Level then
									FoundLevel = Level;
									FoundBase = not value.MarkAsTemporary;
								end;
							end;
						end;
					end;

					-- Check for the default flag.
					if key == "Default" then
						if FoundLevel < Level then
							FoundLevel = Level;
						end;
						FoundBase = value;
					end;
				end;
			end;

			return FoundLevel, FoundBase;
		end

		-- Attempt to fetch the player data from in-game data.
		local FoundLevel, FoundBase = GetLevel(env.Data.Ingame.Admins);

		-- Attempt to fetch the player data from the settings.
		if not FoundBase then
			FoundLevel, FoundBase = GetLevel(env.Data.Settings.Admins);
		end

		-- Return the found level and base admin status.
		return FoundLevel, FoundBase;
	end
end
