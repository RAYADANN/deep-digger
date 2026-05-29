# STATUS.md — Deep Digger 🪨

> Состояние проекта, заглушки и планы.
> Обновлено: 2026-05-29

### Последнее (29.05)
- Блок 4.5 студа
- Hover: PointLight (свечение) + золотая рамка по граням
- Разрушение: Tween-сжатие + проваливание (0.25 сек)
- Частицы при каждом ударе
- Атмосферная пыль в шахте
- Спарклы на epic+ рудах
- Damage Number: scale-up + bounce
- HP бар: rounded corners, Tween-заполнение

---

## 🏗 Архитектура

```
Поверхность: 15×15×10 (2250 блоков, Y=0..9)
Шахта:      чанки 5×5×5 (125 блоков) при углублении, по центру копания
Блок:       3×3×3 студа, CanCollide=true
Чанки:      ленивая генерация, всё старьё остаётся (дырки)
Глубина:    прогресс-метры, не сдвигает видимые блоки
Ключи:      "x_z_y"
```

---

## ✅ Готово

### Сервер
| Файл | Что делает |
|------|------------|
| `init.server.lua` | Точка входа, загрузка профиля, синхронизация чанков, MineBlock |
| `core/MiningEngine.lua` | Чанки 15×15×10 + 5×5×5, _mined, _mineCenter, слои, шахты, дроп |
| `core/OreDatabase.lua` | 13 руд (6 Dirt + 7 Stone) с редкостью |
| `core/ProfileManager.lua` | ProfileService: загрузка/автосохранение/релиз |
| `core/AntiCheat.lua` | Лимит 15 кликов/сек |

### Клиент
| Файл | Что делает |
|------|------------|
| `init.client.lua` | Точка входа, запуск рендера, чат-команды (/rarity, /hpbar, /help) |
| `core/MiningRenderer.lua` | 3D-блоки, CanCollide, ClickDetector, HP бар при hover, Damage Numbers, rarity tags, hover-подсветка |

### Shared
| Файл | Статус |
|------|--------|
| `constants.lua` | Все константы: слои, сетка, улучшения, шансы |
| `util/Logger.lua` | ✅ |
| `util/Signal.lua` | ✅ Свой Signal |
| `types/OreTypes.lua` | ✅ OreDef, OreInstance, PlayerData |

---

## 🟠 Заглушки / частично

| Файл | Проблема |
|------|----------|
| `core/EconomyManager.lua` | buyUpgrade/sellAll — заглушка |
| `core/AchievementManager.lua` | Класс есть, но ачивки не подключены |
| `core/Leaderboard.lua` | Пустышка, не падает |

---

## 🔴 Чего нет

### Клиент (`src/client/`)
- `core/UIController.lua`
- `core/CameraController.lua`
- `core/EffectsManager.lua`
- `ui/HUD.lua`
- `ui/ShopUI.lua`
- `ui/BossUI.lua`

### Shared (`src/shared/`)
- `util/TableUtils.lua`
- `util/MathUtils.lua`
- `util/Promise.lua`
- `util/RemoteWrapper.lua`
- `types/PlayerData.lua`
- `types/ShopTypes.lua`

---

## 📋 MVP

| Этап | Статус | Заметки |
|------|--------|---------|
| 1. Архитектура | ✅ | Rojo, Wally, Signal, Net, ProfileService |
| 2. MiningEngine | ✅ | Чанки, Mine Shafts, AntiCheat, CanCollide, дырки |
| 3. Руды | 🟡 | Damage Numbers ✅, частицы ✅, редкость тоглится `/rarity` |
| 4. Экономика + Магазин | 🟠 | EconomyManager — заглушка |
| 5. Слои + Глубина | 🟡 | Логика в MiningEngine, нет отдельного модуля |
| 6. Прогрессия | 🔴 | — |
| 7. Босс (Stone Guardian) | 🔴 | — |
| 8. Сохранения | ✅ | ProfileManager |
| 9. UI + Полировка | 🟡 | HP bar, hover, damage numbers есть. HUD/магазина нет |
| 10. Тестирование | 🔴 | — |

---

## 🎮 Команды (в чат)
- `/rarity` — показать/скрыть полоски редкости над блоками
- `/hpbar` — показать/скрыть HP бар при наведении
- `/help` — список команд

---

## 🐛 Known Issues (закрыты)
| Проблема | Решение |
|----------|---------|
| Logger `...: any` в type definition | → `...any` |
| Signal не было модуля | Создан свой |
| Require пути через `script.shared.*` | → `game:GetService("ReplicatedStorage")` |
| `OnServerInvoke` → `sleitnick/net` API | → `Net:Handle()` |
| Mined блоки пересоздавались | Добавлен `_mined[]` |
| Вся поверхность удалялась при сдвиге Y | Окно видимости фиксировано |
| Чанки в центре (0,0) | → `_mineCenter[userId]` |
| BindToClose на клиенте | → AncestryChanged |
