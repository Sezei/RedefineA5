-- This module will act as a wrapper for MessagingService, and will allow for easier use of it all while using only a single topic rather than individually listening to each topic.

local MessagingService = game:GetService("MessagingService");
local Listeners = {};

local module = {};
module.__index = module;

function module.new(topic)
	local self = setmetatable({
		Topic = topic;
	}, module);
	return self;
end;

function module:Push(data, compatibility)
	if compatibility then
		-- In compatibility mode, 'data' is the topic and 'compatibility' is the message data.
		MessagingService:PublishAsync('RedefineA5', {Topic = data, Data = compatibility});
	else
		MessagingService:PublishAsync('RedefineA5', {Topic = self.Topic, Data = data});
	end;
end

function module:Publish(topic, data)
	MessagingService:PublishAsync('RedefineA5', {Topic = topic, Data = data});
end;

function module:Listen(callback, compatibility)
	if compatibility then
		-- Compatibility mode: first argument is the topic, second is the callback.
		Listeners[compatibility] = callback;
	else
		Listeners[self.Topic] = callback;
	end;
end;

function module:Subscribe(topic, callback)
	Listeners[topic] = callback;
end;

function module:Unlisten()
	Listeners[self.Topic] = nil;
end;

function module:Unsubscribe(topic)
	Listeners[topic] = nil;
end;

-- Unique functions
function module:Once(callback)
	Listeners[self.Topic] = function(data)
		callback(data);
		Listeners[self.Topic] = nil;
	end;
end;

function module:Promise()
	local result = {Complete = false, Data = nil};
	Listeners[self.Topic] = function(data)
		result.Complete = true;
		result.Data = data;
		Listeners[self.Topic] = nil;
	end;
	return result;
end;

function module:Wait()
	local result = {Complete = false, Data = nil};
	Listeners[self.Topic] = function(data)
		result.Complete = true;
		result.Data = data;
		Listeners[self.Topic] = nil;
	end;
	repeat task.wait() until result.Complete;
	return result.Data;
end

MessagingService:SubscribeAsync('RedefineA5', function(message)
	local topic = message.Topic;
	local data = message.Data;
	if Listeners[topic] then
		Listeners[topic](data);
	end;
end);

return module;