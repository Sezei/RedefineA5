local HttpService = game:GetService("HttpService");
local require = require;
local Datastore;
local Casestore;
--local TagStore;
local mod = {};
local env:env = nil;

type UnbanInfo = {
	Moderator:number;
	Reason:string;
	Timestamp:number;
};

type ActionData = {
	Moderator:number;
	Action:string;
	Reason:string;
	Timestamp:number;
	CaseId:number?; -- new bans only
};

type BanData={
	Type:"Unbanned"|"Expired"|"Active"; --> Priority: Check for UnbannedBy; Check if it's expired; Count as active if neither.
	Moderator:number;
	Reason:string;
	Timestamp:number;

	ExpiresAt:number?; -- if nil, it's a permanent ban; if not and tick() > ExpiresAt, it's an expired ban
	UnbannedBy:UnbanInfo?; -- if not nil, it's an unbanned type (takes priority over Expired)
	-- if both are nil, it's an active permanent ban.

	History:{ActionData}; -- if nil, it means it's their first action

	UserId:number?; -- for new bans with cases
	CaseId:number?;
};

type DatastoreTask={
	wait:(DatastoreTask)->DatastoreTask;
	cancel:(DatastoreTask)->nil;
	Data:(string|number|{any}|BanData)?;
	Cancelled:boolean;
	Complete:boolean;
};

type DatastoreHandle={
	Load:(DatastoreHandle,string)->DatastoreTask;
	Save:(DatastoreHandle,string,any)->DatastoreTask;
};

type env = {
	Datastore:(string,env,{nocache:boolean?,nosandbox:boolean?})->DatastoreHandle;
	RegisterCommand:(env,{})->nil;
	Signals:{[string]:RBXScriptSignal};
	GetLevel:(env,Player|number)->number;
};

local Serverbans = {

};

local function LogIt(Data)
	if env.Data.Settings.WebhookURL then
		local LogURL = env.Data.Settings.WebhookURL;

		local Encoded = HttpService:JSONEncode(Data);

		HttpService:PostAsync(LogURL, Encoded);
	end;
end

local function ApproximateFromMinutes(Minutes:number):string -- turn a number of minutes into a string of days, hours, minutes, and seconds
	local Months = math.floor(Minutes / 40320);
	local Weeks = math.floor((Minutes % 40320) / 10080);
	local Days = math.floor(((Minutes % 40320) % 10080) / 1440);
	local Hours = math.floor((((Minutes % 40320) % 10080) % 1440) / 60);
	local Minutes = math.floor((((Minutes % 40320) % 10080) % 1440) % 60);

	local BuiltString = {};

	if Months > 0 then
		if Months == 1 then
			table.insert(BuiltString, "1 month");
		else
			table.insert(BuiltString, Months.." months");
		end
	end

	if Weeks > 0 then
		if Weeks == 1 then
			table.insert(BuiltString, "1 week");
		else
			table.insert(BuiltString, Weeks.." weeks");
		end
	end

	if Days > 0 then
		if Days == 1 then
			table.insert(BuiltString, "1 day");
		else
			table.insert(BuiltString, Days.." days");
		end
	end

	if Hours > 0 then
		if Hours == 1 then
			table.insert(BuiltString, "1 hour");
		else
			table.insert(BuiltString, Hours.." hours");
		end
	end

	if Minutes > 0 then
		if Minutes == 1 then
			table.insert(BuiltString, "1 minute");
		else
			table.insert(BuiltString, Minutes.." minutes");
		end
	end

	return table.concat(BuiltString, ', ');
end

local function FindUserIdInRecord(records, userId)
	for i,record in pairs(records) do
		if tostring(record["UserId"]) == tostring(userId) then
			return i
		end
	end
	return false
end

function mod:_NxWrapper_PostInit()
	env = self;
	local DiscordModule = env.DiscordEmbedder;
	Datastore = env.Storage -- we need to allow this stuff to work in vip servers too so we disable the sandboxing
	Casestore = env.Datastore("BetterBans_v1_Cases",env,{nocache=true;nosandbox=true});
	--TagStore = env.Datastore("TagService",env,{nocache=true,nosandbox=true});

	local function AssignCaseId(Task:BanData?)
		if not Task then return end;
		local t:number = tonumber(Casestore:Load('TotalCases'):wait().Data) or 0;

		Task.CaseId = t+1;
		Task.History[#Task.History].CaseId = t+1;

		Casestore:Save('TotalCases',t+1);
		Casestore:Save('Case'..t+1,Task);
	end

	--TODO
	local function DestroyCase(CaseId:number)
		local Case = Casestore:Load('Case'..CaseId):wait().Data;
		if not Case then return end;


	end

	local function GetActiveType(Data:BanData):"Unbanned"|"Active"|"Expired" -- Condence the ban to a string to avoid unnecessary load times.
		if Data.Type ~= 'Active' then return Data.Type end;
		if Data.UnbannedBy then
			return 'Unbanned';
		elseif Data.ExpiresAt then
			if Data.ExpiresAt < tick() then
				return 'Expired';
			else
				return 'Active';
			end
		else
			return 'Active';
		end
	end;

	-- Better bans
	env:RegisterCommand(
		{
			Disabled = false;
			Name = "Permban";
			Description = "Drops a ban hammer.";
			Arguments = {
				{
					Name = 'Player';
					Type = "PlayerIdentifier";
					Required = true;
				};
				{
					Name = 'Reason';
					Type = "String";
					Required = true;
				};
			};
			Level = 4;
			Keys={
				usera = true;
			};

			OnRun = function(env, Executor, Arguments, Keys)
				if env:GetLevel(Arguments.Player.Id) >= env:GetLevel(Executor) then
					return {
						Success = false;
						Message = 'You can\'t ban someone whose level is equal or higher than yours.';
					}
				end

				local s, _ = pcall(function()
					game:GetService("Players"):BanAsync({
						UserIds = {Arguments.Player.Id};
						ApplyToUniverse = true;
						Duration = -1;
						DisplayReason = Arguments.Reason;
						PrivateReason = Arguments.Reason .. ' || Banned by '..Executor.UserId;
						ExcludeAltAccounts = false;
					});
				end)
				if s then
					-- Saved = true;
					task.spawn(function()
						LogIt(DiscordModule.new()
							:SetTitle("Player Banned")
							:AddField("Executor",`[{Executor.Name}](https://www.roblox.com/users/{Executor.UserId}/profile)`, true)
							:AddField("Player",`[{Arguments.Player.DisplayName} (@{Arguments.Player.Username})](https://www.roblox.com/users/{Arguments.Player.Id}/profile)`, true)
							:AddField("Time",'Permanent', true)
							:AddField("Reason",Arguments.Reason)
							:SetCustomThumbnail(HttpService:JSONDecode(HttpService:GetAsync('https://thumbnails.roproxy.com/v1/users/avatar?userIds='..Arguments.Player.Id..'&size=720x720&format=Png&isCircular=false')).data[1].imageUrl)
							:SetTimestamp()
							:SetFooter("Redefine:A")
							:SetColor(Color3.new(1, 0, 0))
							:BuildMessage());
					end)
					return {
						Success = true,
						Message = "Successfully banned "..Arguments.Player.Username
					};
				end
			end;
		}
	);

	env:RegisterCommand(
		{
			Disabled = false;
			Name = "Ban";
			Description = "Bans a player for a certain amount of time.";
			Arguments = {
				{
					Name = 'Player';
					Type = "PlayerIdentifier";
					Required = true;
				};
				{
					Name = 'Time';
					Type = "Time";
					Required = true;
					Maximum = 40320; -- 1 month
					Minimum = 1; -- 1 minute
				};
				{
					Name = 'Reason';
					Type = "String";
					Required = true;
				};
			};
			Level = 3;
			Keys = {
				usera = true;
			};

			OnRun = function(env, Executor, Arguments:{Player:Player,Time:{Minutes:number},Reason:string}, Keys)
				print(Arguments.Player);
				if env:GetLevel(Arguments.Player.Id) >= env:GetLevel(Executor) then
					return {
						Success = false;
						Message = 'You can\'t ban someone whose level is equal or higher than yours.';
					}
				end
				local s, _ = pcall(function()
					game:GetService("Players"):BanAsync({
						UserIds = {Arguments.Player.Id};
						ApplyToUniverse = true;
						Duration = Arguments.Time.Minutes * 60;
						DisplayReason = Arguments.Reason;
						PrivateReason = Arguments.Reason .. ' || Banned by '..Executor.UserId;
						ExcludeAltAccounts = false;
					});
				end)
				if s then
					task.spawn(function()
						LogIt(DiscordModule.new()
							:SetTitle("Player Banned")
							:AddField("Executor",`[{Executor.Name}](https://www.roblox.com/users/{Executor.UserId}/profile)`, true)
							:AddField("Player",`[{Arguments.Player.DisplayName} (@{Arguments.Player.Username})](https://www.roblox.com/users/{Arguments.Player.Id}/profile)`, true)
							:AddField("Time", ApproximateFromMinutes(Arguments.Time.Minutes), true)
							:AddField("Reason",Arguments.Reason)
							:SetCustomThumbnail(HttpService:JSONDecode(HttpService:GetAsync('https://thumbnails.roproxy.com/v1/users/avatar?userIds='..Arguments.Player.Id..'&size=720x720&format=Png&isCircular=false')).data[1].imageUrl)
							:SetTimestamp()
							:SetFooter("Redefine:A")
							:SetColor(Color3.new(1, 0, 0))
							:BuildMessage()
						);
					end);

					return {
						Success = true;
						Message = "Successfully banned "..Arguments.Player.Username.." for "..Arguments.Time.Minutes.." minutes.";
					}
				end
			end;
		}
	);

	env:RegisterCommand(
		{
			Disabled = false;
			Name = "ServerBan";
			Description = "-";
			Arguments = {
				{
					Name = 'Player';
					Type = "SafePlayer";
					Required = true;
				};
				{
					Name = 'Reason';
					Type = "String";
					Required = true;
				};
			};
			Level = 2;

			OnRun = function(env, Executor, Arguments:{Player:Player,Reason:string}, Keys)
				if env:GetLevel(Arguments.PlayerId) >= env:GetLevel(Executor) or game.PrivateServerOwnerId~=Executor.UserId then
					return {
						Success = false;
						Message = 'You can\'t ban someone whose level is equal or higher than yours.';
					}
				end

				Arguments.Player:Kick("You have been banned from this server. Reason: "..Arguments.Reason);

				Serverbans[Arguments.Player.UserId] = Arguments.Reason;

				task.spawn(function()
					if game.PrivateServerId == "" then
						LogIt(DiscordModule.new()
							:SetTitle("Player Server Banned")
							:AddField("Executor",`[{Executor.Name}](https://www.roblox.com/users/{Executor.UserId}/profile)`, true)
							:AddField("Player",`[{Arguments.Player.DisplayName} (@{Arguments.Player.Name})](https://www.roblox.com/users/{Arguments.Player.UserId}/profile)`, true)
							:AddField("Reason",Arguments.Reason)
							:SetFooter("Redefine:A BetterBans")
							:SetCustomThumbnail(HttpService:JSONDecode(HttpService:GetAsync('https://thumbnails.roproxy.com/v1/users/avatar?userIds='..Arguments.Player.UserId..'&size=720x720&format=Png&isCircular=false')).data[1].imageUrl)
							:SetTimestamp()
							:SetColor(Color3.new(1, 0, 0))
							:BuildMessage()
						);
					end;
				end);

				return {
					Success = true,
					Message = "Successfully server-banned "..Arguments.Player.Name
				};
			end;
		}
	);

	env:RegisterCommand(
		{
			Disabled = false;
			Name = "Unban";
			Description = "Unbans a player.";
			Arguments = {
				{
					Name = 'PlayerId';
					Type = "PlayerIdentity";
					Required = true;
				};
				{
					Name = 'Reason';
					Type = "String";
					Required = false;
					Default = 'No reason has been given.';
				};
			};
			Level = 2;

			OnRun = function(env, Executor, Arguments, Keys)
				game:GetService("Players"):UnbanAsync({
					UserIds = {Arguments.PlayerId.Id};
					ApplyToUniverse = true;
				});

				task.spawn(function()
					LogIt(DiscordModule.new()
						:SetTitle("Player Unbanned")
						:AddField("Executor",`[{Executor.Name}](https://www.roblox.com/users/{Executor.UserId}/profile)`)
						:AddField("Player",`[{Arguments.PlayerId.Username}](https://www.roblox.com/users/{Arguments.PlayerId.Id}/profile)`)
						:AddField("Reason",Arguments.Reason)
						:SetCustomThumbnail(HttpService:JSONDecode(HttpService:GetAsync('https://thumbnails.roproxy.com/v1/users/avatar?userIds='..Arguments.PlayerId.Id..'&size=720x720&format=Png&isCircular=false')).data[1].imageUrl)
						:SetTimestamp()
						:SetFooter("Redefine:A")
						:SetColor(Color3.new(1, 1, 0.498039))
						:BuildMessage()
					);
				end)

				return {
					Success = true,
					Message = "Cleared "..Arguments.PlayerId.Username.."'s ban data."
				};
			end;
		}
	);

	env.Signals.JoinEvent:Connect(function(Player)
		if Serverbans[Player.UserId] then
			Player:Kick("You are banned from this server. Reason: "..Serverbans[Player.UserId]);
		end

		local Load = Datastore:Load('BanProfile_'..tostring(Player.UserId)):wait();
		local LoadData = Load.Data :: BanData?;

		if LoadData then
			if GetActiveType(LoadData) == 'Active' then
				if game:GetService("RunService"):IsStudio() then
					return;
				end
				Player:Kick("You are banned from this game. Reason: "..LoadData.Reason);
			elseif GetActiveType(LoadData) ~= 'Active' and LoadData.Type == 'Active' then
				task.spawn(function() -- Remove the 'Active' type if it's not active anymore.
					if LoadData.UnbannedBy then
						LoadData.Type = 'Unbanned';
					elseif LoadData.ExpiresAt and LoadData.ExpiresAt < tick() then
						LoadData.Type = 'Expired';

						table.insert(LoadData.History,{
							Moderator = 1;
							Action = 'Unbanned - Automatic';
							Reason = 'Ban has expired.';
							Timestamp = tick();
						});

						LogIt(DiscordModule.new()
							:SetTitle("Player Unbanned")
							:AddField("Executor",`[Automatic](https://www.youtube.com/watch?v=dQw4w9WgXcQ)`)
							:AddField("Player",`[{Player.Name}](https://www.roblox.com/users/{Player.UserId}/profile)`)
							:AddField("Reason","Ban has expired.")
							:SetCustomThumbnail(HttpService:JSONDecode(HttpService:GetAsync('https://thumbnails.roproxy.com/v1/users/avatar?userIds='..Player.UserId..'&size=720x720&format=Png&isCircular=false')).data[1].imageUrl)
							:SetTimestamp()
							:SetFooter("Redefine:A BetterBans")
							:SetColor(Color3.new(0.333333, 1, 0))
							:BuildMessage()
						);
					end;

					LoadData.Type = GetActiveType(LoadData);
					Datastore:Save('BanProfile_'..tostring(Player.UserId),LoadData);
				end);
			end;
		end;
	end);
end

return mod