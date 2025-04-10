--- Luasm: A simple finite state machine with a clear API
--- See 

local M = {}
M.__index = M

local current 
local last = {}
local from
local to

--- Example
-- local machine = {
-- 	initial = 'start',
-- 	edges = {
-- 		{from = 'start', to = 'splash'},
-- 		{from = 'splash', to = 'menu'},
-- 		{from = 'menu', to = {'settings', 'load_game'}},
-- 		{from = 'settings', to = {'menu', 'game'}},
-- 		{from = 'load_game', to = 'game'},
-- 	},
--  splash = {
--      {onenter = function(self, msg) print(msg) end, onexit = function(self) print("Entering " .. self.to()) end}
--  }
-- }

--- Inverts the given table making each value into a key, which incidentally results in a table where each key is unique
---@param t table The table to invert
local function invert(t)
	local rtn = {}
	
	for k, v in pairs(t) do 
		rtn[v] = k 
	end
	
	return rtn
end

--- Print a debug message to the console
---@param msg string The message for the user
---@param level integer The debug level; 1 = Trace, 2 = Warn, 3 = Error, 4 = Critical
local function dbg_msg(msg, level)
    local levels = {
        'Trace',
        'Warn',
        'Error',
        'Critical'
    }

    local colors = {
        '\27[96m',
        '\27[93m',
        '\27[31m',
        '\27[91m'
    }

	local level = level or 1
	local info = debug.getinfo(3, "Sl")
	local line_info = info.short_src .. ":" .. info.currentline
	local clear_code = '\27[0m'

	print(string.format("%s[%s]%s %s %s", colors[level], levels[level], clear_code, line_info, msg))
end

--- Calls on exit and enter callbacks for the current and next states respectively, then updates the last and current state fields
---@param self table The state machine that is transitioning
---@param next_state string The state to move to
local function update_state(self, next_state, ...)
	to = next_state
    from = current

	if self[current].onexit then -- If there is an onexit callback for the current state, call it
		self[current].onexit(self, ...)
	end
	
	if self[next_state].onenter then -- If there is an onenter callback for the new state, call it
		self[next_state].onenter(self, ...)
	end

	table.insert(last, current) -- Update last

	-- last = current

	current = next_state -- Update current

    from = nil
	to = nil
end

--- Transitions to the given state if able.
---@param self table The state machine that is transitioning
---@param to_state string The state to transition to
---@param ... any Arguments to pass to the callback
local function transition(self, to_state, ...)
    if type(to_state) ~= 'string' then
        dbg_msg("to_state must be a string representing the name of the state you want to transition to", 3)
        return 
    end

	if not current then -- Can transition out of nil to any state
		if self[to_state].onenter then -- If there is an onenter callback for the new state, call it
			self[to_state].onenter(self, ...)
		end

		current = to_state -- Update current
	else
		for _, v in ipairs(self.edges) do
			if v.from == current then -- Find the edge where 'from' is our current state
                if type(v.to) == 'table' then -- Check for the case where our edge 'to' field is an array of states
                    for _, val in pairs(v.to) do
                        if val == to_state then -- Check if the 'to_state' is valid state for our current state
                            update_state(self, to_state, ...)
                            return
                        end
                    end
                else
                    if v.to == to_state then -- Check if the 'to_state' is valid state for our current state
                        update_state(self, to_state, ...)
                        return
                    end
                end
			end
		end
        dbg_msg("State '" .. tostring(to_state) .. "' is not a valid transition for current state '" .. tostring(current) .. "'", 3)
	end
end

local function get_next(self)
	if not current then 
		return nil
	end

	local edge_count = 0
	local to_state

    -- Loop through all of the edges, incrementing edge_count for each where the from field is our current state
    -- Set to_state to the to value of the matching edge
	for _, v in ipairs(self.edges) do
		if v.from == current then
			to_state = v.to
			edge_count = edge_count + 1
		end
	end

	if edge_count > 1 or type(to_state) == 'table' then -- Current state has more than one possible transition
		return nil
	end

	return to_state
end

--- Transitions from the current state to the next if there is only one edge
---@param self table The state machine that is transitioning
local function next(self, ...)
	local next_state = get_next(self)

	if next_state then
		update_state(self, next_state, ...)
	else
		dbg_msg("Cannot use next() to transition from a nil state or from one with more than one edge", 2)
	end
end

local function get_current()
	return current
end

local function get_last(index)
	local i = index or 0
	
	if last then
		return last[#last - i]
	else
		return nil
	end
end

local function get_to()
	return to
end

local function get_from()
	return from
end

--- Create a new state machine
---@param machine table Optional keys: initial, current. Required keys: edges
function M.make(machine)
    -- Do some error checking to ensure the machine is initialized into a valid state
	if not machine.edges or type(machine.edges) ~= 'table' then
		error("Machine must have a table of edges of the form {from = string, to = string[]}")
		return
	end

	for index, v in ipairs(machine.edges) do
		for key, val in pairs(v) do
			if key ~= 'from' and key ~= 'to' then
				error("Edges' keys must be named 'from' and 'to'")
				return
			end

			if key == 'from' and type(val) ~= 'string' then
				error("Edges Index: " .. tostring(index) .. " 'from' key's value must be a string representing the state name")
				return
			elseif key == 'to' and type(val) ~= 'string' then
				if type(val) == 'table' then
					for _, to_val in ipairs(val) do
						if type(to_val) ~= 'string' then
							error("Edges Index: " .. tostring(index) .." 'to' key's value must be either a string or an array of strings")
							return
						end
					end
				else
					error("Edges Index: " .. tostring(index) .." 'to' key's value must be either a string or an array of strings")
					return
				end
			end
		end
	end

    -- Set our local current to either a defined current, the initial state, or nil
	current = machine.current or machine.initial

	--- Currently active state
    --- @type string
    --- @type nil On machine initialization
	machine.current = get_current
	--- State the machine was last in.
    --- @type string
    --- @type nil On machine initialization
	machine.last = get_last
	--- State the machine is currently transitioning to. 
    --- @type string Inside a callback
	--- @type nil Outside of a callback
	machine.to = get_to
    --- State the machine is currently transitioning to. 
    --- @type string Inside a callback
	--- @type nil Outside of a callback
	machine.from = get_from

	-- State the machine may transition into if given the next() command.
	-- Nil if the current state is nil or there are more than one edge
	machine.get_next = get_next
	-- Transitions to the given state if able.
	machine.transition = transition
	-- Transitions from the current state to the next if there is only one edge
	machine.next = next

    -- Extract the states from the edges table
	local states = {}

	for k, v in pairs(machine.edges) do
		for _, val in pairs(v) do
			states[#states + 1] = val
		end
	end

	machine.states = {}

    -- For each unique key in the state list define the valid callback handles
	for k, v in pairs(invert(states)) do
		machine[k] = machine[k] or {onenter = nil, onexit = nil}
        machine[k].transition = function(...) machine:transition(k, ...) end
	end

    -- Assign this table as a metatable to the passed table, turning it into a FSM
	setmetatable(machine, M)

	return machine
end

return M