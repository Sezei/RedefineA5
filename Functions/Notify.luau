local activenotifications = {
};

local listener;

return function(env, player, text, data)

	-- Check if we are using api.Notify(player, {}) instead of env:Notify(player, "text", options); That way, we can recognise if the command came from compatibility mode.
	if env.Name and game:GetService("Players"):FindFirstChild(env.Name) and typeof(player) == 'table' then -- ;-;

		local type = 'normal'
		-- Build the notification
		if string.lower(player[1]) == "unsuccessful" or string.lower(player[1]) == "failed" or string.lower(player[1]) == "problem" or  string.lower(player[1]) == "warning" then
			type = 'warning';
		elseif string.lower(player[1]) == "no_permission" or string.lower(player[1]) == "error" then
			type = 'error';
		elseif string.lower(player[1]) == "script_error" or string.lower(player[1]) == "bug" then
			type = 'critical';
		end

		game:GetService("ReplicatedStorage"):FindFirstChild("NxRemoteFunction"):InvokeClient(env, "Notify", player[2], {
			Type = type;
			Timeout = 20;
		});

		-- We are in compatibility mode! We won't use the new notification system.
		return nil;
	end

	if not data then data = {} end; -- data is completely optional.
	if not listener then
		listener = env.RemoteEvent.OnServerEvent:Connect(function(player, key, uid, info,...)
			if key == "NotificationOptionSelected" then
				local notification = activenotifications[uid];
				if notification then
					if notification.Callback then
						notification.Callback(info);
					end
					notification.Completed = true;
					notification.SelectedOption = info;
				end
			elseif key == "CommandSent" then
				env:RunCommand(player,env.Data.Settings.Prefix..uid,true);
			elseif key == "OnboardResponse" and env.Data.AllowOnboardResponse then
				if env.Data.AllowOnboardResponse == player.UserId then
					env.Data.AllowOnboardResponse = nil; -- free up
					
					local Received = game:GetService("HttpService"):JSONDecode(uid);
					
					task.spawn(function()
						env.ValidateSettings(Received);
						task.wait();
						env.PersistStorage:Save('Settings', Received);
						
						env.Data.Settings = Received;
					end)
				else
					player:Destroy(); -- no.
				end
			elseif env.RemoteEventKeys and env.RemoteEventKeys[key] then
				env.RemoteEventKeys[key](player,uid,info,...)
			end
		end)
	end

	-- Format the text using PlaceholderAPI (env.format);
	text = env.format(text, {}, player)

	-- Check if the provided player is a player instance.
	if player and typeof(player) == "Instance" and player:IsA("Player") then
		-- Check if the player is in the game.
		if player.Parent == game.Players then
			-- Create a notification instance
			local notification = {};

			local UID;
			local success, fail = pcall(function()
				UID = env.RemoteFunction:InvokeClient(player, "Notify", text, data);
			end)
			if not success then
				table.insert(env.Data.Logs.Errors, {
					os.time(),
					"Failed to send notification to player " .. player.Name .. " with error: " .. fail
				});
				return fail;
			end

			activenotifications[UID] = {
				UID = UID; -- repetitive?
				Player = player,
				Text = text,
				Options = data.Options,
				Callback = data.Callback,
				Completed = false,
				SelectedOption = nil,
			};

			notification = activenotifications[UID];

			function notification:AwaitResponse(callback)
				-- Wait for the player to respond to the notification.
				activenotifications[UID].Callback = callback;

				repeat task.wait() until activenotifications[UID].Completed;
				return activenotifications[UID].SelectedOption;
			end

			function notification:Update(options)
				env.RemoteEvent:FireClient(player, "UpdateNotification", UID, options);
			end

			function notification:Destroy()
				-- Send a signal to the player to destroy the notification on their end.
				env.RemoteEvent:FireClient(player, "ClearNotification", UID);
				activenotifications[UID] = nil;
			end

			return notification;
		end
	end
end
