--[========[Config Manipulation Functions]========]
print("Loading WML module...")

local function ensure_config(cfg)
	if type(cfg) == 'table' then
		return wml.valid(cfg)
	end
	if type(cfg) == 'userdata' then
		if getmetatable(cfg) == 'wml object' then return true end
		error("Expected a table or wml object but got " .. getmetatable(cfg), 3)
	else
		error("Expected a table or wml object but got " .. type(cfg), 3)
	end
	return false
end

--! Returns the first subtag of @a cfg with the given @a name.
--! If @a id is not nil, the "id" attribute of the subtag has to match too.
--! The function also returns the index of the subtag in the array.
--! Returns nil if no matching subtag is found
function wml.get_child(cfg, name, id)
	ensure_config(cfg)
	for i,v in ipairs(cfg) do
		if v[1] == name then
			local w = v[2]
			if not id or w.id == id then return w, i end
		end
	end
end

--! Returns the nth subtag of @a cfg with the given @a name.
--! (Indices start at 1, as always with Lua.)
--! The function also returns the index of the subtag in the array.
--! Returns nil if no matching subtag is found
function wml.get_nth_child(cfg, name, n)
	ensure_config(cfg)
	for i,v in ipairs(cfg) do
		if v[1] == name then
			n = n - 1
			if n == 0 then return v[2], i end
		end
	end
end

--! Returns the first subtag of @a cfg with the given @a name that matches the @a filter.
--! If @a name is omitted, any subtag can match regardless of its name.
--! The function also returns the index of the subtag in the array.
--! Returns nil if no matching subtag is found
function wml.find_child(cfg, name, filter)
	ensure_config(cfg)
	if filter == nil then
		filter = name
		name = nil
	end
	for i,v in ipairs(cfg) do
		if name == nil or v[1] == name then
			local w = v[2]
			if wml.matches_filter(w, filter) then return w, i end
		end
	end
end

--! Returns the number of attributes of the config
function wml.attribute_count(cfg)
	ensure_config(cfg)
	local count = 0
	for k,v in pairs(cfg) do
		if type(k) == 'string' then
			count = count + 1
		end
	end
	return count
end

--! Returns the number of subtags of @a with the given @a name.
function wml.child_count(cfg, name)
	ensure_config(cfg)
	local n = 0
	for i,v in ipairs(cfg) do
		if v[1] == name then
			n = n + 1
		end
	end
	return n
end

--! Returns an iterator over all the subtags of @a cfg with the given @a name.
function wml.child_range(cfg, tag)
	ensure_config(cfg)
	local iter, state, i = ipairs(cfg)
	local function f(s)
		local c
		repeat
			i,c = iter(s,i)
			if not c then return end
		until c[1] == tag
		return c[2]
	end
	return f, state
end

--! Returns an array from the subtags of @a cfg with the given @a name
function wml.child_array(cfg, tag)
	ensure_config(cfg)
	local result = {}
	for val in wml.child_range(cfg, tag) do
		table.insert(result, val)
	end
	return result
end

--! Removes the first matching child tag from @a cfg
function wml.remove_child(cfg, tag)
	ensure_config(cfg)
	for i,v in ipairs(cfg) do
		if v[1] == tag then
			table.remove(cfg, i)
			return
		end
	end
end

--! Removes all matching child tags from @a cfg
function wml.remove_children(cfg, ...)
	for i = #cfg, 1, -1 do
		for _,v in ipairs(...) do
			if cfg[i] == v then
				table.remove(cfg, i)
			end
		end
	end
end

--[========[WML Tag Creation Table]========]

local create_tag_mt = {
	__metatable = "WML tag builder",
	__index = function(self, n)
		return function(cfg) return { n, cfg } end
	end
}

wml.tag = setmetatable({}, create_tag_mt)

--[========[Config / Vconfig Unified Handling]========]

-- These are slated to be moved to game kernel only

function wml.literal(cfg)
	if type(cfg) == "userdata" then
		return cfg.__literal
	else
		return cfg or {}
	end
end

function wml.parsed(cfg)
	if type(cfg) == "userdata" then
		return cfg.__parsed
	else
		return cfg or {}
	end
end

function wml.shallow_literal(cfg)
	if type(cfg) == "userdata" then
		return cfg.__shallow_literal
	else
		return cfg or {}
	end
end

function wml.shallow_parsed(cfg)
	if type(cfg) == "userdata" then
		return cfg.__shallow_parsed
	else
		return cfg or {}
	end
end

if wesnoth.kernel_type() == "Game Lua Kernel" then
	--[========[WML error helper]========]

	--! Interrupts the current execution and displays a chat message that looks like a WML error.
	function wml.error(m)
		error("~wml:" .. m, 0)
	end

	--- Calling wesnoth.fire isn't the same as calling wesnoth.wml_actions[name] due to the passed vconfig userdata
	--- which also provides "constness" of the passed wml object from the point of view of the caller.
	--- So please don't remove since it's not deprecated.
	function wesnoth.fire(name, cfg)
		wesnoth.wml_actions[name](wml.tovconfig(cfg or {}))
	end

	--[========[Basic variable access]========]

	-- Get all variables via wml.all_variables (read-only)
	local get_all_vars_local = wesnoth.get_all_vars
	setmetatable(wml, {
		__metatable = "WML module",
		__index = function(self, key)
			if key == 'all_variables' then
				return get_all_vars_local()
			end
			return rawget(self, key)
		end,
		__newindex = function(self, key, value)
			if key == 'all_variables' then
				error("all_variables is read-only")
				-- TODO Implement writing?
			end
			rawset(self, key, value)
		end
	})

	-- So that definition of wml.variables does not cause deprecation warnings:
	local get_variable_local = wesnoth.get_variable
	local set_variable_local = wesnoth.set_variable

	-- Get and set variables via wml.variables[variable_path]
	wml.variables = setmetatable({}, {
		__metatable = "WML variables",
		__index = function(_, key)
			return get_variable_local(key)
		end,
		__newindex = function(_, key, value)
			set_variable_local(key, value)
		end
	})

	--[========[Variable Proxy Table]========]

	local variable_mt = {
		__metatable = "WML variable proxy"
	}

	local function get_variable_proxy(k)
		local v = wml.variables[k]
		if type(v) == "table" then
			v = setmetatable({ __varname = k }, variable_mt)
		end
		return v
	end

	local function set_variable_proxy(k, v)
		if getmetatable(v) == "WML variable proxy" then
			v = wml.variables[v.__varname]
		end
		wml.variables[k] = v
	end

	function variable_mt.__index(t, k)
		local i = tonumber(k)
		if i then
			k = t.__varname .. '[' .. i .. ']'
		else
			k = t.__varname .. '.' .. k
		end
		return get_variable_proxy(k)
	end

	function variable_mt.__newindex(t, k, v)
		local i = tonumber(k)
		if i then
			k = t.__varname .. '[' .. i .. ']'
		else
			k = t.__varname .. '.' .. k
		end
		set_variable_proxy(k, v)
	end

	local root_variable_mt = {
		__metatable = "WML variables proxy",
		__index    = function(t, k)    return get_variable_proxy(k)    end,
		__newindex = function(t, k, v)
			if type(v) == "function" then
				-- User-friendliness when _G is overloaded early.
				-- FIXME: It should be disabled outside the "preload" event.
				rawset(t, k, v)
			else
				set_variable_proxy(k, v)
			end
		end
	}

	wml.variables_proxy = setmetatable({}, root_variable_mt)

	--[========[Variable Array Access]========]

	local function resolve_variable_context(ctx, err_hint)
		if ctx == nil then
			return {get = get_variable_local, set = set_variable_local}
		elseif type(ctx) == 'number' and ctx > 0 and ctx <= #wesnoth.sides then
			return resolve_variable_context(wesnoth.sides[ctx])
		elseif type(ctx) == 'string' then
			-- TODO: Treat it as a namespace for a global (persistent) variable
			-- (Need Lua API for accessing them first, though.)
		elseif getmetatable(ctx) == "unit" then
			return {
				get = function(path) return ctx.variables[path] end,
				set = function(path, val) ctx.variables[path] = val end,
			}
		elseif getmetatable(ctx) == "side" then
			return {
				get = function(path) return wesnoth.sides[ctx.side].variables[path] end,
				set = function(path, val) wesnoth.sides[ctx.side].variables[path] = val end,
			}
		elseif getmetatable(ctx) == "unit variables" or getmetatable(ctx) == "side variables" then
			return {
				get = function(path) return ctx[path] end,
				set = function(path, val) ctx[path] = val end,
			}
		end
		error(string.format("Invalid context for %s: expected nil, side, or unit", err_hint), 3)
	end

	wml.array_access = {}

	--! Fetches all the WML container variables with name @a var.
	--! @returns a table containing all the variables (starting at index 1).
	function wml.array_access.get(var, context)
		context = resolve_variable_context(context, "get_variable_array")
		local result = {}
		for i = 1, context.get(var .. ".length") do
			result[i] = context.get(string.format("%s[%d]", var, i - 1))
		end
		return result
	end

	--! Puts all the elements of table @a t inside a WML container with name @a var.
	function wml.array_access.set(var, t, context)
		context = resolve_variable_context(context, "set_variable_array")
		context.set(var)
		for i, v in ipairs(t) do
			context.set(string.format("%s[%d]", var, i - 1), v)
		end
	end

	--! Creates proxies for all the WML container variables with name @a var.
	--! This is similar to wml.array_access.get, except that the elements
	--! can be used for writing too.
	--! @returns a table containing all the variable proxies (starting at index 1).
	function wml.array_access.get_proxy(var)
		local result = {}
		for i = 1, wml.variables[var .. ".length"] do
			result[i] = get_variable_proxy(string.format("%s[%d]", var, i - 1))
		end
		return result
	end

	-- More convenient when accessing global variables
	wml.array_variables = setmetatable({}, {
		__metatable = "WML variables",
		__index = function(_, key)
			return wml.array_access.get(key)
		end,
		__newindex = function(_, key, value)
			wml.array_access.set(key, value)
		end
	})
else
	--[========[Backwards compatibility for wml.tovconfig]========]
	local fake_vconfig_mt = {
		__index = function(self, key)
			if key == '__literal' or key == '__parsed' or key == '__shallow_literal' or key == '__shallow_parsed' then
				return self
			end
			return self[key]
		end
	}

	local function tovconfig_fake(cfg)
		ensure_config(cfg)
		return setmetatable(cfg, fake_vconfig_mt)
	end

	wesnoth.tovconfig = wesnoth.deprecate_api('wesnoth.tovconfig', 'wml.valid or wml.interpolate', 1, nil, tovconfig_fake, 'tovconfig is now deprecated in plugin or map generation contexts; if you need to check whether a table is valid as a WML object, use wml.valid instead, and use wml.interpolate if you need to substitute variables into a WML object.')
	wml.tovconfig = wesnoth.deprecate_api('wml.tovconfig', 'wml.valid', 1, nil, tovconfig_fake, 'tovconfig is now deprecated in plugin or map generation contexts; if you need to check whether a table is valid as a WML object, use wml.valid instead.')
	wml.literal = wesnoth.deprecate_api('wml.literal', '(no replacement)', 1, nil, wml.literal, 'Since vconfigs are not supported outside of the game kernel, this function is redundant and will be removed from plugin and map generation contexts. It will continue to work in the game kernel.')
	wml.parsed = wesnoth.deprecate_api('wml.parsed', '(no replacement)', 1, nil, wml.parsed, 'Since vconfigs are not supported outside of the game kernel, this function is redundant and will be removed from plugin and map generation contexts. It will continue to work in the game kernel.')
	wml.shallow_literal = wesnoth.deprecate_api('wml.shallow_literal', '(no replacement)', 1, nil, wml.shallow_literal, 'Since vconfigs are not supported outside of the game kernel, this function is redundant and will be removed from plugin and map generation contexts. It will continue to work in the game kernel.')
	wml.shallow_parsed = wesnoth.deprecate_api('wml.shallow_parsed', '(no replacement)', 1, nil, wml.shallow_parsed, 'Since vconfigs are not supported outside of the game kernel, this function is redundant and will be removed from plugin and map generation contexts. It will continue to work in the game kernel.')
end

wesnoth.tovconfig = wesnoth.deprecate_api('wesnoth.tovconfig', 'wml.tovconfig', 1, nil, wml.tovconfig)
wesnoth.debug = wesnoth.deprecate_api('wesnoth.debug', 'wml.tostring', 1, nil, wml.tostring)
wesnoth.wml_matches_filter = wesnoth.deprecate_api('wesnoth.wml_matches_filter', 'wml.matches_filter', 1, nil, wml.matches_filter)

if wesnoth.kernel_type() == "Game Lua Kernel" then
	wesnoth.get_variable = wesnoth.deprecate_api('wesnoth.get_variable', 'wml.variables', 1, nil, wesnoth.get_variable)
	wesnoth.set_variable = wesnoth.deprecate_api('wesnoth.set_variable', 'wml.variables', 1, nil, wesnoth.set_variable)
	wesnoth.get_all_vars = wesnoth.deprecate_api('wesnoth.get_all_vars', 'wml.all_variables', 1, nil, wesnoth.get_all_vars)
end
