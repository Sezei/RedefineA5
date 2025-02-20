return function(env, CompiledData, Module)
	-- WE HAD OVER A YEAR TO NOTICE THAT COMMAND.DISABLED ISN'T EVEN BEING READ 😭😭😭😭😭😭
	if CompiledData.Disabled then
		return;
	end
	
	if not Module then Module = {Name = CompiledData.Name} end;
	local sanity = env:CommandSC(CompiledData, Module) :: boolean;
	local load = true;

	-- Sanity check the returned command data
	if not sanity then
		table.insert(env.Data.Logs.Errors,{os.time(),"Command Sanity Check Failed: "..Module.Name});
		load = false;
		return;
	end

	-- Check the dependencies
	if CompiledData.Dependencies then
		for _,dependency in CompiledData.Dependencies do
			if not env[dependency] then
				warn('Redefine:A | Command "'..Module.Name..'" has a dependency on "'..dependency..'" which does not exist in the environment.');
				table.insert(env.Data.Logs.Errors,{os.time(),"Command Dependency Check: "..Module.Name..' is "'..dependency..'" and refused to load.'});
				load = false;
				return;
			end
		end
	end;
	
	-- Check the dependencies
	if CompiledData.SoftDependencies then
		for _,dependency in CompiledData.SoftDependencies do
			if not env[dependency] then
				print('Redefine:A | Command "'..Module.Name..'" has a soft dependency on "'..dependency..'" which does not exist in the environment; Continuing load.');
				table.insert(env.Data.Logs.Errors,{os.time(),"Soft Command Dependency Check: "..Module.Name..' is missing "'..dependency..'"'});
			end
		end
	end;

	if env.Commands[string.lower(CompiledData.Name)] then
		if env.Commands[string.lower(CompiledData.Name)].DisallowOverwrite then
			warn('Redefine:A | Command "'..CompiledData.Name..'" has overwrite protection and cannot be overwritten; Skipping...');
			load = false;
			return;
		else
			print('Redefine:A | Command "'..CompiledData.Name..'" is being overwritten!')
		end
	end
	if not (type(env.Commands) == "table") then env.Commands = {} end

	if load then
		-- There is a CompiledData.OnLoad?
		if type(CompiledData.OnLoad) == "function" then
			local success, err = pcall(function()
				CompiledData.OnLoad(env)
			end)

			if not success then
				warn('Redefine:A | Failed to load command: '..CompiledData.Name..'; because of a load error "'..err..'"');
				return;
			end
		end

		env.Commands[string.lower(CompiledData.Name)] = CompiledData;

		-- Add the credits
		if not (type(env.Data.Credits) == "table") then env.Data.Credits = {} end
		for _,v in pairs(CompiledData.Credits) do
			if not env.Data.Credits[v] then
				env.Data.Credits[v] = true;
			end
		end

		-- Add the aliases
		for _,Module in CompiledData.Aliases do
			env.Aliases[string.lower(Module)] = CompiledData;
		end
	end

	env.Signals.CommandRegistered:Fire(CompiledData);
end