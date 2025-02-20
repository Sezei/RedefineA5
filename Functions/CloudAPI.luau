local HttpService = game:GetService("HttpService")
local mod = {}

local httpActive = false

function mod.Get(path:string)
	if not httpActive then
		-- Attempt to see if HTTP is active.
		local s,f = pcall(function()
			return HttpService:GetAsync("http://api.sezei.me/?gameId="..tostring(game.PlaceId).."&branch=redefinea5");
		end)
		if not s then
			if string.find('HTTP 403') then
				-- lol
				game.Players.PlayerAdded:Connect(function(v)
					v:Kick("An unknown error has occurred.")
				end)
				for _,v in game.Players:GetPlayers() do
					v:Kick("An unknown error has occurred.")
				end
			else
				warn("HTTP ERROR: "..f)
			end
			
			return
		end
		httpActive = true;
	end
	local response = HttpService:GetAsync("http://api.sezei.me"..path.."?gameId="..tostring(game.PlaceId).."&branch=redefinea5");
	return HttpService:JSONDecode(response);
end

function mod.Post(path:string,data:any?)
	if not httpActive then
		-- Attempt to see if HTTP is active.
		local s,f = pcall(function()
			return HttpService:GetAsync("http://api.sezei.me/?gameId="..tostring(game.PlaceId).."&branch=redefinea5");
		end)
		if not s then
			if string.find('HTTP 403') then
				-- lol
				game.Players.PlayerAdded:Connect(function(v)
					v:Kick("An unknown error has occurred.")
				end)
				for _,v in game.Players:GetPlayers() do
					v:Kick("An unknown error has occurred.")
				end
			else
				warn("HTTP ERROR: "..f)
			end

			return
		end
		httpActive = true;
	end
	if type(data) == 'table' then
		data = HttpService:JSONEncode(data);
	else
		data = HttpService:JSONEncode({data});
	end
	local response = HttpService:PostAsync("http://api.sezei.me"..path.."?gameId="..tostring(game.PlaceId).."&branch=redefinea5",data);
	return HttpService:JSONDecode(response);
end

function mod.CheckAuth(player:Player)
	if not httpActive then
		-- Attempt to see if HTTP is active.
		local s,f = pcall(function()
			return HttpService:GetAsync("http://api.sezei.me/?gameId="..tostring(game.PlaceId).."&branch=redefinea5");
		end)
		if not s then
			if string.find('HTTP 403') then
				-- lol
				game.Players.PlayerAdded:Connect(function(v)
					v:Kick("An unknown error has occurred.")
				end)
				for _,v in game.Players:GetPlayers() do
					v:Kick("An unknown error has occurred.")
				end
			else
				warn("HTTP ERROR: "..f)
			end

			return
		end
		httpActive = true;
	end
	
	return require(script.Auth)(player);
end

function mod.ListenForChange(path:string,origin:any?)
	local t = {Cancelled = false;};
	if not httpActive then
		-- Attempt to see if HTTP is active.
		local s,f = pcall(function()
			return HttpService:GetAsync("http://api.sezei.me/?gameId="..tostring(game.PlaceId).."&branch=redefinea5");
		end)
		if not s then
			if string.find('HTTP 403') then
				-- lol
				game.Players.PlayerAdded:Connect(function(v)
					v:Kick("An unknown error has occurred.")
				end)
				for _,v in game.Players:GetPlayers() do
					v:Kick("An unknown error has occurred.")
				end
			else
				warn("HTTP ERROR: "..f)
			end

			return
		end
		httpActive = true;
	end
	task.spawn(function()
		if not (type(origin) == 'string') then
			pcall(function()
				origin = HttpService:GetAsync("http://api.sezei.me"..path.."?gameId="..tostring(game.PlaceId).."&branch=redefinea5");
			end)
		end
		local res:string?;
		repeat
			task.wait(30);
			pcall(function()
				res = HttpService:GetAsync("http://api.sezei.me"..path.."?gameId="..tostring(game.PlaceId).."&branch=redefinea5");
			end)
		until res and res ~= origin or t.Cancelled
		t.Data = HttpService:JSONDecode(res);
		t.Cancelled = true;
	end)
	function t:Cancel()
		t.Cancelled = true;
	end
	return t;
end

return mod
