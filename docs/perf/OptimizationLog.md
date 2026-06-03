# Deep Digger — лог оптимизации производительности (фризы при копании)

> Документ для передачи контекста в новый чат. Цель: **полностью убрать фризы при
> копании**. Ниже — что уже сделано, что замерено, текущий диагноз и план.
> Статус на момент написания: **фризы НЕ устранены** (худший кадр всё ещё 600–1300+ мс).

---

## 1. Симптом

- Игрок жалуется на **сильные просадки FPS / фризы при копании**, особенно при
  пробитии новых полостей/комнат.
- Это **не** стабильно низкий FPS, а **резкие подвисания** на 0.2–1.4 секунды.

---

## 2. Контекст игры

- Roblox mining-sim «Deep Digger», Rojo + Fusion 0.3.
- Шахта = папка `workspace.DeepDigger_Mine`, в ней **2250+ Part'ов** на старте,
  растёт до **2900+** за минуту копания (без culling'а).
- Архитектура синка: сервер шлёт `SyncBlocks` →
  `{ kind = "snapshot" | "delta", payload = ... }`.
  - `snapshot` — полная замена (один раз при входе, ~2250 блоков).
  - `delta` — `{ created = {...}, updated = {...}, removed = {...} }`.
    При пробитии полости сервер присылает **десятки–сотни** created-блоков разом.
- Ключевой клиентский файл: `src/client/core/MiningRenderer.lua`.
- Точка входа: `src/client/init.client.lua` (создаёт `renderer`, дергает
  `renderer:start()` на каждый `CharacterAdded`).

---

## 3. Что уже сделано (хронологически)

### 3.1. Phase 14 визуал (исходная задача, НЕ про перф)
- Заполнены `material`/`reflectance`/`glow` для 31 руды в
  `src/shared/data/OreDatabase.lua`.
- Per-layer lighting в `src/client/core/LayerEnvironment.lua` +
  `Constants.LAYER_LIGHTING` в `src/shared/constants.lua`.

### 3.2. Оптимизации рендера блоков (`MiningRenderer.lua`)
1. **`CastShadow = false`** на всех блоках (тени ~2250 партов — дорого).
2. **Ленивые BillboardGui**: HP-бар и rarity-плашка создаются по
   наведению/тогглу (`_ensureHPBar`, `_ensureRarityTag`), а не на каждый блок.
3. **Материалы**: убран `Glass` с массовых common/uncommon (заменён на
   `Marble`/`Slate`); `reflectance = 0` для common/uncommon.
4. **Neon убран с блоков**: `glow` теперь даёт `Foil`, не `Neon`
   (`mythic` material тоже `Foil`). Меньше bloom-нагрузки.
5. **PointLight кап**: `MAX_RARITY_GLOWS = 40`, свет только для epic+,
   счётчик `_activeGlows`.

### 3.3. ClickDetector → Raycast
- Удалены **2250 ClickDetector'ов** (по одному на блок).
- Вместо них один raycast: `UserInputService.InputBegan` (клик) +
  `RunService.RenderStepped` → `_updateHover` (наведение).
- Хелперы: `_raycastParams`, `_raycastBlockPart`, `RAYCAST_DISTANCE = 200`.
- **Подтверждено в Studio: ClickDetector = 0.**

### 3.4. Срез эффектов
- `BREAK_CHUNK_COUNT` / `BREAK_DUST_COUNT` урезаны примерно вдвое по всем
  rarity (common chunks 6→3, dust 8→4 и т.д.).
- `_hitParticles`: убран `chunkBurst`, `dustCloud` 4→2 частицы.
- Sparkle: `rare` без sparkle (`sparkleRate = 0`), epic 3→1.5,
  legendary 5→2.5, mythic 9→4.
- **Подтверждено в Studio: ParticleEmitter 440 → ~106.**

### 3.5. Очередь создания блоков (анти-фриз) — ГЛАВНЫЙ ФИКС
Проблема: `applySnapshot`/`applyDelta` создавали все парты **синхронно в одном
кадре** → при дельте на 137 блоков фриз 400–650 мс.

Решение в `MiningRenderer.lua`:
- `CREATE_BUDGET_PER_FRAME = 25` — не более 25 `_createPart` за кадр.
- Очередь FIFO: `_createQueue`, `_createHead` (O(1) без `table.remove`),
  `_createPending` (key → entry, для отмены/замены).
- Методы: `_queueCreate`, `_clearCreateQueue`, `_drainCreateQueue`.
- Дренаж на `RunService.Heartbeat` (`self._createConn`).
- `applySnapshot`/`applyDelta` теперь **кладут в очередь**, а не строят сразу.
- Гонки учтены: `removed` отменяет блок в очереди; `updated` обновляет hp
  у ещё не созданного блока; повторный `created` заменяет entry.

### 3.6. Утечка подписки на SyncBlocks — ФИКС (последний)
Найдено: `renderer:start()` вызывается на **каждый** `CharacterAdded`
(респавн) и вешал **новый** `Net:Connect("SyncBlocks")` без отписки.
После 2–3 смертей каждая delta обрабатывалась 2–3 раза → раздувание очереди,
всплески +87 блоков, секундные фризы.

Решение:
- `self._syncConn` хранит подписку; `start()` отписывает старую перед новой;
  `stop()` тоже отписывает.
- `init.client.lua`: перед повторным `start()` вызывается `renderer:stop()`.

> ⚠️ Этот фикс ещё **НЕ проверен в игре** (нужен ресинк Rojo + рестарт Play).

---

## 4. Замеры (Roblox Studio, MCP)

### 4.1. ВАЖНО про методологию
- **`RunService.RenderStepped` троттлится, когда окно Studio НЕ в фокусе**
  (Heartbeat остаётся 60, Render падает до ~15). Поэтому замеры FPS валидны
  только когда **фокус на окне Studio**.
- Проверка фокуса: если Heartbeat=60, а RenderStepped=15 → окно в фоне,
  цифры FPS невалидны (но фризы-всплески всё равно видны).
- Память/инстансы/InstanceCount от фокуса не зависят.

### 4.2. Ключевые числа
- GPU ~0.8%, CPU ~17% — **узкое место не GPU**.
- `LuaHeap` ≈ 628 МБ — высоковато, но **стабильно** (нет утечки/GC-рывков).
- Свет/частицы при копании выключали полностью — **FPS не изменился** →
  не они причина фризов.
- Камера в небо vs в шахту — без разницы (но это мерилось в фоне, см. 4.1).

### 4.3. До фикса очереди (копание)
- avg 19 FPS, worst frame **655 мс**, **137 блоков создано за 1 кадр**.

### 4.4. После фикса очереди, но ДО фикса утечки SyncBlocks (60 c, вероятно частично в фоне)
- avg 15 FPS (939 кадров за 60 c — похоже на троттлинг фона).
- worst frame **1372 мс**, second worst 1065 мс.
- p95 563 мс, p99 752 мс.
- кадров >200 мс: **60 из 939** (~6%).
- блоков в шахте: 2250 → **2911** (+1068 за минуту).
- max прирост папки за Heartbeat: **+87** (т.е. дельты всё ещё крупные;
  при дублировании listener'а — суммировались).

---

## 5. Текущий диагноз

1. **Утечка SyncBlocks-подписки** (исправлена, не проверена) — вероятно
   главный усилитель фризов после нескольких респавнов. **Проверить первым.**
2. **Очередь создания** работает, но всплески +87 за Heartbeat говорят, что
   либо listener дублировался, либо дренаж не успевает (25/кадр при больших
   дельтах = несколько кадров на разгрузку — это ок, но если listener ×3,
   очередь забивается втрое).
3. **Нет distance culling** — 2900+ партов в сцене постоянно. Это даёт
   фоновую тяжесть (не пиковые фризы, а общий низкий FPS).
4. **`_createPart` тяжёлый сам по себе** — создаёт Part + задаёт ~10 свойств +
   возможно PointLight + ParticleEmitter. 25 таких за кадр может быть много;
   стоит замерить стоимость одного `_createPart`.

---

## 6. План для нового чата (по приоритету)

1. **Проверить фикс утечки SyncBlocks**: ресинк Rojo → рестарт Play →
   монитор 60 c **с фокусом на Studio**. Сравнить worst frame (ждём падения
   с ~1300 мс). Залогировать, сколько раз срабатывает `applyDelta` на один
   `created`-батч (поставить счётчик/принт).
2. Если фризы остались — **профилировать `_createPart`**: замерить
   `os.clock()` вокруг создания N блоков; решить, что резать (PointLight?
   ParticleEmitter? пересоздание RaycastParams?).
3. **Понизить `CREATE_BUDGET_PER_FRAME`** (попробовать 10–15) и/или
   разнести создание на `task.wait()` корутину вместо Heartbeat.
4. **Distance culling**: не держать парты дальше N студов от игрока
   (скрывать/удалять и пересоздавать при приближении). Самый большой выигрыш
   по фоновому FPS, но сложнее всего (надо синхронизировать с delta-синком).
5. Рассмотреть **пул объектов** (reuse Part'ов вместо Destroy/Instance.new).

---

## 7. Файлы, которые трогали

- `src/client/core/MiningRenderer.lua` — основной (очередь, raycast, эффекты,
  материалы, SyncBlocks-подписка).
- `src/client/init.client.lua` — `renderer:stop()` перед `start()` на респавне.
- `src/shared/data/OreDatabase.lua` — материалы/reflectance/glow (Phase 14).
- `src/client/core/LayerEnvironment.lua` — per-layer lighting.
- `src/shared/constants.lua` — `LAYER_LIGHTING`.
- `src/shared/types/OreTypes.lua` — комментарии типов.

## 8. Полезные MCP-сниппеты для замеров

**Снимок инстансов в шахте:**
```lua
local f = workspace:FindFirstChild("DeepDigger_Mine")
local s = { parts=0, clickDetectors=0, pointLights=0, particleEmitters=0 }
for _, i in f:GetDescendants() do
  if i:IsA("BasePart") then s.parts+=1
  elseif i:IsA("ClickDetector") then s.clickDetectors+=1
  elseif i:IsA("PointLight") then s.pointLights+=1
  elseif i:IsA("ParticleEmitter") then s.particleEmitters+=1 end
end
return s
```

**Проверка фокуса/троттлинга (Heartbeat vs RenderStepped):**
```lua
local RS = game:GetService("RunService")
local hb, rs = 0, 0
local c1 = RS.Heartbeat:Connect(function() hb+=1 end)
local c2 = RS.RenderStepped:Connect(function() rs+=1 end)
task.wait(2); c1:Disconnect(); c2:Disconnect()
return { heartbeatFps = hb//2, renderFps = rs//2 } -- если hb=60,rs=15 → окно в фоне
```

**Монитор фризов 60 c (запускать с фокусом на Studio):**
```lua
local RS = game:GetService("RunService")
local frames, worst, lastCount, maxJump = {}, 0, 0, 0
local f0 = workspace:FindFirstChild("DeepDigger_Mine")
lastCount = f0 and #f0:GetChildren() or 0
local c = RS.RenderStepped:Connect(function(dt)
  table.insert(frames, dt); local ms=dt*1000; if ms>worst then worst=ms end
end)
local j = RS.Heartbeat:Connect(function()
  local f = workspace:FindFirstChild("DeepDigger_Mine"); if not f then return end
  local cc = #f:GetChildren(); local d = cc-lastCount
  if d>maxJump then maxJump=d end; lastCount=cc
end)
task.wait(60); c:Disconnect(); j:Disconnect()
local n=#frames; local sum=0; for _,dt in frames do sum+=dt end
local over200=0; for _,dt in frames do if dt*1000>200 then over200+=1 end end
return { avgFps=n//sum, worstMs=math.floor(worst), framesOver200ms=over200, maxPartsJump=maxJump }
```
