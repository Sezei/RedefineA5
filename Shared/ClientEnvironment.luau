local Client = {}

-- The client environment is a place to put environment variables that are shared with the client and server.
-- For example, you can use this to add new variables into the client, or to override existing ones.
-- Additionally, you can send assets to the client using the ClientEnvironment:SendAsset() function.
-- Make sure, however, to include a cardboard asset in your asset, otherwise it may not be usable on the client.

-- Example: Add/Overwrite new env variables to the client
Client.MyVariable = "Hello, world!"

-- Add remote event keys to the client using these tables
Client.ClientEvents = {
	-- [ReceivingKey] = function(...) end;
};

Client.ClientFunctions = {
	-- [ReceivingKey] = function(...) return non-tuple-value end;
}

function Client.PlaySound(AudioString : string) : nil
	local Sound = Instance.new("Sound");
	Sound.SoundId = AudioString;
	Sound.Parent = Client.GUI;
	Sound.Looped = false;
	task.spawn(function()
		if not Sound.IsLoaded then Sound.Loaded:Wait() end;
		Sound:Play();
		Sound.Ended:Connect(function()
			Sound:Destroy();
		end);
	end)

	return nil;
end;

function Client.CreateUID()
	local UID = "";
	for i = 1, 24 do
		UID = UID .. string.char(math.random(65, 90));
	end
	return UID;
end

function Client.ToHex(color:Color3|string)
	if type(color) == "string" then
		return color; -- Assume it's already a hex color.
	elseif typeof(color) == "Color3" then
		return string.format("#%02X%02X%02X", color.R * 255, color.G * 255, color.B * 255);
	else
		return "#FFFFFF";
	end;
end;

-- Core functions of the client environment
function Client.AddAsset(env, asset)
	-- Sends an asset to the client to either replace an existing one, or to add a new one.
	-- @param asset: The asset to send to the client
	-- @return void

	-- Check if the server is sending this command
	if not game:GetService("RunService"):IsServer() then
		return;
	end

	-- Send the asset to the client(s);

	-- Replace the asset in the default UI:
	local UI = env.MainModule.RedefineAUI;
	if UI then
		local Assets = UI:FindFirstChild("Assets");
		if not Assets then return end;

		if Assets:FindFirstChild(asset.Name) then
			warn("Warning: Overwriting existing asset '" .. asset.Name .. "'");
			Assets[asset.Name]:Destroy();
		end

		asset.Parent = Assets;
	end;

	-- Replace the asset in all existing UIs:
	for _, Player in pairs(game:GetService("Players"):GetPlayers()) do
		if Player:FindFirstChild("PlayerGui") then
			local LUI = Player.PlayerGui:FindFirstChild(UI.Name);
			if LUI then
				local Assets = LUI:FindFirstChild("Assets");
				if not Assets then return end;

				if Assets:FindFirstChild(asset.Name) then
					Assets[asset.Name]:Destroy();
				end

				asset.Parent = Assets;
			end;
		end;
	end;
end

return Client