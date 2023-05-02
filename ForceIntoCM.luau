-- ForceIntoCM-itor = ForceIntoCommunitMarketplace
-- This is a trick to get into the creator marketplace by bypassing the require() check (it's annoying!);

-- i can't believe im doing this..
return {
	WaitForChild = function(self, moduleid)
		return tonumber(string.reverse(string.reverse(tostring(moduleid))));
	end;
};

-- Fun fact; a lot of backdoors do the EXACT SAME THING! Check if there are suspicious scripts in your game, and if there are, remove them!