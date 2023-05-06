local CollectionService = game:GetService("CollectionService");

return {_NxWrapper = function(env)
	-- SocialChat v2
	task.spawn(function() -- Put it in a separate thread
		local SocialChatExists = game.ReplicatedStorage:WaitForChild("SocialChat",60); -- Give it a full minute to find it.
		if not SocialChatExists then return end;
		local SocialChat = require(SocialChatExists);
		local Channels = SocialChat.Src.Channels

		Channels.OnMessageSent:Connect(function(Speaker, Message, Recipient)
			table.insert(env.Data.Logs.Chat,{os.time(),Speaker.UserId,Message});
			env:RunCommand(Speaker.Agent,Message);
		end);

		-- Add a gateway
		Channels:AddValidator(function(Speaker, Message, Recipient)
			if env:GetLevel(Speaker.Agent) >= 1 then
				-- Check if the message starts with the prefix, and whether or not it has a --silent flag within it.
				if Message:sub(1,#env.Data.Prefix) == env.Data.Prefix then
					local Silent = Message:find("--silent");
					if Silent then
						return true; -- Mark the message as invalid.
					end;
				end;
			end;

			return false; -- Mark the message as valid.
		end);
	end)

	return nil;
end};