# todo: update the documentation here lol

## Commands in R:A5
Commands in Redefine:A 5 are way different than what they were in Redefine:A 4. In fact, they are more similar to [Nano](https://devforum.roblox.com/t/nano-the-non-intrusive-admin-panel/1734987)'s commands than anything.

This is mainly because I wanted to make creating commands easier for developers, and I think having it like a type-system based command system is the best way to do it.


## Creating the command
References for this part;
```lua
Command --> The returned command table of which you build the command with.
Argument --> A table in Command.Arguments that defines the argument.
```

To create a command, you must first create a new module script in the `Commands` folder. The name of the module script does not affect the command name. The command name is defined in the module script itself under Command.Name.

The best way to create the command is to use the template below;
```lua
return {
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
}
```

```diff
! Note: After Build 103, the command handler has changed to use the new env:RegisterCommand function, which allows you to use the command handler without having to create modules for every command.
! This can be used to make multiple commands within the same module, and is recommended for when you want to make commands that are used for the same thing such as un-something.
```

Let's start this from the beginning;

`Disabled` -> When set to true, the command will not load. This is useful for when you want to temporarily disable a command without having to delete it entirely.

`Name` -> The name of the command. This is what you type in the command bar to execute the command. This is also what is displayed in the `!commandslist` command as the first thing before you see the description / aliases.

`Description` -> The description of the command. This is what is displayed in the `!commandslist` command as the second thing before you see the aliases, and what is displayed in the commandbar when you type the command without any arguments.

`Arguments` -> The arguments of the command. This is what builds the command and makes it work. This is a table of Argument tables, but can also be a string of `"rawinput"` that will make the command fully under your own control. However, enabling rawinput will disable the command from having any typing, hence will make highlighting and other R:A5-specific features not work. We will return to this specific topic later.

`Keys` -> This is what we use to change the functionality of the command. This table makes it so everything we type into the command can be easily changed. For example, `!goto [Name] --silent` will not spawn a log in the players' place, because it has a Keys.silent listener. We will return to this topic later as well.

`Level` -> The minimum admin level required to execute the command. This number is required to be in the command, even if you use `RunCapability`, otherwise the CommandSanityCheck may flag the command as being invalid if it's older than Build 89.

`AbuseValue` -> The amount of abuse score the command adds to the player when it's ran. This is used to determine if the player is abusing the command or not. This is also used to determine if the player is abusing the command or not; Currently, AbuseScore is not used for anything, but may be used in the future for something and/or let the game developer decide what to do with it.

`Aliases` -> Alternative ways to call the command. This is a table of strings, and can be empty. It is displayed in `!commandslist`, and can be used to call the command instead of the main name.

`Credits` -> Who made the command? This is a table of UserIds, and the creators will be displayed in `!about`. This is not required, but is recommended if you want to insert yourself into the credits.

`Visible` -> Is the command visible for those who can't use it? This is a boolean value, and is set to false by default. If set to true, the command will be visible in `!commandslist` even for those who can't use it. (Assuming they haven't used `!commandslist --all`).

`Cooldown` -> Global Command Cooldown. This is a number, and is set to 0 by default. This is the delay between the command being used by any user. This is useful for commands that can be abused, such as `!kickall`, `!banall`, etc.

`UserCooldown` -> User Cooldown. This is a number, and is set to 0 by default. This is the delay between the command being used by the same user. This is useful for commands that can be abused, such as `!kick`, `!ban`, etc.

`Color` -> Custom Color3 value for when using the Commandbar. This is a Color3 value, and is set to nil by default. This does not provide any use, but can help make your command stand out when using the Commandbar.

`Destructive` -> Is the command destructive? This is a boolean value, and is set to false by default. This is used to warn the user before executing the command, and is useful for commands that can cause issues in the game, and might, inadvertedly, cause the game to sequence break if one exists.

`Dependencies` -> Dependencies are env variables that are required to be present for the command to run. This is a table of strings, and is set to an empty table by default. Example; `{"GetLevel"}` will require the env variable `GetLevel` (env.GetLevel) to be present for the command to run. This is useful for when you want to make a command that requires a specific env variable to be present, such as `GetLevel`, `GetRank`, etc.

`RunCapability` -> Replaces the level check. Instead of checking for `env:GetLevel(Player)`, it checks for `RunCapability(env, Player)`. This can be used to let only specific players use the command despite their level, or to make the command only usable in specific situations.

`OnLoad` -> Runs this code when the module loads. This is useful for when you want to get stuff into the env when the command loads, and get stuff like the signals that are NOT visible outside of the closed environment of R:A.

`OnRun` -> Runs this code when the player executes the command.


## Creating the arguments
References for this part;
```lua
Command --> The returned command table of which you build the command with.
Argument --> A table in Command.Arguments that defines the argument.
Typing --> Argument.Type
```

Arguments are the most important part of the command. They are what makes the command work on different people, and what defines the command's functionality.
That's also how `!kick all` gets the `all` part, and how `!goto [Name]` gets the `[Name]` part.

To create an argument, you must first create a new table in the `Arguments` table of the command. The name of the table does not affect the argument name. The argument name is defined in the table itself under Argument.Name.

Example;
```lua
Command = {
    ...
    Arguments = {
        { -- This is the first argument that will be used
            Name:string; -- The name of the argument; Displayed in !commandslist, as well as within the OnRun function itself.
            Type:string; -- The type of the argument; This is what defines the argument's functionality. See types below.
            Required:boolean; -- Is the argument required? If set to false, the argument will be optional.
            ... -- Other variables that are specific to the argument type.
        };
    };
    ...
}
```

Let's, again, start it from the beginning;

`Name` -> The name of the argument. This will be used in the OnLoad function as Arguments.Name.

`Type` -> The type of the argument. This is what defines the argument's functionality. See types below.

`Required` -> Whether this argument is required or not. When it is not required, you must add a `Default` argument unless you use `Player`-based arguments.

`...` -> Other variables that are specific to the argument type. See types below.


### Types
Types are what defines the argument's type.
There are a lot of types with Redefine:A5, so we will go through them one by one.

`string` / `rawinput`
```lua
{
    Name = "String";
    Type = "string";
    Required = false;
    Default = "";
    Options = {"full", "another"} | function(progress:string) return full:string end;
}

Arguments.String => "string" / (typeof(Arguments.String) == "string")
```

String is one of the basic argument type. It is used to get a string from the user, and is the default argument type if you don't specify one.
It can be literally anything the player writes, meaning filtering must be done by the command developer.

Options can either be a table of auto-complete strings, or a function that returns a completed string from what the player has typed. This is extremely useful for when you want to make a command that has options, but don't want to make the player guess what the options are.

RawInput will return the string as well, unedited, but will also warn the user that the command is using rawinput.

`number`
```lua
{
    Name = "Number";
    Type = "number";
    Required = false;
    Default = 0;
    Minimum = 0;
    Maximum = 100;
}

Arguments.Number => 0 / (typeof(Arguments.Number) == "number")
```

Number, like string, is one of the basic argument types. It is used to get a number from the user.

Minimum and Maximum are used to limit the number the player can type. This is useful for when you want to make a command that has a limit, such as `!speed [Player] [Number]`, where the speed can't be higher than 100.

`boolean`
```lua
{
    Name = "Boolean";
    Type = "boolean";
    Required = false;
    Default = false;
}

Arguments.Boolean => false / (typeof(Arguments.Boolean) == "boolean")
```

Boolean is, again, one of the basic argument types. It is used to get a boolean value (true/false) from the user.

It does not require any additional arguments, and is used for when you want to make a command that has a true/false option.

`player` / `safeplayer`
```lua
{
    Name = "Player";
    Type = "player";
    Required = false;
    Default = nil;
}

Arguments.Player => PlayerInstance / (typeof(Arguments.Player) == "Instance" and Arguments.Player:IsA("Player"))
```

Player is one of the most used argument types. It is used to get a player from the user, and can be used to get a player.

When used as `safeplayer`, the player will only return if their level is lower than the executor's level. This is useful for when you want to make a command that can only be used on players that are lower than the executor's level, such as `!kick [Player]`.

`players` / `safeplayers`
```lua
{
    Name = "Players";
    Type = "players";
    Required = false;
    Default = nil;
}

Arguments.Players => {PlayerInstance} / (typeof(Arguments.Players) == "table" and Arguments.Players[1]:IsA("Player"))
```

Players, like Player, is one of the most used argument types. It is used to get **multiple** players from the user input.

When used as `safeplayers`, the players will only return if their level is lower than the executor's level. This is useful for when you want to make a command that can only be used on players that are lower than the executor's level.

`color`
```lua
{
    Name = "Color";
    Type = "color";
    Required = false;
    Default = Color3.fromRGB(255, 255, 255);
}

Arguments.Color => Color3 / (typeof(Arguments.Color) == "Color3")
```

Color isn't used as much as the other argument types, but is still useful for when you want to make a command that requires a color.

When used, it highlights the color in the commandbar, and allows the player to say the color name.

Full list of colors can be found in Shared/ColorLib.luau.

Alternatively the player could type the full color, such as `255,255,255`.


## Creating the keys
References for this part;
```lua
Command --> The returned command table of which you build the command with.
Keys --> A string in Command.Keys that defines the key.
```

Keys are like arguments, except they are completely optional and are not required to be used. They are used to change the functionality of the command, and are used to make the command more flexible.

By default, Redefine:A5 already listens for 2 keys; `--silent` and `--delay`. These are used to make the command silent, or to delay the command's execution respectively.

`--silent` will make the command not spawn a log in the executor's place, and `--delay` will delay the command's execution by the amount the player has written.

As the command creator, you can add your own keys as well and listen to them using Keys.keyname.

Keys must be lowercase, and must not contain any spaces.

Example;
```lua
Command = {
    ...
    Keys = {
        keyname = true;
    };
    ...
}

Keys.keyname => true / (typeof(Keys.keyname) == "boolean") || (typeof(Keys.keyname) == "number") || (typeof(Keys.keyname) == "string")
```

There's nothing to explain here. Really. It's just a table that adds extra arguments with Keys.keyname = true when the player types `--keyname` with the command.

Another thing to note, Keys could contain values, such as `--keyname=5` or `--keyname=hi`. This is useful for when you want to make a command that requires a value, such as `--delay=5`.

In order to check if the key has a value, you must check if the key is a number or a string. If it is, it probably means the key has a value; Otherwise, it will be a boolean value.


## Using the command
Now that we've created the command, we can use it.

Best way to check whether the command is working is by using it with the commandbar. You can do this by typing `commandname [Arguments] --[Keys]` in the commandbar, and checking if the commandbar gives you any warnings/notices.

If the commandbar gives you a warning, it means the command may error.

If the commandbar gives you a notice, it means the command is working, but may not be working as intended. This may be because you've used an argument that may fail, or because you've used a key that doesn't exist.

If the commandbar gives you nothing, it means the command is working as intended; If it will still error without a commandbar warning, it means the code in OnRun is faulty.


## Returning values
References for this part;
```lua
Command --> The returned command table of which you build the command with.
```

Commands can return values and give messages back to the player. This is useful for when you want to make a command that returns a value and/or grant feedback to the user.

To return a value, you must return a value in the OnRun function. This value will be returned to the player, and will be displayed in the commandbar.

The return structure will look similar to this;
```lua
return {
    Success = true; -- Whether the command was successful or not.
    Message = "Success!"; -- The message that will be displayed in the commandbar.
};
```

The return structure can also look like this, but it is not recommended since it does not provide actual feedback to the user;
```lua
return true;
```