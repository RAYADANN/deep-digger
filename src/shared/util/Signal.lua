--!strict
-- Signal.lua — реализация Observer pattern.
-- API-совместим со sleitnick/signal, но легче.
-- 
-- Использование:
--   local sig = Signal.new()
--   local conn = sig:Connect(handler)
--   sig:Fire(arg1, arg2)
--   conn:Disconnect()
--   sig:Wait()  -- yields until fired

local Signal = {}
Signal.__index = Signal

export type Connection = {
    Disconnect: (self: Connection) -> (),
    Connected: boolean,
}

export type Signal = {
    new: () -> Signal,
    Connect: (self: Signal, callback: (...any) -> ()) -> Connection,
    Fire: (self: Signal, ...any) -> (),
    DisconnectAll: (self: Signal) -> (),
    Wait: (self: Signal) -> ...any,
    Destroy: (self: Signal) -> (),
}

function Signal.new(): Signal
    local self = setmetatable({}, Signal)
    self._handlers = {} :: { (...any) -> () }
    self._destroyed = false
    return self
end

function Signal:Connect(callback: (...any) -> ()): Connection
    table.insert(self._handlers, callback)
    local connection: Connection = {
        Connected = true,
        Disconnect = function()
            connection.Connected = false
            for i, handler in ipairs(self._handlers) do
                if handler == callback then
                    table.remove(self._handlers, i)
                    break
                end
            end
        end,
    }
    return connection
end

function Signal:Fire(...: any)
    if self._destroyed then return end
    -- Копируем список, чтобы добавление/удаление во время Fire не ломало
    local handlers = table.clone(self._handlers)
    for _, handler in ipairs(handlers) do
        task.spawn(handler, ...)
    end
end

function Signal:DisconnectAll()
    self._handlers = {}
end

function Signal:Wait(): any
    local thread = coroutine.running()
    local connection: Connection
    connection = self:Connect(function(...)
        connection:Disconnect()
        task.spawn(thread, ...)
    end)
    return coroutine.yield()
end

function Signal:Destroy()
    self._destroyed = true
    self:DisconnectAll()
end

-- Алиасы для удобства (строчные версии)
function Signal:connect(callback)
    return self:Connect(callback)
end

function Signal:fire(...)
    return self:Fire(...)
end

function Signal:disconnectAll()
    return self:DisconnectAll()
end

function Signal:wait()
    return self:Wait()
end

return Signal
