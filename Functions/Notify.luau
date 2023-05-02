local activenotifications = {
};

local listener;

return function(env, player, text, data)
	if not data then data = {} end; -- data is completely optional.
	if not listener then
		listener = env.RemoteEvent.OnServerEvent:Connect(function(player, key, uid, info)
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
			else
				-- Unknown key!
				if env.Data.Settings.RemoteTrap and env.Data.Settings.RemoteTrap.Enabled then
					env.Data.Settings.RemoteTrap.Punishment(env, player, text);
				end
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
				table.insert(env.Logs.Errors, {
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
