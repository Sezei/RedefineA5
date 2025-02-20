return {
	-- Set this to true if you don't want people to use the command temporarily.
	Disabled = false;

	-- Main variables.
	Name = "Template"; -- The name of the command; Displayed in !commandslist.
	Description = "A Template Command."; -- The description of the command.
	Arguments = {
		--[[
		{
			Name = "Victim"; -- When creating the code, you can use Arguments.Victim for this specific node.
			Type = "Player";
			Required = true;
		};
		{
			Name = "PunishmentType";
			Type = "String";
			Required = true;
			Options = {
				-- Which punishment do you want to give the player?
				"Ban";
				"Mute";
			};
		};
		{
			Name = "Length";
			Type = "Number";
			Required = false;
			Minimum = 0;
			Maximum = math.huge
		};
		
		-- There are more types other than the ones mentioned here, so feel free to look into the RunCommand module-
		-- -for more of these types.
		]]	
	}; -- Which arguments are expected.
	Keys = { 

	};
	Level = 0; -- Minimum admin level to execute the command.
	AbuseValue = 0; -- Adds 'abuse score' to the player when the command is ran.
	Aliases = {}; -- Alternative ways to call the command.

	-- Secondary variables.
	Credits = {}; -- Who made the command? (UserIds)
	Visible = true; -- Is the command visible for those who can't use it?
	Cooldown = 0; -- Global Command Cooldown (Delay between the command being used by any user)
	UserCooldown = 0; -- User Cooldown (Delay between the command being used by a single user)
	Dependencies = {}; -- Dependencies are env variables that are required to be present for the command to run; Example; {GetLevel = true} will require the env variable GetLevel (env.GetLevel) to be present
	Destructive = false; -- Destructive commands will require the user to acknowledge that the command can cause issues
	
	-- Quick Actions Menu stuff
	QuickActions = {
		Tab = {
			Title = 'Template API';
			Description = 'This is a test of the API for the Quick Actions menu from the template command.';
			Locked = false;
			Color = Color3.new(0,0,0);
		};
		Buttons = {
			Structuring = function(API)
				local Button = API:Button("Show Commands");
				Button.MouseButton1Click:Connect(function()
					API:RunCommand('commandslist');
				end);
			end;
			Updates = {
				{
					game:GetService("Players").PlayerAdded;
					function(API, Player)
						local Button = API:AddPlayerButton(Player, 'smite @'..Player.Name);
						Button.MouseButton1Click:Connect(function()
							API:RunCommand('smite @'..Player.Name);
						end);
					end
				};
			};
		};
	};
	
	-- Checks who can run the command; Use @env and @Player to determine if the player has the ability to run it.
	RunCapability = function(env, Player) -- Checks if the users can even run the command in the first place. Return true to allow. (Replaces Level)
		-- This function replaces the Level value; Use this to determine if the player can run this command.
		return true; -- Must return true or false.
	end;

	-- Runs this code when the module loads.
	OnLoad = function(env)
		-- You can use this to add functions to the environment.
	end;
	
	-- This runs on the CLIENT SIDE of the players.
	OnClientLoad = function(clientEnv, levelMatches)
		-- Don't *fully* trust the client to always return 'levelMatches' accurately.
		-- It is an unprotected check to load stuff on the client-side.
	end;

	-- Runs this code when the player executes the command.
	OnRun = function(env, Executor, Arguments, Keys)
		return {
			Success = true;
			Message = env.format("Hello <player_name>, thank you for checking out Redefine:A 5!",{},Executor)
		}
	end;
	
	OnClientRun = function(clientEnv, Arguments, Keys)
		-- Assume that Executor == game.Players.LocalPlayer. Alternatively you can get clientEnv.Player.
		-- Again; it is unprotected - only run this if you need commands to run on the client-side.
		
		clientEnv.CreateNotification(`Hi {clientEnv.Player.Name}, thank you for checking out Redefine:A 5! This is a Client-Side notification!`);
	end;
}