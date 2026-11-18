--==================================================
-- DRAGGING CONTEXT SOURCE DIAGNOSTIC
-- Read-only inspection of the native Move drag context.
--==================================================

local RS = game:GetService("ReplicatedStorage")
local Module = RS:WaitForChild("BuildMode"):WaitForChild("DraggingContext")

local function Log(...)
    print("[DraggingContextSource]", ...)
end

local function DumpTable(label, value)
    Log("==========", label, "==========")
    if type(value) ~= "table" then
        Log("Not a table:", typeof(value), tostring(value))
        return
    end

    for key, item in pairs(value) do
        Log("Key:", tostring(key), "Type:", typeof(item), "Value:", tostring(item))
    end

    local mt = getmetatable(value)
    if mt then
        Log("Metatable:")
        for key, item in pairs(mt) do
            Log("  ", tostring(key), typeof(item), tostring(item))
        end
    end
end

local ok, class = pcall(require, Module)
if not ok then
    Log("require failed:", class)
    return
end

DumpTable("REQUIRED MODULE TABLE", class)

if type(class) == "table" then
    for _, methodName in ipairs({"new", "Drag", "Reset"}) do
        local fn = rawget(class, methodName)
        if type(fn) == "function" then
            Log("========== METHOD", methodName, "==========")
            local infoOk, info = pcall(debug.getinfo, fn)
            if infoOk and info then
                Log("Source:", info.source or info.short_src, "Nups:", info.nups)
            end

            if methodName == "new" and type(debug.getupvalue) == "function" then
                for index = 1, (info and info.nups or 0) do
                    local packed = table.pack(pcall(debug.getupvalue, fn, index))
                    if packed[1] then
                        local value = packed[packed.n]
                        DumpTable("new upvalue " .. index, value)
                    end
                end
            end

            if type(debug.getconstants) == "function" then
                local cOk, constants = pcall(debug.getconstants, fn)
                if cOk and type(constants) == "table" then
                    for index, constant in ipairs(constants) do
                        Log(methodName .. " constant", index, tostring(constant))
                    end
                end
            end
        end
    end
end

if type(decompile) == "function" then
    Log("========== DECOMPILED MODULE SOURCE ==========")
    local dOk, source = pcall(decompile, Module)
    if dOk and type(source) == "string" then
        Log(source)
    else
        Log("decompile failed:", source)
    end
else
    Log("decompile unavailable")
end

Log("========== END ==========")
