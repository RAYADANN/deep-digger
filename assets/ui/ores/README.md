# Ore icons (Rojo → ReplicatedStorage.uiAssets.ores)

PNG 256×256, прозрачный фон. Имя файла = `oreId` (например `coal.png`).

## Пайплайн (Studio → PNG)

1. В Studio command bar:
   `print(require(game.ReplicatedStorage.shared.dev.BuildOreIconStand).build())`
2. Съёмка блоков (MCP `screen_capture` или вручную).
3. Сырые кадры в `_raw/{oreId}.png`
4. `python prepare_ore_icons.py` — rembg, crop, 256×256
5. Rojo sync → Lua/модули в `shared/` (PNG в `assets/ui/ores` Rojo **не** импортирует).

**Иконки в игре:** baked `OreIconPixels` → `EditableImage` на клиенте. Нужно
Game Settings → Security → **Allow Mesh / Image APIs**. Альтернатива: upload PNG
в Creator Hub → `OreAssets.lua` (`ROBLOX_IMAGES`), как у `tab_*.png` в `UiAssets.lua`.
