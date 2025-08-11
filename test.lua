local g_env = getfenv()
local function find_first(instance, name)
    local success, child = pcall(instance.FindFirstChild, instance, name)
    if success then
        return child
    end
    return nil
end

local global_container = {}
do
	local finder_code, global_container_obj
	finder_code, global_container_obj = (function()
		local globalenv = g_env
		local globalcontainer = {}
		globalenv.globalcontainer = globalcontainer
		local genvs = { _G, shared }
		if getgenv then
			table.insert(genvs, getgenv())
		end
		local calllimit = 0
		do
			local function determineCalllimit()
				calllimit = calllimit + 1
				determineCalllimit()
			end
			pcall(determineCalllimit)
		end
		local function isEmpty(dict)
			for _ in next, dict do
				return false
			end
			return true
		end
		local depth, hardlimit, query, antioverflow, matchedall
		local function recurseEnv(env)
			if globalcontainer == env or (antioverflow and antioverflow[env]) then
				return
			end
			antioverflow[env] = true
			depth = depth + 1
			for name, val in next, env do
				if matchedall then
					break
				end
				local Type = type(val)
				if Type == "table" then
					if depth < hardlimit then
						recurseEnv(val)
					end
				elseif Type == "function" then
					name = string.lower(tostring(name))
					local matched
					for methodname, pattern in next, query do
						if pattern(name) then
							globalcontainer[methodname] = val
							if not matched then
								matched = {}
							end
							table.insert(matched, methodname)
						end
					end
					if matched then
						for _, methodname in next, matched do
							query[methodname] = nil
						end
						matchedall = isEmpty(query)
						if matchedall then
							break
						end
					end
				end
			end
			depth = depth - 1
		end
		local function finder(Query, ForceSearch, CustomCallLimit)
			antioverflow = {}
			query = {}
			do
				local function Find(String, Pattern)
					return string.find(String, Pattern, nil, true)
				end
				for methodname, pattern in next, Query do
					if not globalcontainer[methodname] or ForceSearch then
						if not Find(pattern, "return") then
							pattern = "return " .. pattern
						end
						local success, func = pcall(loadstring, pattern)
						if success and func then
							query[methodname] = func
						end
					end
				end
			end
			depth = 0
			hardlimit = CustomCallLimit or calllimit
			for _, env in ipairs(genvs) do
				recurseEnv(env)
			end
			local fenv = getfenv()
			for methodname in next, query do
				if not globalcontainer[methodname] then
					globalcontainer[methodname] = fenv[methodname]
				end
			end
			hardlimit, depth, antioverflow, query = nil, nil, nil, nil
		end
		return finder, globalcontainer
	end)()
	global_container = global_container_obj
	finder_code({
		getscriptbytecode = 'string.find(...,"get",nil,true) and string.find(...,"bytecode",nil,true)',
		hash = 'local a={...}return string.find(a[1],"hash")',
		decompile = 'string.find(...,"decompile",nil,true) and not string.find(...,"compile",nil,true)',
		setclipboard = 'string.find(...,"setclipboard",nil,true)'
	}, true, 15)
end

local getscriptbytecode = global_container.getscriptbytecode
local decompile = global_container.decompile
local setclipboard = global_container.setclipboard
local sha384

if global_container.hash then
	sha384 = function(data)
		return global_container.hash(data, "sha384")
	end
end

if not sha384 then
	pcall(function()
		local require_online = (function()
			local RequireCache = {}
			local function ARequire(ModuleScript)
				local Cached = RequireCache[ModuleScript]
				if Cached then return Cached end
				local Source = ModuleScript.Source
				local success, LoadedSource = pcall(loadstring, Source)
				if not success or not LoadedSource then return nil end
				local fenv = getfenv(LoadedSource)
				fenv.script = ModuleScript
				fenv.require = ARequire
				local success, Output = pcall(LoadedSource)
				if not success then return nil end
				RequireCache[ModuleScript] = Output
				return Output
			end
			local function ARequireController(AssetId)
				local success, objects = pcall(game.GetObjects, game, "rbxassetid://" .. AssetId)
				if not success or not objects or #objects == 0 then return nil end
				return ARequire(objects[1])
			end
			return ARequireController
		end)()
		if require_online then
			local crypto = require_online(4544052033)
			if crypto and crypto.sha384 then
				sha384 = crypto.sha384
			end
		end
	end)
end

if not g_env.scriptcache then
	g_env.scriptcache = {}
end
local ldeccache = g_env.scriptcache

local function construct_TimeoutHandler(timeout, func, timeout_return_value)
	return function(...)
		local args = { ... }
		if not func then return false, "Function is nil" end
		if timeout < 0 then return pcall(func, table.unpack(args)) end
		local thread = coroutine.running()
		if not thread then return pcall(func, table.unpack(args)) end
		local isCancelled
		local timeoutThread = task.delay(timeout, function()
			isCancelled = true
			task.spawn(coroutine.resume, thread, nil, timeout_return_value)
		end)
		local success, result
		task.spawn(function()
			local s, r = pcall(func, table.unpack(args))
			if isCancelled then return end
			task.cancel(timeoutThread)
			if coroutine.status(thread) == "suspended" then
				success, result = s, r
				task.spawn(coroutine.resume, thread, success, result)
			end
		end)
		return coroutine.yield()
	end
end

local function getScriptSource(scriptInstance)
	if not (decompile and getscriptbytecode and sha384) then
		return false, "--[[ Error: Required functions are missing. ]]--"
	end
	local getbytecode_h = construct_TimeoutHandler(3, getscriptbytecode)
	local decompiler_h = construct_TimeoutHandler(10, decompile, "-- Decompiler timed out after 10 seconds.")
	local success, bytecode = getbytecode_h(scriptInstance)
	local hashed_bytecode
	if success and bytecode and #bytecode > 0 then
		hashed_bytecode = sha384(bytecode)
		if ldeccache[hashed_bytecode] then
			return true, ldeccache[hashed_bytecode]
		end
	elseif success then
		return true, "-- The script is empty."
	else
		return false, "-- Failed to get bytecode."
	end
	local decompile_success, decompiled_source = decompiler_h(scriptInstance)
	local output
	if decompile_success and decompiled_source then
		output = string.gsub(decompiled_source, "\0", "\\0")
	else
		output = "--[[ Failed to decompile. Reason: " .. tostring(decompiled_source) .. " ]]"
	end
	if string.sub(output, 1, 20) == "-- Decompiled with " then
		local first_newline = string.find(output, "\n")
		if first_newline then
			output = string.sub(output, first_newline + 1)
		else
			output = ""
		end
		output = string.gsub(output, "^%s*\n", "")
	end
	if hashed_bytecode then
		ldeccache[hashed_bytecode] = output
	end
	return true, output
end

local function findInstanceByPath(path)
	local current = game
	for part in string.gmatch(path, "[^%.]+") do
		current = find_first(current, part)
		if not current then
			return nil
		end
	end
	return current
end

local function split(s, delimiter)
    local result = {};
    local from = 1;
    local delim_from, delim_to = string.find(s, delimiter, from);
    while delim_from do
        table.insert(result, string.sub(s, from, delim_from - 1));
        from = delim_to + 1;
        delim_from, delim_to = string.find(s, delimiter, from);
    end
    table.insert(result, string.sub(s, from));
    return result;
end

local path_string
local g_table
local main_env = getgenv and getgenv() or _G
if type(main_env.g) == 'table' then
    g_table = main_env.g
elseif type(g_env.g) == 'table' then
    g_table = g_env.g
end

if type(g_table) == "table" and type(g_table.gev) == "string" then
	path_string = g_table.gev
end

if not path_string or not setclipboard then return end

local paths_untrimmed = split(path_string, string.rep("-", 20))
local paths = {}
for _, path in ipairs(paths_untrimmed) do
    local trimmed_path = string.match(path, "^%s*(.-)%s*$")
    if trimmed_path and #trimmed_path > 0 then
        table.insert(paths, trimmed_path)
    end
end

local results = {}
for _, path in ipairs(paths) do
	local target_instance = findInstanceByPath(path)
	if target_instance and pcall(function() return target_instance:IsA("LuaSourceContainer") end) then
		local success, source_code = getScriptSource(target_instance)
		table.insert(results, source_code)
	else
		table.insert(results, "--[[ Could not find a valid script at path: " .. path .. " ]]--")
	end
end

setclipboard(table.concat(results, "\n" .. string.rep("-", 20) .. "\n"))
