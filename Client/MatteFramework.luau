local TS = game:GetService("TweenService")

-- TYPES

type Banner = {
	Instance:typeof(script.Kit.Banner);
	Value:nil;
	SetTitle:(Banner,string)->nil;
	SetDescription:(Banner,string)->nil;
	SetIcon:(Banner,string)->nil;
	SetColor:(Banner,Color3)->nil;
};

type Boolean = {
	Instance:typeof(script.Kit.Boolean);
	Value:boolean;
	SetCallback:(Boolean, any)->nil;
	SetValue:(Boolean, boolean)->nil;
	OnChange:(Boolean, boolean)->nil;
	SetTitle:(Boolean,string)->nil;
	SetDescription:(Boolean,string)->nil;
};

type InputBox = {
	Instance:typeof(script.Kit.Textbox);
	Value:string?;
}

type Dropdown = {
	Instance:typeof(script.Kit.Dropdown);
	Value:string?;
	Options:{string};
}

-- SCRIPT

local Framework = {}

function Framework.Page(Parent:GuiBase)
	if not Parent then
		error("Parent is required for a Page.")
	end

	local Page = setmetatable({},{__index=Framework});

	Page.DropdownIsActive=false;

	Page.Instance = script.Page:Clone();
	Page.Instance.Parent = Parent;

	Page.Values={}; -- For all values from the page
	Page.Missing={}; -- For all missing values (required stuff) from the page

	function Page:SetContentParent(Parent) -- used for dropdowns
		Page.ContentParent = Parent;
		if not Page.DropdownScreen then
			Page.DropdownScreen = script.Kit.Dropdown_Actual:Clone()
		end
		Page.DropdownScreen.Parent = Parent
	end

	function Page:OpenDropdownSelection(Dropdown:Dropdown) -- used for dropdowns
		local TI = TweenInfo.new(0.2, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)

		for _, option in Page.DropdownScreen.Content.ScrollingFrame:GetChildren() do
			if option:IsA("TextButton") then
				if option.Name ~= "Template" then
					option:Destroy()
				end
			end
		end
		for i, option in Dropdown.Options do
			local template = Page.DropdownScreen.Content.ScrollingFrame.Template:Clone()
			template.Text = option
			template.Visible = true
			template.Name = option
			template.Parent = Page.DropdownScreen.Content.ScrollingFrame
			template.MouseButton1Click:Connect(function()
				Dropdown:SetValue(option);
				Page.DropdownIsActive = false;

				--Animate the closing
				TS:Create(Page.DropdownScreen,TI,{
					BackgroundTransparency=1;
				}):Play();
				TS:Create(Page.DropdownScreen.Content,TI,{
					Size=UDim2.fromScale(0.85,0.85);
					GroupTransparency=1;
				}):Play();

				task.delay(0.2,function()
					Page.DropdownScreen.Visible = false;
				end)
			end)
			template.ZIndex = i
		end
		Page.DropdownScreen.BackgroundTransparency=1;
		Page.DropdownScreen.Content.GroupTransparency=1;
		Page.DropdownScreen.Content.Size=UDim2.fromScale(0.85,0.85);

		--While the dropdown is active, everything else should be disabled (including the other dropdown buttons)
		Page.DropdownIsActive = true;

		Page.DropdownScreen.Visible = true
		TS:Create(Page.DropdownScreen,TI,{
			BackgroundTransparency=0.5;
		}):Play();
		TS:Create(Page.DropdownScreen.Content,TI,{
			Size=UDim2.fromScale(0.8,0.8);
			GroupTransparency=0;
		}):Play();
	end

	if Page.Instance.Parent.Name:lower() == 'content' then
		Page:SetContentParent(Page.Instance.Parent.Parent);
	end

	return Page
end;

function Framework:Banner() -- This banner does not count as an input instance, hence there's no 'Value' in it.
	local Page = self;

	local Banner:Banner = {
		Instance = script.Kit.Banner:Clone();
		Value=nil;
	};

	function Banner:SetTitle(NewText:string)
		self.Instance.Frame.TextFrame.Title.Visible = true;
		self.Instance.Frame.TextFrame.Title.Text = NewText;
		return nil;
	end;

	function Banner:SetDescription(NewText:string)
		self.Instance.Frame.TextFrame.Description.Text = NewText;
		return nil;
	end;

	function Banner:SetIcon(AssetUrl:string)
		if AssetUrl == "" then
			self.Instance.Frame.Icon.Visible = false;
			return nil;
		end
		self.Instance.Frame.Icon.Visible = true;
		self.Instance.Frame.Icon.Image = AssetUrl;
		return nil;
	end;

	function Banner:SetColor(Color:Color3)
		self.Instance.Frame.BackgroundColor3 = Color or Color3.fromRGB(0, 85, 255);
		self.Instance.Frame.UIStroke.Color = Color or Color3.fromRGB(0, 85, 255);
		return nil;
	end;

	Banner.Instance.Parent = Page.Instance;
	return Banner;
end;

function Framework:Boolean(DefaultValue:boolean?)
	local Page = self;

	local Boolean:Boolean = {
		Instance = script.Kit.Boolean:Clone();
		Value=DefaultValue or false;
		OnChange=nil;
		Key='';
	};

	function Boolean:SetCallback(func)
		if typeof(func) == "function" then
			self.OnChange = func;
			return nil;
		end
		warn("Boolean::SetCallback | Callback must be a function.")
		return nil;
	end

	function Boolean:SetValue(NewValue:boolean)
		Boolean.Value = NewValue
		Boolean.Instance.Frame.Transparency = NewValue and 0 or 1
		if Boolean.OnChange and typeof(Boolean.OnChange) == "function" then
			Boolean.OnChange(Boolean.Value)
		end

		if Boolean.Key then
			Page.Values[Boolean.Key] = NewValue;
		end

		return nil;
	end;

	Boolean:SetValue(Boolean.Value); -- For the default value

	Boolean.Instance.Frame.MouseButton1Click:Connect(function()
		Boolean:SetValue(not Boolean.Value)
	end)

	function Boolean:SetTitle(NewText:string)
		self.Instance.TextFrame.Title.Visible = true;
		self.Instance.TextFrame.Title.Text = NewText;
		return nil;
	end;

	function Boolean:SetDescription(NewText:string)
		self.Instance.TextFrame.Description.Text = NewText;
		return nil;
	end;

	function Boolean:SetKey(Key:string)
		Page.Values[Key] = Boolean.Value;
		Boolean.Key = Key;
		return nil;
	end;

	function Boolean:GetValue()
		return Boolean.Value;
	end;

	Boolean.Instance.Parent = Page.Instance;
	return Boolean;
end;

function Framework:InputBox(Numeral:boolean?)
	local Page = self;

	local InputBox:InputBox = {
		Instance = script.Kit.Textbox:Clone();
		Value="";
		Placeholder="";
		Numeral=Numeral or false;
		Required=false;
		OnFocus=nil;
		OnChange=nil;
		Editable=true;
		Key='';
	};

	function InputBox:SetCallback(func)
		if typeof(func) == "function" then
			self.OnChange = func;
			return nil;
		end
		warn("InputBox::SetCallback | Callback must be a function.")
		return nil;
	end

	function InputBox:SetPlaceholder(NewValue:string) -- do NOT use SetPlaceholder in order to change the text on the PlaceholderText. Use Instance.Frame.Input.PlaceholderText for that!
		if InputBox.Numeral and NewValue ~= '' then
			NewValue = string.gsub(NewValue, "%D", "");
		end;
		InputBox.Placeholder = NewValue;

		if InputBox.Value:gsub("%s+", "") == "" then
			InputBox.Instance.Frame.Input.PlaceholderText = "Type here...";
		else
			InputBox.Instance.Frame.Input.PlaceholderText = NewValue;
		end;

		return nil;
	end;

	InputBox:SetPlaceholder(InputBox.Placeholder)

	function InputBox:SetValue(NewValue:string)
		if InputBox.Numeral and NewValue ~= '' then
			NewValue = string.gsub(NewValue, "%D", "");
		end; -- lol
		InputBox.Instance.Frame.Input.Text = NewValue;
		InputBox.Instance.Frame.Uneditable.Text = NewValue;
		if NewValue == '' then
			NewValue = InputBox.Placeholder;
		end
		InputBox.Value = NewValue;
		if InputBox.OnChange and typeof(InputBox.OnChange) == "function" then
			InputBox.OnChange(InputBox.Numeral and tonumber(InputBox.Value) or InputBox.Value);
		end;

		if InputBox.Key then
			Page.Values[InputBox.Key] = NewValue;
		end

		return nil;
	end;

	function InputBox:SetEditable(Bool:boolean)
		InputBox.Editable = Bool;
		InputBox.Instance.Frame.Uneditable.Text = InputBox.Value;
		InputBox.Instance.Frame.Uneditable.Visible = not Bool;
		InputBox.Instance.Frame.Input.Visible = Bool;
		return nil;
	end

	function InputBox:SetRequired(Bool:boolean)
		InputBox.Required = Bool;
		InputBox.Instance.Info.Required.Visible = Bool;
		return nil;
	end;

	function InputBox:SetNumeral(Bool:boolean)
		InputBox.Numeral = Bool;
		InputBox:SetValue(InputBox.Value); -- fixes itself if it's a numeral
		InputBox.Instance.Info.Numeral.Visible = Bool;
		return nil;
	end;

	local PreChange = "";
	InputBox.Instance.Frame.Input.Focused:Connect(function()
		PreChange = InputBox.Instance.Frame.Input.Text;
	end);
	InputBox.Instance.Frame.Input.FocusLost:Connect(function(EnterPressed)
		if EnterPressed then
			InputBox:SetValue(InputBox.Instance.Frame.Input.Text);
		else
			InputBox.Instance.Frame.Input.Text = PreChange;
		end;
		if InputBox.Required then
			local TI = TweenInfo.new(0.5, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)
			if InputBox.Instance.Frame.Input.Text:gsub("%s+", "") == "" then
				TS:Create(InputBox.Instance.Frame.UIStroke, TI, {Color = Color3.fromRGB(204, 42, 42)}):Play()
				TS:Create(InputBox.Instance.Info.Numeral, TI, {TextColor3 = Color3.fromRGB(204, 42, 42)}):Play()
				TS:Create(InputBox.Instance.Info.Required, TI, {TextColor3 = Color3.fromRGB(204, 42, 42)}):Play()
				TS:Create(InputBox.Instance.Frame.Input, TI, {PlaceholderColor3 = Color3.fromRGB(204, 42, 42)}):Play()
			else
				TS:Create(InputBox.Instance.Frame.UIStroke, TI, {Color = Color3.fromRGB(127, 127, 127)}):Play()
				TS:Create(InputBox.Instance.Info.Numeral, TI, {TextColor3 = Color3.fromRGB(127, 127, 127)}):Play()
				TS:Create(InputBox.Instance.Info.Required, TI, {TextColor3 = Color3.fromRGB(127, 127, 127)}):Play()
				TS:Create(InputBox.Instance.Frame.Input, TI, {PlaceholderColor3 = Color3.fromRGB(178, 178, 178)}):Play()
			end
		end
	end);
	InputBox.Instance.Frame.Input:GetPropertyChangedSignal("Text"):Connect(function()
		if InputBox.Numeral and InputBox.Instance.Frame.Input.Text ~= '' then
			InputBox.Instance.Frame.Input.Text = string.gsub(InputBox.Instance.Frame.Input.Text, "%D", "");
		end;
	end);

	function InputBox:SetTitle(NewText:string)
		self.Instance.Title.Visible = NewText~="";
		self.Instance.Title.Text = NewText;
		return nil;
	end;

	function InputBox:SetKey(Key:string)
		Page.Values[Key] = InputBox.Value;
		InputBox.Key = Key;
		return nil;
	end;

	function InputBox:GetValue()
		return InputBox.Value;
	end;

	InputBox.Instance.Parent = Page.Instance;
	return InputBox;
end;

function Framework:Dropdown(Options:{string}?)
	local Page = self;

	local Dropdown:Dropdown = {
		Instance = script.Kit.Dropdown:Clone();
		Value= Options[1] or "None";
		Options = Options or {"None"};
		InvalidOptions = {};
		Key='';
	};

	function Dropdown:SetCallback(func)
		if typeof(func) == "function" then
			self.OnChange = func;
			return nil;
		end
		warn("Dropdown::SetCallback | Callback must be a function.")
		return nil;
	end

	function Dropdown:SetValue(NewValue:string, bypassCheck:boolean)
		if table.find(Dropdown.Options, NewValue) or bypassCheck then
			Dropdown.Value = NewValue
			Dropdown.Instance.Frame.Input.Text = NewValue;
			if Dropdown.OnChange and typeof(Dropdown.OnChange) == "function" then
				Dropdown.OnChange(Dropdown.Value)
			end

			if Dropdown.Key then
				Page.Values[Dropdown.Key] = NewValue;
			end
		else
			warn("Dropdown::SetValue | Value must exist in the possible Options.")
		end

		local TI = TweenInfo.new(0.5, Enum.EasingStyle.Circular, Enum.EasingDirection.Out)
		if table.find(Dropdown.InvalidOptions, NewValue) then
			TS:Create(Dropdown.Instance.Frame.UIStroke, TI, {Color = Color3.fromRGB(204, 42, 42)}):Play()
			TS:Create(Dropdown.Instance.Frame.Input, TI, {TextColor3 = Color3.fromRGB(204, 42, 42)}):Play()
		else
			TS:Create(Dropdown.Instance.Frame.UIStroke, TI, {Color = Color3.fromRGB(127, 127, 127)}):Play()
			TS:Create(Dropdown.Instance.Frame.Input, TI, {TextColor3 = Color3.fromRGB(178, 178, 178)}):Play()
		end

		return nil;
	end;

	function Dropdown:SetOptions(NewOptions:{string})
		if #NewOptions >= 1 then
			Dropdown.Value = NewOptions[1]
			if Dropdown.OnChange and typeof(Dropdown.OnChange) == "function" then
				Dropdown.OnChange(Dropdown.Value)
			end

			-- clear non-existing invalid options
			for i, option in Dropdown.InvalidOptions do
				if not table.find(Dropdown.Options, option) then
					table.remove(Dropdown.InvalidOptions, i)
				end
			end
		else
			warn("Dropdown::SetOptions | Options must have at least 1 Value.")
		end
		return nil;
	end;

	Dropdown:SetValue(Dropdown.Value, true); -- For the default value

	Dropdown.Instance.Frame.ClickHitbox.MouseButton1Click:Connect(function()
		if Page.DropdownIsActive then return end;
		if Page.ContentParent then
			if #Dropdown.Options > 0 then
				Page:OpenDropdownSelection(Dropdown)
			else
				warn("Dropdown | Cannot open selection, there are no choices to pick from!")
			end
		else
			warn("Dropdown | Cannot open selection, Page.ContentParent is nil")
		end
	end)

	function Dropdown:MustNotBe(Options:{string}) -- set invalid options that are part of the dropdown options
		for _, option in Options do
			if table.find(Dropdown.Options, option) then
				table.insert(Dropdown.InvalidOptions, option)
			else
				warn("Dropdown::MustNotBe | Option must exist in the possible Options.")
			end
		end
		return nil;
	end;

	function Dropdown:SetKey(Key:string)
		Page.Values[Key] = Dropdown.Value;
		Dropdown.Key = Key;
		return nil;
	end;

	function Dropdown:SetTitle(NewText:string)
		self.Instance.Title.Visible = true;
		self.Instance.Title.Text = NewText;
		return nil;
	end;

	function Dropdown:GetValue()
		return Dropdown.Value;
	end

	Dropdown.Instance.Parent = Page.Instance;
	return Dropdown;
end;

function Framework:Multichoice(Options:{string}?)
	local Page = self;

	local Multichoice = {
		Instance = script.Kit.Multichoice:Clone();
		Value={};
		Options = Options or {"None"};
		Key='';
	};

	function Multichoice:SetCallback(func)
		if typeof(func) == "function" then
			self.OnChange = func;
			return nil;
		end
		warn("Multichoice::SetCallback | Callback must be a function.")
		return nil;
	end

	function Multichoice:UpdateChoices(OptionsUpdated:boolean) -- UI-sided change of the choices, since they're not using a dropdown
		if OptionsUpdated then
			for _,v in Multichoice.Instance.Frame:GetChildren() do
				if v:IsA("Frame") and v.Name ~= 'Template' then
					v:Destroy();
				end
			end

			for i, option in Multichoice.Options do
				local NewChoice = Multichoice.Instance.Frame.Template:Clone();
				NewChoice.ChoiceText.Text = option;
				NewChoice.Name = option;
				NewChoice.Parent = Multichoice.Instance.Frame;
				NewChoice.Visible = true;

				NewChoice.Click.MouseButton1Click:Connect(function()
					Multichoice:SetValue(option);
					for _,v in Multichoice.Instance.Frame:GetChildren() do
						if v:IsA("Frame") and v.Name ~= 'Template' then
							v.Click.Frame.Visible = false;
						end
					end

					NewChoice.Click.Frame.Visible = true;
				end);

				-- Hover
				NewChoice.Click.MouseEnter:Connect(function()
					NewChoice.Click.BackgroundTransparency = 0.85;
				end);
				NewChoice.Click.MouseLeave:Connect(function()
					NewChoice.Click.BackgroundTransparency = 1;
				end);
			end;
		else
			-- Update the UI to reflect the current values
			for _,v in Multichoice.Instance.Frame:GetChildren() do
				if v:IsA("Frame") and v.Name ~= 'Template' then
					if v.Name == Multichoice.Value then
						v.Click.Frame.Visible = true;
					else
						v.Click.Frame.Visible = false;
					end
				end
			end
		end;
	end;

	function Multichoice:SetValue(NewValue:string) -- u cant bypass the check here
		if table.find(Multichoice.Options, NewValue) then
			Multichoice.Value = NewValue
			if Multichoice.OnChange and typeof(Multichoice.OnChange) == "function" then
				Multichoice.OnChange(Multichoice.Value)
			end

			if Multichoice.Key then
				Page.Values[Multichoice.Key] = Multichoice.Values;
			end

			Multichoice:UpdateChoices(false);
		else
			warn("Multichoice::SetValue | Value must exist in the possible Options.")
		end
		return nil;
	end;

	function Multichoice:SetOptions(NewOptions:{string})
		if #NewOptions >= 1 then
			Multichoice.Value = NewOptions[1]
			if Multichoice.OnChange and typeof(Multichoice.OnChange) == "function" then
				Multichoice.OnChange(Multichoice.Values)
			end
		else
			warn("Multichoice::SetOptions | Options must have at least 1 Value.")
		end
		return nil;
	end;

	function Multichoice:SetKey(Key:string)
		Page.Values[Key] = Multichoice.Values;
		Multichoice.Key = Key;
		return nil;
	end;

	function Multichoice:SetTitle(NewText:string)
		self.Instance.TextFrame.Title.Visible = NewText~="";
		self.Instance.TextFrame.Title.Text = NewText;
		return nil;
	end;

	function Multichoice:SetDescription(NewText:string)
		self.Instance.TextFrame.Description.Visible = NewText~="";
		self.Instance.TextFrame.Description.Text = NewText;
		return nil;
	end;

	function Multichoice:GetValue()
		return Multichoice.Value;
	end;

	Multichoice:UpdateChoices(true); -- initial creation

	Multichoice.Instance.Parent = Page.Instance;
	return Multichoice;
end;

function Framework:TextFrame()
	local Page = self;

	local TextFrame = {
		Instance = script.Kit.TextFrame:Clone();
	};

	function TextFrame:SetTitle(NewText:string)
		self.Instance.Title.Visible = NewText~="";
		self.Instance.Title.Text = NewText;
		return nil;
	end;

	function TextFrame:SetDescription(NewText:string)
		self.Instance.Description.Visible = NewText~="";
		self.Instance.Description.Text = NewText;
		return nil;
	end;

	TextFrame.Instance.Parent = Page.Instance;
	return TextFrame;
end;

return Framework;