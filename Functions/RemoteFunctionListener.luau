-- This module listens to remotefunctions.

return function(env)
    env.RemoteFunction.OnServerInvoke = function(player, MainData, ...)
        if MainData == "GetListItems" then
            -- Split the argument [(...):string] into a table; 'something.something' -> should build a path for env.Data.something.something -> {'something', 'something'}
            local Path = ...
            local PathTable = string.split(Path, ".")
            print(Path, PathTable);
            local Cursor = env.Data;

            -- Loop through the table and check if the path exists.
            for _, v in ipairs(PathTable) do
                if Cursor[v] then
                    Cursor = Cursor[v];
                else
                    return false;
                end
            end

            -- Copy the table and return it (for security reasons)
            local Copy = {};
            for k, v in pairs(Cursor) do
                Copy[k] = v;
            end
            return Copy;
        end
    end
end;