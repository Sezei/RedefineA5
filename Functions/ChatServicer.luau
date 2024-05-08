local Chat = game:GetService("TextChatService");
local Players = game:GetService("Players");

return {_NxWrapper_PostInit = function(env)
	-- SocialChat v2
	
	env.ChatMute = function(player)
		
	end;
	
	env.ChatUnmute = function(player)
		
	end;
	
	task.spawn(function() -- SocialChat
		local SocialChatExists = game.ReplicatedStorage:WaitForChild("SocialChat",60); -- Give it a full minute to find it.
		if not SocialChatExists then return end;
		local SocialChat = require(SocialChatExists);
		local Channels = SocialChat.Src.Channels

		Channels.OnMessageSent:Connect(function(Speaker, Message, Recipient)
			table.insert(env.Data.Logs.Chat,{os.time(),Speaker.Agent.UserId,Message});
			env:RunCommand(Speaker.Agent,Message);
		end);
	end)
	
	if type(env.Data.Settings['TextChatService'])=='table' and env.Data.Settings['TextChatService'].Enabled then
		task.spawn(function() -- Are we using TextChatService?
			if Chat.ChatVersion == Enum.ChatVersion.TextChatService then -- cool we can proceed
				local CommandsRegistered = {}
				Chat:WaitForChild("TextChatCommands")
				env.Signals.CommandRegistered:Connect(function(CommandData)
					local Command = Instance.new("TextChatCommand")
					Command.Parent = Chat:FindFirstChild("TextChatCommands")
					Command.PrimaryAlias = "/"..CommandData.Name;
					
					if CommandData.Aliases and CommandData.Aliases[1] then
						Command.SecondaryAlias = "/"..CommandData.Aliases[1]
					end

					Command.Triggered:Connect(function(TextSource, Message)
						-- Removing the first part of the message
						local Message = Message:split(" ");
						table.remove(Message, 1);
						local Message = table.concat(Message, " ");
						
						local Player = Players:GetPlayerByUserId(TextSource.UserId)
						
						env:RunCommand(Player, env.Data.Settings.Prefix..CommandData.Name, true);
					end)
					
					CommandsRegistered[CommandData.Name] = true;
				end)
				
				-- Do the same for all the commands that already exist :pepesmile:
				for _,CommandData in env.Commands do
					if not CommandsRegistered[CommandData.Name] then
						local Command = Instance.new("TextChatCommand")
						Command.Parent = Chat:FindFirstChild("TextChatCommands")
						Command.PrimaryAlias = "/"..CommandData.Name;

						if CommandData.Aliases and CommandData.Aliases[1] then
							Command.SecondaryAlias = "/"..CommandData.Aliases[1]
						end

						Command.Triggered:Connect(function(TextSource, Message)
							-- Removing the first part of the message
							local Message = Message:split(" ");
							table.remove(Message, 1);
							local Message = table.concat(Message, " ");

							local Player = Players:GetPlayerByUserId(TextSource.UserId)

							local r = env:RunCommand(Player, env.Data.Settings.Prefix..CommandData.Name..' '..Message, true);
							if r then
								--TODO: Return chat messages if 'Auto' or Chat.
							end
						end)
						
						CommandsRegistered[CommandData.Name] = true;
					end
				end
			end
		end)
	end;

	return nil;
end};