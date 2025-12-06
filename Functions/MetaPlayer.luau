local ids = {}
local plrs = {}

local senv; -- Stored Environment

local function CreateMeta(env:any, plr:Player?)
	table.insert(env.Data.Logs.System, {os.time(), "MetaPlayer", 'Assigned a new metaplayer instance for '..plr.UserId});
	senv = env;
	if not plr then return {} end;
	if plrs[plr.UserId] then return plrs[plr.UserId] end;

	local player = {};
	player.LocalId = #ids+1;
	ids[player.LocalId] = plr.UserId;

	player.self = plr;
	player.Data = {};
	player.Name = plr.Name;
	player.DisplayName = plr.DisplayName;
	player.UserId = plr.UserId;
	player.AccountAge = plr.AccountAge;
	player.InGame = true;
	player.Gagged = senv.Data.Ingame.Gagged[plr.UserId] and true or false;
	player.Muted = false;

	local function setGagState(gagged:boolean)
		player.Gagged = gagged;
		if gagged then
			senv.Data.Ingame.Gagged[plr.UserId] = true;
		else
			senv.Data.Ingame.Gagged[plr.UserId] = nil;
		end
		senv.RemoteEvent:FireAllClients("GagState", plr.UserId, gagged);
	end

	-- Set the player's Local PlayerId attribute
	plr:SetAttribute("ra_LocalId",player.LocalId);

	function player:GetLevel()
		return senv:GetLevel(plr);
	end

	function player:Kick(...)
		if not player.InGame then return end;
		player.self:Kick(...);
	end

	function player:Kill() -- Meta alias for Character.Humanoid.Health = -100;
		if not player.self then return end;
		player.self.Character.Humanoid.Health = -100;
	end

	function player:Respawn() -- Meta alias for LoadCharacter
		if not player.InGame then return end;
		player.self:LoadCharacter();
	end

	function player:Refresh()
		if not player.InGame then return end;
		local pos = player.self.Character.HumanoidRootPart.CFrame;
		player.self:LoadCharacter();
		player.self.Character:WaitForChild("HumanoidRootPart").CFrame = pos;
	end

	function player:Hint(title,content)
		if not player.InGame then return end;
		senv.RemoteEvent:FireClient(player.self,"Hint",title,content);
	end

	function player:Notify(text, data)
		if not player.InGame then return end;
		senv.RemoteEvent:FireClient(player.self,"Notify",text, data);
	end

	function player:Gag(reason:string?)
		if not player.InGame then return end;
		setGagState(true);
		if reason then
			table.insert(senv.Data.Logs.System, {os.time(), "MetaPlayer", `Gagged {player.Name}: {reason}`});
		end
	end

	function player:Ungag()
		if not player.InGame then return end;
		setGagState(false);
	end
	
	do (function() 
			if not senv.VCSDK then return end;
			local VCSDK = senv.VCSDK;
			
			function player:Mute(Duration)
				if not VCSDK.PlayerHasVoice(player.self) then return end;

				VCSDK.MutePlayer(player.self, Duration);
			end
			
			function player:Unmute()
				if not VCSDK.PlayerHasVoice(player.self) then return end;
				
				VCSDK.UnmutePlayer(player.self);
			end
			
			function player:SetVolume(NewVolume)
				if not VCSDK.PlayerHasVoice(player.self) then return end;
				
				VCSDK.SetPlayerVolume(player.self, NewVolume);
			end
	end)() end

	table.insert(plrs,player);

	return player;
end

game:GetService("Players").PlayerRemoving:Connect(function(plr)
	if plrs[plr.UserId] then
		plrs[plr.UserId].InGame = false;
		plrs[plr.UserId].self = nil; -- Player disconnected! No point in holding a useless 'notnil' object.
	end
end)

game:GetService("Players").PlayerAdded:Connect(function(plr)
	plr.CharacterAppearanceLoaded:Wait();
	if plrs[plr.UserId] then
		plrs[plr.UserId].InGame = true;
		plrs[plr.UserId].self = plr; -- Player reconnected! Undo the nil

		if senv.Data.Ingame.Gagged[plr.UserId] then
			plrs[plr.UserId].Gagged = true;
			senv.RemoteEvent:FireAllClients("GagState", plr.UserId, true);
		end

		if plrs[plr.UserId].Muted then
			-- Notify all of the admins that the player has reconnected and is still muted
			for _,player in pairs(game:GetService("Players"):GetPlayers()) do
				-- Check if the player is an admin
				if senv:GetLevel(player) >= 2 then
					-- Notify the admin that the player has reconnected and is still muted
					senv:NotifyFireClient(player,plr.Name.." has reconnected and has been re-muted.",{
						Type = "Warning";
					});
				end
			end

			-- Remute the player
			senv.VCSDK.mutePlayerAsync(plr);
		end

		-- Add the player's Local PlayerId to the player instance
		plr:SetAttribute("ra_LocalId",plrs[plr.UserId].LocalId);
	end
end)

return CreateMeta