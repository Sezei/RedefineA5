return {
	{
		name = "all"; -- The qualifier name.
		methods = {
			sourcemod = "@all", -- The qualifier for the method.
			simple = "all",
			minecraft = "@a",
		};
		maximumstrictness = 1; -- The maximum strictness level that this qualifier can be used at. (0 = no strictness, 1 = strict, 2 = very strict)
		identifier = function(env, players, executor)
			return players; -- Return all players.
		end;
	};
	{
		name = "me";
		methods = {
			sourcemod = "@me",
			simple = "me",
			minecraft = "@p",
		};
		maximumstrictness = 2;
		identifier = function(env, players, executor)
			return {executor}; -- Return the executor.
		end;
	};
	{
		name = "friends";
		methods = {
			sourcemod = "@friends",
			simple = "friends",
			minecraft = "@f",
		};
		maximumstrictness = 1;
		identifier = function(env, players, executor)
			local friends = {};
			for _, player in pairs(players) do
				if player:IsFriendsWith(executor.UserId) then
					table.insert(friends, player);
				end;
			end;
			return friends; -- Return all players who are friends with executor
		end;
	};
	{
		name = "nonfriends";
		methods = {
			sourcemod = "@nonfriends",
			simple = "nonfriends",
			minecraft = "@nf",
		};
		maximumstrictness = 1;
		identifier = function(env, players, executor)
			local nonfriends = {};
			for _, player in pairs(players) do
				if not player:IsFriendsWith(executor.UserId) then
					table.insert(nonfriends, player);
				end;
			end;
			return nonfriends; -- Return all players not friends with executor
		end;
	};
	{
		name = "premiums";
		methods = {
			sourcemod = "@premiums",
			simple = "premiums",
		};
		maximumstrictness = 1;
		identifier = function(env, players, executor)
			local premiums = {};
			for _, player in pairs(players) do
				if player.MembershipType ~= Enum.MembershipType.None then
					table.insert(premiums, player);
				end;
			end;
			return premiums; -- Return all players who have a Premium membership
		end;
	};
	{
		name = "nonpremiums";
		methods = {
			sourcemod = "@nonpremiums",
			simple = "nonpremiums",
		};
		maximumstrictness = 1;
		identifier = function(env, players, executor)
			local nonpremiums = {};
			for _, player in pairs(players) do
				if player.MembershipType ~= Enum.MembershipType.None then
					table.insert(nonpremiums, player);
				end;
			end;
			return nonpremiums; -- Return all players who do not have a Premium membership
		end;
	};
	{
		name = "r6";
		methods = {
			sourcemod = "@r6",
			simple = "r6",
		};
		maximumstrictness = 1;
		identifier = function(env, players, executor)
			local r6 = {};
			for _, player in pairs(players) do
				local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.RigType == Enum.HumanoidRigType.R6 then
					table.insert(r6, player);
				end;
			end;
			return r6; -- Return all players who have a r6 rig type
		end;
	};
	{
		name = "r15";
		methods = {
			sourcemod = "@r15",
			simple = "r15",
		};
		maximumstrictness = 1;
		identifier = function(env, players, executor)
			local r15 = {};
			for _, player in pairs(players) do
				local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.RigType == Enum.HumanoidRigType.R15 then
					table.insert(r15, player);
				end;
			end;
			return r15; -- Return all players who have a r15 rig type
		end;
	};
	{
		name = "near";
		methods = {
			sourcemod = "@near",
			simple = "near",
		};
		maximumstrictness = 1;
		identifier = function(env, players, executor)
			-- Go through all players and find any players wihin 50 studs of the executor. (not including the executor)
			local near = {};
			for _, player in pairs(players) do
				if player ~= executor and (player.Character.PrimaryPart.Position - executor.Character.PrimaryPart.Position).magnitude <= 50 then
					table.insert(near, player);
				end
			end
			return near; -- Return all players who are near the executor
		end;
	};
	{
		name = "far";
		methods = {
			sourcemod = "@far",
			simple = "far",
		};
		maximumstrictness = 1;
		identifier = function(env, players, executor)
			-- Go through all players and find any players who are more than 50 studs away from the executor. (not including the executor)
			local far = {};
			for _, player in pairs(players) do
				if player ~= executor and (player.Character.PrimaryPart.Position - executor.Character.PrimaryPart.Position).magnitude >= 50 then
					table.insert(far, player);
				end
			end
			return far; -- Return all players who are far from the executor
		end
	};
	{
		name = "others";
		methods = {
			sourcemod = "@others",
			simple = "others",
			minecraft = "@e",
		};
		maximumstrictness = 1;
		identifier = function(env, players, executor)
			local others = {};
			for _, player in pairs(players) do
				if player ~= executor then
					table.insert(others, player);
				end;
			end;
			return others; -- Return all players except the executor.
		end;
	};
	{
		name = "admins";
		methods = {
			sourcemod = "@admins",
			simple = "admins",
		};
		maximumstrictness = 1;
		identifier = function(env, players, executor)
			if not env then return players; end -- If there is no environment, return all players.
			local admins = {};
			for _, player in pairs(players) do
				local _,_,isAdmin = env:GetLevel(player);
				if isAdmin then
					table.insert(admins, player);
				end;
			end;
			return admins; -- Return all players with an admin level of 2 or higher.
		end;
	};
	{
		name = "nonadmins";
		methods = {
			sourcemod = "@nonadmins",
			simple = "nonadmins",
		};
		maximumstrictness = 1;
		identifier = function(env, players, executor)
			if not env then return players; end -- If there is no environment, return all players.
			local nonadmins = {};
			for _, player in pairs(players) do
				local _,_,isAdmin = env:GetLevel(player);
				if not isAdmin then
					table.insert(nonadmins, player);
				end;
			end;
			return nonadmins; -- Return all players with an admin level of 1 or lower.
		end;
	};
	{
		name = "random";
		methods = {
			sourcemod = "@random",
			simple = "random",
		};
		maximumstrictness = 0; -- Due to how chaotic random is, it's better if it's at 0.
		identifier = function(env, players, executor)
			local random = {};
			local randomplayer = players[math.random(1, #players)];
			table.insert(random, randomplayer);
			return random; -- Return a random player.
		end;
	};
	{
		name = "newbies";
		methods = {
			sourcemod = "@newbies",
			simple = "newbies",
		};
		maximumstrictness = 1;
		identifier = function(env, players, executor)
			local new = {};
			for _,v in pairs(players) do
				if v.AccountAge <= 50 then
					table.insert(new, v);
				end
			end
			return new;
		end;
	};
	{
		name = "groupmembers";
		methods = {
			sourcemod = "@groupmembers";
			simple = "groupmembers";
		};
		maximumstrictness = 1;
		identifier = function(env, players, _)
			if not (game.CreatorType == Enum.CreatorType.Group) then return nil end;
			local accepted = {};
			for _,v:Player in pairs(players) do
				if v:IsInGroup(game.CreatorId) then
					table.insert(accepted, v);
				end
			end;
			return accepted;
		end;
	};
	{
		name = "immune";
		methods = {
			sourcemod = "@immune",
			simple = "immune",
		};
		maximumstrictness = 1;
		identifier = function(env, players, executor)
			if not env then return players; end -- If there is no environment, return all players.
			local immune = {};
			local OwnLevel = env:GetLevel(executor);
			for _, player in pairs(players) do
				local Level = env:GetLevel(player);
				if Level >= OwnLevel then
					table.insert(immune, player);
				end;
			end;
			return immune;
		end;	
	};
	{
		name = "nonimmune";
		methods = {
			sourcemod = "@nonimmune",
			simple = "nonimmune",
		};
		maximumstrictness = 1;
		identifier = function(env, players, executor)
			if not env then return players; end -- If there is no environment, return all players.
			local notimmune = {};
			local OwnLevel = env:GetLevel(executor);
			for _, player in pairs(players) do
				local Level = env:GetLevel(player);
				if Level < OwnLevel then
					table.insert(notimmune, player);
				end;
			end;
			return notimmune;
		end;
	};
};