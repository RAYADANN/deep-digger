--!strict
-- Logger.lua — универсальный логгер для любых Roblox проектов.
-- Уровни логирования: DEBUG, INFO, WARN, ERROR
-- Можно перенести в любой проект без изменений.

local Logger = {}
Logger.__index = Logger

export type LogLevel = "DEBUG" | "INFO" | "WARN" | "ERROR"
export type LoggerInstance = {
    debug: (self: LoggerInstance, message: string, ...any) -> (),
    info: (self: LoggerInstance, message: string, ...any) -> (),
    warn: (self: LoggerInstance, message: string, ...any) -> (),
    error: (self: LoggerInstance, message: string, ...any) -> (),
    setLevel: (self: LoggerInstance, level: LogLevel) -> (),
    setTag: (self: LoggerInstance, tag: string) -> (),
}

local LEVEL_MAP: { [LogLevel]: number } = {
    DEBUG = 0,
    INFO = 1,
    WARN = 2,
    ERROR = 3,
}

local LEVEL_NAMES: { [number]: string } = {
    [0] = "[DEBUG]",
    [1] = "[INFO] ",
    [2] = "[WARN] ",
    [3] = "[ERROR]",
}

-- Создаёт новый экземпляр логгера с тегом.
-- @param tag — имя модуля (например "MiningEngine")
-- @param minLevel — минимальный уровень для вывода (по умолчанию DEBUG)
-- @return LoggerInstance
function Logger.new(tag: string, minLevel: LogLevel?): LoggerInstance
    local self = setmetatable({}, Logger)
    self._tag = tag or "App"
    self._level = minLevel or "DEBUG"
    return self :: any
end

-- Устанавливает минимальный уровень логирования
function Logger:setLevel(level: LogLevel)
    self._level = level
end

-- Устанавливает тег модуля
function Logger:setTag(tag: string)
    self._tag = tag
end

-- Основной метод логирования
function Logger:_log(level: LogLevel, message: string, ...: any)
    local minLevelNum = LEVEL_MAP[self._level]
    local levelNum = LEVEL_MAP[level]
    if levelNum < minLevelNum then
        return
    end

    local levelStr = LEVEL_NAMES[levelNum] or "[????]"
    local timestamp = os.date("%H:%M:%S")
    local prefix = string.format("%s %s [%s]", timestamp, levelStr, self._tag)
    local extras = { ... }

    if #extras > 0 then
        local extraStr = ""
        for _, v in ipairs(extras) do
            extraStr = extraStr .. " " .. tostring(v)
        end
        print(prefix, message, extraStr)
    else
        print(prefix, message)
    end
end

-- Уровни-хелперы
function Logger:debug(message: string, ...: any)
    self:_log("DEBUG", message, ...)
end

function Logger:info(message: string, ...: any)
    self:_log("INFO", message, ...)
end

function Logger:warn(message: string, ...: any)
    self:_log("WARN", message, ...)
end

function Logger:error(message: string, ...: any)
    self:_log("ERROR", message, ...)
end

return Logger
