-- This module will act as a wrapper for MessagingService, and will allow for easier use of it all while using only a single topic rather than individually listening to each topic.

local MessagingService = game:GetService("MessagingService");

local function CreateUID()
	local UID = "";
	for _ = 1, 24 do
		UID = UID .. string.char(math.random(65, 90));
	end
	return UID;
end

local module = {
	Topics = {};
	Listeners = {};
};

function module:Push(topic,data)
	MessagingService:PublishAsync("RedefineA5",{Topic = topic,Data = data});
end;

function module:Publish(topic,data) -- Alias for Push
	self:Push(topic,data);
end;

function module:Listen(topic,callback)
	local listener = {
        Topic = topic;
        Callback = callback;
        ID = CreateUID();
    };
    
    table.insert(self.Listeners, listener);

    return listener;
end;

function module:Subscribe(topic,callback) -- Alias for Listen
	return self:Listen(topic,callback);
end;

function module:Unlisten(listener)
	for i,v in ipairs(self.Listeners) do
        if v.ID == listener.ID then
            table.remove(self.Listeners,i);
        end;
    end;
end;

function module:Unsubscribe(listener) -- Alias for Unlisten
	self:Unlisten(listener);
end;

-- Unique functions
function module:Once(topic,callback)
	local listener;
	listener = self:Listen(topic,function(data)
		callback(data);
		self:Unlisten(listener);
	end);
end;

function module:Wait(topic,callback)
	local listener;
	local data;
	listener = self:Listen(topic,function(d)
		data = d;
		self:Unlisten(listener);
	end);

	repeat task.wait() until data;
	callback(data);
	return data;
end;

MessagingService:SubscribeAsync("RedefineA5",function(data)
    for _,v in ipairs(module.Listeners) do
        if v.Topic == data.Data.Topic then
            v.Callback(data.Data.Data);
        end
    end
end);

return module;