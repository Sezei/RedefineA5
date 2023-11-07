## Redefine:A 5's Engine
The engine used by Redefine:A 5 is NxEngine2, which is the same engine that powers [Nano](https://devforum.roblox.com/t/nano-the-non-intrusive-admin-panel/1734987). It is a direct fork of Redefine:A 4, which uses NxEngine, rewritten from the ground up in order to make the system far more customizable while keeping the loader as lightweight as possible.

## The Engine
The engine is the core of Redefine:A 5. It is responsible for loading and running the modules that the developers of the game attach to it. It is not responsible for the commands, as the functions that are made for it (eg. MainFunctions) will handle them. The engine is simply there to load the modules and run them, while also keeping track of the modules that are loaded, and anything that is attached to the engine.

The only mentionable thing regarding it is the BaseEnvironment module, which directly gives the information about the engine to the modules, as well as being the defining factor of how the Environment would look like.

## The Environment
The environment is the core of the engine. It is the thing that is passed to the modules, and it is the thing that the modules use to communicate with each other.
By default, the environment is an empty table containing only the following data;
```lua
{
	-- Version info
	NxEngine = {
		BuildId = 0; -- Build ID here
	};

	-- In-game Data
	Data = {
		-- Stuff the modules would usually use.
	};

	-- Variables that Redefine:A5 specifically uses.
	Commands = {};
	Aliases = {};

	-- Instances
	MainModule = script.Parent.Parent;
}
```

The environment is passed to the modules as the first argument of most modules within the environment, hence making it possible to call functions using env:FunctionName() instead of module.FunctionName(env) as some other administration systems do.

Thanks to how the engine handles the modules, it is possible to change the environment at any time, making it possible to change even the core of the engine at any time, even during runtime, which means that theoretically it's possible to make a new system that forks Redefine:A 5, just like Nano.

## Security-wise
As mentioned in the previous section, *the environment can and will be changed during runtime.* In order to make this secure, we made sure that nothing that isn't *already* part of the environment can change it, meaning that if the security fails, it's likely due to a user error rather than a vulnerability in the engine.

Note: **In the rare cases where the environment is flawed, the engine will not lock itself up due to how it's build, therefore making it susceptible to malicios actors.** The only *real* way to stop such activity is to make sure none of the modules open up access to external scripts.

## Cheatsheet specific for Redefine:A 5
Since technically the environment can be changed, nothing here is guaranteed to be accurate, but it's 100% accurate if none of the modules are forked/changed within the system.

`BaseEnvironment` -> Mentioned in the previous section. It's the base environment that is passed to the modules.

`BetterBasics` -> A module that contains a few functions that are used by the engine, and can be used outside of it. Mainly made for stuff such as `BetterBasics.string.fixnewchat` which fixes the new chat's issues with the rich-text characters. Documentation is unnecessary for this module, as it's mainly internal, but can be easily read through the source.

`Datastore` -> A module that contains the functions that are used to save and load data from the datastore (duh).
* `Datastore(Category, env)` -> Returns a category object that can be used to save and load data from the datastore. Returns `Category`.
* `Category:Save(Key, Data)` -> Saves the data to the datastore. Returns `DataTask`.
* `Category:Update(Key, UpdateFunction)` -> Loads the data from the datastore. Returns `DataTask`.
* `Category:Load(Key, Data)` -> Ditto, but uses direct data instead of a function. Returns `DataTask`.
* `Category:Remove(Key)` -> Removes the data from the datastore. Returns `DataTask`.
* `DataTask:wait()` -> Waits for the data to load. Returns `self`.
* `DataTask:Cancel()` -> Attempts to stop the task. `void`
* `DataTask:Focus()` -> Returns a `MetaTask` object that can be used to change some of the data.
* `MetaTask:Redo()` -> Redoes the task. Returns `self`.
* `MetaTask:Increment(n)` -> Specific for Load tasks. If the returned data is a number, it will increment it by `n`. Returns `self`.
* `MetaTask:Decrement(n)` -> Specific for Load tasks. If the returned data is a number, it will decrement it by `n`. Returns `self`.

`format / PlaceholderAPI` -> A module that contains the functions that are used to format strings.
* `env.format(string, replacementdata, player?)` -> Formats the string using the replacement data. Returns `string`.

`GetLevel` -> A module that contains the functions that are used to get the level of a player.
* `env:GetLevel(player)` -> Returns the level of the player. Returns `number`.

`MessageService` -> A module made to wrap the MessagingService API. Uses a single 'listening' channel in order to not block the MessagingService API, hence making it possible to use it without having to worry about it blocking the MessagingService API from creating more channels.
* `env.MessageService:Push(channel, data)` -> Publishes the data to the channel.
* `env.MessageService:Listen(channel, callback)` -> Subscribes to the channel.
* `env.MessageService:Unlisten(channel)` -> Unsubscribes from the channel.
* `env.MessageService:Once(channel, callback)` -> Subscribes to the channel, but only once. Once the callback is called, it will unsubscribe from the channel. Returns `Listener`.
* `env.MessageService:Wait(channel, callback)` -> Waits for the channel to be published to.

`MetaPlayer` -> *The Big One*. Created as a means to use player as a data point rather than an instance. *It's better to look at it manually.*

`Notify` -> A module that contains the functions that are used to send notifications to the players.
* `env:Notify(player, title, data)` -> Sends a notification to the player.
Data can be used to change the notification entirely. It's mostly-client-sided, so it's not recommended to use it for anything important.

Notification structure:
```lua
Player = Player; -- Receiver
Title = string; -- The text that is shown on the notification
Data = {
    Type = "Normal" | "Warning" | "Error" | "Critical"; -- The type of the notification
    TextColor = Color3; -- The color of the text
    BackgroundColor = Color3; -- The color of the background
    Timeout = number; -- The time it takes for the notification to disappear
    PushLowest = boolean; -- Whether or not the notification should be pushed directly to the bottom of the other notifications.
    Clickable = boolean; -- Whether or not the notification can be clicked to make it disappear. Will be forced to true if there are no options to make the notification disappear, such as timeout, options, and clickable is false. If no options are specified, the notification will return 'Clicked' as the callback option.
    Image = AssetURL; -- The image that is shown on the notification
    Sound = AssetURL; -- The sound that is played when the notification appears
    Callback = function(Option); -- The function that is called when the notification is clicked/times out/an option is selected. [[SERVERSIDED]]
    Options = {
        [string] = { -- The sent option to the server.
            Text = string; -- The text that is shown on the option
            Primary = boolean; -- Whether or not the option is the primary option. 1st option will be primary if none are specified, and if clickable, will be called when the notification is clicked without selecting an option.
            TimedOut = boolean; -- Whether or not the option is the timed out option. Will be called when the notification times out. If one is not specified, the server will receive "Timedout" as the option.
        };
    }
}
```

`RegisterCommand` -> The module containing the function that is used to register commands.
* `env:RegisterCommand(CommandData, Module?)` -> Registers the command. Fires the `CommandRegistered` signal with the command data.

`RunCommand` -> The module containing the function that is used to run commands.
* `env:RunCommand(player, fullmessage, isConsole)` -> Runs the command. Returns `true` if successful, or `nil` if an error has occurred.