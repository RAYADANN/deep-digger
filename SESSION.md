# SESSION.md — Быстрый старт после нового чата

> Читать первым при начале новой сессии.

---

## Состояние проекта

**Название:** Deep Digger 🪨
**Жанр:** Mining Incremental (Roblox)
**Оригинал:** Infinite Mining Incremental by StellarScript
**Стек:** Rojo + Wally, Fusion (UI), Net (сеть), ProfileService (сейвы)

**Дата последнего коммита:** 2026-05-29

---

## Текущая архитектура шахты

### Neighbor Reveal MiningEngine
- Блоки генерируются при разрушении соседнего (6 направлений по 3D-граням)
- Воздух (`_air`) трекается отдельно — не путается с не-сгенерированным
- Поверхность 15×15×10 при старте
- Бесконечное расширение во все стороны
- Дыр = нет (соседи сразу заполняют)

### Ключевые файлы

| Файл | Назначение |
|------|-----------|
| `src/server/core/MiningEngine.lua` | Neighbor Reveal, поверхность, комнаты |
| `src/client/core/MiningRenderer.lua` | 3D-рендер, HP bar, hover, particles |
| `src/server/init.server.lua` | Точка входа сервера |
| `src/client/init.client.lua` | Точка входа клиента, чат-команды |
| `src/shared/constants.lua` | Все константы (слои, сетка, улучшения) |

### Что работает
- ✅ 3D блоки 11×11×5 (поверхность + соседи) на Z=30 перед игроком
- ✅ CanCollide = true
- ✅ HP bar на hover (зелёный→жёлтый→красный)
- ✅ Damage Numbers при ударе
- ✅ Частицы при ударе и разрушении
- ✅ Hover: свечение + золотая рамка
- ✅ Комнаты (15% шанс, random walk)
- ✅ Чат-команды: `/rarity`, `/hpbar`, `/help`
- ✅ Сохранения (ProfileService, заглушка для Studio)

### Что НЕ работает / заглушки
- ❌ EconomyManager — buyUpgrade/sellAll возвращают "Not implemented"
- ❌ Leaderboard — пустышка
- ❌ AchievementManager — класс есть, не подключён
- ❌ Нет UI (HUD, магазин, boss screen)
- ❌ Нет LayerManager, BossEngine, AntiCheat как отдельных модулей
- ❌ Частицы — пользователь жаловался что не видны (возможно настроить)

---

## Куда двигаться дальше

### Приоритеты (MVP)

1. **EconomyManager** — монеты, продажа руд, покупка улучшений
2. **HUD (Fusion)** — монеты, глубина, урон/скорость
3. **ShopUI (Fusion)** — магазин с улучшениями
4. **Слои** — отдельный модуль LayerManager
5. **Боссы** — Stone Guardian на 100м
6. **Полировка** — звуки, туториал, анимации

---

## Важные ссылки

| Что | Где |
|-----|-----|
| Проект | `C:\Projects\Roblox\Mining\` |
| Статус | `STATUS.md` |
| GDD | `GDD.md` |
| MVP чек-лист | `MVP.md` |
| Тех. стек | `TECH.md` |
| Память | `memory/*.md` |
| Rojo serve | `C:\Rojo\rojo.exe serve` (порт 34872) |

---

## MCP — Roblox Studio доступ

У Старенького MCP Roblox сервер запущен в VS Code.
Я (Zeon) имею доступ к Studio через встроенные Roblox-инструменты OpenClaw:

**Как активировать:**
1. Я вижу Studio как `roblox-studio__list_roblox_studios`
2. Выбрать нужную: `roblox-studio__set_active_studio(studio_id)`
3. После этого работают:
   - `search_game_tree(path)` — иерархия объектов
   - `inspect_instance(path)` — свойства объекта
   - `script_read(file)` — чтение скриптов
   - `script_grep(query)` — поиск по скриптам
   - `execute_luau(code)` — запуск кода в Studio
   - `screen_capture()` — скриншоты

**Важно:** Основная разработка — через Rojo. Studio-инструменты — для отладки,
просмотра Workspace, проверки что синхронизировалось.

## Контакты

- **Старенький** — заказчик, тестирует в Studio
- **Zeon 🌀** — AI-разработчик
- Стиль: неформальный, по делу, русский язык
