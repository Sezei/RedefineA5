game:GetService("TestService"):Message("Redefine:A5 | BuildId " .. script.Parent:GetAttribute("nxversion"));
local Settings = {
	NoTaskbar = script.Parent:GetAttribute("notaskbar");
	ConsoleKeybind = script.Parent:GetAttribute("consolekeybind");

	NotificationSounds = true;
}; 

-- Services
local ContentProvider = game:GetService("ContentProvider")
local TweenService:TweenService = game:GetService("TweenService");
local UserInputService:UserInputService = game:GetService("UserInputService");
local TextChatService = game:GetService("TextChatService");

-- Inner stuff
local GUI:ScreenGui = script.Parent;
local DefaultAssets:Folder = GUI:WaitForChild("DefaultAssets") :: Folder;
local Assets:Folder = GUI:FindFirstChild("Assets") :: Folder;
local Taskbar:Frame = GUI:FindFirstChild("Taskbar") :: Frame;
local Sidemenu:Frame = GUI:FindFirstChild("Sidemenu") :: Frame;

-- Requires
local env = require(script:WaitForChild("ClientEnvironment",1));
env.Dragify = require(script:FindFirstChild("Dragify")); -- Allows creating draggable UI elements; usage: Dragify(DraggableFrame, PartToDragFrom);
env.Cardboard = require(script:FindFirstChild("CardBoard")); -- Allows creating UI elements from the Assets folder; usage: Cardboard(AssetType, Parent, Properties);
env.Colors = require(script:WaitForChild("ColorLib",1)); -- Allows converting color string into a Color3 instance; Usage: Colors("White") or Colors("255,255,255");
env.Settings = Settings;
env.GaggedUsers = {};

-- Find the remotes.
local InternalEvent:BindableEvent = GUI:FindFirstChild("InternalCommunication") :: BindableEvent;
local RemoteEvent = game:GetService("ReplicatedStorage"):WaitForChild("NxRemoteEvent") :: RemoteEvent;
local RemoteFunction = game:GetService("ReplicatedStorage"):WaitForChild("NxRemoteFunction") :: RemoteFunction;
local LocalPlayer:Player = game:GetService("Players").LocalPlayer;
local Players = game:GetService("Players");

env.InternalEvent = InternalEvent;
env.RemoteEvent = RemoteEvent;
env.RemoteFunction = RemoteFunction;
env.Player = LocalPlayer;

-- Wait for LocalPlayer to exist
if not LocalPlayer then
	game.Players:GetPropertyChangedSignal('LocalPlayer'):Wait()
	LocalPlayer = game.Players.LocalPlayer; -- Once we do this, Player? is supposed to be Player (since there's no way it would be nil)
end

env.GUI = GUI;
env.Assets = Assets;

for _,v in DefaultAssets:GetChildren() do
	if not Assets:FindFirstChild(v.Name) then
		v:Clone().Parent = Assets;
		v:Destroy();
	end;
end;

if Assets:FindFirstChild("_Theme") then
	local Theme = require(Assets._Theme);
	if type(Theme) == 'table' then -- for the prototype (v.1) testers @ build 120 (those who use this as a custom function)
		for Func, Replacement in Theme do			
			env[Func] = Replacement;
		end
	elseif type(Theme) == 'function' then
		Theme(env);
	end
end;

-- Types (LuaU)
type QuickActionAPI = {

}

-- For some reason these values keep resetting, so we have to set them again.
GUI.IgnoreGuiInset = true;
GUI.ResetOnSpawn = false;

local Listenings = {};
InternalEvent.Event:Connect(function(Action, UID, Option)
	if Action == "NotificationOptionSelected" then
		if Listenings[UID] and type(Listenings[UID]) == "function" then
			Listenings[UID](Option);
		end
		RemoteEvent:FireServer("NotificationOptionSelected", UID, Option);
	end
end);

local LastCommands = {}; -- Keep track of 5 commands the user has executed, so they can be accessed with the sidemenu to be ran quickly again.
env.Commands = {};

local QuickActionAPI = nil;
local QuickActionCursor = nil;
local QuickActionTabs = {};
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
			RemoteEvent:FireServer("CommandSent", Command);
		end;
		RunEnvCommand = function(self, Command)
			return env[Command];
		end;
	};
end;

-- Get the commands and several settings from the server
local Commands = RemoteFunction:InvokeServer("GetCommands");
local CommandModules = game:GetService("ReplicatedStorage"):FindFirstChild("RA5_Commands");
local Method = string.lower(RemoteFunction:InvokeServer("GetMethod"));

local LocalLevel = RemoteFunction:InvokeServer("GetLevel", LocalPlayer.UserId);
local StoredLevels = {};
StoredLevels[LocalPlayer.UserId] = LocalLevel;

task.spawn(function()
	local cmdstoremove = {};
	for _,v in Commands do
		if v.Level >= LocalLevel then
			cmdstoremove[v.Name] = true;
		end
	end

	pcall(function()
		for _,v:TextChatCommand in game:GetService("TextChatService"):FindFirstChild("TextChatCommands"):GetChildren() do
			if table.find(cmdstoremove, '/'..v.PrimaryAlias) then
				v:Destroy();
			end
		end
	end)
end)

function RegisterModule(Module)
	if not Module:IsA("ModuleScript") then return end;
	pcall(function()
		local Data = require(Module);
		if LocalLevel >= Data.Level then
			if Data.QuickActions then
				table.insert(QuickActionTabs, Data.QuickActions);
			end
			if Data.OnClientLoad then
				Data.OnClientLoad(env, LocalLevel>=Data.Level);
			end
			if Data.OnClientRun then
				env.Commands[Data.Name:lower()] = Data.OnClientRun; -- Store the command for future use.
			end
		end
	end);
end

if not Settings.NoTaskbar then
	if Commands['kick'].Level > LocalLevel then
		QuickActionTabs.InstantKick = nil;
	end

	CommandModules.ChildAdded:Connect(function(Module)
		RegisterModule(Module);
	end)
	for _,Module in (CommandModules:GetChildren()) do
		RegisterModule(Module);
	end
end;

--[[
CreateNotification("Success!", {
	Timeout = 20;
	Image = "rbxassetid://8589545938";
	Options = {
		["help"] = "Okay!";
		["ok"] = "Discard";
	}
});
]]

local function ArgSplit(str)
	local args = {};
	local inquote = false;
	local current = "";
	for i = 1,#str do
		local char = str:sub(i,i);
		if char == '"' then
			inquote = not inquote;
		elseif char == " " and not inquote then
			table.insert(args,current);
			current = "";
		else
			current = current..char;
		end
	end
	table.insert(args,current);
	return args, inquote;
end

if Method == "sm" then 
	Method = "sourcemod";
elseif Method == "mc" then 
	Method = "minecraft";
elseif Method == "s" then
	Method = "simple";
end

local sortedqualifiers = {};

-- Check if the qualifier method is valid.
if not (Method == "sourcemod" or Method == "minecraft" or Method == "simple") then
	warn("Invalid qualifier method selected. Defaulting to 'sourcemod'.");
	Method = "sourcemod";
end;

-- Loop through all the qualifiers to check if they have the selected method.
for _, qualifier in (require(script.Qualifiers)) do
	if qualifier.methods[Method] then
		sortedqualifiers[qualifier.methods[Method]] = qualifier;
	end;
end;

local function FindPlayers(Names,Strict) -- Function that finds players by name or displayname; @strict = If the name check only applies for Player.Name.
	if string.len(Names) == 0 then return nil end -- If the name is empty, return nil.

	-- Check if there are any ',' in the name. If there are, split the name into multiple names.
	local names = string.split(Names,",")
	local matches = {} -- Table that will contain all the matches.

	-- If @strict is true, the name check will only apply for Player.Name; It will still allow short names, since we are attempting to find the player by name.
	if Strict then
		for _,Name in (names) do
			for _,v in next,Players:GetPlayers() do
				if string.lower(v.Name):sub(1,string.len(Name)) == string.lower(Name) then
					table.insert(matches,v);
				end
			end
		end
		return matches;
	end

	-- Loop through all the players.
	for _,Name in (names) do
		for _,v in next,Players:GetPlayers() do
			local matched = false; -- If a player has been matched, this will be set to true so they won't be matched again and again.

			-- Check if the executor started the Name with #; This will use the players' Local PlayerId (#1 = First Join, #2 = Second join, etc.)
			-- The players have a 'ra_LocalId' attribute that is set when they join the game.
			if Name:sub(1,1) == "#" then
				local LocalId = v:GetAttribute("ra_LocalId");
				if LocalId then
					if tonumber(Name:sub(2)) == LocalId then
						matches[#matches+1] = v
						matched = true;
					end
				end
			end

			-- Because of the '@'; prioritise checking the username first before the displayname; Alongside that, it will also not check for the displayname.
			local s1 = string.lower("@"..v.Name)
			if s1:sub(1, #Name) == string.lower(Name) then
				if not matched then
					matches[#matches+1] = v
				end
			end

			-- Check for the displayname.
			local s1 = string.lower(v.DisplayName)
			if s1:sub(1, #Name) == string.lower(Name) then
				if not matched then
					matches[#matches+1] = v
				end
			end

			-- Check for the username.
			local s1 = string.lower(v.Name)
			if s1:sub(1, #Name) == string.lower(Name) then
				if not matched then
					matches[#matches+1] = v
				end
			end

			-- Check the sortedqualifiers table for any matches; If there are any, handle them and add them to the matches table.
			for method, qualifier in (sortedqualifiers) do
				if string.lower(Name) == string.lower(method) then
					local MatchedPlayers = qualifier.identifier(false, Players:GetPlayers(), LocalPlayer);
					for _, Player in (MatchedPlayers) do
						table.insert(matches, Player);
					end;
				end;
			end;
		end
	end

	-- Remove duplicates.
	local newmatches = {}
	for _,v in (matches) do
		if not table.find(newmatches,v) then
			table.insert(newmatches,v)
		end
	end

	return newmatches -- Return the matches.
end

-- Commandbar handler
local Commandbar = GUI:FindFirstChild("CommandBar");

function OpenConsole()
	if not StoredLevels[LocalPlayer.UserId] then -- Chances are, the level won't change, so lets just check it once and avoid lag entirely. :3
		LocalLevel = RemoteFunction:InvokeServer("GetLevel", LocalPlayer.UserId); -- Update the local level stored in the client
		StoredLevels[LocalPlayer.UserId] = LocalLevel; -- Update the stored level in the client
	end;
	Commandbar:TweenPosition(UDim2.new(0.5, 0, 0, 10), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.1, true,function()
		Commandbar:FindFirstChild("Input").Text = "";
		Commandbar.Warnings.Visible = true;
	end);
	Commandbar:FindFirstChild("Input"):CaptureFocus();
end

Sidemenu.Content.ConsoleOpener.Open.MouseButton1Click:Connect(function()
	OpenConsole();
end);

UserInputService.InputBegan:Connect(function(input)
	-- Ignore the input if there's already an active input field
	if UserInputService:GetFocusedTextBox() then return end;
	-- Ignore the input if there's the player's typing in LagChatService
	if game:GetService("TextChatService").ChatInputBarConfiguration.IsFocused then return end;

	if input.KeyCode == (Settings.ConsoleKeybind and Enum.KeyCode[Settings.ConsoleKeybind] or Enum.KeyCode.Equals) then
		OpenConsole();
	end
end);

-- When the commandbar is unfocused, hide it
Commandbar:FindFirstChild("Input").FocusLost:Connect(function(enterPressed)
	if enterPressed then
		-- Send the command to the server
		local Command = Commandbar:FindFirstChild("Input").Text;
		RemoteEvent:FireServer("CommandSent", Command);

		-- Store the command and build it into the sidemenu
		table.insert(LastCommands, 1, Command);

		if #LastCommands > 10 then -- If there are more than 10 commands, remove the last one to make space for the new one.
			table.remove(LastCommands, #LastCommands);
		end

		for _,v in (Sidemenu.Content.QuickCommands:GetChildren()) do
			if v:IsA("TextButton") and v.Visible then
				v:Destroy();
			end;
		end

		for i,v in LastCommands do
			local newCommand = Sidemenu.Content.QuickCommands.CommandTemplate:Clone();
			newCommand.Text = v;
			newCommand.Visible = true;
			newCommand.Parent = Sidemenu.Content.QuickCommands;
			newCommand.MouseButton1Click:Connect(function()
				RemoteEvent:FireServer("CommandSent", v);
			end);
			newCommand.LayoutOrder = i;
		end
	end;
	Commandbar:TweenPosition(UDim2.new(0.5, 0, 0, -35), Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.1, true);
	Commandbar:FindFirstChild("Input").Text = "";
	Commandbar.Warnings.Visible = false;
end);

local EscapeForms = {
	["<"] = "&lt;",
	[">"] = "&gt;",
	["&"] = "&amp;",
	["'"] = "&apos;",
};

-- Commandbar TextMask (Masks the text for highlighting and stuff)
local TextMask = Commandbar:FindFirstChild("TextMask");
local CurrentAutoComplete = nil; -- The current autocomplete option for when tab is pressed; This is set to nil when the text is changed and tab wasn't pressed.
Commandbar.Input:GetPropertyChangedSignal("Text"):Connect(function()
	-- Process the text
	local Text = Commandbar.Input.Text;

	-- Check the text for any of the escape forms; If there are any, replace them with the correct escape form.
	for EscapeForm, EscapeFormValue in (EscapeForms) do
		if Text:find(EscapeForm) then
			Text = string.gsub(Text, EscapeForm, EscapeFormValue);
		end;
	end;

	-- Check if the last pressed button was the tab key (to process autocomplete); This can be checked by checking if the last character is a tab (\t)
	local TabPressed = false;
	if Text:sub(-1) == "\t" then
		TabPressed = true;
		-- Format the text to remove the tab character
		Text = string.gsub(Text, "\t", "");
		Commandbar.Input.Text = Text;
	end;

	if CurrentAutoComplete and TabPressed then
		-- Process the autocomplete
		Commandbar.Input.Text ..= CurrentAutoComplete;
		Commandbar.Input.CursorPosition = #Commandbar.Input.Text + 1;
		CurrentAutoComplete = nil;
		return;
	end;

	-- Clear all warnings
	for _,v in (Commandbar:FindFirstChild("Warnings"):GetChildren()) do
		if v.Name ~= "Template" and v:IsA("TextLabel") then
			v:Destroy();
		end
	end

	if Text == "" then
		TextMask.Text = "<font color='#AAAAAA'>Enter a command (without prefix) here, or press Escape to cancel.</font>";
		return
	end

	local MaskedText = "";

	-- Split the text into args
	local Args, inquote = ArgSplit(Text);

	-- Highlight the command (if one is found);
	local ValidCommand = false;
	local Compatibility = false;
	local Command = string.lower(Args[1]);
	if Commands[Command] and Commands[Command].Description:sub(1,7) == "(NANO);" then
		Compatibility = true;
		MaskedText = "<font color='#D5D5D5'><b>" .. Command .. "</b></font>";
		ValidCommand = true;
		--elseif Commands[Command] and Commands[Command].ModName then
		--	Compatibility = true;
		--	MaskedText = "<font color='#D5D5D5'><b>" .. Command .. "</b></font>";
		--	ValidCommand = true;
	elseif Commands[Command] then
		MaskedText = "<font color='#FFFF77'><b>" .. Command .. "</b></font>";
		ValidCommand = true;
	else
		MaskedText = "<font color='#FFCC00'>" .. Command .. "</font>";
	end

	if ValidCommand and Commands[Command].Color then
		MaskedText = "<font color='#" .. env.ToHex(Commands[Command].Color) .. "'><b>" .. Command .. "</b></font>";
	end

	-- Remove the command from the args
	table.remove(Args, 1);

	-- Highlight the args; If the command is invalid, highlight all args as grey
	if ValidCommand then
		-- Get the command's args
		local CommandArgs = Commands[Command].Arguments;
		local LastArgumentWarned = false;

		-- Check if the player even has permission to run the command
		if LocalLevel < Commands[Command].Level then
			-- If not, warn them
			local Warning = Commandbar.Warnings.Template:Clone();
			Warning.Text = "<font color='#ff4444'>You do not have permission to run this command.</font>";
			Warning.Name = "Permission";
			Warning.Visible = true;
			Warning.Parent = Commandbar.Warnings;
			Warning.LayoutOrder = -1; -- Topmost
		end

		-- Check if no arguments are filled in yet
		if #Args == 0 then
			-- If none are filled, show the user the command's arguments
			local Warning = Commandbar.Warnings.Template:Clone();
			-- Check if the description starts with '(NANO); '; If it does, remove it, and replace it with a warning.
			if Compatibility then
				Warning.Text = "<font color='#cfcfcf'>Compatibility Mode; </font><b>" .. Commands[Command].Description:sub(9) .. "</b>";
				Warning.Name = "Description";
				Warning.Visible = true;
				Warning.Parent = Commandbar.Warnings;
			else
				Warning.Text = "<b>" .. Commands[Command].Description .. "</b>";
				Warning.Name = "Description";
				Warning.Visible = true;
				Warning.Parent = Commandbar.Warnings;
			end
		end

		-- Check to see if the command has any keys within it. (Keys are arguments that change the way the command works; For example, --silent or --silent=true)
		for i,arg in (Args) do
			if arg:sub(1,2) == "--" then
				-- It's a key!
				local key = string.lower(arg:sub(3));
				local value = true;
				local valid = true;

				-- Check if the key is not empty
				if key == "" then
					MaskedText = MaskedText .. " <font color='#FF0000'><b>"..arg.."</b></font>";
					local Warning = Commandbar:FindFirstChild("Warnings"):FindFirstChild("Template"):Clone();
					Warning.Name = "Warning_Key" .. i;
					Warning.Text = "<font color='#ff7700'>Invalid Key</font>; "..i.."; Key is empty";
					Warning.Visible = true;
					Warning.Parent = Commandbar:FindFirstChild("Warnings");
					valid = false;
				end

				-- Check if it has a value
				if key:find("=") then
					local split = key:split("=");
					key = split[1];
					value = split[2];
					-- Check to see if the key is not empty
					if key == "" then
						-- The key is invalid! Mark the text as an invalid argument and add a warning
						MaskedText = MaskedText .. " <font color='#FF0000'><b>"..arg.."</b></font>";
						local Warning = Commandbar:FindFirstChild("Warnings"):FindFirstChild("Template"):Clone();
						Warning.Name = "Warning_Key" .. i;
						Warning.Text = "<font color='#ff7700'>Invalid Key</font>; "..i.."; Key is empty";
						Warning.Visible = true;
						Warning.Parent = Commandbar:FindFirstChild("Warnings");
						valid = false;
					end
				end

				-- Check if the command is expecting this key
				if valid and (not Commands[Command].Keys[key] and not (key == "delay") and not (key == "silent")) then
					-- Mark the key as still valid, but notify the user that it's not expected.
					local Warning = Commandbar:FindFirstChild("Warnings"):FindFirstChild("Template"):Clone();
					Warning.Name = "Warning_Key" .. i;
					Warning.Text = "<font color='#ffaa00'>Unknown Key</font>; "..i.."; Key is valid, but unused.";
					Warning.Visible = true;
					Warning.Parent = Commandbar:FindFirstChild("Warnings");
				end

				if valid then
					MaskedText = MaskedText .. " <font color='#FFFF99'>" .. arg .. "</font>";
				end

				table.remove(Args,i);
			end
		end

		local InSubcommand = nil;
		local SubcommandArgs = {};

		if CommandArgs and type(CommandArgs) == "table" then
			-- Ignore this block if it's a table
		elseif CommandArgs and type(CommandArgs) == "string" then
			-- Check if the string is 'RawInput'; If it is, we ignore the arguments and just use the raw input without any highlighting; It's up to the command creator to make sure the input is valid
			if CommandArgs:lower() == "rawinput" then
				MaskedText = MaskedText .. " <font color='#FFFFFF'>" .. table.concat(Args, " ") .. "</font>";
				local Warning = Commandbar:FindFirstChild("Warnings"):FindFirstChild("Template"):Clone();
				Warning.Name = "Warning_RawInput";
				Warning.Text = "<font color='#ffff55'>Raw Input</font>; This command does not support highlighting.";
				Warning.Visible = true;
				Warning.Parent = Commandbar:FindFirstChild("Warnings");

				TextMask.Text = MaskedText;
				return;
			end
		end

		for argnum, arg in ipairs(Args) do
			if CommandArgs[argnum] then
				-- Get the argument type
				local Type = CommandArgs[argnum].Type:lower();

				-- Check if the player left the string open
				if inquote then
					MaskedText = MaskedText .. " <font color='#FF7700'><b>\"</b></font>";
					local Warning = Commandbar:FindFirstChild("Warnings"):FindFirstChild("Template"):Clone();
					Warning.Name = "Warning" .. argnum;
					Warning.Text = "<font color='#ffaa00'>Unclosed Argument</font>; " .. argnum .. "; Make sure to close the quotes!";
					Warning.Visible = true;
					Warning.Parent = Commandbar:FindFirstChild("Warnings");
				end
				if Type == "string" then
					-- Check if the string has an 'Options' table; This is used to check if the string is valid for this specific operation.
					if CommandArgs[argnum].Options and type(CommandArgs[argnum].Options) == "table" then
						-- Check if the string is in the options table
						local found = false;
						for _, v in (CommandArgs[argnum].Options) do
							if v:sub(1, #arg):lower() == arg:lower() then
								found = v;
								break;
							end
						end
						if not found then
							-- Add a warning
							MaskedText = MaskedText .. " <font color='#FFFFBC'>" .. arg .. "</font>";
							local Warning = Commandbar:FindFirstChild("Warnings"):FindFirstChild("Template"):Clone();
							Warning.Name = "Warning" .. argnum;
							Warning.Text = "<font color='#ffaa00'>Notice</font>; " .. argnum .. "; This argument is not matching any of the options in the table.";
							Warning.Visible = true;
							Warning.Parent = Commandbar:FindFirstChild("Warnings");
						else
							-- Auto-complete the argument if it's not already completed
							--CurrentAutoComplete = string.sub(Name, string.len(arg) + 1);
							--MaskedText = MaskedText .. "<font color='#CCCCCC'>" .. CurrentAutoComplete .. "</font>";
							MaskedText = MaskedText .. " <font color='#FFFFFF'>" .. arg .. "</font>";
							CurrentAutoComplete = string.sub(found, string.len(arg) + 1);
							MaskedText = MaskedText .. "<font color='#CCCCCC'>" .. CurrentAutoComplete .. "</font>";
						end
					elseif CommandArgs[argnum].Options and type(CommandArgs[argnum].Options) == "function" then
						local Success, Option = pcall(function() CommandArgs[argnum].Options(arg:lower()) end);
						if Success and Option then
							MaskedText = MaskedText .. " <font color='#FFFFFF'>" .. arg .. "</font>";
							CurrentAutoComplete = string.sub(Option, string.len(arg) + 1);
							MaskedText = MaskedText .. "<font color='#CCCCCC'>" .. CurrentAutoComplete .. "</font>";
						elseif Success then
							MaskedText = MaskedText .. " <font color='#FFFFBC'>" .. arg .. "</font>";
							local Warning = Commandbar:FindFirstChild("Warnings"):FindFirstChild("Template"):Clone();
							Warning.Name = "Warning" .. argnum;
							Warning.Text = "<font color='#ffaa00'>Notice</font>; " .. argnum .. "; This argument does not match the function's return value.";
							Warning.Visible = true;
							Warning.Parent = Commandbar:FindFirstChild("Warnings");
						else
							MaskedText = MaskedText .. " <font color='#FF0000'><b>" .. arg .. "</b></font>";
							local Warning = Commandbar:FindFirstChild("Warnings"):FindFirstChild("Template"):Clone();
							Warning.Name = "Warning" .. argnum;
							Warning.Text = "<font color='#ff0000'>Malformed Type</font>; " .. argnum .. "; The argument's Options function returned an error.";
							Warning.Visible = true;
							Warning.Parent = Commandbar:FindFirstChild("Warnings");
						end
					elseif CommandArgs[argnum].Required and arg:gsub("%s+", "")=='' then
						-- Required value, can't use the default one!
						local Warning = Commandbar:FindFirstChild("Warnings"):FindFirstChild("Template"):Clone();
						Warning.Name = "Warning" .. argnum;
						Warning.Text = "<font color='#ff3300'>String Empty</font>; " .. argnum .. "; This argument requires an input and cannot be empty.";
						Warning.Visible = true;
						Warning.Parent = Commandbar:FindFirstChild("Warnings");
					else
						MaskedText = MaskedText .. " <font color='#FFFFFF'>" .. arg .. "</font>";
					end
				elseif Type == "dependant" then
					--TODO: Use custom for now
				elseif Type == "custom" then
					if CommandArgs[argnum].Validator then
						local valid, err = pcall(CommandArgs[argnum].Validator, arg);
						if valid then
							if CommandArgs[argnum].Highlighting then
								local success, ret = pcall(CommandArgs[argnum].Highlighting, arg);
								if success then
									MaskedText = MaskedText .. " " .. ret;
								else
									if not err[1] then
										MaskedText = MaskedText .. " <font color='#FF0000'><b>" .. arg .. "</b></font>";
									else
										MaskedText = MaskedText .. " <font color='#FFFFFF'>" .. err[1].."</font>";
									end;
								end;
							else
								if not err[1] then
									MaskedText = MaskedText .. " <font color='#FF0000'><b>" .. arg .. "</b></font>";
								else
									MaskedText = MaskedText .. " <font color='#FFFFFF'>" .. err[1].."</font>";
								end;
							end;

							if not err[1] then
								local Warning = Commandbar:FindFirstChild("Warnings"):FindFirstChild("Template"):Clone();
								Warning.Name = "Warning" .. argnum;
								Warning.Text = "<font color='#ffaa00'>Custom Error</font>; " .. argnum .. "; " .. err[2];
								Warning.Visible = true;
								Warning.Parent = Commandbar:FindFirstChild("Warnings");
							end;
						else
							MaskedText = MaskedText .. " <font color='#FF0000'><b>" .. arg .. "</b></font>";
							local Warning = Commandbar:FindFirstChild("Warnings"):FindFirstChild("Template"):Clone();
							Warning.Name = "Warning" .. argnum;
							Warning.Text = "<font color='#ff0000'>Malformed Type</font>; " .. argnum .. "; Custom type returns error; " .. err;
							Warning.Visible = true;
							Warning.Parent = Commandbar:FindFirstChild("Warnings");
						end;
					else
						local Warning = Commandbar:FindFirstChild("Warnings"):FindFirstChild("Template"):Clone();
						Warning.Name = "Warning" .. argnum;
						Warning.Text = "<font color='#ff0000'>Malformed Type</font>; " .. argnum .. "; Custom type missing a validator.";
					end;
				elseif Type == "number" or Type == "slider" then
					local num = tonumber(arg);
					if num then
						if num > (CommandArgs[argnum].Maximum or math.huge) then
							MaskedText = MaskedText .. " <font color='#FF5500'><b>" .. arg .. "</b></font>";
							-- Add a warning
							local Warning = Commandbar:FindFirstChild("Warnings"):FindFirstChild("Template"):Clone();
							Warning.Name = "Warning" .. argnum;
							Warning.Text = "<font color='#ffaa00'>Notice</font>; " .. argnum .. "; " .. CommandArgs[argnum].Maximum .. " is the maximum value for this argument.";
							Warning.Visible = true;
							Warning.Parent = Commandbar:FindFirstChild("Warnings");
						elseif num < (CommandArgs[argnum].Minimum or -math.huge) then
							MaskedText = MaskedText .. " <font color='#FF5500'><b>" .. arg .. "</b></font>";
							-- Add a warning
							local Warning = Commandbar:FindFirstChild("Warnings"):FindFirstChild("Template"):Clone();
							Warning.Name = "Warning" .. argnum;
							Warning.Text = "<font color='#ffaa00'>Notice</font>; " .. argnum .. "; " .. CommandArgs[argnum].Minimum .. " is the minimum value for this argument.";
							Warning.Visible = true;
							Warning.Parent = Commandbar:FindFirstChild("Warnings");
						elseif num~=num then
							MaskedText = MaskedText .. " <font color='#FF0000'><b>" .. arg .. "</b></font>";
							-- Add a warning
							local Warning = Commandbar:FindFirstChild("Warnings"):FindFirstChild("Template"):Clone();
							Warning.Name = "Warning" .. argnum;
							Warning.Text = "<font color='#ff7700'>Invalid Argument</font>; " .. argnum .. "; Invalid number received.";
							Warning.Visible = true;
							Warning.Parent = Commandbar:FindFirstChild("Warnings");
						else
							MaskedText = MaskedText .. " <font color='#5E7CE2'>" .. arg .. "</font>";
						end
					else
						MaskedText = MaskedText .. " <font color='#FF0000'><b>" .. arg .. "</b></font>";
						-- Add a warning
						local Warning = Commandbar:FindFirstChild("Warnings"):FindFirstChild("Template"):Clone();
						Warning.Name = "Warning" .. argnum;
						Warning.Text = "<font color='#ff7700'>Argument Mismatch</font>; " .. argnum .. "; Expected a number.";
						Warning.Visible = true;
						Warning.Parent = Commandbar:FindFirstChild("Warnings");
					end
				elseif Type == "boolean" then
					if arg == "true" then
						MaskedText = MaskedText .. " <font color='#76B041'>" .. arg .. "</font>";
					elseif arg == "false" then
						MaskedText = MaskedText .. " <font color='#D7263D'>" .. arg .. "</font>";
					else
						MaskedText = MaskedText .. " <font color='#FF0000'><b>" .. arg .. "</b></font>";
						-- Add a warning
						local Warning = Commandbar:FindFirstChild("Warnings"):FindFirstChild("Template"):Clone();
						Warning.Name = "Warning" .. argnum;
						Warning.Text = "<font color='#ff7700'>Argument Mismatch</font>; " .. argnum .. "; Expected a boolean. (true/false)";
						Warning.Visible = true;
						Warning.Parent = Commandbar:FindFirstChild("Warnings");
					end
				elseif Type == "rawinput" then
					MaskedText = MaskedText .. arg;
					local Warning = Commandbar:FindFirstChild("Warnings"):FindFirstChild("Template"):Clone();
					Warning.Name = "Warning" .. argnum;
					Warning.Text = "<font color='#ffff77'>Raw Input</font>; " .. argnum .. "; This argument does not support highlighting.";
					Warning.Visible = true;
					Warning.Parent = Commandbar:FindFirstChild("Warnings");
				elseif Type == "player" or Type == "safeplayer" or Type == "players" or Type == "safeplayers" then
					if FindPlayers(arg) and FindPlayers(arg)[1] then
						MaskedText = MaskedText .. " <font color='#4ECDC4'>" .. arg .. "</font>";

						-- Check if the user is using Player.Name using @strict with FindPlayers
						if FindPlayers(arg,true)[1] then
							-- Add the autocomplete.
							local Name = FindPlayers(arg,true)[1].Name;
							CurrentAutoComplete = string.sub(Name, string.len(arg) + 1);
							MaskedText = MaskedText .. "<font color='#CCCCCC'>" .. CurrentAutoComplete .. "</font>";
						end

						-- If the type is player or safeplayer (NOT players or safeplayers), they only use the first player found; Warn the player if there's more than one player found
						if Type == "player" or Type == "safeplayer" then
							if #FindPlayers(arg) > 1 then
								-- Add a warning
								local Warning = Commandbar:FindFirstChild("Warnings"):FindFirstChild("Template"):Clone();
								Warning.Name = "Warning" .. argnum;
								Warning.Text = "<font color='#ffaa00'>Notice</font>; " .. argnum .. "; More than one player was found.";
								Warning.Visible = true;
								Warning.Parent = Commandbar:FindFirstChild("Warnings");
							end
						end

						if Type == 'safeplayer' then
							if LocalLevel <= StoredLevels[FindPlayers(arg)[1].UserId] then
								-- Add a warning
								local Warning = Commandbar:FindFirstChild("Warnings"):FindFirstChild("Template"):Clone();
								Warning.Name = "Warning" .. argnum;
								Warning.Text = "<font color='#ffaa00'>Notice</font>; " .. argnum .. "; You cannot target a player.";
								Warning.Visible = true;
								Warning.Parent = Commandbar:FindFirstChild("Warnings");
							end
						elseif Type == 'safeplayers' then
							local found = false;
							for i,v in (FindPlayers(arg)) do
								if LocalLevel <= StoredLevels[v.UserId] then
									found = true;
									break;
								end
							end
							if found then
								-- Add a warning
								local Warning = Commandbar:FindFirstChild("Warnings"):FindFirstChild("Template"):Clone();
								Warning.Name = "Warning" .. argnum;
								Warning.Text = "<font color='#ffaa00'>Notice</font>; " .. argnum .. "; At least one of the players cannot be targeted.";
								Warning.Visible = true;
								Warning.Parent = Commandbar:FindFirstChild("Warnings");
							end
						end;
					else
						MaskedText = MaskedText .. " <font color='#FF0000'><b>" .. arg .. "</b></font>";
						-- Add a warning
						local Warning = Commandbar:FindFirstChild("Warnings"):FindFirstChild("Template"):Clone();
						Warning.Name = "Warning" .. argnum;
						Warning.Text = "<font color='#ff7700'>Player Missing</font>; " .. argnum .. "; Couldn't find a player with the name '" .. arg .. "'.";
						Warning.Visible = true;
						Warning.Parent = Commandbar:FindFirstChild("Warnings");
					end
				elseif Type == "color" then
					local color = env.Colors(string.lower(arg));
					-- Convert the color3 to a hex color
					if color then
						local hex = string.format("#%02X%02X%02X", color.r * 255, color.g * 255, color.b * 255);
						MaskedText = MaskedText .. " <font color='" .. hex .. "'>" .. arg .. "</font>";
					else
						MaskedText = MaskedText .. " <font color='#FF0000'><b>" .. arg .. "</b></font>";
						-- Add a warning
						local Warning = Commandbar:FindFirstChild("Warnings"):FindFirstChild("Template"):Clone();
						Warning.Name = "Warning" .. argnum;
						Warning.Text = "<font color='#ff7700'>Invalid Color</font>; " .. argnum .. "; Failed to create color. Is it valid?";
						Warning.Visible = true;
						Warning.Parent = Commandbar:FindFirstChild("Warnings");
					end
				end
			else
				-- Check if the last argument type is a string in order to highlight the rest of the args as a string rather than as a non-existent argument
				if CommandArgs and CommandArgs[#CommandArgs] and (string.lower(CommandArgs[#CommandArgs].Type) == "string" or string.lower(CommandArgs[#CommandArgs].Type) == "rawinput") then
					MaskedText = MaskedText .. " <font color='#FFFFFF'>" .. arg .. "</font>";
				else
					MaskedText = MaskedText .. " <font color='#AAAAAA'>" .. arg .. "</font>";
					-- Add a warning ONCE
					if not LastArgumentWarned then
						local Warning = Commandbar:FindFirstChild("Warnings"):FindFirstChild("Template"):Clone();
						Warning.Name = "Warning" .. argnum;
						Warning.Text = "<font color='#ff7700'>Unnecessary Argument</font>; " .. argnum .. "; This argument will be ignored.";
						Warning.Visible = true;
						Warning.Parent = Commandbar:FindFirstChild("Warnings");
						LastArgumentWarned = true;
					end;
				end
			end
		end

		-- Check if any of the arguments are missing
		if CommandArgs then
			for i, v in (CommandArgs) do
				if not Args[i] and not v.Required then
					local Warning = Commandbar:FindFirstChild("Warnings"):FindFirstChild("Template"):Clone();
					Warning.Name = "Warning" .. i;
					Warning.Text = "<font color='#ffaa00'>Optional Argument</font>; " .. i .. "; "..env.NameFormat(v.Name).." of type '" .. v.Type .. "'.";
					Warning.Visible = true;
					Warning.Parent = Commandbar:FindFirstChild("Warnings");
				elseif v.Required and not Args[i] then
					-- Add a warning
					local Warning = Commandbar:FindFirstChild("Warnings"):FindFirstChild("Template"):Clone();
					Warning.Name = "Warning" .. i;
					Warning.Text = "<font color='#ff3300'>Argument Missing</font>; " .. i .. "; Required "..env.NameFormat(v.Name).." of type '" .. v.Type .. "'.";
					Warning.Visible = true;
					Warning.Parent = Commandbar:FindFirstChild("Warnings");
				end
			end
		end
	else
		for _, Arg in (Args) do
			MaskedText = MaskedText .. " <font color='#AAAAAA'>" .. Arg .. "</font>";
		end

		-- Add a warning
		local Warning = Commandbar:FindFirstChild("Warnings"):FindFirstChild("Template"):Clone();
		Warning.Name = "Warning";
		Warning.Text = "<font color='#ff3300'>Invalid Command</font>; No command with the name '" .. Command .. "'.";
		Warning.Visible = true;
		Warning.Parent = Commandbar:FindFirstChild("Warnings");
	end

	-- Set the text
	TextMask.Text = MaskedText;
end);

-- Sidebar stuff
Taskbar.Logo.MouseButton1Click:Connect(function()
	Sidemenu:TweenPosition(UDim2.fromScale(0, 0), "Out", "Quad", 0.2, true);
	Sidemenu.Visible = true;
end);

Sidemenu.Close.MouseButton1Click:Connect(function()
	Sidemenu:TweenPosition(UDim2.fromScale(-0.2, 0), "Out", "Quad", 0.2, true, function()
		Sidemenu.Visible = false;
	end);
end);

Sidemenu.QuickSettings.NotificationSounds.MouseButton1Click:Connect(function()
	Settings.NotificationSounds = not Settings.NotificationSounds;
	Sidemenu.QuickSettings.NotificationSounds.ImageButton.Image = Settings.NotificationSounds and "http://www.roblox.com/asset/?id=6034308946" or "http://www.roblox.com/asset/?id=6034308947";
end);

if Settings.NoTaskbar then
	Taskbar.Visible = false;
	Taskbar.LocalScript.Enabled = false;
	GUI.TaskbarHitbox:Destroy();
end

-- Go through all of the QuickActionTabs
if not Settings.NoTaskbar then	
	for Key,TabData in (QuickActionTabs) do

		local locked = TabData.Tab.Locked or false;
		local Tab = Assets:FindFirstChild("QuickActionsTab"):Clone();
		QuickActionCursor = Tab;
		Tab.LayoutOrder = TabData.Tab.Locked and 2 or 0;
		Tab.Name = Key;
		Tab.Title.Text = TabData.Tab.Title;
		Tab.Description.Text = TabData.Tab.Description;
		Tab.BackgroundColor3 = TabData.Tab.Color or Color3.fromRGB(0, 0, 0);

		Tab:SetAttribute("Locked",TabData.Tab.Locked);

		if TabData.Tab.Locked then
			Tab.Title.Lock.Visible = true;
			Tab.Title.Lock.MouseButton1Click:Connect(function()
				locked = not locked;
				Tab.Title.Lock.Image = locked and "http://www.roblox.com/asset/?id=6031082533" or "http://www.roblox.com/asset/?id=6026568220";
			end);
		end;

		-- Go through all of the actions
		TabData.Buttons.Structuring(QuickActionAPI);

		-- Go through all of the update stuff
		for _, update in (TabData.Buttons.Updates) do -- {Event, API Function}
			update[1]:Connect(function(...)
				QuickActionCursor = Tab;
				update[2](QuickActionAPI, ...);
			end);
		end;

		-- Add the tab
		Tab.Parent = Sidemenu.Content;
		Tab.Visible = true;
	end;
end;

do
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then

		local PrevTextChatOnIncomingMessage = TextChatService.OnIncomingMessage;
		TextChatService.OnIncomingMessage = function(message)
			local userId = message.TextSourceUserId;
			if userId and env.GaggedUsers[userId] then
				local props = Instance.new("TextChatMessageProperties");
				props.ShouldDeliver = false;
				return props;
			else
				if PrevTextChatOnIncomingMessage then -- very dangerous game here icl
					return PrevTextChatOnIncomingMessage(message)
				end
			end
		end

	end;
end

local function refreshGagList()
	local success, list = pcall(function()
		return RemoteFunction:InvokeServer("GetGaggedUsers");
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

-- Connect the remotes.
RemoteEvent.OnClientEvent:Connect(function(...)
	local Arguments = {...};
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
		env.CreateHint(Arguments[1], Arguments[2], Arguments[3])
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
				if payload == LocalPlayer.UserId then
					env.CreateNotification("You have been gagged and cannot chat.", {
						Type = "Warning";
						Timeout = 10;
					});
				end
			else
				env.GaggedUsers[payload] = nil;
				if payload == LocalPlayer.UserId then
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

RemoteFunction.OnClientInvoke = function(...)
	local Arguments = {...};
	local FunctionName = Arguments[1];
	table.remove(Arguments, 1);

	if FunctionName == "NotificationExists" then
		return (not (not env.Cardboard:FindAsset(Arguments[1])));
	elseif FunctionName == "Notify" then -- If used in a function, it usually means the server is awaiting for a response from the player due to the .Options; Return an UUID to the server.
		local _, UID = env.CreateNotification(tostring(Arguments[1]), Arguments[2]);
		return UID;
	elseif FunctionName == "Prompt" then
		local _, UID = env.CreatePrompt(Arguments[1]);
		return UID;
	elseif FunctionName == "RunClientCommand" then
		if not env.Commands[Arguments[1]:lower()] then
			return false, "Command is not registered on the Client-Side. (Are you using a dedicated Command module?)";
		end;
		--
		local s,f = pcall(function()
			env.Commands[Arguments[1]:lower()](env, Arguments[2], Arguments[3]);
		end);
		if not s then
			warn('An error occurred with the command: '..f);
		end;
		return s,f;
	elseif env.ClientFunctions[FunctionName] then
		return env.ClientFunctions[FunctionName](unpack(Arguments));
	end

	return warn("Unknown client function call attempt: "..FunctionName);
end;

Players.PlayerAdded:Connect(function(player)
	StoredLevels[player.UserId] = RemoteFunction:InvokeServer("GetLevel", player.UserId);
end);
for _, player in (Players:GetPlayers()) do
	StoredLevels[player.UserId] = RemoteFunction:InvokeServer("GetLevel", player.UserId);
end;

-- Update the stored levels every 60 seconds
task.spawn(function()
	while task.wait(60) do
		for _, player in (Players:GetPlayers()) do
			StoredLevels[player.UserId] = RemoteFunction:InvokeServer("GetLevel", player.UserId);
		end;

		LocalLevel = StoredLevels[LocalPlayer.UserId];
	end;
end)