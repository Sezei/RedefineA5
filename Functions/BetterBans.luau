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
	--[[Datastore = env.Storage -- we need to allow this stuff to work in vip servers too so we disable the sandboxing
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
	end;--]]

	-- Better bans
	env:RegisterCommand(
		{
			Disabled = false;
			Name = "Permban";
			Description = "Drops a ban hammer.";
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
			Level = 4;
			Keys={
				usera = true;
			};

			OnRun = function(env, Executor, Arguments:{Reason:string;Player:Player}, Keys)
				if env:GetLevel(Arguments.Player) >= env:GetLevel(Executor) then
					return {
						Success = false;
						Message = 'You can\'t ban someone whose level is equal or higher than yours.';
					}
				end
				
				--[[local Load = Datastore:Load('BanProfile_'..tostring(Arguments.Player.UserId)):wait();
				local LoadData = Load.Data :: BanData?;

				if LoadData and LoadData.History then
					table.insert(LoadData.History,{
						Moderator = Executor.UserId;
						Action = 'Permanent Ban';
						Reason = Arguments.Reason;
						Timestamp = tick();
					});

					LoadData.Type = 'Active';
					LoadData.Moderator = Executor.UserId;
					LoadData.Reason = Arguments.Reason;
					LoadData.Timestamp = tick();
					LoadData.UnbannedBy = nil;
					LoadData.ExpiresAt = nil;
				else
					LoadData = {
						Type = 'Active';
						Moderator = Executor.UserId;
						Reason = Arguments.Reason;
						Timestamp = tick();
						History = {
							{
								Moderator = Executor.UserId;
								Action = 'Permanent Ban';
								Reason = Arguments.Reason;
								Timestamp = tick();
							}
						};
					} :: BanData;
				end;

				local Saved=false;
				local Task=nil;
				task.delay(10,function()
					if not Saved then
						-- welp, that sucked.
						Task:cancel();
					end
				end)--]]

				--if not Keys.usera then
					local s, _ = pcall(function()
						game:GetService("Players"):BanAsync({
							UserIds = {Arguments.Player.UserId};
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
								:AddField("Player",`[{Arguments.Player.DisplayName} (@{Arguments.Player.Name})](https://www.roblox.com/users/{Arguments.Player.UserId}/profile)`, true)
								:AddField("Time",'Permanent', true)
								:AddField("Reason",Arguments.Reason)
								:SetCustomThumbnail(HttpService:JSONDecode(HttpService:GetAsync('https://thumbnails.roproxy.com/v1/users/avatar?userIds='..Arguments.Player.UserId..'&size=720x720&format=Png&isCircular=false')).data[1].imageUrl)
								:SetTimestamp()
								:SetFooter("Redefine:A")
								:SetColor(Color3.new(1, 0, 0))
								:BuildMessage());
						end)
						return {
							Success = true,
							Message = "Successfully banned "..Arguments.Player.Name
						};
					end
				--end

				--[[AssignCaseId(LoadData);
				Task = Datastore:Save('BanProfile_'..tostring(Arguments.Player.UserId),LoadData);
				Task:wait();
				Saved=not Task.Cancelled;

				if Saved then
					Arguments.Player:Kick("You have been permanently banned from this game. Reason: "..Arguments.Reason);

					task.spawn(function()
						LogIt(DiscordModule.new()
							:SetTitle("Player Banned")
							:AddField("Executor",`[{Executor.Name}](https://www.roblox.com/users/{Executor.UserId}/profile)`, true)
							:AddField("Player",`[{Arguments.Player.DisplayName} (@{Arguments.Player.Name})](https://www.roblox.com/users/{Arguments.Player.UserId}/profile)`, true)
							:AddField("Time",'Permanent', true)
							:AddField("Reason",Arguments.Reason)
							:SetCustomThumbnail(HttpService:JSONDecode(HttpService:GetAsync('https://thumbnails.roproxy.com/v1/users/avatar?userIds='..Arguments.Player.UserId..'&size=720x720&format=Png&isCircular=false')).data[1].imageUrl)
							:SetTimestamp()
							:SetFooter("Redefine:A BetterBans | Case "..(tonumber(LoadData.CaseId) or '-'))
							:SetColor(Color3.new(1, 0, 0))
							:BuildMessage()
						);
					end);

					return {
						Success = true,
						Message = "Successfully banned "..Arguments.Player.Name
					};
				else
					task.spawn(function()
						LogIt(DiscordModule.new()
							:SetTitle("Error saving a permanent ban!")
							:SetDescription("The ban request has yielded for too long, and the request was cancelled. Please make sure to try again later.")
							:AddField("Executor",`[{Executor.Name}](https://www.roblox.com/users/{Executor.UserId}/profile)`, true)
							:AddField("Player",`[{Arguments.Player.DisplayName} (@{Arguments.Player.Name})](https://www.roblox.com/users/{Arguments.Player.UserId}/profile)`, true)
							:AddField("Time",'Permanent', true)
							:AddField("Reason",Arguments.Reason)
							:SetCustomThumbnail(HttpService:JSONDecode(HttpService:GetAsync('https://thumbnails.roproxy.com/v1/users/avatar?userIds='..Arguments.Player.UserId..'&size=720x720&format=Png&isCircular=false')).data[1].imageUrl)
							:SetTimestamp()
							:SetFooter("Redefine:A BetterBans")
							:SetColor(Color3.new(1, 0, 0))
							:BuildMessage('<@274598834070618112>')
						);
					end);

					return {
						Success = false,
						Message = "Failed to ban "..Arguments.Player.Name..' due to an unknown error. (Datastore yielded for too long)'
					};
				end--]]
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
					Type = "SafePlayer";
					Required = true;
				};
				{
					Name = 'Minutes';
					Type = "Number";
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

			OnRun = function(env, Executor, Arguments:{Player:Player,Minutes:number,Reason:string}, Keys)
				if env:GetLevel(Arguments.Player) >= env:GetLevel(Executor) then
					return {
						Success = false;
						Message = 'You can\'t ban someone whose level is equal or higher than yours.';
					}
				end
				
				--[[local Load = Datastore:Load('BanProfile_'..tostring(Arguments.Player.UserId)):wait();
				local LoadData = Load.Data :: BanData?;

				if LoadData and LoadData.History then
					table.insert(LoadData.History,{
						Moderator = Executor.UserId;
						Action = 'Ban for '..ApproximateFromMinutes(Arguments.Minutes);
						Reason = Arguments.Reason;
						Timestamp = tick();
					});

					LoadData.Type = 'Active';
					LoadData.Moderator = Executor.UserId;
					LoadData.Reason = Arguments.Reason;
					LoadData.Timestamp = tick();
					LoadData.UnbannedBy = nil;
					LoadData.ExpiresAt = tick() + (Arguments.Minutes * 60);
				else
					LoadData = {
						Type = 'Active';
						Moderator = Executor.UserId;
						Reason = Arguments.Reason;
						Timestamp = tick();
						ExpiresAt = tick() + (Arguments.Minutes * 60);
						History = {
							{
								Moderator = Executor.UserId;
								Action = 'Ban for '..ApproximateFromMinutes(Arguments.Minutes);
								Reason = Arguments.Reason;
								Timestamp = tick();
							}
						};
					};
				end;

				if not Keys.usera then]]
					local s, _ = pcall(function()
						game:GetService("Players"):BanAsync({
							UserIds = {Arguments.Player.UserId};
							ApplyToUniverse = true;
							Duration = Arguments.Minutes * 60;
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
								:AddField("Player",`[{Arguments.Player.DisplayName} (@{Arguments.Player.Name})](https://www.roblox.com/users/{Arguments.Player.UserId}/profile)`, true)
								:AddField("Time", ApproximateFromMinutes(Arguments.Minutes), true)
								:AddField("Reason",Arguments.Reason)
								:SetCustomThumbnail(HttpService:JSONDecode(HttpService:GetAsync('https://thumbnails.roproxy.com/v1/users/avatar?userIds='..Arguments.Player.UserId..'&size=720x720&format=Png&isCircular=false')).data[1].imageUrl)
								:SetTimestamp()
								:SetFooter("Redefine:A")
								:SetColor(Color3.new(1, 0, 0))
								:BuildMessage()
							);
						end);

						return {
							Success = true;
							Message = "Successfully banned "..Arguments.Player.Name;
						}
					end
				--[[end;


				AssignCaseId(LoadData);
				Datastore:Save('BanProfile_'..tostring(Arguments.Player.UserId),LoadData):wait();

				Arguments.Player:Kick("You have been banned from this game. Reason: "..Arguments.Reason);

				task.spawn(function()
					LogIt(DiscordModule.new()
						:SetTitle("Player Banned")
						:AddField("Executor",`[{Executor.Name}](https://www.roblox.com/users/{Executor.UserId}/profile)`, true)
						:AddField("Player",`[{Arguments.Player.DisplayName} (@{Arguments.Player.Name})](https://www.roblox.com/users/{Arguments.Player.UserId}/profile)`, true)
						:AddField("Time", ApproximateFromMinutes(Arguments.Minutes), true)
						:AddField("Reason",Arguments.Reason)
						:SetCustomThumbnail(HttpService:JSONDecode(HttpService:GetAsync('https://thumbnails.roproxy.com/v1/users/avatar?userIds='..Arguments.Player.UserId..'&size=720x720&format=Png&isCircular=false')).data[1].imageUrl)
						:SetTimestamp()
						:SetFooter("Redefine:A BetterBans | Case "..(tonumber(LoadData.CaseId) or '-'))
						:SetColor(Color3.new(1, 0, 0))
						:BuildMessage()
					);
				end);

				return {
					Success = true,
					Message = "Successfully banned "..Arguments.Player.Name
				};]]
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

	env:RegisterCommand( -- Offline Banning
		{
			Disabled = false;
			Name = "OfflinePermBan";
			Description = "Bans an offline player for a certain amount of time.";
			Arguments = {
				{
					Name = 'PlayerId';
					Type = "Number";
					Required = true;
				};
				{
					Name = 'Reason';
					Type = "String";
					Required = true;
				};
			};
			Level = 4;
			Aliases = {"opban"};
			Keys = {
				usera = true;
			};

			OnRun = function(env:env, Executor:Player, Arguments:{PlayerId:number,Minutes:number,Reason:string}, Keys)
				if env:GetLevel(Arguments.PlayerId) >= env:GetLevel(Executor) then
					return {
						Success = false;
						Message = 'You can\'t ban someone whose level is equal or higher than yours.';
					}
				end

				--[[local Load = Datastore:Load('BanProfile_'..tostring(Arguments.PlayerId)):wait();
				local LoadData = Load.Data :: BanData?;

				if LoadData and LoadData.History then
					table.insert(LoadData.History,{
						Moderator = Executor.UserId;
						Action = 'Permanent Ban';
						Reason = Arguments.Reason;
						Timestamp = tick();
					});

					LoadData.Type = 'Active';
					LoadData.Moderator = Executor.UserId;
					LoadData.Reason = Arguments.Reason;
					LoadData.Timestamp = tick();
					LoadData.UnbannedBy = nil;
					LoadData.ExpiresAt = nil;
				else
					LoadData = {
						Type = 'Active';
						Moderator = Executor.UserId;
						Reason = Arguments.Reason;
						Timestamp = tick();
						ExpiresAt = nil;
						History = {
							{
								Moderator = Executor.UserId;
								Action = 'Permanent Ban';
								Reason = Arguments.Reason;
								Timestamp = tick();
							}
						};
					};
				end;

				if not Keys.usera then]]
					local s, _ = pcall(function()
						game:GetService("Players"):BanAsync({
							UserIds = {Arguments.PlayerId};
							ApplyToUniverse = true;
							Duration = -1;
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
								:AddField("Player",`[{game:GetService('Players'):GetNameFromUserIdAsync(Arguments.PlayerId)}](https://www.roblox.com/users/{Arguments.PlayerId}/profile)`, true)
								:AddField("Time", "Permanent", true)
								:AddField("Reason",Arguments.Reason)
								:SetCustomThumbnail(HttpService:JSONDecode(HttpService:GetAsync('https://thumbnails.roproxy.com/v1/users/avatar?userIds='..Arguments.PlayerId..'&size=720x720&format=Png&isCircular=false')).data[1].imageUrl)
								:SetTimestamp()
								:SetFooter("Redefine:A")
								:SetColor(Color3.new(1, 0, 0))
								:BuildMessage());
						end)
						return {
							Success = true,
							Message = "Successfully banned "..game:GetService('Players'):GetNameFromUserIdAsync(Arguments.PlayerId)
						};
					end
				--[[end

				AssignCaseId(LoadData);
				Datastore:Save('BanProfile_'..tostring(Arguments.PlayerId),LoadData):wait();

				if game:GetService("Players"):GetPlayerByUserId(Arguments.PlayerId) then
					game:GetService("Players"):GetPlayerByUserId(Arguments.PlayerId):Kick("You have been permanently banned from this game. Reason: "..Arguments.Reason);
				end

				task.spawn(function()
					LogIt(DiscordModule.new()
						:SetTitle("Player Banned")
						:AddField("Executor",`[{Executor.Name}](https://www.roblox.com/users/{Executor.UserId}/profile)`, true)
						:AddField("Player",`[{game:GetService('Players'):GetNameFromUserIdAsync(Arguments.PlayerId)}](https://www.roblox.com/users/{Arguments.PlayerId}/profile)`, true)
						:AddField("Time", "Permanent", true)
						:AddField("Reason",Arguments.Reason)
						:SetCustomThumbnail(HttpService:JSONDecode(HttpService:GetAsync('https://thumbnails.roproxy.com/v1/users/avatar?userIds='..Arguments.PlayerId..'&size=720x720&format=Png&isCircular=false')).data[1].imageUrl)
						:SetTimestamp()
						:SetFooter("Redefine:A BetterBans | Case "..(tonumber(LoadData.CaseId) or '-'))
						:SetColor(Color3.new(1, 0, 0))
						:BuildMessage()
					);
				end);

				return {
					Success = true,
					Message = "Successfully banned "..Arguments.PlayerId
				};]]
			end;
		}
	);

	env:RegisterCommand( -- Offline Banning
		{
			Disabled = false;
			Name = "OfflineBan";
			Description = "Bans an offline player for a certain amount of time.";
			Arguments = {
				{
					Name = 'PlayerId';
					Type = "Number";
					Required = true;
				};
				{
					Name = 'Minutes';
					Type = "Number";
					Required = true;
					Maximum = 40320;
					Minimum = 1;
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

			OnRun = function(env:env, Executor:Player, Arguments:{PlayerId:number,Minutes:number,Reason:string}, Keys)
				if env:GetLevel(Arguments.PlayerId) >= env:GetLevel(Executor) then
					return {
						Success = false;
						Message = 'You can\'t ban someone whose level is equal or higher than yours.';
					}
				end

				--[[local Load = Datastore:Load('BanProfile_'..tostring(Arguments.PlayerId)):wait();
				local LoadData = Load.Data :: BanData?;

				if LoadData and LoadData.History then
					table.insert(LoadData.History,{
						Moderator = Executor.UserId;
						Action = 'Ban for '..ApproximateFromMinutes(Arguments.Minutes);
						Reason = Arguments.Reason;
						Timestamp = tick();
					});

					LoadData.Type = 'Active';
					LoadData.Moderator = Executor.UserId;
					LoadData.Reason = Arguments.Reason;
					LoadData.Timestamp = tick();
					LoadData.UnbannedBy = nil;
					LoadData.ExpiresAt = tick() + (Arguments.Minutes * 60);
				else
					LoadData = {
						Type = 'Active';
						Moderator = Executor.UserId;
						Reason = Arguments.Reason;
						Timestamp = tick();
						ExpiresAt = tick() + (Arguments.Minutes * 60);
						History = {
							{
								Moderator = Executor.UserId;
								Action = 'Ban for '..ApproximateFromMinutes(Arguments.Minutes);
								Reason = Arguments.Reason;
								Timestamp = tick();
							}
						};
					};
				end;

				if not Keys.usera then]]
					local s, _ = pcall(function()
						game:GetService("Players"):BanAsync({
							UserIds = {Arguments.PlayerId};
							ApplyToUniverse = true;
							Duration = Arguments.Minutes * 60;
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
								:AddField("Player",`[{game:GetService('Players'):GetNameFromUserIdAsync(Arguments.PlayerId)}](https://www.roblox.com/users/{Arguments.PlayerId}/profile)`, true)
								:AddField("Time", ApproximateFromMinutes(Arguments.Minutes), true)
								:AddField("Reason",Arguments.Reason)
								:SetCustomThumbnail(HttpService:JSONDecode(HttpService:GetAsync('https://thumbnails.roproxy.com/v1/users/avatar?userIds='..Arguments.PlayerId..'&size=720x720&format=Png&isCircular=false')).data[1].imageUrl)
								:SetTimestamp()
								:SetFooter("Redefine:A")
								:SetColor(Color3.new(1, 0, 0))
								:BuildMessage()
							);
						end);

						return {
							Success = true;
							Message = "Successfully banned "..game:GetService('Players'):GetNameFromUserIdAsync(Arguments.PlayerId);
						}
					end
				--[[end;

				AssignCaseId(LoadData);
				Datastore:Save('BanProfile_'..tostring(Arguments.PlayerId),LoadData):wait();

				if game:GetService("Players"):GetPlayerByUserId(Arguments.PlayerId) then
					game:GetService("Players"):GetPlayerByUserId(Arguments.PlayerId):Kick("You have been banned from this game. Reason: "..Arguments.Reason);
				end

				task.spawn(function()
					LogIt(DiscordModule.new()
						:SetTitle("Player Banned")
						:AddField("Executor",`[{Executor.Name}](https://www.roblox.com/users/{Executor.UserId}/profile)`, true)
						:AddField("Player",`[{game:GetService('Players'):GetNameFromUserIdAsync(Arguments.PlayerId)}](https://www.roblox.com/users/{Arguments.PlayerId}/profile)`, true)
						:AddField("Time", ApproximateFromMinutes(Arguments.Minutes), true)
						:AddField("Reason",Arguments.Reason)
						:SetCustomThumbnail(HttpService:JSONDecode(HttpService:GetAsync('https://thumbnails.roproxy.com/v1/users/avatar?userIds='..Arguments.PlayerId..'&size=720x720&format=Png&isCircular=false')).data[1].imageUrl)
						:SetTimestamp()
						:SetFooter("Redefine:A BetterBans | Case "..(tonumber(LoadData.CaseId) or '-'))
						:SetColor(Color3.new(1, 0, 0))
						:BuildMessage()
					);
				end);

				return {
					Success = true,
					Message = "Successfully banned "..game:GetService('Players'):GetNameFromUserIdAsync(Arguments.PlayerId)
				};]]
			end;
		}
	)

	--[[env:RegisterCommand(
		{
			Disabled = false;
			Name = "Editban";
			Description = "Edits an ACTIVE ban on a player.";
			Arguments = {
				{
					Name = 'PlayerId';
					Type = "Number";
					Required = true;
				};
				{
					Name = 'Argument';
					Type = "String";
					Required = true;
					Options = {
						'Time';
						'Reason';
					};
				};
				{
					Name = 'NewValue';
					Type = 'String';
					Required = true;
				};
			};
			Level = 3;

			OnRun = function(env:env, Executor:Player, Arguments:{PlayerId:number,Argument:'Time'|'Reason',NewValue:string}, Keys)
				if env:GetLevel(Arguments.PlayerId) >= env:GetLevel(Executor) then
					return {
						Success = false;
						Message = 'You can\'t edit a ban of a player whose level is equal or higher than yours.';
					}
				end

				local Load = Datastore:Load('BanProfile_'..tostring(Arguments.PlayerId)):wait();
				local LoadData = Load.Data :: BanData?;

				if LoadData and LoadData.History then
					if GetActiveType(LoadData)=='Active' then
						if Arguments.Argument=='Reason' then
							LoadData.Reason = Arguments.NewValue;
						elseif Arguments.Argument=='Time' then
							if LoadData.ExpiresAt then
								local NewTime:number? = tonumber(Arguments.NewValue);

								if not NewTime then
									return {
										Success = false;
										Message = 'You must provide a valid number of minutes.';
									}
								else
									NewTime=math.clamp(NewTime,1,43200);
								end

								local Timestamp = LoadData.History[#LoadData.History].Timestamp;
								LoadData.ExpiresAt = Timestamp + (NewTime * 60);
							else
								return {
									Success = false;
									Message = 'You can\'t edit a permanent ban Time value: Unban and re-ban with the desired time.';
								}
							end
						else
							return {
								Success = false;
								Message = 'Argument type is invalid (Accepting "Reason" or "Time")';
							}
						end

						table.insert(LoadData.History,{
							Moderator = Executor.UserId;
							Action = 'Edited '..Arguments.Argument..' to '..Arguments.NewValue;
							Reason = 'Reason can\'t be provided for this command.';
							Timestamp = tick();
						});

						Datastore:Save('BanProfile_'..tostring(Arguments.PlayerId),LoadData):wait();

						LogIt(DiscordModule.new()
							:SetTitle("Active Ban Edited")
							:AddField("Executor",`[{Executor.Name}](https://www.roblox.com/users/{Executor.UserId}/profile)`,true)
							:AddField("Player",`[{game:GetService('Players'):GetNameFromUserIdAsync(Arguments.PlayerId)}](https://www.roblox.com/users/{Arguments.PlayerId}/profile)`,true)
							:AddField("Value Changed",Arguments.Argument)
							:AddField("New Value",Arguments.NewValue)
							:SetCustomThumbnail(HttpService:JSONDecode(HttpService:GetAsync('https://thumbnails.roproxy.com/v1/users/avatar?userIds='..Arguments.PlayerId..'&size=720x720&format=Png&isCircular=false')).data[1].imageUrl)
							:SetTimestamp()
							:SetFooter("Redefine:A BetterBans | Case "..(tonumber(LoadData.CaseId) or '-'))
							:SetColor(Color3.new(0.333333, 1, 0))
							:BuildMessage()
						);

						return {
							Success = true,
							Message = "Successfully changed the " .. Arguments.Argument .. " to " .. Arguments.NewValue .. " for "..game:GetService('Players'):GetNameFromUserIdAsync(Arguments.PlayerId)
						};
					else
						return {
							Success = false,
							Message = "You can only edit active bans."
						};
					end;
				else
					return {
						Success = false,
						Message = "Player has no ban data, or has been banned using the Roblox-provided Ban API - Please try banning again."
					};
				end;
			end;
		}
	);]]

	env:RegisterCommand(
		{
			Disabled = false;
			Name = "Unban";
			Description = "Unbans a player.";
			Arguments = {
				{
					Name = 'PlayerId';
					Type = "Number";
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
				--[[if Serverbans[Arguments.PlayerId] then
					Serverbans[Arguments.PlayerId]=nil;

					if game.PrivateServerId == "" then
						LogIt(DiscordModule.new()
							:SetTitle("Player Unserver-banned")
							:AddField("Executor",`[{Executor.Name}](https://www.roblox.com/users/{Executor.UserId}/profile)`)
							:AddField("Player",`[{game:GetService('Players'):GetNameFromUserIdAsync(Arguments.PlayerId)}](https://www.roblox.com/users/{Arguments.PlayerId}/profile)`)
							:AddField("Reason",Arguments.Reason)
							:SetCustomThumbnail(HttpService:JSONDecode(HttpService:GetAsync('https://thumbnails.roproxy.com/v1/users/avatar?userIds='..Arguments.PlayerId..'&size=720x720&format=Png&isCircular=false')).data[1].imageUrl)
							:SetTimestamp()
							:SetFooter("Redefine:A BetterBans")
							:SetColor(Color3.new(0.333333, 1, 0))
							:BuildMessage()
						);
					end;

					return {Success=true;Message='Removed Serverban from '..game:GetService('Players'):GetNameFromUserIdAsync(Arguments.PlayerId)}
				end
				--
				if env:GetLevel(Executor) <= 2 then return {Success = false; Message = "You may not use this command outside of your VIP server."} end;
				local Load = Datastore:Load('BanProfile_'..tostring(Arguments.PlayerId)):wait();
				local LoadData = Load.Data :: BanData?;

				if LoadData and LoadData.History then
					if LoadData.Type == 'Active' then
						if LoadData.UnbannedBy then
							return {
								Success = false,
								Message = "Player is already unbanned.";
							};
						elseif LoadData.ExpiresAt and LoadData.ExpiresAt < tick() then
							return {
								Success = false,
								Message = "The ban is already expired.";
							};
						else
							table.insert(LoadData.History,{
								Moderator = Executor.UserId;
								Action = 'Unban';
								Reason = Arguments.Reason;
								Timestamp = tick();
							});

							LoadData.Type = 'Unbanned';
							LoadData.UnbannedBy = {
								Moderator = Executor.UserId;
								Reason = Arguments.Reason;
								Timestamp = tick();
							};

							AssignCaseId(LoadData);
							Datastore:Save('BanProfile_'..tostring(Arguments.PlayerId),LoadData):wait();

							LogIt(DiscordModule.new()
								:SetTitle("Player Unbanned")
								:AddField("Executor",`[{Executor.Name}](https://www.roblox.com/users/{Executor.UserId}/profile)`)
								:AddField("Player",`[{game:GetService('Players'):GetNameFromUserIdAsync(Arguments.PlayerId)}](https://www.roblox.com/users/{Arguments.PlayerId}/profile)`)
								:AddField("Reason",Arguments.Reason)
								:SetCustomThumbnail(HttpService:JSONDecode(HttpService:GetAsync('https://thumbnails.roproxy.com/v1/users/avatar?userIds='..Arguments.PlayerId..'&size=720x720&format=Png&isCircular=false')).data[1].imageUrl)
								:SetTimestamp()
								:SetFooter("Redefine:A BetterBans | Case "..(tonumber(LoadData.CaseId) or '-'))
								:SetColor(Color3.new(0.333333, 1, 0))
								:BuildMessage()
							);

							return {
								Success = true,
								Message = "Successfully unbanned "..Arguments.PlayerId
							};
						end;
					else
						local s, _ = pcall(function()
							game.Players:UnbanAsync({
								UserIds = {Arguments.PlayerId};
								ApplyToUniverse = true;
							});
						end);
						if s then
							return {
								Success = false,
								Message = "Player is not currently banned, or has been successfully unbanned from the Roblox Ban API."
							}
						end

						return {
							Success = false,
							Message = "Player is not currently banned."
						};
					end;
				else
					pcall(function()
						game:GetService("Players"):UnbanAsync({
							UserIds = {Arguments.PlayerId};
							ApplyToUniverse = true;
						});
					end)


					return {
						Success = false,
						Message = "Player has no ban data."
					};
				end;]]
				
				game:GetService("Players"):UnbanAsync({
					UserIds = {Arguments.PlayerId};
					ApplyToUniverse = true;
				});
				
				return {
					Success = true,
					Message = "Cleared "..Arguments.PlayerId.."'s ban data."
				};
			end;
		}
	);

	--local cache = {}; -- damn

	--[[env:RegisterCommand(
		{
			Disabled = false;
			Name = "BanHistory";
			Description = "Gets the ban history of a player.";
			Arguments = {
				{
					Name = 'User';
					Type = "Player";
					Required = true;
				};
			};
			Aliases = {'bans'};
			Level = 3;

			OnRun = function(env, Executor, Arguments, Keys)
				local Load = Datastore:Load('BanProfile_'..tostring(Arguments.User.UserId)):wait();
				local LoadData = Load.Data :: BanData?;

				if LoadData and LoadData.History then
					local BuiltList = {};

					for _,v in LoadData.History do
						local Moderator = cache[v.Moderator] or game.Players:GetNameFromUserIdAsync(v.Moderator);
						if not cache[v.Moderator] then
							cache[v.Moderator] = Moderator;
						end;
						local Action = v.Action;
						local Reason = v.Reason;
						local Timestamp = v.Timestamp;

						table.insert(BuiltList, 1, "Action: "..Action.."\nModerator: "..Moderator.."\nReason: "..Reason.."\n\n"..os.date("%c",math.floor(Timestamp)));
					end;

					env.RemoteEvent:FireClient(Executor,"CreateList","Ban History for "..Arguments.User.Name,BuiltList);

					return {
						Success = true;
						Message = "Showing ban history for "..Arguments.User.Name;
					};
				else
					return {
						Success = false;
						Message = "Player has no ban data.";
					};
				end;
			end;
		}
	);]]
	--[[env:RegisterCommand(
		{
			Disabled = false;
			Name = "OfflineBanHistory";
			Description = "Gets the ban history of a player.";
			Arguments = {
				{
					Name = 'UserId';
					Type = "Number";
					Required = true;
				};
			};
			Aliases = {'offlinebans','obans'};
			Level = 3;

			OnRun = function(env, Executor, Arguments, Keys)
				local Load = Datastore:Load('BanProfile_'..tostring(Arguments.UserId)):wait();
				local LoadData = Load.Data :: BanData?;

				if LoadData and LoadData.History then
					local BuiltList = {};
					for _,v in LoadData.History do
						local Moderator = cache[v.Moderator] or game.Players:GetNameFromUserIdAsync(v.Moderator);
						if not cache[v.Moderator] then
							cache[v.Moderator] = Moderator;
						end;
						local Action = v.Action;
						local Reason = v.Reason;
						local Timestamp = v.Timestamp;

						table.insert(BuiltList, 1, "Action: "..Action.."\nModerator: "..Moderator.."\nReason: "..Reason.."\n\n"..os.date("%c",math.floor(Timestamp)));
					end;

					env.RemoteEvent:FireClient(Executor,"CreateList","Ban History for "..Arguments.UserId,BuiltList);

					return {
						Success = true;
						Message = "Showing ban history for "..Arguments.UserId;
					};
				else
					return {
						Success = false;
						Message = "Player has no ban data.";
					};
				end;
			end;
		}
	);]]

	--[[env.Signals.JoinEvent:Connect(function(Player)
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
	end);]]
end

return mod