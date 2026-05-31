# STATUS.md — Deep Digger 🪨

> Состояние проекта, заглушки и планы.
> Обновлено: 2026-05-31

---

## 🏗 Архитектура

```
Движок:     Neighbor Reveal — блоки генерируются при разрушении соседних
Поверхность: 15×15×10 (2250 блоков) при старте
Расширение:  бесконечное по X, Z, Y (6 направлений по 3D-граням)
Блок:       4.5×4.5×4.5 студа, CanCollide = true
Позиция:    Z=30 перед игроком, Y=0 на уровне ног
Ключи:      "x_z_y"
UI:         Fusion 0.3 (scope: Value, New, Computed, OnEvent)
```

---

## ✅ Готово

### Сервер (6 файлов)
| Файл | Что делает |
|------|------------|
| `init.server.lua` | Точка входа, обработка кликов, синхронизация блоков + статов |
| `core/MiningEngine.lua` | Neighbor Reveal, поверхность, комнаты (15% шанс) |
| `core/OreDatabase.lua` | 31 руда, 7 слоёв (Dirt → Void) |
| `core/ProfileManager.lua` | ProfileService, автосохранение, данные игрока |
| `core/AntiCheat.lua` | Лимит 15 кликов/сек |
| `core/EconomyManager.lua` | 🟠 **Заглушка** — buyUpgrade/sellAll "Not implemented" |

### Клиент (4 файла)
| Файл | Что делает |
|------|------------|
| `init.client.lua` | Точка входа, рендер + HUD + PlayerStats |
| `core/MiningRenderer.lua` | 3D-блоки, HP bar, hover, частицы, уведомления о комнатах |
| `ui/HUD.lua` | Fusion HUD — монеты, глубина, уровни, кнопка SELL |
| `core/AchievementManager.lua` | 🟠 **Заглушка** |

### Shared (3 файла)
| `constants.lua` | Слои, сетка, улучшения, шансы |
| `util/Logger.lua` | Логирование |
| `util/Signal.lua` | Свой Signal |
| `types/OreTypes.lua` | Типы данных |

---

## 🟠 Заглушки
- `EconomyManager.lua` — нет продажи руд, покупок, монет
- `AchievementManager.lua` — не подключён
- `Leaderboard.lua` — пустышка
- HUD кнопка SELL — print("Sell!") вместо реальной продажи

---

## 🔴 Чего нет
- Инвентарь (UI списка руд)
- Магазин (ShopUI)
- LayerManager
- BossEngine
- CameraController, EffectsManager
- Звуки
- Туториал

---

## 📋 MVP

| Этап | Статус |
|------|--------|
| 1. Архитектура | ✅ |
| 2. MiningEngine | ✅ Neighbor Reveal |
| 3. Руды | ✅ 7 слоёв, 31 руда |
| 4. Экономика | 🟠 EconomyManager — заглушка |
| 5. Слои + Глубина | 🟡 В MiningEngine |
| 6. Прогрессия | 🔴 |
| 7. Боссы | 🔴 |
| 8. Сохранения | ✅ ProfileManager |
| 9. UI + Полировка | 🟡 HUD готов, инвентаря/магазина нет |
| 10. Тестирование | 🔴 |

---

## 🎮 Команды
- `/rarity` — полоски редкости
- `/hpbar` — HP бар при наведении
- `/help` — список

---

## 📊 Git
- 3 ветки: `main`
- 8 коммитов
- Последний: "HUD: clean mining incremental style"
- GitHub: `github.com/RAYADANN/deep-digger`
