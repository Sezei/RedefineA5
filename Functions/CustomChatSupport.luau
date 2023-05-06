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
	end)

	return nil;
end};