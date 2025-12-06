local MessagingService = game:GetService("MessagingService")
local Listeners = {}  -- Maps topics to an array of callbacks

local function addListener(topic, callback)
	if not Listeners[topic] then
		Listeners[topic] = {}
	end
	table.insert(Listeners[topic], callback)
end

local function removeListener(topic, callback)
	if not Listeners[topic] then return end
	for i, cb in ipairs(Listeners[topic]) do
		if cb == callback then
			table.remove(Listeners[topic], i)
			break
		end
	end
	if #Listeners[topic] == 0 then
		Listeners[topic] = nil
	end
end

local function clearListeners(topic)
	Listeners[topic] = nil
end

local module = {}
module.__index = module

function module.new(topic)
	local self = setmetatable({
		Topic = topic,
	}, module)
	return self
end

function module:Push(data, compatibility)
	local payload
	if compatibility then
		-- In compatibility mode, 'data' is the topic and 'compatibility' is the message data.
		payload = {Topic = data, Data = compatibility}
	else
		payload = {Topic = self.Topic, Data = data}
	end
	local success, err = pcall(function()
		MessagingService:PublishAsync("RedefineA5", payload)
	end)
	if not success then
		warn("PublishAsync failed: " .. tostring(err))
	end
end

function module:Publish(topic, data)
	local payload = {Topic = topic, Data = data}
	local success, err = pcall(function()
		MessagingService:PublishAsync("RedefineA5", payload)
	end)
	if not success then
		warn("PublishAsync failed: " .. tostring(err))
	end
end

function module:Listen(callback, compatibility)
	-- Compatibility mode: if a topic is passed as the second argument, use that.
	local topic = compatibility or self.Topic
	addListener(topic, callback)
end

function module:Subscribe(topic, callback)
	addListener(topic, callback)
end

function module:Unlisten()
	clearListeners(self.Topic)
end

function module:Unsubscribe(topic)
	clearListeners(topic)
end

-- Unique functions

function module:Once(callback)
	-- Create a wrapper that removes itself after being called.
	local function wrapper(data)
		local ok, err = pcall(callback, data)
		if not ok then
			warn("Once callback error: " .. tostring(err))
		end
		removeListener(self.Topic, wrapper)
	end
	addListener(self.Topic, wrapper)
end

function module:Promise()
	local result = {Complete = false, Data = nil}
	local function wrapper(data)
		result.Complete = true
		result.Data = data
		removeListener(self.Topic, wrapper)
	end
	addListener(self.Topic, wrapper)
	return result
end

function module:Wait()
	local result = {Complete = false, Data = nil}
	local function wrapper(data)
		result.Complete = true
		result.Data = data
		removeListener(self.Topic, wrapper)
	end
	addListener(self.Topic, wrapper)
	repeat task.wait() until result.Complete
	return result.Data
end

MessagingService:SubscribeAsync("RedefineA5", function(message)
	local payload = message.Data
	-- Validate payload structure.
	if type(payload) ~= "table" then
		warn("Received payload is not a table")
		return
	end
	local topic = payload.Topic
	local data = payload.Data

	print("[MS] received", typeof(payload), payload and topic)

	if not topic then
		warn("Received payload missing topic")
		return
	end

	if not Listeners[topic] then
		warn("Got topic with no listeners:", topic)
		return
	end

	-- Iterate over a shallow copy to allow removal during iteration.
	local callbacks = {}
	if Listeners[topic] then
		for _, callback in (Listeners[topic]) do
			table.insert(callbacks, callback)
		end
	end

	-- Call each listener safely.
	for _, callback in (callbacks) do
		local ok, err = pcall(callback, data)
		if not ok then
			warn("Listener callback error: " .. tostring(err))
		end
	end
end)

-- Subscribe to the common MessagingService topic.
local success, subscription = pcall(function()
	return true
end)
if not success then
	warn("SubscribeAsync failed: " .. tostring(subscription))
end

return module
