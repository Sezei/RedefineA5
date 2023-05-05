game:GetService("TestService"):Message("Redefine:A5 | BuildId " .. script.Parent:GetAttribute("nxversion"));

-- Services
local TweenService:TweenService = game:GetService("TweenService");
local UserInputService:UserInputService = game:GetService("UserInputService");

-- Inner stuff
local GUI:ScreenGui = script.Parent;
local DefaultAssets:Folder = GUI:WaitForChild("DefaultAssets") :: Folder;
local Assets:Folder = GUI:FindFirstChild("Assets") :: Folder;

-- Requires
local env = require(script:FindFirstChild("ClientEnvironment"));
local Dragify = require(script:FindFirstChild("Dragify")); -- Allows creating draggable UI elements; usage: Dragify(DraggableFrame, PartToDragFrom);
local Cardboard = require(script:FindFirstChild("CardBoard")); -- Allows creating UI elements from the Assets folder; usage: Cardboard(AssetType, Parent, Properties);
local Colors = require(script:WaitForChild("ColorLib",1)); -- Allows converting color string into a Color3 instance; Usage: Colors("White") or Colors("255,255,255");

-- Find the remotes.
local InternalEvent:BindableEvent = GUI:FindFirstChild("InternalCommunication") :: BindableEvent;
local RemoteEvent = game:GetService("ReplicatedStorage"):WaitForChild("NxRemoteEvent") :: RemoteEvent;
local RemoteFunction = game:GetService("ReplicatedStorage"):WaitForChild("NxRemoteFunction") :: RemoteFunction;
local LocalPlayer:Player? = game:GetService("Players").LocalPlayer;
local Players = game:GetService("Players"):GetPlayers();

-- For some reason these values keep resetting, so we have to set them again.
GUI.IgnoreGuiInset = true;
GUI.ResetOnSpawn = false;

for _,v in pairs(DefaultAssets:GetChildren()) do
	if not Assets:FindFirstChild(v.Name) then
		v:Clone().Parent = Assets;
		v:Destroy();
	end;
end;

local Listenings = {};
InternalEvent.Event:Connect(function(Action, UID, Option)
	if Action == "NotificationOptionSelected" then
		if Listenings[UID] and type(Listenings[UID]) == "function" then
			Listenings[UID](Option);
		end
		RemoteEvent:FireServer("NotificationOptionSelected", UID, Option);
	end
end);

local function CreateUID()
	local UID = "";
	for i = 1, 24 do
		UID = UID .. string.char(math.random(65, 90));
	end
	return UID;
end

local function ToHex(color)
	if type(color) == "string" then
		return color; -- Assume it's already a hex color.
	elseif typeof(color) == "Color3" then
		return string.format("#%02X%02X%02X", color.r * 255, color.g * 255, color.b * 255);
	else
		return "#FFFFFF";
	end;
end;

local function ClearNotification(Notification:TextButton)
	Notification.Name = "disappearing"
	-- Remove the notification out of the screen
	local currentpos = Notification.Position;
	local targetpos = UDim2.new(currentpos.X.Scale + 2, currentpos.X.Offset, currentpos.Y.Scale, currentpos.Y.Offset);
	local tween = TweenService:Create(Notification, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = targetpos});
	tween:Play();
	-- Move any other notifications downwards
	for _,v in pairs(GUI:GetChildren()) do
		if v:IsA("TextButton") then
			if v.Position.Y.Offset < Notification.Position.Y.Offset then
				local currentpos = v.Position;
				local targetpos = UDim2.new(currentpos.X.Scale, currentpos.X.Offset, currentpos.Y.Scale, currentpos.Y.Offset + 50);
				local tween = TweenService:Create(v, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = targetpos});
				tween:Play();
			end
		end
	end
	-- Delete the notification after the tween is done
	task.wait(0.75);
	Notification:Destroy();
end;

local function NameFormat(input:string) -- This will turn any string input into a correctly-capitalised output; 'hElOOl' -> 'Heloool'
	local output = input:lower();
	output = output:sub(1,1):upper() .. output:sub(2);
	return output;
end;

-- A prompt is a hint with a selection of choices.
local function CreatePrompt(options:{[any?]:any?}?)
	-- Override protection; Await until the previous prompt is cleared.
	if GUI:FindFirstChild("ActivePrompt") then
		repeat task.wait() until not GUI:FindFirstChild("ActivePrompt");
	end;

	-- Create the prompt.
	local Prompt = Assets:FindFirstChild("Prompt"):Clone();
	Prompt.Name = "ActivePrompt";

	local Choices = Prompt:FindFirstChild("Options");
	local Content = Prompt:FindFirstChild("Content");
	local Options = options.Options or {'Button'};

	for _v in pairs(Choices:GetChildren()) do

	end

	Content.Text = options.Text or "Missing String";

	local SortedOptions = {};
	local PrimaryOption = nil;
	local checked = false;
	for internalname, optionvalues in pairs(options.Options) do
		if type(optionvalues) == "string" then
			SortedOptions[internalname] = optionvalues;
			if checked == false then
				PrimaryOption = internalname;
			end
			checked = true;
		elseif type(optionvalues) == "table" then
			SortedOptions[internalname] = internalname;
			if optionvalues.Text and (type(optionvalues.Text) == "string" or type(optionvalues.Text) == "number") then
				SortedOptions[internalname] = tostring(optionvalues.Text);
				if checked == false then
					PrimaryOption = internalname;
				end
			end
			if optionvalues.Primary and type(optionvalues.Primary) == "boolean" and optionvalues.Primary == true then
				PrimaryOption = internalname;
			end
			checked = true;
		end
	end

	-- Create the primary option
	local Button:TextButton = Choices:FindFirstChild("PROMPT_DefaultButton"):Clone() :: TextButton;
	Button.Name = PrimaryOption;
	Button.Text = SortedOptions[PrimaryOption];
	Button.Parent = Choices;
	Button.Visible = true;
	Button.Size = UDim2.new(0, Button.TextBounds.X + 20, 0, 30);
	Button.MouseButton1Click:Connect(function()
		InternalEvent:Fire("NotificationOptionSelected", options.UID, PrimaryOption);
		Prompt:Destroy();
	end);

	-- Create the other options
	for internalname, text in pairs(SortedOptions) do
		if internalname ~= PrimaryOption then
			local Button:TextButton = Choices:FindFirstChild("PROMPT_Button"):Clone() :: TextButton;
			Button.Name = internalname;
			Button.Text = text;
			Button.Parent = Choices;
			Button.Visible = true;
			Button.Size = UDim2.new(0, Button.TextBounds.X + 10, 0, 30);
			Button.MouseButton1Click:Connect(function()
				InternalEvent:Fire("NotificationOptionSelected", options.UID, internalname);
				Prompt:Destroy();
			end);
		end
	end
end;

-- An Input is UI that allows the user to input text.
local function CreateInput(options:{[any?]:any?}?)
	--TODO: INPUT UI
end;

local function CreateNotification(text:string, options:{[any?]: any?}?)
    --[[
	local UID = CreateUID();
	local Notification:TextButton = Assets:FindFirstChild("Notification"):Clone() :: TextButton;
    --]]

	local Notification, UID = Cardboard("Notification", GUI, {
		["Text"] = text;
	});

	local Label:TextLabel = Notification:FindFirstChild("Label") :: TextLabel;

	local Options:Frame = Notification:FindFirstChild("Options") :: Frame;
	local PrimaryOption = nil;
	local TimedOutOption = nil;
	local PushingDown:boolean = false;
	local Clickable:boolean = true;
	local OnePosDown:boolean = false;

	Notification.Name = UID;
	Notification.Parent = GUI;

	if options then
		-- Avoid 'permanent' notifications; They MUST get a way to be removed.
		if typeof(options.Timeout) ~= "number" and typeof(options.Clickable) == "boolean" and options.Clickable == false then
			options.Timeout = 30; -- This makes the notification last for 30 seconds.
			-- For addon devs: If you want a permanent notification, don't make the notification unclickable; It'll clutter the screen.
			-- You can use a hintbox instead for !setmessage, as it will not obscure the notifications box.
		end

		if options.Type and type(options.Type) == "string" then
			if string.lower(options.Type) == "normal" then
				Cardboard:UpdateAsset(UID, {
					["BackgroundColor"] = Color3.fromRGB(45, 45, 45);
					["TextColor"] = Color3.fromRGB(255, 255, 255);
				});
			elseif string.lower(options.Type) == "warning" or string.lower(options.Type) == "warn" then
				Cardboard:UpdateAsset(UID, {
					["BackgroundColor"] = Color3.fromRGB(45, 45, 45);
					["TextColor"] = Color3.fromRGB(255, 127, 0);
				});
			elseif string.lower(options.Type) == "error" then
				Cardboard:UpdateAsset(UID, {
					["BackgroundColor"] = Color3.fromRGB(45, 45, 45);
					["TextColor"] = Color3.fromRGB(255, 60, 60);
				});
			elseif string.lower(options.Type) == "critical" then
				Cardboard:UpdateAsset(UID, {
					["BackgroundColor"] = Color3.fromRGB(255, 60, 60);
					["TextColor"] = Color3.fromRGB(255, 255, 255);
				});
				Label.Font = Enum.Font.GothamBlack;
				PushingDown = true;
			end
		end
		if options.TextColor and typeof(options.TextColor) == "Color3" then
			Cardboard:UpdateAsset(UID, {
				["TextColor"] = options.TextColor;
			});
		end
		if options.BackgroundColor and typeof(options.BackgroundColor) == "Color3" then
			Cardboard:UpdateAsset(UID, {
				["BackgroundColor"] = options.BackgroundColor;
			});
		end
		if options.Timeout and typeof(options.Timeout) == "number" then
			local timer:Frame = Notification:FindFirstChild("Timer") :: Frame;
			timer:TweenSize(UDim2.new(0, 0, 0, 2), Enum.EasingDirection.InOut, Enum.EasingStyle.Linear, options.Timeout, true);
			timer.Visible = true;
			task.spawn(function()
				task.wait(options.Timeout + 0.1);
				if Notification.Parent then
					InternalEvent:Fire("NotificationOptionSelected", UID, TimedOutOption or "Timedout");
					ClearNotification(Notification);
				end
			end)
		end
		if options.PushLowest and type(options.PushLowest) == "boolean" then
			PushingDown = options.PushLowest;
		end
		if type(options.Clickable) == "boolean" then
			Clickable = options.Clickable;
			Notification.AutoButtonColor = options.Clickable;
		end
		if options.Image and type(options.Image) == "string" then
			Cardboard:UpdateAsset(UID, {
				["Icon"] = options.Image;
			});
			Label.Position = UDim2.new(0, 42, 0, 0);
			Notification.Image.Visible = true;
		else
			Label.Position = UDim2.new(0, 10, 0, 0);
			Notification.Image.Visible = false;
		end
		if options.Options and type(options.Options) == "table" then
			local SortedOptions = {};
			local checked = false;
			for internalname, optionvalues in pairs(options.Options) do
				if type(optionvalues) == "string" then
					SortedOptions[internalname] = optionvalues;
					if checked == false then
						PrimaryOption = internalname;
					end
					checked = true;
				elseif type(optionvalues) == "table" then
					SortedOptions[internalname] = internalname;
					if optionvalues.Text and (type(optionvalues.Text) == "string" or type(optionvalues.Text) == "number") then
						SortedOptions[internalname] = tostring(optionvalues.Text);
						if checked == false then
							PrimaryOption = internalname;
						end
					end
					if optionvalues.Primary and type(optionvalues.Primary) == "boolean" and optionvalues.Primary == true then
						PrimaryOption = internalname;
					end
					if optionvalues.TimedOut and type(optionvalues.TimedOut) == "boolean" and optionvalues.TimedOut == true then
						TimedOutOption = internalname;
					end
					checked = true;
				end
			end

			-- Create the primary option
			local Button:TextButton = Options:FindFirstChild("PROMPT_DefaultButton"):Clone() :: TextButton;
			Button.Name = PrimaryOption;
			Button.Text = SortedOptions[PrimaryOption];
			Button.Parent = Options;
			Button.Visible = true;
			Button.Size = UDim2.new(0, Button.TextBounds.X + 20, 0, 30);
			Button.MouseButton1Click:Connect(function()
				InternalEvent:Fire("NotificationOptionSelected", UID, PrimaryOption);
				ClearNotification(Notification);
			end);

			-- Create the other options
			for internalname, text in pairs(SortedOptions) do
				if internalname ~= PrimaryOption then
					local Button:TextButton = Options:FindFirstChild("PROMPT_Button"):Clone() :: TextButton;
					Button.Name = internalname;
					Button.Text = text;
					Button.Parent = Options;
					Button.Visible = true;
					Button.Size = UDim2.new(0, Button.TextBounds.X + 10, 0, 30);
					Button.MouseButton1Click:Connect(function()
						InternalEvent:Fire("NotificationOptionSelected", UID, internalname);
						ClearNotification(Notification);
					end);
				end
			end
		end
	end;

	-- Combine the size of the label and the options
	local ListLayout = Options:FindFirstChild("UIListLayout") :: UIListLayout;
	local XSize = Label.TextBounds.X + ListLayout.AbsoluteContentSize.X + 35;

	if ListLayout.AbsoluteContentSize.X < 2 then
		XSize = Label.TextBounds.X + 20;
	end

	if type(options) == "table" and options.Image and type(options.Image) == "string" then
		XSize = XSize + 32;
	end

	Notification.Size = UDim2.new(0, math.max(XSize, 250), 0, 40);

	-- Find where the notification should go if PushLowest is disabled
	if not PushingDown then
		local NotificationCount = -1;
		for _, notification in pairs(GUI:GetChildren()) do
			if notification:IsA("TextButton") and notification.Name ~= "disappearing" then
				NotificationCount = NotificationCount + 1;
			end
		end
		local NotificationPosition = UDim2.new(1, -10, 1, (-50 * NotificationCount - 10));
		Notification.Position = NotificationPosition;
	else
		local children = GUI:GetChildren();
		for _,v in pairs(children) do
			if v:IsA("TextButton") and v.Name ~= UID and v.Name ~= "disappearing" then
				local currentpos = v.Position;
				local targetpos = UDim2.new(currentpos.X.Scale, currentpos.X.Offset, currentpos.Y.Scale, currentpos.Y.Offset - 50);
				local tween = TweenService:Create(v, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = targetpos});
				tween:Play();
			end
		end
	end

	-- On notification click (not on the options)
	Notification.MouseButton1Click:Connect(function()
		if not Clickable then
			return;
		end
		InternalEvent:Fire("NotificationOptionSelected", UID, PrimaryOption or "Clicked");
		Clickable = false;
		ClearNotification(Notification);
	end);

	Notification.Visible = true;

	return Notification, UID;
end;

local function UpdateNotification(Notification:TextButton|string, Changes:any)
	if type(Notification) == 'string' then
		-- Find the notification
		Notification = GUI:FindFirstChild(Notification) :: TextButton;
	end
	if not Notification then return end;
	local Label:TextLabel = Notification:FindFirstChild("Label") :: TextLabel;
	local Options:Frame = Notification:FindFirstChild("Options") :: Frame;
	if type(Changes) == "string" then
		Label.Text = Changes;
	elseif type(Changes) == "table" then
		if Changes.Text and type(Changes.Text) == "string" then
			Label.Text = Changes.Text;
		end
		if Changes.Image and type(Changes.Image) == "string" then
			if Changes.Image ~= "remove" then
				local Image:ImageLabel = Notification:FindFirstChild("Image") :: ImageLabel;
				Image.Image = Changes.Image;
				Image.Visible = true;
				Label.Position = UDim2.new(0, 42, 0, 0);
			else
				local Image:ImageLabel = Notification:FindFirstChild("Image") :: ImageLabel;
				Image.Image = "";
				Image.Visible = false;
				Label.Position = UDim2.new(0, 10, 0, 0);
			end
		end
		if Changes.TextColor and typeof(Changes.TextColor) == "Color3" then
			Label.TextColor3 = Changes.TextColor;
		end
		if Changes.BackgroundColor and typeof(Changes.BackgroundColor) == "Color3" then
			Notification.BackgroundColor3 = Changes.BackgroundColor;
		end
		if Changes.Options and type(Changes.Options) == "table" then
			-- Clear the options
			for _, option in pairs(Options:GetChildren()) do
				if option:IsA("TextButton") and option.Name ~= "PROMPT_DefaultButton" and option.Name ~= "PROMPT_Button" then
					option:Destroy();
				end
			end

			local SortedOptions = {};
			local PrimaryOption;
			local TimedOutOption;
			local checked = false;
			for internalname, optionvalues in pairs(Changes.Options) do
				if type(optionvalues) == "table" then
					if optionvalues.Text and type(optionvalues.Text) == "string" then
						SortedOptions[internalname] = tostring(optionvalues.Text);
						if checked == false then
							PrimaryOption = internalname;
						end
					end
					if optionvalues.Primary and type(optionvalues.Primary) == "boolean" and optionvalues.Primary == true then
						PrimaryOption = internalname;
					end
					if optionvalues.TimedOut and type(optionvalues.TimedOut) == "boolean" and optionvalues.TimedOut == true then
						TimedOutOption = internalname;
					end
					checked = true;
				end
			end

			-- Create the primary option
			local Button:TextButton = Options:FindFirstChild("PROMPT_DefaultButton"):Clone() :: TextButton;
			Button.Name = PrimaryOption;
			Button.Text = SortedOptions[PrimaryOption];
			Button.Parent = Options;
			Button.Visible = true;
			Button.Size = UDim2.new(0, Button.TextBounds.X + 20, 0, 30);
			Button.MouseButton1Click:Connect(function()
				InternalEvent:Fire("NotificationOptionSelected", Notification.Name, PrimaryOption);
				ClearNotification(Notification);
			end);

			-- Create the other options
			for internalname, text in pairs(SortedOptions) do
				if internalname ~= PrimaryOption then
					local Button:TextButton = Options:FindFirstChild("PROMPT_Button"):Clone() :: TextButton;
					Button.Name = internalname;
					Button.Text = text;
					Button.Parent = Options;
					Button.Visible = true;
					Button.Size = UDim2.new(0, Button.TextBounds.X + 10, 0, 30);
					Button.MouseButton1Click:Connect(function()
						InternalEvent:Fire("NotificationOptionSelected", Notification.Name, internalname);
						ClearNotification(Notification);
					end);
				end
			end
		end
	end

	-- Resize the notification
	local ListLayout = Options:FindFirstChild("UIListLayout") :: UIListLayout;
	local XSize = Label.TextBounds.X + ListLayout.AbsoluteContentSize.X + 35;

	if ListLayout.AbsoluteContentSize.X < 2 then
		XSize = Label.TextBounds.X + 20;
	end

	if type(Changes) == "table" and Changes.Image and type(Changes.Image) == "string" then
		XSize = XSize + 32;
	end

	Notification:TweenSize(UDim2.new(0, XSize, 0, 40), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true);
end

local function CreateList(title:string, items:{any: string|number}?, options:{string: any?}?)
	if not items then items = {} end;
	if not options then options = {} end;
	--TODO
	local UID = CreateUID();
	local List:Frame = Assets:FindFirstChild("List"):Clone() :: Frame;

	local Topbar:Frame = List:FindFirstChild("Top") :: Frame;
	local Title:TextLabel = Topbar:FindFirstChild("Title") :: TextLabel;
	local Close:TextButton = Topbar:FindFirstChild("Close") :: TextButton;
	local Minimize:TextButton = Topbar:FindFirstChild("PushToTaskbar") :: TextButton;

	local Bottombar:Frame = List:FindFirstChild("Bottom") :: Frame;
	local Searchbar:TextBox = Bottombar:FindFirstChild("Searchbar") :: TextBox;

	local Container:ScrollingFrame = List:FindFirstChild("Content") :: ScrollingFrame;
	local ButtonTemplate:TextButton = Container:FindFirstChild("TemplateButton") :: TextButton;

	List.Name = UID;
	Title.Text = title;
	ButtonTemplate.Visible = false;
	List.Parent = GUI;
	List.Visible = true;

	Dragify(List, Topbar);

	-- Sort the items
	local SortedItems = {};
	for internalname, item in pairs(items) do
		if type(item) == "string" or type(item) == "number" then
			SortedItems[internalname] = tostring(item);
		else
			warn("Invalid item type for list item '" .. internalname .. "'");
		end
	end

	-- Create the buttons for the items
	for internalname, text in pairs(SortedItems) do
		local Button:TextButton = ButtonTemplate:Clone() :: TextButton;
		Button.Name = internalname;
		Button.Label.Text = text;
		Button.Parent = Container;
		Button.Visible = true;

		Button.Label.TextWrapped = true
		Button.Label.TextTruncate = Enum.TextTruncate.AtEnd
		Button.ClipsDescendants = true

		local toggle = false;
		local debounce = false;

		task.wait(); -- Wait for it to update (for some reason it doesn't update without it, hence the wait. @Roblox; Fix?)
		Button.Label.Size = UDim2.new(1, -12, 0, 300); -- Attempt to get the textlabel's Y size

		Button.MouseButton1Click:Connect(function()
			-- Create a toggle to keep track of the state of the button; false = collapsed (default state), true = expanded
			if debounce then return false end;
			debounce = true;
			toggle = not toggle -- Invert the toggle state

			if toggle then -- If the toggle is true, expand the textlabel
				-- Expand the button to match the label's Y size
				Button:TweenSize(UDim2.new(1, 0, 0, Button.Label.TextBounds.Y + 14), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.1, true);
			else -- If the toggle is false, collapse the textlabel
				Button:TweenSize(UDim2.new(1,-8,0,30), "Out", "Quad", 0.1, true);
			end

			task.delay(0.3,function()
				debounce = false;
			end)
		end);
	end

	-- Make the list searchable
	Searchbar:GetPropertyChangedSignal("Text"):Connect(function()
		local SearchText = Searchbar.Text;
		for _, button in pairs(Container:GetChildren()) do
			if button:IsA("TextButton") and button.Name ~= "TemplateButton" then
				if string.find(string.lower(button.Label.Text), string.lower(SearchText)) then
					button.Visible = true;
				else
					button.Visible = false;
				end
			end
		end
	end);
end;

-- Get the commands and several settings from the server
local Commands = RemoteFunction:InvokeServer("GetCommands");
local Method = string.lower(RemoteFunction:InvokeServer("GetMethod"));

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
for _, qualifier in pairs(require(script.Qualifiers)) do
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
		for _,Name in pairs(names) do
			for _,v in next,game:GetService("Players"):GetPlayers() do
				if string.lower(v.Name):sub(1,string.len(Name)) == string.lower(Name) then
					table.insert(matches,v);
				end
			end
		end
		return matches;
	end

	-- Loop through all the players.
	for _,Name in pairs(names) do
		for _,v in next,game:GetService("Players"):GetPlayers() do
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
			for method, qualifier in pairs(sortedqualifiers) do
				if string.lower(Name) == string.lower(method) then
					local MatchedPlayers = qualifier.identifier(false, Players, LocalPlayer);
					for _, Player in pairs(MatchedPlayers) do
						table.insert(matches, Player);
					end;
				end;
			end;
		end
	end

	-- Remove duplicates.
	local newmatches = {}
	for _,v in pairs(matches) do
		if not table.find(newmatches,v) then
			table.insert(newmatches,v)
		end
	end

	return newmatches -- Return the matches.
end

-- Commandbar handler
local Commandbar = GUI:FindFirstChild("CommandBar");

UserInputService.InputBegan:Connect(function(input)
	-- Ignore the input if there's already an active input field
	if UserInputService:GetFocusedTextBox() then return end;

	if input.KeyCode == Enum.KeyCode.Equals then
		Commandbar:TweenPosition(UDim2.new(0.5, 0, 0, 10), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.1, true,function()
			Commandbar:FindFirstChild("Input").Text = "";
			Commandbar.Warnings.Visible = true;
		end);
		Commandbar:FindFirstChild("Input"):CaptureFocus();
	end
end);

-- When the commandbar is unfocused, hide it
Commandbar:FindFirstChild("Input").FocusLost:Connect(function(enterPressed)
	Commandbar:TweenPosition(UDim2.new(0.5, 0, 0, -35), Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.1, true);
	if enterPressed then
		-- Send the command to the server
		local Command = Commandbar:FindFirstChild("Input").Text;
		RemoteEvent:FireServer("CommandSent", Command);
	end
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
	for EscapeForm, EscapeFormValue in pairs(EscapeForms) do
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
	for _,v in pairs(Commandbar:FindFirstChild("Warnings"):GetChildren()) do
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
		MaskedText = "<font color='#" .. ToHex(Commands[Command].Color) .. "'><b>" .. Command .. "</b></font>";
	end

	-- Remove the command from the args
	table.remove(Args, 1);

	-- Highlight the args; If the command is invalid, highlight all args as grey
	if ValidCommand then
		-- Get the command's args
		local CommandArgs = Commands[Command].Arguments;
		local LastArgumentWarned = false;

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
		for i,arg in pairs(Args) do
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
						for _, v in pairs(CommandArgs[argnum].Options) do
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
					else
						MaskedText = MaskedText .. " <font color='#FFFFFF'>" .. arg .. "</font>";
					end
				elseif Type == "subcommand" then
					-- This type is no longer supported.
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
					Warning.Text = "<font color='#ffff77'>Raw Input</font>; " .. argnum .. "; This command does not support highlighting.";
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
					local color = Colors(string.lower(arg));
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
				if CommandArgs and CommandArgs[#CommandArgs] and (CommandArgs[#CommandArgs].Type == "string" or CommandArgs[#CommandArgs].Type == "rawinput") then
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
			for i, v in pairs(CommandArgs) do
				if not Args[i] and not v.Required then
					local Warning = Commandbar:FindFirstChild("Warnings"):FindFirstChild("Template"):Clone();
					Warning.Name = "Warning" .. i;
					Warning.Text = "<font color='#ffaa00'>Optional Argument</font>; " .. i .. "; "..NameFormat(v.Name).." of type '" .. v.Type .. "'.";
					Warning.Visible = true;
					Warning.Parent = Commandbar:FindFirstChild("Warnings");
				elseif v.Required and not Args[i] then
					-- Add a warning
					local Warning = Commandbar:FindFirstChild("Warnings"):FindFirstChild("Template"):Clone();
					Warning.Name = "Warning" .. i;
					Warning.Text = "<font color='#ff3300'>Argument Missing</font>; " .. i .. "; Required "..NameFormat(v.Name).." of type '" .. v.Type .. "'.";
					Warning.Visible = true;
					Warning.Parent = Commandbar:FindFirstChild("Warnings");
				end
			end
		end
	else
		for _, Arg in pairs(Args) do
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

-- Connect the remotes.
RemoteEvent.OnClientEvent:Connect(function(...)
	local Arguments = {...};
	local EventName = Arguments[1];
	table.remove(Arguments, 1);

	if EventName == "Notify" then
		CreateNotification(Arguments[1], Arguments[2]);
	elseif EventName == "UpdateNotification" then
		UpdateNotification(Arguments[1], Arguments[2]);
	elseif EventName == "ClearNotification" then
		ClearNotification(Arguments[1]);
	elseif EventName == "CreateList" then
		CreateList(Arguments[1], Arguments[2]);
	elseif EventName == "Hint" then
		local hint = Cardboard("Hint", GUI, {
			Title = Arguments[1];
			Content = Arguments[2];
		});
		-- Get the hint off the screen
		hint.Position = UDim2.new(0.5, 0, -1, 0);
		hint:TweenPosition(UDim2.new(0.5, 0, 0, 20), Enum.EasingDirection.Out, Enum.EasingStyle.Quad, 0.3, true);

		-- Get the text length
		local lenght = #Arguments[2];

		-- Wait for the hint to be on screen
		task.wait(0.3);

		-- Wait for the hint to be off screen
		task.wait( math.clamp(lenght / 30, 5, 20) );

		-- Get the hint off the screen
		hint:TweenPosition(UDim2.new(0.5, 0, -1, 0), Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.3, true, function()
			hint:Destroy();
		end);
	elseif env.ClientEvents[EventName] then
		env.ClientEvents[EventName](unpack(Arguments));
	end
end);

RemoteFunction.OnClientInvoke = function(...)
	local Arguments = {...};
	local FunctionName = Arguments[1];
	table.remove(Arguments, 1);

	if FunctionName == "NotificationExists" then
		return (not (not Cardboard:FindAsset(Arguments[1])));
	elseif FunctionName == "Notify" then -- If used in a function, it usually means the server is awaiting for a response from the player due to the .Options; Return an UUID to the server.
		local _, UID = CreateNotification(Arguments[1], Arguments[2]);
		return UID;
	elseif FunctionName == "Prompt" then
		local _, UID = CreatePrompt(Arguments[1]);
		return UID;
	elseif env.ClientFunctions[FunctionName] then
		return env.ClientFunctions[FunctionName](unpack(Arguments));
	end
end;