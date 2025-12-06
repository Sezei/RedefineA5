--[[
	This is a base for RA plugins to extend with for example you make a plugin in the plugins folder
	it can be defined as you wished and will automatically extend this ""class"" (if you can even call it one)
]]

local HttpService = game:GetService("HttpService")

local plugin = {
	Name = "RA:5 PluginBase",
	Description = "No description provided.",
	Options = {}
}

function plugin:Setup(env)
	warn("[REDEFINE A:5 PLUGIN] Please add a Setup function to your plugin to remove this warning")
end

function plugin:AddOption(id:string, name:string, description:string, defaultValue:any, type:string)
	plugin.Options[id] = {
		Name = name,
		Description = description or "No description provided",
		Type = type or "Boolean",
		DefaultValue = defaultValue
	}
	return self
end

function plugin:SetName(newName:string)
	self.Name = newName
	return self
end

function plugin:SetDescription(newName:string)
	self.Description = newName
	return self
end

function plugin:Serialize()
	local data = {}

	for k, v in (self) do
		local valueType = typeof(v)
		if valueType ~= "function" and valueType ~= "RBXScriptSignal" and valueType ~= "Instance" then
			data[k] = v
		end
	end

	return HttpService:JSONEncode(data)
end

return plugin