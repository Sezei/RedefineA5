game:GetService("TestService"):Message("Redefine:A5 | BuildId " .. script.Parent:GetAttribute("nxversion"));

local Settings = {
	NoTaskbar = script.Parent:GetAttribute("notaskbar");
	ConsoleKeybind = script.Parent:GetAttribute("consolekeybind");

	NotificationSounds = true;
};

--// Services
local ContentProvider = game:GetService("ContentProvider");
local TweenService:TweenService = game:GetService("TweenService");
local UserInputService:UserInputService = game:GetService("UserInputService");
local TextChatService = game:GetService("TextChatService");
local ReplicatedStorage = game:GetService("ReplicatedStorage");
local Players = game:GetService("Players");

--// Inner stuff
local GUI:ScreenGui = script.Parent;
local DefaultAssets:Folder = GUI:WaitForChild("DefaultAssets") :: Folder;
local Assets:Folder = GUI:FindFirstChild("Assets") :: Folder;
local Taskbar:Frame = GUI:FindFirstChild("Taskbar") :: Frame;
local Sidemenu:Frame = GUI:FindFirstChild("Sidemenu") :: Frame;
local Commandbar = GUI:FindFirstChild("CommandBar");

--// Requires / env
local env = require(script:WaitForChild("ClientEnvironment", 1));
env.Dragify = require(script:FindFirstChild("Dragify"));
env.Cardboard = require(script:FindFirstChild("CardBoard"));
env.Colors = require(script:WaitForChild("ColorLib", 1));
env.Settings = Settings;
env.GaggedUsers = {};

local Util = {};
local Levels = {};
local Theme = {};
local QuickActions = {};
local CommandsData = {};
local Qualifiers = {};
local Remotes = {};

env.Util = 		Util;
env.Levels = 	{};

--// Connections
script.Parent.AttributeChanged:Connect(function(Attribute)
	if Attribute == "consolekeybind" then
		Settings.ConsoleKeybind = script.Parent:GetAttribute("consolekeybind");
	end;
end);

--// Util
function Util.CloneMissingAssets(Defaults: Instance, Target: Instance)
	for _, v in Defaults:GetChildren() do
		if not Target:FindFirstChild(v.Name) then
			v:Clone().Parent = Target;
			v:Destroy();
		end;
	end;
end

function Util.NameToMethod(Method: string)
	Method = string.lower(Method or "");
	if Method == "sm" then
		return "sourcemod";
	elseif Method == "mc" then
		return "minecraft";
	elseif Method == "s" then
		return "simple";
	end
	return Method;
end

function Util.ArgSplit(str: string)
	local args = {};
	local quoted = {};
	local inquote = false;
	local current = "";
	local currentWasQuoted = false;

	for i = 1, #str do
		local char = str:sub(i, i);
		if char == '"' then
			if not inquote then
				inquote = true;
				currentWasQuoted = true;
			else
				inquote = false;
			end
		elseif char == " " and not inquote then
			table.insert(args, current);
			table.insert(quoted, currentWasQuoted);
			current = "";
			currentWasQuoted = false;
		else
			current ..= char;
		end
	end

	table.insert(args, current);
	table.insert(quoted, currentWasQuoted);

	return args, inquote, quoted;
end

function Util.SafeGet(Parent: Instance, Name: string, ClassName: string?)
	local obj = Parent:FindFirstChild(Name);
	if not obj then return nil end;
	if ClassName and not obj:IsA(ClassName) then return nil end;
	return obj;
end

local TimeUnits = {
	["s"] = 1;
	["m"] = 60;
	["h"] = 60 * 60;
	["d"] = 60 * 60 * 24;
	["w"] = 60 * 60 * 24 * 7;
};

function Util.ParseTime(str: string) -- definitely didnt steal the code from a friend of mine lol
	if typeof(str) ~= "string" then
		return false, "Expected a string.";
	end;

	local raw = str:gsub("%s+", "");
	if raw == "" then
		return false, "Time is empty.";
	end;

	local units = {
		["s"] = 1;
		["m"] = 60;
		["h"] = 3600;
		["d"] = 86400;
		["w"] = 604800;
	};

	local rawMinutes = tonumber(raw);
	if rawMinutes then
		if rawMinutes < 0 then
			return false, "Time cannot be negative.";
		end
		local seconds = math.floor(rawMinutes * 60);
		return true, {
			Seconds = seconds;
			Minutes = rawMinutes;
			Time = os.time() + seconds;
		};
	end;

	local amountStr, unitStr = raw:match("^(%d*%.?%d+)([smhdwSMHDW])$");
	if not amountStr or not unitStr then
		return false, "Invalid time format. Examples: 10, 5m, 1h, 1d, 1w";
	end;

	local amount = tonumber(amountStr);
	if not amount then
		return false, "Invalid time number.";
	end
	if amount < 0 then
		return false, "Time cannot be negative.";
	end

	local unit = string.lower(unitStr);
	local mult = units[unit];

	if not mult then
		return false, "Unknown time unit '" .. tostring(unitStr) .. "'.";
	end;

	local seconds = math.floor(amount * mult);
	if seconds < 0 then
		return false, "Time cannot be negative.";
	end

	return true, {
		Seconds = seconds;
		Minutes = math.round(seconds / 60);
		Time = os.time() + seconds;
	};
end


--// Remotes + player init
do
	local InternalEvent:BindableEvent = GUI:FindFirstChild("InternalCommunication") :: BindableEvent;
	local RemoteEvent = ReplicatedStorage:WaitForChild("NxRemoteEvent") :: RemoteEvent;
	local RemoteFunction = ReplicatedStorage:WaitForChild("NxRemoteFunction") :: RemoteFunction;

	local LocalPlayer:Player = Players.LocalPlayer;
	if not LocalPlayer then
		Players:GetPropertyChangedSignal("LocalPlayer"):Wait();
		LocalPlayer = Players.LocalPlayer;
	end

	env.InternalEvent = InternalEvent;
	env.RemoteEvent = RemoteEvent;
	env.RemoteFunction = RemoteFunction;
	env.Player = LocalPlayer;

	env.GUI = GUI;
	env.Assets = Assets;

	Remotes.InternalEvent = InternalEvent;
	Remotes.RemoteEvent = RemoteEvent;
	Remotes.RemoteFunction = RemoteFunction;

	Remotes.LocalPlayer = LocalPlayer;
	Remotes.Players = Players;
end

--// Apply default assets + theme
do
	Util.CloneMissingAssets(DefaultAssets, Assets);

	if Assets:FindFirstChild("_Theme") then
		local Loaded = require(Assets._Theme);
		if type(Loaded) == "table" then
			for Func, Replacement in Loaded do
				env[Func] = Replacement;
			end
		elseif type(Loaded) == "function" then
			Loaded(env);
		end
	end
end

--// For some reason these values keep resetting, so we have to set them again.
GUI.IgnoreGuiInset = true;
GUI.ResetOnSpawn = false;

--// Notification option callbacks
do
	local Listenings = {};

	Remotes.Listenings = Listenings;

	Remotes.InternalEvent.Event:Connect(function(Action, UID, Option)
		if Action == "NotificationOptionSelected" then
			if Listenings[UID] and type(Listenings[UID]) == "function" then
				Listenings[UID](Option);
			end
			Remotes.RemoteEvent:FireServer("NotificationOptionSelected", UID, Option);
		end
	end);
end

--// Levels (cache)
do
	local StoredLevels = {};
	local LocalPlayer = Remotes.LocalPlayer;

	function Levels.Get(UserId: number)
		if StoredLevels[UserId] ~= nil then
			return StoredLevels[UserId];
		end
		local lvl = Remotes.RemoteFunction:InvokeServer("GetLevel", UserId);
		StoredLevels[UserId] = lvl;
		return lvl;
	end

	function Levels.Set(UserId: number, Level: number)
		StoredLevels[UserId] = Level;
	end

	function Levels.GetLocal()
		return Levels.Get(LocalPlayer.UserId);
	end

	function Levels.GetStore()
		return StoredLevels;
	end

	Levels.Set(LocalPlayer.UserId, Levels.GetLocal());
end

--// QuickAction API
do
	local LocalPlayer = Remotes.LocalPlayer;
	local QuickActionAPI = nil;
	local QuickActionCursor = nil;
	local QuickActionTabs = {};

	QuickActions.API = function()
		return QuickActionAPI;
	end
	QuickActions.SetCursor = function(Cursor)
		QuickActionCursor = Cursor;
	end
	QuickActions.GetCursor = function()
		return QuickActionCursor;
	end
	QuickActions.GetTabs = function()
		return QuickActionTabs;
	end

	if not Settings.NoTaskbar then
		QuickActionAPI = {
			LocalPlayer = LocalPlayer;

			Button = function(self, Text)
				local Button:TextButton = QuickActionCursor:FindFirstChild("ButtonTemplate"):Clone() :: TextButton;
				Button.Text = Text;
				Button.Parent = QuickActionCursor;
				Button.Visible = true;
				return Button;
			end;

			AddInstanceButton = function(self, Instance, Text)
				local Button:TextButton = QuickActionCursor:FindFirstChild("ButtonTemplate"):Clone() :: TextButton;
				Button.Text = Text;
				Button.Parent = QuickActionCursor;
				Button.Visible = true;

				Instance:GetPropertyChangedSignal("Parent"):Connect(function()
					if Instance.Parent == nil then
						Button:Destroy();
					end;
				end);

				return Button;
			end;

			AddPlayerButton = function(self, Player, Text)
				return QuickActionAPI:AddInstanceButton(Player, Text);
			end;

			RunCommand = function(self, Command)
				Remotes.RemoteEvent:FireServer("CommandSent", Command);
			end;

			RunEnvCommand = function(self, Command)
				return env[Command];
			end;
		};
	end

	QuickActions._API = QuickActionAPI;
end

--// Get commands/settings from server + command module registration
do
	local Commands = Remotes.RemoteFunction:InvokeServer("GetCommands");
	local CommandModules = ReplicatedStorage:FindFirstChild("RA5_Commands");
	local Method = string.lower(Remotes.RemoteFunction:InvokeServer("GetMethod"));

	CommandsData.Commands = Commands;
	CommandsData.CommandModules = CommandModules;
	CommandsData.Method = Util.NameToMethod(Method);

	env.Commands = {};

	-- purge textcommands you can't use
	task.spawn(function()
		local LocalLevel = Levels.GetLocal();
		local cmdstoremove = {};

		for _, v in Commands do
			if v.Level > LocalLevel then
				cmdstoremove["/" .. string.lower(v.Name)] = true;
			end
		end

		pcall(function()
			local CmdFolder = TextChatService:FindFirstChild("TextChatCommands");
			if not CmdFolder then return end;

			for _, v:TextChatCommand in CmdFolder:GetChildren() do
				local Alias = "/" .. string.lower(v.PrimaryAlias);
				if cmdstoremove[Alias] then
					v:Destroy();
				end
			end
		end);
	end);

	local function RegisterModule(Module)
		if not Module:IsA("ModuleScript") then return end;

		pcall(function()
			local Data = require(Module);
			local LocalLevel = Levels.GetLocal();

			if LocalLevel >= Data.Level then
				if Data.QuickActions then
					table.insert(QuickActions.GetTabs(), Data.QuickActions);
				end
				if Data.OnClientLoad then
					Data.OnClientLoad(env, LocalLevel >= Data.Level);
				end
				if Data.OnClientRun then
					env.Commands[Data.Name:lower()] = Data.OnClientRun;
				end
			end
		end);
	end

	CommandsData.RegisterModule = RegisterModule;

	if not Settings.NoTaskbar and CommandModules then
		pcall(function()
			if Commands["kick"] and Commands["kick"].Level > Levels.GetLocal() then
				QuickActions.GetTabs().InstantKick = nil;
			end
		end);

		CommandModules.ChildAdded:Connect(function(Module)
			RegisterModule(Module);
		end);

		for _, Module in CommandModules:GetChildren() do
			RegisterModule(Module);
		end
	end
end

--// Qualifiers + FindPlayers
do
	local sortedqualifiers = {};
	local Method = CommandsData.Method;

	if not (Method == "sourcemod" or Method == "minecraft" or Method == "simple") then
		warn("Invalid qualifier method selected. Defaulting to 'sourcemod'.");
		Method = "sourcemod";
		CommandsData.Method = Method;
	end;

	for _, qualifier in require(script.Qualifiers) do
		if qualifier.methods[Method] then
			sortedqualifiers[qualifier.methods[Method]] = qualifier;
		end;
	end;

	Qualifiers.Sorted = sortedqualifiers;

	local function FindPlayers(Names, Strict)
		if string.len(Names) == 0 then return nil end;

		local names = string.split(Names, ",");
		local matches = {};
		local players = Players:GetPlayers();

		local function Add(p)
			if p and not table.find(matches, p) then
				matches[#matches + 1] = p;
			end
		end

		-- Strict: Player.Name only
		if Strict then
			for _, Name in names do
				local ln = string.lower(Name);
				for _, v in players do
					if string.lower(v.Name):sub(1, #Name) == ln then
						Add(v);
					end
				end
			end
			return matches;
		end

		for _, Name in names do
			local Raw = Name;
			local NameLower = string.lower(Name);

			-- Qualifiers
			do
				for method, qualifier in sortedqualifiers do
					if NameLower == string.lower(method) then
						local MatchedPlayers = qualifier.identifier(false, players, Remotes.LocalPlayer);
						for _, p in MatchedPlayers do
							Add(p);
						end
					end
				end
			end

			-- Local join index (#1, #2, ...)
			if Raw:sub(1, 1) == "#" then
				local wanted = tonumber(Raw:sub(2));
				if wanted then
					for _, v in players do
						local LocalId = v:GetAttribute("ra_LocalId");
						if LocalId and LocalId == wanted then
							Add(v);
						end
					end
				end
			end

			-- Username-only
			for _, v in players do
				local atName = string.lower("@" .. v.Name);
				if atName:sub(1, #Raw) == NameLower then
					Add(v);
				end
			end

			-- DisplayName
			for _, v in players do
				local dn = string.lower(v.DisplayName);
				if dn:sub(1, #Raw) == NameLower then
					Add(v);
				end
			end

			-- Username
			for _, v in players do
				local un = string.lower(v.Name);
				if un:sub(1, #Raw) == NameLower then
					Add(v);
				end
			end
		end

		return matches;
	end

	Qualifiers.FindPlayers = FindPlayers;
end

--// Commandbar + highlighting
do
	local LocalPlayer = Remotes.LocalPlayer;
	local RemoteEvent = Remotes.RemoteEvent;
	local RemoteFunction = Remotes.RemoteFunction;

	local Commands = CommandsData.Commands;
	local StoredLevels = Levels.GetStore();

	local LastCommands = {};
	local EscapeForms = {
		["<"] = "&lt;";
		[">"] = "&gt;";
		["&"] = "&amp;";
		["'"] = "&apos;";
	};

	local CurrentAutoComplete = nil;

	local TextMask = Commandbar:FindFirstChild("TextMask");
	local WarningsFrame = Commandbar:FindFirstChild("Warnings");
	local WarningTemplate = WarningsFrame and WarningsFrame:FindFirstChild("Template");

	local function ClearWarnings()
		if not WarningsFrame then return end;
		for _, v in WarningsFrame:GetChildren() do
			if v.Name ~= "Template" and v:IsA("TextLabel") then
				v:Destroy();
			end
		end
	end

	local function AddWarning(Name: string, RichText: string, LayoutOrder: number?)
		if not (WarningsFrame and WarningTemplate) then return end;

		local Warning = WarningTemplate:Clone();
		Warning.Name = Name;
		Warning.Text = RichText;
		Warning.Visible = true;
		Warning.Parent = WarningsFrame;
		if LayoutOrder ~= nil then
			Warning.LayoutOrder = LayoutOrder;
		end
		return Warning;
	end

	local function MaskText(Text:string, Color:Color3|string, Bold:boolean?)
		local Mask = "";
		local FontColor = '';

		if typeof(Color) == 'Color3' then
			FontColor = env.ToHex(Color);
		else
			FontColor = tostring(Color or "FFFFFF");
			FontColor = string.gsub(FontColor, "#", "");
		end;

		Mask = "<font color='#" .. FontColor .. "'>";
		Mask ..= (Bold and '<b>' or '');
		Mask ..= Text;
		Mask ..= (Bold and '</b>' or '');
		Mask ..= "</font>";

		return Mask;
	end

	local function MaskCommandName(Command: string, CommandData)
		local MaskedText = "";
		local ValidCommand = false;
		local Compatibility = false;

		if Commands[Command] and Commands[Command].Description:sub(1, 7) == "(NANO);" then
			Compatibility = true;
			MaskedText = MaskText(Command, 'D5D5D5', true);
			ValidCommand = true;
		elseif Commands[Command] then
			MaskedText = MaskText(Command, 'FFFF77', true);
			ValidCommand = true;
		else
			MaskedText = MaskText(Command, 'FFCC00', false);
		end

		if ValidCommand and Commands[Command].Color then
			MaskedText = MaskText(Command, Commands[Command].Color, false);
		end

		return MaskedText, ValidCommand, Compatibility;
	end

	local function ProcessKeys(Args: {string}, Quoted: {boolean}, CommandName: string, MaskedText: string)
		for i = #Args, 1, -1 do
			local arg = Args[i];
			if arg:sub(1, 2) == "--" then
				local key = string.lower(arg:sub(3));
				local value = true;
				local valid = true;

				if key == "" then
					MaskedText ..= " " .. MaskText(arg, "FF0000", true);
					AddWarning("Warning_Key" .. i, MaskText("Invalid Key", "ff7700") .. "; " .. i .. "; Key is empty");
					valid = false;
				end

				if key:find("=") then
					local split = key:split("=");
					key = split[1];
					value = split[2];

					if key == "" then
						MaskedText ..= " " .. MaskText(arg, "FF0000", true);
						AddWarning("Warning_Key" .. i, MaskText("Invalid Key", "ff7700") .. "; " .. i .. "; Key is empty");
						valid = false;
					end
				end

				if valid and (not Commands[CommandName].Keys[key] and not (key == "delay") and not (key == "silent")) then
					AddWarning("Warning_Key" .. i, MaskText("Unknown Key", "ffaa00") .. "; " .. i .. "; Key is valid, but unused.");
				end

				if valid then
					MaskedText ..= " " .. MaskText(arg, "FFFF99", false);
				end

				table.remove(Args, i);
				table.remove(Quoted, i);
			end
		end

		return Args, Quoted, MaskedText;
	end

	local function HighlightArg(CommandName: string, ArgDef, argnum: number, arg: string, inquote: boolean, wasQuoted: boolean)
		local Type = string.lower(ArgDef.Type);
		local Mask = "";
		local AutoComplete = nil;

		local DisplayArg = arg;

		if wasQuoted then
			if inquote then
				Mask ..= " " .. MaskText('"', "FF7700", true);
				AddWarning("Warning_UnclosedQuote", MaskText("Unclosed Argument", "ffaa00") .. "; Make sure to close the quotes!");
				DisplayArg = arg;
			else
				DisplayArg = '"' .. arg .. '"';
			end
		end


		if Type == "string" then
			if ArgDef.Options and type(ArgDef.Options) == "table" then
				local found = false;
				for _, v in ArgDef.Options do
					if v:sub(1, #arg):lower() == arg:lower() then
						found = v;
						break;
					end
				end

				if not found then
					Mask ..= " " .. MaskText(DisplayArg, "FFFFBC", false);
					AddWarning("Warning" .. argnum, MaskText("Notice", "ffaa00") .. "; " .. argnum .. "; This argument is not matching any of the options in the table.");
				else
					Mask ..= " " .. MaskText(DisplayArg, "FFFFFF", false);
					AutoComplete = string.sub(found, string.len(arg) + 1);
					Mask ..= MaskText(AutoComplete, "CCCCCC", false);
				end
			elseif ArgDef.Options and type(ArgDef.Options) == "function" then
				local Success, Option = pcall(function()
					return ArgDef.Options(arg:lower());
				end);

				if Success and Option then
					Mask ..= " " .. MaskText(DisplayArg, "FFFFFF", false);
					AutoComplete = string.sub(Option, string.len(arg) + 1);
					Mask ..= MaskText(AutoComplete, "CCCCCC", false);
				elseif Success then
					Mask ..= " " .. MaskText(DisplayArg, "FFFFBC", false);
					AddWarning("Warning" .. argnum, MaskText("Notice", "ffaa00") .. "; " .. argnum .. "; This argument does not match the function's return value.");
				else
					Mask ..= " " .. MaskText(DisplayArg, "FF0000", true);
					AddWarning("Warning" .. argnum, MaskText("Malformed Type", "ff0000") .. "; " .. argnum .. "; The argument's Options function returned an error.");
				end
			elseif ArgDef.Required and arg:gsub("%s+", "") == "" then
				AddWarning("Warning" .. argnum, MaskText("String Empty", "ff3300") .. "; " .. argnum .. "; This argument requires an input and cannot be empty.");
				Mask ..= " " .. MaskText(DisplayArg, "FFFFFF", false);
			else
				Mask ..= " " .. MaskText(DisplayArg, "FFFFFF", false);
			end

		elseif Type == "custom" then
			if ArgDef.Validator then
				local ok, err = pcall(ArgDef.Validator, arg);
				if ok then
					if ArgDef.Highlighting then
						local success, ret = pcall(ArgDef.Highlighting, arg);
						if success then
							Mask ..= " " .. ret;
						else
							if not err[1] then
								Mask ..= " " .. MaskText(DisplayArg, "FF0000", true);
							else
								Mask ..= " " .. MaskText(err[1], "FFFFFF", false);
							end;
						end;
					else
						if not err[1] then
							Mask ..= " " .. MaskText(DisplayArg, "FF0000", true);
						else
							Mask ..= " " .. MaskText(err[1], "FFFFFF", false);
						end;
					end;

					if not err[1] then
						AddWarning("Warning" .. argnum, MaskText("Custom Error", "ffaa00") .. "; " .. argnum .. "; " .. err[2]);
					end;
				else
					Mask ..= " " .. MaskText(DisplayArg, "FF0000", true);
					AddWarning("Warning" .. argnum, MaskText("Malformed Type", "ff0000") .. "; " .. argnum .. "; Custom type returns error; " .. err);
				end;
			else
				AddWarning("Warning" .. argnum, MaskText("Malformed Type", "ff0000") .. "; " .. argnum .. "; Custom type missing a validator.");
				Mask ..= " " .. MaskText(DisplayArg, "FF0000", true);
			end

		elseif Type == "number" or Type == "slider" then
			local num = tonumber(arg);
			if num then
				if num > (ArgDef.Maximum or math.huge) then
					Mask ..= " " .. MaskText(DisplayArg, "FF5500", true);
					AddWarning("Warning" .. argnum, MaskText("Notice", "ffaa00") .. "; " .. argnum .. "; " .. ArgDef.Maximum .. " is the maximum value for this argument.");
				elseif num < (ArgDef.Minimum or -math.huge) then
					Mask ..= " " .. MaskText(DisplayArg, "FF5500", true);
					AddWarning("Warning" .. argnum, MaskText("Notice", "ffaa00") .. "; " .. argnum .. "; " .. ArgDef.Minimum .. " is the minimum value for this argument.");
				elseif num ~= num then
					Mask ..= " " .. MaskText(DisplayArg, "FF0000", true);
					AddWarning("Warning" .. argnum, MaskText("Invalid Argument", "ff7700") .. "; " .. argnum .. "; Invalid number received.");
				else
					Mask ..= " " .. MaskText(DisplayArg, "34EB9B", false);
				end
			else
				Mask ..= " " .. MaskText(DisplayArg, "FF0000", true);
				AddWarning("Warning" .. argnum, MaskText("Argument Mismatch", "ff7700") .. "; " .. argnum .. "; Expected a number.");
			end

		elseif Type == "boolean" then
			if arg == "true" then
				Mask ..= " " .. MaskText(DisplayArg, "76B041", false);
			elseif arg == "false" then
				Mask ..= " " .. MaskText(DisplayArg, "D7263D", false);
			else
				Mask ..= " " .. MaskText(DisplayArg, "FF0000", true);
				AddWarning("Warning" .. argnum, MaskText("Argument Mismatch", "ff7700") .. "; " .. argnum .. "; Expected a boolean. (true/false)");
			end

		elseif Type == "rawinput" then
			Mask ..= " " .. DisplayArg;
			AddWarning("Warning" .. argnum, MaskText("Raw Input", "ffff77") .. "; " .. argnum .. "; This argument does not support highlighting.");

		elseif Type == "playeridentifier" or Type == "playeridentity" then
			local plrFound = Qualifiers.FindPlayers(arg)
			if plrFound and plrFound[1] then
				AddWarning("Warning" .. argnum, MaskText("Warning", "ffaa00") .. "; " .. argnum .. "; You are targeting " .. MaskText(plrFound[1].DisplayName,"FFFFFF",true) .. ".");
			end;
			
			if tonumber(arg) then
				Mask ..= " " .. MaskText(DisplayArg, "34EB9B", false);
			else
				Mask ..= " " .. MaskText(DisplayArg, "5E7CE2", false);
			end;

		elseif Type == "player" or Type == "safeplayer" or Type == "players" or Type == "safeplayers" then
			local foundPlayers = Qualifiers.FindPlayers(arg);
			if foundPlayers and foundPlayers[1] then
				Mask ..= " " .. MaskText(DisplayArg, "4ECDC4", false);

				local strictPlayers = Qualifiers.FindPlayers(arg, true);
				if strictPlayers and strictPlayers[1] then
					local Name = strictPlayers[1].Name;
					AutoComplete = string.sub(Name, string.len(arg) + 1);
					Mask ..= MaskText(AutoComplete, "CCCCCC", false);
				end

				if Type == "player" or Type == "safeplayer" then
					if #foundPlayers > 1 then
						AddWarning("Warning" .. argnum, MaskText("Notice", "ffaa00") .. "; " .. argnum .. "; More than one player was found.");
					end
				end

				if Type == "safeplayer" then
					local target = foundPlayers[1];
					if target and StoredLevels[target.UserId] and Levels.GetLocal() <= StoredLevels[target.UserId] then
						AddWarning("Warning" .. argnum, MaskText("Notice", "ffaa00") .. "; " .. argnum .. "; You cannot target a player.");
					end
				elseif Type == "safeplayers" then
					local bad = false;
					for _, p in foundPlayers do
						if StoredLevels[p.UserId] and Levels.GetLocal() <= StoredLevels[p.UserId] then
							bad = true;
							break;
						end
					end
					if bad then
						AddWarning("Warning" .. argnum, MaskText("Notice", "ffaa00") .. "; " .. argnum .. "; At least one of the players cannot be targeted.");
					end
				end
			else
				Mask ..= " " .. MaskText(DisplayArg, "FF0000", true);
				AddWarning("Warning" .. argnum, MaskText("Player Missing", "ff7700") .. "; " .. argnum .. "; Couldn't find a player with the name '" .. arg .. "'.");
			end

		elseif Type == "color" then
			local color = env.Colors(string.lower(arg));
			if color then
				Mask ..= " " .. MaskText(DisplayArg, color, false);
			else
				Mask ..= " " .. MaskText(DisplayArg, "FF0000", true);
				AddWarning("Warning" .. argnum, MaskText("Invalid Color", "ff7700") .. "; " .. argnum .. "; Failed to create color. Is it valid?");
			end

		elseif Type == "time" then
			local ok, ret = Util.ParseTime(arg);
			if ok then
				Mask ..= " " .. MaskText(DisplayArg, "34EB9B", false);
			else
				Mask ..= " " .. MaskText(DisplayArg, "FF0000", true);
				AddWarning("Warning" .. argnum, MaskText("Invalid Time", "ff7700") .. "; " .. argnum .. "; " .. tostring(ret));
			end

		else
			-- dependant / other / TODO types fall back to neutral
			Mask ..= " " .. MaskText(DisplayArg, "AAAAAA", false);
		end

		return Mask, AutoComplete;
	end

	function OpenConsole()
		StoredLevels[LocalPlayer.UserId] = StoredLevels[LocalPlayer.UserId] or RemoteFunction:InvokeServer("GetLevel", LocalPlayer.UserId);

		env.PlaySound("rbxassetid://93927627634818", 1, true, true);
		Commandbar:TweenPosition(UDim2.new(0.5, 0, 0, 10), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.1, true, function()
			Commandbar.Input.Text = "";
			Commandbar.Warnings.Visible = true;
		end);

		Commandbar.Input:CaptureFocus();
	end

	-- Open console from UI
	Sidemenu.Content.ConsoleOpener.Open.MouseButton1Click:Connect(function()
		OpenConsole();
	end);

	-- Keybind open
	UserInputService.InputBegan:Connect(function(input)
		if UserInputService:GetFocusedTextBox() then return end;
		if TextChatService.ChatInputBarConfiguration.IsFocused then return end;

		if input.KeyCode == (Settings.ConsoleKeybind and Enum.KeyCode[Settings.ConsoleKeybind] or Enum.KeyCode.Equals) then
			OpenConsole();
		end
	end);

	-- FocusLost: send command + close
	Commandbar.Input.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			local Command = Commandbar.Input.Text;
			RemoteEvent:FireServer("CommandSent", Command);

			table.insert(LastCommands, 1, Command);
			if #LastCommands > 10 then
				table.remove(LastCommands, #LastCommands);
			end

			for _, v in Sidemenu.Content.QuickCommands:GetChildren() do
				if v:IsA("TextButton") and v.Visible then
					v:Destroy();
				end;
			end

			for i, v in LastCommands do
				local newCommand = Sidemenu.Content.QuickCommands.CommandTemplate:Clone();
				newCommand.Text = v;
				newCommand.Visible = true;
				newCommand.Parent = Sidemenu.Content.QuickCommands;
				newCommand.LayoutOrder = i;

				newCommand.MouseButton1Click:Connect(function()
					RemoteEvent:FireServer("CommandSent", v);
				end);
			end
		end;

		Commandbar:TweenPosition(UDim2.new(0.5, 0, 0, -35), Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.1, true);
		Commandbar.Input.Text = "";
		Commandbar.Warnings.Visible = false;
		env.PlaySound("rbxassetid://93927627634818", 0.75, true, true);
	end);

	-- Highlighting + warnings
	Commandbar.Input:GetPropertyChangedSignal("Text"):Connect(function()
		local Text = Commandbar.Input.Text;

		if Text ~= "" then
			env.PlaySound("rbxassetid://103866342467024", 1, false, false);
		end;

		for EscapeForm, EscapeFormValue in EscapeForms do
			if Text:find(EscapeForm) then
				Text = string.gsub(Text, EscapeForm, EscapeFormValue);
			end;
		end;

		local TabPressed = false;
		if Text:sub(-1) == "\t" then
			TabPressed = true;
			Text = string.gsub(Text, "\t", "");
			if Commandbar.Input.Text ~= Text then
				Commandbar.Input.Text = Text;
			end
		end;

		if CurrentAutoComplete and TabPressed then
			Commandbar.Input.Text ..= CurrentAutoComplete;
			Commandbar.Input.CursorPosition = #Commandbar.Input.Text + 1;
			CurrentAutoComplete = nil;
			return;
		end;

		ClearWarnings();

		if Text == "" then
			TextMask.Text = MaskText("Enter a command (without prefix) here, or press Escape to cancel.", "AAAAAA", false);
			return;
		end

		local MaskedText = "";
		local Args, inquote, Quoted = Util.ArgSplit(Text);

		local Command = string.lower(Args[1] or "");
		local CommandDef = Commands[Command];

		local cmdMask, ValidCommand, Compatibility = MaskCommandName(Command, CommandDef);
		MaskedText = cmdMask;

		table.remove(Args, 1);
		table.remove(Quoted, 1);

		if ValidCommand then
			local CommandArgs = CommandDef.Arguments;
			local LastArgumentWarned = false;

			-- permission warning
			if Levels.GetLocal() < CommandDef.Level then
				AddWarning("Permission", MaskText("You do not have permission to run this command.", "ff4444", false), -1);
			end

			-- description if no args yet
			if #Args == 0 then
				if Compatibility then
					AddWarning("Description", "<font color='#cfcfcf'>Compatibility Mode; </font><b>" .. CommandDef.Description:sub(9) .. "</b>");
				else
					AddWarning("Description", "<b>" .. CommandDef.Description .. "</b>");
				end
			end

			-- keys
			if CommandDef.Keys and type(CommandDef.Keys) == "table" then
				Args, Quoted, MaskedText = ProcessKeys(Args, Quoted, Command, MaskedText);
			end

			-- rawinput shortcut
			if CommandArgs and type(CommandArgs) == "string" then
				if CommandArgs:lower() == "rawinput" then
					MaskedText ..= " " .. MaskText(table.concat(Args, " "), "FFFFFF", false);
					AddWarning("Warning_RawInput", MaskText("Raw Input", "ffff55", false) .. "; This command does not support highlighting.");
					TextMask.Text = MaskedText;
					return;
				end
			end


			-- highlight args
			for argnum, arg in ipairs(Args) do
				if CommandArgs and CommandArgs[argnum] then
					local wasQuoted = (Quoted[argnum] == true);
					local isUnclosed = (inquote == true) and (argnum == #Args) and wasQuoted;

					local chunk, ac = HighlightArg(Command, CommandArgs[argnum], argnum, arg, isUnclosed, wasQuoted);
					MaskedText ..= chunk;
					CurrentAutoComplete = ac or CurrentAutoComplete;
				else
					if CommandArgs and CommandArgs[#CommandArgs] and (string.lower(CommandArgs[#CommandArgs].Type) == "string" or string.lower(CommandArgs[#CommandArgs].Type) == "rawinput") then
						MaskedText ..= " <font color='#FFFFFF'>" .. arg .. "</font>";
					else
						MaskedText ..= " <font color='#AAAAAA'>" .. arg .. "</font>";
						if not LastArgumentWarned then
							AddWarning("Warning" .. argnum, MaskText("Unnecessary Argument", "ff7700", false) .. "; " .. argnum .. "; This argument will be ignored.");
							LastArgumentWarned = true;
						end;
					end
				end
			end

			-- missing args warnings
			if CommandArgs then
				for i, v in CommandArgs do
					if not Args[i] and not v.Required then
						AddWarning("Warning" .. i, MaskText("Optional Argument", "ffaa00", false) .. "; " .. i .. "; " .. env.NameFormat(v.Name) .. " of type '" .. v.Type .. "'.");
					elseif v.Required and not Args[i] then
						AddWarning("Warning" .. i, MaskText("Argument Missing", "ff3300", false) .. "; " .. i .. "; Required " .. env.NameFormat(v.Name) .. " of type '" .. v.Type .. "'.");
					end
				end
			end
		else
			for _, Arg in Args do
				MaskedText ..= " " .. MaskText(Arg, "AAAAAA", false);
			end

			AddWarning("Warning", MaskText("Invalid Command", "ff3300", false) .. "; No command with the name '" .. Command .. "'.");
		end

		TextMask.Text = MaskedText;
	end);
end

--// Sidebar / taskbar
do
	if Taskbar and Taskbar:FindFirstChild("Logo") then
		Taskbar.Logo.MouseButton1Click:Connect(function()
			Sidemenu:TweenPosition(UDim2.fromScale(0, 0), "Out", "Quad", 0.2, true);
			Sidemenu.Visible = true;
		end);
	end

	if Sidemenu and Sidemenu:FindFirstChild("Close") then
		Sidemenu.Close.MouseButton1Click:Connect(function()
			Sidemenu:TweenPosition(UDim2.fromScale(-0.2, 0), "Out", "Quad", 0.2, true, function()
				Sidemenu.Visible = false;
			end);
		end);
	end

	Sidemenu.QuickSettings.NotificationSounds.MouseButton1Click:Connect(function()
		Settings.NotificationSounds = not Settings.NotificationSounds;
		Sidemenu.QuickSettings.NotificationSounds.ImageButton.Image = Settings.NotificationSounds
			and "http://www.roblox.com/asset/?id=6034308946"
			or "http://www.roblox.com/asset/?id=6034308947";
	end);

	if Settings.NoTaskbar then
		Taskbar.Visible = false;
		Taskbar.LocalScript.Enabled = false;
		GUI.TaskbarHitbox:Destroy();
	end
end

--// Build QuickAction tabs UI
do
	if not Settings.NoTaskbar then
		for Key, TabData in QuickActions.GetTabs() do
			local locked = TabData.Tab.Locked or false;
			local Tab = Assets:FindFirstChild("QuickActionsTab"):Clone();

			QuickActions.SetCursor(Tab);

			Tab.LayoutOrder = TabData.Tab.Locked and 2 or 0;
			Tab.Name = Key;
			Tab.Title.Text = TabData.Tab.Title;
			Tab.Description.Text = TabData.Tab.Description;
			Tab.BackgroundColor3 = TabData.Tab.Color or Color3.fromRGB(0, 0, 0);

			Tab:SetAttribute("Locked", TabData.Tab.Locked);

			if TabData.Tab.Locked then
				Tab.Title.Lock.Visible = true;
				Tab.Title.Lock.MouseButton1Click:Connect(function()
					locked = not locked;
					Tab.Title.Lock.Image = locked and "http://www.roblox.com/asset/?id=6031082533" or "http://www.roblox.com/asset/?id=6026568220";
				end);
			end;

			-- actions
			TabData.Buttons.Structuring(QuickActions._API);

			-- updates
			for _, update in TabData.Buttons.Updates do
				update[1]:Connect(function(...)
					QuickActions.SetCursor(Tab);
					update[2](QuickActions._API, ...);
				end);
			end;

			Tab.Parent = Sidemenu.Content;
			Tab.Visible = true;
		end;
	end;
end

--// Gag list refresh
do
	local function refreshGagList()
		local success, list = pcall(function()
			return Remotes.RemoteFunction:InvokeServer("GetGaggedUsers");
		end);

		if not success or typeof(list) ~= "table" then return end;

		env.GaggedUsers = {};
		for _, userId in pairs(list) do
			if typeof(userId) == "number" then
				env.GaggedUsers[userId] = true;
			end
		end
	end

	refreshGagList();
end

--// RemoteEvent dispatch
do
	Remotes.RemoteEvent.OnClientEvent:Connect(function(...)
		local Arguments = { ... };
		local EventName = Arguments[1];
		table.remove(Arguments, 1);

		if EventName == "Notify" then
			env.CreateNotification(tostring(Arguments[1]), Arguments[2]);
		elseif EventName == "UpdateNotification" then
			env.UpdateNotification(Arguments[1], Arguments[2]);
		elseif EventName == "ClearNotification" then
			env.ClearNotification(Arguments[1]);
		elseif EventName == "CreateList" then
			env.CreateList(Arguments[1], Arguments[2], Arguments[3]);
		elseif EventName == "GetPM" then
			env.ReceivePrivateConversation(Arguments[1], Arguments[2]);
		elseif EventName == "Hint" then
			env.CreateHint(Arguments[1], Arguments[2], Arguments[3]);
		elseif EventName == "GagState" then
			local payload = Arguments[1];
			local gagged = Arguments[2];

			if typeof(payload) == "table" then
				env.GaggedUsers = {};
				for _, userId in pairs(payload) do
					if typeof(userId) == "number" then
						env.GaggedUsers[userId] = true;
					end
				end
			elseif typeof(payload) == "number" then
				if gagged then
					env.GaggedUsers[payload] = true;
					if payload == Remotes.LocalPlayer.UserId then
						env.CreateNotification("You have been gagged and cannot chat.", {
							Type = "Warning";
							Timeout = 10;
						});
					end
				else
					env.GaggedUsers[payload] = nil;
					if payload == Remotes.LocalPlayer.UserId then
						env.CreateNotification("You have been ungagged and can chat again.", {
							Timeout = 10;
						});
					end
				end
			end
		elseif env.ClientEvents[EventName] then
			env.ClientEvents[EventName](unpack(Arguments));
		end
	end);
end

--// RemoteFunction dispatch
do
	Remotes.RemoteFunction.OnClientInvoke = function(...)
		local Arguments = { ... };
		local FunctionName = Arguments[1];
		table.remove(Arguments, 1);

		if FunctionName == "NotificationExists" then
			return (not (not env.Cardboard:FindAsset(Arguments[1])));
		elseif FunctionName == "Notify" then
			local _, UID = env.CreateNotification(tostring(Arguments[1]), Arguments[2]);
			return UID;
		elseif FunctionName == "Prompt" then
			local _, UID = env.CreatePrompt(Arguments[1]);
			return UID;
		elseif FunctionName == "RunClientCommand" then
			if not env.Commands[Arguments[1]:lower()] then
				return false, "Command is not registered on the Client-Side. (Are you using a dedicated Command module?)";
			end;

			local s, f = pcall(function()
				env.Commands[Arguments[1]:lower()](env, Arguments[2], Arguments[3]);
			end);

			if not s then
				warn("An error occurred with the command: " .. f);
			end;

			return s, f;
		elseif env.ClientFunctions[FunctionName] then
			return env.ClientFunctions[FunctionName](unpack(Arguments));
		end

		return warn("Unknown client function call attempt: " .. FunctionName);
	end;
end

--// Stored levels population + refresh
do
	local StoredLevels = Levels.GetStore();

	Players.PlayerAdded:Connect(function(player)
		StoredLevels[player.UserId] = Remotes.RemoteFunction:InvokeServer("GetLevel", player.UserId);
	end);

	for _, player in Players:GetPlayers() do
		StoredLevels[player.UserId] = Remotes.RemoteFunction:InvokeServer("GetLevel", player.UserId);
	end;

	task.spawn(function()
		while task.wait(60) do
			for _, player in Players:GetPlayers() do
				StoredLevels[player.UserId] = Remotes.RemoteFunction:InvokeServer("GetLevel", player.UserId);
			end;
		end
	end);
end

--// Soft Requires
do
	local function TryLoad(Module)
		if Module:IsA("ModuleScript") then
			local s, f = pcall(function()
				local mod = require(Module);
				if type(mod) == "table" and mod._NxWrapper then
					env[Module.Name] = mod._NxWrapper(env);
				else
					env[Module.Name] = mod;
				end
			end);

			if not s then
				warn("Redefine:A | SoftRequire failed for " .. Module.Name .. ": " .. f);
			end
		end
	end

	script.SoftRequire.ChildAdded:Connect(TryLoad);
	for _, sr in script.SoftRequire:GetChildren() do
		TryLoad(sr);
	end
end
