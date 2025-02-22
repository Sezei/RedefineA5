local TS = game:GetService("TweenService")
local Serializer = require(script.Serializer);

local settingChanged = false;

local TrueParent = script:FindFirstAncestorOfClass('ScreenGui')

local curSettings = Serializer.decode(TrueParent:GetAttribute('settings'));
local baseSettings = Serializer.decode(TrueParent:GetAttribute('basesettings'));

script.Parent.LeftHalf.Buttons.TextLabel.Text = string.format("Redefine:A 5 - Build %s", tostring(TrueParent:GetAttribute("nxversion")))
local Tips = require(script.Tips)

function getRandomTip()
	local random = Random.new():NextInteger(1, #Tips)
	while random == 7 do
		random = Random.new():NextInteger(1, #Tips)
		task.wait()
	end
	script.Parent.RightHalf.Slides.RandomTip.Tip.Text = Tips[random]
end

task.spawn(function()
	getRandomTip()
	while task.wait(20) do
		getRandomTip()
	end
end)

local TOS = require(script.TermsOfService)
local Framework = require(script.Parent.Framework);
local ProgressDots = require(script.ProgressDots).new(3, script.Parent.RightHalf.ProgressDots)
local Pages = {}

type PageItem = {
	Type:"Dropdown" | "Banner" | "Boolean" | "InputBox" | "Multichoice" | "TextFrame";
	Title:string?;
	Description:string?;
	Icon:string?;
	Required:boolean?;
	Numeral:boolean?;
	Choices:{string}?;
	DefaultValue:string|boolean?;
	Color:Color3?;
	Callback:any?;
};
type PageData = {
	Items:{PageItem};
	Index:number;
	OnOpen:any?;
	Variables:{any}?;
};
local PageIndex = 0

pagesData = {
	{
		Index = 0;
		Items = {
			{
				Type = "Banner";
				Title = "Warning";
				Description = "Please note that by using Redefine:A, you agree its TOS.";
				Icon = "http://www.roblox.com/asset/?id=6026568210";
				Color = Color3.fromRGB(255, 0, 0);
				Persist = false;
			},

			{
				Type = 'TextFrame';
				Title = 'Terms of Service ('..TOS.Date..')';
				Description = TOS.TOS;
			},

			{
				Type = "Boolean";
				Title = "I agree to the SME TOS";
				Description = "Check to continue to next step";
				DefaultValue = false;
				Callback = function(val)
					script.Parent.LeftHalf.Buttons.Next.Visible = val
				end,
			}
		},
		OnOpen = function()
			ProgressDots:SetDotStatus(0);
			script.Parent.LeftHalf.Buttons.Previous.Visible = false;
		end,
	},

	{
		Index = 1;
		Items = {
			{
				Type = "TextFrame";
				Description = "Checking for missing settings...";
			}
		},
		OnOpen = function(RawPage)
			ProgressDots:SetDotStatus(1)
			script.Parent.LeftHalf.Buttons.Next.Visible = false;
			script.Parent.LeftHalf.Buttons.Previous.Visible = false;
			if RawPage.Data.Variables.AlreadyChecked then
				script.Parent.LeftHalf.Buttons.Next.Visible = true;
				script.Parent.LeftHalf.Buttons.Previous.Visible = true;
				return;
			else
				local missingSettings = {};
				-- a bit confusing but curSettings is what *should* be after it is filtered in the datastore check
				-- baseSettings is what the user puts in the loader and are used as the 'effective' settings
				local s,e = pcall(function()
					for setting, _ in curSettings do
						if not baseSettings then continue end;
						if type(baseSettings[setting])=='nil' then
							table.insert(missingSettings, setting);
						end
					end
				end)
				
				if not s then
					RawPage.Items[1]:SetDescription('It appears there was an error\nchecking for missing settings.\n\nIs this the first launch\nof Redefine:A5?');
					warn(e)
					print(baseSettings);
					print(curSettings);
				else
					if #missingSettings > 0 then
						RawPage.Items[1]:SetDescription('The following settings are missing:\n\n' .. table.concat(missingSettings, '\n')..'\n\nYou will be forwarded to fix the missing settings.');
					else
						RawPage.Items[1]:SetDescription('There are no missing settings.');
					end

					script.Parent.LeftHalf.Buttons.Previous.Visible = true;
					script.Parent.LeftHalf.Buttons.Next.Visible = true;
					RawPage.Data.Variables.AlreadyChecked = true;
				end;
			end
		end,
		Variables = {
			AlreadyChecked = false;	
		};
	},

	{
		Index = 2;
		Items = {
			{
				Type = "Banner";
				Title = "Missing Settings";
				Description = "(Optional) You can set the missing settings here.";
				Color = Color3.fromRGB(0, 0, 0);
			},
		},
		OnOpen = function(RawPage)
			ProgressDots:SetDotStatus(2)
			script.Parent.LeftHalf.Buttons.Next.Visible = false;
			script.Parent.LeftHalf.Buttons.Previous.Visible = false;
			script.Parent.LeftHalf.Buttons.Close.Visible = false;

			if RawPage.Data.Variables.AlreadyChecked then
				script.Parent.LeftHalf.Buttons.Next.Visible = true;
				script.Parent.LeftHalf.Buttons.Previous.Visible = true;
				return;
			end;

			RawPage.Data.Variables.AlreadyChecked = true;

			

			local missingSettings = {};
			for setting, _ in pairs(curSettings) do
				if not baseSettings then continue end;
				if type(baseSettings[setting])=='nil' then
					table.insert(missingSettings, setting);
				end
			end

			if #missingSettings > 0 then
				for _, setting in missingSettings do
					if type(curSettings[setting])=='boolean' then
						local boolean = RawPage.Page:Boolean();
						boolean:SetTitle(setting);
						boolean:SetDescription("");
						boolean:SetValue(curSettings[setting]); -- set to default value
						boolean:SetCallback(function(val)
							baseSettings[setting] = boolean:GetValue();
							settingChanged = true;
						end);
					elseif type(curSettings[setting])=='string' or type(curSettings[setting])=='number' then
						local inputBox = RawPage.Page:InputBox();
						inputBox:SetTitle(setting);
						inputBox:SetValue(curSettings[setting])
						inputBox:SetNumeral(type(curSettings[setting])=='number');
						inputBox:SetCallback(function(val)
							baseSettings[setting] = inputBox:GetValue();
							settingChanged = true;
						end);
					else
						-- no support for other types yet!
						local textFrame = RawPage.Page:TextFrame();
						textFrame:SetTitle(setting);
						textFrame:SetDescription('The setting type for this setting is not supported yet.');
					end;
				end
			else
				local textFrame = RawPage.Page:TextFrame();
				textFrame:SetTitle('There are no missing settings.');
				textFrame:SetDescription('You can continue to the next step.');
			end

			script.Parent.LeftHalf.Buttons.Next.Visible = true;
			script.Parent.LeftHalf.Buttons.Previous.Visible = true;
		end;
		Variables = {
			AlreadyChecked = false;	
		};
	},

	{
		Index = 3;
		Items = {
			{
				Type = "Banner";
				Title = "Changelogs";
				Description = 'Catch up on stuff you missed!';
				Color = Color3.fromRGB(85, 170, 255);
			},
		},
		OnOpen = function(RawPage)
			ProgressDots:SetDotStatus(3)
			script.Parent.LeftHalf.Buttons.Next.Visible = false;
			script.Parent.LeftHalf.Buttons.Close.Visible = true;
			
			if settingChanged then
				script.Parent.LeftHalf.Buttons.Close.Text = 'Save';
			end

			if RawPage.Data.Variables.AlreadyChecked then return end;

			-- eek
			RawPage.Data.Variables.AlreadyChecked = true;

			local Changelogs = require(script.Changelogs);
			
			local ChangeLogCount = 0
			for Version,Build in Changelogs do
				if baseSettings['latestChangelog'] and baseSettings['latestChangelog'] < Version then
					local textFrame = RawPage.Page:TextFrame();
					textFrame:SetTitle(Build[1]);
					textFrame:SetDescription(Build[2]);
					ChangeLogCount = ChangeLogCount + 1
				end;
			end;
			if ChangeLogCount == 0 then
				local textFrame = RawPage.Page:TextFrame();
				textFrame:SetTitle("Nothing to catch up on");
				textFrame:SetDescription("You're all done!");
			end
			print(baseSettings, TrueParent);
			
			baseSettings.latestChangelog = tonumber(TrueParent:GetAttribute("nxversion"));
			TrueParent:SetAttribute('basesettings', Serializer.encode(baseSettings));
		end,
		Variables = {
			AlreadyChecked = false;	
		};
	}
}::{PageData}

for _, page:PageData in pagesData do
	local Parent = Instance.new("Frame")
	Parent.Size = UDim2.fromScale(1, 1)
	Parent.Position = UDim2.fromScale(page.Index ~= 0 and 1 or 0)
	Parent.Transparency = 1
	Parent.Name = "Page"..tostring(page.Index)
	Parent.Parent = script.Parent.LeftHalf.Content
	local Page = Framework.Page(Parent);
	local Items = {};
	for key, pageItem:PageItem in page.Items do
		if Page[pageItem.Type] and typeof(Page[pageItem.Type]) == "function" then
			if pageItem.Type == "Banner" then
				local banner = Page:Banner()
				if pageItem.Title then banner:SetTitle(pageItem.Title) end
				if pageItem.Description then banner:SetDescription(pageItem.Description) end
				if pageItem.Icon then banner:SetIcon(pageItem.Icon) else banner:SetIcon('') end
				if pageItem.Color then banner:SetColor(pageItem.Color) end
				Items[key] = banner
			elseif pageItem.Type == 'TextFrame' then
				local textFrame = Page:TextFrame()
				if pageItem.Title then textFrame:SetTitle(pageItem.Title) end
				if pageItem.Description then textFrame:SetDescription(pageItem.Description) end
				Items[key] = textFrame
			elseif pageItem.Type == "Boolean" then
				local boolean = Page:Boolean()
				if pageItem.Callback then boolean:SetCallback(pageItem.Callback) end
				if pageItem.Title then boolean:SetTitle(pageItem.Title) end
				if pageItem.Description then boolean:SetDescription(pageItem.Description) end
				if pageItem.DefaultValue and typeof(pageItem.DefaultValue) == "boolean" then print(pageItem.DefaultValue); boolean:SetValue(pageItem.DefaultValue) end
				Items[key] = boolean
			end
		else
			warn("\""..pageItem.Type.."\" is not a valid page item")
		end
	end
	Pages[page.Index] = {Page = Page, Items = Items, Data = page, Holder = Parent}
end
local debounce = true

local PageTS = TweenInfo.new(1, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
ProgressDots.TweenInfo = TweenInfo.new(1, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
script.Parent.LeftHalf.Buttons.Previous.MouseButton1Click:Connect(function()
	if not debounce then return end
	if Pages[PageIndex] then
		TS:Create(Pages[PageIndex].Holder, PageTS, {Position = UDim2.fromScale((Pages[PageIndex].Data.Index - PageIndex) + 1)}):Play()
	end
	if Pages[PageIndex - 1] then
		TS:Create(Pages[PageIndex - 1].Holder, PageTS, {Position = UDim2.fromScale(Pages[PageIndex].Data.Index - PageIndex)}):Play()
		if Pages[PageIndex - 1].Data.OnOpen and typeof(Pages[PageIndex - 1].Data.OnOpen) == "function" then
			Pages[PageIndex - 1].Data.OnOpen(Pages[PageIndex-1]);
		end
	end
	debounce = false
	task.delay(PageTS.Time, function()
		debounce = true
	end)
	PageIndex = PageIndex - 1
	if PageIndex == 0 then
		script.Parent.LeftHalf.Buttons.Previous.Visible = false
	end
	if PageIndex == (#Pages - 1) then
		script.Parent.LeftHalf.Buttons.Next.Visible = true
	end
end)
script.Parent.LeftHalf.Buttons.Next.MouseButton1Click:Connect(function()
	if not debounce then return end
	if Pages[PageIndex] then
		TS:Create(Pages[PageIndex].Holder, PageTS, {Position = UDim2.fromScale((Pages[PageIndex].Data.Index - PageIndex) - 1)}):Play()
	end
	if Pages[PageIndex + 1] then
		TS:Create(Pages[PageIndex + 1].Holder, PageTS, {Position = UDim2.fromScale(Pages[PageIndex].Data.Index - PageIndex)}):Play()
		if Pages[PageIndex + 1].Data.OnOpen and typeof(Pages[PageIndex + 1].Data.OnOpen) == "function" then
			Pages[PageIndex + 1].Data.OnOpen(Pages[PageIndex+1])
		end
	end
	debounce = false
	task.delay(PageTS.Time, function()
		debounce = true
	end)
	PageIndex = PageIndex + 1
	--if PageIndex == 1 then
	--	script.Parent.LeftHalf.Buttons.Previous.Visible = true
	--end
	--if PageIndex == #Pages then
	--	script.Parent.LeftHalf.Buttons.Next.Visible = false
	--end
end)
script.Parent.LeftHalf.Buttons.Close.MouseButton1Click:Once(function()
	-- Sends a remote event for the server to save the settings
	local remote:RemoteEvent = game:GetService("ReplicatedStorage"):WaitForChild("NxRemoteEvent");
	remote:FireServer('OnboardResponse', TrueParent:GetAttribute("basesettings"));
	
	-- close the UI
	TS:Create(TrueParent.Onboarding, PageTS , {Position = UDim2.fromScale(0.5, 3)}):Play();
	task.wait(5);
	TrueParent:Destroy();
end)

print(Pages)