local Handled = {};

return function (env, player)
	if Handled[player.UserId] == true then
		local unhandlewarn = script.UnhandledWarn:Clone();
		unhandlewarn.Parent = player.PlayerGui;
		task.wait(1);
		unhandlewarn.Disabled = false;
		return 
	end;

	local clone = env.RedefineAUI:Clone();
	
	clone.Assets:Destroy();
	
	local Themes = env.MainModule.Themes;
	if not env.Data.Settings.Theme then
		env.Data.Settings.Theme = 'Dark';
	end;
	
	local ThemeClone = Themes[env.Data.Settings.Theme]:Clone();
	ThemeClone.Parent = clone;
	ThemeClone.Name = "Assets";
	
	clone:SetAttribute("notaskbar",env.Data.Settings['DisableTaskbar'] or false)
	clone:SetAttribute("nxversion",env.NxEngine.BuildId or "Nightly");
	clone:SetAttribute("consolekeybind",env.Data.Settings['ConsoleKeybind'] or 'Equals')
	clone.Parent = player.PlayerGui;

	if not (type(env.Data.Logs.Joins) == "table") then env.Data.Logs.Joins = {} end
	local success,ret = pcall(function() -- The actual join handling function; Wrapped in pcall to avoid errors on the main thread
		if player.FollowUserId ~= 0 then
			table.insert(env.Data.Logs.Joins,{os.time(),player.UserId,player.FollowUserId});
		else
			table.insert(env.Data.Logs.Joins,{os.time(),player.UserId});
		end

		Handled[player.UserId] = true;

		-- Allow global banlist to be used in the game? If yes, check if the player is identified as a threat for game safety.
		if env.Data.Settings.CloudAPI.UseBanlist then
			local bandata = env.GlobalBanlist;

			if bandata then
				if bandata[tostring(player.UserId)] then
					local pinfo = bandata[tostring(player.UserId)];
					if pinfo.active and pinfo.active == true then
						env.Bind:Fire("JoinWhileBanned",player.UserId,"Cloudban: "..pinfo.reason);
						player:Kick("\nSezei.me API\n----------------\n\nYou are cloud banned from all games with Sezei.me products.\n\nReason:\n"..pinfo.reason)
					else
						-- The player was banned before, but the ban is no longer active. We will keep track on them using task.spawn.
						task.spawn(function()
							repeat 
								task.wait(125)
								pinfo = env.GlobalBanlist[tostring(player.UserId)];
							until pinfo.active or not player;
							if pinfo.active and player then
								player:Kick("\nSezei.me API\n----------------\n\nYou are cloud banned from all games with Sezei.me products.\n\nReason:\n"..pinfo.reason)
							end
						end)
					end
				else
					-- Player isn't banned, but it's better to still keep track on them using task.spawn in-case that changes.
					task.spawn(function()
						local pinfo = env.GlobalBanlist[tostring(player.UserId)];
						repeat 
							task.wait(50) -- Because they have no history of being banned, we can increase the check time from 60 seconds to 120 seconds because usually it means they have no reason to be checked again.
							pinfo = env.GlobalBanlist[tostring(player.UserId)];
						until (pinfo and pinfo.active) or not player;
						if pinfo.active and player then
							player:Kick("\nSezei.me API\n----------------\n\nYou are cloud banned from all games with Sezei.me products.\n\nReason:\n"..pinfo.reason)
						end
					end)
				end
			else
				env.warn(4, "Couldn't verify whether "..player.Name.." is Cloud-Banned or not due to not being able to fetch the banlist.");
			end
		end

		-- Check if any of the player's friends are in-game
		task.spawn(function()
			for _,OtherPlayer in game:GetService("Players"):GetPlayers() do
				-- Check if the OtherPlayer is a friend of the player who's joining
				if OtherPlayer:IsFriendsWith(player.UserId) then
					-- Check if the OtherPlayer is in-game
					if OtherPlayer.Parent then
						env:Notify(OtherPlayer,"Your friend, "..player.Name..", has joined the server!",{
							TextColor = Color3.fromRGB(0, 179, 255);
							Timeout = 15;
							Options = {
								["-"] = {Primary = true; Text = "Got it"};
							};
						});
						env:Notify(player,"Your friend, "..OtherPlayer.Name..", is in-game!",{
							TextColor = Color3.fromRGB(0, 179, 255);
							Timeout = 15;
							Options = {
								["-"] = {Primary = true; Text = "Got it"};
							};
						});
					end
				end
			end
		end)

		env:MetaPlayer(player); -- Create a MetaPlayer instance for the player.

		player.Chatted:Connect(function(msg)
			--table.insert(env.Data.Logs.Chat,{os.time(),player.UserId,msg});
			env:RunCommand(player,msg);
		end)

		-- Fire the join event
		env.Signals.JoinEvent:Fire(player);

		-- Send a notification to the player
		task.spawn(function()
			local PlayerLevel = env:GetLevel(player);
			if PlayerLevel >= 1 and (type(env.Data.Settings['SendLevelNotification'])=="boolean" and env.Data.Settings['SendLevelNotification'] or type(env.Data.Settings['SendLevelNotification'])=='nil') then
				local notification = env:Notify(player,"Welcome to the server! You are a(n) "..env.Data.Settings.Admins[PlayerLevel].GroupName.." (Level "..PlayerLevel..").",{
					TextColor = Color3.fromRGB(85, 170, 255);
					Options = {
						["-"] = {Primary = true; Text = "Got it"};
						["ShowCommands"] = "Show Commands";
					};
					Timeout = 20;
				});

				notification:AwaitResponse(function(response)
					if response == "ShowCommands" then
						env:RunCommand(player,env.Data.Settings.Prefix.."commandslist");
					end
				end)
			end;
		end)
	end);

	if not success then
		if player.Parent then -- If the player is still in the game, readd them to the queue
			warn("An error has occurred handling "..player.Name..".. | "..ret);
		end
	end

	player:GetPropertyChangedSignal("Parent"):Connect(function()
		if player.Parent == nil then
			Handled[player.UserId] = false;
		end
	end)
end