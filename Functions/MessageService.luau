-- This module will act as a wrapper for MessagingService, and will allow for easier use of it all while using only a single topic rather than individually listening to each topic.

local MessagingService = game:GetService("MessagingService");

Listeners = {};

local module = {};

function module.new(topic)
	local self = setmetatable({
		Topic = topic;
	}, module);
	return self;
end;

function module:Push(data,compatibility) -- If compatibility mode is required (old versions of the code might use it), we use Data as the topic.
	if compatibility then
		MessagingService:PublishAsync('RedefineA5',{Topic=data,Data=compatibility});
	else
		MessagingService:PublishAsync('RedefineA5',{Topic=self.Topic,Data=data});
	end;
end;

function module:Publish(topic, data) -- Alias for Push, but for any topic
	MessagingService:PublishAsync('RedefineA5',{Topic=topic,Data=data});
end;

function module:Listen(callback,compatibility) -- Primarily unnecessary since by creating a new topic, you're already listening to it; there's just no function to call the callback.
	if compatibility then -- Compatibility for older code; Deprecated tho so use module.new(Topic) instead ;p
		Listeners[callback] = compatibility;
	else
		Listeners[self.Topic] = callback;
	end;
end;

function module:Subscribe(topic, data) -- Alias for Listen, but for any topic
	Listeners[topic] = data;
end;

function module:Unlisten()
	Listeners[self.Topic] = nil;
end;

function module:Unsubscribe(topic) -- Alias for Unlisten, but for any topic
	Listeners[topic] = nil;
end;

-- Unique functions
function module:Once(callback)
	local Listener = true;
	Listeners[self.Topic] = function(data)
		callback(data);
		Listeners[self.Topic] = nil;
	end;
end;

function module:Promise()
	local Listener = true;
	local Data = {Complete = false; Data = nil;};
	Listeners[self.Topic] = function(data)
		Data = {Complete = true; Data = data;};
		Listeners[self.Topic] = nil;
	end;
	return Data;
end;

function module:Wait()
	local Listener = true;
	local Data = {Complete = false; Data = nil;};
	Listeners[self.Topic] = function(data)
		Data = {Complete = true; Data = data;};
		Listeners[self.Topic] = nil;
	end;
	repeat task.wait() until Data.Complete;
	return Data.Data;
end;

MessagingService:SubscribeAsync('RedefineA5',function(data)
	if Listeners[data.Topic] then
		Listeners[data.Topic](data.Data);
	end
end);