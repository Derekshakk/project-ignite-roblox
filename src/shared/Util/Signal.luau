--[[
	Signal

	Minimal event object so game logic can notify listeners (such as the UI)
	without knowing anything about them. Each handler runs in its own thread,
	so an error in one listener cannot break the caller or other listeners.
]]

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(handler: (...any) -> ())
	table.insert(self._handlers, handler)

	local signal = self
	local connection = { Connected = true }
	function connection:Disconnect()
		if not self.Connected then
			return
		end
		self.Connected = false
		local index = table.find(signal._handlers, handler)
		if index then
			table.remove(signal._handlers, index)
		end
	end
	return connection
end

function Signal:Fire(...: any)
	-- Clone so handlers that connect/disconnect while firing are safe.
	for _, handler in table.clone(self._handlers) do
		task.spawn(handler, ...)
	end
end

function Signal:DisconnectAll()
	table.clear(self._handlers)
end

return Signal
