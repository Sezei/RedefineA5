--!strict
-- Discord embed builder for Roblox using OOP
-- idk i was bored and wanted an easy way to make embeds
local HttpService = game:GetService("HttpService");


local function GetUrlFromId(RobloxId:number):string|nil
	if not RobloxId or typeof(RobloxId)~='number' then return nil end;

	local s,Returning = pcall(function()
		local Result = HttpService:GetAsync('https://thumbnails.roproxy.com/v1/assets?assetIds='..RobloxId..'&size=420x420&format=Png');
		local Decoded = HttpService:JSONDecode(Result);

		if Decoded.data[1] then
			return Decoded.data[1].imageUrl;
		else
			return nil;
		end;
	end)

	return (s and Returning) or nil;
end

local Module = {}

function Module.new()
	local self = {}
	setmetatable(self, {__index = Module});
	self.Title = nil;
	self.Description = nil;
	self.Color = nil;
	self.Fields = {};
	self.Footer = nil;
	self.Image = nil;
	self.Thumbnail = nil;
	self.Author = nil;
	self.Timestamp = nil;
	return self;
end;

function Module:SetTitle(Title:string)
	self.Title = Title;
	return self;
end;

function Module:SetDescription(Description:string)
	self.Description = Description;
	return self;
end;

function Module:SetColor(Color:Color3)
	self.Color = math.floor(Color.R * 0xFF0000) + math.floor(Color.G * 0xFF00) + math.floor(Color.B * 0xFF);
	return self;
end;

function Module:AddField(Name:string, Value:string, Inline:boolean?)
	table.insert(self.Fields, {name = Name, value = Value, inline = Inline or false});
	return self;
end;

function Module:SetImage(RobloxId:number) -- the only issue here is that we need to make it work with Roblox images.. damn.
	self.Image = {url = GetUrlFromId(RobloxId)};
	return self;
end;

function Module:SetCustomImage(URL:string)
	self.Image = {url = URL};
	return self;
end

function Module:SetThumbnail(RobloxId:number)
	self.Thumbnail = {url = GetUrlFromId(RobloxId)};
	return self;
end;

function Module:SetCustomThumbnail(URL:string)
	self.Thumbnail = {url = URL};
	return self;
end;

function Module:SetFooter(Text, RobloxId:number)
	self.Footer = {text = Text, icon_url = GetUrlFromId(RobloxId)};
	return self;
end;

function Module:SetAuthor(Name, RobloxId:number)
	self.Author = {name = Name, icon_url = GetUrlFromId(RobloxId)};
	return self;
end;

function Module:SetTimestamp()
	self.Timestamp = os.date("!%Y-%m-%dT%H:%M:%S");
	return self;
end;

function Module:BuildMessage(OptionalContent:string?)
	local Data = {
		content = OptionalContent or '',
		embeds = {
			{
				title = self.Title,
				description = self.Description,
				color = self.Color,
				fields = self.Fields,
				footer = self.Footer,
				image = self.Image,
				thumbnail = self.Thumbnail,
				author = self.Author,
				timestamp = self.Timestamp
			}
		}
	}
	return Data;
end;

return Module;