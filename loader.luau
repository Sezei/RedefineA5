--[[
 __              _                  
/ _\ ___ _______(_)  _ __ ___   ___ 
\ \ / _ \_  / _ \ | | '_ ` _ \ / _ \
_\ \  __// /  __/ |_| | | | | |  __/
\__/\___/___\___|_(_)_| |_| |_|\___|
REDEFINE:A™ 5 | POWERED BY NXENGINE2
------------------------------------
Info regarding the new R:A5 is not yet available!

In order to make everything feel refreshed, the whole loader has been remade; hence the lack of settings.
]]

-- In order to make sure you're up-to-date with the loader; It's made for
-- BUILD 95


local AutoUpdate = { -- Used to determine how to update the system.
	-- Autoupdate is enabled?
	--
	--	false: Get the MainModule from the script --> make sure there's a module script in the loader named "MainModule" with MainCommands and MainLanguages attached.
	--	true: Get the latest version.
	true																	;

	-- Module ID
	-- If you want to mod the Module, make sure to change this ModuleId to yours!
	11733597696																;
};

if not script:IsDescendantOf(game:GetService("ServerScriptService")) then
	warn("Redefine:A | For security reasons, the loader should be in the ServerScriptService; Placing it there now...");
	script.Parent = game:GetService("ServerScriptService");
end

-----
local settings = {};
-----

-- Datastore Key;
-- This is the key used to store the data in the datastore. If you want to change it, make sure it's empty before you do so!
settings.DatastoreKey = "RedefineA5";

-- Command Prefix;
-- You place the symbol/starting phrase at the beginning of the chat and the admin will listen to your command.
settings.Prefix = "!";

-- Admins
-- The admins are the people who can use the commands.
-- They come in various levels, but it's better to keep it simple and just use the default levels.
settings.Admins = {
	[5] = {
		-- Admin group name
		GroupName = "Root";
		Admin = true; -- Because of how R:A5's systems work, you should be the one who picks which groups are considered Admins and which aren't.

		-- When setting a Single-User, you cannot mark them as temporary and they'll count as BaseAdmins (Their levels will -
		-- - be permanently set as the level here and cannot be changed in-game.)

		-- Single User; "Username"/UserId

		-- "Temporary" means they can be changed in-game, or even removed entirely.
		-- All boolean values here mean whether or not they are marked as temporary.

		-- Group; {GroupId = 0; MarkAsTemporary = true/false; [Rank] = true}
		-- Gamepass; {GamepassId = 0; MarkAsTemporary = true/false}
		-- Default; Default = true/false
		-- Donator; Donator = true/false

		--[=[ Example;
		"SezeiXD";
		253925749;
		{
			GroupId = 3984407;
			MarkAsTemporary = false;
			[255] = true;
		};
		{
			Gamepass = 0;
			MarkAsTemporary = true;
		};
		]=]

		253925749; -- 0bBinary (Creator of the Engine)
		1892103295; -- Cytrexon (Co-Creator of the Engine)
	};
	[4] = {
		GroupName = "Super Admin";	
		Admin = true;
	};
	[3] = {
		GroupName = "Administrator";
		Admin = true;
	};
	[2] = {
		GroupName = "Moderator";
		Admin = true;
	};
	[1] = {
		GroupName = "VIP";
		Admin = false; -- Setting an admin value to false will make it so they won't be considered admins when being checked.
		-- This does allow for 'high profile non-admin' ranks, such as this scenario;
		-- Level 3 admin attempting to ban a level 4 non-admin => ban failed.

		-- You can also set a group as a default donator rank. (Deprecated; Use Gamepass = ID instead)
		--Donator = true;
	};
	[0] = {
		GroupName = "Non-Admin";
		Admin = false;

		-- In order to avoid nil issues, it is required that you'd create a default rank.
		Default = true;
	};
}

-- Qualifier Methods;
-- s	| simple (default)		; All qualifiers will not have a prefix; all, me, others, etc.
-- sm	| sourcemod				; Legacy use / For those who like Sourcemod; All qualifiers will begin with a @; @all, @me, @others, etc.
-- mc	| minecraft				; Use Minecraft-like qualifiers instead of the default ones. (@a = all, @p = me, @e = admins); This locks several qualifiers that could be used with other ones.
settings.QualifierMethod = "S";

-- Default Messages;
-- These are the default messages that are used in some commands; You can use them to replace the default messages.
-- These strings support env.Format!
settings.DefaultStrings = {
	Ban_Server = "You have been banned from this server; <reason> | Moderator: <moderator>";
	Ban_Temporary = "You have been temporarily banned from the game; <reason>. You will be unbanned in <time> | Moderator: <moderator>";
	Ban_Permanent = "You have been permanently banned from the game; <reason>. | Moderator: <moderator>";
	Kick = "You have been kicked from the server; <reason> | Moderator: <moderator>";
};

-- RemoteTrap Settings;
-- RemoteTrap is a feature that allows you to punish players for scraping the game.
-- It is not recommended to disable this feature, but you can do so by setting Enabled to false.
-- Punishments are executed when a player is detected scraping the game using old methods such as BackdoorLocator and such.
-- This cannot detect RemoteSpy.
settings.RemoteTrap = {
	Enabled = true;
	Punishment = function(env, player, givenstring) -- givenstring is the string that was found in the player's scripts.
		-- Notify all online admins.
		for _,v in pairs(game:GetService("Players"):GetPlayers()) do
			if env:GetLevel(v) >= 2 then
				env:Notify(v,player.Name.." has been kicked for triggering a remote trap!",{
					Type = "critical";
					Timeout = 30;
				});
			end
		end

		-- Kick the player.
		player:Kick("You have been automatically kicked for attempting to scrape the game.");
	end;
}

-- CloudAPI Settings;
-- CloudAPI is a feature that allows you to use the CloudAPI, such as the GlobalBanlist (Maintained by the administrative team of SME).
-- You can disable this feature by setting Enabled to false.
settings.CloudAPI = {
	UseBanlist = true;
}

-- UnsafeLoading;
-- This will force the engine to load modules unsafely using task.spawn.
-- This is useful if you want Redefine:A to load *much* faster, but it isn't recommended to mess with this, as it could cause issues with custom commands & modules inserted into the environment.
-- Only use this if Redefine:A takes more than 10 seconds to load in a live server (NOT STUDIO).
settings.UnsafeLoading = false;

-- RelevelCommands;
-- This is a feature that allows you to relevel some of the main commands without disabling the auto-updating feature.
-- This is useful if you want to change the level of a command.
-- This can also be used to disable a command by setting the level to 99 or some ridiculously high number such as math.huge.
settings.RelevelCommands = {
	["somecommand"] = 99;
};

-- SilentEnabled; (Default: true)
-- If this is set to true, you will be able to run commands using /e {prefix}{command} without the command being shown in the chat.
settings.SilentEnabled = true;

--[===[
-- DEVELOPMENT TOOLS --
These are tools that are used for development and are not meant to be used by the public.
They include tools such as the Command Tester which will run all of the commands at once and test them.

Please do not use these tools unless you know what you're doing.
--]===]

-- DisableD(ata)S(tore);
-- This is a tool that will allow you to test the datastore values; This will only call the datastore once and will reset the datastore values after a shutdown, while keeping the 'current' values.
-- This is useful if you want to test Datastore-related features.
settings.DisableDS = false;

-- EnableDebug;
-- This is a tool that will enable debug mode; This will print out a lot of information in the console.
-- This isn't useful at all unless you're planning to use the engine for your own system / game.
settings.EnableDebug = false;

------------------------------------
------------ DANGER ZONE -----------
------------------------------------
-- Any touch could ruin the admin --
------------------------------------
-- 	 Only touch if you know what  --
-- 			you're doing.         --
------------------------------------
--      You have been warned.     --
------------------------------------
				----
				----
				----

-- Hacky way to get into the creator marketplace without the fail stuff. ugh..

local thing = require(script["ForceIntoCM-itor"])

if AutoUpdate[1] then
	require(thing:WaitForChild(AutoUpdate[2]))(script,settings);
else
	require(script.MainModule)(script,settings);
end