--!strict

local UpgradeMeta = {
    NAMES = {
        pickaxe = "Кирка",
        speed = "Скорость",
        fortune = "Удача",
        inventory = "Рюкзак",
        crit = "Крит",
        multiSell = "Продажа",
        autoSell = "Авто-продажа",
    },
    DESC = {
        pickaxe = "Увеличивает урон по блокам",
        speed = "Ускоряет добычу",
        fortune = "Шанс редких руд",
        inventory = "Слоты инвентаря",
        crit = "Шанс крит. удара",
        multiSell = "Бонус к продаже",
        autoSell = "Авто-продажа руд",
    },
    ORDER = { "pickaxe", "speed", "fortune", "inventory", "crit", "multiSell", "autoSell" },
}

return UpgradeMeta
