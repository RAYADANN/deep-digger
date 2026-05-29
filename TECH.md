# Tech Stack — Deep Digger 🪨

> **Версия:** 1.0  
> **Дата:** 2026-05-27  
> **Цель:** Масштабируемая, модульная, оптимизированная архитектура для 100k+ пользователей

---

## 1. Инструменты разработки

| Инструмент | Назначение | Установка |
|-----------|-----------|-----------|
| **Rojo** | Синхронизация .lua файлов с Roblox Studio | `wally install` |
| **Wally** | Пакетный менеджер для Luau | Через `wally init` |
| **Aftman** | Управление версиями инструментов (Rojo, stylua) | `aftman install` |
| **StyLua** | Автоформаттер кода Luau | Через Aftman |
| **VS Code** | Редактор кода | Расширение: Rojo + Luau Language Server |
| **Git** | Контроль версий | `git init` |

---

## 2. Библиотеки (Wally)

```toml
# wally.toml
[package]
name = "stellerscript/deep-digger"
version = "0.1.0"
registry = "https://github.com/UpliftGames/wally-index"

[dependencies]
# ===== Data =====
ProfileService = "loleris/profile-service@1.4.2"
# Управление DataStore: автосохранение, кэш, очереди, fallback
# Всё, что нужно для сохранения/загрузки прогресса игрока
# Не нужно писать SaveManager с нуля

# ===== Networking =====
Net = "sleitnick/net@2.0.1"
# Обёртка над RemoteEvents/RemoteFunctions
# Типизация, блокировка спама, автоматическое определение клиент/сервер
# Вместо ручных RemoteEvent + OnServerEvent

# ===== UI =====
Fusion = "elttob/fusion@0.3.1"
# Реактивный UI-фреймворк (как React для Luau)
# Декларативное создание UI, автоматическое обновление при изменении данных
# Позволяет писать меньше кода для интерфейсов

# ===== Async =====
Promise = "evaera/promise@4.0.0"
# Асинхронные операции (DataStore, HTTP запросы)
# Избавляет от callback hell, упрощает pcall

# ===== Utilities =====
Signal = "sleitnick/signal@1.0.1"
# Реализация Observer pattern (подписка на события)

Llama = "sleitnick/llama@1.1.0"
# Утилиты для работы с таблицами (map, filter, merge)
# Универсально — можно перенести в любой проект

# ===== Math =====
Lune = "sleitnick/lune@1.0.2"
# Дополнительные математические функции (lerp, clamp, round)
```

---

## 3. Архитектура проекта

```
src/
├── shared/                    ← Код, доступный и серверу, и клиенту
│   ├── modules/               ← Библиотеки (wally зависимости)
│   ├── util/                  ← Универсальные утилиты (можно перенести в любой проект)
│   │   ├── TableUtils.lua     ← filter, map, merge (обёртка над Llama)
│   │   ├── MathUtils.lua      ← lerp, clamp, round (обёртка над Lune)
│   │   ├── Signal.lua         ← события (обёртка над одноимённой библиотекой)
│   │   ├── Promise.lua        ← асинхронность (обёртка)
│   │   └── RemoteWrapper.lua  ← универсальная обёртка над Net
│   ├── types/                 ← Типы данных
│   │   ├── OreTypes.lua       ← таблицы руд
│   │   ├── PlayerData.lua     ← структура данных игрока
│   │   └── ShopTypes.lua      ← структуры для магазина
│   └── constants.lua          ← общие константы (слои, цвета, формулы)
│
├── server/                    ← Серверный код (только исполняется на сервере)
│   ├── core/                  ← Ключевые модули игры
│   │   ├── ProfileManager.lua ← ProfileService: создание/загрузка/сохранение профилей
│   │   ├── MiningEngine.lua   ← механика: удар, урон, разрушение, спавн блоков
│   │   ├── LayerManager.lua   ← слои, глубиномер, переходы
│   │   ├── EconomyManager.lua ← монеты, покупки, улучшения, продажа руд
│   │   ├── ShaftManager.lua   ← Mine Shafts: открытие, генерация блоков
│   │   ├── BossEngine.lua     ← боссы: появление, таймер, награды
│   │   ├── AntiCheat.lua      ← валидация: не больше 15 кликов/сек, проверка данных
│   │   └── Leaderboard.lua    ← глобальный лидерборд через MemoryStore
│   ├── init.server.lua        ← точка входа (запускает все core-модули)
│
├── client/                    ← Клиентский код (только на клиенте)
│   ├── core/
│   │   ├── UIController.lua   ← управление состояниями UI (экраны, переходы)
│   │   ├── CameraController.lua ← камера (следит за глубиной, плавно двигается)
│   │   └── EffectsManager.lua  ← частицы, звуки, damage numbers
│   ├── ui/
│   │   ├── HUD.lua            ← глубина, монеты, статы (Fusion)
│   │   ├── ShopUI.lua         ← магазин (Fusion)
│   │   ├── SettingsUI.lua     ← настройки (Fusion)
│   │   └── BossUI.lua         ← экран босса (Fusion)
│   └── init.client.lua        ← точка входа клиента
│
├── test/                      ← Тесты (если будут)
│   └── MiningEngine_spec.lua
│
└── default.project.json       ← Rojo конфиг
```

---

## 4. Рендер: Part'ы на клиенте

Блоки шахты — **3D Part'ы**, создаваемые **на клиенте** (в LocalScript).
Сервер не создаёт ни одного Instance. Только данные в таблице.

**Как это работает:**
1. Сервер хранит состояние блоков в памяти: `{ [playerId] = { [key] = { oreId, hp } } }`
2. При заходе в игру сервер отправляет клиенту массив видимых блоков через RemoteEvent
3. Клиент создаёт Part'ы в workspace с ClickDetector'ами
4. При клике клиент отправляет запрос серверу через RemoteFunction
5. Сервер валидирует, считает урон, дропает руду, шлёт ответ
6. Клиент анимирует разрушение / обновляет визуал

**Параметры Part'ов для производительности:**
```lua
part.Anchored = true
part.CanCollide = false
part.CanTouch = false
part.CastShadow = false
part.Material = Enum.Material.SmoothPlastic
```

**Сколько Part'ов:** 25 колонок × 12 рядов = 300 Part'ов на клиенте. 
Для Roblox — лёгкая нагрузка. Телефоны держат 500+ Part'ов.

## 5. Клиент-серверная модель

```
[КЛИЕНТ]                        [СЕРВЕР]
   │                                │
   │  кликнул по блоку              │
   │──MineBlock(blockId)────────▶│  │
   │                                │  ┌─ AntiCheat: проверка
   │                                │  │  - не чаще чем 15/сек
   │                                │  │  - блок существует
   │                                │  └─ игрок может бить этот блок
   │                                │
   │                                │  block.HP -= player.Power
   │                                │
   │  ┌─ block.HP > 0?             │
   │  │  да: BlockDamaged(id, hp)──│  │
   │  │  нет: BlockBroken(id, руда)│  │
   │  │  + InventoryUpdate(items)  │  │
   │                                │
   │  обновляем UI                  │
   │  дёргаем анимацию              │
```

### Правила:

| Что | Где | Почему |
|-----|-----|--------|
| **Прогресс игрока** | Сервер | Клиент не трогает DataStore |
| **Урон по блоку** | Сервер | Предотвращает читы (бесконечный урон) |
| **Спавн блоков** | Сервер | Определяет тип руды по глубине |
| **Инвентарь + монеты** | Сервер | Клиент видит только копию |
| **UI-логика** | Клиент | Открытие/закрытие меню, анимации |
| **Камера** | Клиент | Лагает если через сервер |
| **Тип блока** | Клиент (запрос) | Сервер подтверждает тип при ударе |
| **Подсказки (туториал)** | Клиент | Не критично, можно офлайн |

---

## 5. Оптимизация для 100k+ пользователей

### 5.1 RemoteEvent лимиты

- Roblox лимит: ~250 RemoteEvent вызовов/сек на сервер
- Для 10–50 игроков на сервер — **не критично**
- Тем не менее используем батчинг: клиент накапливает клики за 0.1 сек и отправляет пачкой

```lua
-- Клиент: накопление кликов
local clickBuffer = {}
local FLUSH_INTERVAL = 0.1 -- 100ms

local function flushClicks()
    if #clickBuffer > 0 then
        Net:FireServer("MineBlocks", clickBuffer)
        clickBuffer = {}
    end
end

-- Каждые 100мс отправляем пачку
task.spawn(function()
    while task.wait(FLUSH_INTERVAL) do
        flushClicks()
    end
end)
```

### 5.2 Instance лимиты

- На сервере **ноль Part'ов**. Только таблицы в памяти.
- 300 Part'ов на клиенте — лёгкая нагрузка.
- Для сравнения: обычная Roblox игра с 50 игроками × персонажи/аксессуары имеет 5000+ Instance'ов.

### 5.3 Оптимизация для 10–50 игроков/сервер

- Это стандартный размер Roblox сервера
- 300 Part'ов × 50 игроков = 15,000 Part'ов **всего** (на разных клиентах, не на одном)
- Сервер обрабатывает только текстовые данные — это копейки

### 5.4 DataStore

- ProfileService автоматически:
  - Кэширует данные в памяти
  - Сохраняет каждые ~60 сек (регулируется)
  - Обрабатывает DataStore failures (retry)
  - Lock игрока при загрузке (предотвращает потерю данных)

### 5.4 MemoryStore (лидерборд)

- Для глобальной таблицы лидеров использовать MemoryStore (а не DataStore)
- MemoryStore быстрее и рассчитан на частые чтения/записи

### 5.5 Оптимизация UI

- Использовать Fusion с ScrollingFrame — виртуализация списков
- Не обновлять весь HUD каждый frame, только при изменении данных
- Избегать `GetChildren()`/`GetDescendants()` в горячих циклах

---

## 6. Модульность и переиспользование

Каждый модуль спроектирован так, чтобы его можно было вытащить в другой проект.

### Модули общего назначения (можно перенести в любой Roblox проект):

| Модуль | Зависимости | Куда перенести |
|--------|------------|----------------|
| `util/TableUtils` | Llama | Любой проект |
| `util/MathUtils` | Lune | Любой проект |
| `util/RemoteWrapper` | Net | Любой проект с RemoteEvents |
| `core/ProfileManager` | ProfileService, Promise | Любой проект с DataStore |
| `core/AntiCheat` | — | Любой проект с кликером |

### Модули Deep Digger (привязаны к игре):

| Модуль | Привязан к |
|--------|-----------|
| MiningEngine | Механике добычи |
| LayerManager | Системе слоёв |
| ShaftManager | Шахтам |
| BossEngine | Боссам |
| EconomyManager | Экономике |

### Как изолировать:

```lua
-- Пример: ProfileManager можно вытащить в другой проект
-- достаточно поменять структуру PlayerData
local ProfileManager = {
    TEMPLATE = {
        coins = 0,
        gems = 0,
        depth = 0,
        pickaxeLevel = 1,
        speedLevel = 1,
        inventory = {},
    },
    -- Методы универсальны для любой игры с сохранениями
    load = function(player) ... end,
    save = function(player) ... end,
    get = function(player) ... end,
    update = function(player, key, value) ... end,
}
```

---

## 7. Установка и запуск

```bash
# 1. Клонировать репозиторий
cd C:\Projects\Roblox\Mining

# 2. Инициализировать Wally
wally init
# → создаст wally.toml

# 3. Установить зависимости
wally install

# 4. Запустить синхронизацию с Roblox Studio
rojo serve
# → в Studio: подключиться через Rojo plugin (подключение к localhost)

# 5. Редактировать код в VS Code
# → Rojo автоматически синхронизирует изменения
```

---

## 8. Структура данных игрока (PlayerData)

```lua
local DEFAULT_PROFILE = {
    -- Прогресс
    depth = 0,              -- текущая глубина в метрах
    layer = "dirt",         -- текущий слой
    
    -- Экономика
    coins = 0,
    gems = 0,
    
    -- Улучшения
    pickaxeLevel = 1,
    speedLevel = 1,
    fortuneLevel = 1,
    inventoryLevel = 1,
    critLevel = 1,
    multiSellLevel = 1,
    autoSellUnlocked = false,
    
    -- Инвентарь (руды, которые ещё не проданы)
    inventory = {},         -- { [oreId] = quantity }
    
    -- Статистика
    totalBlocksMined = 0,
    totalCoinsEarned = 0,
    bossesDefeated = 0,
    
    -- Босс
    currentBoss = nil,      -- ID активного босса (если есть)
    bossTimer = nil,        -- оставшееся время
    
    -- Шахты
    shaftsFound = {},       -- найденные шахты
    
    -- Мета
    lastSave = os.time(),
    playTime = 0,           -- общее время в игре (сек)
}
```

---

## 9. Rojo конфиг

```json
{
  "name": "deep-digger",
  "tree": {
    "$className": "DataModel",
    "ReplicatedStorage": {
      "$className": "ReplicatedStorage",
      "shared": {
        "$path": "src/shared"
      }
    },
    "ServerScriptService": {
      "$className": "ServerScriptService",
      "server": {
        "$path": "src/server"
      }
    },
    "StarterGui": {
      "$className": "StarterGui",
      "client": {
        "$path": "src/client"
      }
    }
  }
}
```

---

## 10. Принципы кодирования

1. **Никаких глобальных переменных** — всё через ModuleScript:return
2. **Типизация** — используем Luau type annotations (--!strict)
3. **Сервер — источник правды** — клиент никогда не доверяет своим данным
4. **Батчинг RemoteEvent'ов** — пачки, не одиночные вызовы
5. **No yielding на клиенте** — UI не должен тормозить из-за DataStore
6. **Изолированные модули** — каждый модуль можно протестировать отдельно
7. **Единый стиль кода** — StyLua форматтер, 4 пробела, lowercase переменные
