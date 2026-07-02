--!strict
-- OreFXPalette.lua — палитра VFX для руды (ambient, glow, discovery).
-- Берёт цвет руды из OreDatabase + цвет редкости → сбалансированный набор
-- оттенков для частиц, лучей и света. Тёмные руды (уголь, void) подмешивают
-- цвет редкости, чтобы эффект читался в тёмной шахте.

export type Palette = {
    core: Color3,
    glow: Color3,
    accent: Color3,
    dim: Color3,
}

local OreFXPalette = {}

local function lum(c: Color3): number
    return c.R * 0.299 + c.G * 0.587 + c.B * 0.114
end

local function brighten(c: Color3, a: number): Color3
    return c:Lerp(Color3.new(1, 1, 1), a)
end

local function dim(c: Color3, a: number): Color3
    return c:Lerp(Color3.new(0, 0, 0), a)
end

local function saturate(c: Color3, mul: number): Color3
    local h, s, v = c:ToHSV()
    return Color3.fromHSV(h, math.clamp(s * mul, 0, 1), v)
end

-- Профессиональный приём: идентичность = цвет руды, «дороговизна» = акцент редкости.
function OreFXPalette.fromColors(oreColor: Color3, rarityColor: Color3): Palette
    local core = oreColor
    local glow: Color3
    if lum(oreColor) < 0.18 then
        core = oreColor:Lerp(rarityColor, 0.38)
        glow = brighten(rarityColor:Lerp(oreColor, 0.15), 0.3)
    else
        glow = saturate(brighten(oreColor, 0.4), 1.12)
    end
    return {
        core = core,
        glow = glow,
        accent = rarityColor,
        dim = dim(core, 0.5),
    }
end

function OreFXPalette.particleGradient(p: Palette): ColorSequence
    return ColorSequence.new({
        ColorSequenceKeypoint.new(0, p.glow),
        ColorSequenceKeypoint.new(0.42, p.core),
        ColorSequenceKeypoint.new(1, p.dim),
    })
end

function OreFXPalette.beamGradient(p: Palette): ColorSequence
    return ColorSequence.new({
        ColorSequenceKeypoint.new(0, p.glow),
        ColorSequenceKeypoint.new(0.55, p.core),
        ColorSequenceKeypoint.new(1, p.core:Lerp(p.accent, 0.28)),
    })
end

-- Сохраняет форму градиента шаблона (временны́е точки), перекрашивая по яркости keypoint.
function OreFXPalette.remapColorSequence(seq: ColorSequence, p: Palette): ColorSequence
    local keys = seq.Keypoints
    if #keys == 0 then
        return OreFXPalette.particleGradient(p)
    end
    local newKeys: { ColorSequenceKeypoint } = {}
    for _, kp in keys do
        local l = lum(kp.Value)
        local c = if l > 0.55 then p.glow:Lerp(p.core, (l - 0.55) / 0.45)
            elseif l > 0.28 then p.core
            else p.core:Lerp(p.dim, (0.28 - l) / 0.28)
        table.insert(newKeys, ColorSequenceKeypoint.new(kp.Time, c))
    end
    return ColorSequence.new(newKeys)
end

-- Прямой градиент палитры руды — сильнее читается, чем remap шаблона (у всех
-- uncommon один и тот же синий пресет в Studio, remap давал «почти одинаково»).
function OreFXPalette.tintDescendants(root: Instance, p: Palette)
    local emission = if lum(p.core) < 0.2 then 0.52 else 0.42
    for _, d in root:GetDescendants() do
        if d:IsA("ParticleEmitter") then
            d.Color = OreFXPalette.particleGradient(p)
            d.LightEmission = math.max(d.LightEmission, emission)
        elseif d:IsA("Beam") then
            d.Color = OreFXPalette.beamGradient(p)
            d.LightEmission = math.max(d.LightEmission, emission + 0.12)
        elseif d:IsA("Trail") then
            d.Color = OreFXPalette.particleGradient(p)
            d.LightEmission = math.max(d.LightEmission, emission)
        elseif d:IsA("PointLight") or d:IsA("SpotLight") then
            d.Color = p.glow
        elseif d:IsA("BasePart") and d.Material == Enum.Material.Neon then
            d.Color = p.core
        end
    end
    if root:IsA("BasePart") and root.Material == Enum.Material.Neon then
        root.Color = p.core
    end
end

return OreFXPalette
