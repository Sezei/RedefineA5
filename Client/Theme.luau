-- THIS IS RUNNING ON THE CLIENT SIDE!
-- Make sure to fully use the clientenv!

local ContentProvider = game:GetService("ContentProvider")
local TweenService:TweenService = game:GetService("TweenService");
local UserInputService:UserInputService = game:GetService("UserInputService");

local Players = game:GetService("Players");

function Theme(env)
	local GUI = env.GUI;
	local Assets = env.Assets;
	local Dragify = env.Dragify; -- Allows creating draggable UI elements; usage: Dragify(DraggableFrame, PartToDragFrom);
	local Cardboard = env.Cardboard; -- Allows creating UI elements from the Assets folder; usage: Cardboard(AssetType, Parent, Properties);
	local Colors = env.Colors;
	local InternalEvent = env.InternalEvent;
	local RemoteEvent = env.RemoteEvent;
	local RemoteFunction = env.RemoteFunction;
	
	
	function env.NameFormat(input:string) -- This will turn any string input into a correctly-capitalised output; 'hElOOl' -> 'Heloool'
		local output = input:lower();
		output = output:sub(1,1):upper() .. output:sub(2);
		return output;
	end;
	
	function env.ClearNotification(Notification:TextButton)
		Notification.Name = "disappearing"
		-- Remove the notification out of the screen
		local currentpos = Notification.Position;
		local targetpos = UDim2.new(currentpos.X.Scale + 2, currentpos.X.Offset, currentpos.Y.Scale, currentpos.Y.Offset);
		local tween = TweenService:Create(Notification, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = targetpos});
		tween:Play();
		-- Move any other notifications downwards
		for _,v in GUI:GetChildren() do
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

	-- A prompt is a hint with a selection of choices.
	function env.CreatePrompt(options:{[any]:any?})
		-- Override protection; Await until the previous prompt is cleared.
		if GUI:FindFirstChild("ActivePrompt") then
			repeat task.wait() until not GUI:FindFirstChild("ActivePrompt");
		end;

		-- Create the prompt.
		local Prompt = Assets:FindFirstChild("Prompt"):Clone();
		Prompt.Name = "ActivePrompt";
		Dragify(Prompt);

		local Choices = Prompt:FindFirstChild("Options") :: Frame;
		local Content = Prompt:FindFirstChild("Content") :: TextLabel;
		local Options = options.Options or {'Button'};

		Content.Text = options.Text or "Missing String";

		local SortedOptions = {};
		local PrimaryOption = nil;
		local checked = false;
		for internalname, optionvalues in (Options) do
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
		for internalname, text in (SortedOptions) do
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
	function env.CreateInput(options:{[any?]:any?}?)
		-- Override Protection: Wait until the previous input is gone.
		if GUI:FindFirstChild("ActiveInput") then
			repeat task.wait() until not GUI:FindFirstChild("ActiveInput");
		end

		--TODO: Input UI
	end;


	-- The following two functions will be removed upon the completion of CreateInput, and migrated into it.
	function env.CreatePrivateConversation(playerID:number)
		-- This uses the INPUT UI.
		-- Make sure we don't override the previous input.
		if GUI:FindFirstChild("ActiveInput") then
			repeat task.wait() until not GUI:FindFirstChild("ActiveInput");
		end

		-- Create the input.
		local Input = Assets:FindFirstChild("Input"):Clone() :: Frame;
		Input.Name = "ActiveInput";
		Input.Parent = GUI;
		Input.Visible = true;
		Dragify(Input);

		Input:FindFirstChild("Title")
			.Text = "Sending to <b>" .. Players:GetPlayerByUserId(playerID).DisplayName .. "</b>";

		local function Send()
			-- Send the message to the server.
			local Text = Input.InputHolder:FindFirstChild("Input").Text
			Input:Destroy();
			RemoteEvent:FireServer("PrivateMessage", playerID, Text);
		end;

		local function Cancel()
			-- Cancel the message.
			Input:Destroy();
		end;

		Input.Options.PROMPT_DefaultButton.MouseButton1Click:Connect(Send);
		Input.Options.PROMPT_DefaultButton.Visible = true;

		if not env.Settings.NoTaskbar then
			local SendLater = Input.Options.PROMPT_Button:Clone();
			SendLater.Parent = Input.Options;
			SendLater.Visible = true;
			SendLater.Text = "Send Later";

			SendLater.MouseButton1Click:Connect(function()
				local UID = env.CreateUID();
				Input.Name = UID;

				Input.Visible = false;
				local btn = GUI.Taskbar.InnerContainer.Template:Clone();
				btn.Text = "PM to "..Players:GetPlayerByUserId(playerID).DisplayName
				btn.Name = UID;
				btn.Parent = GUI.Taskbar.InnerContainer;
				task.wait();
				btn.Size = UDim2.fromOffset(math.clamp(btn.TextBounds.X + 20, 90, 250), 40);
				btn.Visible = true;
			end);
		end;

		Input.Options.PROMPT_Button.MouseButton1Click:Connect(Cancel);
		Input.Options.PROMPT_Button.Visible = true;
	end;

	function env.ReceivePrivateConversation(playerID:number, text:string)
		-- Function to receive a private conversation message.
		-- This uses the DInput UI, which is input but can't edit the message.

		if GUI:FindFirstChild("ActiveInput") then
			repeat task.wait() until not GUI:FindFirstChild("ActiveInput");
		end

		-- Create the input.
		local Input = Assets:FindFirstChild("DInput"):Clone();
		Input.Name = "ActiveInput";
		Input.Parent = GUI;
		Input.Visible = true;
		Dragify(Input);

		Input.Title.Text = "Private Message From <b>" .. Players:GetPlayerByUserId(playerID).DisplayName .. "</b>";
		Input.InputHolder:FindFirstChild("Input").Text = text;

		local function Send()
			-- Send the message to the server.
			Input:Destroy();
			env.CreatePrivateConversation(playerID);
		end;

		local function Cancel()
			-- Cancel the message.
			Input:Destroy();
		end;

		Input.Options.PROMPT_DefaultButton.MouseButton1Click:Connect(Send);
		Input.Options.PROMPT_DefaultButton.Visible = true;

		if not env.Settings.NoTaskbar then
			local SendLater = Input.Options.PROMPT_Button:Clone();
			SendLater.Parent = Input.Options;
			SendLater.Visible = true;
			SendLater.Text = "Save Message";

			SendLater.MouseButton1Click:Connect(function()
				local UID = env.CreateUID();
				Input.Name = UID;

				Input.Visible = false;
				local btn = GUI.Taskbar.InnerContainer.Template:Clone();
				btn.Text = "PM from "..Players:GetPlayerByUserId(playerID).DisplayName
				btn.Name = UID;
				btn.Parent = GUI.Taskbar.InnerContainer;
				task.wait();
				btn.Size = UDim2.fromOffset(math.clamp(btn.TextBounds.X + 20, 90, 250), 40);
				btn.Visible = true;
			end);
		end;

		Input.Options.PROMPT_Button.MouseButton1Click:Connect(Cancel);
		Input.Options.PROMPT_Button.Visible = true;
	end;

	function env.CreateNotification(text:string, options:{[any?]: any?}?)
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
					options.Sound = options.Sound or 'rbxassetid://5974456365';
				elseif string.lower(options.Type) == "error" then
					Cardboard:UpdateAsset(UID, {
						["BackgroundColor"] = Color3.fromRGB(45, 45, 45);
						["TextColor"] = Color3.fromRGB(255, 60, 60);
					});
					options.Sound = options.Sound or 'rbxassetid://5974456449';
				elseif string.lower(options.Type) == "critical" then
					Cardboard:UpdateAsset(UID, {
						["BackgroundColor"] = Color3.fromRGB(255, 60, 60);
						["TextColor"] = Color3.fromRGB(255, 255, 255);
					});
					Label.Font = Enum.Font.GothamBlack;
					PushingDown = true;
					options.Sound = options.Sound or 'rbxassetid://5974456264';
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
						env.ClearNotification(Notification);
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
			if options.Sound and type(options.Sound) == "string" then
				if env.Settings.NotificationSounds then
					env.PlaySound(options.Sound);
				end;
			end
			if options.Options and type(options.Options) == "table" then
				local SortedOptions = {};
				local checked = false;
				for internalname, optionvalues in (options.Options) do
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
					env.ClearNotification(Notification);
				end);

				-- Create the other options
				for internalname, text in (SortedOptions) do
					if internalname ~= PrimaryOption then
						local Button:TextButton = Options:FindFirstChild("PROMPT_Button"):Clone() :: TextButton;
						Button.Name = internalname;
						Button.Text = text;
						Button.Parent = Options;
						Button.Visible = true;
						Button.Size = UDim2.new(0, Button.TextBounds.X + 10, 0, 30);
						Button.MouseButton1Click:Connect(function()
							InternalEvent:Fire("NotificationOptionSelected", UID, internalname);
							env.ClearNotification(Notification);
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
			for _, notification in (GUI:GetChildren()) do
				if notification:IsA("TextButton") and notification.Name ~= "disappearing" then
					NotificationCount = NotificationCount + 1;
				end
			end
			local NotificationPosition = UDim2.new(1, -10, 1, (-50 * NotificationCount - 10));
			Notification.Position = NotificationPosition;
		else
			local children = GUI:GetChildren();
			for _,v in (children) do
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
			env.ClearNotification(Notification);
		end);

		Notification.Visible = true;

		return Notification, UID;
	end;

	function env.UpdateNotification(Notification:TextButton|string, Changes:any)
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
				for _, option in (Options:GetChildren()) do
					if option:IsA("TextButton") and option.Name ~= "PROMPT_DefaultButton" and option.Name ~= "PROMPT_Button" then
						option:Destroy();
					end
				end

				local SortedOptions = {};
				local PrimaryOption;
				local TimedOutOption;
				local checked = false;
				for internalname, optionvalues in (Changes.Options) do
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
					env.ClearNotification(Notification);
				end);

				-- Create the other options
				for internalname, text in (SortedOptions) do
					if internalname ~= PrimaryOption then
						local Button:TextButton = Options:FindFirstChild("PROMPT_Button"):Clone() :: TextButton;
						Button.Name = internalname;
						Button.Text = text;
						Button.Parent = Options;
						Button.Visible = true;
						Button.Size = UDim2.new(0, Button.TextBounds.X + 10, 0, 30);
						Button.MouseButton1Click:Connect(function()
							InternalEvent:Fire("NotificationOptionSelected", Notification.Name, internalname);
							env.ClearNotification(Notification);
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

	function env.CreateList(title:string, items:{any: string|number}?, options:{string: boolean}?)
		if not items then items = {} end;
		if not options then options = {Searchbar = true; Minimizable = true;} end;
		--TODO
		local UID = env.CreateUID();
		local List:Frame = Assets:FindFirstChild("List"):Clone() :: Frame;

		local Topbar:Frame = List:FindFirstChild("Top") :: Frame;
		local Title:TextLabel = Topbar:FindFirstChild("Title") :: TextLabel;
		local Close:TextButton = Topbar:FindFirstChild("Close") :: TextButton;
		local Minimize:TextButton = Topbar:FindFirstChild("PushToTaskbar") :: TextButton;
		local Refresh:TextButton = Topbar:FindFirstChild("Refresh") :: TextButton;

		local Bottombar:Frame = List:FindFirstChild("Bottom") :: Frame;
		local Searchbar:TextBox = Bottombar:FindFirstChild("Searchbar") :: TextBox;

		local Container:ScrollingFrame = List:FindFirstChild("Content") :: ScrollingFrame;
		local ButtonTemplate:TextButton = Container:FindFirstChild("TemplateButton") :: TextButton;
		local RealButton = Container:FindFirstChild("TemplateRealButton");
		local Description = Container:FindFirstChild("TemplateDescription");

		Container.ClipsDescendants = true; -- For some reason it can randomly be set to false?

		List.Name = UID;
		Title.Text = title;
		ButtonTemplate.Visible = false;
		List.Parent = GUI;
		List.Visible = true;

		List:SetAttribute("AssetClass", "List"); -- When we use RefreshList(), we can check if the asset is a list or not so we don't need to rebuild it entirely

		Dragify(List, Topbar);

		-- Sort the items
		local SortedItems = {};
		for internalname, item in (items) do
			if type(item) == "string" or type(item) == "number" then
				SortedItems[internalname] = tostring(item);
			else
				warn("Invalid item type for list item '" .. internalname .. "'");
			end
		end

		if options.Searchbar then
			Searchbar.Visible = true;
			Searchbar:GetPropertyChangedSignal("Text"):Connect(function()
				local SearchText = Searchbar.Text;
				for _, button in (Container:GetChildren()) do
					if button:IsA("TextButton") and button.Name ~= "TemplateButton" and button.Name ~= "TemplateRealButton" then
						if string.find(string.lower(button.Label.Text), string.lower(SearchText)) then
							button.Visible = true;
						else
							button.Visible = false;
						end
					end
				end
			end);
		else
			Searchbar.Visible = false;
			Searchbar:Destroy();
			Bottombar.Size = UDim2.new(1, 0, 0, 0);
		end;
		if options.Minimizable then
			Minimize.Visible = true;
		else
			Minimize.Visible = false;
			Minimize:Destroy();
		end;
		if options.Refreshable then
			if not options.Minimizable then
				Minimize.Position = UDim2.new(1, -26, 0.5, 0);
			end;
			Refresh.Visible = true;
			Refresh.MouseButton1Click:Connect(function()
				local Items = RemoteFunction:InvokeServer("GetListItems", options.Refreshable); -- If it's refreshable, there's probably a valid function to get the items in the server-side; likely env.Data[path]

				if not Items then return end;

				for _, button in (Container:GetChildren()) do
					if button:IsA("TextButton") and button.Name ~= "TemplateButton" then
						button:Destroy();
					end
				end

				local SortedItems = {};
				for internalname, item in (Items) do
					if type(item) == "string" or type(item) == "number" then
						SortedItems[internalname] = tostring(item);
					else
						warn("Invalid item type for list item '" .. internalname .. "'");
					end
				end

				for internalname, item in (SortedItems) do
					local Button:TextButton = ButtonTemplate:Clone() :: TextButton;
					Button.Name = internalname;
					Button.Label.Text = tostring(item);
					Button.Parent = Container;
					Button.Visible = true;
				end
			end);
		end;

		-- Create the buttons for the items
		for internalname, item in (SortedItems) do
			if type(item) == 'string' then
				local Button:TextButton = ButtonTemplate:Clone() :: TextButton;
				Button.Name = internalname;
				Button.Label.Text = item;
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
			elseif type(item) == 'table' then
				if item.Type == "ClickText" then
					local Button:TextButton = ButtonTemplate:Clone() :: TextButton;
					Button.Name = internalname;
					Button.Label.Text = item.Text;
					Button.Parent = Container;
					Button.Visible = true;

					Button.Label.TextWrapped = true;
					Button.Label.TextTruncate = Enum.TextTruncate.AtEnd;
					Button.ClipsDescendants = true;

					if item.TextColor then
						Button.Label.TextColor3 = item.TextColor;
					end;

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
				elseif item.Type == "Button" then
					local Button = RealButton:Clone();
					Button.Name = internalname;
					Button.Button.Text = item.Text;
					Button.Parent = Container;
					Button.Visible = true;

					Button.Button.MouseButton1Click:Connect(function()
						RemoteEvent:FireServer("ExecuteCallbackAsClient", item.CallbackId);
					end);
				end
			end;
		end

		return List, UID;
	end;
end;

return Theme;