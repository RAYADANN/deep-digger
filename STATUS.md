# STATUS.md — Deep Digger 🪨

> Состояние проекта, заглушки и планы.
> Обновлено: 2026-06-02
> **Scope расширен:** MVP теперь launch-ready (pets, rebirth, monetization, leaderboard, daily). См. MVP.md.

---

## 🏗 Архитектура

```
Движок:      Neighbor Reveal — блоки генерируются при разрушении соседних
Поверхность: 15×15×10 (2250 блоков) при старте
Расширение:  бесконечное по X, Z, Y (6 направлений по 3D-граням)
Блок:        4.5×4.5×4.5 студа, CanCollide = true
Позиция:     Z=30 перед игроком, Y=0 на уровне ног
Ключи:       "x_z_y"
UI:          Fusion 0.3 (scope: Value, New, Computed, OnEvent)
Сеть:        SyncBlocks { kind = "snapshot" | "delta", payload }
             snapshot → один раз при заходе/reset
             delta    → { created, updated, removed } после каждого удара
```

---

## ✅ Готово

### Сервер
| Файл | Что делает |
|------|------------|
| `init.server.lua` | Точка входа, MineBlock + дельта-флаш, depth-sync, notify |
| `core/MiningEngine.lua` | Neighbor Reveal, валидация exposed-блоков, дельта в `blockDelta` |
| `core/OreDatabase.lua` | 31 руда, 7 слоёв (Dirt → Void) |
| `core/ProfileManager.lua` | ProfileService, автосохранение, данные игрока |
| `core/AntiCheat.lua` | CPS, лимит батча `MAX_MINE_BATCH_SIZE`, swing-кулдаун |
| `core/EconomyManager.lua` | BuyUpgrade/SellOres, multiSell, autoSell |
| `core/MiningLoot.lua` | Fortune-ролл, capacity + autoSell |
| `core/DevCommands.lua` | `/coins`, `/reset`, `/maxlvl`, `/devhelp` (Studio) |

### Клиент
| Файл | Что делает |
|------|------------|
| `init.client.lua` | Точка входа, рендер + HUD + PlayerStats + Notify |
| `core/MiningRenderer.lua` | 3D-блоки, applySnapshot/applyDelta, HP-bar, hover, частицы |
| `core/DepthTracker.lua` | Клиентский трекер глубины по `HumanoidRootPart.Y` |
| `core/LayerEnvironment.lua` | Твин `Lighting.Ambient/OutdoorAmbient/FogColor` по слою |
| `ui/HUD.lua` | Fusion-фасад: монеты, глубина, уровни, кнопки апгрейдов, SELL |
| `ui/Notification.lua` | Переиспользуемая всплывашка |

### Shared
| Файл | Что делает |
|------|------------|
| `constants.lua` | Слои, сетка, апгрейды, RARITY_*, SHAFT_* |
| `util/LayerUtil.lua` | depth↔layer, colorToPayload |
| `util/UpgradeLogic.lua` | Все формулы апгрейдов |
| `util/InventoryUtil.lua` | totalCount, addOre |
| `util/Logger.lua`, `util/Signal.lua` | Утилиты |
| `types/OreTypes.lua` | Типы данных |

---

## 🟠 Заглушки
- `AchievementManager.lua` — не подключён в MVP (после).
- `Leaderboard.lua` — пустышка.

---

## 🔴 Чего нет в коде, но **должно быть к релизу** (Фазы 7-13)

| Модуль | Фаза |
|--------|------|
| `client/core/CameraShake.lua` | 7 (game feel) |
| `client/ui/Tutorial.lua` | 8 (онбординг) |
| `server/core/RebirthManager.lua` | 9 (prestige) |
| `server/core/DailyReward.lua` | 10 (retention) |
| `shared/data/PetDatabase.lua` | 11 (pets) |
| `server/core/PetManager.lua` | 11 (pets) |
| `server/core/EggManager.lua` | 11 (pets) |
| `client/ui/PetsPanel.lua` | 11 (pets) |
| `server/core/MonetizationManager.lua` | 12 (revenue) |
| `Constants.GAMEPASSES`, `Constants.DEVPRODUCTS`, `Constants.REBIRTH` | 9, 12 |

## 🔴 Post-MVP (патчи 1.1, 1.2 и большие апдейты)
- Trading между игроками.
- Achievements (`AchievementManager` есть, подключить).
- BossEngine, Mine Shafts как отдельная фича.
- Limestone+ контент-пасс.
- Гильдии / кланы, limited events.
- Расходники (молоток/бомба), гемы и магазин за гемы.

---

## 📋 MVP по фазам

| Фаза | Статус |
|------|--------|
| 0. Scope | 🟢 |
| 1. Фундамент и баги | 🟢 |
| 2. Экономика | 🟢 |
| 3. Апгрейды | 🟢 |
| 4. Прогрессия слоёв | 🟢 |
| 5. Сеть и производительность | 🟢 (требуется плейтест-профайл) |
| 6. Один источник данных по рудам | 🔴 |
| 7. Game Feel & Juice (звуки, screen shake) | 🔴 |
| 8. Онбординг и UX (туториал, error UX) | 🔴 |
| 9. Rebirth / Prestige | 🔴 |
| 10. Daily reward + Leaderboard | 🔴 |
| 11. Pets MVP (5-10 петов, egg) | 🔴 |
| 12. Монетизация (3-4 gamepass + 2-3 devproduct) | 🔴 |
| 13. Визуальная идентичность (материалы, key art) | 🔴 |
| 14. Soft launch и стабилизация | 🔴 |

---

## 🎮 Команды
- `/rarity` — полоски редкости
- `/hpbar` — HP бар при наведении
- `/coins <N>`, `/reset`, `/maxlvl`, `/devhelp` — только Studio
- `/help` — список

---

## 📊 Чек-лист профилирования Фазы 5

Пройти 10+ минут активного копания в Studio с MicroProfiler и убедиться:

- [ ] **ScriptContext (Server)** — нет монотонного роста времени на тик. Спайки только в моменты `MineBlock` (норма).
- [ ] **RemoteEvent OutgoingDataKB/s** — после первого `snapshot` (~2250 блоков) исходящий трафик резко падает. На активном копании держится десятки B/s на дельту, не килобайты.
- [ ] **FPS** — клиент не проседает <50 FPS на ~2000 видимых партах. Если проседает — смотреть `MiningRenderer:_createPart` (BillboardGui/ParticleEmitter).
- [ ] **Memory (Server)** — `self._blocks[uid]` растёт линейно с количеством раскопанных блоков. Освобождается при `resetPlayer` (выход игрока).
- [ ] **Tasks scheduled** — `_animateDestroy` через 0.3 с чистит partы; в `_parts`/`_blockData` нет осиротевших ключей после серии разрушений.
- [ ] **Второй аккаунт** — два игрока на одном сервере, дельты идут только своему игроку (`FireClient`, не `FireAllClients`).
- [ ] **Античит** — фастклик `/onclick` (или AutoHotkey) триггерит `Too many clicks` / `Too fast` уже на батч >16 или CPS >20.

Если все галочки зелёные → Фаза 5 закрыта окончательно, можно переходить к Фазе 6 (`OreDatabase` как единственный источник для клиентских цветов/редкостей).

---

## 📊 Git
- `main`
- GitHub: `github.com/RAYADANN/deep-digger`
