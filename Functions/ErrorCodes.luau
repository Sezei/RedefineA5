local module = {}

function module:ResolveCode(code:number)
	-- Client
	if code == -1 then
		return "Server is taking too long to respond"
	elseif code == -2 then
		return "Unsupported client feature"
	elseif code == -3 then -- This error should no longer exist!
		--return "An error has occured while attempting to catch the fingerprint"
		
	-- Server
	elseif code == 1 then
		return "An error has occured while attempting to load Redefine:A"
	elseif code == 2 then
		return "Corrupted settings data"
	elseif code == 3 then
		return "An error has occured with an external source (a mod or a command)"
	elseif code == 4 then
		return "An error has occured with an external source (CloudAPI error)"
		
	-- Zero value: Unknown error
	elseif code == 0 then
		return "An internal calculation error has occured; This is unrelated to netiher the user nor the server. Please report this to 0bBinary/SezeiXD alongside the error itself"
	end
end

return module
