-- This module is made to validate settings; and if something is missing, it will be added with a default value.
-- If something is *not* missing, it will be checked for validity.

return {
	-- Key = {type, defaultValue}
	DatastoreKey = {'string', 'RedefineA5'},
	Prefix = {'string', '!'},
	Splitter = {'string', ' | '},
	SubSplitter = {'string', ' || '},
	Admins = {'table', {
		[5] = {
			GroupName = "Root",
			Admin = true,
		},
		[4] = {
			GroupName = "Super Admin",
			Admin = true
		},
		[3] = {
			GroupName = "Administrator",
			Admin = true
		},
		[2] = {
			GroupName = "Moderator",
			Admin = true
		},
		[1] = {
			GroupName = "VIP",
			Admin = false
		},
		[0] = {
			GroupName = "Non-Admin",
			Admin = false,
			Default = true
		}
	}},
	QualifierMethod = {'string', 'S'},
	DefaultStrings = {'table', {
		Ban_Server = "You have been banned from this server; {reason} | Moderator: {moderator}",
		Ban_Temporary = "You have been temporarily banned from the game; {reason}. You will be unbanned in {time} | Moderator: {moderator}",
		Ban_Permanent = "You have been permanently banned from the game; {reason}. | Moderator: {moderator}",
		Kick = "You have been kicked from the server; {reason} | Moderator: {moderator}"
	}},
	CloudAPI = {'table', {
		UseBanlist = true
	}},
	UnsafeLoading = {'boolean', false},
	RelevelCommands = {'table', {
		["somecommand"] = 99
	}},
	SilentEnabled = {'boolean', true},
	TextChatService = {'table', {
		Enabled = true,
		OnNotification = "Auto"
	}},
	DisableTaskbar = {'boolean', false},
	SendLevelNotification = {'boolean', true},
	ConsoleKeybind = {'string', 'Equals'},
	Theme = {'string', 'Dark'},
	WebhookURL = {'string', nil},
	EnableFriendNotifications = {'boolean', false},
	DisableDS = {'boolean', false},
	EnableDebug = {'boolean', false},
	
	-- Experimental
	AutoRefresh = {'boolean', false},
	InterchangableIls = {'boolean', false},
	
	-- Onboarding stuff
	latestChangelog = {'number',124},
};