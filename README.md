# Luasm
A simple finite state machine implementation with a clear API.

## Install
Download [luasm.lua](./luasm.lua).

## Use
### Quickstart
```lua
local luasm = require('luasm') -- Include luasm in your project

-- Declare a table containing a list of directed edges to initialize the state machine
local game_state = {
    edges = { -- Required; List of directed edges
        {from = 'splash', to = 'menu'},
        {from = 'menu', to = {'settings', 'game'}},
        {from = 'settings', to = {'menu', 'game'}},
        {from = 'game', to = {'settings', 'menu'}},
    },
    initial = 'splash', -- Optional; Starting state
    splash = { -- Optional; Callbacks for a specific state's transitions
        -- Access the state being left and the state being entered with .from() and .to() respectively
        onexit = function(self) print("Left " .. self.from()  .. " for " .. self.to()) end, 
        onenter = function(self, logo, msg, var_3) -- Pass any number of arguments
            print("Entering splash")
            display(logo)
            print(msg) 
        end, 
    }
}

-- Make a finite state machine out of the table.
local game_state_machine = luasm.make(game_state)

-- Transition from single-edged states using machine:next(...)
print(game_state_machine.current()) -- splash
game_state_machine:next() -- Executes game_state_machine.splash:onexit; prints "Left splash for menu"
print(game_state_machine.current()) -- menu

-- Set callbacks after initialization
game_state_machine.menu.onexit = function(self, exit_msg) print("Leaving menu: " .. exit_msg) end

-- Transition from multi-edged states using machine:transition(to_state, ...)
-- Sends the string 'Have fun in settings!' to the onexit callback of the current state and to the onenter callback of settings
game_state_machine:transition('settings', 'Have fun in settings!') -- prints "Leaving menu: Have fun in settings!"
print(game_state_machine.current()) -- settings

-- Alternatively, reference the to_state's transition directly using machine.state.transition(...)
game_state_machine.game.onenter = function(self, name) print("Starting awesome game: " .. name) end
game_state_machine.game.transition('FTL') -- Executes game_state_machine.game:onenter; prints "Starting awesome game: FTL"
print(game_state_machine.current()) -- game

-- For states with multiple entry points access the previous state with machine.last()
game_state_machine:transition(game_state.last()) -- Transitions from game back to settings
print(game_state_machine.current()) -- settings
```

### In Depth
Include **luasm** in your project like:

```lua
local luasm = require('luasm')
```

Initialize a finite state machine by passing a table to `luasm.make()`. That table only requires one entry; `edges`, a table of directed edges where each edge is defined by a `from` state and a `to` state. Optional keys include `initial` to set the starting state of the machine, and a table for each state with a list of callbacks. Valid callbacks are `onexit` and `onenter` and have a signature of `function(self, ...)`.

```lua
-- Make a finite state machine out of the table.
local game_state_machine = luasm.make({
    edges = { -- Required; List of directed edges
        {from = 'splash', to = 'menu'},
        {from = 'menu', to = {'settings', 'game'}},
        {from = 'settings', to = {'menu', 'game'}},
        {from = 'game', to = {'settings', 'menu'}},
    },
    initial = 'splash', -- Optional; Starting state
    splash = { -- Optional; Callbacks for a specific state's transitions
        -- Access the state being left and the state being entered with .from() and .to() respectively
        onexit = function(self) print("Left " .. self.from()  .. " for " .. self.to()) end, 
        onenter = function(self, logo, msg, var_3) -- Pass any number of arguments
            print("Entering splash")
            display(logo)
            print(msg) 
        end, 
    }
})
```

Callbacks execute *prior* to the execution of the transition. The state being left can be accessed with `self.from()` (an alias of current) and the one being entered with `self.to()`.

Declare callbacks after initialization of the machine with a function that has the signature `function(self, ...)`.

```lua
game_state_machine.menu.onexit = function(self, exit_msg) print("Leaving menu: " .. exit_msg) end
```

Transition states using the `machine:next(...)` method if your current state has only one edge or `machine:transition(to_state, ...)` to define which state to transition to. Alternatively, you can use the state's function table directly using `machine.state.transition(...)` syntax.

```lua
game_state_machine:next() -- Transitions from current state to the next state if single-edged
-- Transition to the settings state 
-- Sends the string 'Have fun in settings!' to the onexit callback of the current state and to the onenter callback of settings
game_state_machine:transition('settings', 'Have fun in settings!')
game_state_machine.game.transition('FTL') -- Transitions to the game state while sending the string 'FTL' to the onexit and onenter callbacks
```

Using the `machine.state.transition()` syntax could allow the user to further qualify the execution order of the transition by creating a wrapper around the `machine:transition(to_state, ...)`. For example, the user could declare callbacks that execute before the state's default callbacks or after the state has fully transitioned.

```lua
local function pretransition_fn(...)
    print "Pre-transition!"
end
local function posttransition_fn(...)
    print "Post-transition!"
end

game_state_machine.game.onenter = function(self, name) print("Starting " .. name) end

-- pretransition_fn precedes the onexit and onenter callbacks
-- posttransition_fn executes after the state machine has completed changing states
game_state_machine.game.transition = function(...) 
    pretransition_fn(...)
    game_state_machine:transition('game', ...)  -- Be sure to include this line or you will not trigger an actual state transition.
    posttransition_fn(...) 
end  

game_state_machine.game.transition('FTL') -- prints "Pre-transition!" \n "Starting FTL" \n "Post-transition!"
```

Example of accidentally breaking the function by overwriting the internal call to `machine:transition(to_state, ...)`.

```lua
print(game_state_machine.current()) -- settings
game_state_machine.game.transition = function(...) print "Transitioning!"
game_state_machine.game.transition('FTL') -- prints "Transitioning!" but does not transition the state machine
print(game_state_machine.current()) -- settings
```

## API
### `luasm.make(t)` 
- Params: `t` a table containing a list of directed **edges**. Ex. `states = {edges = {from = 'start', to = 'end'}}`.
- Returns: A finite state machine built from the given table.

Creates a finite state machine from the given table. Fails with an error if the given table does not contain a key-value set of edges as described above.

### `machine:next(...)`
- Params: `...` args that are passed on to the `onexit` and `onenter` callbacks, if they exist for the involved states.

If the current state is single edged this transitions to the next state, else it fails and warns the user.

### `machine.transition(to_state, ...)`
- Params: `to_state` the string name of the state to tranisition to.
- Params: `...` args that are passed on to the `onexit` and `onenter` callbacks, if they exist for the involved states.

Transitions to the given state if able, else it fails and warns the user.

### `machine.state.onexit | machine.state.onenter = function(self, ...)`

Declare `onexit` and `onenter` callbacks for the given state. The callbacks' function signatures must be of the form `funciton(self, ...)`.

### `machine.current()`

Returns the name of the current state or `nil` if uninitialized.

### `machine.last(index)`
- Params: `index` the index from the top of the history stack. Defaults to `0`.

Returns the name of the last `index`th state from the top of the state history stack, or `nil` if uninitialized.

Ex. 
```lua
print(machine.current()) -- start
machine:next() -- state_one
machine:next() -- state_two

print(machine.current()) -- state_two
print(machine.last()) -- state_one ; Equivalent to machine.last(0)
print(machine.last(1)) -- start
```

### `machine.from()`

Alias for `machine.current()`. Returns the name of the state being transitioned from inside a callback, else `nil`.

### `machine.to()`

Returns the name of the state being transitioned to inside a callback, else `nil`.
