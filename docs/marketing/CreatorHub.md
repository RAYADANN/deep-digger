# Creator Hub — Deep Digger 🪨

> Фаза 14 (Визуальная идентичность). Бриф + готовые тексты для загрузки в
> Roblox Creator Hub. Финальные PNG-ассеты разработчик рендерит/загружает сам
> (placeholder-пути ниже). Цель: игра узнаётся в Discover как **mining-sim**.

---

## 1. Название (Title)

| Язык | Название |
|------|----------|
| EN | **Deep Digger ⛏️ Mining Simulator** |
| RU | **Deep Digger ⛏️ Симулятор Шахтёра** |

> Держать ≤ 50 символов, чтобы не обрезалось в карточке Discover. Эмодзи-кирка
> ⛏️ работает как визуальный маркер жанра прямо в названии.

Альтернативы (A/B-тест после soft launch):
- `Deep Digger: Mine & Rebirth`
- `⛏️ Deep Digger | Pets & Mining`

---

## 2. Описание (Description)

Ключевые слова для алгоритма Discover (обязательны в первых 2 строках):
**mining**, **pets**, **rebirth**, **simulator**.

### EN

```
⛏️ DEEP DIGGER — the mining simulator where every block counts!

Dig deeper, discover 30+ rare ores, and collect them all in your Ore Journal.
Hatch PETS that boost your mining power. REBIRTH to multiply your earnings and
climb the global leaderboard. From the Dirt layer down to the Void — how deep
can YOU go?

✨ FEATURES
• Mine & sell 30+ ores across 7 deep layers
• Hatch pets with damage, luck & coin boosts
• Rebirth for permanent multipliers
• Daily rewards & streak boosts
• Ore Discovery Journal — collect them all
• Global leaderboards (coins & depth)

Tags: mining, simulator, pets, rebirth, dig, ore, adventure
```

### RU

```
⛏️ DEEP DIGGER — симулятор шахтёра, где важен каждый блок!

Копай глубже, открывай 30+ редких руд и собирай их в Журнале находок.
Открывай ПИТОМЦЕВ, усиливающих добычу. Делай РЕБЁРТ, чтобы умножить доход и
подняться в глобальном лидерборде. От слоя Земли до Бездны — насколько глубоко
сможешь спуститься ТЫ?

✨ ОСОБЕННОСТИ
• Добыча и продажа 30+ руд на 7 слоях глубины
• Питомцы с бустами урона, удачи и монет
• Ребёрт ради постоянных множителей
• Ежедневные награды и стрик-бусты
• Журнал находок — собери все руды
• Глобальные лидерборды (монеты и глубина)

Теги: mining, simulator, pets, rebirth, копание, руда, шахта
```

---

## 3. Genre / Tags (Creator Hub → Settings → Basic Info)

- **Genre (primary):** Simulator
- **Genre (secondary / tags):** Adventure
- **Subgenre tags:** Mining, Pets, Idle/Incremental
- **Server fill:** по умолчанию
- **Age guidance:** Mild (без насилия, только копание)

---

## 4. Чеклист ассетов

Все финальные файлы кладём в `docs/marketing/assets/` (см. имена ниже), затем
загружаем в Creator Hub. Пути в репо — placeholder под будущие PNG.

### 4.1. Icon — `docs/marketing/assets/icon_512.png`
- [ ] Размер **512×512** PNG, без альфа-краёв (заполнен весь квадрат).
- [ ] **Читается в 64×64** (мобильное превью Discover): один крупный объект,
      максимум 2 цвета-акцента, без мелкого текста.
- [ ] Композиция: **золотая кирка ⛏️ бьёт по блестящему алмазному/золотому
      блоку**, искры/осколки летят. Фон — тёмная шахта с тёплым светом факела.
- [ ] Высокий контраст «кирка (тёплый металл) vs блок (холодный gem-cyan)».
- [ ] Без рамок и watermark — Roblox обрезает углы скруглением.
- **Критерий приёмки:** 5 случайных людей по иконке в 64×64 угадывают
  «копание / шахта / добыча».

### 4.2. Thumbnails (4 шт.) — `docs/marketing/assets/thumb_N_*.png`
Все **16:9, 1920×1080**, крупный понятный субъект, короткий текст-плашка.

- [ ] `thumb_1_mining.png` — **Копание:** игрок с большой киркой бьёт rare-блок,
      coin-pop «+500 💰», разлёт chunks. Плашка «DIG DEEP».
- [ ] `thumb_2_rebirth.png` — **Rebirth FX:** золотые shockwave-кольца вокруг
      игрока, чип «x2.5». Плашка «REBIRTH = MORE COINS».
- [ ] `thumb_3_egg.png` — **Egg hatch:** трясущееся яйцо → reveal legendary-пета
      с rarity-свечением. Плашка «HATCH PETS».
- [ ] `thumb_4_leaderboard.png` — **Лидерборд:** топ-3 с короной 👑 и аватарами,
      «#1» подсвечен золотом. Плашка «BE #1».

### 4.3. Key Art / Promo — `docs/marketing/assets/keyart_1920x1080.png`
- [ ] 3D-рендер: **гигантская кирка** на переднем плане, **питомец** парит сбоку,
      под ними уходящая вглубь шахта со слоями (земля → камень → кристаллы →
      void), руды светятся по слоям. Логотип «DEEP DIGGER» сверху.
- [ ] Глубина кадра = главный хук: взгляд «проваливается вниз» по слоям —
      ровно то ощущение «спуска вглубь», что даёт LayerEnvironment в игре.
- [ ] Цветовая прогрессия слоёв совпадает с `Constants.LAYER_LIGHTING`
      (тёплый верх → холодный/тёмный низ).

---

## 5. Соответствие визуала в игре (для консистентности ассетов)

Ассеты должны отражать то, что игрок реально видит — иначе bounce на входе.

- **Материалы руд** (`shared/data/OreDatabase.lua`, Фаза 14):
  Dirt→Ground, Stone→Slate, металлы→Foil/Metal, самоцветы→Glass+reflectance,
  мистические (astralite/spirit_shard/nebula/star/void_crystal)→шиммер Foil (glow).
- **Атмосфера слоёв** (`Constants.LAYER_LIGHTING` + `LayerEnvironment`):
  яркий полдень на Dirt → почти полная тьма в Void, сгущающаяся дымка
  (Atmosphere) с глубиной.
- **Палитра редкости** (`Constants.RARITY_COLORS`): common серый → mythic
  красный; в thumbnails использовать те же акцентные цвета свечения.

---

## 6. Pipeline загрузки (после рендера PNG)

1. Положить финальные PNG в `docs/marketing/assets/` под именами из чеклиста.
2. Creator Hub → Game → **Icon**: загрузить `icon_512.png`.
3. Creator Hub → Game → **Thumbnails**: загрузить 4 шт. (порядок 1→4).
4. Settings → Basic Info: вставить Title + Description (RU как primary при
   таргете на СНГ, EN — для глобала; Roblox поддерживает локализацию описаний).
5. Genre: Simulator; добавить теги Adventure/Mining.
6. Прогнать «icon-тест 5 людей» (критерий 4.1) до публикации.
