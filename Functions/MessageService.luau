-- This module will act as a wrapper for MessagingService, and will allow for easier use of it all while using only a single topic rather than individually listening to each topic.

local MessagingService = game:GetService("MessagingService");

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
    local listener = MessagingService:SubscribeAsync("RedefineA5",function(data)
        if data.Topic == topic then
            callback(data.Data);
        end
    end);
    table.insert(self.Listeners,listener);
    return listener;
end;

function module:Subscribe(topic,callback) -- Alias for Listen
    return self:Listen(topic,callback);
end;

function module:Unlisten(listener)
    for i,v in ipairs(self.Listeners) do
        if v == listener then
            table.remove(self.Listeners,i);
            listener:Disconnect();
            break;
        end
    end
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

return module;