--[[AtAltitude's Classic Datastore Module || Forked by 0bBinary for Sezei.me's uses.
--	EEDS / Even Easier DataStore

	API spec:
	
	DataCategory = Module(name)
		Returns a DataCategory to save data to and retrieve data from. The name can be any string (such as 
		"Leaderboard" or "Player Data")
	
	Task = DataCategory:Save(key,data)
		Asks the module to save the given data under the given key. It will return a 'Task' which contains 
		information and methods for the monitoring and control of the data saving process. Sending a new
		request while the old one is in progress will simply result in the old request being overridden.
	
	Task = DataCategory:Update(key,updateFunc)
		Asks the module to update the data under the given key according to the given function. This comes with
		a failsafe to prevent the overriding of previously saved data.
	
	Task = DataCategory:Load(key)
		Asks the module to retrieve the data stored under the given key. It will return a 'Task' which contains
		information and methods for the monitoring and control of the data retrieval process.	
		
	Task = DataCategory:Nullify(key) || DataCategory:Remove(key)
		Asks the module to nullify the key by setting the stored data to nil (using RemoveAsync).
	
	Task:wait()
		Waits until the task completes or is cancelled.
	
	Task:Cancel()
		Cancels the task.
	
	Task.Complete
		Says whether or not the task has been completed.
	
	Task.Attempts
		The amount of previous, failed attempts to complete the task.
	
	Task.NextTry
		Time in seconds before the next attempt
	
	Task.Type
		"Load" if the task is to retrieve data, "Save" if the task is to save data.
	
	Task.Data
		The data to be saved, or the data that was retrieved depending on the type of task.
	
	Task.Key
		The key the task is supposed to read/write.
		
	-- META TASKS --
	
	MetaTask = Task:Focus()
		Focuses on the singular task.
		
	MetaTask:Redo()
		Queue the task to be redone.
	
	MetaTask:Increment(n)
		Load Only.
		If the task data is a number, increments the data by data+n. If n is not added, then n = 1 by default.
		If the task data is NaN, the function errors.
		
	MetaTask:Decrement(n)
		Load Only.
		If the task data is a number, decrements the data by data-n. If n is not added, then n = 1 by default.
		If the task data is NaN, the function errors.
	
	Task = MetaTask.Task
		Returns the origin Task.
--]]

--Get important instances
local dataStoreSvc 	= game:GetService("DataStoreService")
local httpSvc = game:GetService("HttpService")
local datacache = {};

local disabled = false;
local privateserver = false;

-- Check if the game is running on a private server; Datastores will use a private version of itself, allowing VIP server sandboxing.
if (game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0) then -- Checks if the game is running on a private server.
	privateserver = game.PrivateServerOwnerId;
end

--Information storage
local categories 	= {}
local tasks 		= {}
local taskQueue 	= {}

--Making Nano env global after a single call
local api;

local olderror = error
local function error(debg,...)
	if game:GetService("RunService"):IsStudio() then
		print(debg)
	end

	return olderror(...)
end

--Module
function Module(name,env,...)
	table.insert(env.Data.Logs.System, {os.time(), "Datastore", "Listening to category "..name});
	if not api then api = env end;

	if privateserver then -- Sandbox the datastore to the private server's owner ID.
		name = name.."_Prv"..privateserver;
	end

	--Check if we've already done all the hard work, and if yes, just give them what we already have
	if (categories[name]) then return categories[name] end

	--Oh no, it looks like we haven't dealt with this yet
	if not datacache[name] then
		datacache[name] = {};
	end

	local DataCategory = {}
	DataCategory.Store = dataStoreSvc:GetDataStore(name)
	DataCategory.Name = name
	function DataCategory:Save(key,data)
		table.insert(env.Data.Logs.System, {os.time(), "Datastore", name.."; Saving to "..key});
		if type(key) ~= "string" then error(key,"Even Easier Datastore | Expected string, got "..type(key)) end
		--Overwrite old data so we don't waste precious requests
		if (tasks[key]) then tasks[key].Data = data return tasks[key] end

		local Task = {}
		Task.Complete = false
		Task.InProgress = false
		Task.Attempts = 0
		Task.NextTry = 0
		Task.Type = "Save"
		Task.Key = key
		Task.Category = self
		Task.Cancelled = false

		if type(data) == "table" then
			data = "_tbl:"..httpSvc:JSONEncode(data);
		end

		Task.Data = data

		function Task:wait() 
			repeat
				task.wait()
			until (self.Complete or self.Cancelled)
			return Task
		end
		function Task:Cancel() 
			self.Cancelled = true;
		end
		function Task:Focus()
			local MetaTask = {}

			MetaTask.Task = Task;

			function MetaTask:Redo()
				Task.Cancelled = false;
				Task.Complete = false;
				Task.InProgress = false;
				Task.Attempts = 0
				Task.NextTry = 0
				tasks[key] = Task --Store it so we don't do overlap work
				table.insert(taskQueue,Task) --Store it under a numerical value as well
				return Task
			end

			return MetaTask
		end

		tasks[key] = Task --Store it so we don't do overlap work
		table.insert(taskQueue,Task) --Store it under a numerical value as well
		return Task
	end

	function DataCategory:Update(key,updateFunc)
		table.insert(env.Data.Logs.System, {os.time(), "Datastore", name.."; Updating "..key});
		--Overwrite old data so we don't waste precious requests
		if (tasks[key]) then 
			if (tasks[key].Data == nil) then
				tasks[key].Data = {}
			end
			table.insert(tasks[key].Data,updateFunc)
			return tasks[key] 
		end

		local Task = {}
		Task.Complete = false
		Task.InProgress = false
		Task.Attempts = 0
		Task.NextTry = 0
		Task.Type = "Update"
		Task.Data = {updateFunc}
		Task.Key = key
		Task.Category = self
		Task.Cancelled = false

		function Task:wait() 
			repeat 
				task.wait() 
			until (self.Complete or self.Cancelled) 
			return Task
		end
		function Task:Cancel() 
			self.Cancelled = true 
		end
		function Task:Focus()
			local MetaTask = {}

			MetaTask.Task = Task;

			function MetaTask:Redo()
				Task.Cancelled = false;
				Task.Complete = false;
				Task.InProgress = false;
				Task.Attempts = 0
				Task.NextTry = 0
				tasks[key] = Task --Store it so we don't do overlap work
				table.insert(taskQueue,Task) --Store it under a numerical value as well
				return Task
			end

			return MetaTask
		end

		tasks[key] = Task --Store it so we don't do overlap work
		table.insert(taskQueue,Task) --Store it under a numerical value as well
		return Task
	end

	function DataCategory:Load(key)
		table.insert(env.Data.Logs.System, {os.time(), "Datastore", name.."; Loaded from "..key});
		if (tasks[key]) then return tasks[key] end

		local Task = {}
		Task.Complete = false
		Task.InProgress = false
		Task.Attempts = 0
		Task.NextTry = 0
		Task.Type = "Load"
		Task.Data = nil
		Task.Key = key
		Task.Category = self
		Task.Cancelled = false

		function Task:wait() 
			repeat 
				task.wait();
			until (self.Complete or self.Cancelled) 
			return Task
		end
		function Task:Cancel() 
			self.Cancelled = true 
		end
		function Task:Focus()
			local MetaTask = {}

			MetaTask.Task = Task;

			function MetaTask:Redo()
				Task.Cancelled = false;
				Task.Complete = false;
				Task.InProgress = false;
				Task.Attempts = 0
				Task.NextTry = 0
				tasks[key] = Task --Store it so we don't do overlap work
				table.insert(taskQueue,Task) --Store it under a numerical value as well
				return Task
			end

			function MetaTask:Increment(n)
				if type(Task.Data) == 'number' then
					Task.Data = Task.Data+n
					return Task.Data;
				else
					return nil;
				end
			end

			function MetaTask:Decrement(n)
				if type(Task.Data) == 'number' then
					Task.Data = Task.Data-n
					return Task.Data;
				else
					return nil;
				end
			end

			return MetaTask
		end

		tasks[key] = Task --Store it so we don't do overlap work
		table.insert(taskQueue,Task) --Store it under a numerical value as well
		return Task
	end

	function DataCategory:Nullify(key)
		table.insert(env.Data.Logs.System, {os.time(), "Datastore", name.."; Deleted "..key});
		--Overwrite old data so we don't waste precious requests
		if (tasks[key]) then tasks[key].Data = nil return tasks[key] end

		local Task = {}
		Task.Complete = false
		Task.InProgress = false
		Task.Attempts = 0
		Task.NextTry = 0
		Task.Type = "Nullify"
		Task.Data = nil
		Task.Key = key
		Task.Category = self
		Task.Cancelled = false

		function Task:wait() repeat task.wait() until (self.Complete or self.Cancelled) end
		function Task:Cancel() self.Cancelled = true; end
		function Task:Focus()
			local MetaTask = {}

			MetaTask.Task = Task;

			function MetaTask:Redo()
				Task.Cancelled = false;
				Task.Complete = false;
				Task.InProgress = false;
				Task.Attempts = 0
				Task.NextTry = 0
				tasks[key] = Task --Store it so we don't do overlap work
				table.insert(taskQueue,Task) --Store it under a numerical value as well
				return Task
			end

			return MetaTask
		end

		tasks[key] = Task --Store it so we don't do overlap work
		table.insert(taskQueue, tasks[key]) --Store it under a numerical value as well
		return Task
	end

	function DataCategory:Remove(key) -- Alias for Nullify
		table.insert(env.Data.Logs.System, {os.time(), "Datastore", name.."; Deleted "..key});
		--Overwrite old data so we don't waste precious requests
		if (tasks[key]) then tasks[key].Data = nil return tasks[key] end

		local Task = {}
		Task.Complete = false
		Task.InProgress = false
		Task.Attempts = 0
		Task.NextTry = 0
		Task.Type = "Nullify"
		Task.Data = nil
		Task.Key = key
		Task.Category = self
		Task.Cancelled = false

		function Task:wait() repeat task.wait() until (self.Complete or self.Cancelled) end
		function Task:Cancel() self.Cancelled = true; end
		function Task:Focus()
			local MetaTask = {}

			MetaTask.Task = Task;

			function MetaTask:Redo()
				Task.Cancelled = false;
				Task.Complete = false;
				Task.InProgress = false;
				Task.Attempts = 0
				Task.NextTry = 0
				tasks[key] = Task --Store it so we don't do overlap work
				table.insert(taskQueue,Task) --Store it under a numerical value as well
				return Task
			end

			return MetaTask
		end

		tasks[key] = Task --Store it so we don't do overlap work
		table.insert(taskQueue, tasks[key]) --Store it under a numerical value as well
		return Task
	end

	categories[name] = DataCategory --Make sure we don't have to do all that again
	return DataCategory --Tell them that we're done and give them the result
end

--Creating new threads is usually bad practice, but in our case we want the module to continuously read
--the information we give it and attempt to do what we want it to.
task.spawn(function()
	while true do
		task.wait(0.05)
		if (#taskQueue > 0) then
			local Task = taskQueue[1]

			if (not Task.Complete and not Task.InProgress) then
				--Wait until we're supposed to execute the task (and yes, this blocks all following tasks too)
				--No point in making more requests when one is failing.
				--[[print("Now handling task of type " 
					.. Task.Type .. " on key " 
					.. Task.Key .. "; Next try in " 
					.. Task.NextTry .. " seconds.")]]

				repeat
					task.wait(0.1)
					Task.NextTry = Task.NextTry - 0.1
				until Task.NextTry < 0

				--print("Wait time complete, attempting to execute task...")

				--Saving, updating and loading unfortunately yields, so we're creating another thread here.
				task.spawn(function()
					--Store the information elsewhere so we can tell if there have been more requests to save to
					--the same key
					local data = Task.Data
					Task.Data = nil

					--Make sure we don't do overlap work (debounce)
					Task.InProgress = true

					--Attempt to save/load the information and see if it was successful
					local ok,err;
					if not api.Data.Settings.DisableDS then
						ok,err = pcall(function()
							if (Task.Type == "Save") then
								if not data then return end
								if datacache[Task.Category.Name][Task.Key] == data then warn("Even Easier Datastore | " .. Task.Key.." - Unnecessary save request!"); return end;
								if not disabled then
									Task.Category.Store:SetAsync(Task.Key,data) -- Save in here too just in-case the API will go down. - It'll destroy the Sync tho.
								end
								datacache[Task.Category.Name][Task.Key] = data;
							elseif (Task.Type == "Nullify") then
								if not disabled then
									Task.Category.Store:RemoveAsync(Task.Key)
								end

								datacache[Task.Category.Name][Task.Key] = nil;
							elseif (Task.Type == "Update") then
								--Rather than making tons of requests to the datastore, we cumulate the modifier functions here
								--and only request with the result
								if datacache[Task.Category.Name][Task.Key] == data then warn("Even Easier Datastore | " .. Task.Key.." - Unnecessary update request!"); return end;
								local function func(variant)
									for _,f in pairs(data) do variant = f(variant) end
									return variant
								end
								if not disabled then
									Task.Category.Store:UpdateAsync(Task.Key,func)
								end
								datacache[Task.Category.Name][Task.Key] = data;
							else
								if datacache[Task.Category.Name][Task.Key] then
									Task.Data = datacache[Task.Category.Name][Task.Key]
								else
									local dat = Task.Category.Store:GetAsync(Task.Key)
									if type(dat) == "string" and string.sub(dat,1,5) == "_tbl:" then
										Task.Data = httpSvc:JSONDecode(string.sub(dat,6));
									else
										Task.Data = dat
									end
								end
							end
						end)
					else
						ok = true;
					end

					if (ok) then
						--If it was a success, we can call it done and remove it from the queue.
						Task.Complete = true
						table.remove(taskQueue,1)
						tasks[Task.Key] = nil

						--Oh, but wait! If we tried pushing more data while the datastore was busy, we may want to
						--redo this so we have the latest info.
						if (Task.Type ~= "Load") then
							if (Task.Data ~= nil) then
								--Yeah, can't quite exit yet, sorry. But we'll give you an update so you don't feel left alone!
								Task.Complete = false
								--print("Saving to key '" .. Task.Key .. "' succeeded but will be repeated")

								--Not quite done yet, but add it to the end of the queue
								table.insert(taskQueue,Task)
								tasks[Task.Key] = Task
							else
								--We want this to be the original value 
								Task.Data = data
							end
						end
						--[[print("Task of type "  -- debug
							.. Task.Type .. " on key " 
							.. Task.Key .. " succeeded.")]]
					else
						--Check if we're running on Studio and attempting to update/save; if so, warn user that this may be the reason we failed
						if (Task.Type ~= "Load" and game:GetService("RunService"):IsStudio()) then
							warn("DataStore save/update failed in a Studio session. Is API access to DataStores enabled?")
						end
						warn("Even Easier Datastore | An error has occured with the datastores: "..err)

						--Looks like it failed. We'll take a note of that and retry again later.
						Task.Attempts = Task.Attempts + 1
						Task.NextTry = math.min(math.pow(2,Task.Attempts-1),5)

						if Task.Attempts == 3 then -- Auto-cancel after 3 attempts; Notify the user.
							Task.Cancelled = true
							warn("Even Easier Datastore | Cancelled attempt to "..Task.Type.." key \""..Task.Key.."\" due to failing 3 times.");
						end

						--Also, we'll tell you so you know what's happening.
						--print("Even Easier Datastore | Saving to key '" .. Task.Key .. "' failed with error: \"" .. err .. "\", retrying in " .. Task.NextTry .. " seconds")
						Task.Data = data
					end

					--Debounce again
					Task.InProgress = false
				end)
			else
				--If the task was cancelled, get rid of it.
				table.remove(taskQueue,1)
				tasks[Task.Key] = nil
			end
		end
	end
end)

return Module
