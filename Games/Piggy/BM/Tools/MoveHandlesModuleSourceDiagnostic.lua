--==================================================
-- MOVE HANDLES MODULE SOURCE DIAGNOSTIC
-- Attempts to read the source of native adornment modules.
-- Read-only: does not modify BuildMode or its handles.
--==================================================

local RS = game:GetService("ReplicatedStorage")
local Packages = RS:WaitForChild("Packages")
local CustomAdornments = Packages:WaitForChild("CustomAdornments")

local modules = {
    CustomAdornments:WaitForChild("BaseAdornment"),
    CustomAdornments:WaitForChild("ArrowDragger"),
}

local function TrySource(module)
    print("========== MODULE", module:GetFullName(), "==========")
    print("CLASS", module.ClassName)

    local candidates = {
        "decompile",
        "getscriptbytecode",
        "dumpstring",
    }

    for _, name in ipairs(candidates) do
        local fn = Env and Env[name] or nil
        if type(fn) ~= "function" then
            local ok, value = pcall(function()
                return getfenv(0)[name]
            end)
            if ok then fn = value end
        end

        if type(fn) == "function" then
            local ok, result = pcall(fn, module)
            print("METHOD", name, "OK", ok, "TYPE", typeof(result))
            if ok and type(result) == "string" then
                print("----- SOURCE BEGIN", name, "-----")
                print(result)
                print("----- SOURCE END", name, "-----")
            elseif not ok then
                print("ERROR", tostring(result))
            elseif type(result) == "table" then
                for key, value in pairs(result) do
                    print("RESULT", tostring(key), typeof(value), tostring(value))
                end
            end
        else
            print("METHOD", name, "UNAVAILABLE")
        end
    end

    local okRequire, returned = pcall(require, module)
    print("REQUIRE", okRequire, typeof(returned), tostring(returned))
    if okRequire and type(returned) == "table" then
        for key, value in pairs(returned) do
            print("EXPORT", tostring(key), typeof(value), tostring(value))
        end
    end
end

local Env = (getgenv and getgenv()) or _G

print("========== MOVE HANDLES MODULE SOURCE ==========")
for _, module in ipairs(modules) do
    TrySource(module)
end
print("========== END MODULE SOURCE ==========")
