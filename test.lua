local setclipboard = setclipboard
local global_container
do
	local finder_code, global_container_obj = (function()
		local globalenv = getgenv and getgenv() or _G or shared
		local globalcontainer = globalenv.globalcontainer
		if not globalcontainer then
			globalcontainer = {}
			globalenv.globalcontainer = globalcontainer
		end
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
				return
			end
			return true
		end
		local depth, printresults, hardlimit, query, antioverflow, matchedall
		local function recurseEnv(env, envname)
			if globalcontainer == env then
				return
			end
			if antioverflow[env] then
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
						recurseEnv(val, name)
					end
				elseif Type == "function" then
					name = string.lower(tostring(name))
					local matched
					for methodname, pattern in next, query do
						if pattern(name, envname) then
							globalcontainer[methodname] = val
							if not matched then
								matched = {}
							end
							table.insert(matched, methodname)
							if printresults then
							end
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
		local function finder(Query, ForceSearch, CustomCallLimit, PrintResults)
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
						query[methodname] = loadstring(pattern)
					end
				end
			end
			depth = 0
			printresults = PrintResults
			hardlimit = CustomCallLimit or calllimit
			recurseEnv(genvs)
			do
				local env = getfenv()
				for methodname in next, Query do
					if not globalcontainer[methodname] then
						globalcontainer[methodname] = env[methodname]
					end
				end
			end
			hardlimit = nil
			depth = nil
			printresults = nil
			antioverflow = nil
			query = nil
		end
		return finder, globalcontainer
	end)()
	global_container = global_container_obj
	finder_code({
		getscriptbytecode = 'string.find(...,"get",nil,true) and string.find(...,"bytecode",nil,true)',
		hash = 'local a={...}local b=a[1]local function c(a,b)return string.find(a,b,nil,true)end;return c(b,"hash")and c(string.lower(tostring(a[2])),"crypt")'
	}, true, 10)
end

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
				if Cached then
					return Cached
				end
				local Source = ModuleScript.Source
				local LoadedSource = loadstring(Source)
				local fenv = getfenv(LoadedSource)
				fenv.script = ModuleScript
				fenv.require = ARequire
				local Output = LoadedSource()
				RequireCache[ModuleScript] = Output
				return Output
			end
			local function ARequireController(AssetId)
				local ModuleScript = game:GetObjects("rbxassetid://" .. AssetId)[1]
				return ARequire(ModuleScript)
			end
			return ARequireController
		end)()
		if require_online then
			sha384 = require_online(4544052033).sha384
		end
	end)
end

local decompile = decompile
local getscriptbytecode = global_container.getscriptbytecode
local genv = getgenv and getgenv() or _G or shared
if not genv.scriptcache then
	genv.scriptcache = {}
end
local ldeccache = genv.scriptcache

local function GetInstanceFromPath(pathStr)
	local current = game
	for component in pathStr:gmatch("([^%.]+)") do
		if not current then return nil end
		current = current:FindFirstChild(component)
		if not current then return nil end
	end
	return current
end

local serialize
serialize = function(val, indent, seen)
	indent = indent or ""
	seen = seen or {}
	local t = type(val)
	if t == "string" then
		return string.format("%q", val)
	elseif t == "number" or t == "boolean" or t == "nil" then
		return tostring(val)
	elseif t == "table" then
		if seen[val] then
			return "\"{CYCLIC_TABLE}\""
		end
		seen[val] = true
		local parts = {}
		local isList = #val > 0
		if isList then
			for i=1, #val do
				if val[i] ~= nil then
					isList = true
				else
					isList = false
					break
				end
			end
			if next(val, #val) then isList = false end
		end

		if isList then
			for i = 1, #val do
				table.insert(parts, indent .. "  " .. serialize(val[i], indent .. "  ", seen))
			end
		else
			for k, v in pairs(val) do
				local keyStr = (type(k) == "string" and k:match("^[_%a][_%w]*$")) and k or "[" .. serialize(k, "", seen) .. "]"
				table.insert(parts, indent .. "  " .. keyStr .. " = " .. serialize(v, indent .. "  ", seen))
			end
		end
		seen[val] = nil
		if #parts == 0 then return "{}" end
		return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
	else
		return string.format("\"<%s>\"", t)
	end
end

local function construct_TimeoutHandler(timeout, func, timeout_return_value)
	return function(...)
		local args = { ... }
		if not func then return false, "Function is nil" end
		if timeout < 0 then return pcall(func, table.unpack(args)) end
		local thread = coroutine.running()
		local timeoutThread, isCancelled
		timeoutThread = task.delay(timeout, function()
			isCancelled = true
			coroutine.resume(thread, nil, timeout_return_value)
		end)
		task.spawn(function()
			local success, result = pcall(func, table.unpack(args))
			if isCancelled then return end
			task.cancel(timeoutThread)
			while coroutine.status(thread) ~= "suspended" do task.wait() end
			coroutine.resume(thread, success, result)
		end)
		return coroutine.yield()
	end
end

local function getScriptSource(scriptInstance, timeout)
	if not (decompile and getscriptbytecode and sha384) then
		return false, "Required functions (decompile, getscriptbytecode, sha384) are missing."
	end
	local decompileTimeout = timeout or 10
	local getbytecode_h = construct_TimeoutHandler(3, getscriptbytecode)
	local decompiler_h = construct_TimeoutHandler(decompileTimeout, decompile, "-- Decompiler timed out after " .. tostring(decompileTimeout) .. " seconds.")
	local success, bytecode = getbytecode_h(scriptInstance)
	local hashed_bytecode
	local cached_source
	if success and bytecode and bytecode ~= "" then
		hashed_bytecode = sha384(bytecode)
		cached_source = ldeccache[hashed_bytecode]
	elseif success then
		return true, "-- This script is empty."
	else
		return false, "-- Failed to get script bytecode."
	end
	if cached_source then
		return true, cached_source
	end
	local decompile_success, decompiled_source = decompiler_h(scriptInstance)
	local output
	if decompile_success and decompiled_source then
		output = string.gsub(decompiled_source, "\0", "\\0")
	else
		output = "--[[ Failed to decompile. Reason: " .. tostring(decompiled_source) .. " ]]"
	end
	if output:match("^%s*%-%- Decompiled with") then
		local first_newline = output:find("\n")
		if first_newline then
			output = output:sub(first_newline + 1)
		else
			output = ""
		end
		output = output:gsub("^%s*\n", "")
	end
	if hashed_bytecode then
		ldeccache[hashed_bytecode] = output
	end
	return true, output
end

local final_outputs = {}
local paths_to_process = type(_G.path) == "string" and { _G.path } or _G.path

local processInstance
processInstance = function(instance, collected_data)
	if not instance then return end

	local success, isContainer = pcall(function() return instance:IsA("LuaSourceContainer") end)
	if success and isContainer then
		local path = instance:GetFullName()
		local output
		if instance:IsA("ModuleScript") then
			local ok, required_module = pcall(require, instance)
			if ok and type(required_module) == "table" then
				output = "return " .. serialize(required_module)
			else
				local source_success, source_code = getScriptSource(instance)
				output = source_success and source_code or "--[[ DECOMPILATION FAILED: " .. tostring(source_code) .. " ]]--"
			end
		else
			local source_success, source_code = getScriptSource(instance)
			output = source_success and source_code or "--[[ DECOMPILATION FAILED: " .. tostring(source_code) .. " ]]--"
		end
		table.insert(collected_data, { path = path, code = output })
	end

	local success_children, children = pcall(function() return instance:GetChildren() end)
	if success_children and children and not (success and isContainer) then
		for _, child in ipairs(children) do
			processInstance(child, collected_data)
		end
	end
end

for _, path_str in ipairs(paths_to_process) do
	local target_instance = GetInstanceFromPath(path_str)
	if target_instance then
		local scripts_in_path = {}
		processInstance(target_instance, scripts_in_path)

		if #scripts_in_path > 0 then
			table.sort(scripts_in_path, function(a, b) return a.path < b.path end)
			local output_parts = {}
			for _, data in ipairs(scripts_in_path) do
				local formatted_entry = string.format("-- Path: %s\n%s", data.path, data.code)
				table.insert(output_parts, formatted_entry)
			end
			table.insert(final_outputs, table.concat(output_parts, "\n\n"))
		else
			table.insert(final_outputs, "-- No processable scripts or modules found at: " .. path_str)
		end
	else
		table.insert(final_outputs, "-- Could not find instance at path: " .. path_str)
	end
end

if setclipboard and #final_outputs > 0 then
	setclipboard(table.concat(final_outputs, "\n-----------\n"))
end
