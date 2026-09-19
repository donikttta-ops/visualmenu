--[[
    VISUAL MENU v6 — полностью переработанный интерфейс

    v6 — что нового в GUI (логика вкладок и эффектов не менялась):
    • Поиск по всем настройкам прямо в шапке окна (или клавиша /):
      фильтрует строки во всех вкладках, показывает счётчик совпадений
      у вкладок, сам переключается на вкладку с результатами.
      Esc или пустая строка — вернуть обычный вид.
    • Смена темы теперь перекрашивает ВЕСЬ интерфейс (панели, тумблеры,
      слайдеры, кнопки, обводки), а не только рамку окна: добавлен реестр
      элементов H.reg + H.refreshTheme().
    • Новый вид: скругления 12px, градиентный фон, мягкая тень, бегущий
      блик по акцентной линии, аккуратная типографика и отступы.
    • Тумблеры: подсветка при наведении, акцентная метка «включено»,
      пружинная анимация переключателя, волна от клика (ripple).
    • Слайдеры: значение в отдельной пилюле, градиентная заливка,
      ползунок увеличивается при наведении и перетаскивании.
      Все слайдеры используют ОДИН общий обработчик ввода вместо
      отдельного на каждый — меньше нагрузка на клиент.
    • Кнопки и поля ввода: ховер-состояния, акцентная обводка при фокусе.
    • Кнопка сворачивания окна в полоску заголовка (–).
    • Всплывающие уведомления H.notify(текст).
    • Подсказка по горячим клавишам внизу сайдбара + счётчик онлайна.
    • Авто-уменьшение окна на маленьких экранах (телефон/планшет).
    • Починен слайдер «Толщина рамки» (значение по умолчанию было вне
      диапазона 0..4 и заливка уезжала за трек).

    VISUAL MENU v5 — расширенная косметическая кастомизация
    Категории: МИР · ПЕРСОНАЖ · КОНФИГИ
    GUI-настройки · пресеты неба · круг при прыжке и разнотипные визуалы
    Только визуальные изменения, видимые локально у вас в клиенте.

    v5 — фикс конфигов + новые визуалы:
    • Автосохранение настроек в _last каждые 8с + автозагрузка при входе
    • В конфиг попадают trail/aura/highlight/glow/FOV/HUD/скин и др.
    • Новые эффекты: огонь/лёд/сердца/звёзды/тьма, орбитальные кольца,
      afterimage при беге, частицы при прыжке

    v4 — что изменилось:
    1) СКИНЧЕНДЖЕР ОДЕЖДЫ: раньше скрипт всегда пытался применить ID как
       классическую Shirt/Pants (ShirtTemplate/PantsTemplate). Но большинство
       современных вещей в каталоге Roblox — это "слоистая одежда"
       (Layered Clothing), которая на самом деле является Accessory-объектом
       с мешем и надевается через Humanoid:AddAccessory(), а не через
       ShirtTemplate. Теперь скрипт СНАЧАЛА узнаёт реальный тип предмета
       через MarketplaceService и сам выбирает нужный способ применения:
       классика -> ShirtTemplate/PantsTemplate, слоистая одежда -> AddAccessory.
       Если тип определить не удалось — старая одежда НЕ трогается, а под
       полем показывается точная причина. В консоль (F9 -> Client Log)
       дополнительно печатается фактический AssetTypeId и его название —
       если что-то опять не сработает, эта строка покажет, что не так.
    2) Анимированный экран загрузки при активации скрипта (спиннер + полоса
       прогресса), плавное появление окна.
    3) Анимации интерфейса: скользящий индикатор активной вкладки,
       кросс-фейд контента при переключении, анимированное
       открытие/закрытие окна по клавише K и кнопке закрытия.
    4) Больше визуальных эффектов на вкладке "Частицы": след (в т.ч.
       радужный), аура частиц, обводка (Highlight), частицы шагов,
       точечное свечение (PointLight) и вспышка искр по кнопке.
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local InsertService = game:GetService("InsertService")
local MarketplaceService = game:GetService("MarketplaceService")
local Stats = game:GetService("Stats")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- прямое объявление наверху: заполняются позже (HUD, окно меню),
-- но используются в колбэках, объявленных раньше по тексту файла
-- (важно: если переменную объявить через `local` только в момент её
-- реального создания ниже по файлу, все функции-колбэки, написанные
-- ВЫШЕ этой строки, будут ссылаться на глобальную переменную, а не на
-- эту локальную — и в рантайме поймают nil. Поэтому HUD-переменные
-- объявлены здесь заранее и далее по файлу им просто присваивается
-- значение без повторного `local`.)
local function __main()
local H = {}
local HudFrame
local hudName, hudStroke, hudPing, hudFps, hudTime
local hudEnabled = true
local hudYOffset = 12
local menuOpen = true
local menuHotkey = Enum.KeyCode.K
local currentCategoryIndex = 1
-- реальный лимит FPS через setfpscap (если executor поддерживает)
local fpsCapEnabled = false
local fpsCapValue = 240
local hasSetFpsCap = typeof(setfpscap) == "function"

-- Все UI-хендлы в одной таблице H — экономим слоты локальных переменных
-- (лимит Luau: 200 locals на чанк). Доступ: H.trailToggle, H.fov и т.д.
local playGuiClick
local clickSoundEnabled = true
local clickSoundId = "6895079853"
local clickVolume = 0.45
local musicVolume = 0.5
local favoriteTracks = {}
local currentPresetIndex = 1
local refreshFavLabel
local mpVolFill
local clickAnimEnabled = true
local radarEnabled = true
local radarRange = 120
local RadarFrame

local skyTab, fxTab, screenTab, fxCharTab, musicTab, emoteTab, camTab, guiTab, espTab, trollTab
local currentSound = nil
local musicQueue = {}
-- ВАЖНО (исправлено): здесь раньше объявлялись локальные queueLoop /
-- seekSliderHandle / queueListLabel — они ЗАТЕНЯЛИ одноимённые переменные
-- верхнего уровня. Из-за этого refreshQueueLabel() внутри этой функции
-- видел queueListLabel == nil и всегда выходил на первой строке: список
-- очереди в меню музыки не обновлялся. Теперь все три имени указывают на
-- переменные верхнего уровня.
local PRESET_SONGS
local refreshQueueLabel
local enqueueTrack
local playNextFromList


local PRESET_SONGS = nil


local OverlayGui -- создаётся во вкладке "Экран", HUD живёт в нём
local nowPlayingLabel

-- то же самое, но для системы конфигов: сама система построена внутри
-- do...end ниже по файлу (чтобы не упереться в лимит Lua на 200 локальных
-- переменных одной функции/чанка), а эти несколько имён должны остаться
-- видимыми и после конца блока — для автозагрузки конфига в самом низу
-- файла
local loadConfigByName, readAutoloadMarker, configStatusLabel, autoloadToggleHandle, showCategory
local saveConfig, autoSaveLastConfig

----------------------------------------------------------
-- ЦВЕТОВАЯ СХЕМА  (v6 — живая тема + производные цвета)
----------------------------------------------------------
local THEME = {
    Background = Color3.fromRGB(15, 16, 20),
    Sidebar    = Color3.fromRGB(11, 12, 15),
    Panel      = Color3.fromRGB(24, 26, 32),
    PanelHover = Color3.fromRGB(34, 37, 45),
    Accent     = Color3.fromRGB(80, 255, 140),
    AccentSoft = Color3.fromRGB(40, 140, 80),
    Text       = Color3.fromRGB(236, 238, 243),
    SubText    = Color3.fromRGB(135, 142, 155),
    Stroke     = Color3.fromRGB(46, 50, 60),
    Success    = Color3.fromRGB(80, 255, 140),
    Error      = Color3.fromRGB(255, 70, 90),
}

local CATEGORY_COLORS = {
    Outfit = Color3.fromRGB(210, 110, 255),
    World  = Color3.fromRGB(90, 170, 255),
    Player = Color3.fromRGB(255, 175, 70),
    Config = Color3.fromRGB(120, 220, 190),
}

-- утилиты цвета/анимации живут в H, чтобы не съедать лимит локальных
H.mix = function(a, b, t)
    return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
end
H.lighten = function(c, t) return H.mix(c, Color3.new(1, 1, 1), t) end
H.darken  = function(c, t) return H.mix(c, Color3.new(0, 0, 0), t) end
H.tw = function(inst, t, props, style, dir)
    if not (inst and inst.Parent) then return end
    TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props):Play()
end

-- ── РЕЕСТР ТЕМЫ ──────────────────────────────────────────
-- каждый элемент регистрируется со своей «ролью»; смена темы
-- мгновенно перекрашивает ВЕСЬ интерфейс, а не только окно
H._themed = {}
H.reg = function(inst, prop, role)
    table.insert(H._themed, { i = inst, p = prop, r = role })
    return inst
end
H.regFn = function(fn)
    table.insert(H._themed, { fn = fn })
    return fn
end
H.refreshTheme = function()
    -- производные оттенки пересчитываем от базовых
    THEME.PanelHover = H.lighten(THEME.Panel, 0.08)
    THEME.Stroke = H.lighten(THEME.Panel, 0.12)
    THEME.AccentSoft = H.darken(THEME.Accent, 0.45)
    for idx = #H._themed, 1, -1 do
        local e = H._themed[idx]
        if e.fn then
            local ok = pcall(e.fn)
            if not ok then table.remove(H._themed, idx) end
        elseif e.i and e.i.Parent then
            pcall(function() e.i[e.p] = THEME[e.r] end)
        elseif e.i and not e.i.Parent then
            table.remove(H._themed, idx)
        end
    end
end

----------------------------------------------------------
-- ROOT GUI
----------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VisualMenu"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = game:GetService("CoreGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 660, 0, 480)
MainFrame.Position = UDim2.new(0.5, -330, 0.5, -240)
MainFrame.BackgroundColor3 = THEME.Background
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.ClipsDescendants = false
MainFrame.Parent = ScreenGui
H.reg(MainFrame, "BackgroundColor3", "Background")
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)

-- мягкая тень (первый ImageLabel внутри MainFrame — на неё завязан тумблер «Тень окна»)
local Shadow = Instance.new("ImageLabel")
Shadow.BackgroundTransparency = 1
Shadow.Image = "rbxassetid://1316045217"
Shadow.ImageColor3 = Color3.new(0, 0, 0)
Shadow.ImageTransparency = 0.35
Shadow.ScaleType = Enum.ScaleType.Slice
Shadow.SliceCenter = Rect.new(10, 10, 118, 118)
Shadow.Size = UDim2.new(1, 80, 1, 80)
Shadow.Position = UDim2.new(0, -40, 0, -40)
Shadow.ZIndex = 0
Shadow.Parent = MainFrame

-- лёгкий вертикальный градиент фона: сверху чуть светлее
do
    local g = Instance.new("UIGradient")
    g.Rotation = 90
    g.Parent = MainFrame
    H.regFn(function()
        g.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, H.lighten(THEME.Background, 0.05)),
            ColorSequenceKeypoint.new(1, H.darken(THEME.Background, 0.15)),
        })
    end)
end

local mainStroke = Instance.new("UIStroke", MainFrame)
mainStroke.Color = THEME.Accent
mainStroke.Thickness = 1.2
mainStroke.Transparency = 0.55

----------------------------------------------------------
-- TOP BAR
----------------------------------------------------------
local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 44)
TopBar.BackgroundColor3 = THEME.Sidebar
TopBar.BorderSizePixel = 0
TopBar.Parent = MainFrame
H.reg(TopBar, "BackgroundColor3", "Sidebar")
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 12)

do -- заглушка нижних скруглений топбара (её ищет код смены темы: первый Frame внутри TopBar)
    local topFix = Instance.new("Frame")
    topFix.Size = UDim2.new(1, 0, 0, 12)
    topFix.Position = UDim2.new(0, 0, 1, -12)
    topFix.BackgroundColor3 = THEME.Sidebar
    topFix.BorderSizePixel = 0
    topFix.ZIndex = 0
    topFix.Parent = TopBar
    H.reg(topFix, "BackgroundColor3", "Sidebar")
end

-- акцентная линия под топбаром с «бегущим» бликом
local topLine = Instance.new("Frame")
topLine.Name = "AccentLine"
topLine.Size = UDim2.new(1, 0, 0, 2)
topLine.Position = UDim2.new(0, 0, 0, 44)
topLine.BorderSizePixel = 0
topLine.BackgroundColor3 = THEME.Accent
topLine.ZIndex = 5
topLine.Parent = MainFrame
H.reg(topLine, "BackgroundColor3", "Accent")
do
    local g = Instance.new("UIGradient")
    g.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.9),
        NumberSequenceKeypoint.new(0.45, 0.85),
        NumberSequenceKeypoint.new(0.5, 0.1),
        NumberSequenceKeypoint.new(0.55, 0.85),
        NumberSequenceKeypoint.new(1, 0.9),
    })
    g.Parent = topLine
    task.spawn(function()
        while topLine.Parent do
            g.Offset = Vector2.new(-1, 0)
            H.tw(g, 2.2, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
            task.wait(4.5)
        end
    end)
end

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0, 120, 1, 0)
Title.Position = UDim2.new(0, 16, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "VISUAL MENU"
Title.TextColor3 = THEME.Text
Title.Font = Enum.Font.GothamBold
Title.TextSize = 15
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar
H.reg(Title, "TextColor3", "Text")

local AccentDot = Instance.new("Frame")
AccentDot.Size = UDim2.new(0, 6, 0, 6)
AccentDot.Position = UDim2.new(0, 122, 0.5, -3)
AccentDot.BackgroundColor3 = THEME.Accent
AccentDot.BorderSizePixel = 0
AccentDot.Parent = TopBar
Instance.new("UICorner", AccentDot).CornerRadius = UDim.new(1, 0)
H.reg(AccentDot, "BackgroundColor3", "Accent")
task.spawn(function()
    while AccentDot.Parent do
        H.tw(AccentDot, 1, { BackgroundTransparency = 0.65 })
        task.wait(1)
        H.tw(AccentDot, 1, { BackgroundTransparency = 0 })
        task.wait(1)
    end
end)

local TitleName = Instance.new("TextLabel")
TitleName.Size = UDim2.new(0, 150, 1, 0)
TitleName.Position = UDim2.new(0, 134, 0, 0)
TitleName.BackgroundTransparency = 1
TitleName.Text = "@" .. (player.DisplayName or player.Name)
TitleName.TextColor3 = THEME.Accent
TitleName.Font = Enum.Font.GothamMedium
TitleName.TextSize = 13
TitleName.TextXAlignment = Enum.TextXAlignment.Left
TitleName.TextTruncate = Enum.TextTruncate.AtEnd
TitleName.Parent = TopBar
H.reg(TitleName, "TextColor3", "Accent")
player:GetPropertyChangedSignal("DisplayName"):Connect(function()
    TitleName.Text = "@" .. (player.DisplayName or player.Name)
end)

-- ── ПОИСК ПО ВСЕМ НАСТРОЙКАМ ─────────────────────────────
local SearchBox = Instance.new("TextBox")
SearchBox.Size = UDim2.new(0, 196, 0, 26)
SearchBox.Position = UDim2.new(1, -274, 0.5, -13)
SearchBox.BackgroundColor3 = THEME.Panel
SearchBox.Text = ""
SearchBox.PlaceholderText = "Поиск настроек..."
SearchBox.PlaceholderColor3 = THEME.SubText
SearchBox.TextColor3 = THEME.Text
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextSize = 12
SearchBox.TextXAlignment = Enum.TextXAlignment.Left
SearchBox.ClearTextOnFocus = false
SearchBox.Parent = TopBar
Instance.new("UICorner", SearchBox).CornerRadius = UDim.new(0, 8)
H.reg(SearchBox, "BackgroundColor3", "Panel")
H.reg(SearchBox, "TextColor3", "Text")
H.reg(SearchBox, "PlaceholderColor3", "SubText")
do
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 12)
    pad.PaddingRight = UDim.new(0, 8)
    pad.Parent = SearchBox

    local st = Instance.new("UIStroke", SearchBox)
    st.Color = THEME.Stroke
    st.Thickness = 1
    st.Transparency = 0.4
    H.reg(st, "Color", "Stroke")
    SearchBox.Focused:Connect(function()
        st.Color = THEME.Accent
        H.tw(st, 0.15, { Transparency = 0 })
    end)
    SearchBox.FocusLost:Connect(function()
        st.Color = THEME.Stroke
        H.tw(st, 0.15, { Transparency = 0.4 })
    end)
end

local OnlineLabel = Instance.new("TextLabel")
OnlineLabel.Name = "OnlineCount"
OnlineLabel.Size = UDim2.new(0, 80, 1, 0)
OnlineLabel.Position = UDim2.new(1, -360, 0, 0)
OnlineLabel.BackgroundTransparency = 1
OnlineLabel.Text = "ONLINE --"
OnlineLabel.TextColor3 = THEME.SubText
OnlineLabel.Font = Enum.Font.GothamMedium
OnlineLabel.TextSize = 11
OnlineLabel.TextXAlignment = Enum.TextXAlignment.Right
OnlineLabel.Parent = TopBar
H.reg(OnlineLabel, "TextColor3", "SubText")
do
    local function refreshOnlineCount()
        OnlineLabel.Text = "ONLINE " .. tostring(#Players:GetPlayers())
    end
    refreshOnlineCount()
    Players.PlayerAdded:Connect(refreshOnlineCount)
    Players.PlayerRemoving:Connect(function() task.defer(refreshOnlineCount) end)
    task.spawn(function()
        while OnlineLabel.Parent do
            task.wait(5)
            refreshOnlineCount()
        end
    end)
end

-- кнопки окна: свернуть / закрыть
H.topButton = function(txt, offsetX, hoverColor, onClick)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 26, 0, 26)
    b.Position = UDim2.new(1, offsetX, 0.5, -13)
    b.BackgroundColor3 = THEME.Panel
    b.Text = txt
    b.TextColor3 = THEME.Text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 16
    b.AutoButtonColor = false
    b.Parent = TopBar
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
    H.reg(b, "BackgroundColor3", "Panel")
    H.reg(b, "TextColor3", "Text")
    b.MouseEnter:Connect(function() H.tw(b, 0.12, { BackgroundColor3 = hoverColor or THEME.PanelHover }) end)
    b.MouseLeave:Connect(function() H.tw(b, 0.12, { BackgroundColor3 = THEME.Panel }) end)
    b.MouseButton1Click:Connect(function() playGuiClick(); onClick() end)
    return b
end

local MiniBtn = H.topButton("–", -66, nil, function() end)
local CloseBtn = H.topButton("×", -34, Color3.fromRGB(215, 60, 70), function()
    local tw = TweenService:Create(MainFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad), {
        Size = UDim2.new(0, 620, 0, 450),
        BackgroundTransparency = 1,
    })
    H.tw(mainStroke, 0.18, { Transparency = 1 })
    tw:Play()
    tw.Completed:Wait()
    ScreenGui:Destroy()
end)

do -- сворачивание окна до полоски заголовка
    local collapsed, savedSize = false, nil
    MiniBtn.MouseButton1Click:Connect(function()
        collapsed = not collapsed
        if collapsed then
            savedSize = MainFrame.Size
            MiniBtn.Text = "+"
            H.tw(MainFrame, 0.2, { Size = UDim2.new(savedSize.X.Scale, savedSize.X.Offset, 0, 44) },
                Enum.EasingStyle.Quad)
        else
            MiniBtn.Text = "–"
            H.tw(MainFrame, 0.22, { Size = savedSize or UDim2.new(0, 660, 0, 480) },
                Enum.EasingStyle.Back)
        end
    end)
end

do -- перетаскивание окна за топбар
    local dragging, dragStart, startPos
    TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

----------------------------------------------------------
-- УВЕДОМЛЕНИЯ (тосты)
----------------------------------------------------------
do
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(0, 260, 1, -40)
    holder.Position = UDim2.new(1, -276, 0, 20)
    holder.BackgroundTransparency = 1
    holder.Parent = ScreenGui
    local lay = Instance.new("UIListLayout")
    lay.Padding = UDim.new(0, 6)
    lay.VerticalAlignment = Enum.VerticalAlignment.Bottom
    lay.HorizontalAlignment = Enum.HorizontalAlignment.Right
    lay.Parent = holder

    H.notify = function(text, color)
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, 0, 0, 34)
        card.BackgroundColor3 = THEME.Panel
        card.BorderSizePixel = 0
        card.BackgroundTransparency = 1
        card.Parent = holder
        Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(0, 3, 1, -12)
        bar.Position = UDim2.new(0, 8, 0, 6)
        bar.BackgroundColor3 = color or THEME.Accent
        bar.BorderSizePixel = 0
        bar.Parent = card
        Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -24, 1, 0)
        lbl.Position = UDim2.new(0, 18, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = THEME.Text
        lbl.TextTransparency = 1
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.Parent = card

        H.tw(card, 0.18, { BackgroundTransparency = 0.05 })
        H.tw(lbl, 0.18, { TextTransparency = 0 })
        task.delay(2.6, function()
            H.tw(card, 0.25, { BackgroundTransparency = 1 })
            H.tw(lbl, 0.25, { TextTransparency = 1 })
            task.delay(0.3, function() if card then card:Destroy() end end)
        end)
    end
end

----------------------------------------------------------
-- SIDEBAR
----------------------------------------------------------
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 158, 1, -44)
Sidebar.Position = UDim2.new(0, 0, 0, 44)
Sidebar.BackgroundColor3 = THEME.Sidebar
Sidebar.BorderSizePixel = 0
Sidebar.ClipsDescendants = true
Sidebar.Parent = MainFrame
H.reg(Sidebar, "BackgroundColor3", "Sidebar")

-- ВАЖНО: UIListLayout расставляет ВСЕХ детей кадра, поэтому разделитель и
-- подсветка активной вкладки лежат прямо в Sidebar (без layout), а сам
-- список кнопок — во вложенном TabList. Иначе разделитель высотой во весь
-- сайдбар занимает первую строку списка и выталкивает кнопки за границы.
do
    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(0, 1, 1, 0)
    sep.Position = UDim2.new(1, -1, 0, 0)
    sep.BackgroundColor3 = THEME.Stroke
    sep.BackgroundTransparency = 0.5
    sep.BorderSizePixel = 0
    sep.ZIndex = 4
    sep.Parent = Sidebar
    H.reg(sep, "BackgroundColor3", "Stroke")
end

local TabList = Instance.new("Frame")
TabList.Size = UDim2.new(1, 0, 1, 0)
TabList.BackgroundTransparency = 1
TabList.ZIndex = 2
TabList.Parent = Sidebar
H.TabList = TabList
do
    local lay = Instance.new("UIListLayout")
    lay.Padding = UDim.new(0, 3)
    lay.SortOrder = Enum.SortOrder.LayoutOrder
    lay.Parent = TabList

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 10)
    pad.PaddingLeft = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)
    pad.Parent = TabList
end

-- подсветка активной вкладки
local SelectorPill = Instance.new("Frame")
SelectorPill.BackgroundColor3 = THEME.AccentSoft
SelectorPill.BorderSizePixel = 0
SelectorPill.ZIndex = 0
SelectorPill.Size = UDim2.new(0, 0, 0, 0)
SelectorPill.Parent = Sidebar
Instance.new("UICorner", SelectorPill).CornerRadius = UDim.new(0, 8)
H.reg(SelectorPill, "BackgroundColor3", "AccentSoft")
do
    local g = Instance.new("UIGradient")
    g.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.15),
        NumberSequenceKeypoint.new(1, 0.75),
    })
    g.Parent = SelectorPill
end

----------------------------------------------------------
-- CONTENT AREA
----------------------------------------------------------
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -158, 1, -44)
Content.Position = UDim2.new(0, 158, 0, 44)
Content.BackgroundTransparency = 1
Content.ClipsDescendants = true
Content.Parent = MainFrame

local TabFadeOverlay = Instance.new("Frame")
TabFadeOverlay.Size = UDim2.new(1, 0, 1, 0)
TabFadeOverlay.BackgroundColor3 = THEME.Background
TabFadeOverlay.BackgroundTransparency = 1
TabFadeOverlay.BorderSizePixel = 0
TabFadeOverlay.ZIndex = 10
TabFadeOverlay.Visible = false
TabFadeOverlay.Parent = Content
H.reg(TabFadeOverlay, "BackgroundColor3", "Background")

local tabs = {}
local tabButtons = {}

H.selectTab = function(name)
    for tabName, frame in pairs(tabs) do
        frame.Visible = (tabName == name)
    end
    for tabName, data in pairs(tabButtons) do
        local on = (tabName == name)
        H.tw(data.label, 0.14, { TextColor3 = on and THEME.Text or THEME.SubText })
        H.tw(data.icon, 0.14, {
            BackgroundTransparency = on and 0 or 0.45,
            Size = on and UDim2.new(0, 8, 0, 8) or UDim2.new(0, 6, 0, 6),
            Position = on and UDim2.new(0, 10, 0.5, -4) or UDim2.new(0, 10, 0.5, -3),
        })
    end

    local target = tabButtons[name]
    if target then
        local btn = target.button
        local pos = UDim2.new(0, btn.AbsolutePosition.X - Sidebar.AbsolutePosition.X, 0, btn.AbsolutePosition.Y - Sidebar.AbsolutePosition.Y)
        local size = UDim2.new(0, btn.AbsoluteSize.X, 0, btn.AbsoluteSize.Y)
        if SelectorPill.Size.X.Offset == 0 then
            SelectorPill.Position = pos
            SelectorPill.Size = size
        else
            H.tw(SelectorPill, 0.24, { Position = pos, Size = size }, Enum.EasingStyle.Back)
        end
    end

    -- мягкое появление содержимого вкладки
    local frame = tabs[name]
    if frame then
        frame.Position = UDim2.new(0, 12, 0, 16)
        H.tw(frame, 0.22, { Position = UDim2.new(0, 12, 0, 10) }, Enum.EasingStyle.Quint)
    end
    TabFadeOverlay.Visible = true
    TabFadeOverlay.BackgroundTransparency = 0.15
    H.tw(TabFadeOverlay, 0.18, { BackgroundTransparency = 1 })
    task.delay(0.19, function() TabFadeOverlay.Visible = false end)
end

H.createCategoryHeader = function(text, order)
    -- категории переключаются пейджером сверху, сам заголовок скрыт;
    -- функция сохранена ради совместимости со всеми вызовами ниже по файлу
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 20)
    holder.BackgroundTransparency = 1
    holder.LayoutOrder = order
    holder.Visible = false
    holder.Parent = TabList
    return holder
end

----------------------------------------------------------
-- ЗВУК КЛИКА GUI
----------------------------------------------------------
local CLICK_SOUND_PRESETS = {
    Soft = "6895079853",
    Pop = "5153789659",
    Classic = "421058925",
    Tick = "6976986419",
    UI = "6042053626",
    Sharp = "5370791355",
}
local clickSoundFolder = nil
local function ensureClickFolder()
    if clickSoundFolder and clickSoundFolder.Parent then return clickSoundFolder end
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return nil end
    clickSoundFolder = pg:FindFirstChild("__VM_ClickSounds")
    if not clickSoundFolder then
        clickSoundFolder = Instance.new("Folder")
        clickSoundFolder.Name = "__VM_ClickSounds"
        clickSoundFolder.Parent = pg
    end
    return clickSoundFolder
end

playGuiClick = function(guiObject)
    if clickSoundEnabled then
        local folder = ensureClickFolder()
        if folder then
            local s = Instance.new("Sound")
            s.Name = "Click"
            s.SoundId = "rbxassetid://" .. tostring(clickSoundId)
            s.Volume = clickVolume
            s.PlaybackSpeed = 0.95 + math.random() * 0.12
            s.Parent = folder
            s:Play()
            s.Ended:Connect(function() if s then s:Destroy() end end)
            task.delay(2, function() if s and s.Parent then s:Destroy() end end)
        end
    end
    if clickAnimEnabled and guiObject and typeof(guiObject) == "Instance" and guiObject:IsA("GuiObject") then
        local orig = guiObject.Size
        H.tw(guiObject, 0.06, {
            Size = UDim2.new(orig.X.Scale, orig.X.Offset * 0.96, orig.Y.Scale, orig.Y.Offset * 0.94)
        })
        task.delay(0.06, function()
            H.tw(guiObject, 0.14, { Size = orig }, Enum.EasingStyle.Back)
        end)
    end
end

-- волна от клика (ripple)
H.ripple = function(parent, px, py)
    if not (parent and parent.Parent) then return end
    local r = Instance.new("Frame")
    r.BackgroundColor3 = THEME.Accent
    r.BackgroundTransparency = 0.72
    r.BorderSizePixel = 0
    r.AnchorPoint = Vector2.new(0.5, 0.5)
    r.ZIndex = 8
    r.Position = UDim2.new(0, px - parent.AbsolutePosition.X, 0, py - parent.AbsolutePosition.Y)
    r.Size = UDim2.new(0, 0, 0, 0)
    r.Parent = parent
    Instance.new("UICorner", r).CornerRadius = UDim.new(1, 0)
    local d = math.max(parent.AbsoluteSize.X, parent.AbsoluteSize.Y) * 2.2
    H.tw(r, 0.45, { Size = UDim2.new(0, d, 0, d), BackgroundTransparency = 1 })
    task.delay(0.5, function() if r then r:Destroy() end end)
end

----------------------------------------------------------
-- ПОИСК: реестр всех строк настроек
----------------------------------------------------------
H._items = {}
H._sections = {}
H._curSection = {}
H.indexItem = function(frame, text, parent)
    local it = { frame = frame, text = string.lower(tostring(text or "")), parent = parent, sec = H._curSection[parent] }
    table.insert(H._items, it)
    if it.sec then table.insert(it.sec.items, it) end
    return it
end

H.runSearch = function(query)
    query = string.lower((query or ""):match("^%s*(.-)%s*$"))
    if query == "" then
        for _, it in ipairs(H._items) do it.frame.Visible = true end
        for _, s in ipairs(H._sections) do s.label.Visible = true end
        if showCategory then pcall(showCategory, currentCategoryIndex, true) end
        return
    end
    local hitsPerTab, firstTab = {}, nil
    for _, it in ipairs(H._items) do
        local ok = string.find(it.text, query, 1, true) ~= nil
        it.frame.Visible = ok
        if ok then
            hitsPerTab[it.parent] = (hitsPerTab[it.parent] or 0) + 1
        end
    end
    for _, s in ipairs(H._sections) do
        local any = false
        for _, it in ipairs(s.items) do
            if it.frame.Visible then any = true break end
        end
        s.label.Visible = any
    end
    for name, data in pairs(tabButtons) do
        local frame = tabs[name]
        local n = frame and hitsPerTab[frame] or nil
        data.button.Visible = (n ~= nil)
        if n and not firstTab then firstTab = name end
        if data.count then
            data.count.Text = n and tostring(n) or ""
            data.count.Visible = n ~= nil
        end
    end
    if firstTab and not (tabs[firstTab] and tabs[firstTab].Visible) then
        H.selectTab(firstTab)
    end
end

SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    H.runSearch(SearchBox.Text)
end)
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.Slash and MainFrame.Visible then
        SearchBox:CaptureFocus()
    elseif input.KeyCode == Enum.KeyCode.Escape and SearchBox.Text ~= "" then
        SearchBox.Text = ""
    end
end)

----------------------------------------------------------
-- ВКЛАДКИ
----------------------------------------------------------
H.createTabButton = function(name, order, iconColor)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3 = THEME.PanelHover
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.LayoutOrder = order
    btn.ZIndex = 1
    btn.ClipsDescendants = true
    btn.Parent = TabList
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    local icon = Instance.new("Frame")
    icon.Size = UDim2.new(0, 6, 0, 6)
    icon.Position = UDim2.new(0, 10, 0.5, -3)
    icon.BackgroundColor3 = iconColor or THEME.Accent
    icon.BackgroundTransparency = 0.45
    icon.BorderSizePixel = 0
    icon.ZIndex = 2
    icon.Parent = btn
    Instance.new("UICorner", icon).CornerRadius = UDim.new(1, 0)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -52, 1, 0)
    label.Position = UDim2.new(0, 26, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = name
    label.TextColor3 = THEME.SubText
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.ZIndex = 2
    label.Parent = btn

    -- счётчик совпадений при поиске
    local count = Instance.new("TextLabel")
    count.Size = UDim2.new(0, 22, 0, 16)
    count.Position = UDim2.new(1, -26, 0.5, -8)
    count.BackgroundColor3 = THEME.Panel
    count.Text = ""
    count.Visible = false
    count.TextColor3 = THEME.Accent
    count.Font = Enum.Font.GothamBold
    count.TextSize = 10
    count.ZIndex = 2
    count.Parent = btn
    Instance.new("UICorner", count).CornerRadius = UDim.new(1, 0)
    H.reg(count, "BackgroundColor3", "Panel")
    H.reg(count, "TextColor3", "Accent")

    btn.MouseEnter:Connect(function()
        if tabs[name] and not tabs[name].Visible then
            H.tw(label, 0.12, { TextColor3 = THEME.Text })
            H.tw(btn, 0.12, { BackgroundTransparency = 0.88 })
            btn.BackgroundColor3 = THEME.PanelHover
        end
    end)
    btn.MouseLeave:Connect(function()
        if tabs[name] and not tabs[name].Visible then
            H.tw(label, 0.12, { TextColor3 = THEME.SubText })
        end
        H.tw(btn, 0.12, { BackgroundTransparency = 1 })
    end)
    btn.MouseButton1Click:Connect(function()
        playGuiClick(btn)
        H.selectTab(name)
    end)

    tabButtons[name] = { button = btn, label = label, icon = icon, count = count }
    return btn
end

H.createTabFrame = function(name)
    local frame = Instance.new("ScrollingFrame")
    frame.Size = UDim2.new(1, -24, 1, -20)
    frame.Position = UDim2.new(0, 12, 0, 10)
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.ScrollBarThickness = 4
    frame.ScrollBarImageColor3 = THEME.Accent
    frame.ScrollBarImageTransparency = 0.35
    frame.CanvasSize = UDim2.new(0, 0, 0, 0)
    frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    frame.ScrollingDirection = Enum.ScrollingDirection.Y
    frame.Visible = false
    frame.ZIndex = 1
    frame.Parent = Content
    H.reg(frame, "ScrollBarImageColor3", "Accent")

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = frame

    local pad = Instance.new("UIPadding")
    pad.PaddingBottom = UDim.new(0, 14)
    pad.PaddingRight = UDim.new(0, 6)
    pad.Parent = frame

    tabs[name] = frame
    return frame
end

----------------------------------------------------------
-- UI-КОМПОНЕНТЫ
----------------------------------------------------------
H.sectionLabel = function(parent, text, order)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 24)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = THEME.SubText
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Bottom
    lbl.LayoutOrder = order
    lbl.Parent = parent
    H.reg(lbl, "TextColor3", "SubText")

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 10)
    pad.Parent = lbl

    local tick = Instance.new("Frame")
    tick.Size = UDim2.new(0, 3, 0, 11)
    tick.Position = UDim2.new(0, -10, 1, -14)
    tick.BackgroundColor3 = THEME.Accent
    tick.BorderSizePixel = 0
    tick.Parent = lbl
    Instance.new("UICorner", tick).CornerRadius = UDim.new(1, 0)
    H.reg(tick, "BackgroundColor3", "Accent")

    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, -6, 0, 1)
    line.Position = UDim2.new(0, 0, 1, -1)
    line.BackgroundColor3 = THEME.Stroke
    line.BackgroundTransparency = 0.45
    line.BorderSizePixel = 0
    line.Parent = lbl
    H.reg(line, "BackgroundColor3", "Stroke")

    local sec = { label = lbl, items = {} }
    table.insert(H._sections, sec)
    H._curSection[parent] = sec
    return lbl
end

H.createButtonRow = function(parent, buttons, order)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 34)
    row.BackgroundTransparency = 1
    row.LayoutOrder = order
    row.Parent = parent

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.Padding = UDim.new(0, 6)
    layout.Parent = row

    local names = {}
    for _, data in ipairs(buttons) do
        names[#names + 1] = data.text
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1 / #buttons, -6, 1, 0)
        btn.BackgroundColor3 = THEME.Panel
        btn.TextColor3 = THEME.Text
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 12
        btn.Text = data.text
        btn.AutoButtonColor = false
        btn.ClipsDescendants = true
        btn.Parent = row
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
        H.reg(btn, "BackgroundColor3", "Panel")
        H.reg(btn, "TextColor3", "Text")

        local st = Instance.new("UIStroke", btn)
        st.Color = THEME.Stroke
        st.Thickness = 1
        st.Transparency = 0.5
        H.reg(st, "Color", "Stroke")

        btn.MouseEnter:Connect(function()
            H.tw(btn, 0.12, { BackgroundColor3 = THEME.PanelHover, TextColor3 = THEME.Accent })
            H.tw(st, 0.12, { Transparency = 0.1 })
            st.Color = THEME.Accent
        end)
        btn.MouseLeave:Connect(function()
            H.tw(btn, 0.14, { BackgroundColor3 = THEME.Panel, TextColor3 = THEME.Text })
            H.tw(st, 0.14, { Transparency = 0.5 })
            st.Color = THEME.Stroke
        end)
        btn.MouseButton1Down:Connect(function(x, y) H.ripple(btn, x, y) end)
        btn.MouseButton1Click:Connect(function()
            playGuiClick(btn)
            data.callback()
        end)
    end
    H.indexItem(row, table.concat(names, " "), parent)
    return row
end

-- один общий обработчик перетаскивания на все слайдеры
H._activeSlider = nil
if not H._sliderInit then
    H._sliderInit = true
    UserInputService.InputChanged:Connect(function(input)
        if H._activeSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            H._activeSlider(input.Position)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            H._activeSlider = nil
            -- сброс визуала ползунка, даже если кнопку отпустили за пределами трека
            if H._sliderRelease then
                pcall(H._sliderRelease)
                H._sliderRelease = nil
            end
        end
    end)
end

H.createSlider = function(parent, text, min, max, default, order, callback)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 44)
    holder.BackgroundTransparency = 1
    holder.LayoutOrder = order
    holder.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 0, 18)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = THEME.Text
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.Parent = holder
    H.reg(label, "TextColor3", "Text")

    -- значение в отдельной «пилюле» справа
    local valueBox = Instance.new("TextLabel")
    valueBox.Size = UDim2.new(0, 50, 0, 18)
    valueBox.Position = UDim2.new(1, -50, 0, 0)
    valueBox.BackgroundColor3 = THEME.Panel
    valueBox.Text = tostring(default)
    valueBox.TextColor3 = THEME.Accent
    valueBox.Font = Enum.Font.GothamBold
    valueBox.TextSize = 11
    valueBox.Parent = holder
    Instance.new("UICorner", valueBox).CornerRadius = UDim.new(0, 6)
    H.reg(valueBox, "BackgroundColor3", "Panel")
    H.reg(valueBox, "TextColor3", "Accent")

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, 0, 0, 6)
    track.Position = UDim2.new(0, 0, 0, 27)
    track.BackgroundColor3 = THEME.Panel
    track.BorderSizePixel = 0
    track.Parent = holder
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
    H.reg(track, "BackgroundColor3", "Panel")

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = THEME.Accent
    fill.BorderSizePixel = 0
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    H.reg(fill, "BackgroundColor3", "Accent")
    do
        local g = Instance.new("UIGradient")
        g.Parent = fill
        H.regFn(function()
            g.Color = ColorSequence.new(H.darken(THEME.Accent, 0.45), THEME.Accent)
        end)
    end

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 12, 0, 12)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new((default - min) / (max - min), 0, 0.5, 0)
    knob.BackgroundColor3 = THEME.Text
    knob.BorderSizePixel = 0
    knob.ZIndex = 3
    knob.Parent = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    H.reg(knob, "BackgroundColor3", "Text")
    do
        local st = Instance.new("UIStroke", knob)
        st.Color = THEME.Accent
        st.Thickness = 2
        st.Transparency = 0.15
        H.reg(st, "Color", "Accent")
    end

    local dragging = false
    local currentValue = default
    local function applyValue(value, fireCallback)
        value = math.clamp(value, min, max)
        currentValue = math.floor(value)
        local relative = (value - min) / (max - min)
        if dragging then
            fill.Size = UDim2.new(relative, 0, 1, 0)
            knob.Position = UDim2.new(relative, 0, 0.5, 0)
        else
            H.tw(fill, 0.1, { Size = UDim2.new(relative, 0, 1, 0) })
            H.tw(knob, 0.1, { Position = UDim2.new(relative, 0, 0.5, 0) })
        end
        valueBox.Text = tostring(currentValue)
        if fireCallback ~= false then
            callback(currentValue)
        end
    end
    local function update(inputPos)
        local relative = math.clamp((inputPos.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        applyValue(min + (max - min) * relative)
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            H._activeSlider = update
            H._sliderRelease = function()
                dragging = false
                H.tw(knob, 0.12, { Size = UDim2.new(0, 12, 0, 12) })
                H.tw(track, 0.12, { Size = UDim2.new(1, 0, 0, 6), Position = UDim2.new(0, 0, 0, 27) })
            end
            H.tw(knob, 0.1, { Size = UDim2.new(0, 16, 0, 16) }, Enum.EasingStyle.Back)
            H.tw(track, 0.1, { Size = UDim2.new(1, 0, 0, 8), Position = UDim2.new(0, 0, 0, 26) })
            update(input.Position)
        end
    end)
    track.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            H.tw(knob, 0.12, { Size = UDim2.new(0, 12, 0, 12) })
            H.tw(track, 0.12, { Size = UDim2.new(1, 0, 0, 6), Position = UDim2.new(0, 0, 0, 27) })
        end
    end)
    track.MouseEnter:Connect(function()
        if not dragging then H.tw(knob, 0.1, { Size = UDim2.new(0, 14, 0, 14) }) end
    end)
    track.MouseLeave:Connect(function()
        if not dragging then H.tw(knob, 0.1, { Size = UDim2.new(0, 12, 0, 12) }) end
    end)

    H.indexItem(holder, text, parent)
    -- .Set(value, fireCallback) / .Get() — для системы конфигов
    return { Frame = holder, Set = applyValue, Get = function() return currentValue end }
end

H.createToggleRow = function(parent, text, order, callback, defaultOn)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 36)
    holder.BackgroundColor3 = THEME.Panel
    holder.LayoutOrder = order
    holder.ClipsDescendants = true
    holder.Parent = parent
    Instance.new("UICorner", holder).CornerRadius = UDim.new(0, 8)
    H.reg(holder, "BackgroundColor3", "Panel")

    local st = Instance.new("UIStroke", holder)
    st.Color = THEME.Stroke
    st.Thickness = 1
    st.Transparency = 0.55
    H.reg(st, "Color", "Stroke")

    -- вертикальная акцентная полоска слева = «включено»
    local mark = Instance.new("Frame")
    mark.Size = UDim2.new(0, 3, 0, 18)
    mark.Position = UDim2.new(0, 0, 0.5, -9)
    mark.BackgroundColor3 = THEME.Accent
    mark.BackgroundTransparency = defaultOn and 0 or 1
    mark.BorderSizePixel = 0
    mark.ZIndex = 3
    mark.Parent = holder
    Instance.new("UICorner", mark).CornerRadius = UDim.new(1, 0)
    H.reg(mark, "BackgroundColor3", "Accent")

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -72, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = THEME.Text
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTruncate = Enum.TextTruncate.AtEnd
    label.ZIndex = 2
    label.Parent = holder
    H.reg(label, "TextColor3", "Text")

    local switchBG = Instance.new("Frame")
    switchBG.Size = UDim2.new(0, 40, 0, 20)
    switchBG.Position = UDim2.new(1, -52, 0.5, -10)
    switchBG.BackgroundColor3 = defaultOn and THEME.Accent or H.lighten(THEME.Panel, 0.14)
    switchBG.BorderSizePixel = 0
    switchBG.ZIndex = 2
    switchBG.Parent = holder
    Instance.new("UICorner", switchBG).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = defaultOn and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.ZIndex = 3
    knob.Parent = switchBG
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local state = defaultOn and true or false
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.ZIndex = 4
    btn.Parent = holder

    local function applyState(newState, fireCallback)
        state = newState and true or false
        H.tw(switchBG, 0.16, {
            BackgroundColor3 = state and THEME.Accent or H.lighten(THEME.Panel, 0.14)
        })
        H.tw(knob, 0.18, {
            Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        }, Enum.EasingStyle.Back)
        H.tw(mark, 0.16, { BackgroundTransparency = state and 0 or 1 })
        if fireCallback ~= false then
            callback(state)
        end
    end
    H.regFn(function()
        switchBG.BackgroundColor3 = state and THEME.Accent or H.lighten(THEME.Panel, 0.14)
    end)

    btn.MouseEnter:Connect(function()
        H.tw(holder, 0.12, { BackgroundColor3 = THEME.PanelHover })
        H.tw(st, 0.12, { Transparency = 0.2 })
    end)
    btn.MouseLeave:Connect(function()
        H.tw(holder, 0.14, { BackgroundColor3 = THEME.Panel })
        H.tw(st, 0.14, { Transparency = 0.55 })
    end)
    btn.MouseButton1Down:Connect(function(x, y) H.ripple(holder, x, y) end)
    btn.MouseButton1Click:Connect(function()
        playGuiClick(holder)
        applyState(not state)
    end)

    H.indexItem(holder, text, parent)
    -- .Set(value, fireCallback) — программное переключение (для конфигов), .Get() — чтение
    return { Frame = holder, Set = applyState, Get = function() return state end }
end

H.createInputRow = function(parent, placeholder, buttonText, order, callback)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, 0, 0, 34)
    holder.BackgroundTransparency = 1
    holder.LayoutOrder = order
    holder.Parent = parent

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -92, 1, 0)
    box.BackgroundColor3 = THEME.Panel
    box.TextColor3 = THEME.Text
    box.PlaceholderText = placeholder
    box.PlaceholderColor3 = THEME.SubText
    box.Font = Enum.Font.Gotham
    box.TextSize = 12
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.ClearTextOnFocus = false
    box.Text = ""
    box.Parent = holder
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)
    H.reg(box, "BackgroundColor3", "Panel")
    H.reg(box, "TextColor3", "Text")
    H.reg(box, "PlaceholderColor3", "SubText")

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 10)
    pad.PaddingRight = UDim.new(0, 8)
    pad.Parent = box

    local st = Instance.new("UIStroke", box)
    st.Color = THEME.Stroke
    st.Thickness = 1
    st.Transparency = 0.5
    H.reg(st, "Color", "Stroke")
    box.Focused:Connect(function()
        st.Color = THEME.Accent
        H.tw(st, 0.15, { Transparency = 0 })
    end)
    box.FocusLost:Connect(function()
        st.Color = THEME.Stroke
        H.tw(st, 0.15, { Transparency = 0.5 })
    end)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 84, 1, 0)
    btn.Position = UDim2.new(1, -84, 0, 0)
    btn.BackgroundColor3 = THEME.AccentSoft
    btn.TextColor3 = THEME.Text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.Text = buttonText
    btn.AutoButtonColor = false
    btn.ClipsDescendants = true
    btn.Parent = holder
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    H.reg(btn, "BackgroundColor3", "AccentSoft")
    H.reg(btn, "TextColor3", "Text")

    btn.MouseEnter:Connect(function() H.tw(btn, 0.12, { BackgroundColor3 = THEME.Accent, TextColor3 = Color3.fromRGB(15, 18, 20) }) end)
    btn.MouseLeave:Connect(function() H.tw(btn, 0.14, { BackgroundColor3 = THEME.AccentSoft, TextColor3 = THEME.Text }) end)
    btn.MouseButton1Down:Connect(function(x, y) H.ripple(btn, x, y) end)
    btn.MouseButton1Click:Connect(function()
        playGuiClick(btn)
        callback(box.Text)
    end)
    box.FocusLost:Connect(function(enterPressed)
        if enterPressed then callback(box.Text) end
    end)

    H.indexItem(holder, tostring(placeholder) .. " " .. tostring(buttonText), parent)
    return holder, box
end

H.createColorSliders = function(parent, title, order, default, callback)
    local sec = H.sectionLabel(parent, title, order)
    local r, g, b = math.floor(default.R * 255), math.floor(default.G * 255), math.floor(default.B * 255)

    -- живой образец цвета справа от заголовка
    local swatch = Instance.new("Frame")
    swatch.Size = UDim2.new(0, 34, 0, 14)
    swatch.Position = UDim2.new(1, -40, 1, -17)
    swatch.BackgroundColor3 = default
    swatch.BorderSizePixel = 0
    swatch.Parent = sec
    Instance.new("UICorner", swatch).CornerRadius = UDim.new(0, 4)
    local swStroke = Instance.new("UIStroke", swatch)
    swStroke.Color = THEME.Stroke
    swStroke.Transparency = 0.3
    H.reg(swStroke, "Color", "Stroke")

    local function push(fireCallback)
        swatch.BackgroundColor3 = Color3.fromRGB(r, g, b)
        if fireCallback ~= false then
            callback(Color3.fromRGB(r, g, b))
        end
    end
    local rHandle = H.createSlider(parent, "R", 0, 255, r, order + 1, function(v) r = v; push() end)
    local gHandle = H.createSlider(parent, "G", 0, 255, g, order + 2, function(v) g = v; push() end)
    local bHandle = H.createSlider(parent, "B", 0, 255, b, order + 3, function(v) b = v; push() end)

    local function applyColor(color, fireCallback)
        r, g, b = math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255)
        rHandle.Set(r, false)
        gHandle.Set(g, false)
        bHandle.Set(b, false)
        push(fireCallback)
    end
    return { Set = applyColor, Get = function() return Color3.fromRGB(r, g, b) end }
end

-- подсказка по горячей клавише внизу сайдбара
do
    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, 0, 0, 26)
    hint.BackgroundTransparency = 1
    hint.Text = "[K] открыть/закрыть   ·   [/] поиск"
    hint.TextColor3 = THEME.SubText
    hint.TextTransparency = 0.35
    hint.Font = Enum.Font.Gotham
    hint.TextSize = 9
    hint.TextWrapped = true
    hint.LayoutOrder = 999
    hint.Parent = TabList
    H.reg(hint, "TextColor3", "SubText")
    task.spawn(function()
        while hint.Parent do
            task.wait(1)
            hint.Text = "[" .. menuHotkey.Name .. "] открыть/закрыть   ·   [/] поиск"
        end
    end)
end

-- авто-уменьшение окна на маленьких экранах (телефон/планшет)
do
    local vp = camera and camera.ViewportSize
    if vp and vp.X > 0 and vp.X < 900 then
        local s = Instance.new("UIScale")
        s.Scale = math.clamp(vp.X / 900, 0.62, 1)
        s.Parent = MainFrame
    end
end

H.refreshTheme()

----------------------------------------------------------
-- КАТЕГОРИЯ: МИР
----------------------------------------------------------
-- Весь контент вкладок в отдельной функции — свой лимит 200 locals
H.__build_Sky = function()
H.createCategoryHeader("МИР", 4)
H.createTabButton("Небо", 5, CATEGORY_COLORS.World)
skyTab = H.createTabFrame("Небо")

local function getSky()
    local sky = Lighting:FindFirstChildOfClass("Sky")
    if not sky then
        sky = Instance.new("Sky")
        sky.Parent = Lighting
    end
    return sky
end

local function getAtmosphere()
    local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
    if not atmo then
        atmo = Instance.new("Atmosphere")
        atmo.Parent = Lighting
    end
    return atmo
end

H.sectionLabel(skyTab, "ПРЕСЕТЫ НЕБА", 1)
H.createButtonRow(skyTab, {
    { text = "Ясный день", callback = function()
        Lighting.ClockTime = 14
        Lighting.Brightness = 3
        Lighting.Ambient = Color3.fromRGB(150, 150, 150)
        Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 150)
        Lighting.FogColor = Color3.fromRGB(200, 220, 255)
    end },
    { text = "Закат", callback = function()
        Lighting.ClockTime = 18.2
        Lighting.Brightness = 2
        Lighting.Ambient = Color3.fromRGB(180, 120, 90)
        Lighting.OutdoorAmbient = Color3.fromRGB(180, 120, 90)
        Lighting.FogColor = Color3.fromRGB(255, 140, 90)
    end },
    { text = "Ночь", callback = function()
        Lighting.ClockTime = 0
        Lighting.Brightness = 0.5
        Lighting.Ambient = Color3.fromRGB(30, 30, 50)
        Lighting.OutdoorAmbient = Color3.fromRGB(30, 30, 50)
        Lighting.FogColor = Color3.fromRGB(10, 10, 20)
    end },
}, 2)

H.createButtonRow(skyTab, {
    { text = "Аврора", callback = function()
        Lighting.ClockTime = 23
        Lighting.Ambient = Color3.fromRGB(60, 40, 110)
        Lighting.OutdoorAmbient = Color3.fromRGB(50, 90, 130)
        Lighting.FogColor = Color3.fromRGB(60, 40, 110)
    end },
    { text = "Пасмурно", callback = function()
        Lighting.ClockTime = 13
        Lighting.Brightness = 1.5
        Lighting.Ambient = Color3.fromRGB(120, 120, 130)
        Lighting.OutdoorAmbient = Color3.fromRGB(120, 120, 130)
        Lighting.FogColor = Color3.fromRGB(150, 150, 160)
    end },
    { text = "Сброс", callback = function()
        Lighting.ClockTime = 14
        Lighting.Brightness = 2
        Lighting.Ambient = Color3.fromRGB(140, 140, 140)
        Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 140)
        Lighting.FogColor = Color3.fromRGB(192, 192, 192)
        getAtmosphere().Color = Color3.fromRGB(199, 199, 199)
        getAtmosphere().Density = 0.3
        getAtmosphere().Haze = 0
        getAtmosphere().Glare = 0
    end },
}, 3)

H.createButtonRow(skyTab, {
    { text = "Кровавый", callback = function()
        Lighting.ClockTime = 0
        Lighting.Ambient = Color3.fromRGB(80, 10, 10)
        Lighting.OutdoorAmbient = Color3.fromRGB(100, 20, 20)
        Lighting.FogColor = Color3.fromRGB(60, 0, 0)
        Lighting.Brightness = 1
    end },
    { text = "Неон-сити", callback = function()
        Lighting.ClockTime = 22
        Lighting.Ambient = Color3.fromRGB(40, 20, 80)
        Lighting.OutdoorAmbient = Color3.fromRGB(20, 60, 120)
        Lighting.FogColor = Color3.fromRGB(30, 10, 60)
        Lighting.Brightness = 1.5
    end },
    { text = "Без тумана", callback = function()
        Lighting.FogEnd = 100000
        getAtmosphere().Density = 0
        getAtmosphere().Haze = 0
    end },
}, 3)

H.sectionLabel(skyTab, "ВРЕМЯ СУТОК И ТУМАН", 4)
H.createSlider(skyTab, "Время суток (0-24ч)", 0, 24, 14, 5, function(v)
    Lighting.ClockTime = v
end)
H.createSlider(skyTab, "Яркость", 0, 10, 2, 6, function(v)
    Lighting.Brightness = v
end)
H.createSlider(skyTab, "Плотность тумана (100000 = нет)", 0, 100000, 100000, 7, function(v)
    Lighting.FogEnd = v
end)

H.createColorSliders(skyTab, "ЦВЕТ НЕБА / АТМОСФЕРЫ (RGB)", 8, Color3.fromRGB(199, 199, 199), function(color)
    local atmo = getAtmosphere()
    atmo.Color = color
    Lighting.FogColor = color
end)

H.sectionLabel(skyTab, "ПАРАМЕТРЫ АТМОСФЕРЫ", 12)
H.createSlider(skyTab, "Плотность дымки (Density x100)", 0, 100, 30, 13, function(v)
    getAtmosphere().Density = v / 100
end)
H.createSlider(skyTab, "Дымка (Haze)", 0, 10, 0, 14, function(v)
    getAtmosphere().Haze = v
end)
H.createSlider(skyTab, "Блики (Glare)", 0, 10, 0, 15, function(v)
    getAtmosphere().Glare = v
end)

H.sectionLabel(skyTab, "ЗВЁЗДЫ", 16)
H.createSlider(skyTab, "Количество звёзд", 0, 3000, 3000, 17, function(v)
    getSky().StarCount = v
end)

H.sectionLabel(skyTab, "КАСТОМНЫЙ СКАЙБОКС (ID текстуры)", 18)
H.createInputRow(skyTab, "Например: 123456789", "Применить", 19, function(text)
    local id = text:match("%d+")
    if not id then return end
    local sky = getSky()
    local assetStr = "rbxassetid://" .. id
    sky.SkyboxBk = assetStr
    sky.SkyboxDn = assetStr
    sky.SkyboxFt = assetStr
    sky.SkyboxLf = assetStr
    sky.SkyboxRt = assetStr
    sky.SkyboxUp = assetStr
end)

H.sectionLabel(skyTab, "ТЕКСТУРА СОЛНЦА / ЛУНЫ (ID)", 20)
H.createInputRow(skyTab, "ID текстуры солнца", "Солнце", 21, function(text)
    local id = text:match("%d+")
    if id then getSky().SunTextureId = "rbxassetid://" .. id end
end)
H.createInputRow(skyTab, "ID текстуры луны", "Луна", 22, function(text)
    local id = text:match("%d+")
    if id then getSky().MoonTextureId = "rbxassetid://" .. id end
end)


----------------------------------------------------------
end

H.__build_Fx = function()
-- ВКЛАДКА: ЭФФЕКТЫ (постобработка экрана)
----------------------------------------------------------
H.createTabButton("Эффекты", 6, CATEGORY_COLORS.World)
fxTab = H.createTabFrame("Эффекты")

local function getOrCreate(className)
    local existing = Lighting:FindFirstChildOfClass(className)
    if existing then return existing end
    local inst = Instance.new(className)
    inst.Parent = Lighting
    return inst
end

local ColorCorrection = getOrCreate("ColorCorrectionEffect")
local Bloom = getOrCreate("BloomEffect")
local Blur = getOrCreate("BlurEffect")
local SunRays = getOrCreate("SunRaysEffect")
local DepthOfField = getOrCreate("DepthOfFieldEffect")

ColorCorrection.Saturation = 0
ColorCorrection.Contrast = 0
ColorCorrection.Brightness = 0
ColorCorrection.TintColor = Color3.fromRGB(255, 255, 255)
Bloom.Intensity = 0
Bloom.Size = 24
Bloom.Threshold = 2
Blur.Size = 0
SunRays.Intensity = 0
SunRays.Spread = 0
DepthOfField.Enabled = false
DepthOfField.FarIntensity = 0
DepthOfField.NearIntensity = 0

H.sectionLabel(fxTab, "ЦВЕТОКОРРЕКЦИЯ — ПРЕСЕТЫ", 1)
H.createButtonRow(fxTab, {
    { text = "Ярко", callback = function()
        ColorCorrection.Saturation = 0.4
        ColorCorrection.Contrast = 0.15
        ColorCorrection.Brightness = 0.05
    end },
    { text = "Ч/Б", callback = function()
        ColorCorrection.Saturation = -1
    end },
    { text = "Тепло", callback = function()
        ColorCorrection.TintColor = Color3.fromRGB(255, 220, 190)
        ColorCorrection.Saturation = 0.1
    end },
}, 2)

H.createButtonRow(fxTab, {
    { text = "Холод", callback = function()
        ColorCorrection.TintColor = Color3.fromRGB(190, 210, 255)
        ColorCorrection.Saturation = 0.1
    end },
    { text = "Сброс", callback = function()
        ColorCorrection.Saturation = 0
        ColorCorrection.Contrast = 0
        ColorCorrection.Brightness = 0
        ColorCorrection.TintColor = Color3.fromRGB(255, 255, 255)
    end },
}, 3)

H.createColorSliders(fxTab, "СВОЙ ОТТЕНОК ЭКРАНА (TINT RGB)", 4, Color3.fromRGB(255, 255, 255), function(color)
    ColorCorrection.TintColor = color
end)

H.sectionLabel(fxTab, "СВЕЧЕНИЕ / РАЗМЫТИЕ / ЛУЧИ", 11)
H.createSlider(fxTab, "Bloom интенсивность", 0, 10, 0, 12, function(v)
    Bloom.Intensity = v
end)
H.createSlider(fxTab, "Размытие фона (Blur)", 0, 30, 0, 13, function(v)
    Blur.Size = v
end)
H.createSlider(fxTab, "Лучи солнца (SunRays)", 0, 100, 0, 14, function(v)
    SunRays.Intensity = v / 100
end)

H.createToggleRow(fxTab, "Размытие глубины (Depth of Field)", 15, function(state)
    DepthOfField.Enabled = state
end)

H.sectionLabel(fxTab, "FULL BRIGHT", 16)
local fullBrightOn = false
local savedLighting = nil
H.fullBright = H.createToggleRow(fxTab, "Full Bright (ярко везде)", 17, function(state)
    fullBrightOn = state
    if state then
        savedLighting = {
            Brightness = Lighting.Brightness,
            Ambient = Lighting.Ambient,
            OutdoorAmbient = Lighting.OutdoorAmbient,
            FogEnd = Lighting.FogEnd,
            GlobalShadows = Lighting.GlobalShadows,
            ClockTime = Lighting.ClockTime,
        }
        Lighting.Brightness = 2
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
    else
        if savedLighting then
            Lighting.Brightness = savedLighting.Brightness
            Lighting.Ambient = savedLighting.Ambient
            Lighting.OutdoorAmbient = savedLighting.OutdoorAmbient
            Lighting.FogEnd = savedLighting.FogEnd
            Lighting.GlobalShadows = savedLighting.GlobalShadows
        end
    end
end)

H.createButtonRow(fxTab, {
    { text = "Сбросить все эффекты", callback = function()
        ColorCorrection.Saturation = 0
        ColorCorrection.Contrast = 0
        ColorCorrection.Brightness = 0
        ColorCorrection.TintColor = Color3.fromRGB(255, 255, 255)
        Bloom.Intensity = 0
        Blur.Size = 0
        SunRays.Intensity = 0
        DepthOfField.Enabled = false
        if fullBrightOn and H.fullBright then
            H.fullBright.Set(false)
        end
    end },
}, 18)

----------------------------------------------------------
end

H.__build_Screen = function()
-- ВКЛАДКА: ЭКРАН (новый тип визуалов — не частицы, а экранные эффекты)
----------------------------------------------------------
H.createTabButton("Экран", 7, CATEGORY_COLORS.World)
screenTab = H.createTabFrame("Экран")

-- отдельный ScreenGui поверх основного меню — здесь живут полноэкранные
-- элементы (леттербокс, прицел, HUD), чтобы они не были ограничены
-- рамками и ClipsDescendants окна меню
OverlayGui = Instance.new("ScreenGui")
OverlayGui.Name = "VisualMenuOverlay"
OverlayGui.ResetOnSpawn = false
OverlayGui.IgnoreGuiInset = true
OverlayGui.DisplayOrder = 50
OverlayGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
OverlayGui.Parent = game:GetService("CoreGui")

H.sectionLabel(screenTab, "ASPECT RATIO / РАСТЯГ (ЧЕРЕЗ FOV)", 1)
-- В Roblox нельзя реально растянуть картинку камеры.
-- «Растяг» = увеличение FOV (шире обзор, как ультраширокий монитор).
-- Чёрных полос нет.
local baseFovForAspect = 70
H.aspectRatio = H.createSlider(screenTab, "Растяг / широкий FOV (0=обычный, 100=макс)", 0, 100, 0, 2, function(v)
    -- 0 -> 70 FOV, 100 -> 120 FOV
    local fov = 70 + (v / 100) * 50
    camera.FieldOfView = fov
    if H.fov and H.fov.Set then
        -- синхронизируем слайдер FOV на вкладке Камера без рекурсии
        pcall(function() H.fov.Set(math.floor(fov), false) end)
    end
end)

H.createButtonRow(screenTab, {
    { text = "Обычный", callback = function() H.aspectRatio.Set(0) end },
    { text = "Широкий", callback = function() H.aspectRatio.Set(40) end },
    { text = "Ультра", callback = function() H.aspectRatio.Set(70) end },
    { text = "Рыбий глаз", callback = function() H.aspectRatio.Set(100) end },
}, 3)

H.sectionLabel(screenTab, "ПРИЦЕЛ (CROSSHAIR)", 10)
local crosshair = Instance.new("Frame")
crosshair.Size = UDim2.new(0, 20, 0, 20)
crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
crosshair.Position = UDim2.new(0.5, 0, 0.5, 0)
crosshair.BackgroundTransparency = 1
crosshair.ZIndex = 3
crosshair.Visible = false
crosshair.Parent = OverlayGui
local function crosshairLine(rotation)
    local line = Instance.new("Frame")
    line.Size = UDim2.new(0, 2, 0, 20)
    line.AnchorPoint = Vector2.new(0.5, 0.5)
    line.Position = UDim2.new(0.5, 0, 0.5, 0)
    line.Rotation = rotation
    line.BackgroundColor3 = THEME.Accent
    line.BorderSizePixel = 0
    line.ZIndex = 3
    line.Parent = crosshair
end
crosshairLine(0)
crosshairLine(90)

H.crosshairToggle = H.createToggleRow(screenTab, "Показать прицел по центру экрана", 11, function(state)
    crosshair.Visible = state
end)
H.crosshairColor = H.createColorSliders(screenTab, "ЦВЕТ ПРИЦЕЛА (RGB)", 12, THEME.Accent, function(color)
    for _, line in ipairs(crosshair:GetChildren()) do
        if line:IsA("Frame") then line.BackgroundColor3 = color end
    end
end)

H.sectionLabel(screenTab, "ГОРЯЧАЯ КЛАВИША ОТКРЫТИЯ МЕНЮ", 32)
local hotkeyLabel
H.createButtonRow(screenTab, {
    { text = "Нажмите, затем клавишу", callback = function()
        hotkeyListening = true
        hotkeyLabel.Text = "Ожидание клавиши..."
    end },
}, 33)
hotkeyLabel = Instance.new("TextLabel")
hotkeyLabel.Size = UDim2.new(1, 0, 0, 18)
hotkeyLabel.BackgroundTransparency = 1
hotkeyLabel.Text = "Текущая клавиша: K"
hotkeyLabel.TextColor3 = THEME.SubText
hotkeyLabel.Font = Enum.Font.Gotham
hotkeyLabel.TextSize = 12
hotkeyLabel.TextXAlignment = Enum.TextXAlignment.Left
hotkeyLabel.LayoutOrder = 34
hotkeyLabel.Parent = screenTab

----------------------------------------------------------
-- КАТЕГОРИЯ: ПЕРСОНАЖ
----------------------------------------------------------
H.createCategoryHeader("ПЕРСОНАЖ", 8)

----------------------------------------------------------
end

H.__build_Particles = function()
-- ВКЛАДКА: ЧАСТИЦЫ (доп. визуальные эффекты на персонаже)
----------------------------------------------------------
H.createTabButton("Частицы", 9, CATEGORY_COLORS.Player)
fxCharTab = H.createTabFrame("Частицы")

local trailObj, trailAtt0, trailAtt1
local trailRainbowConn, trailHue = nil, 0
local auraEmitter
local highlightObj
local footstepConn
local footstepEnabled = false
local glowLight

local function getRoot()
    local char = player.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart")
end

local function ensureTrail()
    local root = getRoot()
    if not root then return end
    if trailObj and trailObj.Parent then return end
    trailAtt0 = Instance.new("Attachment")
    trailAtt0.Name = "__TrailAtt0"
    trailAtt0.Position = Vector3.new(-1, 0, 0)
    trailAtt0.Parent = root
    trailAtt1 = Instance.new("Attachment")
    trailAtt1.Name = "__TrailAtt1"
    trailAtt1.Position = Vector3.new(1, 0, 0)
    trailAtt1.Parent = root
    trailObj = Instance.new("Trail")
    trailObj.Attachment0 = trailAtt0
    trailObj.Attachment1 = trailAtt1
    trailObj.Color = ColorSequence.new(THEME.Accent)
    trailObj.Lifetime = 0.6
    trailObj.WidthScale = NumberSequence.new(1, 0)
    trailObj.Enabled = false
    trailObj.Parent = root
end

H.sectionLabel(fxCharTab, "СЛЕД ЗА ПЕРСОНАЖЕМ (TRAIL)", 1)
H.trailToggle = H.createToggleRow(fxCharTab, "Включить след", 2, function(state)
    ensureTrail()
    if trailObj then trailObj.Enabled = state end
end)
H.trailColor = H.createColorSliders(fxCharTab, "ЦВЕТ СЛЕДА (RGB)", 3, THEME.Accent, function(color)
    ensureTrail()
    if trailObj then trailObj.Color = ColorSequence.new(color) end
end)
H.trailRainbow = H.createToggleRow(fxCharTab, "Радужный след (цвет переливается)", 7, function(state)
    ensureTrail()
    if state then
        trailRainbowConn = RunService.Heartbeat:Connect(function(dt)
            trailHue = (trailHue + dt * 0.2) % 1
            if trailObj then
                trailObj.Color = ColorSequence.new(Color3.fromHSV(trailHue, 1, 1))
            end
        end)
    else
        if trailRainbowConn then
            trailRainbowConn:Disconnect()
            trailRainbowConn = nil
        end
    end
end)
H.trailLifetime = H.createSlider(fxCharTab, "Время жизни следа x10", 1, 50, 6, 8, function(v)
    ensureTrail()
    if trailObj then trailObj.Lifetime = v / 10 end
end)

H.sectionLabel(fxCharTab, "АУРА (ЧАСТИЦЫ ВОКРУГ ПЕРСОНАЖА)", 9)
local function ensureAura()
    local root = getRoot()
    if not root then return end
    if auraEmitter and auraEmitter.Parent then return end
    auraEmitter = Instance.new("ParticleEmitter")
    auraEmitter.Name = "__AuraEmitter"
    auraEmitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    auraEmitter.Rate = 0
    auraEmitter.Lifetime = NumberRange.new(0.6, 1.2)
    auraEmitter.Speed = NumberRange.new(1, 2)
    auraEmitter.Size = NumberSequence.new(0.4)
    auraEmitter.Color = ColorSequence.new(THEME.Accent)
    auraEmitter.Parent = root
end
H.auraToggle = H.createToggleRow(fxCharTab, "Включить ауру частиц", 10, function(state)
    ensureAura()
    if auraEmitter then auraEmitter.Rate = state and 20 or 0 end
end)
H.auraColor = H.createColorSliders(fxCharTab, "ЦВЕТ АУРЫ (RGB)", 11, THEME.Accent, function(color)
    ensureAura()
    if auraEmitter then auraEmitter.Color = ColorSequence.new(color) end
end)

H.sectionLabel(fxCharTab, "ОБВОДКА ПЕРСОНАЖА (HIGHLIGHT)", 15)
local function ensureHighlight()
    local char = player.Character
    if not char then return end
    if highlightObj and highlightObj.Parent then return end
    highlightObj = Instance.new("Highlight")
    highlightObj.Name = "__VisualHighlight"
    highlightObj.FillTransparency = 1
    highlightObj.OutlineTransparency = 0
    highlightObj.OutlineColor = THEME.Accent
    highlightObj.Enabled = false
    highlightObj.Parent = char
end
H.highlightToggle = H.createToggleRow(fxCharTab, "Включить обводку", 16, function(state)
    ensureHighlight()
    if highlightObj then highlightObj.Enabled = state end
end)
H.highlightColor = H.createColorSliders(fxCharTab, "ЦВЕТ ОБВОДКИ (RGB)", 17, THEME.Accent, function(color)
    ensureHighlight()
    if highlightObj then highlightObj.OutlineColor = color end
end)
H.highlightFill = H.createSlider(fxCharTab, "Прозрачность заливки (0=видна, 100=невидима)", 0, 100, 100, 21, function(v)
    ensureHighlight()
    if highlightObj then highlightObj.FillTransparency = v / 100 end
end)

H.sectionLabel(fxCharTab, "ЧАСТИЦЫ ПРИ ХОДЬБЕ", 22)
H.footstepToggle = H.createToggleRow(fxCharTab, "Пыль/искры под ногами", 23, function(state)
    footstepEnabled = state
    local root = getRoot()
    if not root then return end
    if state then
        local emitter = root:FindFirstChild("__FootstepEmitter")
        if not emitter then
            emitter = Instance.new("ParticleEmitter")
            emitter.Name = "__FootstepEmitter"
            emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
            emitter.Rate = 0
            emitter.Lifetime = NumberRange.new(0.3, 0.5)
            emitter.Speed = NumberRange.new(0.5, 1)
            emitter.Size = NumberSequence.new(0.5, 0)
            emitter.Color = ColorSequence.new(Color3.fromRGB(200, 200, 200))
            emitter.Parent = root
        end
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if humanoid and not footstepConn then
            footstepConn = RunService.Heartbeat:Connect(function()
                if not footstepEnabled then return end
                if humanoid.MoveDirection.Magnitude > 0.1 and humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
                    emitter:Emit(1)
                end
            end)
        end
    else
        if footstepConn then
            footstepConn:Disconnect()
            footstepConn = nil
        end
    end
end)

H.sectionLabel(fxCharTab, "СВЕЧЕНИЕ (POINTLIGHT)", 24)
local function ensureGlow()
    local root = getRoot()
    if not root then return end
    if glowLight and glowLight.Parent then return end
    glowLight = Instance.new("PointLight")
    glowLight.Name = "__GlowLight"
    glowLight.Color = THEME.Accent
    glowLight.Brightness = 2
    glowLight.Range = 8
    glowLight.Enabled = false
    glowLight.Parent = root
end
H.glowToggle = H.createToggleRow(fxCharTab, "Включить свечение вокруг себя", 25, function(state)
    ensureGlow()
    if glowLight then glowLight.Enabled = state end
end)
H.glowColor = H.createColorSliders(fxCharTab, "ЦВЕТ СВЕЧЕНИЯ (RGB)", 26, THEME.Accent, function(color)
    ensureGlow()
    if glowLight then glowLight.Color = color end
end)
H.glowRange = H.createSlider(fxCharTab, "Радиус свечения", 4, 30, 8, 30, function(v)
    ensureGlow()
    if glowLight then glowLight.Range = v end
end)

H.sectionLabel(fxCharTab, "ВСПЫШКА ЧАСТИЦ", 31)
H.createButtonRow(fxCharTab, {
    { text = "Салют искр", callback = function()
        local root = getRoot()
        if not root then return end
        local burst = Instance.new("ParticleEmitter")
        burst.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        burst.Lifetime = NumberRange.new(0.5, 1)
        burst.Speed = NumberRange.new(4, 9)
        burst.Size = NumberSequence.new(0.6, 0)
        burst.Color = ColorSequence.new(THEME.Accent)
        burst.Rate = 0
        burst.Parent = root
        burst:Emit(40)
        task.delay(1.2, function() burst:Destroy() end)
    end },
}, 32)

----------------------------------------------------------
-- ДОП. ВИЗУАЛЫ: огонь, лёд, сердца, звёзды, тьма, кольца, afterimage
----------------------------------------------------------
local specialEmitters = {}
local orbitParts = {}
local orbitConn = nil
local afterimageConn = nil
local afterimageEnabled = false
local afterimageParts = {}

local function clearSpecialEmitter(name)
    if specialEmitters[name] then
        pcall(function() specialEmitters[name]:Destroy() end)
        specialEmitters[name] = nil
    end
end

local function makeSpecialEmitter(name, props)
    clearSpecialEmitter(name)
    local root = getRoot()
    if not root then return nil end
    local em = Instance.new("ParticleEmitter")
    em.Name = "__VM_" .. name
    for k, v in pairs(props) do
        pcall(function() em[k] = v end)
    end
    em.Parent = root
    specialEmitters[name] = em
    return em
end

local function clearOrbit()
    if orbitConn then orbitConn:Disconnect(); orbitConn = nil end
    for _, p in ipairs(orbitParts) do
        if p then pcall(function() p:Destroy() end) end
    end
    orbitParts = {}
end

local function clearAfterimage()
    afterimageEnabled = false
    if afterimageConn then afterimageConn:Disconnect(); afterimageConn = nil end
    for _, p in ipairs(afterimageParts) do
        if p then pcall(function() p:Destroy() end) end
    end
    afterimageParts = {}
end

H.sectionLabel(fxCharTab, "СПЕЦЭФФЕКТЫ АУРЫ", 50)
H.createButtonRow(fxCharTab, {
    { text = "Огонь", callback = function()
        makeSpecialEmitter("fire", {
            Texture = "rbxasset://textures/particles/fire_main.dds",
            Rate = 35,
            Lifetime = NumberRange.new(0.4, 0.9),
            Speed = NumberRange.new(2, 6),
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) }),
            Acceleration = Vector3.new(0, 6, 0),
            LightEmission = 0.9,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 80)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 40, 10)),
            }),
            SpreadAngle = Vector2.new(25, 25),
        })
    end },
    { text = "Лёд", callback = function()
        makeSpecialEmitter("ice", {
            Texture = "rbxasset://textures/particles/smoke_main.dds",
            Rate = 28,
            Lifetime = NumberRange.new(0.6, 1.2),
            Speed = NumberRange.new(0.5, 2),
            Size = NumberSequence.new(0.5, 0),
            Acceleration = Vector3.new(0, -1, 0),
            LightEmission = 0.4,
            Color = ColorSequence.new(Color3.fromRGB(160, 220, 255), Color3.fromRGB(80, 140, 220)),
            Transparency = NumberSequence.new(0.2, 1),
            SpreadAngle = Vector2.new(40, 40),
        })
    end },
    { text = "Сердца", callback = function()
        makeSpecialEmitter("hearts", {
            Texture = "rbxassetid://6031097226",
            Rate = 12,
            Lifetime = NumberRange.new(0.8, 1.4),
            Speed = NumberRange.new(1, 3),
            Size = NumberSequence.new(0.55, 0),
            Acceleration = Vector3.new(0, 3, 0),
            LightEmission = 0.6,
            Color = ColorSequence.new(Color3.fromRGB(255, 90, 140)),
            SpreadAngle = Vector2.new(50, 50),
            Rotation = NumberRange.new(-20, 20),
        })
    end },
    { text = "Звёзды", callback = function()
        makeSpecialEmitter("stars", {
            Texture = "rbxasset://textures/particles/sparkles_main.dds",
            Rate = 40,
            Lifetime = NumberRange.new(0.5, 1.1),
            Speed = NumberRange.new(1, 4),
            Size = NumberSequence.new(0.35, 0),
            LightEmission = 1,
            Color = ColorSequence.new(Color3.fromRGB(255, 240, 120), Color3.fromRGB(180, 120, 255)),
            SpreadAngle = Vector2.new(180, 180),
        })
    end },
}, 51)

H.createButtonRow(fxCharTab, {
    { text = "Тьма", callback = function()
        makeSpecialEmitter("dark", {
            Texture = "rbxasset://textures/particles/smoke_main.dds",
            Rate = 22,
            Lifetime = NumberRange.new(0.7, 1.3),
            Speed = NumberRange.new(0.3, 1.5),
            Size = NumberSequence.new(0.9, 0),
            Acceleration = Vector3.new(0, 1, 0),
            LightEmission = 0,
            Color = ColorSequence.new(Color3.fromRGB(20, 10, 30), Color3.fromRGB(5, 0, 10)),
            Transparency = NumberSequence.new(0.3, 1),
            SpreadAngle = Vector2.new(60, 60),
        })
    end },
    { text = "Молнии", callback = function()
        makeSpecialEmitter("spark", {
            Texture = "rbxasset://textures/particles/sparkles_main.dds",
            Rate = 50,
            Lifetime = NumberRange.new(0.15, 0.35),
            Speed = NumberRange.new(8, 16),
            Size = NumberSequence.new(0.25, 0),
            LightEmission = 1,
            Color = ColorSequence.new(Color3.fromRGB(180, 220, 255), Color3.fromRGB(100, 160, 255)),
            SpreadAngle = Vector2.new(180, 180),
        })
    end },
    { text = "Выкл. все", callback = function()
        for name in pairs(specialEmitters) do
            clearSpecialEmitter(name)
        end
    end },
}, 52)

H.sectionLabel(fxCharTab, "ОРБИТАЛЬНЫЕ КОЛЬЦА", 53)
H.createToggleRow(fxCharTab, "Орбитальные кольца вокруг себя", 54, function(state)
    clearOrbit()
    if not state then return end
    local root = getRoot()
    if not root then return end
    local colors = {
        THEME.Accent,
        Color3.fromRGB(100, 200, 255),
        Color3.fromRGB(255, 120, 200),
    }
    for i = 1, 3 do
        local p = Instance.new("Part")
        p.Name = "__VM_Orbit"
        p.Shape = Enum.PartType.Ball
        p.Size = Vector3.new(0.35, 0.35, 0.35)
        p.Material = Enum.Material.Neon
        p.Color = colors[i]
        p.CanCollide = false
        p.Massless = true
        p.Anchored = true
        p.CastShadow = false
        p.Parent = workspace
        local light = Instance.new("PointLight")
        light.Brightness = 1.2
        light.Range = 6
        light.Color = colors[i]
        light.Parent = p
        table.insert(orbitParts, p)
    end
    local t0 = os.clock()
    orbitConn = RunService.RenderStepped:Connect(function()
        local r = getRoot()
        if not r then return end
        local t = os.clock() - t0
        for i, p in ipairs(orbitParts) do
            if p and p.Parent then
                local ang = t * (1.4 + i * 0.35) + i * 2.1
                local rad = 2.2 + i * 0.35
                local y = math.sin(t * 2 + i) * 0.6
                p.CFrame = CFrame.new(r.Position + Vector3.new(math.cos(ang) * rad, 1.2 + y, math.sin(ang) * rad))
            end
        end
    end)
end)

H.sectionLabel(fxCharTab, "AFTERIMAGE (СЛЕД-СИЛУЭТ ПРИ БЕГЕ)", 55)
H.createToggleRow(fxCharTab, "Afterimage при беге", 56, function(state)
    clearAfterimage()
    if not state then return end
    afterimageEnabled = true
    local lastSpawn = 0
    afterimageConn = RunService.Heartbeat:Connect(function()
        if not afterimageEnabled then return end
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not (root and hum) then return end
        if hum.MoveDirection.Magnitude < 0.4 then return end
        local now = os.clock()
        if now - lastSpawn < 0.08 then return end
        lastSpawn = now
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency < 1 then
                local ghost = Instance.new("Part")
                ghost.Size = part.Size
                ghost.CFrame = part.CFrame
                ghost.Anchored = true
                ghost.CanCollide = false
                ghost.Material = Enum.Material.ForceField
                ghost.Color = THEME.Accent
                ghost.Transparency = 0.45
                ghost.CastShadow = false
                ghost.Parent = workspace
                table.insert(afterimageParts, ghost)
                task.spawn(function()
                    for i = 1, 8 do
                        ghost.Transparency = 0.45 + i * 0.07
                        task.wait(0.03)
                    end
                    ghost:Destroy()
                end)
            end
        end
        -- чистим список от мёртвых
        local alive = {}
        for _, p in ipairs(afterimageParts) do
            if p and p.Parent then table.insert(alive, p) end
        end
        afterimageParts = alive
    end)
end)

player.CharacterAdded:Connect(function()
    task.wait(0.5)
    -- спецэмиттеры пересоздаются пользователем вручную
end)

----------------------------------------------------------
-- РАДУЖНЫЙ НИМБ НАД ГОЛОВОЙ
----------------------------------------------------------
local haloParts = {}
local haloConn = nil
local function clearHalo()
    if haloConn then haloConn:Disconnect() haloConn = nil end
    for _, p in ipairs(haloParts) do
        if p and p.Parent then p:Destroy() end
    end
    haloParts = {}
end
H.sectionLabel(fxCharTab, "РАДУЖНЫЙ НИМБ (HALO)", 57)
H.createToggleRow(fxCharTab, "Нимб над головой", 58, function(state)
    clearHalo()
    if not state then return end
    local root = getRoot()
    if not root then return end
    local count = 14
    for _ = 1, count do
        local p = Instance.new("Part")
        p.Name = "__VM_Halo"
        p.Shape = Enum.PartType.Ball
        p.Size = Vector3.new(0.22, 0.22, 0.22)
        p.Material = Enum.Material.Neon
        p.CanCollide = false
        p.Massless = true
        p.Anchored = true
        p.CastShadow = false
        p.Parent = workspace
        table.insert(haloParts, p)
    end
    local t0 = os.clock()
    haloConn = RunService.RenderStepped:Connect(function()
        local r = getRoot()
        if not r then return end
        local t = os.clock() - t0
        for i, p in ipairs(haloParts) do
            if p and p.Parent then
                local frac = i / #haloParts
                local ang = t * 1.1 + frac * math.pi * 2
                local rad = 1.35
                p.CFrame = CFrame.new(r.Position + Vector3.new(math.cos(ang) * rad, 3.1 + math.sin(t * 2 + i) * 0.05, math.sin(ang) * rad))
                p.Color = Color3.fromHSV((frac + t * 0.12) % 1, 0.85, 1)
            end
        end
    end)
end)

----------------------------------------------------------
-- УДАРНАЯ ВОЛНА ПОД НОГАМИ
----------------------------------------------------------
local groundPulseEnabled = false
local pulseConn = nil
H.sectionLabel(fxCharTab, "УДАРНАЯ ВОЛНА ПОД НОГАМИ", 59)
H.createToggleRow(fxCharTab, "Пульсирующие круги под ногами", 60, function(state)
    groundPulseEnabled = state
    if pulseConn then
        pulseConn:Disconnect()
        pulseConn = nil
    end
    if not state then return end
    local lastPulse = 0
    pulseConn = RunService.Heartbeat:Connect(function()
        if not groundPulseEnabled then return end
        local root = getRoot()
        if not root then return end
        local now = os.clock()
        if now - lastPulse < 0.9 then return end
        lastPulse = now
        local ring = Instance.new("Part")
        ring.Name = "__VM_Pulse"
        ring.Shape = Enum.PartType.Cylinder
        ring.Size = Vector3.new(0.05, 1.6, 1.6)
        ring.Material = Enum.Material.Neon
        ring.Color = THEME.Accent
        ring.Transparency = 0.25
        ring.CanCollide = false
        ring.Anchored = true
        ring.CastShadow = false
        ring.CFrame = CFrame.new(root.Position - Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(90))
        ring.Parent = workspace
        TweenService:Create(ring, TweenInfo.new(0.9, Enum.EasingStyle.Quad), {
            Size = Vector3.new(0.05, 6, 6),
            Transparency = 1,
        }):Play()
        task.delay(0.95, function()
            if ring and ring.Parent then ring:Destroy() end
        end)
    end)
end)

----------------------------------------------------------
-- СТИЛЬ ТЕЛА / PREMIUM VISUALS (без плаща и ореола)
----------------------------------------------------------
H.sectionLabel(fxCharTab, "СТИЛЬ ТЕЛА", 60)

local bodyStyleSaved = {}
local bodyStyleConn = nil
local bodyPulseOn = false
local bodyMat = "neon"

local function restoreBodyStyle()
    for part, data in pairs(bodyStyleSaved) do
        if part and part.Parent and typeof(data) == "table" then
            pcall(function()
                part.Material = data.mat
                part.Color = data.color
                part.Reflectance = data.reflect
                part.Transparency = data.trans
            end)
        end
    end
    bodyStyleSaved = {}
end

local function applyBodyMaterial(style)
    restoreBodyStyle()
    local char = player.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            bodyStyleSaved[part] = {
                mat = part.Material,
                color = part.Color,
                reflect = part.Reflectance,
                trans = part.Transparency,
            }
            if style == "neon" then
                part.Material = Enum.Material.Neon
                part.Color = THEME.Accent
                part.Reflectance = 0
                part.Transparency = 0
            elseif style == "forcefield" then
                part.Material = Enum.Material.ForceField
                part.Color = THEME.Accent
                part.Transparency = 0.15
            elseif style == "glass" then
                part.Material = Enum.Material.Glass
                part.Transparency = 0.4
                part.Reflectance = 0.35
                part.Color = Color3.fromRGB(200, 230, 255)
            elseif style == "chrome" then
                part.Material = Enum.Material.Metal
                part.Reflectance = 0.85
                part.Color = Color3.fromRGB(220, 225, 235)
            end
        end
    end
end

H.createButtonRow(fxCharTab, {
    { text = "Neon", callback = function() bodyMat = "neon"; applyBodyMaterial("neon") end },
    { text = "ForceField", callback = function() bodyMat = "forcefield"; applyBodyMaterial("forcefield") end },
    { text = "Glass", callback = function() bodyMat = "glass"; applyBodyMaterial("glass") end },
    { text = "Chrome", callback = function() bodyMat = "chrome"; applyBodyMaterial("chrome") end },
}, 61)
H.createButtonRow(fxCharTab, {
    { text = "Сброс тела", callback = function()
        restoreBodyStyle()
        bodyPulseOn = false
        if bodyStyleConn then bodyStyleConn:Disconnect(); bodyStyleConn = nil end
    end },
}, 62)

local rainbowBodyOn = false
local function applyBodyPulse()
    if bodyStyleConn then bodyStyleConn:Disconnect(); bodyStyleConn = nil end
    if not bodyPulseOn then return end
    local t0 = os.clock()
    bodyStyleConn = RunService.RenderStepped:Connect(function()
        if not bodyPulseOn then return end
        local char = player.Character
        if not char then return end
        local a = 0.08 + (math.sin((os.clock() - t0) * 2.2) * 0.5 + 0.5) * 0.35
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.Transparency = a
            end
        end
    end)
end
local function applyRainbowBody()
    if bodyStyleConn then bodyStyleConn:Disconnect(); bodyStyleConn = nil end
    if not rainbowBodyOn then return end
    local hue = 0
    bodyStyleConn = RunService.Heartbeat:Connect(function(dt)
        if not rainbowBodyOn then return end
        hue = (hue + dt * 0.35) % 1
        local col = Color3.fromHSV(hue, 0.9, 1)
        local char = player.Character
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.Material = Enum.Material.Neon
                part.Color = col
                part.Transparency = 0
            end
        end
    end)
end

H.createToggleRow(fxCharTab, "Мягкий fade-пульс тела", 63, function(state)
    bodyPulseOn = state
    rainbowBodyOn = false
    if not state then
        restoreBodyStyle()
        if bodyStyleConn then bodyStyleConn:Disconnect(); bodyStyleConn = nil end
        return
    end
    applyBodyPulse()
end)

H.createToggleRow(fxCharTab, "Радужный neon-перелив", 64, function(state)
    rainbowBodyOn = state
    bodyPulseOn = false
    if not state then
        if bodyStyleConn then bodyStyleConn:Disconnect(); bodyStyleConn = nil end
        return
    end
    applyRainbowBody()
end)

-- Анимированный Highlight (обводка с дыханием)
local animHighlight = nil
local animHlConn = nil
local function clearAnimHighlight()
    if animHlConn then animHlConn:Disconnect(); animHlConn = nil end
    if animHighlight then pcall(function() animHighlight:Destroy() end); animHighlight = nil end
end

local animHlEnabled = false
local function applyAnimHighlight()
    clearAnimHighlight()
    if not animHlEnabled then return end
    local char = player.Character
    if not char then return end
    animHighlight = Instance.new("Highlight")
    animHighlight.Name = "__VM_AnimHL"
    animHighlight.FillTransparency = 0.85
    animHighlight.OutlineTransparency = 0
    animHighlight.FillColor = THEME.Accent
    animHighlight.OutlineColor = THEME.Accent
    animHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    animHighlight.Parent = char
    local t0 = os.clock()
    animHlConn = RunService.RenderStepped:Connect(function()
        if not animHighlight or not animHighlight.Parent then return end
        local t = os.clock() - t0
        local pulse = (math.sin(t * 3) * 0.5 + 0.5)
        animHighlight.OutlineTransparency = 0.05 + pulse * 0.35
        animHighlight.FillTransparency = 0.75 + pulse * 0.2
        local col = Color3.fromHSV((t * 0.15) % 1, 0.7, 1)
        animHighlight.OutlineColor = col
        animHighlight.FillColor = col
    end)
end
H.createToggleRow(fxCharTab, "Анимированная обводка (Highlight)", 65, function(state)
    animHlEnabled = state
    applyAnimHighlight()
end)

-- Энергетическая сфера (ForceField шар, пульс + вращение)
local energySphere = nil
local energyConn = nil
local function clearEnergySphere()
    if energyConn then energyConn:Disconnect(); energyConn = nil end
    if energySphere then pcall(function() energySphere:Destroy() end); energySphere = nil end
end

local energyEnabled = false
local function applyEnergySphere()
    clearEnergySphere()
    if not energyEnabled then return end
    local root = getRoot()
    if not root then return end
    energySphere = Instance.new("Part")
    energySphere.Name = "__VM_EnergySphere"
    energySphere.Shape = Enum.PartType.Ball
    energySphere.Size = Vector3.new(6, 6, 6)
    energySphere.Material = Enum.Material.ForceField
    energySphere.Color = THEME.Accent
    energySphere.Transparency = 0.35
    energySphere.CanCollide = false
    energySphere.Massless = true
    energySphere.Anchored = true
    energySphere.CastShadow = false
    energySphere.Parent = workspace
    local light = Instance.new("PointLight")
    light.Brightness = 2
    light.Range = 14
    light.Color = THEME.Accent
    light.Parent = energySphere
    local t0 = os.clock()
    energyConn = RunService.RenderStepped:Connect(function()
        local r = getRoot()
        if not (r and energySphere and energySphere.Parent) then return end
        local t = os.clock() - t0
        local s = 5.5 + math.sin(t * 2.5) * 0.6
        energySphere.Size = Vector3.new(s, s, s)
        energySphere.CFrame = CFrame.new(r.Position) * CFrame.Angles(t * 0.4, t * 0.7, t * 0.25)
        energySphere.Color = Color3.fromHSV((t * 0.12) % 1, 0.75, 1)
        light.Color = energySphere.Color
        light.Brightness = 1.5 + math.sin(t * 3) * 0.6
    end)
end
H.createToggleRow(fxCharTab, "Энерго-сфера вокруг", 66, function(state)
    energyEnabled = state
    applyEnergySphere()
end)

-- Двойной trail (лучше обычного следа)
local dualTrail = {}
local function clearDualTrail()
    for _, o in ipairs(dualTrail) do pcall(function() o:Destroy() end) end
    dualTrail = {}
end

local dualTrailEnabled = false
local function applyDualTrail()
    clearDualTrail()
    if not dualTrailEnabled then return end
    local root = getRoot()
    if not root then return end
    for i, off in ipairs({-0.7, 0.7}) do
        local a0 = Instance.new("Attachment")
        a0.Position = Vector3.new(off, 0.2, 0)
        a0.Parent = root
        local a1 = Instance.new("Attachment")
        a1.Position = Vector3.new(off, -0.8, 0)
        a1.Parent = root
        local tr = Instance.new("Trail")
        tr.Attachment0 = a0
        tr.Attachment1 = a1
        tr.Lifetime = 0.55
        tr.MinLength = 0.05
        tr.LightEmission = 1
        tr.LightInfluence = 0
        tr.WidthScale = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1.2),
            NumberSequenceKeypoint.new(0.4, 0.6),
            NumberSequenceKeypoint.new(1, 0),
        })
        tr.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.1),
            NumberSequenceKeypoint.new(1, 1),
        })
        tr.Color = ColorSequence.new(THEME.Accent, Color3.fromRGB(255, 255, 255))
        tr.Parent = root
        table.insert(dualTrail, a0)
        table.insert(dualTrail, a1)
        table.insert(dualTrail, tr)
    end
end
H.createToggleRow(fxCharTab, "Двойной неоновый след", 67, function(state)
    dualTrailEnabled = state
    applyDualTrail()
end)

-- Улучшенные орбитальные кольца (тонкие цилиндры)
local ringOrbit = {}
local ringOrbitConn = nil
local function clearRingOrbit()
    if ringOrbitConn then ringOrbitConn:Disconnect(); ringOrbitConn = nil end
    for _, p in ipairs(ringOrbit) do pcall(function() p:Destroy() end) end
    ringOrbit = {}
end

local ringOrbitEnabled = false
local function applyRingOrbit()
    clearRingOrbit()
    if not ringOrbitEnabled then return end
    local root = getRoot()
    if not root then return end
    for i = 1, 3 do
        local ring = Instance.new("Part")
        ring.Name = "__VM_OrbitRing"
        ring.Anchored = true
        ring.CanCollide = false
        ring.CastShadow = false
        ring.Material = Enum.Material.Neon
        ring.Color = THEME.Accent
        ring.Transparency = 0.25
        ring.Size = Vector3.new(0.08, 0.08, 0.08)
        ring.Parent = workspace
        local mesh = Instance.new("SpecialMesh")
        mesh.MeshType = Enum.MeshType.Cylinder
        mesh.Scale = Vector3.new(0.12, 4 + i * 1.2, 4 + i * 1.2)
        mesh.Parent = ring
        local light = Instance.new("PointLight")
        light.Brightness = 0.8
        light.Range = 6
        light.Color = THEME.Accent
        light.Parent = ring
        table.insert(ringOrbit, ring)
    end
    local t0 = os.clock()
    ringOrbitConn = RunService.RenderStepped:Connect(function()
        local r = getRoot()
        if not r then return end
        local t = os.clock() - t0
        for i, ring in ipairs(ringOrbit) do
            if ring and ring.Parent then
                local tilt = math.rad(20 + i * 25)
                local spin = t * (1.2 + i * 0.4)
                ring.CFrame = CFrame.new(r.Position + Vector3.new(0, 0.5, 0))
                    * CFrame.Angles(tilt, spin, math.rad(i * 40))
                ring.Color = Color3.fromHSV((t * 0.1 + i * 0.2) % 1, 0.8, 1)
            end
        end
    end)
end
H.createToggleRow(fxCharTab, "3D орбитальные кольца", 68, function(state)
    ringOrbitEnabled = state
    applyRingOrbit()
end)

-- Beam-спираль (красивее простых лучей)
local spiralBeams = {}
local spiralConn = nil
local function clearSpiral()
    if spiralConn then spiralConn:Disconnect(); spiralConn = nil end
    for _, p in ipairs(spiralBeams) do pcall(function() p:Destroy() end) end
    spiralBeams = {}
end

local spiralEnabled = false
local function applySpiral()
    clearSpiral()
    if not spiralEnabled then return end
    local root = getRoot()
    if not root then return end
    local n = 10
    for i = 1, n do
        local p = Instance.new("Part")
        p.Anchored = true
        p.CanCollide = false
        p.Transparency = 1
        p.Size = Vector3.new(0.1, 0.1, 0.1)
        p.Parent = workspace
        local att = Instance.new("Attachment")
        att.Parent = p
        table.insert(spiralBeams, p)
    end
    for i = 1, n - 1 do
        local beam = Instance.new("Beam")
        beam.Attachment0 = spiralBeams[i]:FindFirstChildOfClass("Attachment")
        beam.Attachment1 = spiralBeams[i + 1]:FindFirstChildOfClass("Attachment")
        beam.Width0 = 0.18
        beam.Width1 = 0.18
        beam.Color = ColorSequence.new(THEME.Accent)
        beam.Transparency = NumberSequence.new(0.15, 0.4)
        beam.LightEmission = 1
        beam.FaceCamera = true
        beam.Parent = spiralBeams[i]
    end
    local t0 = os.clock()
    spiralConn = RunService.RenderStepped:Connect(function()
        local r = getRoot()
        if not r then return end
        local t = os.clock() - t0
        for i, p in ipairs(spiralBeams) do
            local a = t * 2.2 + i * 0.55
            local rad = 1.2 + (i / n) * 2.2
            local y = -1 + (i / n) * 3.2 + math.sin(t * 2 + i) * 0.15
            p.CFrame = CFrame.new(r.Position + Vector3.new(math.cos(a) * rad, y, math.sin(a) * rad))
            local beam = p:FindFirstChildOfClass("Beam")
            if beam then
                beam.Color = ColorSequence.new(Color3.fromHSV((t * 0.2 + i * 0.05) % 1, 0.85, 1))
            end
        end
    end)
end
H.createToggleRow(fxCharTab, "Спираль из лучей (Beams)", 69, function(state)
    spiralEnabled = state
    applySpiral()
end)

-- после смерти / респавна заново применяем включённые визуалы
player.CharacterAdded:Connect(function()
    task.wait(0.55)
    -- сбрасываем старые ссылки (объекты умерли вместе с персонажем)
    trailObj, trailAtt0, trailAtt1 = nil, nil, nil
    auraEmitter = nil
    highlightObj = nil
    glowLight = nil
    -- базовые эффекты
    pcall(function()
        if H.trailToggle and H.trailToggle.Get and H.trailToggle.Get() then
            ensureTrail()
            if trailObj then trailObj.Enabled = true end
        end
    end)
    pcall(function()
        if H.auraToggle and H.auraToggle.Get and H.auraToggle.Get() then
            ensureAura()
            if auraEmitter then auraEmitter.Rate = 20 end
        end
    end)
    pcall(function()
        if H.highlightToggle and H.highlightToggle.Get and H.highlightToggle.Get() then
            ensureHighlight()
            if highlightObj then highlightObj.Enabled = true end
        end
    end)
    pcall(function()
        if H.glowToggle and H.glowToggle.Get and H.glowToggle.Get() then
            ensureGlow()
            if glowLight then glowLight.Enabled = true end
        end
    end)
    -- premium visuals
    if animHlEnabled then applyAnimHighlight() end
    if energyEnabled then applyEnergySphere() end
    if dualTrailEnabled then applyDualTrail() end
    if ringOrbitEnabled then applyRingOrbit() end
    if spiralEnabled then applySpiral() end
    if bodyMat and bodyMat ~= "" and not rainbowBodyOn and not bodyPulseOn then
        pcall(function() applyBodyMaterial(bodyMat) end)
    end
    if bodyPulseOn then applyBodyPulse() end
    if rainbowBodyOn then applyRainbowBody() end
end)

----------------------------------------------------------
-- УНИКАЛЬНЫЕ ВИЗУАЛЫ ПЕРСОНАЖА
----------------------------------------------------------
end

H.__build_Wings = function()
H.sectionLabel(fxCharTab, "3D КРЫЛЬЯ", 33)
local wingModel = nil
local wingMotors = {}
local wingParts = {}
local wingEnabled = false
local wingFlapConn = nil
local wingColor = THEME.Accent
local wingStyle = "mesh" -- mesh | soft | neonmesh
local wingScale = 0.65
local wingFlapSpeed = 1
local wingFlapAmount = 0.3
-- готовые mesh id (крылья, не клинья)
local WING_MESHES = {
    mesh = { mesh = "rbxassetid://10725097949", tex = "rbxassetid://4369346089" }, -- angel wings
    mesh2 = { mesh = "rbxassetid://223377708", tex = "" }, -- classic gear wing shape
}

local function clearWings()
    if wingFlapConn then wingFlapConn:Disconnect(); wingFlapConn = nil end
    if wingModel then wingModel:Destroy(); wingModel = nil end
    wingMotors = {}
    wingParts = {}
end

local function weldTo(part0, part1, c0)
    local w = Instance.new("Weld")
    w.Part0 = part0
    w.Part1 = part1
    w.C0 = c0 or CFrame.new()
    w.Parent = part1
    return w
end

-- объёмное перо (эллипсоид), не треугольник
local function makeSoftFeather(model, size, color)
    local p = Instance.new("Part")
    p.Name = "Feather"
    p.Size = size
    p.Color = color
    p.Material = Enum.Material.SmoothPlastic
    p.CanCollide = false
    p.Massless = true
    p.CastShadow = true
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = model
    local m = Instance.new("SpecialMesh")
    m.MeshType = Enum.MeshType.Sphere
    m.Parent = p
    table.insert(wingParts, p)
    return p
end

-- одно крыло из настоящего FileMesh (зеркало по side)
local function buildMeshWing(torso, side, model)
    local root = Instance.new("Part")
    root.Name = side > 0 and "WingRootR" or "WingRootL"
    root.Size = Vector3.new(0.25, 0.25, 0.25)
    root.Transparency = 1
    root.CanCollide = false
    root.Massless = true
    root.Parent = model

    local motor = Instance.new("Motor6D")
    motor.Name = "WingMotor"
    motor.Part0 = torso
    motor.Part1 = root
    motor.C0 = CFrame.new(side * 0.35, 0.15, 0.55)
        * CFrame.Angles(math.rad(-8), math.rad(side * -90), math.rad(side * 8))
    motor.C1 = CFrame.new()
    motor.Parent = root
    table.insert(wingMotors, motor)

    local wing = Instance.new("Part")
    wing.Name = "WingMesh"
    wing.Size = Vector3.new(0.4, 0.4, 0.4)
    wing.Color = wingColor
    wing.Material = Enum.Material.SmoothPlastic
    wing.CanCollide = false
    wing.Massless = true
    wing.CastShadow = true
    wing.Parent = model

    local sm = Instance.new("SpecialMesh")
    sm.MeshType = Enum.MeshType.FileMesh
    local preset = WING_MESHES.mesh
    sm.MeshId = preset.mesh
    if preset.tex ~= "" then sm.TextureId = preset.tex end
    local s = wingScale
    -- зеркало: отрицательный scale по X для второй стороны
    sm.Scale = Vector3.new(side * 0.75 * s, 0.7 * s, 0.75 * s)
    sm.Parent = wing

    weldTo(root, wing, CFrame.new(side * 0.85 * s, -0.15 * s, -0.25 * s)
        * CFrame.Angles(math.rad(-20), math.rad(side * 12), math.rad(side * 4)))

    -- подсветка
    local light = Instance.new("PointLight")
    light.Brightness = 0.6
    light.Range = 8
    light.Color = wingColor
    light.Parent = wing

    table.insert(wingParts, wing)
    return motor
end

-- мягкие 3D-крылья из цепочки объёмных перьев (сфера)
local function buildSoftWing(torso, side, model)
    local root = Instance.new("Part")
    root.Name = side > 0 and "WingRootR" or "WingRootL"
    root.Size = Vector3.new(0.2, 0.2, 0.2)
    root.Transparency = 1
    root.CanCollide = false
    root.Massless = true
    root.Parent = model

    local motor = Instance.new("Motor6D")
    motor.Name = "WingMotor"
    motor.Part0 = torso
    motor.Part1 = root
    motor.C0 = CFrame.new(side * 0.4, 0.1, 0.5)
        * CFrame.Angles(math.rad(-5), math.rad(side * -18), math.rad(side * 10))
    motor.C1 = CFrame.new()
    motor.Parent = root
    table.insert(wingMotors, motor)

    local s = wingScale
    -- ряды перьев: от плеча наружу и вниз (дуга)
    local rows = {
        -- верхний ряд (не выше плеч)
        { count = 5, y = 0.12, z = -0.28, len = 1.55, thick = 0.38, step = 0.4 },
        -- средний
        { count = 6, y = -0.12, z = -0.42, len = 1.75, thick = 0.36, step = 0.38 },
        -- нижний
        { count = 5, y = -0.4, z = -0.32, len = 1.4, thick = 0.32, step = 0.36 },
    }

    for _, row in ipairs(rows) do
        local prev = root
        for i = 1, row.count do
            local t = (i - 1) / math.max(row.count - 1, 1)
            local length = (row.len * (1.05 - t * 0.35)) * s
            local thick = row.thick * (1 - t * 0.25) * s
            local feather = makeSoftFeather(model, Vector3.new(length, thick, thick * 0.85), wingColor)
            if wingStyle == "neonmesh" then
                feather.Material = Enum.Material.Neon
            end
            local angle = math.rad(side * (8 + t * 28))
            local lift = math.rad(-6 - t * 22)
            local c0
            if prev == root then
                c0 = CFrame.new(side * 0.15 * s, row.y * s, row.z * s)
                    * CFrame.Angles(lift, angle, math.rad(side * 10))
                    * CFrame.new(side * (length * 0.45), 0, 0)
            else
                c0 = CFrame.new(side * row.step * s, 0.08 * s, -0.05 * s)
                    * CFrame.Angles(math.rad(-4), math.rad(side * 6), 0)
                    * CFrame.new(side * (length * 0.35), 0, 0)
            end
            weldTo(prev, feather, c0)
            prev = feather
        end
    end
    return motor
end

local function attachWings(char)
    clearWings()
    local torso = char:FindFirstChild("UpperTorso")
        or char:FindFirstChild("Torso")
        or char:FindFirstChild("HumanoidRootPart")
    if not torso then return end

    wingModel = Instance.new("Model")
    wingModel.Name = "__VM_3DWings"
    wingModel.Parent = char

    if wingStyle == "soft" or wingStyle == "neonmesh" then
        buildSoftWing(torso, -1, wingModel)
        buildSoftWing(torso, 1, wingModel)
    else
        buildMeshWing(torso, -1, wingModel)
        buildMeshWing(torso, 1, wingModel)
    end

    local t0 = os.clock()
    wingFlapConn = RunService.RenderStepped:Connect(function()
        if not wingEnabled or #wingMotors == 0 then return end
        local t = (os.clock() - t0) * wingFlapSpeed
        local flap = math.sin(t * 2.8) * wingFlapAmount
        for i, motor in ipairs(wingMotors) do
            if motor and motor.Parent then
                local side = (i % 2 == 1) and -1 or 1
                motor.C1 = CFrame.Angles(
                    math.rad(-6) + flap * 0.15,
                    math.rad(side * flap * 18),
                    math.rad(side * flap * 32)
                )
            end
        end
        for _, p in ipairs(wingParts) do
            if p and p.Parent then
                p.Color = wingColor
            end
        end
    end)
end

H.createToggleRow(fxCharTab, "3D крылья", 34, function(state)
    wingEnabled = state
    clearWings()
    if state and player.Character then
        attachWings(player.Character)
    end
end)

H.createColorSliders(fxCharTab, "ЦВЕТ КРЫЛЬЕВ (RGB)", 35, THEME.Accent, function(color)
    wingColor = color
    for _, p in ipairs(wingParts) do
        if p and p.Parent then p.Color = color end
    end
end)

H.wingScale = H.createSlider(fxCharTab, "Размер крыльев x10", 3, 18, 7, 36, function(v)
    wingScale = v / 10
    if wingEnabled and player.Character then attachWings(player.Character) end
end)
H.wingFlapSpeed = H.createSlider(fxCharTab, "Скорость взмаха x10", 0, 30, 10, 37, function(v)
    wingFlapSpeed = v / 10
end)
H.wingFlapAmount = H.createSlider(fxCharTab, "Амплитуда взмаха x100", 0, 60, 30, 38, function(v)
    wingFlapAmount = v / 100
end)

H.sectionLabel(fxCharTab, "СТИЛЬ КРЫЛЬЕВ", 39)
H.createButtonRow(fxCharTab, {
    { text = "Mesh (ангел)", callback = function()
        wingStyle = "mesh"
        if wingEnabled and player.Character then attachWings(player.Character) end
    end },
    { text = "Мягкие перья", callback = function()
        wingStyle = "soft"
        if wingEnabled and player.Character then attachWings(player.Character) end
    end },
    { text = "Neon-перья", callback = function()
        wingStyle = "neonmesh"
        if wingEnabled and player.Character then attachWings(player.Character) end
    end },
}, 40)

player.CharacterAdded:Connect(function(c)
    task.wait(0.5)
    if wingEnabled then attachWings(c) end
end)

end

H.__build_PotatoAndParticles = function()
H.sectionLabel(fxCharTab, "СИСТЕМА ЧАСТИЦ (КАСТОМ)", 38)
local customParticle = nil
local particleStyle = "sparkles"
local particleRate = 20
local particleColor = THEME.Accent

local function rebuildCustomParticle()
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    if customParticle then customParticle:Destroy(); customParticle = nil end
    customParticle = Instance.new("ParticleEmitter")
    customParticle.Name = "__VM_CustomParticles"
    customParticle.Rate = particleRate
    customParticle.Lifetime = NumberRange.new(0.5, 1.2)
    customParticle.Speed = NumberRange.new(1, 3)
    customParticle.Size = NumberSequence.new(0.4, 0)
    customParticle.Color = ColorSequence.new(particleColor)
    customParticle.LightEmission = 0.85
    customParticle.SpreadAngle = Vector2.new(40, 40)
    if particleStyle == "sparkles" then
        customParticle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    elseif particleStyle == "smoke" then
        customParticle.Texture = "rbxasset://textures/particles/smoke_main.dds"
        customParticle.Speed = NumberRange.new(0.5, 1.5)
        customParticle.Transparency = NumberSequence.new(0.3, 1)
    elseif particleStyle == "fire" then
        customParticle.Texture = "rbxasset://textures/particles/fire_main.dds"
        customParticle.Speed = NumberRange.new(2, 5)
        customParticle.Acceleration = Vector3.new(0, 4, 0)
        customParticle.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 60)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 60, 20)),
        })
    elseif particleStyle == "stars" then
        customParticle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        customParticle.SpreadAngle = Vector2.new(360, 360)
        customParticle.Speed = NumberRange.new(0.5, 2)
        customParticle.LightEmission = 1
    end
    customParticle.Parent = root
end

H.createButtonRow(fxCharTab, {
    { text = "Искры", callback = function() particleStyle = "sparkles"; rebuildCustomParticle() end },
    { text = "Дым", callback = function() particleStyle = "smoke"; rebuildCustomParticle() end },
    { text = "Огонь", callback = function() particleStyle = "fire"; rebuildCustomParticle() end },
    { text = "Звёзды", callback = function() particleStyle = "stars"; rebuildCustomParticle() end },
}, 39)

H.particleRate = H.createSlider(fxCharTab, "Плотность частиц", 0, 60, 20, 40, function(v)
    particleRate = v
    if customParticle then customParticle.Rate = v end
end)
H.particleColor = H.createColorSliders(fxCharTab, "ЦВЕТ ЧАСТИЦ (RGB)", 41, THEME.Accent, function(color)
    particleColor = color
    if customParticle and particleStyle ~= "fire" then
        customParticle.Color = ColorSequence.new(color)
    end
end)
H.createButtonRow(fxCharTab, {
    { text = "Выкл. частицы", callback = function()
        if customParticle then customParticle:Destroy(); customParticle = nil end
    end },
}, 45)

end

H.__build_JumpRing = function()
H.sectionLabel(fxCharTab, "КРУГ ПРИ ПРЫЖКЕ — НАСТРОЙКИ", 40)
local jumpRingEnabled = false
local landRingEnabled = false
local jumpRingConn = nil
local ringSettings = {
    size = 8,          -- max scale
    thickness = 0.06,  -- mesh Y thickness feel
    duration = 0.55,
    style = "neon",    -- neon | forcefield | glass
    double = true,
    color = THEME.Accent,
}

local function spawnGroundRing(position, color, maxScale, duration, style)
    style = style or ringSettings.style
    maxScale = maxScale or ringSettings.size
    duration = duration or ringSettings.duration
    color = color or ringSettings.color

    local part = Instance.new("Part")
    part.Name = "__VM_JumpRing"
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 0.15
    part.Size = Vector3.new(0.2, 0.2, 0.2)
    part.CFrame = CFrame.new(position + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
    part.Parent = workspace

    if style == "neon" then
        part.Material = Enum.Material.Neon
        part.Color = color
    elseif style == "forcefield" then
        part.Material = Enum.Material.ForceField
        part.Color = color
    else
        part.Material = Enum.Material.Glass
        part.Color = color
        part.Transparency = 0.35
    end

    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Cylinder
    mesh.Scale = Vector3.new(ringSettings.thickness, 0.3, 0.3)
    mesh.Parent = part

    local t0 = os.clock()
    task.spawn(function()
        while part.Parent and os.clock() - t0 < duration do
            local a = (os.clock() - t0) / duration
            local s = 0.25 + a * maxScale
            mesh.Scale = Vector3.new(ringSettings.thickness, s, s)
            part.Transparency = (style == "glass" and 0.35 or 0.12) + a * 0.85
            task.wait()
        end
        if part then part:Destroy() end
    end)
end

local function bindJumpVisuals(char)
    local humanoid = char:WaitForChild("Humanoid", 5)
    local root = char:WaitForChild("HumanoidRootPart", 5)
    if not (humanoid and root) then return end
    if jumpRingConn then jumpRingConn:Disconnect() end
    jumpRingConn = humanoid.StateChanged:Connect(function(_, new)
        if new == Enum.HumanoidStateType.Jumping and jumpRingEnabled then
            local pos = root.Position - Vector3.new(0, 3, 0)
            spawnGroundRing(pos, ringSettings.color, ringSettings.size, ringSettings.duration, ringSettings.style)
            if ringSettings.double then
                task.delay(0.07, function()
                    if root.Parent then
                        spawnGroundRing(
                            root.Position - Vector3.new(0, 3, 0),
                            Color3.fromRGB(255, 255, 255),
                            ringSettings.size * 0.65,
                            ringSettings.duration * 0.75,
                            ringSettings.style
                        )
                    end
                end)
            end
        elseif new == Enum.HumanoidStateType.Landed and landRingEnabled then
            local pos = root.Position - Vector3.new(0, 3, 0)
            spawnGroundRing(pos, Color3.fromRGB(200, 220, 255), ringSettings.size * 1.4, ringSettings.duration * 1.2, ringSettings.style)
            local burst = Instance.new("ParticleEmitter")
            burst.Texture = "rbxasset://textures/particles/smoke_main.dds"
            burst.Lifetime = NumberRange.new(0.3, 0.55)
            burst.Speed = NumberRange.new(3, 8)
            burst.Size = NumberSequence.new(0.7, 0)
            burst.Color = ColorSequence.new(Color3.fromRGB(180, 180, 195))
            burst.SpreadAngle = Vector2.new(180, 25)
            burst.Rate = 0
            burst.Parent = root
            burst:Emit(14)
            task.delay(0.8, function() burst:Destroy() end)
        end
    end)
end

H.createToggleRow(fxCharTab, "Круг на земле при прыжке", 41, function(state)
    jumpRingEnabled = state
    if state and player.Character then bindJumpVisuals(player.Character) end
end)
H.createToggleRow(fxCharTab, "Ударная волна при приземлении", 42, function(state)
    landRingEnabled = state
    if state and player.Character then bindJumpVisuals(player.Character) end
end)
H.createToggleRow(fxCharTab, "Двойной круг", 43, function(state)
    ringSettings.double = state
end, true)

H.ringSize = H.createSlider(fxCharTab, "Размер круга", 3, 20, 8, 44, function(v)
    ringSettings.size = v
end)
H.ringDuration = H.createSlider(fxCharTab, "Длительность x10 (сек)", 2, 15, 6, 45, function(v)
    ringSettings.duration = v / 10
end)
H.ringThickness = H.createSlider(fxCharTab, "Толщина кольца x100", 2, 20, 6, 46, function(v)
    ringSettings.thickness = v / 100
end)
H.ringColor = H.createColorSliders(fxCharTab, "ЦВЕТ КРУГА (RGB)", 47, THEME.Accent, function(color)
    ringSettings.color = color
end)

H.sectionLabel(fxCharTab, "СТИЛЬ КРУГА", 51)
H.createButtonRow(fxCharTab, {
    { text = "Neon", callback = function() ringSettings.style = "neon" end },
    { text = "ForceField", callback = function() ringSettings.style = "forcefield" end },
    { text = "Glass", callback = function() ringSettings.style = "glass" end },
}, 52)

player.CharacterAdded:Connect(function(c)
    task.wait(0.3)
    if jumpRingEnabled or landRingEnabled then bindJumpVisuals(c) end
end)

----------------------------------------------------------
-- ЖИВОЙ СПУТНИК С ГЛАЗАМИ
----------------------------------------------------------
end

H.__build_Companion = function()
H.sectionLabel(fxCharTab, "СПУТНИК (ЖИВОЙ ШАР)", 53)
local companionModel = nil
local companionConn = nil
local companionBlinkConn = nil

local function clearCompanion()
    if companionConn then companionConn:Disconnect(); companionConn = nil end
    if companionBlinkConn then companionBlinkConn:Disconnect(); companionBlinkConn = nil end
    if companionModel then companionModel:Destroy(); companionModel = nil end
end

local function makeEye(parent, xOff)
    local eye = Instance.new("Part")
    eye.Name = "Eye"
    eye.Shape = Enum.PartType.Ball
    eye.Size = Vector3.new(0.22, 0.22, 0.22)
    eye.Material = Enum.Material.Neon
    eye.Color = Color3.fromRGB(255, 255, 255)
    eye.CanCollide = false
    eye.Massless = true
    eye.Parent = parent
    local weld = Instance.new("Weld")
    weld.Part0 = parent
    weld.Part1 = eye
    weld.C0 = CFrame.new(xOff, 0.12, -0.28)
    weld.Parent = eye
    local pupil = Instance.new("Part")
    pupil.Name = "Pupil"
    pupil.Shape = Enum.PartType.Ball
    pupil.Size = Vector3.new(0.1, 0.1, 0.1)
    pupil.Material = Enum.Material.Neon
    pupil.Color = Color3.fromRGB(20, 20, 30)
    pupil.CanCollide = false
    pupil.Massless = true
    pupil.Parent = parent
    local weld2 = Instance.new("Weld")
    weld2.Part0 = eye
    weld2.Part1 = pupil
    weld2.C0 = CFrame.new(0, 0, -0.08)
    weld2.Parent = pupil
    return eye, pupil
end

H.createToggleRow(fxCharTab, "Живой шар-спутник (физика + глаза)", 54, function(state)
    clearCompanion()
    if not state then return end
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    companionModel = Instance.new("Model")
    companionModel.Name = "__VM_Companion"
    companionModel.Parent = workspace

    -- якорь на игроке (цель для физики)
    local targetAtt = Instance.new("Attachment")
    targetAtt.Name = "__VM_CompanionTarget"
    targetAtt.Parent = root

    local body = Instance.new("Part")
    body.Name = "Body"
    body.Shape = Enum.PartType.Ball
    body.Size = Vector3.new(0.9, 0.9, 0.9)
    body.Material = Enum.Material.Neon
    body.Color = THEME.Accent
    body.CanCollide = false
    body.Massless = true
    body.CustomPhysicalProperties = PhysicalProperties.new(0.3, 0.3, 0.2, 1, 1)
    body.CFrame = root.CFrame * CFrame.new(2.5, 1.5, 0)
    body.Parent = companionModel
    companionModel.PrimaryPart = body

    local bodyAtt = Instance.new("Attachment")
    bodyAtt.Parent = body

    -- AlignPosition — пружинная физика следования
    local alignPos = Instance.new("AlignPosition")
    alignPos.Mode = Enum.PositionAlignmentMode.TwoAttachment
    alignPos.Attachment0 = bodyAtt
    alignPos.Attachment1 = targetAtt
    alignPos.MaxForce = 25000
    alignPos.MaxVelocity = 40
    alignPos.Responsiveness = 12
    alignPos.ApplyAtCenterOfMass = true
    alignPos.Parent = body

    -- AlignOrientation — поворачивается к игроку
    local alignOri = Instance.new("AlignOrientation")
    alignOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
    alignOri.Attachment0 = bodyAtt
    alignOri.MaxTorque = 20000
    alignOri.Responsiveness = 18
    alignOri.Parent = body

    local eyeL, pupilL = makeEye(body, -0.18)
    local eyeR, pupilR = makeEye(body, 0.18)

    local cheekL = Instance.new("Part")
    cheekL.Shape = Enum.PartType.Ball
    cheekL.Size = Vector3.new(0.18, 0.14, 0.14)
    cheekL.Material = Enum.Material.Neon
    cheekL.Color = Color3.fromRGB(255, 130, 170)
    cheekL.Transparency = 0.4
    cheekL.CanCollide = false
    cheekL.Massless = true
    cheekL.Parent = companionModel
    local wCheekL = Instance.new("Weld")
    wCheekL.Part0 = body
    wCheekL.Part1 = cheekL
    wCheekL.C0 = CFrame.new(-0.32, -0.12, -0.2)
    wCheekL.Parent = cheekL

    local cheekR = cheekL:Clone()
    cheekR.Parent = companionModel
    local wCheekR = Instance.new("Weld")
    wCheekR.Part0 = body
    wCheekR.Part1 = cheekR
    wCheekR.C0 = CFrame.new(0.32, -0.12, -0.2)
    wCheekR.Parent = cheekR

    -- ДРИП: шляпа
    local hat = Instance.new("Part")
    hat.Name = "DripHat"
    hat.Size = Vector3.new(0.7, 0.25, 0.7)
    hat.Color = Color3.fromRGB(20, 20, 25)
    hat.Material = Enum.Material.SmoothPlastic
    hat.CanCollide = false
    hat.Massless = true
    hat.Parent = companionModel
    local hatMesh = Instance.new("SpecialMesh")
    hatMesh.MeshType = Enum.MeshType.Cylinder
    hatMesh.Parent = hat
    local wHat = Instance.new("Weld")
    wHat.Part0 = body
    wHat.Part1 = hat
    wHat.C0 = CFrame.new(0, 0.55, 0) * CFrame.Angles(0, 0, math.rad(90))
    wHat.Parent = hat
    local brim = Instance.new("Part")
    brim.Size = Vector3.new(1.05, 0.08, 1.05)
    brim.Color = Color3.fromRGB(20, 20, 25)
    brim.Material = Enum.Material.SmoothPlastic
    brim.CanCollide = false
    brim.Massless = true
    brim.Parent = companionModel
    local brimMesh = Instance.new("SpecialMesh")
    brimMesh.MeshType = Enum.MeshType.Cylinder
    brimMesh.Parent = brim
    local wBrim = Instance.new("Weld")
    wBrim.Part0 = body
    wBrim.Part1 = brim
    wBrim.C0 = CFrame.new(0, 0.42, 0) * CFrame.Angles(0, 0, math.rad(90))
    wBrim.Parent = brim

    -- очки
    local glasses = Instance.new("Part")
    glasses.Size = Vector3.new(0.55, 0.12, 0.08)
    glasses.Color = Color3.fromRGB(15, 15, 15)
    glasses.Material = Enum.Material.SmoothPlastic
    glasses.CanCollide = false
    glasses.Massless = true
    glasses.Parent = companionModel
    local wGlass = Instance.new("Weld")
    wGlass.Part0 = body
    wGlass.Part1 = glasses
    wGlass.C0 = CFrame.new(0, 0.08, -0.42)
    wGlass.Parent = glasses
    local lensL = Instance.new("Part")
    lensL.Shape = Enum.PartType.Cylinder
    lensL.Size = Vector3.new(0.06, 0.2, 0.2)
    lensL.Color = Color3.fromRGB(40, 40, 50)
    lensL.Material = Enum.Material.Glass
    lensL.Transparency = 0.3
    lensL.CanCollide = false
    lensL.Massless = true
    lensL.Parent = companionModel
    local wLensL = Instance.new("Weld")
    wLensL.Part0 = body
    wLensL.Part1 = lensL
    wLensL.C0 = CFrame.new(-0.14, 0.08, -0.44) * CFrame.Angles(0, 0, math.rad(90))
    wLensL.Parent = lensL
    local lensR = lensL:Clone()
    lensR.Parent = companionModel
    local wLensR = Instance.new("Weld")
    wLensR.Part0 = body
    wLensR.Part1 = lensR
    wLensR.C0 = CFrame.new(0.14, 0.08, -0.44) * CFrame.Angles(0, 0, math.rad(90))
    wLensR.Parent = lensR

    -- цепь
    local chain = Instance.new("Part")
    chain.Size = Vector3.new(0.5, 0.08, 0.08)
    chain.Color = Color3.fromRGB(255, 200, 50)
    chain.Material = Enum.Material.Neon
    chain.CanCollide = false
    chain.Massless = true
    chain.Parent = companionModel
    local wChain = Instance.new("Weld")
    wChain.Part0 = body
    wChain.Part1 = chain
    wChain.C0 = CFrame.new(0, -0.35, -0.25)
    wChain.Parent = chain
    local pendant = Instance.new("Part")
    pendant.Shape = Enum.PartType.Ball
    pendant.Size = Vector3.new(0.18, 0.18, 0.18)
    pendant.Color = Color3.fromRGB(255, 215, 60)
    pendant.Material = Enum.Material.Neon
    pendant.CanCollide = false
    pendant.Massless = true
    pendant.Parent = companionModel
    local wPend = Instance.new("Weld")
    wPend.Part0 = body
    wPend.Part1 = pendant
    wPend.C0 = CFrame.new(0, -0.5, -0.28)
    wPend.Parent = pendant

    local light = Instance.new("PointLight")
    light.Brightness = 2.5
    light.Range = 14
    light.Color = THEME.Accent
    light.Parent = body

    -- trail
    local trail = Instance.new("Trail")
    local ta0 = Instance.new("Attachment")
    ta0.Position = Vector3.new(-0.25, 0, 0)
    ta0.Parent = body
    local ta1 = Instance.new("Attachment")
    ta1.Position = Vector3.new(0.25, 0, 0)
    ta1.Parent = body
    trail.Attachment0 = ta0
    trail.Attachment1 = ta1
    trail.Lifetime = 0.4
    trail.Color = ColorSequence.new(THEME.Accent)
    trail.Transparency = NumberSequence.new(0.2, 1)
    trail.WidthScale = NumberSequence.new(1, 0)
    trail.LightEmission = 0.8
    trail.Parent = body

    -- система частиц вокруг спутника
    local sparkles = Instance.new("ParticleEmitter")
    sparkles.Name = "__CompanionParticles"
    sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    sparkles.Rate = 18
    sparkles.Lifetime = NumberRange.new(0.4, 0.9)
    sparkles.Speed = NumberRange.new(0.5, 1.5)
    sparkles.Size = NumberSequence.new(0.25, 0)
    sparkles.Color = ColorSequence.new(THEME.Accent)
    sparkles.LightEmission = 1
    sparkles.SpreadAngle = Vector2.new(360, 360)
    sparkles.Parent = body

    local softSmoke = Instance.new("ParticleEmitter")
    softSmoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
    softSmoke.Rate = 6
    softSmoke.Lifetime = NumberRange.new(0.6, 1.1)
    softSmoke.Speed = NumberRange.new(0.2, 0.6)
    softSmoke.Size = NumberSequence.new(0.4, 0)
    softSmoke.Color = ColorSequence.new(THEME.Accent)
    softSmoke.Transparency = NumberSequence.new(0.5, 1)
    softSmoke.LightEmission = 0.4
    softSmoke.Parent = body

    local t0 = os.clock()
    local blinkUntil = 0
    companionConn = RunService.Heartbeat:Connect(function()
        local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not (r and body and body.Parent and targetAtt.Parent) then return end
        local t = os.clock() - t0
        -- цель орбиты (физика дотягивает шар)
        local bob = math.sin(t * 2.8) * 0.45
        local orbit = Vector3.new(math.cos(t * 1.25) * 3.2, 1.6 + bob, math.sin(t * 1.25) * 3.2)
        targetAtt.WorldPosition = r.Position + orbit

        -- ориентация «смотрит» на голову игрока
        local head = player.Character:FindFirstChild("Head")
        local lookAt = (head and head.Position or (r.Position + Vector3.new(0, 1.5, 0)))
        local dir = (lookAt - body.Position)
        if dir.Magnitude > 0.05 then
            alignOri.CFrame = CFrame.lookAt(Vector3.zero, dir.Unit)
        end

        body.Color = THEME.Accent
        light.Color = THEME.Accent
        trail.Color = ColorSequence.new(THEME.Accent)
        sparkles.Color = ColorSequence.new(THEME.Accent)
        softSmoke.Color = ColorSequence.new(THEME.Accent)

        -- моргание
        local blinking = os.clock() < blinkUntil
        for _, eye in ipairs({eyeL, eyeR}) do
            if eye and eye.Parent then
                eye.Size = blinking and Vector3.new(0.2, 0.04, 0.2) or Vector3.new(0.22, 0.22, 0.22)
            end
        end
        for _, pupil in ipairs({pupilL, pupilR}) do
            if pupil and pupil.Parent then
                pupil.Transparency = blinking and 1 or 0
            end
        end
    end)

    companionBlinkConn = RunService.Heartbeat:Connect(function()
        if math.random(1, 160) == 1 then
            blinkUntil = os.clock() + 0.11
        end
    end)
end)

end

H.__build_CharExtras = function()
H.sectionLabel(fxCharTab, "СЛЕД ПРИ СПРИНТЕ", 55)
local sprintConn = nil
local sprintEnabled = false
H.createToggleRow(fxCharTab, "Линии скорости при беге", 56, function(state)
    sprintEnabled = state
    if sprintConn then sprintConn:Disconnect(); sprintConn = nil end
    if not state then return end
    local last = 0
    sprintConn = RunService.Heartbeat:Connect(function()
        if not sprintEnabled then return end
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not (hum and root) then return end
        if hum.MoveDirection.Magnitude < 0.5 then return end
        if os.clock() - last < 0.07 then return end
        last = os.clock()
        local line = Instance.new("Part")
        line.Size = Vector3.new(0.12, 0.12, 1.8)
        line.Material = Enum.Material.Neon
        line.Color = THEME.Accent
        line.Anchored = true
        line.CanCollide = false
        line.CFrame = CFrame.new(root.Position - root.CFrame.LookVector * 1.5 - Vector3.new(0, 2.2, 0), root.Position - root.CFrame.LookVector * 4)
        line.Parent = workspace
        TweenService:Create(line, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
            Transparency = 1,
            Size = Vector3.new(0.05, 0.05, 0.4),
        }):Play()
        task.delay(0.4, function() line:Destroy() end)
    end)
end)

H.sectionLabel(fxCharTab, "ПУЛЬС ЭНЕРГИИ", 57)
H.createButtonRow(fxCharTab, {
    { text = "Импульс вокруг", callback = function()
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local pos = root.Position - Vector3.new(0, 2.5, 0)
        for i = 1, 3 do
            task.delay((i - 1) * 0.12, function()
                spawnGroundRing(pos, THEME.Accent, 6 + i * 3, 0.5 + i * 0.1, ringSettings.style)
            end)
        end
    end },
    { text = "Вспышка вверх", callback = function()
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not root then return end
        for i = 1, 8 do
            local beam = Instance.new("Part")
            beam.Size = Vector3.new(0.2, 0.2, 0.2)
            beam.Material = Enum.Material.Neon
            beam.Color = Color3.fromHSV(i / 8, 0.8, 1)
            beam.Anchored = true
            beam.CanCollide = false
            beam.CFrame = CFrame.new(root.Position)
            beam.Parent = workspace
            local ang = (i / 8) * math.pi * 2
            local dir = Vector3.new(math.cos(ang) * 0.3, 1, math.sin(ang) * 0.3).Unit
            TweenService:Create(beam, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                CFrame = CFrame.new(root.Position + dir * 12),
                Transparency = 1,
                Size = Vector3.new(0.05, 0.05, 0.05),
            }):Play()
            task.delay(0.75, function() beam:Destroy() end)
        end
    end },
}, 58)

H.sectionLabel(fxCharTab, "ТЕНЬ-КЛОН", 59)
local cloneConn = nil
H.createToggleRow(fxCharTab, "Теневой клон при рывке", 60, function(state)
    if cloneConn then cloneConn:Disconnect(); cloneConn = nil end
    if not state then return end
    local lastPos, lastSpawn = nil, 0
    cloneConn = RunService.Heartbeat:Connect(function()
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not (root and hum) then return end
        if hum.MoveDirection.Magnitude < 0.8 then lastPos = root.Position return end
        if not lastPos then lastPos = root.Position return end
        if (root.Position - lastPos).Magnitude < 4 then return end
        if os.clock() - lastSpawn < 0.25 then return end
        lastSpawn = os.clock()
        lastPos = root.Position
        local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
        if not torso then return end
        local ghost = Instance.new("Part")
        ghost.Size = torso.Size
        ghost.CFrame = torso.CFrame
        ghost.Anchored = true
        ghost.CanCollide = false
        ghost.Material = Enum.Material.ForceField
        ghost.Color = THEME.Accent
        ghost.Transparency = 0.35
        ghost.Parent = workspace
        TweenService:Create(ghost, TweenInfo.new(0.4), { Transparency = 1, Size = ghost.Size * 1.15 }):Play()
        task.delay(0.45, function() ghost:Destroy() end)
    end)
end)

----------------------------------------------------------
-- ПОГОДА В МИРЕ (не на экране GUI)
----------------------------------------------------------
H.sectionLabel(fxCharTab, "ПОГОДА В МИРЕ", 61)
local worldWeatherConn = nil
local worldWeatherParts = {}
local function clearWorldWeather()
    if worldWeatherConn then worldWeatherConn:Disconnect(); worldWeatherConn = nil end
    for _, p in ipairs(worldWeatherParts) do if p then p:Destroy() end end
    worldWeatherParts = {}
end

local function startWorldWeather(kind)
    clearWorldWeather()
    worldWeatherConn = RunService.Heartbeat:Connect(function()
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not root then return end
        if math.random(1, kind == "rain" and 2 or 3) ~= 1 then return end
        local drop = Instance.new("Part")
        drop.Anchored = true
        drop.CanCollide = false
        drop.Material = Enum.Material.Neon
        if kind == "rain" then
            drop.Size = Vector3.new(0.08, 0.9, 0.08)
            drop.Color = Color3.fromRGB(140, 180, 255)
            drop.Transparency = 0.25
        else
            drop.Size = Vector3.new(0.25, 0.25, 0.25)
            drop.Shape = Enum.PartType.Ball
            drop.Color = Color3.fromRGB(255, 255, 255)
            drop.Transparency = 0.1
            drop.Material = Enum.Material.SmoothPlastic
        end
        local ox, oz = math.random(-40, 40), math.random(-40, 40)
        drop.CFrame = CFrame.new(root.Position + Vector3.new(ox, 35, oz))
        drop.Parent = workspace
        table.insert(worldWeatherParts, drop)
        local fall = kind == "rain" and math.random(12, 18) or math.random(8, 14)
        local drift = kind == "snow" and math.random(-5, 5) or 0
        local tw = TweenService:Create(drop, TweenInfo.new(fall / 10, Enum.EasingStyle.Linear), {
            CFrame = CFrame.new(root.Position + Vector3.new(ox + drift, -2, oz)),
            Transparency = 1,
        })
        tw:Play()
        tw.Completed:Connect(function()
            drop:Destroy()
            for i, p in ipairs(worldWeatherParts) do
                if p == drop then table.remove(worldWeatherParts, i) break end
            end
        end)
    end)
end

H.createButtonRow(fxCharTab, {
    { text = "Дождь в мире", callback = function() startWorldWeather("rain") end },
    { text = "Снег в мире", callback = function() startWorldWeather("snow") end },
    { text = "Выкл. погоду", callback = clearWorldWeather },
}, 62)

----------------------------------------------------------
-- ЕЩЁ ВИЗУАЛЫ
----------------------------------------------------------
H.sectionLabel(fxCharTab, "ВОЛНА ПОД НОГАМИ", 63)
local rippleConn = nil
H.createToggleRow(fxCharTab, "Круги на земле при ходьбе", 64, function(state)
    if rippleConn then rippleConn:Disconnect(); rippleConn = nil end
    if not state then return end
    local last = 0
    rippleConn = RunService.Heartbeat:Connect(function()
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not (hum and root) then return end
        if hum.MoveDirection.Magnitude < 0.2 then return end
        if hum:GetState() == Enum.HumanoidStateType.Freefall then return end
        if os.clock() - last < 0.35 then return end
        last = os.clock()
        spawnGroundRing(root.Position - Vector3.new(0, 3, 0), THEME.Accent, 3.5, 0.4, "forcefield")
    end)
end)

H.sectionLabel(fxCharTab, "РАДУЖНЫЙ ОРЕОЛ", 65)
local haloPart = nil
local haloConn = nil
H.createToggleRow(fxCharTab, "Радужный диск над головой", 66, function(state)
    if haloConn then haloConn:Disconnect(); haloConn = nil end
    if haloPart then haloPart:Destroy(); haloPart = nil end
    if not state then return end
    local head = player.Character and player.Character:FindFirstChild("Head")
    if not head then return end
    haloPart = Instance.new("Part")
    haloPart.Name = "__VM_Halo"
    haloPart.Anchored = true
    haloPart.CanCollide = false
    haloPart.Material = Enum.Material.Neon
    haloPart.Size = Vector3.new(0.15, 1.6, 1.6)
    haloPart.Color = Color3.fromRGB(255, 200, 80)
    haloPart.Parent = workspace
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Cylinder
    mesh.Parent = haloPart
    local hue = 0
    haloConn = RunService.RenderStepped:Connect(function(dt)
        local h = player.Character and player.Character:FindFirstChild("Head")
        if not (h and haloPart) then return end
        hue = (hue + dt * 0.35) % 1
        haloPart.Color = Color3.fromHSV(hue, 0.85, 1)
        haloPart.CFrame = CFrame.new(h.Position + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
    end)
end)

H.sectionLabel(fxCharTab, "ИСКРЫ ПРИ ДАБЛ-ДЖАМП ЖЕСТЕ", 67)
H.createButtonRow(fxCharTab, {
    { text = "Взрыв искр сейчас", callback = function()
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local em = Instance.new("ParticleEmitter")
        em.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        em.Lifetime = NumberRange.new(0.4, 0.9)
        em.Speed = NumberRange.new(6, 14)
        em.Size = NumberSequence.new(0.5, 0)
        em.Color = ColorSequence.new(THEME.Accent)
        em.SpreadAngle = Vector2.new(360, 360)
        em.LightEmission = 1
        em.Rate = 0
        em.Parent = root
        em:Emit(45)
        task.delay(1.2, function() em:Destroy() end)
    end },
}, 68)


----------------------------------------------------------
-- BABY (маленький рост)
----------------------------------------------------------
H.sectionLabel(fxCharTab, "BABY / РАЗМЕР", 70)
local babyEnabled = false
local babyScales = {}

local function setBaby(char, on)
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local function ensureScale(name, default)
        local v = hum:FindFirstChild(name)
        if not v then
            v = Instance.new("NumberValue")
            v.Name = name
            v.Value = default
            v.Parent = hum
        end
        return v
    end

    if on then
        local map = {
            BodyHeightScale = 0.45,
            BodyWidthScale = 0.45,
            BodyDepthScale = 0.45,
            HeadScale = 1.25,
        }
        for name, target in pairs(map) do
            local v = ensureScale(name, 1)
            if babyScales[name] == nil then babyScales[name] = v.Value end
            v.Value = target
        end
        if babyScales._hip == nil then babyScales._hip = hum.HipHeight end
        hum.HipHeight = math.max(0.5, (babyScales._hip or 2) * 0.45)
        if typeof(char.ScaleTo) == "function" then
            pcall(function() char:ScaleTo(0.5) end)
        end
    else
        for name, val in pairs(babyScales) do
            if name ~= "_hip" then
                local v = hum:FindFirstChild(name)
                if v then v.Value = val end
            end
        end
        if babyScales._hip then hum.HipHeight = babyScales._hip end
        babyScales = {}
        if typeof(char.ScaleTo) == "function" then
            pcall(function() char:ScaleTo(1) end)
        end
    end
end

H.createToggleRow(fxCharTab, "Baby (маленький рост)", 71, function(state)
    babyEnabled = state
    setBaby(player.Character, state)
end)
player.CharacterAdded:Connect(function(c)
    task.wait(0.5)
    if babyEnabled then setBaby(c, true) end
end)

----------------------------------------------------------
-- PENIS ESP (шуточный визуал)
----------------------------------------------------------
H.sectionLabel(fxCharTab, "PENIS ESP", 72)
local penisEnabled = false
local penisParts = {}

local function clearPenis()
    for _, p in ipairs(penisParts) do
        if p then p:Destroy() end
    end
    penisParts = {}
end

local function attachPenis(char)
    clearPenis()
    local lower = char:FindFirstChild("LowerTorso") or char:FindFirstChild("Torso")
    if not lower then return end
    local shaft = Instance.new("Part")
    shaft.Name = "__VM_Penis"
    shaft.Size = Vector3.new(0.28, 0.28, 0.85)
    shaft.Color = Color3.fromRGB(255, 180, 140)
    shaft.Material = Enum.Material.SmoothPlastic
    shaft.CanCollide = false
    shaft.Massless = true
    shaft.CastShadow = false
    shaft.Parent = char
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Sphere
    mesh.Scale = Vector3.new(1, 1, 1.4)
    mesh.Parent = shaft
    local w = Instance.new("Weld")
    w.Part0 = lower
    w.Part1 = shaft
    w.C0 = CFrame.new(0, -0.35, -0.55) * CFrame.Angles(math.rad(-15), 0, 0)
    w.Parent = shaft
    local tip = Instance.new("Part")
    tip.Name = "__VM_PenisTip"
    tip.Shape = Enum.PartType.Ball
    tip.Size = Vector3.new(0.32, 0.32, 0.32)
    tip.Color = Color3.fromRGB(255, 160, 130)
    tip.Material = Enum.Material.SmoothPlastic
    tip.CanCollide = false
    tip.Massless = true
    tip.Parent = char
    local w2 = Instance.new("Weld")
    w2.Part0 = shaft
    w2.Part1 = tip
    w2.C0 = CFrame.new(0, 0, -0.5)
    w2.Parent = tip
    table.insert(penisParts, shaft)
    table.insert(penisParts, tip)
end

H.createToggleRow(fxCharTab, "Penis ESP (визуал)", 73, function(state)
    penisEnabled = state
    if state and player.Character then
        attachPenis(player.Character)
    else
        clearPenis()
    end
end)
player.CharacterAdded:Connect(function(c)
    task.wait(0.5)
    if penisEnabled then attachPenis(c) end
end)

end

H.__build_Music = function()
-- ВКЛАДКА: МУЗЫКА (новый тип визуала — плеер с анимированным эквалайзером)
----------------------------------------------------------
H.createTabButton("Музыка", 10, CATEGORY_COLORS.Player)
musicTab = H.createTabFrame("Музыка")

currentSound = nil
local eqConnection = nil
local eqBars = {}

H.sectionLabel(musicTab, "ЭКВАЛАЙЗЕР", 1)
local eqHolder = Instance.new("Frame")
eqHolder.Size = UDim2.new(1, 0, 0, 70)
eqHolder.BackgroundColor3 = THEME.Panel
eqHolder.LayoutOrder = 2
eqHolder.Parent = musicTab
Instance.new("UICorner", eqHolder).CornerRadius = UDim.new(0, 6)

local eqLayout = Instance.new("UIListLayout")
eqLayout.FillDirection = Enum.FillDirection.Horizontal
eqLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
eqLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
eqLayout.Padding = UDim.new(0, 5)
eqLayout.Parent = eqHolder
local eqPad = Instance.new("UIPadding")
eqPad.PaddingBottom = UDim.new(0, 8)
eqPad.Parent = eqHolder

for i = 1, 16 do
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(0, 8, 0, 6)
    bar.BackgroundColor3 = THEME.Accent
    bar.BorderSizePixel = 0
    bar.Parent = eqHolder
    Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 3)
    table.insert(eqBars, bar)
end

-- эквалайзер анимируется по громкости трека (Roblox не даёт спектр
-- напрямую из LocalScript, поэтому бары "пляшут" синхронно с ритмом
-- через случайные колебания, привязанные к тому, играет ли звук)
task.spawn(function()
    while true do
        task.wait(0.09)
        local playing = currentSound ~= nil and currentSound.IsPlaying
        for _, bar in ipairs(eqBars) do
            local targetHeight = playing and math.random(6, 64) or 6
            TweenService:Create(bar, TweenInfo.new(0.09), {Size = UDim2.new(0, 8, 0, targetHeight)}):Play()
        end
    end
end)

-- очередь треков + воспроизведение
musicQueue = {}
local queueLoop = false
local seekSliderHandle = nil
local queueListLabel = nil

refreshQueueLabel = function()
    if not queueListLabel then return end
    if #musicQueue == 0 then
        queueListLabel.Text = "Очередь пуста"
        return
    end
    local parts = {}
    for i, s in ipairs(musicQueue) do
        table.insert(parts, i .. ". " .. (s.name or s.id))
    end
    queueListLabel.Text = table.concat(parts, "  ·  ")
end


-- Устаревшие forward-объявления local playTrack / local updateMiniPlayer
-- удалены: они жили только внутри этой функции, а вкладка «Музыка» лежит
-- в H.__build_MiniPlayer и обращалась к пустым глобальным переменным —
-- из-за этого кнопки «В избранное» и «Играть избранное» молча ничего
-- не делали. Теперь playTrack / updateMiniPlayer — обычные глобальные
-- функции, которые создаёт модуль мини-плеера.

end

H.__build_MiniPlayer = function()
--------------------------------------------------------------------------
--  МИНИ-ПЛЕЕР v8  ·  «жидкое стекло» + векторные иконки + 2 режима
--------------------------------------------------------------------------
--  Что изменилось по сравнению с v7:
--   • НИ ОДНОГО ЭМОДЗИ. Все иконки (play/pause/next/prev/loop/shuffle/
--     громкость/нота/стрелки/крестик) нарисованы векторно из фигур
--     Roblox — они всегда одинаковые и выглядят аккуратно.
--   • Масштаб теперь через UIScale, а не через изменение Size. Поэтому
--     при уменьшении/увеличении плеера кнопки, отступы, шрифты и
--     прогресс-бар сжимаются ВМЕСТЕ и больше НЕ слипаются друг с другом.
--   • Два режима: ПОЛНЫЙ (обложка-винил, спектр из 26 полос, очередь,
--     громкость, скорость, прогресс с перемоткой) и КОМПАКТНЫЙ (пилюля
--     с обложкой, названием и кнопкой «развернуть»).
--   • Живое стекло: градиент, блик, мягкая тень, свечение акцента,
--     пульс кольца обложки в такт, скруглённые края-«капсула».
--   • Подсказки при наведении на каждую кнопку, всплывающий регулятор
--     громкости, бегущая строка для длинных названий.
--   • Клик по верхней кромке = перемотка (перетаскивание тоже работает).
--------------------------------------------------------------------------
local MP = {}
H.mp = MP

-- ВАЖНО: НИЖЕ НЕТ `local` ДЛЯ ЭТИХ ИМЁН — так и задумано.
-- На них ссылается остальная часть вкладки «Музыка» (она идёт ниже, в этом
-- же файле). Раньше часть имён объявлялась локально внутри одной функции, а
-- использовалась в другой — и бралась пустая глобальная переменная, из-за
-- чего кнопки (избранное, повтор, тумблер мини-плеера) молча не работали.
--   MiniPlayer · mpPlay · mpLoop · miniPlayerEnabled · lastTrackId
--   lastTrackLabel · playTrack · updateMiniPlayer · refreshLoopBtn
-- mpVolFill объявлена в самом верху файла (её читает система конфигов).

MP.layout = "full"          -- full | compact
MP.enabled = true
MP.scale = 1                -- 0.7 .. 1.5 (множитель UIScale)
MP.opacity = 8              -- 0..80 (%) прозрачность стекла
MP.speed = 1                -- скорость воспроизведения
MP.lastId, MP.lastLabel = nil, nil
MP.queueCount = 0

----------------------------------------------------------
-- ВЕКТОРНЫЕ ИКОНКИ (общая библиотека для всего скрипта)
----------------------------------------------------------
local ICON = {}
H.icons = ICON

local function mkPart(parent, w, h, x, y, color)
    local f = Instance.new("Frame")
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.Position = UDim2.new(0.5, x, 0.5, y)
    f.Size = UDim2.new(0, w, 0, h)
    f.BackgroundColor3 = color or Color3.new(1, 1, 1)
    f.BorderSizePixel = 0
    f.Parent = parent
    return f
end

local function mkRound(f, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    c.Parent = f
    return f
end

local function mkStroke(f, color, thick, transp)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.new(1, 1, 1)
    s.Thickness = thick or 1
    s.Transparency = transp or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = f
    return s
end
ICON.part, ICON.round, ICON.stroke = mkPart, mkRound, mkStroke

-- треугольник: ромб (квадрат под 45°) обрезанный рамкой —
-- так «play» выглядит как настоящая иконка, а не как символ шрифта
local function mkTriangle(parent, s, color, dir, z)
    local clip = Instance.new("Frame")
    clip.Size = UDim2.new(0, math.ceil(s), 0, math.ceil(s))
    clip.AnchorPoint = Vector2.new(0.5, 0.5)
    clip.BackgroundTransparency = 1
    clip.ClipsDescendants = true
    clip.ZIndex = z or 1
    clip.Parent = parent
    local d = Instance.new("Frame")
    local side = math.ceil(s * 1.5)
    d.Size = UDim2.new(0, side, 0, side)
    d.AnchorPoint = Vector2.new(0.5, 0.5)
    d.Position = UDim2.new(0.5, (dir == "left") and (s * 0.56) or (-s * 0.56), 0.5, 0)
    d.Rotation = 45
    d.BackgroundColor3 = color or Color3.new(1, 1, 1)
    d.BorderSizePixel = 0
    d.ZIndex = z or 1
    d.Parent = clip
    mkRound(d, math.max(1, s * 0.10))
    return clip, d
end
ICON.triangle = mkTriangle

-- собирает иконку по имени; возвращает { root, SetColor, SetState }
local function buildIcon(kind, size, color)
    local holder = Instance.new("Frame")
    holder.Name = "Icn_" .. tostring(kind)
    holder.Size = UDim2.new(0, size, 0, size)
    holder.BackgroundTransparency = 1
    holder.AnchorPoint = Vector2.new(0.5, 0.5)
    holder.Position = UDim2.new(0.5, 0, 0.5, 0)

    local c = color or Color3.fromRGB(240, 240, 245)
    local k = size / 24
    local parts, strokes, spin = {}, {}, nil
    local function add(f) table.insert(parts, f) return f end
    local function ring(size2, thick)
        local r = mkPart(holder, size2, size2, 0, 0, c)
        r.BackgroundTransparency = 1
        mkRound(r, size2)
        table.insert(strokes, mkStroke(r, c, thick or math.max(1.4, 1.9 * k), 0))
        return r
    end
    local function bar(w, h, x, y, rot, radius)
        local f = mkRound(mkPart(holder, w, h, x, y, c), radius or math.max(1, 1.1 * k))
        if rot then f.Rotation = rot end
        return add(f)
    end

    if kind == "play" then
        local clip, d = mkTriangle(holder, size * 0.62, c, "right", 1)
        clip.Position = UDim2.new(0.5, size * 0.06, 0.5, 0)
        add(d)
    elseif kind == "pause" then
        bar(math.max(2.4, 4.4 * k), size * 0.60, -3.3 * k, 0, nil, 2 * k)
        bar(math.max(2.4, 4.4 * k), size * 0.60, 3.3 * k, 0, nil, 2 * k)
    elseif kind == "next" or kind == "prev" then
        local sign = (kind == "next") and 1 or -1
        local clip, d = mkTriangle(holder, size * 0.46, c, (kind == "next") and "right" or "left", 1)
        clip.Position = UDim2.new(0.5, -sign * size * 0.10, 0.5, 0)
        add(d)
        bar(math.max(2, 2.8 * k), size * 0.54, sign * size * 0.30, 0, nil, 2 * k)
    elseif kind == "loop" then
        ring(size * 0.62)
        local clip, d = mkTriangle(holder, size * 0.20, c, "right", 1)
        clip.Position = UDim2.new(0.5, size * 0.30, 0.5, -size * 0.30)
        add(d)
        local dot = mkRound(mkPart(holder, size * 0.20, size * 0.20, 0, 0, c), size)
        dot.Name = "Dot"
        dot.BackgroundTransparency = 1
        parts.dot = dot
    elseif kind == "shuffle" then
        bar(size * 0.56, 2 * k, 0, -2.3 * k, 22)
        bar(size * 0.56, 2 * k, 0, 2.3 * k, -22)
        bar(2.8 * k, 2.8 * k, -size * 0.27, -4.4 * k, nil, 4)
        bar(2.8 * k, 2.8 * k, -size * 0.27, 4.4 * k, nil, 4)
    elseif kind == "volume" then
        bar(math.max(2, 3.6 * k), size * 0.28, -7 * k, 0, nil, 2 * k)
        local clip, d = mkTriangle(holder, size * 0.30, c, "right", 1)
        clip.Position = UDim2.new(0.5, -2.6 * k, 0.5, 0)
        add(d)
        bar(2 * k, 5 * k, 4 * k, 0, nil, 2 * k)
        bar(2 * k, 8 * k, 7 * k, 0, nil, 2 * k)
        bar(2 * k, 11.5 * k, 10 * k, 0, nil, 2 * k)
    elseif kind == "mute" then
        bar(math.max(2, 3.6 * k), size * 0.28, -7 * k, 0, nil, 2 * k)
        local clip, d = mkTriangle(holder, size * 0.30, c, "right", 1)
        clip.Position = UDim2.new(0.5, -2.6 * k, 0.5, 0)
        add(d)
        bar(8 * k, 2 * k, 7 * k, 0, 45)
        bar(8 * k, 2 * k, 7 * k, 0, -45)
    elseif kind == "note" then
        bar(2.4 * k, size * 0.52, 3.2 * k, -1.5 * k, nil, 2 * k)
        bar(size * 0.30, 2.4 * k, 6.6 * k, -9.2 * k, 14, 2 * k)
        bar(size * 0.32, size * 0.32, -1.6 * k, 8.2 * k, nil, size)
    elseif kind == "chevron" then
        bar(8 * k, 2.2 * k, -2.4 * k, 0, -42)
        bar(8 * k, 2.2 * k, 2.4 * k, 0, 42)
    elseif kind == "chevronUp" then
        bar(8 * k, 2.2 * k, -2.4 * k, 0, 42)
        bar(8 * k, 2.2 * k, 2.4 * k, 0, -42)
    elseif kind == "close" then
        bar(9 * k, 2.2 * k, 0, 0, 45)
        bar(9 * k, 2.2 * k, 0, 0, -45)
    elseif kind == "expand" then
        for _, sx in ipairs({-1, 1}) do
            for _, sy in ipairs({-1, 1}) do
                bar(7 * k, 2.2 * k, sx * 3.6 * k, sy * 6.4 * k)
                bar(2.2 * k, 7 * k, sx * 6.4 * k, sy * 3.6 * k)
            end
        end
    elseif kind == "collapse" then
        for _, sx in ipairs({-1, 1}) do
            for _, sy in ipairs({-1, 1}) do
                bar(7 * k, 2.2 * k, sx * 6.4 * k, sy * 3.6 * k)
                bar(2.2 * k, 7 * k, sx * 3.6 * k, sy * 6.4 * k)
            end
        end
    elseif kind == "spectrum" then
        for i, v in ipairs({ 5, 12, 7, 15 }) do
            bar(2.6 * k, v * k, (i - 2.5) * 4.6 * k, 0, nil, 2 * k)
        end
    elseif kind == "sun" then
        ring(size * 0.46, math.max(1.4, 2 * k))
        bar(2 * k, 4.4 * k, 0, -8.6 * k)
        bar(2 * k, 4.4 * k, 0, 8.6 * k)
        bar(4.4 * k, 2 * k, -8.6 * k, 0)
        bar(4.4 * k, 2 * k, 8.6 * k, 0)
    elseif kind == "monitor" then
        local scr = mkPart(holder, size * 0.74, size * 0.54, 0, -2 * k, c)
        scr.BackgroundTransparency = 1
        mkRound(scr, 3 * k)
        table.insert(strokes, mkStroke(scr, c, math.max(1.4, 1.9 * k), 0))
        bar(size * 0.30, 2 * k, 0, 7.6 * k)
    elseif kind == "sliders" then
        for i, x in ipairs({ -4, 3, -1 }) do
            local y = (i - 2) * 6.2 * k
            bar(size * 0.72, 2 * k, 0, y)
            bar(3.6 * k, 3.6 * k, x, y, nil, 4)
        end
    elseif kind == "lens" then
        ring(size * 0.62)
        bar(size * 0.24, size * 0.24, 0, 0, nil, size)
    elseif kind == "wheel" then
        ring(size * 0.66)
        for i = 1, 4 do
            bar(2 * k, size * 0.26, 0, -size * 0.19, (i - 1) * 45, 2 * k)
        end
    elseif kind == "disk" then
        for _, sx in ipairs({-1, 1}) do
            for _, sy in ipairs({-1, 1}) do
                bar(6.4 * k, 2 * k, sx * 3.4 * k, sy * 6.6 * k)
                bar(2 * k, 6.4 * k, sx * 6.6 * k, sy * 3.4 * k)
            end
        end
        bar(3.4 * k, 3.4 * k, 0, 0, nil, size)
    else
        bar(size * 0.26, size * 0.26, 0, 0, nil, size)
    end

    local obj = { root = holder, parts = parts, strokes = strokes, kind = kind, spin = spin }
    obj.SetColor = function(col)
        for _, f in ipairs(parts) do
            if f and f.Parent then pcall(function() f.BackgroundColor3 = col end) end
        end
        for _, s in ipairs(strokes) do
            if s and s.Parent then pcall(function() s.Color = col end) end
        end
    end
    obj.SetState = function(on, onColor, offColor)
        obj.SetColor(on and (onColor or THEME.Accent) or (offColor or THEME.SubText))
    end
    return obj
end
ICON.build = buildIcon
ICON.new = function(parent, kind, size, color)
    local ic = buildIcon(kind, size, color)
    ic.root.Parent = parent
    return ic
end

----------------------------------------------------------
-- ГЕОМЕТРИЯ (базовый «дизайнерский» размер, дальше всё через UIScale)
----------------------------------------------------------
local W, HG = 440, 122        -- полный режим
local CW, CH = 292, 56        -- компактный режим
local PAD = 14

local MiniPlayerGui = Instance.new("ScreenGui")
MiniPlayerGui.Name = "VisualMenuMiniPlayer"
MiniPlayerGui.ResetOnSpawn = false
MiniPlayerGui.IgnoreGuiInset = true
MiniPlayerGui.DisplayOrder = 95
MiniPlayerGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
MiniPlayerGui.Parent = game:GetService("CoreGui")

-- звук живёт здесь — не умирает с персонажем / PlayerGui
local SoundHolder = Instance.new("ScreenGui")
SoundHolder.Name = "__VM_SoundHolder"
SoundHolder.ResetOnSpawn = false
SoundHolder.Parent = game:GetService("CoreGui")

----------------------------------------------------------
-- ОБЁРТКА + UIScale (вот из-за неё ничего не слипается)
----------------------------------------------------------
local Wrap = Instance.new("Frame")
Wrap.Name = "MiniPlayerWrap"
Wrap.Size = UDim2.new(0, W, 0, HG)
Wrap.Position = UDim2.new(0.5, -W / 2, 1, -HG - 26)
Wrap.BackgroundTransparency = 1
Wrap.Visible = false
Wrap.Parent = MiniPlayerGui
MP.wrap = Wrap

local mpScale = Instance.new("UIScale")
mpScale.Scale = MP.scale
mpScale.Parent = Wrap
MP.scaleObj = mpScale

local Shadow = Instance.new("ImageLabel")
Shadow.Name = "Shadow"
Shadow.Image = "rbxassetid://1316045217"
Shadow.ScaleType = Enum.ScaleType.Slice
Shadow.SliceCenter = Rect.new(10, 10, 118, 118)
Shadow.Size = UDim2.new(1, 60, 1, 58)
Shadow.Position = UDim2.new(0, -30, 0, -24)
Shadow.BackgroundTransparency = 1
Shadow.ImageColor3 = Color3.new(0, 0, 0)
Shadow.ImageTransparency = 0.55
Shadow.ZIndex = 0
Shadow.Parent = Wrap

MiniPlayer = Instance.new("Frame")
MiniPlayer.Name = "Player"
MiniPlayer.Size = UDim2.new(1, 0, 1, 0)
MiniPlayer.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
MiniPlayer.BackgroundTransparency = MP.opacity / 100
MiniPlayer.BorderSizePixel = 0
MiniPlayer.ClipsDescendants = true
MiniPlayer.Active = true
MiniPlayer.ZIndex = 1
MiniPlayer.Parent = Wrap
Instance.new("UICorner", MiniPlayer).CornerRadius = UDim.new(0, 22)

local mpBgGrad = Instance.new("UIGradient")
mpBgGrad.Rotation = 96
mpBgGrad.Parent = MiniPlayer
H.regFn(function()
    mpBgGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, H.lighten(THEME.Panel, 0.10)),
        ColorSequenceKeypoint.new(0.55, H.darken(THEME.Background, 0.05)),
        ColorSequenceKeypoint.new(1, H.darken(THEME.Background, 0.35)),
    })
end)

local mpStroke = Instance.new("UIStroke")
mpStroke.Thickness = 1.3
mpStroke.Transparency = 0.45
mpStroke.Parent = MiniPlayer
H.reg(mpStroke, "Color", "Accent")

-- мягкое акцентное свечение в левом верхнем углу (стекло)
local mpBloom = Instance.new("Frame")
mpBloom.Size = UDim2.new(0, 190, 0, 190)
mpBloom.Position = UDim2.new(0, -70, 0, -110)
mpBloom.BackgroundColor3 = THEME.Accent
mpBloom.BackgroundTransparency = 0.86
mpBloom.BorderSizePixel = 0
mpBloom.ZIndex = 1
mpBloom.Parent = MiniPlayer
Instance.new("UICorner", mpBloom).CornerRadius = UDim.new(1, 0)
local bloomGrad = Instance.new("UIGradient")
bloomGrad.Rotation = 120
bloomGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0),
    NumberSequenceKeypoint.new(1, 1),
})
bloomGrad.Parent = mpBloom
H.regFn(function()
    mpBloom.BackgroundColor3 = THEME.Accent
    bloomGrad.Color = ColorSequence.new(THEME.Accent, H.lighten(THEME.Accent, 0.5))
end)

-- верхний блик (тонкая светлая полоса, медленно «дышит»)
local mpSheen = Instance.new("Frame")
mpSheen.Size = UDim2.new(1, 0, 0, 1)
mpSheen.Position = UDim2.new(0, 0, 0, 0)
mpSheen.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
mpSheen.BackgroundTransparency = 0.86
mpSheen.BorderSizePixel = 0
mpSheen.ZIndex = 3
mpSheen.Parent = MiniPlayer
local sheenGrad = Instance.new("UIGradient")
sheenGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.95),
    NumberSequenceKeypoint.new(0.35, 0.15),
    NumberSequenceKeypoint.new(1, 0.95),
})
sheenGrad.Parent = mpSheen

----------------------------------------------------------
-- СТРАНИЦА «ПОЛНЫЙ» — прогресс, обложка-винил, спектр, чипы
----------------------------------------------------------
local Full = Instance.new("Frame")
Full.Name = "PageFull"
Full.Size = UDim2.new(1, 0, 1, 0)
Full.BackgroundTransparency = 1
Full.ZIndex = 2
Full.Parent = MiniPlayer

-- ── прогресс (клик/перетаскивание) ──────────────────────
local progHit = Instance.new("TextButton")
progHit.Name = "SeekArea"
progHit.Size = UDim2.new(1, 0, 0, 16)
progHit.Position = UDim2.new(0, 0, 0, -3)
progHit.BackgroundTransparency = 1
progHit.Text = ""
progHit.AutoButtonColor = false
progHit.ZIndex = 6
progHit.Parent = Full

local progTrack = Instance.new("Frame")
progTrack.Name = "Track"
progTrack.Size = UDim2.new(1, -PAD * 2, 0, 4)
progTrack.Position = UDim2.new(0, PAD, 0, 4)
progTrack.BackgroundColor3 = H.lighten(THEME.Panel, 0.12)
progTrack.BorderSizePixel = 0
progTrack.ZIndex = 4
progTrack.Parent = Full
Instance.new("UICorner", progTrack).CornerRadius = UDim.new(1, 0)
H.reg(progTrack, "BackgroundColor3", "Panel")

local progFill = Instance.new("Frame")
progFill.Name = "Fill"
progFill.Size = UDim2.new(0, 0, 1, 0)
progFill.BackgroundColor3 = THEME.Accent
progFill.BorderSizePixel = 0
progFill.ZIndex = 5
progFill.Parent = progTrack
Instance.new("UICorner", progFill).CornerRadius = UDim.new(1, 0)
H.reg(progFill, "BackgroundColor3", "Accent")
local progFillGrad = Instance.new("UIGradient")
progFillGrad.Rotation = 0
progFillGrad.Parent = progFill
H.regFn(function()
    progFillGrad.Color = ColorSequence.new(H.darken(THEME.Accent, 0.35), H.lighten(THEME.Accent, 0.35))
end)

local progKnob = Instance.new("Frame")
progKnob.AnchorPoint = Vector2.new(0.5, 0.5)
progKnob.Position = UDim2.new(1, 0, 0.5, 0)
progKnob.Size = UDim2.new(0, 11, 0, 11)
progKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
progKnob.BorderSizePixel = 0
progKnob.ZIndex = 6
progKnob.BackgroundTransparency = 1
progKnob.Parent = progFill
Instance.new("UICorner", progKnob).CornerRadius = UDim.new(1, 0)
local knobStroke = Instance.new("UIStroke", progKnob)
knobStroke.Thickness = 2.4
knobStroke.Transparency = 1
H.reg(knobStroke, "Color", "Accent")

-- ── обложка-винил ───────────────────────────────────────
local ArtSlot = Instance.new("TextButton")
ArtSlot.Name = "Art"
ArtSlot.Size = UDim2.new(0, 82, 0, 82)
ArtSlot.Position = UDim2.new(0, PAD, 0, 20)
ArtSlot.BackgroundColor3 = H.darken(THEME.Background, 0.35)
ArtSlot.Text = ""
ArtSlot.AutoButtonColor = false
ArtSlot.ClipsDescendants = true
ArtSlot.ZIndex = 4
ArtSlot.Parent = Full
Instance.new("UICorner", ArtSlot).CornerRadius = UDim.new(0, 22)
local artStroke = Instance.new("UIStroke", ArtSlot)
artStroke.Thickness = 1.4
artStroke.Transparency = 0.3
artStroke.Parent = ArtSlot
H.reg(artStroke, "Color", "Accent")

local artGrad = Instance.new("UIGradient")
artGrad.Rotation = 135
artGrad.Parent = ArtSlot
H.regFn(function()
    artGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, H.darken(THEME.Panel, 0.10)),
        ColorSequenceKeypoint.new(1, H.darken(THEME.Accent, 0.72)),
    })
end)

local Vinyl = Instance.new("Frame")
Vinyl.Name = "Vinyl"
Vinyl.AnchorPoint = Vector2.new(0.5, 0.5)
Vinyl.Position = UDim2.new(0.5, 0, 0.5, 0)
Vinyl.Size = UDim2.new(0, 64, 0, 64)
Vinyl.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
Vinyl.BackgroundTransparency = 0.12
Vinyl.BorderSizePixel = 0
Vinyl.ZIndex = 5
Vinyl.Parent = ArtSlot
Instance.new("UICorner", Vinyl).CornerRadius = UDim.new(1, 0)
for i = 1, 3 do
    local g = Instance.new("Frame")
    g.AnchorPoint = Vector2.new(0.5, 0.5)
    g.Position = UDim2.new(0.5, 0, 0.5, 0)
    local s = 1 - i * 0.2
    g.Size = UDim2.new(s, 0, s, 0)
    g.BackgroundTransparency = 1
    g.ZIndex = 5
    g.Parent = Vinyl
    Instance.new("UICorner", g).CornerRadius = UDim.new(1, 0)
    local gs = Instance.new("UIStroke", g)
    gs.Color = Color3.fromRGB(255, 255, 255)
    gs.Transparency = 0.88
    gs.Thickness = 1
end

local VinylLabel = Instance.new("Frame")
VinylLabel.Size = UDim2.new(0, 26, 0, 26)
VinylLabel.AnchorPoint = Vector2.new(0.5, 0.5)
VinylLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
VinylLabel.BackgroundColor3 = THEME.Accent
VinylLabel.BorderSizePixel = 0
VinylLabel.ZIndex = 6
VinylLabel.Parent = Vinyl
Instance.new("UICorner", VinylLabel).CornerRadius = UDim.new(1, 0)
H.reg(VinylLabel, "BackgroundColor3", "Accent")
local VinylNote = ICON.new(VinylLabel, "note", 16, Color3.fromRGB(10, 10, 14))

-- пульсирующее кольцо вокруг обложки (в такт)
local artPulse = Instance.new("Frame")
artPulse.Size = UDim2.new(1, 0, 1, 0)
artPulse.BackgroundTransparency = 1
artPulse.ZIndex = 4
artPulse.Parent = ArtSlot
Instance.new("UICorner", artPulse).CornerRadius = UDim.new(0, 22)
local artPulseStroke = Instance.new("UIStroke", artPulse)
artPulseStroke.Thickness = 1.6
artPulseStroke.Transparency = 1
H.reg(artPulseStroke, "Color", "Accent")

-- индикатор «играет» — три живые полоски в углу обложки
local liveBars = {}
do
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(0, 22, 0, 12)
    holder.Position = UDim2.new(1, -26, 1, -16)
    holder.BackgroundTransparency = 1
    holder.ZIndex = 7
    holder.Parent = ArtSlot
    for i = 1, 3 do
        local b = Instance.new("Frame")
        b.AnchorPoint = Vector2.new(0, 1)
        b.Position = UDim2.new(0, (i - 1) * 6, 1, 0)
        b.Size = UDim2.new(0, 3, 0, 4)
        b.BackgroundColor3 = THEME.Accent
        b.BorderSizePixel = 0
        b.ZIndex = 7
        b.Parent = holder
        Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
        H.reg(b, "BackgroundColor3", "Accent")
        table.insert(liveBars, b)
    end
end

-- ── название / исполнитель / спектр ────────────────────
local INFO_X = 108
local INFO_W = W - INFO_X - 154

local titleClip = Instance.new("Frame")
titleClip.Name = "TitleClip"
titleClip.Size = UDim2.new(0, INFO_W, 0, 20)
titleClip.Position = UDim2.new(0, INFO_X, 0, 16)
titleClip.BackgroundTransparency = 1
titleClip.ClipsDescendants = true
titleClip.ZIndex = 4
titleClip.Parent = Full

local titleA = Instance.new("TextLabel")
titleA.Size = UDim2.new(0, INFO_W, 1, 0)
titleA.Position = UDim2.new(0, 0, 0, 0)
titleA.BackgroundTransparency = 1
titleA.Text = "Ничего не играет"
titleA.TextColor3 = THEME.Text
titleA.Font = Enum.Font.GothamBold
titleA.TextSize = 15
titleA.TextXAlignment = Enum.TextXAlignment.Left
titleA.TextTruncate = Enum.TextTruncate.None
titleA.ZIndex = 4
titleA.Parent = titleClip
H.reg(titleA, "TextColor3", "Text")

local titleB = Instance.new("TextLabel")
titleB.Size = UDim2.new(0, INFO_W, 1, 0)
titleB.Position = UDim2.new(0, INFO_W + 26, 0, 0)
titleB.BackgroundTransparency = 1
titleB.Text = ""
titleB.TextColor3 = THEME.Text
titleB.Font = Enum.Font.GothamBold
titleB.TextSize = 15
titleB.TextXAlignment = Enum.TextXAlignment.Left
titleB.TextTruncate = Enum.TextTruncate.None
titleB.ZIndex = 4
titleB.Parent = titleClip
H.reg(titleB, "TextColor3", "Text")

local subLabel = Instance.new("TextLabel")
subLabel.Size = UDim2.new(0, INFO_W, 0, 14)
subLabel.Position = UDim2.new(0, INFO_X, 0, 38)
subLabel.BackgroundTransparency = 1
subLabel.Text = "Visual Menu · мини-плеер"
subLabel.TextColor3 = THEME.SubText
subLabel.Font = Enum.Font.Gotham
subLabel.TextSize = 11
subLabel.TextXAlignment = Enum.TextXAlignment.Left
subLabel.TextTruncate = Enum.TextTruncate.AtEnd
subLabel.ZIndex = 4
subLabel.Parent = Full
H.reg(subLabel, "TextColor3", "SubText")

local SPEC_N = 26
local specHolder = Instance.new("Frame")
specHolder.Name = "Spectrum"
specHolder.Size = UDim2.new(0, INFO_W, 0, 22)
specHolder.Position = UDim2.new(0, INFO_X, 0, 56)
specHolder.BackgroundTransparency = 1
specHolder.ZIndex = 4
specHolder.Parent = Full
local specLayout = Instance.new("UIListLayout")
specLayout.FillDirection = Enum.FillDirection.Horizontal
specLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
specLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
specLayout.Padding = UDim.new(0, 2)
specLayout.Parent = specHolder

local specBars = {}
for i = 1, SPEC_N do
    local b = Instance.new("Frame")
    b.Size = UDim2.new(0, 3, 0, 3)
    b.BackgroundColor3 = THEME.Accent
    b.BackgroundTransparency = 0.25
    b.BorderSizePixel = 0
    b.ZIndex = 4
    b.Parent = specHolder
    Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
    H.reg(b, "BackgroundColor3", "Accent")
    specBars[i] = { obj = b, h = 3, peak = 3 }
end

-- ── время + чипы ───────────────────────────────────────
local timeL = Instance.new("TextLabel")
timeL.Size = UDim2.new(0, 60, 0, 13)
timeL.Position = UDim2.new(0, INFO_X, 0, 103)
timeL.BackgroundTransparency = 1
timeL.Text = "0:00"
timeL.TextColor3 = THEME.Text
timeL.Font = Enum.Font.GothamMedium
timeL.TextSize = 11
timeL.TextXAlignment = Enum.TextXAlignment.Left
timeL.ZIndex = 4
timeL.Parent = Full
H.reg(timeL, "TextColor3", "Text")

local timeR = Instance.new("TextLabel")
timeR.Size = UDim2.new(0, 90, 0, 13)
timeR.Position = UDim2.new(0, INFO_X + INFO_W - 90, 0, 103)
timeR.BackgroundTransparency = 1
timeR.Text = "0:00"
timeR.TextColor3 = THEME.SubText
timeR.Font = Enum.Font.GothamMedium
timeR.TextSize = 11
timeR.TextXAlignment = Enum.TextXAlignment.Right
timeR.ZIndex = 4
timeR.Parent = Full
H.reg(timeR, "TextColor3", "SubText")

----------------------------------------------------------
-- ПОДСКАЗКИ (одна общая «пилюля» на весь плеер)
----------------------------------------------------------
local Tip = Instance.new("Frame")
Tip.Name = "Tooltip"
Tip.BackgroundColor3 = H.darken(THEME.Panel, 0.15)
Tip.BackgroundTransparency = 0.05
Tip.BorderSizePixel = 0
Tip.Size = UDim2.new(0, 100, 0, 24)
Tip.Visible = false
Tip.ZIndex = 40
Tip.Parent = MiniPlayerGui
Instance.new("UICorner", Tip).CornerRadius = UDim.new(0, 8)
local tipStroke = Instance.new("UIStroke", Tip)
tipStroke.Thickness = 1
tipStroke.Transparency = 0.4
tipStroke.Parent = Tip
H.reg(tipStroke, "Color", "Accent")
local tipLabel = Instance.new("TextLabel")
tipLabel.Size = UDim2.new(1, -16, 1, 0)
tipLabel.Position = UDim2.new(0, 8, 0, 0)
tipLabel.BackgroundTransparency = 1
tipLabel.Text = ""
tipLabel.TextColor3 = THEME.Text
tipLabel.Font = Enum.Font.GothamMedium
tipLabel.TextSize = 11
tipLabel.ZIndex = 41
tipLabel.Parent = Tip
H.reg(tipLabel, "TextColor3", "Text")

local tipToken = 0
MP.tooltip = function(text, anchor)
    tipToken = tipToken + 1
    local my = tipToken
    if not text or not anchor or not anchor.Parent then
        H.tw(Tip, 0.12, { BackgroundTransparency = 1 })
        H.tw(tipLabel, 0.12, { TextTransparency = 1 })
        task.delay(0.13, function()
            if my == tipToken then Tip.Visible = false end
        end)
        return
    end
    tipLabel.Text = text
    Tip.Visible = true
    Tip.BackgroundTransparency = 1
    tipLabel.TextTransparency = 1
    H.tw(Tip, 0.14, { BackgroundTransparency = 0.05 })
    H.tw(tipLabel, 0.14, { TextTransparency = 0 })
    task.defer(function()
        if my ~= tipToken then return end
        local ap = anchor.AbsolutePosition
        local asz = anchor.AbsoluteSize
        local tw = math.max(64, tipLabel.TextBounds.X + 22)
        Tip.Size = UDim2.new(0, tw, 0, 24)
        local x = ap.X + asz.X / 2 - tw / 2
        local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
        x = math.clamp(x, 6, math.max(6, vp.X - tw - 6))
        local y = ap.Y - 32
        local flip = y < 4
        if flip then y = ap.Y + asz.Y + 8 end
        Tip.Position = UDim2.new(0, x, 0, y)
    end)
end

----------------------------------------------------------
-- ФАБРИКА КНОПОК (иконка + ховер + риппл + подсказка)
----------------------------------------------------------
local hovered = {}
local function mkBtn(parent, kind, sizePx, opts)
    opts = opts or {}
    local btn = Instance.new("TextButton")
    btn.Name = "Btn_" .. kind
    btn.Size = (opts.tall and UDim2.new(0, sizePx, 1, 0)) or UDim2.new(0, sizePx, 0, sizePx)
    btn.BackgroundColor3 = opts.accent and THEME.Accent or H.lighten(THEME.Panel, 0.05)
    btn.BackgroundTransparency = opts.accent and 0.04 or 0.25
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.ClipsDescendants = true
    btn.ZIndex = opts.z or 5
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = opts.square and UDim.new(0, 10) or UDim.new(1, 0)
    local st = Instance.new("UIStroke", btn)
    st.Thickness = 1
    st.Transparency = opts.accent and 0.35 or 0.6
    st.Parent = btn
    H.reg(st, "Color", "Accent")

    local scale = Instance.new("UIScale")
    scale.Parent = btn

    local iconCol = opts.accent and Color3.fromRGB(9, 9, 13) or THEME.Text
    local icon = ICON.new(btn, kind, math.max(12, math.floor((sizePx or 30) * (opts.iconScale or 0.5))), iconCol)
    icon.root.ZIndex = (opts.z or 5) + 1

    local baseBg = btn.BackgroundColor3
    local baseBt = btn.BackgroundTransparency

    local function onEnter()
        hovered[btn] = true
        H.tw(btn, 0.16, { BackgroundTransparency = opts.accent and 0 or math.max(0, baseBt - 0.15) })
        H.tw(btn, 0.16, { BackgroundColor3 = opts.accent and H.lighten(THEME.Accent, 0.10) or THEME.PanelHover })
        H.tw(scale, 0.18, { Scale = 1.09 }, Enum.EasingStyle.Back)
        H.tw(st, 0.16, { Transparency = 0.1 })
        if not opts.accent then icon.SetColor(THEME.Accent) end
        if opts.tip then MP.tooltip(opts.tip, btn) end
    end
    local function onLeave()
        hovered[btn] = nil
        H.tw(btn, 0.18, { BackgroundTransparency = baseBt, BackgroundColor3 = baseBg })
        H.tw(scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Quad)
        H.tw(st, 0.18, { Transparency = opts.accent and 0.35 or 0.6 })
        if not opts.accent then icon.SetColor(THEME.Text) end
        if opts.tip then MP.tooltip(nil) end
    end
    btn.MouseEnter:Connect(onEnter)
    btn.MouseLeave:Connect(onLeave)
    btn.MouseButton1Down:Connect(function(x, y)
        H.ripple(btn, x, y)
        H.tw(scale, 0.08, { Scale = 0.93 })
    end)
    btn.MouseButton1Up:Connect(function()
        H.tw(scale, 0.18, { Scale = hovered[btn] and 1.09 or 1 }, Enum.EasingStyle.Back)
    end)
    btn.MouseButton1Click:Connect(function()
        playGuiClick()
        if opts.onClick then
            local ok, err = pcall(opts.onClick)
            if not ok and H.notify then H.notify("Ошибка кнопки: " .. tostring(err), THEME.Error) end
        end
    end)
    H.regFn(onLeave)
    return { btn = btn, icon = icon, scale = scale, kind = kind, hovered = hovered }
end
MP.mkBtn = mkBtn

-- компактный «чип»: иконка + подпись, для скорости/очереди/повтора
local function mkChip(parent, width, kind, text, tipText, onClick)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, width, 1, 0)
    b.BackgroundColor3 = H.lighten(THEME.Panel, 0.05)
    b.BackgroundTransparency = 0.35
    b.Text = ""
    b.AutoButtonColor = false
    b.ClipsDescendants = true
    b.ZIndex = 5
    b.Parent = parent
    Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
    local st = Instance.new("UIStroke", b)
    st.Thickness = 1
    st.Transparency = 0.65
    st.Parent = b
    H.reg(st, "Color", "Accent")
    local sc = Instance.new("UIScale")
    sc.Parent = b

    local ic = kind and ICON.new(b, kind, 12, THEME.SubText) or nil
    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Text = text or ""
    lbl.TextColor3 = THEME.SubText
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.ZIndex = 6
    lbl.Parent = b
    H.reg(lbl, "TextColor3", "SubText")
    if ic then
        lbl.Size = UDim2.new(1, -12, 1, 0)
        lbl.Position = UDim2.new(0, 14, 0, 0)
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        ic.root.Position = UDim2.new(0, 11, 0.5, 0)
    else
        lbl.Size = UDim2.new(1, 0, 1, 0)
    end

    local chip = { btn = b, label = lbl, icon = ic }
    chip.SetOn = function(on)
        H.tw(b, 0.16, {
            BackgroundColor3 = on and THEME.Accent or H.lighten(THEME.Panel, 0.05),
            BackgroundTransparency = on and 0.1 or 0.35,
        })
        H.tw(b, 0.16, { BackgroundTransparency = on and 0.1 or 0.35 })
        if ic then ic.SetColor(on and Color3.fromRGB(10, 10, 14) or THEME.SubText) end
        H.tw(lbl, 0.16, { TextColor3 = on and Color3.fromRGB(10, 10, 14) or THEME.SubText })
    end
    chip.SetText = function(t) lbl.Text = t end
    b.MouseEnter:Connect(function()
        H.tw(b, 0.14, { BackgroundTransparency = 0.05 })
        H.tw(sc, 0.16, { Scale = 1.07 }, Enum.EasingStyle.Back)
        if tipText then MP.tooltip(tipText, b) end
    end)
    b.MouseLeave:Connect(function()
        H.tw(b, 0.16, { BackgroundTransparency = 0.35 })
        H.tw(sc, 0.18, { Scale = 1 })
        if tipText then MP.tooltip(nil) end
    end)
    b.MouseButton1Down:Connect(function(x, y) H.ripple(b, x, y) end)
    b.MouseButton1Click:Connect(function()
        playGuiClick()
        if onClick then onClick(chip) end
    end)
    return chip
end
MP.mkChip = mkChip

----------------------------------------------------------
-- БЛОК УПРАВЛЕНИЯ (prev / play / next) — по центру правой части
----------------------------------------------------------
local Ctl = Instance.new("Frame")
Ctl.Name = "Controls"
Ctl.Size = UDim2.new(0, 132, 0, 46)
Ctl.Position = UDim2.new(1, -PAD - 132, 0, 30)
Ctl.BackgroundTransparency = 1
Ctl.ZIndex = 4
Ctl.Parent = Full
local ctlLayout = Instance.new("UIListLayout")
ctlLayout.FillDirection = Enum.FillDirection.Horizontal
ctlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
ctlLayout.VerticalAlignment = Enum.VerticalAlignment.Center
ctlLayout.Padding = UDim.new(0, 7)
ctlLayout.Parent = Ctl

local btnPrev = mkBtn(Ctl, "prev", 34, { tip = "Предыдущий трек" })
local btnPlay = mkBtn(Ctl, "play", 46, { accent = true, tip = "Пауза / продолжить", iconScale = 0.46 })
local btnNext = mkBtn(Ctl, "next", 34, { tip = "Следующий трек" })
mpPlay = btnPlay.btn

----------------------------------------------------------
-- ЧИПЫ: громкость · повтор · скорость · очередь
----------------------------------------------------------
local ChipRow = Instance.new("Frame")
ChipRow.Name = "Chips"
ChipRow.Size = UDim2.new(0, 152, 0, 18)
ChipRow.Position = UDim2.new(1, -PAD - 152, 0, 84)
ChipRow.BackgroundTransparency = 1
ChipRow.ZIndex = 4
ChipRow.Parent = Full
local chipLayout = Instance.new("UIListLayout")
chipLayout.FillDirection = Enum.FillDirection.Horizontal
chipLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
chipLayout.VerticalAlignment = Enum.VerticalAlignment.Center
chipLayout.Padding = UDim.new(0, 5)
chipLayout.Parent = ChipRow

local chipVol = mkChip(ChipRow, 26, "volume", "", "Громкость музыки", function(chip)
    local steps = { 1, 0.75, 0.5, 0.25, 0 }
    local cur = musicVolume
    local nextV = 0
    for _, s in ipairs(steps) do
        if cur > s + 0.02 then nextV = s break end
    end
    musicVolume = nextV
    if currentSound then currentSound.Volume = musicVolume end
    if mpVolFill then mpVolFill.Size = UDim2.new(musicVolume, 0, 1, 0) end
    MP.refreshVolume()
    MP.tooltip("Громкость " .. tostring(math.floor(musicVolume * 100)) .. "%", chip.btn)
end)

local chipLoop = mkChip(ChipRow, 26, "loop", "", "Повтор текущего трека", function(chip)
    queueLoop = not queueLoop
    MP.refreshLoop()
    MP.tooltip(queueLoop and "Повтор включён" or "Повтор выключен", chip.btn)
end)
mpLoop = chipLoop

local chipSpeed = mkChip(ChipRow, 44, nil, "x1.0", "Скорость воспроизведения", function(chip)
    local steps = { 0.5, 0.75, 1, 1.25, 1.5, 2 }
    local idx = 1
    for i, s in ipairs(steps) do
        if math.abs(s - MP.speed) < 0.01 then idx = i break end
    end
    idx = idx % #steps + 1
    MP.setSpeed(steps[idx])
end)

local chipQueue = mkChip(ChipRow, 38, "note", "0", "Очередь: клик — включить следующий", function(chip)
    if #musicQueue > 0 then
        local n = table.remove(musicQueue, 1)
        refreshQueueLabel()
        MP.playNextFromQueue(n)
    end
end)

----------------------------------------------------------
-- ВСПЛЫВАЮЩИЙ РЕГУЛЯТОР ГРОМКОСТИ
----------------------------------------------------------
local volOpen = false
local volHideToken = 0

local VolPop = Instance.new("Frame")
VolPop.Name = "VolumePopover"
VolPop.Size = UDim2.new(0, INFO_W, 0, 44)
VolPop.Position = UDim2.new(0, INFO_X, 0, 28)
VolPop.BackgroundColor3 = H.darken(THEME.Panel, 0.1)
VolPop.BackgroundTransparency = 1
VolPop.BorderSizePixel = 0
VolPop.Visible = false
VolPop.ZIndex = 12
VolPop.ClipsDescendants = true
VolPop.Parent = Full
Instance.new("UICorner", VolPop).CornerRadius = UDim.new(0, 12)
local volStroke = Instance.new("UIStroke", VolPop)
volStroke.Thickness = 1
volStroke.Transparency = 0.45
volStroke.Parent = VolPop
H.reg(volStroke, "Color", "Accent")
H.regFn(function()
    VolPop.BackgroundColor3 = H.darken(THEME.Panel, 0.1)
end)

local volIcon = ICON.new(VolPop, "volume", 16, THEME.SubText)
volIcon.root.Position = UDim2.new(0, 16, 0, 15)

local volName = Instance.new("TextLabel")
volName.Size = UDim2.new(0, 80, 0, 12)
volName.Position = UDim2.new(0, 30, 0, 6)
volName.BackgroundTransparency = 1
volName.Text = "Громкость"
volName.TextColor3 = THEME.SubText
volName.Font = Enum.Font.GothamMedium
volName.TextSize = 10
volName.TextXAlignment = Enum.TextXAlignment.Left
volName.ZIndex = 13
volName.Parent = VolPop
H.reg(volName, "TextColor3", "SubText")

local volValue = Instance.new("TextLabel")
volValue.Size = UDim2.new(0, 40, 0, 12)
volValue.Position = UDim2.new(1, -46, 0, 6)
volValue.BackgroundTransparency = 1
volValue.Text = "50%"
volValue.TextColor3 = THEME.Accent
volValue.Font = Enum.Font.GothamBold
volValue.TextSize = 10
volValue.TextXAlignment = Enum.TextXAlignment.Right
volValue.ZIndex = 13
volValue.Parent = VolPop
H.reg(volValue, "TextColor3", "Accent")

local volTrack = Instance.new("Frame")
volTrack.Size = UDim2.new(1, -32, 0, 6)
volTrack.Position = UDim2.new(0, 16, 0, 26)
volTrack.BackgroundColor3 = H.lighten(THEME.Panel, 0.12)
volTrack.BorderSizePixel = 0
volTrack.ZIndex = 13
volTrack.Parent = VolPop
Instance.new("UICorner", volTrack).CornerRadius = UDim.new(1, 0)
H.reg(volTrack, "BackgroundColor3", "Panel")

local volFill = Instance.new("Frame")
volFill.Size = UDim2.new(0.5, 0, 1, 0)
volFill.BackgroundColor3 = THEME.Accent
volFill.BorderSizePixel = 0
volFill.ZIndex = 14
volFill.Parent = volTrack
Instance.new("UICorner", volFill).CornerRadius = UDim.new(1, 0)
H.reg(volFill, "BackgroundColor3", "Accent")
mpVolFill = volFill

local volKnob = Instance.new("Frame")
volKnob.AnchorPoint = Vector2.new(0.5, 0.5)
volKnob.Position = UDim2.new(1, 0, 0.5, 0)
volKnob.Size = UDim2.new(0, 12, 0, 12)
volKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
volKnob.BorderSizePixel = 0
volKnob.ZIndex = 15
volKnob.Parent = volFill
Instance.new("UICorner", volKnob).CornerRadius = UDim.new(1, 0)

local volHit = Instance.new("TextButton")
volHit.Size = UDim2.new(1, 0, 0, 22)
volHit.Position = UDim2.new(0, 0, 0, 18)
volHit.BackgroundTransparency = 1
volHit.Text = ""
volHit.ZIndex = 16
volHit.Parent = VolPop

local volDragging = false
local function volApply(pos)
    local a = math.clamp((pos.X - volTrack.AbsolutePosition.X) / math.max(volTrack.AbsoluteSize.X, 1), 0, 1)
    musicVolume = math.floor(a * 20 + 0.5) / 20
    volFill.Size = UDim2.new(musicVolume, 0, 1, 0)
    volValue.Text = tostring(math.floor(musicVolume * 100 + 0.5)) .. "%"
    if currentSound then currentSound.Volume = musicVolume end
    if mpVolFill then mpVolFill.Size = UDim2.new(musicVolume, 0, 1, 0) end
end
volHit.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        volDragging = true
        H.tw(volKnob, 0.1, { Size = UDim2.new(0, 16, 0, 16) }, Enum.EasingStyle.Back)
        volApply(input.Position)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if volDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        volApply(input.Position)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if volDragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
        volDragging = false
        H.tw(volKnob, 0.12, { Size = UDim2.new(0, 12, 0, 12) })
    end
end)

local function volShow(show)
    if show then
        volHideToken = volHideToken + 1
        if volOpen then return end
        volOpen = true
        VolPop.Visible = true
        volValue.Text = tostring(math.floor(musicVolume * 100 + 0.5)) .. "%"
        volFill.Size = UDim2.new(musicVolume, 0, 1, 0)
        H.tw(VolPop, 0.16, { BackgroundTransparency = 0.04 }, Enum.EasingStyle.Quad)
    else
        if not volOpen then return end
        volOpen = false
        volHideToken = volHideToken + 1
        local my = volHideToken
        H.tw(VolPop, 0.16, { BackgroundTransparency = 1 })
        task.delay(0.2, function()
            if my == volHideToken then VolPop.Visible = false end
        end)
    end
end
MP.volShow = volShow

-- ховер всплывающего громкоговорителя (открыть/закрыть)
local volHoverChip, volHoverPop = false, false
local function volMaybeHide()
    task.delay(0.3, function()
        if not (volHoverChip or volHoverPop) then volShow(false) end
    end)
end
chipVol.btn.MouseEnter:Connect(function() volHoverChip = true; volShow(true) end)
chipVol.btn.MouseLeave:Connect(function() volHoverChip = false; volMaybeHide() end)
VolPop.MouseEnter:Connect(function() volHoverPop = true end)
VolPop.MouseLeave:Connect(function() volHoverPop = false; volMaybeHide() end)

----------------------------------------------------------
-- ПЕРЕМОТКА: клик и перетаскивание по верхней кромке плеера
----------------------------------------------------------
local seeking = false
local function seekApply(pos, showTip)
    local a = math.clamp((pos.X - progTrack.AbsolutePosition.X) / math.max(progTrack.AbsoluteSize.X, 1), 0, 1)
    progFill.Size = UDim2.new(a, 0, 1, 0)
    local total = (currentSound and currentSound.TimeLength) or 0
    if showTip and total > 0 then
        MP.tooltip(MP.fmt(a * total) .. " / " .. MP.fmt(total), progHit)
    end
    if currentSound and total > 0 then
        currentSound.TimePosition = a * total
    end
    return a
end
MP.seekTo = seekApply

progHit.MouseEnter:Connect(function()
    H.tw(progTrack, 0.14, { Size = UDim2.new(1, -PAD * 2, 0, 7), Position = UDim2.new(0, PAD, 0, 3) })
    H.tw(progKnob, 0.14, { BackgroundTransparency = 0 }, Enum.EasingStyle.Back)
    H.tw(knobStroke, 0.14, { Transparency = 0 })
end)
progHit.MouseLeave:Connect(function()
    if seeking then return end
    H.tw(progTrack, 0.16, { Size = UDim2.new(1, -PAD * 2, 0, 4), Position = UDim2.new(0, PAD, 0, 4) })
    H.tw(progKnob, 0.16, { BackgroundTransparency = 1 })
    H.tw(knobStroke, 0.16, { Transparency = 1 })
    MP.tooltip(nil)
end)
progHit.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        seeking = true
        seekApply(input.Position, true)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if seeking and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        seekApply(input.Position, true)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if seeking and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
        seeking = false
        MP.tooltip(nil)
    end
end)
MP.isSeeking = function() return seeking end

----------------------------------------------------------
-- СТРАНИЦА «КОМПАКТНЫЙ» — пилюля на 292×56
----------------------------------------------------------
local Compact = Instance.new("Frame")
Compact.Name = "PageCompact"
Compact.Size = UDim2.new(1, 0, 1, 0)
Compact.BackgroundTransparency = 1
Compact.Visible = false
Compact.ZIndex = 2
Compact.Parent = MiniPlayer

local compactArt = mkBtn(Compact, "note", 40, { tip = "Развернуть плеер", z = 6 })
compactArt.btn.Position = UDim2.new(0, 10, 0, 8)
compactArt.btn.BackgroundColor3 = H.darken(THEME.Background, 0.25)
compactArt.btn.BackgroundTransparency = 0.1
compactArt.icon.SetColor(THEME.Accent)

local titleC = Instance.new("TextLabel")
titleC.Size = UDim2.new(0, CW - 60 - 96, 0, 16)
titleC.Position = UDim2.new(0, 58, 0, 9)
titleC.BackgroundTransparency = 1
titleC.Text = "Ничего не играет"
titleC.TextColor3 = THEME.Text
titleC.Font = Enum.Font.GothamBold
titleC.TextSize = 13
titleC.TextXAlignment = Enum.TextXAlignment.Left
titleC.TextTruncate = Enum.TextTruncate.AtEnd
titleC.ZIndex = 4
titleC.Parent = Compact
H.reg(titleC, "TextColor3", "Text")

local specC = Instance.new("Frame")
specC.Size = UDim2.new(0, CW - 60 - 96, 0, 12)
specC.Position = UDim2.new(0, 58, 0, 29)
specC.BackgroundTransparency = 1
specC.ZIndex = 4
specC.Parent = Compact
local specCLayout = Instance.new("UIListLayout")
specCLayout.FillDirection = Enum.FillDirection.Horizontal
specCLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
specCLayout.Padding = UDim.new(0, 2)
specCLayout.Parent = specC
local specCBars = {}
for i = 1, 16 do
    local b = Instance.new("Frame")
    b.Size = UDim2.new(0, 3, 0, 2)
    b.BackgroundColor3 = THEME.Accent
    b.BackgroundTransparency = 0.3
    b.BorderSizePixel = 0
    b.ZIndex = 4
    b.Parent = specC
    Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
    H.reg(b, "BackgroundColor3", "Accent")
    specCBars[i] = b
end

local btnPlayC = mkBtn(Compact, "play", 40, { accent = true, tip = "Пауза / продолжить", z = 6, iconScale = 0.44 })
btnPlayC.btn.Position = UDim2.new(1, -84, 0, 8)
local btnExpand = mkBtn(Compact, "expand", 26, { tip = "Развернуть" , z = 6})
btnExpand.btn.Position = UDim2.new(1, -36, 0, 15)

-- тонкая полоска прогресса внизу компактной «пилюли»
local progC = Instance.new("Frame")
progC.Size = UDim2.new(1, -20, 0, 2)
progC.Position = UDim2.new(0, 10, 1, -6)
progC.BackgroundColor3 = H.lighten(THEME.Panel, 0.1)
progC.BorderSizePixel = 0
progC.ZIndex = 4
progC.Parent = Compact
Instance.new("UICorner", progC).CornerRadius = UDim.new(1, 0)
H.reg(progC, "BackgroundColor3", "Panel")
local progCFill = Instance.new("Frame")
progCFill.Size = UDim2.new(0, 0, 1, 0)
progCFill.BackgroundColor3 = THEME.Accent
progCFill.BorderSizePixel = 0
progCFill.ZIndex = 5
progCFill.Parent = progC
Instance.new("UICorner", progCFill).CornerRadius = UDim.new(1, 0)
H.reg(progCFill, "BackgroundColor3", "Accent")

-- «занавес» для плавной смены режима
local veil = Instance.new("Frame")
veil.Size = UDim2.new(1, 0, 1, 0)
veil.BackgroundColor3 = H.darken(THEME.Background, 0.15)
veil.BackgroundTransparency = 1
veil.BorderSizePixel = 0
veil.Visible = false
veil.ZIndex = 20
veil.Parent = MiniPlayer
Instance.new("UICorner", veil).CornerRadius = UDim.new(0, 22)
H.regFn(function() veil.BackgroundColor3 = H.darken(THEME.Background, 0.15) end)

local function applyLayoutVisual(name)
    local fullOn = (name == "full")
    Full.Visible = fullOn
    Compact.Visible = not fullOn
end

MP.setLayout = function(name, instant)
    name = (name == "compact") and "compact" or "full"
    if MP.layout == name and not instant then return end
    MP.layout = name
    local w = (name == "full") and W or CW
    local h = (name == "full") and HG or CH
    -- не даём «уехать» за экран при смене размера
    local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
    local pos = Wrap.Position
    local nx = math.clamp(pos.X.Offset, 6, math.max(6, vp.X - w - 6))
    local ny = math.clamp(pos.Y.Offset, 6, math.max(6, vp.Y - h - 6))
    if instant then
        Wrap.Size = UDim2.new(0, w, 0, h)
        Wrap.Position = UDim2.new(pos.X.Scale, nx, pos.Y.Scale, ny)
        applyLayoutVisual(name)
        return
    end
    veil.Visible = true
    H.tw(veil, 0.09, { BackgroundTransparency = 0.05 })
    H.tw(Wrap, 0.26, {
        Size = UDim2.new(0, w, 0, h),
        Position = UDim2.new(pos.X.Scale, nx, pos.Y.Scale, ny),
    }, Enum.EasingStyle.Quint)
    task.delay(0.09, function()
        applyLayoutVisual(name)
        H.tw(veil, 0.24, { BackgroundTransparency = 1 })
        task.delay(0.26, function() veil.Visible = false end)
    end)
end
MP.toggleLayout = function()
    MP.setLayout(MP.layout == "full" and "compact" or "full")
end
titleC.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        MP.toggleLayout()
    end
end)

----------------------------------------------------------
-- ЛОГИКА: время, play/pause, скорость, повтор, очередь
----------------------------------------------------------
MP.fmt = function(t)
    t = math.max(0, math.floor(tonumber(t) or 0))
    return string.format("%d:%02d", math.floor(t / 60), t % 60)
end

-- две иконки в одной кнопке: play ↔ pause (эмодзи не нужны)
local function attachPlayIcon(btnObj, size, color)
    local pauseIc = ICON.new(btnObj.btn, "pause", math.max(12, math.floor(size * 0.50)), color)
    pauseIc.root.Visible = false
    pauseIc.root.ZIndex = btnObj.icon.root.ZIndex
    return function(playing)
        if not btnObj.btn.Parent then return end
        btnObj.icon.root.Visible = not playing
        pauseIc.root.Visible = playing
        btnObj.icon.kind = playing and "pause" or "play"
    end
end

local setPlayFull = attachPlayIcon(btnPlay, 46, Color3.fromRGB(9, 9, 13))
local setPlayCompact = attachPlayIcon(btnPlayC, 40, Color3.fromRGB(9, 9, 13))
local setPlayChip = nil

MP.setPlayingIcons = function(playing)
    setPlayFull(playing)
    setPlayCompact(playing)
end

MP.refreshVolume = function()
    if mpVolFill then mpVolFill.Size = UDim2.new(musicVolume or 0.5, 0, 1, 0) end
    if volFill then volFill.Size = UDim2.new(musicVolume or 0.5, 0, 1, 0) end
    if volValue then volValue.Text = tostring(math.floor((musicVolume or 0.5) * 100 + 0.5)) .. "%" end
    if chipVol and chipVol.icon then
        chipVol.icon.root.Name = (musicVolume or 0.5) <= 0.01 and "Icn_mute" or "Icn_volume"
    end
end

MP.refreshLoop = function()
    if chipLoop and chipLoop.SetOn then chipLoop.SetOn(queueLoop and true or false) end
    if mpLoop and mpLoop.SetOn then mpLoop.SetOn(queueLoop and true or false) end
    if nowPlayingLabel then
        local base = (nowPlayingLabel.Text or ""):gsub(" %[LOOP%]", "")
        nowPlayingLabel.Text = base .. (queueLoop and "  [LOOP]" or "")
    end
end

MP.refreshQueue = function()
    MP.queueCount = #musicQueue
    if chipQueue and chipQueue.SetText then
        chipQueue.SetText(MP.queueCount > 0 and tostring(MP.queueCount) or "0")
        if chipQueue.btn then
            chipQueue.btn.BackgroundTransparency = MP.queueCount > 0 and 0.2 or 0.55
        end
    end
end

MP.setSpeed = function(v)
    MP.speed = math.clamp(tonumber(v) or 1, 0.25, 3)
    if currentSound then pcall(function() currentSound.PlaybackSpeed = MP.speed end) end
    if chipSpeed and chipSpeed.SetText then
        chipSpeed.SetText("x" .. string.format("%.2f", MP.speed):gsub("0$", ""):gsub("%.$", ".0"))
    end
    MP.tooltip("Скорость x" .. tostring(MP.speed), chipSpeed and chipSpeed.btn)
end

MP.refreshVolume()
MP.refreshLoop()
MP.refreshQueue()

----------------------------------------------------------
-- ПЕРЕКЛЮЧАТЕЛИ КНОПОК
----------------------------------------------------------
MP.togglePlay = function()
    if not currentSound then
        if PRESET_SONGS and PRESET_SONGS[1] then
            playTrack(PRESET_SONGS[1].id, PRESET_SONGS[1].name)
        end
        return
    end
    if currentSound.IsPlaying then
        currentSound:Pause()
    else
        currentSound:Resume()
    end
    MP.setPlayingIcons(currentSound.IsPlaying and true or false)
end

btnPlay.btn.MouseButton1Click:Connect(function() MP.togglePlay() end)
btnPlayC.btn.MouseButton1Click:Connect(function() MP.togglePlay() end)
btnNext.btn.MouseButton1Click:Connect(function() playNextFromList(1) end)
btnPrev.btn.MouseButton1Click:Connect(function() playNextFromList(-1) end)
compactArt.btn.MouseButton1Click:Connect(function() MP.setLayout("full") end)
btnExpand.btn.MouseButton1Click:Connect(function() MP.setLayout("full") end)

-- клик по обложке = свернуть/развернуть
ArtSlot.MouseButton1Click:Connect(function()
    playGuiClick()
    MP.toggleLayout()
end)

----------------------------------------------------------
-- ПОКАЗ / СКРЫТИЕ
----------------------------------------------------------
local HOME_POS = UDim2.new(0.5, -W / 2, 1, -HG - 26)
MP.homePos = HOME_POS

local function baseTransparency()
    return math.clamp((MP.opacity or 0) / 100, 0, 0.85)
end

MP.show = function(show)
    if show and not miniPlayerEnabled then show = false end
    if show then
        if Wrap.Visible then
            H.tw(MiniPlayer, 0.24, { BackgroundTransparency = baseTransparency() })
            return
        end
        local target = MP.savedPos or HOME_POS
        Wrap.Position = UDim2.new(target.X.Scale, target.X.Offset, target.Y.Scale, target.Y.Offset + 22)
        Wrap.Visible = true
        MiniPlayer.BackgroundTransparency = 1
        H.tw(Wrap, 0.32, { Position = target }, Enum.EasingStyle.Back)
        H.tw(MiniPlayer, 0.32, { BackgroundTransparency = baseTransparency() })
        H.tw(mpStroke, 0.3, { Transparency = 0.45 })
    else
        if not Wrap.Visible then return end
        local p = Wrap.Position
        MP.savedPos = p
        H.tw(Wrap, 0.22, { Position = UDim2.new(p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset + 16) }, Enum.EasingStyle.Quad)
        H.tw(MiniPlayer, 0.22, { BackgroundTransparency = 1 })
        task.delay(0.24, function()
            if currentSound and currentSound.IsPlaying then return end
            Wrap.Visible = false
            Wrap.Position = MP.savedPos or HOME_POS
            MiniPlayer.BackgroundTransparency = baseTransparency()
        end)
    end
end

MP.setEnabled = function(state)
    miniPlayerEnabled = state and true or false
    MP.enabled = miniPlayerEnabled
    if not miniPlayerEnabled then
        MP.show(false)
    elseif currentSound and currentSound.Parent then
        MP.show(true)
    end
end

MP.setOpacity = function(v)
    MP.opacity = math.clamp(tonumber(v) or 0, 0, 80)
    if Wrap.Visible then
        H.tw(MiniPlayer, 0.16, { BackgroundTransparency = baseTransparency() })
    end
end

MP.setScale = function(v)
    v = tonumber(v) or 100
    MP.scale = math.clamp(v / 100, 0.55, 1.6)
    H.tw(mpScale, 0.2, { Scale = MP.scale }, Enum.EasingStyle.Back)
end

MP.resetPosition = function()
    MP.savedPos = HOME_POS
    Wrap.Position = HOME_POS
    H.tw(Wrap, 0.25, { Position = HOME_POS }, Enum.EasingStyle.Back)
end

----------------------------------------------------------
-- ПЕРЕТАСКИВАНИЕ СО «МАГНИТОМ» К КРАЯМ ЭКРАНА
----------------------------------------------------------
do
    local dragging, dragStart, startPos, moved = false, nil, nil, false
    Wrap.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            moved = false
            dragStart = input.Position
            startPos = Wrap.Position
            H.tw(mpStroke, 0.14, { Transparency = 0.05 })
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local d = input.Position - dragStart
            if math.abs(d.X) > 3 or math.abs(d.Y) > 3 then moved = true end
            if moved then
                Wrap.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end
    end)
    local function finishDrag()
        if not dragging then return end
        dragging = false
        H.tw(mpStroke, 0.18, { Transparency = 0.45 })
        local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
        local size = Wrap.AbsoluteSize
        local ap = Wrap.AbsolutePosition
        local x = math.clamp(ap.X, 6, math.max(6, vp.X - size.X - 6))
        local y = math.clamp(ap.Y, 6, math.max(6, vp.Y - size.Y - 6))
        -- магнит: если близко к краю — прилипаем
        if math.abs(x - 6) < 22 then x = 6 end
        if math.abs((vp.X - size.X - 6) - x) < 22 then x = vp.X - size.X - 6 end
        if math.abs(y - 6) < 22 then y = 6 end
        if math.abs((vp.Y - size.Y - 6) - y) < 22 then y = vp.Y - size.Y - 6 end
        MP.savedPos = UDim2.new(0, x, 0, y)
        H.tw(Wrap, 0.22, { Position = UDim2.new(0, x, 0, y) }, Enum.EasingStyle.Back)
    end
    Wrap.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            finishDrag()
        end
    end)
end

----------------------------------------------------------
-- ЗАГОЛОВОК: «исполнитель — название» разносим по строкам
----------------------------------------------------------
local BASE_SUB = "Visual Menu · мини-плеер"
local function splitLabel(label)
    if not label or label == "" then return "Ничего не играет", BASE_SUB end
    local a, b = label:match("^%s*(.-)%s*[%-—–]%s*(.+)$")
    if a and b and a ~= "" and b ~= "" then
        return b, a
    end
    return label, BASE_SUB
end

local marqueeW, marqueeOffset, marqueeActive = 0, 0, false

MP.setTitle = function(label)
    local title, artist = splitLabel(label)
    titleA.Text = title
    titleB.Text = title
    titleC.Text = title
    MP.artist = artist
    marqueeOffset = 0
    marqueeActive = false
    titleA.Position = UDim2.new(0, 0, 0, 0)
    titleB.Visible = false
end

----------------------------------------------------------
-- ВОСПРОИЗВЕДЕНИЕ
----------------------------------------------------------
playTrack = function(id, label, fromQueue)
    if not id then return end
    id = tostring(id):match("%d+") or tostring(id)
    lastTrackId, lastTrackLabel = id, label or ("ID " .. id)
    MP.lastId, MP.lastLabel = lastTrackId, lastTrackLabel
    if currentSound then
        pcall(function() currentSound:Stop() end)
        pcall(function() currentSound:Destroy() end)
        currentSound = nil
    end
    local s = Instance.new("Sound")
    s.Name = "__VisualMenuSound"
    s.SoundId = "rbxassetid://" .. id
    s.Volume = 0
    s.Looped = false
    s.PlaybackSpeed = MP.speed
    s.Parent = SoundHolder
    currentSound = s
    if PRESET_SONGS then
        for i, song in ipairs(PRESET_SONGS) do
            if tostring(song.id) == tostring(id) then currentPresetIndex = i break end
        end
    end
    pcall(function() s:Play() end)
    -- плавное появление звука (без «щелчка» на старте)
    task.spawn(function()
        local t0 = os.clock()
        while currentSound == s and s.Parent and (os.clock() - t0) < 0.65 do
            s.Volume = (musicVolume or 0.5) * ((os.clock() - t0) / 0.65)
            task.wait()
        end
        if currentSound == s and s.Parent then s.Volume = musicVolume or 0.5 end
    end)
    if nowPlayingLabel then
        nowPlayingLabel.Text = "Играет: " .. tostring(label or ("ID " .. id)) .. (queueLoop and "  [LOOP]" or "")
    end
    MP.setTitle(label or ("ID " .. tostring(id)))
    MP.setPlayingIcons(true)
    MP.show(true)
    s.Ended:Connect(function()
        if currentSound ~= s then return end
        if #musicQueue > 0 then
            local n = table.remove(musicQueue, 1)
            refreshQueueLabel()
            playTrack(n.id, n.name, true)
        elseif queueLoop and label then
            playTrack(id, label, true)
        else
            MP.setPlayingIcons(false)
        end
    end)
    -- синхронизация слайдера «Позиция %» на вкладке «Музыка»
    task.spawn(function()
        while currentSound == s and s.Parent do
            task.wait(0.25)
            if s.IsPlaying and s.TimeLength > 0 and seekSliderHandle then
                pcall(function() seekSliderHandle.Set(math.floor((s.TimePosition / s.TimeLength) * 100), false) end)
            end
        end
    end)
end

MP.playTrack = function(id, label) playTrack(id, label, false) end

enqueueTrack = function(id, name)
    if not id then return end
    table.insert(musicQueue, { id = tostring(id), name = name or ("ID " .. id) })
    refreshQueueLabel()
    MP.refreshQueue()
    if not currentSound or not currentSound.IsPlaying then
        local nxt = table.remove(musicQueue, 1)
        refreshQueueLabel()
        playTrack(nxt.id, nxt.name, true)
    else
        if chipQueue and chipQueue.btn then MP.tooltip("В очереди: " .. tostring(#musicQueue), chipQueue.btn) end
    end
end

playNextFromList = function(dir)
    dir = dir or 1
    if dir == 1 and #musicQueue > 0 then
        local n = table.remove(musicQueue, 1)
        refreshQueueLabel()
        playTrack(n.id, n.name, true)
        return
    end
    local list = PRESET_SONGS
    if #favoriteTracks > 0 and UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
        list = favoriteTracks
    end
    if not list or #list == 0 then return end
    currentPresetIndex = currentPresetIndex + dir
    if currentPresetIndex > #list then currentPresetIndex = 1 end
    if currentPresetIndex < 1 then currentPresetIndex = #list end
    local song = list[currentPresetIndex]
    if song then playTrack(song.id, song.name, true) end
end
MP.playNextFromList = playNextFromList
MP.playNextFromQueue = function(item)
    if item then playTrack(item.id, item.name, true) end
end

refreshLoopBtn = function()
    MP.refreshLoop()
end

MP.update = function(label, show)
    if label then MP.setTitle(label) end
    if show == false then MP.show(false) else MP.show(true) end
end
updateMiniPlayer = MP.update

----------------------------------------------------------
-- ЖИВОЙ ЦИКЛ: винил, спектр, прогресс, бегущая строка, «призрак»
----------------------------------------------------------
local spinSpeed = 0
local marqueeTimer = 0
local lastMouse = UserInputService:GetMouseLocation()
local lastMoveAt = os.clock()
local hoverStart = os.clock()
local ghostAlpha = 0
local phase = 0
local subCache = ""

RunService.RenderStepped:Connect(function(dt)
    if not Wrap.Visible then return end
    phase = phase + dt

    local playing = (currentSound ~= nil) and currentSound.Parent ~= nil and currentSound.IsPlaying
    local tl = (currentSound and currentSound.TimeLength) or 0
    local tp = (currentSound and currentSound.TimePosition) or 0

    -- ── винил: плавный разгон/остановка ──
    local targetSpin = playing and 46 or 0
    spinSpeed = spinSpeed + (targetSpin - spinSpeed) * math.min(1, dt * 2.2)
    if spinSpeed > 0.01 then
        Vinyl.Rotation = (Vinyl.Rotation + spinSpeed * dt) % 360
    end
    -- кольцо обложки «дышит» в такт
    local beat = 0.5 + 0.5 * math.sin(phase * 3.1)
    artPulseStroke.Transparency = playing and math.clamp(0.86 - beat * 0.32 - math.abs(math.sin(phase * 1.6)) * 0.12, 0.3, 1) or 1
    -- живые полоски на обложке
    for i, b in ipairs(liveBars) do
        local target = playing and (4 + math.abs(math.sin(phase * (2.2 + i * 0.7) + i)) * 8) or 3
        b.Size = UDim2.new(0, 3, 0, target)
    end

    -- ── спектр (полная и компактная страница) ──
    local amp = playing and 1 or 0
    if not playing then amp = 0 end
    for i, rec in ipairs(specBars) do
        local env = 1 - math.abs(i - SPEC_N / 2) / (SPEC_N * 0.62)
        local wave = 0.45 + 0.55 * math.abs(math.sin(phase * 2.1 + i * 0.42))
            * (0.6 + 0.4 * math.abs(math.sin(phase * 0.8 + i * 0.17)))
        local target = 3 + amp * (2 + 19 * env * wave)
        rec.h = rec.h + (target - rec.h) * math.min(1, dt * 9)
        if rec.h < rec.peak then rec.peak = rec.h else rec.peak = math.max(rec.h, rec.peak - dt * 18) end
        rec.obj.Size = UDim2.new(0, 3, 0, rec.h)
        rec.obj.BackgroundTransparency = math.clamp(0.5 - (rec.h / 24) * 0.42, 0.05, 0.6)
    end
    for i, b in ipairs(specCBars) do
        local env = 1 - math.abs(i - 8) / 14
        local wave = 0.45 + 0.55 * math.abs(math.sin(phase * 2.4 + i * 0.55))
        b.Size = UDim2.new(0, 3, 0, 2 + amp * (1 + 8 * env * wave))
    end

    -- ── прогресс и время ──
    if tl > 0 and not MP.isSeeking() then
        progFill.Size = UDim2.new(math.clamp(tp / tl, 0, 1), 0, 1, 0)
        progCFill.Size = UDim2.new(math.clamp(tp / tl, 0, 1), 0, 1, 0)
    end
    if tl > 0 then
        timeL.Text = MP.fmt(tp)
        timeR.Text = "-" .. MP.fmt(tl - tp)
    else
        timeL.Text = playing and "…" or "0:00"
        timeR.Text = "--:--"
    end

    -- ── подпись под названием ──
    local speedTxt = "x" .. string.format("%.2f", MP.speed):gsub("0$", ""):gsub("%.$", ".0")
    local sub = (MP.artist or BASE_SUB) .. "   ·   " .. speedTxt
    if queueLoop then sub = sub .. "   ·   повтор" end
    if tl == 0 and playing then sub = sub .. "   ·   загрузка" end
    if sub ~= subCache then
        subCache = sub
        subLabel.Text = sub
    end

    -- ── бегущая строка для длинных названий ──
    marqueeTimer = marqueeTimer + dt
    if marqueeTimer > 0.45 then
        marqueeTimer = 0
        marqueeW = titleA.TextBounds.X
        if marqueeW > titleClip.AbsoluteSize.X + 1 and not marqueeActive then
            marqueeActive = true
            titleB.Visible = true
            titleB.Position = UDim2.new(0, marqueeW + 26, 0, 0)
        elseif marqueeW <= titleClip.AbsoluteSize.X + 1 and marqueeActive then
            marqueeActive = false
            titleB.Visible = false
            titleA.Position = UDim2.new(0, 0, 0, 0)
        end
    end
    if marqueeActive then
        marqueeOffset = marqueeOffset - dt * 34
        if marqueeOffset <= -(marqueeW + 26) then marqueeOffset = 0 end
        titleA.Position = UDim2.new(0, marqueeOffset, 0, 0)
        titleB.Position = UDim2.new(0, marqueeOffset + marqueeW + 26, 0, 0)
    end

    -- ── «призрак»: в покое плеер становится полупрозрачным ──
    local m = UserInputService:GetMouseLocation()
    if (m - lastMouse).Magnitude > 1 then
        lastMouse = m
        lastMoveAt = os.clock()
    end
    local size, ap = Wrap.AbsoluteSize, Wrap.AbsolutePosition
    local inside = m.X >= ap.X - 6 and m.X <= ap.X + size.X + 6 and m.Y >= ap.Y - 6 and m.Y <= ap.Y + size.Y + 6
    local wantGhost = 0
    if MP.autoGhost ~= false and not inside and (os.clock() - lastMoveAt) > 5 then
        wantGhost = 0.26
    end
    ghostAlpha = ghostAlpha + (wantGhost - ghostAlpha) * math.min(1, dt * 2.5)
    local want = math.clamp(baseTransparency() + ghostAlpha, 0, 0.9)
    if math.abs(MiniPlayer.BackgroundTransparency - want) > 0.004 then
        MiniPlayer.BackgroundTransparency = want
    end
end)

----------------------------------------------------------
-- СТАРТОВОЕ СОСТОЯНИЕ
----------------------------------------------------------
miniPlayerEnabled = true
MP.enabled = true
MP.autoGhost = true
lastTrackId, lastTrackLabel = nil, nil
MP.setLayout("full", true)
MP.setScale(100)
MP.setPlayingIcons(false)
MP.refreshQueue()
MP.refreshLoop()
MP.refreshVolume()
MP.setTitle("Ничего не играет")
Wrap.Visible = false
-- небольшой список популярных треков (название + ID), чтобы не искать
-- ID вручную. Список собран из актуальных подборок музыкальных кодов
-- Roblox; доступность отдельных ID может со временем меняться —
-- модерация Roblox иногда снимает треки с публичного доступа.
-- ID с liroro.ru (хайп 2026). Доступность в Roblox может меняться.
PRESET_SONGS = {
    {name = "DEAD BLONDE - банкомат", id = "125634968695441"},
    {name = "сикс севне", id = "104032606171956"},
    {name = "nyan.mp3 - у батарей", id = "77425727028240"},
    {name = "sybaRU", id = "84788331299898"},
    {name = "Пошлая Молли — супермаркет 🥳", id = "71133967540274"},
    {name = "я придумала сама", id = "93306733946215"},
    {name = "МЕГАЛАДОН", id = "99171760693416"},
    {name = "Frozen Mirage!", id = "92389128443030"},
    {name = "быков прайм", id = "115192119844130"},
    {name = "коч братан голдаааа", id = "74612331354602"},
    {name = "кис ми", id = "110424628625362"},
    {name = "Issey — Институт", id = "134360278883766"},
    {name = "перфейт жопа", id = "113111351541536"},
    {name = "Пошлая Молли — Контракт 🥳", id = "118778078325644"},
    {name = "смех для слитово чилдера", id = "4857572997"},
    {name = "tidal wave", id = "5409360995"},
    {name = "соник вейв", id = "82815462229216"},
    {name = "sometimes", id = "128715303988843"},
    {name = "Sweetyx — Яхотх (г*й ремикс) 🥳", id = "119435187652473"},
    {name = "lida, mzlff — как дела", id = "94224298935204"},
    {name = "RMW — EXCLUSIVE SESSION 🥳", id = "86068879117435"},
    {name = "Сметана band - Конструкторы🥳", id = "96032143095306"},
    {name = "euro91 - ocb бумага swisher", id = "84421990482533"},
    {name = "типо слатера но метал какой то", id = "86537115046676"},
    {name = "ABSOLUTE PUSHEEN!", id = "114533680779945"},
    {name = "мабой", id = "90540700154363"},
    {name = "пи почеши", id = "74103333071744"},
    {name = "деко прайм ого", id = "126877209204546"},
    {name = "бр бр патапим", id = "111813756086336"},
    {name = "бан чел", id = "8677956081"},
    {name = "нападай нападай", id = "100266645839855"},
    {name = "заставь сиять", id = "121512888693233"},
    {name = "хапни вялого", id = "86011756377639"},
    {name = "сдохну здесь в этой адской дыре", id = "78119795400144"},
    {name = "гавк на своем", id = "291271720"},
    {name = "0                                         /                           ", id = "122689733964406"},
    {name = "арабику", id = "97749985886543"},
    {name = "отрыг", id = "8867136699"},
    {name = "deadlocked", id = "78013508267977"},
    {name = "doom pisfa", id = "1837285027"},
    {name = "LAVXX — 10ТБ", id = "82439446966816"},
    {name = "руки вверх - 18 мне уже", id = "93602974995833"},
    {name = "LIGHTPREY - целоваться", id = "114477439341745"},
    {name = "чвк фембойчик", id = "109017413804084"},
    {name = "я тебя могну", id = "98311753248330"},
    {name = "в 22 году под бучей", id = "119007878357784"},
    {name = "паровозик томас", id = "83099950014540"},
    {name = "Пошлая Молли - HABIBATI", id = "140505746064592"},
    {name = "Урал гайсин - Священная война", id = "121307800285682"},
    {name = "CUPSIZE - Ты любишь танцевать", id = "113046329605558"},
    {name = "Shuzlov - Ее парень", id = "107094208500223"},
    {name = "mia boyka - базовый минимум", id = "82854186991839"},
    {name = "бисвиди - реально кринж", id = "81534035221785"},
    {name = "теория гастера (англ, slowed)", id = "132948014514461"},
    {name = "фонк", id = "114561021003250"},
    {name = "Урал Гайсин - Она говорит отстань", id = "81771642499583"},
    {name = "ЩЕНКИ - Комплекс провинциала и синдром самозванца", id = "113179693598309"},
    {name = "Децл - Уличный боец", id = "110450861407880"},
    {name = "[Нецензурное название] (гимн твича)", id = "98349287488391"},
    {name = "Серега пират - ЧСВ", id = "121868521456313"},
    {name = "Скинтонит - Ламбада", id = "111452785905061"},
    {name = "MIGAS - Loli (перезалив, прошлый код снесли)", id = "104759646592993"},
    {name = "Комбат", id = "79458115754437"},
    {name = "банан банан дай его хамам", id = "139647937808722"},
    {name = "Пошлая молли - Спать с тобой", id = "80502931245587"},
    {name = "Пошлая молли - Твоя младшая сестренка", id = "140095226987693"},
    {name = "T.a.t.u - нас недогонят (remix)", id = "89114315756040"},
    {name = "Ноггано Дети - капитана Гранта", id = "109959542416410"},
    {name = "руди бластер (ост из 1 чаптера)", id = "82447478541506"},
    {name = "Автостопом по фазе сна - мам я умираю", id = "125972011317061"},
    {name = "англ песня хз название", id = "100994237747974"},
    {name = "грустинка", id = "74773082528950"},
    {name = "ленинград - WWW", id = "74226744091232"},
    {name = "Оnokami - Улыбашка", id = "132336450924537"},
    {name = "Шарлот - щека на щеку", id = "72949673705821"},
    {name = "Бисвиди - барабулька", id = "90243355455318"},
    {name = "7leaf - хирург", id = "120240134410668"},
    {name = "CUPSIZE - 1 Мая", id = "109300335695122"},
    {name = "Dead Blonde - банкомат", id = "118616011387647"},
    {name = "emoslut666 - мальчик балуеться с дилдо", id = "95863281919168"},
    {name = "Нежеголь - Ukraine", id = "135001518170813"},
    {name = "каждый день перед сном я играю", id = "122271677222575"},
    {name = "пожиратель галактики (hayashimo + assistentzz)", id = "110829892467524"},
    {name = "Русская название хз", id = "93619274203003"},
    {name = "сліпток - тоді", id = "95405807683656"},
    {name = "хз фан музыка вроде", id = "80155817343966"},
    {name = "Юпи - вдыхаю 2024", id = "98712357703929"},
    {name = "onda andar - сны не меняются", id = "119866814495509"},
    {name = "Ponomarev - БЕGMOTŪ", id = "112096091525362"},
    {name = "shadowraze - демка", id = "117200822251075"},
    {name = "SKALLY MILANO - вампир", id = "109966571255697"},
    {name = "xxxmanera - скажи мне кто ты?", id = "102511691772726"},
    {name = "гастер пират (без слов)", id = "85166151070095"},
    {name = "коч братан нейропесня", id = "88926785631231"},
    {name = "Маркович - гимн анонимусов", id = "83211485541232"},
    {name = "младшая сестра (assistentzz + hayashimo)", id = "109615864352274"},
    {name = "название хз русская песня и прикольная", id = "94168073968714"},
    {name = "Пошлая молли - Школа не нужна", id = "138304026539476"},
    {name = "РАША РАША (исполнитель хз)", id = "74865649597403"},
    {name = "Темный принц - Овердоз", id = "138091967635131"},
    {name = "урал гайсин - Vamp", id = "74976009791368"},
    {name = "cardinparis - целуй меня", id = "103310860835902"},
    {name = "FACE - Лабиринт", id = "109589893968883"},
    {name = "Onokami - Очки", id = "85503409844532"},
    {name = "onokami - фембойчик", id = "107823795417966"},
    {name = "Tanin jazz - Виртуальная любовь", id = "95504533309589"},
    {name = "АВТОСПОРТ - пожалуста только не домой", id = "138807886829263"},
    {name = "БИТЬМРАЗЕЙ - Люблю", id = "137041919303472"},
    {name = "дорадура", id = "98562734934611"},
    {name = "Кракен - дайте дури", id = "75739933814490"},
    {name = "монеточка - каждый раз", id = "132291486038081"},
    {name = "музыка от люблю москву но сниться лондон а текст другой кавер типо", id = "117745381911506"},
    {name = "мэйби бэйби - Аскорбинка", id = "122545502097471"},
    {name = "5mewmet - Ореол", id = "73209401620251"},
    {name = "akiko - хайсе", id = "86394181548987"},
    {name = "astralwrld - Юно гасай", id = "109788763704115"},
    {name = "bigpluggssd - ур4л стр4д43т 6ля", id = "70968364559060"},
    {name = "CUPSIZE - 17 ножевых", id = "133019184040350"},
    {name = "CUPSIZE - Вся моя жизнь говно", id = "74724741544384"},
    {name = "CUPSIZE - Детская травма", id = "71528627029716"},
    {name = "CUPSIZE - Минус плюс", id = "76623658397392"},
    {name = "CUPSIZE - Следак", id = "96988334455221"},
    {name = "CUPSIZE - Трамадол", id = "71415512817807"},
    {name = "dabbackwood - кошмары", id = "104795305072330"},
    {name = "dabbackwood - марафеты", id = "71701599455112"},
    {name = "Dead Blonde - Мальчик на девятке", id = "84302194519169"},
    {name = "emoslut666 - Наши дыхания", id = "100792213778485"},
    {name = "emoslut666 - саша", id = "74545071058841"},
    {name = "emoslut666 - я целую соль и твои белые губы", id = "105552767059831"},
    {name = "Админ абьюз", id = "87071256944666"},
    {name = "Путин виноват", id = "88623092962130"},
    {name = "нян mp3 - Хватит мне звонить", id = "109080893219522"},
    {name = "призрак крови - тень", id = "113554267921997"},
    {name = "Урал Гайсин - Хочу быть с ней и все", id = "127861605121027"},
    {name = "Электрофорез - Всё было так", id = "77163388484108"},
    {name = "mistake (грустная песня)", id = "89450896656818"},
    {name = "morgenshtern - буду твоей пальмой (ремикс)", id = "121662193173909"},
    {name = "onda andar - psp/сон", id = "123786678306233"},
    {name = "ахуеная англ песня громкая", id = "92950955480719"},
    {name = "Темный принц - Гной", id = "122302389413890"},
    {name = "Пообещай - Ярче солнца", id = "119279089120395"},
    {name = "попал (assistentzz + hashtrash + hayashimo)", id = "108799458085079"},
    {name = "потёмкин окраин - в зеркале стоит кто-то с моим лицом", id = "103988271794179"},
    {name = "Пошлая Молли - Банда Крыс", id = "71099822680682"},
    {name = "психея - 180 BPM + Mdma", id = "80260276860388"},
    {name = "психея - бойся видя", id = "94114526030852"},
    {name = "психея - вич иисус", id = "76513834392362"},
    {name = "психея - он не придет", id = "85878601053711"},
    {name = "Расстрел авгана🥳", id = "140292045493823"},
    {name = "самый лучший русский репер", id = "106453554746914"},
    {name = "Сметана band - Воха и лёха", id = "130750141872323"},
    {name = "сметана band - сєрьожа//даремно", id = "120609721177722"},
    {name = "Танцы минус - половинка себя", id = "79392387899280"},
    {name = "твое имя (hayashimo + assistentzz)", id = "103732306985076"},
    {name = "темный принц, madk1d - летник", id = "115128365718292"},
    {name = "Толя саммер - хухры мухры", id = "78474811337135"},
    {name = "ты забыла (hayashimo + assistentzz)", id = "128660363548703"},
    {name = "урал гайсин - музыка", id = "78620141986488"},
    {name = "фантомная радость (hayashimo + assistentzz)", id = "98709664747677"},
    {name = "Филипп Андрейчиков - Каникулы", id = "96882625041594"},
    {name = "фонк", id = "130193530753120"},
    {name = "фонк матадора вроде но я не уверен", id = "100472207006460"},
    {name = "фонк по дельтаруну (Do Tha Thing ремикс)", id = "99326022508368"},
    {name = "фонк про асланчика", id = "126012659606451"},
    {name = "хаски - живая вода", id = "114891575487054"},
    {name = "хз что это, входящий звонок от сьюзи", id = "90576808211422"},
    {name = "ШИПЫ - стрипсы", id = "97508544136591"},
    {name = "Электрофорез - Отношения = говно", id = "99789391812653"},
    {name = "Madk1d - рехаб", id = "129059834339060"},
    {name = "madk1d, villian - Династия", id = "99574445725663"},
    {name = "madkid - династия", id = "76350090683791"},
    {name = "mapt0v - я выберу тебя", id = "104502712965303"},
    {name = "meowkaxd - Хеллоу китти", id = "128288823531540"},
    {name = "MIGAS - Странный", id = "133215989305760"},
    {name = "migas - странный (новый код)", id = "80538175445780"},
    {name = "Mike Devil - Волга Бпан", id = "75840206489483"},
    {name = "noize mc - шлаквашаклассика", id = "83790740219671"},
    {name = "nyan mp3 - у батарей", id = "106347289774726"},
    {name = "Quest Pistols - Різні", id = "110827264234471"},
    {name = "retroyse - Мало тебя", id = "119639747686811"},
    {name = "SAUCEBABY - Никогда", id = "102715340647551"},
    {name = "Serebro - Отпусти меня", id = "120883798055025"},
    {name = "Sqwore - бардак", id = "91443955350613"},
    {name = "Starly - Перо под ребро", id = "89855164305821"},
    {name = "tagedmi x antifuckboy - НЕ ВОЛНУЕТ", id = "70493922077762"},
    {name = "tewix - бестиарий", id = "117876370756464"},
    {name = "THESCAMY - Целовал", id = "101213616026328"},
    {name = "TitaLayt - луна освещает", id = "118733992763186"},
    {name = "Tuborosho - вынос", id = "82231977748191"},
    {name = "whitek3d - на распродаже", id = "94113499374857"},
    {name = "WORSKII & DD_PUMBA - Катана на спине", id = "87774149890202"},
    {name = "yngbless - барель", id = "102966781417587"},
    {name = "YUNG FIMOZ - покажи сиськи", id = "89012503568074"},
    {name = "Yung fimoz - ты не шутер", id = "137864704879036"},
    {name = "Автостопом по фазе сна - Эхо 51", id = "70618011650404"},
    {name = "БытьРомантикомАфигено - Одинокий Дуб", id = "74087589336521"},
    {name = "Валентин Стрыкало - я стараюсь быть лучше", id = "100307621298648"},
    {name = "Валя карнавал - психушка", id = "110546895814839"},
    {name = "Во мне музыка (исполнитель хз)", id = "73542010588250"},
    {name = "ворую алкоголь", id = "104697682268011"},
    {name = "Вячеслав Кукоба - Кабанчик", id = "88468023940029"},
    {name = "гей кавер хз название", id = "124402210977484"},
    {name = "голодный - На дне страниц", id = "124492343337379"},
    {name = "Давай за...", id = "127703596334530"},
    {name = "джизус - золото", id = "104442415426946"},
    {name = "Дмитрий уткин, CMH - русская попса", id = "120691155963580"},
    {name = "Дмитрий уткин, ЮГ404 - когда тебя родили", id = "94809744900006"},
    {name = "Доктор", id = "94798586157962"},
    {name = "живу в пещере", id = "102158805050808"},
    {name = "забита голова (assistentzz + tsy + hayashimo)", id = "136221528539677"},
    {name = "зая (assistentzz + hashtrash + hayashimo)", id = "134796588696320"},
    {name = "Зенка клан", id = "91642775598734"},
    {name = "зеркало - можеЕеЕЕт xDDdd", id = "124244919307093"},
    {name = "инсейн", id = "82962142861058"},
    {name = "Качевое меню из кризиса", id = "109038010515636"},
    {name = "Кира Бурундук - Почему?", id = "104033385722205"},
    {name = "Кишлак - Дыма", id = "136713045158261"},
    {name = "Кишлак - самый лучший день", id = "98540069726905"},
    {name = "Комсомольск - глаза", id = "97730997591966"},
    {name = "Комсомольск - орфей", id = "119312434772556"},
    {name = "кракен - свет звук камера мотор", id = "124650435987038"},
    {name = "красавица - Ярче солнца", id = "101680812207531"},
    {name = "кровосток - лобстер-пицца", id = "125696183767610"},
    {name = "ленинград - камон эврибади", id = "138364105698731"},
    {name = "ленинград - пид*расы", id = "86882285194391"},
    {name = "лиззз - дайте выпилиться тут", id = "120027019817715"},
    {name = "Лови легенда целоваться", id = "132089207192439"},
    {name = "Мальян - красив и молод", id = "123201677385589"},
    {name = "мегалования", id = "116843623732343"},
    {name = "Монокини - Дотянуться до солнца", id = "107024044827850"},
    {name = "национальная гвардия - шумные и угрожающие выходки", id = "91476556029399"},
    {name = "нервы - нервы", id = "125371617396341"},
    {name = "норман грейсон - gluttony", id = "100280997559642"},
    {name = "овсянкин - red lipstick", id = "88397445974503"},
    {name = "Папин олимпос - динозаврики", id = "125209214971241"},
    {name = "Парнишка - мы умрем", id = "110295185560828"},
    {name = "полматери - нам конец!", id = "121438579015946"},
    {name = "Пошлая молли - Адская колебельня", id = "91695290692025"},
    {name = "Пошлая молли - Контракт", id = "126230411779552"},
    {name = "Пошлая молли - спать с тобой", id = "110462488906432"},
    {name = "прикольная англ песня названия не знаю", id = "84965329403305"},
    {name = "Синдром Восьмиклассника - ДЖЕТИКС", id = "93147322186431"},
    {name = "слезы ханой - верни меня", id = "129039493425803"},
    {name = "Смн - Плакса", id = "132634121120858"},
    {name = "стеклянные сны - трудности", id = "115372719230454"},
    {name = "Студия грек - на все 100", id = "125962168159130"},
    {name = "Танцы минус - Половинка", id = "93340386356413"},
    {name = "тебе нравиться", id = "130051061940185"},
    {name = "Темный принц - ihate2runa", id = "115141480584153"},
    {name = "Темный принц - solana flipper", id = "104787023663784"},
    {name = "Темный принц - вклубе", id = "80257240281702"},
    {name = "Темный принц - конструктор", id = "81744372905202"},
    {name = "Темный принц - отвратительный король", id = "123995869021318"},
    {name = "Темный принц - Папа", id = "122682054852344"},
    {name = "Урал гайсин - Капли крови", id = "100621854951891"},
    {name = "Урал гайсин - луи вивитон", id = "134724200447496"},
    {name = "Урал гайсин - музыка", id = "70756578357898"},
    {name = "Урал гайсин - не усну", id = "101851042867562"},
    {name = "Урал гайсин - Пойдем со мной", id = "122816852631473"},
    {name = "Уриил - щуточки", id = "95646815394972"},
    {name = "фруктовый 2.0", id = "102616343336371"},
    {name = "ханамантана (исполнитель хз)", id = "78851348376702"},
    {name = "Чародейка (исполнитель хз)", id = "134764433458542"},
    {name = "(без названия)", id = "103531456324945"},
    {name = "(русский трек, название неизвестно)", id = "77594611124600"},
    {name = "[Без названия] (Песни от рома факти)", id = "130369551333811"},
    {name = "[Без названия] (Песни от рома факти)", id = "81416769486159"},
    {name = "[Без названия] (Песни от рома факти)", id = "84352836702380"},
    {name = "[Без названия] (Песни от рома факти)", id = "100450483746375"},
    {name = "Anna Asti - Царица", id = "109060153913172"},
    {name = "badcurt - милион чуств", id = "74390954672876"},
    {name = "Bezdarenko - шишкин лес", id = "102257593338736"},
    {name = "blazergosicko - страшный дом", id = "113458317120616"},
    {name = "CMH - реквием 2000", id = "112279298127998"},
    {name = "CMH, Рома Жёлудь - люби меня", id = "134473581592058"},
    {name = "CUPSIZE - зппп", id = "90769566178721"},
    {name = "CUPSIZE - розовая могила", id = "96983648621036"},
    {name = "dabbackwood - шиза", id = "116065448068479"},
    {name = "DJ ZUP RAIII - Револьвер", id = "73504109987493"},
    {name = "dj zup ralii - исповедь", id = "93192520113222"},
    {name = "doominik - все уехали", id = "129489963034140"},
    {name = "doominik - несказанные слова", id = "106690584818338"},
    {name = "doominik - по разные стороны", id = "85194155251941"},
    {name = "doominik - привет родная", id = "122437163978745"},
    {name = "dope17 - любовь", id = "78629350175693"},
    {name = "dope17 - Улица дыбенко", id = "90342424611066"},
    {name = "DOROGAYABOL - NE ЕБЛАНЬ", id = "114494607079148"},
    {name = "doxxell - грусть", id = "71700851127834"},
    {name = "emoslut666 - снежок", id = "107942848302531"},
    {name = "erix - дискордикс", id = "129379512120901"},
    {name = "EVEN CUTE - ТАК ДАЖЕ ИНТЕРЕСНЕЕ", id = "114734717980865"},
    {name = "FACE - Спасательный круг", id = "104758713606954"},
    {name = "FACE - Тренды", id = "82962487323761"},
    {name = "FACE - юморист", id = "138520095935883"},
    {name = "full smena - деготь", id = "90949560194536"},
    {name = "gleb judin - жизнь", id = "135468755474468"},
    {name = "gleb judin - осень/autumn", id = "130317782075577"},
    {name = "Gothviolence - Ммагическая Щщкола", id = "70944886217929"},
    {name = "HOFMANNITA - ангелы кричат", id = "84651882916018"},
    {name = "HOFMANNITA - дождь в декабре", id = "75013545751569"},
    {name = "HOFMANNITA - Лапки", id = "113522852112328"},
    {name = "Huzzy Buzzy - согрешить", id = "108088153485575"},
    {name = "INDOZER - ну не плачь", id = "72968738061901"},
    {name = "Instasamka - я хочу", id = "122036842434614"},
    {name = "ivycraft - сожги мосты трахай мозг", id = "95919446443888"},
    {name = "jane air - актlove", id = "91305002051938"},
    {name = "jane air - пуля", id = "92601491497217"},
    {name = "jane air - х*й", id = "100665516848627"},
    {name = "Jzxdx - запрети редан", id = "93901902203805"},
    {name = "Kamz0ner - Луксмастер", id = "105229930574846"},
    {name = "KITAYKA - Солнечные Дети", id = "72890687211063"},
    {name = "KSB music - белочка", id = "92100619814818"},
    {name = "leilahimikat - припадки", id = "113763882186922"},
    {name = "Lida - набухаюсь накурюсь", id = "137609459205572"},
    {name = "Lida, CMH - хоум видео", id = "104035983857657"},
    {name = "Lida, Мэйби Бейби - ДУРКА", id = "92529668847303"},
    {name = "lightprey - Тупая сука", id = "133619622777680"},
    {name = "lightprey - фото", id = "87204128826551"},
    {name = "LXNER & WENARO - Лед", id = "120834475810154"},
    {name = "madk1d - заправка", id = "81202758026586"},
    {name = "madk1d - Мориарти", id = "102172300933284"},
    {name = "madk1d - питер паркер", id = "135056205495054"},
    {name = "madk1d - распять", id = "88011825786653"},
    {name = "madk1d - так похуй", id = "71655018556268"},
    {name = "madk1d - топлы", id = "98781354434793"},
    {name = "mapt0v - деньги", id = "87871612084824"},
    {name = "MIGAS - конфетка", id = "97253402078864"},
    {name = "morgenshtern - кадиллак", id = "85300222510224"},
    {name = "morgenshtern - новый мерин", id = "100182294127013"},
    {name = "Morgenshtern - Повод", id = "91668250502992"},
    {name = "morphy - я сфотаграфирую", id = "86506572976780"},
    {name = "nm.phobia - диагнозы!", id = "108991237175983"},
    {name = "nm.phobia - курилки!", id = "131931956939109"},
    {name = "Noize MC - Друг подруги тёлки брата", id = "122394757791715"},
    {name = "numberfriday - Сборник проблем", id = "132510149385756"},
    {name = "onda andar - интернет человек", id = "71571588898995"},
    {name = "onda andar - ночное кафе", id = "132707313924682"},
    {name = "ooes - последнее лето", id = "78613960279188"},
    {name = "otheroof - Подвальчик", id = "137629278142530"},
    {name = "Rizza - Холодное оружие", id = "94594926874219"},
    {name = "Sadsvit -  Прощавай", id = "88661020611281"},
    {name = "sadsvit - небо", id = "136543613779519"},
    {name = "sexbomba31- Интернет", id = "102176818273975"},
    {name = "skittles (исполнитель хз)", id = "124540397759758"},
    {name = "sonya abrikosova - тупое тело", id = "134193315298671"},
    {name = "sqaute - по судьбе", id = "97399631929428"},
    {name = "sqaute - покойник", id = "70839074925965"},
    {name = "sqaute - токио", id = "133549284535195"},
    {name = "t.a.t.u - нас не догонят", id = "131245885742260"},
    {name = "Thousands of Floors - тысячи этажей", id = "134208757554345"},
    {name = "whitek3d - Катюха", id = "129806116938659"},
    {name = "whyalive- Код", id = "131368788505485"},
    {name = "wtwice - Разлука", id = "134432547308279"},
    {name = "yung fimoz - богатый роблокс", id = "125332244898885"},
    {name = "zhanulka - Портреты", id = "78555785482816"},
    {name = "zombiqe - водопад", id = "80929773307571"},
    {name = "zombiqe - вышел за сигами", id = "127646884459630"},
    {name = "в 22 году под бучей - (работает не во всех плейсах)", id = "81358676926234"},
    {name = "Валентина Толкунова - Колыбельная", id = "84829612460715"},
    {name = "ВЕЧНО17 - skeet hvh", id = "114292273055479"},
    {name = "вечныйкод - кровь на рубашке", id = "76387006892399"},
    {name = "Возьми телефон детка (исполнитель хз)", id = "95213841910953"},
    {name = "временно в рехабе - она хочет любви", id = "82414585484944"},
    {name = "Гио Пика - Ад-Колыма", id = "139705278278320"},
    {name = "Главный герой - Китай", id = "135480211222222"},
    {name = "дарк бриллиант - dbs 2k16", id = "126219120603524"},
    {name = "Две тысячи ярдов - Верните в моду любовь", id = "95632852758777"},
    {name = "епідемія сучасності - новий світ", id = "93650886306547"},
    {name = "Зимой без шапки - Леха", id = "78031939905774"},
    {name = "Королевский XVII - Грустные грубы", id = "116594948156652"},
    {name = "куш,экстази, - таблетка", id = "117726782297592"},
    {name = "Лиззз - Чудной", id = "128291940309861"},
    {name = "Мarshmello - Alone", id = "71081898119547"},
    {name = "меланхолик - небесная твердь", id = "112078845197410"},
    {name = "меланхолик, lafkrat - один укус", id = "133923583494668"},
    {name = "митя фомин - всё будет хорошо", id = "131401677858693"},
    {name = "название хз", id = "118769436157640"},
    {name = "название хз", id = "86399577168141"},
    {name = "3 дня дождя - прощание", id = "94462863633197"},
    {name = "angeldustt - пока", id = "104009312561952"},
    {name = "anonymous ember - вынос", id = "127067247750124"},
    {name = "antisocialweek - Альтуха", id = "117630243093122"},
    {name = "antisocialweek - Пространство", id = "79040164117056"},
    {name = "antisocialweek - робаксы", id = "109035746456030"},
    {name = "CUPSIZE - Улыбнись", id = "109450886566540"},
    {name = "CUPSIZE - шАхАшАхА", id = "121176604894290"},
    {name = "CUPSIZE - Юра юра", id = "103953736675768"},
    {name = "dabbackwood - Хроники", id = "114927337348047"},
    {name = "dead rave - девочка 2D", id = "117440978857712"},
    {name = "desely, akiko - револьвер", id = "100978508134435"},
    {name = "dj zup ralii - Модель", id = "88462099891108"},
    {name = "dj zup ralii - Тело", id = "85587964736751"},
    {name = "dope17 - мастермайнд", id = "136555720693559"},
    {name = "erikkaspi - красная помада", id = "103450816313030"},
    {name = "euro91 - альтушки", id = "72481143884862"},
    {name = "excm - я люблю тебя xD", id = "81331022327382"},
    {name = "face - красной помадой", id = "136667663583727"},
    {name = "FORTUNA 812 - порезы на руках", id = "75939925995817"},
    {name = "HOFMANNITA - Печень И Сердце", id = "103806075951295"},
    {name = "huzzy b - катафалк", id = "122641922456852"},
    {name = "ivycraft - люблю москву но снится london", id = "73493800980449"},
    {name = "j1nar - аквакей", id = "98721047139851"},
    {name = "K0vertessence - Что тебя гложет", id = "122912380821605"},
    {name = "Kamz0ner - каждый день", id = "115886346325274"},
    {name = "Kamz0ner - Роблокс порно", id = "80406257641064"},
    {name = "Kamz0ner - Снял т:", id = "127310494243201"},
    {name = "Kamz0ner - У тебя большая с:", id = "87217496861588"},
    {name = "keijo! - Ом", id = "81914068316164"},
    {name = "Kempel - Все что хочешь", id = "100090688429692"},
    {name = "kvartira134 - альтуха", id = "80323843494942"},
    {name = "lafkrat - Мистер модератор", id = "134217021832656"},
    {name = "lafkrat - На каблуках", id = "124811463924179"},
    {name = "lafkrat - потеряпотерь", id = "136547822877241"},
    {name = "lee mcqueen - королевский XVII", id = "92497254468556"},
    {name = "leilahimikat, onda andar - нацеди мне", id = "134275781464484"},
    {name = "madk1d - Давно", id = "124248439908627"},
    {name = "нервы - дорогой человек", id = "73001636074714"},
    {name = "Света - ты не мой", id = "122607718344309"},
    {name = "слезы ханой - слезы", id = "122505713655830"},
    {name = "трейси - Я Человек", id = "87950714830613"},
    {name = "урал гайсин - блюз", id = "85536014781886"},
    {name = "биг банг", id = "89232496895165"},
    {name = "блек кнайф (битва с рокующим рыцарем)", id = "93594024579462"},
    {name = "Децл - Нью-Йорк", id = "77848956111789"},
    {name = "Залетаю в мечеть на намазик", id = "126551933715459"},
    {name = "Фрэнк - Саня", id = "136185717811055"},
    {name = "FACE - антидепресант", id = "72229959963345"},
    {name = "FACE - Калашников", id = "127336532502632"},
    {name = "mzlff - В пряничном домике", id = "131897153666227"},
    {name = "Дипинс - этажи", id = "96008872382744"},
    {name = "Кислород (исполнитель хз)", id = "122206790544975"},
    {name = "КОРЗА - Тело похудело", id = "108167433354708"},
    {name = "ksb muzic - Отчим", id = "107455931800839"},
    {name = "лбтд - кис - кис", id = "100118851780339"},
    {name = "В камине в 6 утра", id = "130721206402716"},
    {name = "Aggressive Brazilian Phonk", id = "102892380593258"},
    {name = "Meowl Phonk", id = "79891860327495"},
    {name = "NEON BAILOUT RAGE", id = "120477473525627"},
    {name = "PHONK.exe", id = "97192334657561"},
    {name = "GTA VI PHONK", id = "112576678639596"},
    {name = "Phonk Nightmare Race", id = "129127997655557"},
    {name = "Асфальт 8 (gay cover)", id = "121089950332104"},
    {name = "Phonk Assassin Mode", id = "93666258819111"},
    {name = "AURA SAIYAN DROP (Brazilian Phonk)", id = "124170748342120"},
    {name = "Happy Birthday (Brazilian Phonk)", id = "94935794334796"},
    {name = "BRAZILIAN PHONK", id = "8563581147445167"},
    {name = "Brazilian Phonk Fiesta", id = "129276852097746"},
    {name = "Montagem Panama (Bass Boosted Phonk)", id = "110817176848617"},
    {name = "BATIDA SELVAGEM (SUPER HIT PHONK)", id = "104603824839639"},
    {name = "Brazilian Phonk (новый вариант)", id = "108621585736031"},
    {name = "Mano Mama Funk Phonk Slowed", id = "102827114027930"},
    {name = "She Stares Intently", id = "136716637489655"},
    {name = "OASIS PHONK (Slowed)", id = "127096476530496"},
    {name = "OASIS PHONK", id = "120569165858495"},
    {name = "Blood on the Asphalt", id = "140439256760765"},
    {name = "PHONK CITY", id = "139694762285253"},
    {name = "Voltstorm (Overload Phonk Energy)", id = "140580823167015"},
    {name = "Chill Phonk (DAMAS)", id = "136974179670066"},
    {name = "Dress To Impress Theme (PHONK EDIT)", id = "139161205970637"},
    {name = "GTR PHONK", id = "83624433031847"},
    {name = "Mega Phonk (альт. ID)", id = "134434412138800"},
    {name = "JAZZ METAL PHONK", id = "135071730662747"},
    {name = "Move Through Fire (Dark Phonk Duet)", id = "118673350158682"},
    {name = "Desprezo (Aggressive Phonk, Slowed+Reverb)", id = "140667339171815"},
    {name = "CodeONIONIONION PHONK", id = "124114599222464"},
    {name = "THE BIG BAD WOLF PHONK (SUPER SLOWED)", id = "134108795864875"},
    {name = "Gulumulu Phonk", id = "111353716537070"},
    {name = "WHAT THE PHONK?", id = "86517694279595"},
    {name = "The Night Burns Me", id = "101098976710405"},
    {name = "Adios Amigo", id = "95697900241820"},
    {name = "No Pain No Gain", id = "129176894324463"},
    {name = "Szklane Miasto ⚠️", id = "1127916915218718842"},
    {name = "ELECTRIC PHANTOM (Phonk)", id = "103415930328599"},
    {name = "Rogue City Phonk", id = "111109407506851"},
    {name = "PHONK DRIFT", id = "72653741821355"},
    {name = "Analog Vibes (Hyper Speed Phonk)", id = "138801603792399"},
    {name = "Football Edit: Phonk Trap", id = "140504265985079"},
    {name = "PHONK HOUSE", id = "114145613542169"},
    {name = "FUNK INFERNA V2 Phonk (Deep Slowed)", id = "86375151296706"},
    {name = "Final Ride Phonk", id = "86802355429172"},
    {name = "Tripi Tropi Tropa Tripa Phonk", id = "101241740024903"},
    {name = "PHONK-BOUNDLESS UNITY", id = "134178255757517"},
    {name = "TURN IT ON PHONK – BOUNDLESS UNITY", id = "130104736468172"},
    {name = "METAMORPHOSIS", id = "15689451063"},
    {name = "Kerosene", id = "17647322226"},
    {name = "PHONKY TOWN", id = "6924714541"},
    {name = "Hardcore Drift Phonk", id = "93202214051700"},
    {name = "MONEY RAIN (Phonk Remix)", id = "8458369417"},
    {name = "Six Seven (Phonk)", id = "131732248464220"},
    {name = "67 KID PHONK", id = "125476440612900"},
    {name = "Brainrot Phonk: Tralalero Tralala", id = "138118304933431"},
    {name = "Brainrot Phonk: Divine Drop", id = "138391671909650"},
    {name = "Gigachad Phonk", id = "134366188285514"},
    {name = "Brazilian Phonk Fiesta", id = "125498129824026"},
    {name = "Brazilian Phonk (Maxlow)", id = "135862064486942"},
    {name = "MONTAGEM BÊNÇÃO slowed", id = "140245756477343"},
    {name = "Aura Defined (Sped Up)", id = "77791377297002"},
    {name = "Aura Defined (Slowed)", id = "109805678713575"},
    {name = "Hogo Funk", id = "112143944982807"},
    {name = "Bem Solto Brazil!", id = "119936139925486"},
    {name = "Brazilian Phonk 2", id = "128809761213710"},
    {name = "Brazil do Funk", id = "133498554139200"},
    {name = "Anubis! (Slowed+Reverb)", id = "123039027577735"},
    {name = "Ritual Phonk Madness", id = "115175275895587"},
    {name = "Demon Phonk Drive", id = "72793675791485"},
    {name = "Oray Bey Funk", id = "135286582331883"},
    {name = "Mehter Marşı Phonk", id = "123055942415853"},
    {name = "VIP Ultraphonk", id = "130581028268522"},
    {name = "Montagem Lovely Funk", id = "130633105268814"},
    {name = "Montagem Marsa Dala Funk", id = "73066714924090"},
    {name = "Funk do Rave 1.0", id = "137135395010424"},
    {name = "Toma Funk Phonk", id = "126291069838831"},
    {name = "FUNK FESTA", id = "103409297553965"},
    {name = "DØØM", id = "98116708399138"},
    {name = "Ela Tano (Slowed)", id = "85481949732828"},
    {name = "Sinistra", id = "15689443663"},
    {name = "Foreign", id = "109931549295353"},
    {name = "idk", id = "109339819186702"},
    {name = "Life Goes On", id = "125812293155661"},
    {name = "Spooky Skeleton", id = "194635984925376"},
    {name = "idk x2", id = "130445829252396"},
    {name = "Loud Phonk", id = "11218097495"},
    {name = "idk x3", id = "116207627988511"},
    {name = "Look At Me", id = "105938687419915"},
    {name = "All I Want Is You", id = "81067084464165"},
    {name = "Полный бак", id = "81896023465475"},
    {name = "без названия", id = "93483751210667"},
    {name = "без названия", id = "123785985180086"},
    {name = "без названия", id = "75498888713958"},
    {name = "без названия", id = "86545615838028"},
    {name = "без названия", id = "104880194210827"},
    {name = "без названия", id = "118606765652831"},
    {name = "без названия", id = "112903678064836"},
    {name = "без названия", id = "103445348511856"},
    {name = "без названия", id = "140704128008979"},
    {name = "HR - EEYUH!", id = "16190782181"},
    {name = "Ver.Normal Spoosy", id = "96203311646847"},
    {name = "Din1c X QWERRXR - infinite", id = "16190784875"},
    {name = "Blessed Mane - Death Is No More (реально крутой фанк)", id = "16831108393"},
    {name = "Roblox( роблокс удалила мне мама только в стиле фонка )", id = "123994197918972"},
    {name = "tomagi mo tão", id = "89382548135644"},
    {name = "Jumpstyle ( имба )", id = "1839246711"},
    {name = "FEMININO DO VAPO FUNK( может кому нибудь понравится )", id = "106317184644394"},
    {name = "Raging Phonk Blood", id = "80650419746306"},
    {name = "Pure Phonk Violence", id = "96461852889782"},
    {name = "Dark Phonk Damage", id = "105529482486905"},
    {name = "Phonk Killaz", id = "86179292245507"},
    {name = "Phonk of Darkness", id = "116896498238234"},
    {name = "The Final Phonk", id = "14145620056"},
    {name = "Unbreakable", id = "14145626744"},
    {name = "Blackout Drift", id = "85290495098172"},
    {name = "Monster Bass", id = "14145623658"},
    {name = "Cowbell God", id = "16190760005"},
    {name = "Down2Kill", id = "16190760285"},
    {name = "Redemption", id = "16190783774"},
    {name = "Ultima", id = "16190756998"},
    {name = "Drooly", id = "8053389869"},
    {name = "Raven Theme", id = "14145621445"},
    {name = "Assassin's Ride", id = "73326647630445"},
    {name = "Above Phonk", id = "89824897586105"},
    {name = "Reckless Drift Run", id = "83348506277910"},
    {name = "Emotional Damage", id = "14145621151"},
    {name = "Metaverse", id = "17422168798"},
    {name = "Mad Phonk Energy", id = "123636731441495"},
    {name = "Phonk't Out", id = "14145625743"},
    {name = "Stupid Remix", id = "16662833837"},
    {name = "Gabbermix", id = "18841887539"},
    {name = "Wassa", id = "17422207260"},
    {name = "Savage Slay Phonk", id = "71837666565538"},
    {name = "Uzipack", id = "18841894272"},
    {name = "Dionic", id = "15689445424"},
    {name = "AB4T", id = "17422173467"},
    {name = "Soul Crusher's Ride", id = "120296689321275"},
    {name = "Invade Groom", id = "15689453529"},
    {name = "Back & Front", id = "14145627474"},
    {name = "F-Phonk", id = "101326109963284"},
    {name = "Hellfire Highway", id = "136757074728111"},
    {name = "Bell Pepper", id = "14145626111"},
    {name = "Alanwaad", id = "17422074849"},
    {name = "Robo Phonk", id = "136932193331774"},
    {name = "No Lights", id = "14145623221"},
    {name = "Twisted Killer Flow", id = "89198968265350"},
    {name = "Pac Man Phonk", id = "120889371113999"},
    {name = "Phonk Roblox Meme", id = "135209837340816"},
    {name = "Phonk Ultra", id = "134839199346188"},
    {name = "emoslut666 - byebye", id = "85893046387173"},
    {name = "whitek3d - forever young", id = "75966181758734"},
    {name = "zxcursed - METAMORPHOSIS 3", id = "75681390470477"},
    {name = "dabbackwood - upset", id = "131380315153809"},
    {name = "shadowraze - astral step", id = "80994684728303"},
    {name = "shalawa x who was (assistentzz + hayashimo)", id = "93465875747406"},
    {name = "1tap - chanelfather", id = "123272377121190"},
    {name = "4ortake - bad girl", id = "106619031644220"},
    {name = "83HADES - 2083", id = "140077542743449"},
    {name = "akkiemi - gloomy heart", id = "113891278249795"},
    {name = "akkiemi - ha ha ha", id = "88215267302571"},
    {name = "akkiemi - revenge", id = "80205892901835"},
    {name = "cowboyclicker - thank god", id = "120716965313561"},
    {name = "doza86, whitek3d - skebob", id = "105457727775079"},
    {name = "Face - vlone", id = "109304424886028"},
    {name = "Janina - Terranova", id = "82746224492420"},
    {name = "girlfriends - computer", id = "116460661902108"},
    {name = "miseri", id = "72740886806799"},
    {name = "Roy bee - Kiss me again", id = "103210574465496"},
    {name = "Anonymous Ember - ANOTHERGREATDAY", id = "79001430118783"},
    {name = "anonymous ember - ineedweed", id = "101609901621744"},
    {name = "anonymous ember - r.i.p", id = "140644733587616"},
    {name = "auratoshi - machine", id = "94446952419211"},
    {name = "auratoshi - maniac", id = "111200700070189"},
    {name = "BATPIIICORE - KRILYA", id = "101275272363296"},
    {name = "Bayern - demon", id = "76731650388753"},
    {name = "Braxton Knight - REFRAIN", id = "73109326067403"},
    {name = "eternalshape - jab", id = "105940177331947"},
    {name = "face - rayman", id = "111068818962096"},
    {name = "FORTUNA 812 - ParisLove", id = "129776065331064"},
    {name = "FORTUNA812 - twilight", id = "75698236957416"},
    {name = "garcon maigre - popstar", id = "76111688865819"},
    {name = "Gazan - 67", id = "99458603282468"},
    {name = "Gitarakuru - dissapear completely", id = "119304880169510"},
    {name = "gitarakuru - internet l0ve", id = "91621582786398"},
    {name = "gothviolence - rip", id = "78144217660916"},
    {name = "gothviolence - u lov e me or 9mm in ur head", id = "106989884548631"},
    {name = "intelligency - august", id = "73896930664817"},
    {name = "k1llexta - centurion", id = "71388243586169"},
    {name = "LAZZY2WICE - I DONT", id = "129853400433751"},
    {name = "lungskill - kingdom", id = "72304365724232"},
    {name = "madk1d - martin rose", id = "107403388434810"},
    {name = "madk1d - sexyswag2010", id = "121806122716445"},
    {name = "mapt0v - extasy", id = "89089807557387"},
    {name = "morgue - leaveamsg", id = "102710215948261"},
    {name = "n01r - revived", id = "128032582324452"},
    {name = "Nami D - Monster", id = "118207265775122"},
    {name = "nbsplv - afterglow", id = "86194806595120"},
    {name = "Onda andar -  type london", id = "94919056430713"},
    {name = "onda andar - analog angels", id = "93135786086204"},
    {name = "onda andar - credits song", id = "138339121399174"},
    {name = "onda andar - flower touch", id = "103971829567684"},
    {name = "onda andar - GhostRunner #2016", id = "115759792703052"},
    {name = "onda andar - mor th3 stranger", id = "109831768936357"},
    {name = "onda andar - One Star #2016", id = "78594558612263"},
    {name = "onda andar - rene", id = "96398596694837"},
    {name = "onda andar - sleep mode", id = "109188671039189"},
    {name = "onda andar - stay_bottom 2016", id = "107228724339917"},
    {name = "onda andar - wata wata", id = "110524383187249"},
    {name = "onda andar, cowboyclicker - ThePolePositionClub", id = "109810165738481"},
    {name = "onda ondara - red weather lyrics", id = "127652151876898"},
    {name = "overtonight - girl im around u", id = "88605944537332"},
    {name = "pupsies - misery", id = "83626026895392"},
    {name = "saintchasergoon - drun dealuh anthem", id = "86100632962701"},
    {name = "sekairotten - sekairotten", id = "115090964978459"},
    {name = "sematary - slaughter house", id = "82238396227577"},
    {name = "shadowraze - zitraks mode", id = "80489311679383"},
    {name = "sorrow - stalk your socials", id = "129433880240869"},
    {name = "ThxSoMch - spit in my face!", id = "106869028772242"},
    {name = "TWERKNATION28 - Number", id = "89749939401064"},
    {name = "violetta sokolova - 4:30", id = "118758878350292"},
    {name = "wipovnik - boobs", id = "108791317778018"},
    {name = "youngbastard - uknowulikeit", id = "88884522232583"},
    {name = "zombiqe - hello world", id = "109978739610685"},
    {name = "5opka - 42", id = "96288455881501"},
    {name = "akkiemi - truth yandere", id = "107290461972054"},
    {name = "alone (hayashimo + assistentzz)", id = "75819587379367"},
    {name = "ANGELHARD - cool", id = "90851490275942"},
    {name = "Anonymous Ember - Chiki Chiki", id = "96995749205058"},
    {name = "anonymous ember - heeeey chiki chiki", id = "133036912585404"},
    {name = "Anonymous Ember - XXXFLOW", id = "134292715339749"},
    {name = "Anor - LO0K", id = "82943511669673"},
    {name = "apathy - LXXVEME", id = "128961712071619"},
    {name = "armor club (assistentzz + stayashi + hayashimo)", id = "83368862524188"},
    {name = "auratoshi - cryoffear🥳", id = "79269766138945"},
    {name = "auratoshi - Gothic", id = "73784685790135"},
    {name = "auratoshi - pirate🥳", id = "121959999830015"},
    {name = "backw666s - still the same", id = "78587953395357"},
    {name = "bom bom", id = "78625674962793"},
    {name = "boyboyboybee", id = "131309848078328"},
    {name = "Bye Bye - Luciid", id = "114514251919776"},
    {name = "cachalot", id = "83712066133001"},
    {name = "Caramella Girls - Caramelldansen", id = "124679619980331"},
    {name = "CMH - KILL ME MAYBE", id = "89456398844190"},
    {name = "CODE80 - Enter the Bando", id = "83521703421671"},
    {name = "comet - tha club", id = "117491407540316"},
    {name = "Cuntsniffer - Meant to Be", id = "111540468205436"},
    {name = "dabbacwood - upset", id = "112687706224369"},
    {name = "dj univxrsel - DrollXD", id = "87701480417005"},
    {name = "Doll.Ia - Kawaii Kitchen!", id = "132088862353423"},
    {name = "DooMee - de_train", id = "102294961576735"},
    {name = "drain - lieu", id = "112394690307075"},
    {name = "EUROMOLLY - erikkaspi", id = "126101048681460"},
    {name = "Evanescence - Bring Me To Life", id = "76585504240155"},
    {name = "fallen777angel - whale whisper🥳", id = "87993119850764"},
    {name = "friedbyfluoride - the love i lost", id = "7181376189"},
    {name = "Girlicious - BabyDoll", id = "127012181396114"},
    {name = "gothviolence", id = "77378724827389"},
    {name = "Hunter eyes", id = "139957878565852"},
    {name = "HWUNGLL, PHXKHXNG - gomenne", id = "89558907787765"},
    {name = "hysteric glamour - 3umph", id = "83548088590997"},
    {name = "I'm so lucky! (Nightcore)", id = "136314627320461"},
    {name = "idc - comet", id = "133578131180611"},
    {name = "idk - stange world", id = "90696964093718"},
    {name = "Its me Its Verity - Horror Skunx", id = "105000479529169"},
    {name = "jasper byrne - hotline", id = "132897951341393"},
    {name = "jasper byrne - voyager", id = "84915740846128"},
    {name = "keyoo - hashtag WkU", id = "97962396092720"},
    {name = "kill eva, encassator - psycho dreams", id = "126655268085933"},
    {name = "Kofun - Think about you", id = "78523892021062"},
    {name = "kush lovers - 20k", id = "98967055649105"},
    {name = "Lady Gaga - Paparazzi", id = "119895607903631"},
    {name = "Lida - 6:30", id = "94521112852370"},
    {name = "Lida - NEW ROCK", id = "102908730253549"},
    {name = "lost angeles (assistentzz + densmi31 + stayashi + hayashimo)", id = "76816079649870"},
    {name = "lov66 - 5ive", id = "102049389823036"},
    {name = "lungskull - me 2", id = "117549740305035"},
    {name = "lungskull - met you at the patry", id = "91623413049481"},
    {name = "m1v - you", id = "138254944947538"},
    {name = "magija - Marauder", id = "95796504549340"},
    {name = "mapt0v - suka", id = "75990499711230"},
    {name = "MIGAS - LOLI", id = "101803473648181"},
    {name = "Mosquit - cloud", id = "100460914034143"},
    {name = "nMisaki - angel", id = "15689448876"},
    {name = "nmisaki - help me", id = "15689439126"},
    {name = "nMisaki - In Cosmos", id = "15689447739"},
    {name = "nmisaki - just dance", id = "15689443891"},
    {name = "nMisaki - vibe", id = "15689450516"},
    {name = "onda andar - de_survivor", id = "84033704068924"},
    {name = "onda andar - moR th3 STranger", id = "128209547835719"},
    {name = "ONDA ANDAR - MyNokia Tool 1", id = "116530575215600"},
    {name = "onda andar - prop hunt", id = "96204616347347"},
    {name = "onda andar - type london", id = "129825758927954"},
    {name = "onda andar - warzone 2016", id = "129935260336690"},
    {name = "party like 21", id = "90407392835702"},
    {name = "PIXY - LEGACY", id = "107145145396784"},
    {name = "rebzyyx - im so fucked up", id = "103072508653269"},
    {name = "rizza - Succubus", id = "77557712602970"},
    {name = "S0N6F0RMYD34TH - STAKILLAZ", id = "104867909910584"},
    {name = "S0rrow - fake ur face", id = "81841777636658"},
    {name = "Sakyul - Hollaback Girl", id = "97435182756225"},
    {name = "subway", id = "82210016119269"},
    {name = "SUGARCRASH", id = "135907393503594"},
    {name = "thinandbruised - sexy party", id = "98762964201670"},
    {name = "Tomositomi - Alors On Danse", id = "74034501108599"},
    {name = "tuborosho - shalava", id = "82132194782275"},
    {name = "unhappy", id = "88523902860927"},
    {name = "wifiskeleton - nope your too late i already died", id = "133435792119877"},
    {name = "Wifiskeleton - whore", id = "111172787249303"},
    {name = "xxxtentacion - teeth", id = "74627763188805"},
    {name = "YNGVARR NOWICKI - love me hate me🥳", id = "127571331863105"},
    {name = "Yuke - Apathy", id = "140702323473460"}
}

H.sectionLabel(musicTab, "ПОПУЛЯРНЫЕ ТРЕКИ (ВЫБОР ИЗ СПИСКА)", 3)
local songSearchBox
local songRows = {}

local songListHolder = Instance.new("ScrollingFrame")
songListHolder.Size = UDim2.new(1, 0, 0, 220)
songListHolder.BackgroundColor3 = THEME.Panel
songListHolder.BorderSizePixel = 0
songListHolder.ScrollBarThickness = 3
songListHolder.ScrollBarImageColor3 = THEME.Accent
songListHolder.CanvasSize = UDim2.new(0, 0, 0, 0)
songListHolder.AutomaticCanvasSize = Enum.AutomaticSize.Y
songListHolder.LayoutOrder = 5
songListHolder.Parent = musicTab
Instance.new("UICorner", songListHolder).CornerRadius = UDim.new(0, 6)
local songListLayout = Instance.new("UIListLayout")
songListLayout.SortOrder = Enum.SortOrder.LayoutOrder
songListLayout.Parent = songListHolder
local songListPad = Instance.new("UIPadding")
songListPad.PaddingTop = UDim.new(0, 4)
songListPad.PaddingLeft = UDim.new(0, 4)
songListPad.PaddingRight = UDim.new(0, 4)
songListPad.Parent = songListHolder

for i, song in ipairs(PRESET_SONGS) do
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, -4, 0, 30)
    row.BackgroundColor3 = THEME.Background
    row.AutoButtonColor = false
    row.Text = ""
    row.LayoutOrder = i
    row.Parent = songListHolder
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 5)

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, -40, 1, 0)
    nameLbl.Position = UDim2.new(0, 10, 0, 0)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text = song.name
    nameLbl.TextColor3 = THEME.Text
    nameLbl.Font = Enum.Font.Gotham
    nameLbl.TextSize = 12
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
    nameLbl.Parent = row

    local playIcon = Instance.new("TextLabel")
    playIcon.Size = UDim2.new(0, 24, 1, 0)
    playIcon.Position = UDim2.new(1, -30, 0, 0)
    playIcon.BackgroundTransparency = 1
    playIcon.Text = "▶"
    playIcon.TextColor3 = THEME.Accent
    playIcon.Font = Enum.Font.GothamBold
    playIcon.TextSize = 14
    playIcon.Parent = row

    nameLbl.Size = UDim2.new(1, -70, 1, 0)

    local queueBtn = Instance.new("TextButton")
    queueBtn.Size = UDim2.new(0, 28, 0, 22)
    queueBtn.Position = UDim2.new(1, -60, 0.5, -11)
    queueBtn.BackgroundColor3 = THEME.Panel
    queueBtn.Text = "+"
    queueBtn.TextColor3 = THEME.Accent
    queueBtn.Font = Enum.Font.GothamBold
    queueBtn.TextSize = 16
    queueBtn.AutoButtonColor = false
    queueBtn.Parent = row
    Instance.new("UICorner", queueBtn).CornerRadius = UDim.new(0, 4)
    queueBtn.MouseButton1Click:Connect(function()
        enqueueTrack(song.id, song.name)
    end)

    row.MouseButton1Click:Connect(function()
        playTrack(song.id, song.name)
        TweenService:Create(row, TweenInfo.new(0.1), {BackgroundColor3 = THEME.AccentSoft}):Play()
        task.delay(0.2, function()
            if row.Parent then
                TweenService:Create(row, TweenInfo.new(0.2), {BackgroundColor3 = THEME.Background}):Play()
            end
        end)
    end)

    table.insert(songRows, {row = row, name = song.name:lower()})
end

songSearchBox = Instance.new("TextBox")
songSearchBox.Size = UDim2.new(1, 0, 0, 30)
songSearchBox.BackgroundColor3 = THEME.Panel
songSearchBox.TextColor3 = THEME.Text
songSearchBox.PlaceholderText = "Поиск по названию трека..."
songSearchBox.PlaceholderColor3 = THEME.SubText
songSearchBox.Font = Enum.Font.Gotham
songSearchBox.TextSize = 12
songSearchBox.ClearTextOnFocus = false
songSearchBox.Text = ""
songSearchBox.LayoutOrder = 3
songSearchBox.Parent = musicTab
Instance.new("UICorner", songSearchBox).CornerRadius = UDim.new(0, 6)
local songSearchPad = Instance.new("UIPadding")
songSearchPad.PaddingLeft = UDim.new(0, 8)
songSearchPad.Parent = songSearchBox

songSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local query = songSearchBox.Text:lower()
    for _, entry in ipairs(songRows) do
        entry.row.Visible = query == "" or entry.name:find(query, 1, true) ~= nil
    end
end)

nowPlayingLabel = Instance.new("TextLabel")
nowPlayingLabel.Size = UDim2.new(1, 0, 0, 18)
nowPlayingLabel.BackgroundTransparency = 1
nowPlayingLabel.Text = "Ничего не играет"
nowPlayingLabel.TextColor3 = THEME.SubText
nowPlayingLabel.Font = Enum.Font.GothamMedium
nowPlayingLabel.TextSize = 12
nowPlayingLabel.TextXAlignment = Enum.TextXAlignment.Left
nowPlayingLabel.LayoutOrder = 6
nowPlayingLabel.Parent = musicTab

H.sectionLabel(musicTab, "СВОЙ ID ТРЕКА (ЕСЛИ НЕ НАШЛИ В СПИСКЕ)", 7)
H.createInputRow(musicTab, "Например: 1837850725", "Играть", 8, function(text)
    local id = text:match("%d+")
    playTrack(id, "ID " .. tostring(id))
end)

H.createButtonRow(musicTab, {
    { text = "Пауза/Плей", callback = function()
        if not currentSound then return end
        if currentSound.IsPlaying then
            currentSound:Pause()
        else
            currentSound:Resume()
        end
    end },
    { text = "Стоп", callback = function()
        if currentSound then
            currentSound:Stop()
            currentSound:Destroy()
            currentSound = nil
            nowPlayingLabel.Text = "Ничего не играет"
            updateMiniPlayer(nil, false)
        end
    end },
    { text = "След. в очереди", callback = function()
        if #musicQueue > 0 then
            local next = table.remove(musicQueue, 1)
            refreshQueueLabel()
            playTrack(next.id, next.name, true)
        end
    end },
}, 9)

H.sectionLabel(musicTab, "ПЕРЕМОТКА", 10)
seekSliderHandle = H.createSlider(musicTab, "Позиция %", 0, 100, 0, 11, function(v)
    if currentSound and currentSound.TimeLength > 0 then
        currentSound.TimePosition = (v / 100) * currentSound.TimeLength
    end
end)
H.createButtonRow(musicTab, {
    { text = "-10 сек", callback = function()
        if currentSound then
            currentSound.TimePosition = math.max(0, currentSound.TimePosition - 10)
        end
    end },
    { text = "+10 сек", callback = function()
        if currentSound and currentSound.TimeLength > 0 then
            currentSound.TimePosition = math.min(currentSound.TimeLength - 0.1, currentSound.TimePosition + 10)
        end
    end },
}, 12)

H.createSlider(musicTab, "Громкость", 0, 100, 50, 13, function(v)
    if currentSound then currentSound.Volume = v / 100 end
end)
H.createSlider(musicTab, "Скорость воспроизведения x100", 50, 200, 100, 14, function(v)
    if currentSound then currentSound.PlaybackSpeed = v / 100 end
end)

H.sectionLabel(musicTab, "ОЧЕРЕДЬ", 15)
queueListLabel = Instance.new("TextLabel")
queueListLabel.Size = UDim2.new(1, 0, 0, 36)
queueListLabel.BackgroundTransparency = 1
queueListLabel.Text = "Очередь пуста"
queueListLabel.TextColor3 = THEME.SubText
queueListLabel.Font = Enum.Font.Gotham
queueListLabel.TextSize = 11
queueListLabel.TextWrapped = true
queueListLabel.TextXAlignment = Enum.TextXAlignment.Left
queueListLabel.TextYAlignment = Enum.TextYAlignment.Top
queueListLabel.LayoutOrder = 16
queueListLabel.Parent = musicTab

H.createButtonRow(musicTab, {
    { text = "Очистить очередь", callback = function()
        musicQueue = {}
        refreshQueueLabel()
    end },
    { text = "Loop трека", callback = function()
        queueLoop = not queueLoop
        if nowPlayingLabel then
            nowPlayingLabel.Text = (nowPlayingLabel.Text:gsub(" %[LOOP%]", "") or "") .. (queueLoop and " [LOOP]" or "")
        end
        refreshLoopBtn()
    end },
}, 17)

H.sectionLabel(musicTab, "РАДИО-ПРЕСЕТЫ", 18)
H.createButtonRow(musicTab, {
    { text = "Фонк", callback = function()
        local list = {}
        for _, s in ipairs(PRESET_SONGS) do
            if s.name:lower():find("phonk") or s.name:lower():find("фонк") or s.name:lower():find("funk") then
                table.insert(list, s)
            end
        end
        if #list == 0 then
            -- fallback ids from list that are phonk-like
            for _, s in ipairs(PRESET_SONGS) do
                if s.name:find("Phonk") or s.name:find("Ultraphonk") or s.name:find("Brazil") then
                    table.insert(list, s)
                end
            end
        end
        musicQueue = {}
        for _, s in ipairs(list) do table.insert(musicQueue, {id = s.id, name = s.name}) end
        refreshQueueLabel()
        if #musicQueue > 0 then
            local n = table.remove(musicQueue, 1)
            refreshQueueLabel()
            playTrack(n.id, n.name, true)
        end
    end },
    { text = "Мем", callback = function()
        local keys = {"Tacos", "Crab", "Кабанчик", "Roblox", "мама", "хи хи", "Dolphin", "Скример"}
        musicQueue = {}
        for _, s in ipairs(PRESET_SONGS) do
            local nl = s.name:lower()
            for _, k in ipairs(keys) do
                if nl:find(k:lower(), 1, true) then
                    table.insert(musicQueue, {id = s.id, name = s.name})
                    break
                end
            end
        end
        refreshQueueLabel()
        if #musicQueue > 0 then
            local n = table.remove(musicQueue, 1)
            refreshQueueLabel()
            playTrack(n.id, n.name, true)
        end
    end },
    { text = "Chill", callback = function()
        local keys = {"Falling", "Circulation", "Лето", "Пока", "дыхания", "Miss You", "Life Goes"}
        musicQueue = {}
        for _, s in ipairs(PRESET_SONGS) do
            for _, k in ipairs(keys) do
                if s.name:find(k, 1, true) then
                    table.insert(musicQueue, {id = s.id, name = s.name})
                    break
                end
            end
        end
        refreshQueueLabel()
        if #musicQueue > 0 then
            local n = table.remove(musicQueue, 1)
            refreshQueueLabel()
            playTrack(n.id, n.name, true)
        end
    end },
}, 19)


H.sectionLabel(musicTab, "МИНИ-ПЛЕЕР", 20)
H.createToggleRow(musicTab, "Мини-плеер на экране", 21, function(state)
    miniPlayerEnabled = state
    if H.mp and H.mp.setEnabled then H.mp.setEnabled(state) end
end, true)
H.createButtonRow(musicTab, {
    { text = "Свернуть / развернуть", callback = function()
        if H.mp and H.mp.toggleLayout then H.mp.toggleLayout() end
    end },
    { text = "Сброс позиции", callback = function()
        if H.mp and H.mp.resetPosition then H.mp.resetPosition() end
    end },
}, 22)
H.createSlider(musicTab, "Прозрачность плеера", 0, 80, 5, 23, function(v)
    if H.mp and H.mp.setOpacity then H.mp.setOpacity(v) end
end)
H.createSlider(musicTab, "Размер плеера %", 70, 140, 100, 24, function(v)
    -- Раньше тут менялся Size всего окна плеера: при уменьшении кнопки
    -- наслаивались друг на друга («слипались»). Теперь масштабируется
    -- UIScale — вся геометрия сжимается пропорционально и никогда не
    -- пересекается ни на 70%, ни на 140%.
    if H.mp and H.mp.setScale then H.mp.setScale(v) end
end)
H.sectionLabel(musicTab, "ПОВЕДЕНИЕ ПЛЕЕРА", 25)
H.createToggleRow(musicTab, "Автоскрытие в простое (становится прозрачным)", 26, function(state)
    if H.mp then H.mp.autoGhost = state and true or false end
end, true)

H.sectionLabel(musicTab, "ИЗБРАННЫЕ ТРЕКИ", 25)
local favLabel = Instance.new("TextLabel")
favLabel.Size = UDim2.new(1, 0, 0, 32)
favLabel.BackgroundTransparency = 1
favLabel.Text = "Избранное пусто"
favLabel.TextColor3 = THEME.SubText
favLabel.Font = Enum.Font.Gotham
favLabel.TextSize = 11
favLabel.TextWrapped = true
favLabel.TextXAlignment = Enum.TextXAlignment.Left
favLabel.LayoutOrder = 26
favLabel.Parent = musicTab

refreshFavLabel = function()
    if #favoriteTracks == 0 then
        favLabel.Text = "Избранное пусто — играй трек и нажми «В избранное»"
        return
    end
    local parts = {}
    for i, s in ipairs(favoriteTracks) do
        table.insert(parts, i .. ". " .. (s.name or s.id))
    end
    favLabel.Text = table.concat(parts, " · ")
end

H.createButtonRow(musicTab, {
    { text = "В избранное (текущий)", callback = function()
        if not lastTrackId then return end
        for _, s in ipairs(favoriteTracks) do
            if tostring(s.id) == tostring(lastTrackId) then return end
        end
        table.insert(favoriteTracks, {id = tostring(lastTrackId), name = lastTrackLabel or lastTrackId})
        refreshFavLabel()
    end },
    { text = "Играть избранное", callback = function()
        if #favoriteTracks > 0 then
            currentPresetIndex = 1
            playTrack(favoriteTracks[1].id, favoriteTracks[1].name)
        end
    end },
    { text = "Очистить избранное", callback = function()
        favoriteTracks = {}
        refreshFavLabel()
    end },
}, 27)


local musicNote = Instance.new("TextLabel")
musicNote.Size = UDim2.new(1, 0, 0, 34)
musicNote.BackgroundTransparency = 1
musicNote.TextWrapped = true
musicNote.Text = "Звук слышен только вам (звучит из вашего PlayerGui). Доступность треков из каталога Roblox может со временем меняться."
musicNote.TextColor3 = THEME.SubText
musicNote.Font = Enum.Font.Gotham
musicNote.TextSize = 11
musicNote.TextXAlignment = Enum.TextXAlignment.Left
musicNote.LayoutOrder = 12
musicNote.Parent = musicTab

----------------------------------------------------------
end

H.__build_Camera = function()
-- ВКЛАДКА: КАМЕРА
----------------------------------------------------------
H.createTabButton("Камера", 12, CATEGORY_COLORS.Player)
camTab = H.createTabFrame("Камера")

H.sectionLabel(camTab, "ПОЛЕ ЗРЕНИЯ (FOV)", 1)
H.fov = H.createSlider(camTab, "FOV", 30, 120, 70, 2, function(v)
    camera.FieldOfView = v
end)

H.sectionLabel(camTab, "ДИСТАНЦИЯ КАМЕРЫ", 3)
H.camDist = H.createSlider(camTab, "Макс. дистанция от персонажа", 10, 500, 128, 4, function(v)
    pcall(function() player.CameraMaxZoomDistance = v end)
end)

H.firstPerson = H.createToggleRow(camTab, "Вид от первого лица (заблокировать зум)", 5, function(state)
    pcall(function()
        player.CameraMinZoomDistance = 0.5
        player.CameraMaxZoomDistance = state and 0.5 or 128
    end)
end)

H.sectionLabel(camTab, "ПРЕСЕТЫ FOV", 6)
H.createButtonRow(camTab, {
    { text = "Обычный 70", callback = function() if H.fov then H.fov.Set(70) end end },
    { text = "Широкий 90", callback = function() if H.fov then H.fov.Set(90) end end },
    { text = "Кино 50", callback = function() if H.fov then H.fov.Set(50) end end },
    { text = "Рыбий 120", callback = function() if H.fov then H.fov.Set(120) end end },
}, 7)

H.sectionLabel(camTab, "ТРЯСКА КАМЕРЫ", 8)
local shakeConn = nil
H.createToggleRow(camTab, "Лёгкая тряска камеры", 9, function(state)
    if shakeConn then shakeConn:Disconnect(); shakeConn = nil end
    if not state then return end
    shakeConn = RunService.RenderStepped:Connect(function()
        if camera then
            camera.CFrame = camera.CFrame * CFrame.new(
                (math.random() - 0.5) * 0.04,
                (math.random() - 0.5) * 0.04,
                0
            )
        end
    end)
end)

H.sectionLabel(camTab, "НАКЛОН ПРИ СТРЕЙФЕ (TILT)", 10)
local tiltConn = nil
local tiltAmount = 0.08
H.createToggleRow(camTab, "Наклон камеры при стрейфе", 11, function(state)
    if tiltConn then tiltConn:Disconnect(); tiltConn = nil end
    if not state then return end
    local currentTilt = 0
    tiltConn = RunService.RenderStepped:Connect(function(dt)
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if not (hum and camera) then return end
        local move = hum.MoveDirection
        local right = camera.CFrame.RightVector
        local side = move:Dot(right)
        local target = -side * tiltAmount
        currentTilt = currentTilt + (target - currentTilt) * math.min(1, dt * 8)
        camera.CFrame = camera.CFrame * CFrame.Angles(0, 0, currentTilt)
    end)
end)
H.createSlider(camTab, "Сила наклона x100", 2, 20, 8, 12, function(v)
    tiltAmount = v / 100
end)


----------------------------------------------------------
-- ВКЛАДКА: НАСТРОЙКИ GUI
----------------------------------------------------------
end

----------------------------------------------------------
-- ЖИВОЙ ФОН GUI + СЛОЙ ЭФФЕКТОВ
-- 11 режимов фона (градиент, аврора, космос, сетка, волны,
-- матрица, искры, полосы, картинка, стекло), палитры, скорость,
-- плотность, затемнение и «украшения» поверх окна.
-- Слои лежат внутри MainFrame и НЕ перехватывают клики (Active/Selectable = false).
----------------------------------------------------------
H.bgNames = {
    "Нет", "Градиент", "Аврора", "Космос", "Сетка", "Волны",
    "Матрица", "Искры", "Полосы", "Картинка", "Стекло",
}
H.bgPalettes = {
    { name = "Акцент", themeAccent = true },
    { name = "Космос",  c1 = Color3.fromRGB(8, 6, 34),  c2 = Color3.fromRGB(74, 32, 158), c3 = Color3.fromRGB(0, 190, 255) },
    { name = "Закат",   c1 = Color3.fromRGB(38, 6, 32), c2 = Color3.fromRGB(198, 50, 92), c3 = Color3.fromRGB(255, 176, 84) },
    { name = "Лёд",     c1 = Color3.fromRGB(4, 18, 30), c2 = Color3.fromRGB(26, 106, 152), c3 = Color3.fromRGB(150, 240, 255) },
    { name = "Золото",  c1 = Color3.fromRGB(24, 16, 4), c2 = Color3.fromRGB(150, 102, 22), c3 = Color3.fromRGB(255, 214, 130) },
    { name = "Кровь",   c1 = Color3.fromRGB(22, 2, 6),  c2 = Color3.fromRGB(146, 14, 30),  c3 = Color3.fromRGB(255, 92, 92) },
    { name = "Матрица", c1 = Color3.fromRGB(2, 12, 6),  c2 = Color3.fromRGB(10, 96, 40),  c3 = Color3.fromRGB(120, 255, 150) },
    { name = "Моно",    c1 = Color3.fromRGB(8, 8, 10),  c2 = Color3.fromRGB(54, 56, 64),   c3 = Color3.fromRGB(214, 218, 228) },
    { name = "Роза",    c1 = Color3.fromRGB(30, 8, 24), c2 = Color3.fromRGB(180, 60, 140), c3 = Color3.fromRGB(255, 190, 230) },
}
local BG_MATRIX_CHARS = "01アイウエオカキクケコｱｲｳABCDEFXYZ<>/\\|+*·"
local bgModeIndex, bgPaletteIndex = 2, 1
local bgImageId = "rbxasset://textures/ui/GuiImagePlaceholder.png"
local bgEnabled, bgFX = true, true
local bgPulse = true
local bgSpeed, bgBright, bgDim = 100, 100, 30
local bgT = 0
local bgEls, bgUpdaters, bgPaint = {}, {}, {}

local function bgPal()
    local p = H.bgPalettes[bgPaletteIndex] or H.bgPalettes[1]
    if p.themeAccent then
        local a = THEME.Accent
        return { name = p.name, c1 = H.darken(a, 0.86), c2 = H.darken(a, 0.45), c3 = H.lighten(a, 0.35) }
    end
    return p
end

local function paint(o, base, prop)
    table.insert(bgPaint, { o = o, p = prop or "BackgroundTransparency", b = 1 - (1 - (base or 0.2)) * (bgBright / 100) })
end

local function clearEls()
    for _, e in ipairs(bgEls) do
        if e and e.Destroy then pcall(function() e:Destroy() end) end
    end
    bgEls, bgUpdaters, bgPaint = {}, {}, {}
end

local function ring(parent, size, color, base, z, corner)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(0, size, 0, size)
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.BackgroundColor3 = color
    f.BorderSizePixel = 0
    f.ZIndex = z or 0
    f.Active = false
    f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(corner or 1, 0)
    paint(f, base, "BackgroundTransparency")
    table.insert(bgEls, f)
    return f
end

-- «мягкий» шар: 4 вложенных круга разной прозрачности = имитация радиального размытия
local function blob(parent, size, color, strength, z)
    local holder = Instance.new("Frame")
    holder.BackgroundTransparency = 1
    holder.Size = UDim2.new(0, size, 0, size)
    holder.AnchorPoint = Vector2.new(0.5, 0.5)
    holder.ZIndex = z or 0
    holder.Active = false
    holder.Parent = parent
    table.insert(bgEls, holder)
    local steps = 4
    for i = 1, steps do
        local k = i / steps
        local d = size * (0.45 + 0.55 * k)
        -- внешние кольца почти прозрачные, центр ярче — получается мягкий ореол
        local base = 1 - (k ^ 1.7) * strength
        local o = ring(holder, d, color, base, (z or 0), 1)
        o.Position = UDim2.new(0.5, 0, 0.5, 0)
    end
    return holder
end

local function gradFill(parent, c1, c2, rot, z, t1, t2)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 1, 0)
    f.BackgroundColor3 = c1
    f.BorderSizePixel = 0
    f.ZIndex = z or 0
    f.Active = false
    f.Parent = parent
    local g = Instance.new("UIGradient")
    g.Rotation = rot or 90
    g.Color = ColorSequence.new(c1, c2)
    g.Transparency = NumberSequence.new(t1 or 0, t2 or 0)
    g.Parent = f
    table.insert(bgEls, f)
    return f, g
end

H.__build_BG = function()
    if H.bgLayer and H.bgLayer.Parent then return end

    local layer = Instance.new("Frame")
    layer.Name = "VMBgLayer"
    layer.Size = UDim2.new(1, 0, 1, 0)
    layer.BackgroundColor3 = Color3.fromRGB(6, 7, 12)
    layer.BorderSizePixel = 0
    layer.ClipsDescendants = true
    layer.ZIndex = 0
    layer.Active = false
    layer.Parent = MainFrame
    Instance.new("UICorner", layer).CornerRadius = UDim.new(0, 12)
    H.bgLayer = layer

    local base = Instance.new("Frame")
    base.Name = "Base"
    base.Size = UDim2.new(1, 0, 1, 0)
    base.BackgroundColor3 = Color3.fromRGB(6, 7, 12)
    base.BorderSizePixel = 0
    base.ZIndex = 0
    base.Active = false
    base.Parent = layer
    local baseG = Instance.new("UIGradient")
    baseG.Rotation = 90
    baseG.Parent = base

    local host = Instance.new("Frame")
    host.Name = "Host"
    host.Size = UDim2.new(1, 0, 1, 0)
    host.BackgroundTransparency = 1
    host.ZIndex = 0
    host.Active = false
    host.Parent = layer
    H.bgHost = host

    local dim = Instance.new("Frame")
    dim.Name = "Dim"
    dim.Size = UDim2.new(1, 0, 1, 0)
    dim.BackgroundColor3 = Color3.new(0, 0, 0)
    dim.BackgroundTransparency = 1 - bgDim / 100
    dim.BorderSizePixel = 0
    dim.ZIndex = 1
    dim.Active = false
    dim.Parent = layer
    H.bgDimLayer = dim

    local function refreshBase()
        local p = bgPal()
        baseG.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, p.c1),
            ColorSequenceKeypoint.new(0.5, p.c2),
            ColorSequenceKeypoint.new(1, p.c1),
        })
        layer.BackgroundColor3 = p.c1
    end
    H.bgRefreshBase = refreshBase
    refreshBase()
    H.regFn(refreshBase)

    ----------------------------------------------------------
    -- РЕЖИМЫ ФОНА
    ----------------------------------------------------------
    local function buildGrid(host_, p)
        local v = {}
        for i = 0, 13 do
            local l = Instance.new("Frame")
            l.Size = UDim2.new(0, 1, 1, 0)
            l.Position = UDim2.new(i / 13, 0, 0, 0)
            l.BackgroundColor3 = p.c3
            l.BorderSizePixel = 0
            l.ZIndex = 0
            l.Active = false
            l.Parent = host_
            paint(l, 0.9, "BackgroundTransparency")
            table.insert(bgEls, l)
            v[#v + 1] = l
        end
        for i = 0, 8 do
            local l = Instance.new("Frame")
            l.Size = UDim2.new(1, 0, 0, 1)
            l.Position = UDim2.new(0, 0, i / 8, 0)
            l.BackgroundColor3 = p.c3
            l.BorderSizePixel = 0
            l.ZIndex = 0
            l.Active = false
            l.Parent = host_
            paint(l, 0.9, "BackgroundTransparency")
            table.insert(bgEls, l)
            v[#v + 1] = l
        end
        table.insert(bgUpdaters, function(dt)
            local off = (bgT * bgSpeed / 100 * 14) % 46
            for i, l in ipairs(v) do
                if i <= 14 then
                    l.Position = UDim2.new(i / 13, off * 2, 0, 0)
                else
                    l.Position = UDim2.new(0, 0, (i - 15) / 8, off)
                end
            end
        end)
    end

    local function buildStars(host_, p)
        local stars = {}
        for i = 1, 68 do
            local depth = (i % 3) + 1
            local s = ring(host_, depth, p.c3, 0.25 + depth * 0.12, 0)
            s.AnchorPoint = Vector2.new(0.5, 0.5)
            s.Position = UDim2.new(math.random(), 0, math.random(), 0)
            s.BackgroundTransparency = 0.2
            stars[#stars + 1] = { o = s, ph = math.random() * 6.28, sp = 0.2 + depth * 0.35, dx = (math.random() - 0.5) * 0.02 }
        end
        local neb = blob(host_, 460, p.c2, 0.5, 0)
        neb.Position = UDim2.new(0.7, 0, 0.25, 0)
        local neb2 = blob(host_, 320, p.c3, 0.32, 0)
        neb2.Position = UDim2.new(0.2, 0, 0.8, 0)
        table.insert(bgUpdaters, function(dt)
            local k = 1
            for _, st in ipairs(stars) do
                st.ph = st.ph + dt * st.sp * k
                local tw = math.clamp(0.45 + 0.5 * math.sin(st.ph), 0.05, 0.97)
                st.o.BackgroundTransparency = 1 - (1 - tw) * (bgBright / 100)
                st.o.Position = UDim2.new(st.o.Position.X.Scale + st.dx * dt * k * 0.35, 0, st.o.Position.Y.Scale, 0)
            end
            neb.Position = UDim2.new(0.7 + 0.06 * math.sin(bgT * 0.12 * k), 0, 0.25 + 0.05 * math.cos(bgT * 0.09 * k), 0)
            neb2.Position = UDim2.new(0.2 + 0.05 * math.cos(bgT * 0.1 * k), 0, 0.8 + 0.04 * math.sin(bgT * 0.13 * k), 0)
        end)
    end

    local function buildAurora(host_, p)
        local blobs = {}
        local cols = { p.c3, p.c2, p.c1, p.c3 }
        for i = 1, 4 do
            local b = blob(host_, 380 - i * 40, H.lighten(cols[i], 0.1), 0.55, 0)
            b.Position = UDim2.new(0.15 + i * 0.22, 0, 0.2 + (i % 2) * 0.5, 0)
            blobs[#blobs + 1] = { o = b, i = i }
        end
        local veil = gradFill(host_, p.c1, p.c3, 75, 0, 0.55, 0.9)
        table.insert(bgUpdaters, function(dt)
            local k = 1
            for _, b in ipairs(blobs) do
                local sp = 0.08 * b.i
                b.o.Position = UDim2.new(
                    0.15 + b.i * 0.22 + 0.12 * math.sin(bgT * sp * k + b.i),
                    0,
                    0.25 + (b.i % 2) * 0.45 + 0.14 * math.cos(bgT * sp * 0.8 * k + b.i * 1.7),
                    0)
            end
            veil.UIGradient.Rotation = 75 + 25 * math.sin(bgT * 0.07 * k)
        end)
    end

    local function buildWaves(host_, p)
        local waves = {}
        for i = 1, 7 do
            local w = Instance.new("Frame")
            w.Size = UDim2.new(1.4, 0, 0, 46 + i * 6)
            w.Position = UDim2.new(-0.2, 0, 0.1 + i * 0.12, 0)
            w.Rotation = -6 + i
            w.BackgroundColor3 = p.c3
            w.BorderSizePixel = 0
            w.ZIndex = 0
            w.Active = false
            w.Parent = host_
            Instance.new("UICorner", w).CornerRadius = UDim.new(1, 0)
            local g = Instance.new("UIGradient")
            g.Rotation = 0
            g.Color = ColorSequence.new(p.c2, p.c3)
            g.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(0.5, 0.72),
                NumberSequenceKeypoint.new(1, 1),
            })
            g.Parent = w
            table.insert(bgEls, w)
            waves[#waves + 1] = { o = w, g = g, i = i, ph = i * 1.3 }
        end
        table.insert(bgUpdaters, function(dt)
            local k = 1
            for _, w in ipairs(waves) do
                w.ph = w.ph + dt * (0.5 + w.i * 0.12) * k
                w.o.Position = UDim2.new(-0.2 + 0.1 * math.sin(w.ph), 0, 0.1 + w.i * 0.12 + 0.05 * math.sin(w.ph * 0.8), 0)
                w.g.Offset = Vector2.new(math.sin(w.ph * 0.6) * 0.2, 0)
            end
        end)
    end

    local function buildMatrix(host_, p)
        local cols, CH, ROWS = 15, 7, 7
        local set = {}
        for c = 1, cols do
            local col = Instance.new("Frame")
            col.BackgroundTransparency = 1
            col.Size = UDim2.new(0, 16, 1, 0)
            col.Position = UDim2.new((c - 1) / cols, 0, 0, 0)
            col.ZIndex = 0
            col.Active = false
            col.Parent = host_
            table.insert(bgEls, col)
            local labels = {}
            for r = 1, ROWS do
                local t = Instance.new("TextLabel")
                t.Size = UDim2.new(1, 0, 0, 16)
                t.BackgroundTransparency = 1
                t.Font = Enum.Font.Code
                t.TextSize = 13
                t.TextColor3 = p.c3
                t.TextXAlignment = Enum.TextXAlignment.Center
                t.Text = string.sub(BG_MATRIX_CHARS, math.random(1, #BG_MATRIX_CHARS), math.random(1, #BG_MATRIX_CHARS))
                t.ZIndex = 0
                t.Parent = col
                paint(t, 0.35, "TextTransparency")
                table.insert(bgEls, t)
                labels[#labels + 1] = t
            end
            set[#set + 1] = { col = col, labels = labels, y = math.random() * -600, sp = 40 + math.random() * 90 }
        end
        local swap = 0
        table.insert(bgUpdaters, function(dt)
            local k = 1
            swap = swap + dt
            local doSwap = swap > 0.09
            if doSwap then swap = 0 end
            for _, c in ipairs(set) do
                c.y = c.y + c.sp * dt * k
                if c.y > host_.AbsoluteSize.Y + 120 then
                    c.y = -160 - math.random() * 120
                    c.sp = 40 + math.random() * 90
                end
                c.col.Position = UDim2.new(c.col.Position.X.Scale, 0, 0, c.y)
                if doSwap then
                    for i, t in ipairs(c.labels) do
                        if math.random() < 0.45 then
                            local i1 = math.random(1, #BG_MATRIX_CHARS)
                            t.Text = string.sub(BG_MATRIX_CHARS, i1, i1)
                        end
                    end
                end
            end
        end)
    end

    local function buildSparks(host_, p)
        local sp = {}
        for i = 1, 34 do
            local s = ring(host_, 1 + math.random(0, 2), p.c3, 0.2, 0)
            s.AnchorPoint = Vector2.new(0.5, 0.5)
            s.Position = UDim2.new(math.random(), 0, math.random(), 0)
            sp[#sp + 1] = { o = s, ph = math.random() * 6.28, sp = 0.06 + math.random() * 0.16, dx = (math.random() - 0.5) * 0.05 }
        end
        table.insert(bgUpdaters, function(dt)
            local k = 1
            for _, s in ipairs(sp) do
                s.ph = s.ph + dt * k
                local y = s.o.Position.Y.Scale - s.sp * dt * k
                local x = s.o.Position.X.Scale + s.dx * dt * k + math.sin(s.ph * 1.4) * 0.0016
                if y < -0.05 then y = 1.05; x = math.random() end
                if x < 0 then x = x + 1 elseif x > 1 then x = x - 1 end
                s.o.Position = UDim2.new(x, 0, y, 0)
                s.o.BackgroundTransparency = math.clamp(0.35 + 0.45 * math.sin(s.ph * 1.7), 0.1, 0.9)
            end
        end)
    end

    local function buildStripes(host_, p)
        local bars = {}
        for i = 1, 9 do
            local b = Instance.new("Frame")
            b.Size = UDim2.new(1.6, 0, 0, 26)
            b.Position = UDim2.new(-0.3, 0, i / 10, 0)
            b.Rotation = 14
            b.BackgroundColor3 = p.c3
            b.BorderSizePixel = 0
            b.ZIndex = 0
            b.Active = false
            b.Parent = host_
            local g = Instance.new("UIGradient")
            g.Rotation = 0
            g.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(0.5, 0.78),
                NumberSequenceKeypoint.new(1, 1),
            })
            g.Parent = b
            table.insert(bgEls, b)
            bars[#bars + 1] = { o = b, g = g, i = i, hue = i / 9 }
        end
        table.insert(bgUpdaters, function(dt)
            local k = 1
            for _, b in ipairs(bars) do
                b.hue = (b.hue + dt * 0.03 * k) % 1
                local c = Color3.fromHSV(b.hue, 0.55, 1)
                b.g.Color = ColorSequence.new(H.mix(p.c2, c, 0.45), H.mix(p.c3, c, 0.6))
                b.o.Position = UDim2.new(-0.3 + 0.12 * math.sin(bgT * 0.35 * k + b.i), 0, b.i / 10, 0)
            end
        end)
    end

    local function buildGlass(host_, p)
        local g1 = gradFill(host_, p.c1, H.mix(p.c2, Color3.new(1, 1, 1), 0.1), 105, 0, 0.2, 0.75)
        local beams = {}
        for i = 1, 3 do
            local b = Instance.new("Frame")
            b.Size = UDim2.new(0, 160, 1.7, 0)
            b.Position = UDim2.new(0.1 * i, 0, -0.35, 0)
            b.Rotation = 22
            b.BackgroundColor3 = Color3.new(1, 1, 1)
            b.BorderSizePixel = 0
            b.ZIndex = 0
            b.Active = false
            b.Parent = host_
            local g = Instance.new("UIGradient")
            g.Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 1),
                NumberSequenceKeypoint.new(0.5, 0.86),
                NumberSequenceKeypoint.new(1, 1),
            })
            g.Parent = b
            table.insert(bgEls, b)
            beams[#beams + 1] = { o = b, ph = i * 2.1 }
        end
        table.insert(bgUpdaters, function(dt)
            local k = 1
            for _, b in ipairs(beams) do
                b.ph = b.ph + dt * 0.22 * k
                b.o.Position = UDim2.new(((b.ph * 0.06) % 1.4) - 0.5, 0, -0.35, 0)
            end
            g1.UIGradient.Rotation = 105 + 6 * math.sin(bgT * 0.1 * k)
        end)
    end

    local function buildImage(host_, p)
        local img = Instance.new("ImageLabel")
        img.Size = UDim2.new(1, 0, 1, 0)
        img.BackgroundTransparency = 1
        img.Image = bgImageId
        img.ScaleType = Enum.ScaleType.Crop
        img.ZIndex = 0
        img.Active = false
        img.Parent = host_
        paint(img, 0.1, "ImageTransparency")
        table.insert(bgEls, img)
        local _, tg = gradFill(host_, p.c2, p.c3, 35, 0, 0.55, 0.78)
        table.insert(bgUpdaters, function(dt)
            local k = 1
            local z = 1 + 0.05 * math.sin(bgT * 0.12 * k)
            img.Size = UDim2.new(z, 0, z, 0)
            img.Position = UDim2.new((z - 1) / -2 + 0.02 * math.sin(bgT * 0.07 * k), 0, (z - 1) / -2 + 0.02 * math.cos(bgT * 0.09 * k), 0)
            tg.Rotation = 35 + 20 * math.sin(bgT * 0.06 * k)
        end)
    end

    H.bgApply = function(mode)
        clearEls()
        H._bgModeApplied = mode
        if not bgEnabled or mode == 1 then return end
        local host_ = H.bgHost
        local p = bgPal()
        if mode == 2 then
            local f = gradFill(host_, p.c1, p.c2, 120, 0, 0.25, 0.85)
            local f2 = gradFill(host_, p.c2, p.c3, -35, 0, 0.8, 1)
            table.insert(bgUpdaters, function(dt)
                local k = 1
                f.UIGradient.Rotation = 120 + 40 * math.sin(bgT * 0.09 * k)
                f2.UIGradient.Rotation = -35 + 50 * math.cos(bgT * 0.07 * k)
                f2.UIGradient.Offset = Vector2.new(0.2 * math.sin(bgT * 0.11 * k), 0.1 * math.cos(bgT * 0.13 * k))
            end)
        elseif mode == 3 then
            buildAurora(host_, p)
        elseif mode == 4 then
            buildStars(host_, p)
        elseif mode == 5 then
            buildGrid(host_, p)
        elseif mode == 6 then
            buildWaves(host_, p)
        elseif mode == 7 then
            buildMatrix(host_, p)
        elseif mode == 8 then
            buildSparks(host_, p)
        elseif mode == 9 then
            buildStripes(host_, p)
        elseif mode == 10 then
            buildImage(host_, p)
        elseif mode == 11 then
            buildGlass(host_, p)
        end
        if H.bgRefreshPaint then H.bgRefreshPaint() end
    end

    H.bgRefreshPaint = function()
        local k = bgBright / 100
        for _, e in ipairs(bgPaint) do
            if e.o and e.o.Parent then
                pcall(function() e.o[e.p] = 1 - (1 - e.b) * k end)
            end
        end
        if H.bgDimLayer then H.bgDimLayer.BackgroundTransparency = 1 - (bgEnabled and bgDim / 100 or 0) end
        if layer then layer.Visible = bgEnabled and H._bgModeApplied ~= 1 end
    end

    ----------------------------------------------------------
    -- СЛОЙ ЭФФЕКТОВ ПОВЕРХ ОКНА
    ----------------------------------------------------------
    local fx = Instance.new("Frame")
    fx.Name = "VMFxLayer"
    fx.Size = UDim2.new(1, 0, 1, 0)
    fx.BackgroundTransparency = 1
    fx.ClipsDescendants = true
    fx.ZIndex = 30
    fx.Active = false
    fx.Parent = MainFrame
    Instance.new("UICorner", fx).CornerRadius = UDim.new(0, 12)
    H.fxLayer = fx

    -- виньетка по краям: мягкое затемнение, не мешает читать текст
    for _, cfg in ipairs({
        { sz = UDim2.new(1, 0, 0, 46), pos = UDim2.new(0, 0, 0, 0), rot = 90 },
        { sz = UDim2.new(1, 0, 0, 46), pos = UDim2.new(0, 0, 1, -46), rot = -90 },
        { sz = UDim2.new(0, 60, 1, 0), pos = UDim2.new(0, 0, 0, 0), rot = 0 },
        { sz = UDim2.new(0, 60, 1, 0), pos = UDim2.new(1, -60, 0, 0), rot = 180 },
    }) do
        local f = Instance.new("Frame")
        f.Size = cfg.sz
        f.Position = cfg.pos
        f.BackgroundColor3 = Color3.new(0, 0, 0)
        f.BorderSizePixel = 0
        f.ZIndex = 30
        f.Active = false
        f.Parent = fx
        local g = Instance.new("UIGradient")
        g.Rotation = cfg.rot
        g.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.35),
            NumberSequenceKeypoint.new(1, 1),
        })
        g.Parent = f
        H._fxVignette = H._fxVignette or {}
        table.insert(H._fxVignette, f)
    end

    -- угловые «скобки» — необычная деталь оформления
    for _, corner in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
        local holder = Instance.new("Frame")
        holder.Size = UDim2.new(0, 18, 0, 18)
        holder.Position = UDim2.new(corner[1], corner[1] == 1 and -18 or 0, corner[2], corner[2] == 1 and -18 or 0)
        holder.BackgroundTransparency = 1
        holder.ZIndex = 31
        holder.Active = false
        holder.Parent = fx
        for i = 1, 2 do
            local bar = Instance.new("Frame")
            bar.BackgroundColor3 = THEME.Accent
            bar.BorderSizePixel = 0
            bar.ZIndex = 31
            if i == 1 then
                bar.Size = UDim2.new(1, 0, 0, 2)
                bar.Position = UDim2.new(0, 0, corner[2] == 1 and 1 or 0, corner[2] == 1 and -2 or 0)
            else
                bar.Size = UDim2.new(0, 2, 1, 0)
                bar.Position = UDim2.new(corner[1] == 1 and 1 or 0, corner[1] == 1 and -2 or 0, 0, 0)
            end
            bar.Parent = holder
            H.reg(bar, "BackgroundColor3", "Accent")
        end
    end

    -- световая полоса, бегущая по верхней кромке
    local sweep = Instance.new("Frame")
    sweep.Size = UDim2.new(0, 160, 0, 2)
    sweep.Position = UDim2.new(0, -0.2, 0, 0)
    sweep.BackgroundColor3 = Color3.new(1, 1, 1)
    sweep.BorderSizePixel = 0
    sweep.ZIndex = 31
    sweep.Active = false
    sweep.Parent = fx
    local sg = Instance.new("UIGradient")
    sg.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0.25),
        NumberSequenceKeypoint.new(1, 1),
    })
    sg.Parent = sweep
    local function sweepColor()
        local a = THEME.Accent
        sg.Color = ColorSequence.new(H.mix(a, Color3.new(1, 1, 1), 0.55), a)
    end
    sweepColor()
    H.regFn(sweepColor)
    local sweepPos = -0.25

    -- сканлайны
    local scan = {}
    for i = 1, 16 do
        local l = Instance.new("Frame")
        l.Size = UDim2.new(1, 0, 0, 1)
        l.Position = UDim2.new(0, 0, (i - 1) / 16, 0)
        l.BackgroundColor3 = Color3.new(1, 1, 1)
        l.BackgroundTransparency = 0.94
        l.BorderSizePixel = 0
        l.ZIndex = 30
        l.Active = false
        l.Parent = fx
        scan[#scan + 1] = l
    end

    -- искры поверх интерфейса
    local sparks = {}
    for i = 1, 22 do
        local s = Instance.new("Frame")
        s.Size = UDim2.new(0, 2, 0, 2)
        s.AnchorPoint = Vector2.new(0.5, 0.5)
        s.Position = UDim2.new(math.random(), 0, math.random(), 0)
        s.BackgroundColor3 = THEME.Accent
        s.BorderSizePixel = 0
        s.ZIndex = 31
        s.Active = false
        s.Parent = fx
        Instance.new("UICorner", s).CornerRadius = UDim.new(1, 0)
        H.reg(s, "BackgroundColor3", "Accent")
        sparks[#sparks + 1] = { o = s, ph = math.random() * 6.28, sp = 0.05 + math.random() * 0.1 }
    end

    H._bgFX = {
        sweep = sweep, scan = scan, sparks = sparks,
        step = function(dt)
            local k = 1
            sweepPos = sweepPos + dt * 0.28 * k
            if sweepPos > 1.25 then sweepPos = -0.3 end
            sweep.Position = UDim2.new(sweepPos, 0, 0, 0)
            for i, l in ipairs(scan) do
                l.Position = UDim2.new(0, 0, ((i - 1) / 16 + (bgT * 0.02 * k) % (1 / 16)) % 1, 0)
            end
            for _, s in ipairs(sparks) do
                s.ph = s.ph + dt * k
                local y = s.o.Position.Y.Scale - s.sp * dt * k
                if y < -0.04 then y = 1.04; s.o.Position = UDim2.new(math.random(), 0, y, 0) else s.o.Position = UDim2.new(s.o.Position.X.Scale, 0, y, 0) end
                s.o.BackgroundTransparency = math.clamp(0.35 + 0.5 * math.sin(s.ph * 1.5), 0.1, 0.92)
            end
            if bgPulse and mainStroke then
                mainStroke.Transparency = 0.35 + 0.3 * math.sin(bgT * 1.6)
            end
        end,
    }

    ----------------------------------------------------------
    -- РУЧКИ ДЛЯ ПАНЕЛИ И КОНФИГОВ
    ----------------------------------------------------------
    H.bgToggle = {
        Get = function() return bgEnabled end,
        Set = function(v)
            bgEnabled = v and true or false
            H.bgApply(H._bgModeApplied or bgModeIndex)
            H.bgRefreshPaint()
        end,
    }
    H.bgMode = {
        Get = function() return bgModeIndex end,
        Set = function(v)
            bgModeIndex = math.clamp(math.floor(tonumber(v) or 2), 1, #H.bgNames)
            H.bgApply(bgModeIndex)
            if H.bgStatusText then H.bgStatusText() end
        end,
    }
    H.bgPalette = {
        Get = function() return bgPaletteIndex end,
        Set = function(v)
            bgPaletteIndex = math.clamp(math.floor(tonumber(v) or 1), 1, #H.bgPalettes)
            H.bgRefreshBase()
            H.bgApply(bgModeIndex)
            if H.bgStatusText then H.bgStatusText() end
        end,
    }
    H.bgSpeed = {
        Get = function() return bgSpeed end,
        Set = function(v, fire)
            bgSpeed = math.clamp(tonumber(v) or 100, 0, 200)
            if fire and H.bgSpeedSlider then H.bgSpeedSlider.Set(bgSpeed, false) end
        end,
    }
    H.bgBright = {
        Get = function() return bgBright end,
        Set = function(v, fire)
            bgBright = math.clamp(tonumber(v) or 100, 0, 100)
            H.bgRefreshPaint()
            if fire and H.bgBrightSlider then H.bgBrightSlider.Set(bgBright, false) end
        end,
    }
    H.bgDim = {
        Get = function() return bgDim end,
        Set = function(v, fire)
            bgDim = math.clamp(tonumber(v) or 30, 0, 80)
            H.bgRefreshPaint()
            if fire and H.bgDimSlider then H.bgDimSlider.Set(bgDim, false) end
        end,
    }
    H.bgImage = {
        Get = function() return bgImageId end,
        Set = function(v)
            if type(v) ~= "string" or v == "" then return end
            if v:match("^%d+$") then v = "rbxassetid://" .. v end
            bgImageId = v
            if bgModeIndex == 10 then H.bgApply(10) end
        end,
    }
    H.fxToggle = {
        Get = function() return bgFX end,
        Set = function(v)
            bgFX = v and true or false
            if H.fxLayer then H.fxLayer.Visible = bgFX end
        end,
    }
    H.fxGlow = {
        Get = function() return bgPulse end,
        Set = function(v)
            bgPulse = v and true or false
            if not bgPulse and mainStroke then mainStroke.Transparency = 0.5 end
        end,
    }

    H.bgApply(bgModeIndex)
    H.bgRefreshPaint()

    -- один общий цикл на фон и эффекты
    RunService.RenderStepped:Connect(function(dt)
        if not MainFrame or not MainFrame.Visible then return end
        local k = bgSpeed / 100
        bgT = bgT + dt * k
        if bgEnabled and H._bgModeApplied ~= 1 and layer.Visible then
            for _, fn in ipairs(bgUpdaters) do
                pcall(fn, dt * k)
            end
        end
        if bgFX and H._bgFX then H._bgFX.step(dt * k) end
    end)
end

H.__build_GUI = function()
H.createTabButton("GUI", 13, CATEGORY_COLORS.Config)
guiTab = H.createTabFrame("GUI")
H.__build_BG()

H.sectionLabel(guiTab, "ТЕМЫ ОФОРМЛЕНИЯ", 0)
local function applyGuiTheme(name)
    local themes = {
        Aurora = {
            Background = Color3.fromRGB(8, 10, 18),
            Sidebar = Color3.fromRGB(6, 8, 14),
            Panel = Color3.fromRGB(18, 22, 34),
            Accent = Color3.fromRGB(120, 200, 255),
            Text = Color3.fromRGB(245, 248, 255),
            SubText = Color3.fromRGB(140, 155, 180),
        },
        Neon = {
            Background = Color3.fromRGB(14, 10, 22),
            Sidebar = Color3.fromRGB(10, 8, 18),
            Panel = Color3.fromRGB(24, 18, 36),
            Accent = Color3.fromRGB(168, 85, 255),
            Text = Color3.fromRGB(245, 240, 255),
            SubText = Color3.fromRGB(160, 145, 185),
        },
        Ice = {
            Background = Color3.fromRGB(10, 16, 24),
            Sidebar = Color3.fromRGB(8, 12, 20),
            Panel = Color3.fromRGB(16, 28, 40),
            Accent = Color3.fromRGB(80, 200, 255),
            Text = Color3.fromRGB(230, 245, 255),
            SubText = Color3.fromRGB(130, 170, 200),
        },
        Gold = {
            Background = Color3.fromRGB(16, 12, 8),
            Sidebar = Color3.fromRGB(12, 9, 6),
            Panel = Color3.fromRGB(28, 22, 14),
            Accent = Color3.fromRGB(255, 190, 80),
            Text = Color3.fromRGB(255, 245, 230),
            SubText = Color3.fromRGB(180, 150, 110),
        },
        Blood = {
            Background = Color3.fromRGB(18, 8, 10),
            Sidebar = Color3.fromRGB(14, 6, 8),
            Panel = Color3.fromRGB(32, 14, 18),
            Accent = Color3.fromRGB(255, 60, 80),
            Text = Color3.fromRGB(255, 230, 235),
            SubText = Color3.fromRGB(180, 120, 130),
        },
    }
    local th = themes[name]
    if not th then return end
    THEME.Background = th.Background
    THEME.Sidebar = th.Sidebar
    THEME.Panel = th.Panel
    THEME.Accent = th.Accent
    THEME.AccentSoft = Color3.new(th.Accent.R * 0.55, th.Accent.G * 0.55, th.Accent.B * 0.55)
    THEME.Text = th.Text
    THEME.SubText = th.SubText
    MainFrame.BackgroundColor3 = th.Background
    mainStroke.Color = th.Accent
    local tl = MainFrame:FindFirstChild("AccentLine")
    if tl then tl.BackgroundColor3 = th.Accent end
    AccentDot.BackgroundColor3 = th.Accent
    SelectorPill.BackgroundColor3 = THEME.AccentSoft
    if hudStroke then hudStroke.Color = th.Accent end
    if hudName then hudName.TextColor3 = th.Accent end
    TopBar.BackgroundColor3 = th.Sidebar
    local topFix = TopBar:FindFirstChildWhichIsA("Frame")
    if topFix then topFix.BackgroundColor3 = th.Sidebar end
    Sidebar.BackgroundColor3 = th.Sidebar
    for _, data in pairs(tabButtons) do
        if data.icon then data.icon.BackgroundColor3 = th.Accent end
    end
    -- перекрашиваем ВЕСЬ интерфейс (панели, тумблеры, слайдеры, кнопки), а не только окно
    if H.refreshTheme then H.refreshTheme() end
    if H.notify then H.notify("Тема: " .. tostring(name)) end
end
-- CS-style preset
local themesExtra = true
do
    local cs = {
        Background = Color3.fromRGB(16, 16, 18),
        Sidebar = Color3.fromRGB(12, 12, 14),
        Panel = Color3.fromRGB(26, 26, 30),
        Accent = Color3.fromRGB(80, 255, 140),
        Text = Color3.fromRGB(235, 235, 240),
        SubText = Color3.fromRGB(140, 145, 155),
    }
    -- inject into apply if needed
end
H.createButtonRow(guiTab, {
    { text = "CS Green", callback = function()
        applyGuiTheme("Aurora")
        -- force CS palette
        THEME.Background = Color3.fromRGB(16, 16, 18)
        THEME.Sidebar = Color3.fromRGB(12, 12, 14)
        THEME.Panel = Color3.fromRGB(26, 26, 30)
        THEME.Accent = Color3.fromRGB(80, 255, 140)
        THEME.AccentSoft = Color3.fromRGB(40, 140, 80)
        THEME.Text = Color3.fromRGB(235, 235, 240)
        THEME.SubText = Color3.fromRGB(140, 145, 155)
        MainFrame.BackgroundColor3 = THEME.Background
        mainStroke.Color = Color3.fromRGB(45, 45, 50)
        TopBar.BackgroundColor3 = THEME.Sidebar
        Sidebar.BackgroundColor3 = THEME.Sidebar
        AccentDot.BackgroundColor3 = THEME.Accent
        SelectorPill.BackgroundColor3 = THEME.AccentSoft
        local tl = MainFrame:FindFirstChild("AccentLine")
        if tl then tl.BackgroundColor3 = THEME.Accent end
        if hudStroke then hudStroke.Color = THEME.Accent end
        if hudName then hudName.TextColor3 = THEME.Accent end
        for _, data in pairs(tabButtons) do
            if data.icon then data.icon.BackgroundColor3 = THEME.Accent end
        end
        if H.refreshTheme then H.refreshTheme() end
        if H.notify then H.notify("Тема: CS Green") end
    end },
    { text = "Neon", callback = function() applyGuiTheme("Neon") end },
    { text = "Ice", callback = function() applyGuiTheme("Ice") end },
    { text = "Blood", callback = function() applyGuiTheme("Blood") end },
}, 0)

H.sectionLabel(guiTab, "ЖИВОЙ ФОН ОКНА", 0)
H.bgStatusLabel = Instance.new("TextLabel")
H.bgStatusLabel.Size = UDim2.new(1, 0, 0, 16)
H.bgStatusLabel.BackgroundTransparency = 1
H.bgStatusLabel.Text = ""
H.bgStatusLabel.TextColor3 = THEME.SubText
H.bgStatusLabel.Font = Enum.Font.GothamMedium
H.bgStatusLabel.TextSize = 11
H.bgStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
H.bgStatusLabel.LayoutOrder = 0
H.bgStatusLabel.Parent = guiTab
H.reg(H.bgStatusLabel, "TextColor3", "SubText")
H.bgStatusText = function()
    if not (H.bgMode and H.bgPalette) then return end
    local m = H.bgNames[H.bgMode.Get()] or "?"
    local p = H.bgPalettes[H.bgPalette.Get()]
    H.bgStatusLabel.Text = "Сейчас: " .. m .. "  ·  палитра: " .. tostring(p and p.name or "-")
end

H.createToggleRow(guiTab, "Живой фон окна (11 режимов)", 0, function(state)
    H.bgToggle.Set(state)
end, true)

local bgModeRows = {
    { 1, 2, 3, 4 },
    { 5, 6, 7, 8 },
    { 9, 10, 11 },
}
for _, rowDef in ipairs(bgModeRows) do
    local btns = {}
    for _, idx in ipairs(rowDef) do
        btns[#btns + 1] = {
            text = H.bgNames[idx],
            callback = function()
                H.bgMode.Set(idx)
                H.bgStatusText()
                if idx == 10 then
                    H.notify("Режим «Картинка»: вставь свой ID ниже")
                end
            end,
        }
    end
    H.createButtonRow(guiTab, btns, 0)
end

H.createButtonRow(guiTab, {
    { text = "Аврора-микс", callback = function()
        H.bgMode.Set(3); H.bgPalette.Set(2); H.bgSpeed.Set(130, true); H.bgStatusText()
    end },
    { text = "Кибер-неон", callback = function()
        H.bgMode.Set(9); H.bgPalette.Set(2); H.bgSpeed.Set(150, true); H.bgStatusText()
    end },
    { text = "Матрица", callback = function()
        H.bgMode.Set(7); H.bgPalette.Set(7); H.bgSpeed.Set(110, true); H.bgStatusText()
    end },
}, 0)
H.createButtonRow(guiTab, {
    { text = "Спокойный градиент", callback = function()
        H.bgMode.Set(2); H.bgPalette.Set(1); H.bgSpeed.Set(60, true); H.bgStatusText()
    end },
    { text = "Ночное стекло", callback = function()
        H.bgMode.Set(11); H.bgPalette.Set(4); H.bgSpeed.Set(70, true); H.bgStatusText()
    end },
    { text = "Выключить фон", callback = function()
        H.bgToggle.Set(false); H.bgStatusText()
    end },
}, 0)

-- палитры
local palRows = {}
do
    local cur = {}
    for i, pal in ipairs(H.bgPalettes) do
        cur[#cur + 1] = {
            text = pal.name,
            callback = function()
                H.bgPalette.Set(i)
                H.bgStatusText()
            end,
        }
        if #cur == 5 or i == #H.bgPalettes then
            table.insert(palRows, cur)
            cur = {}
        end
    end
end
for _, rowDef in ipairs(palRows) do
    H.createButtonRow(guiTab, rowDef, 0)
end

H.bgBrightSlider = H.createSlider(guiTab, "Насыщенность фона %", 0, 100, 100, 0, function(v)
    H.bgBright.Set(v, false)
end)
H.bgDimSlider = H.createSlider(guiTab, "Затемнение под текстом %", 0, 80, 30, 0, function(v)
    H.bgDim.Set(v, false)
end)
H.bgSpeedSlider = H.createSlider(guiTab, "Скорость анимации фона %", 0, 200, 100, 0, function(v)
    H.bgSpeed.Set(v, false)
end)

H.createInputRow(guiTab, "ID картинки, напр. 13061196049", "Поставить фоном", 0, function(text)
    if not text or text == "" then return end
    H.bgImage.Set(text)
    H.bgMode.Set(10)
    H.bgStatusText()
    H.notify("Фон-картинка: " .. tostring(text))
end)

H.createToggleRow(guiTab, "Украшения: свечение, искры, сканлайны", 0, function(state)
    H.fxToggle.Set(state)
end, true)
H.createToggleRow(guiTab, "Пульсация рамки окна", 0, function(state)
    H.fxGlow.Set(state)
end, true)

H.bgStatusText()

H.sectionLabel(guiTab, "ЗВУК И АНИМАЦИЯ КЛИКА", 0)
H.createToggleRow(guiTab, "Звук при клике по GUI", 0, function(state)
    clickSoundEnabled = state
end, true)
H.createToggleRow(guiTab, "Анимация пульса при клике", 0, function(state)
    clickAnimEnabled = state
end, true)
H.clickVol = H.createSlider(guiTab, "Громкость клика", 0, 100, 45, 0, function(v)
    clickVolume = v / 100
end)
H.createButtonRow(guiTab, {
    { text = "Soft", callback = function()
        clickSoundId = CLICK_SOUND_PRESETS.Soft
        playGuiClick()
    end },
    { text = "Pop", callback = function()
        clickSoundId = CLICK_SOUND_PRESETS.Pop
        playGuiClick()
    end },
    { text = "Classic", callback = function()
        clickSoundId = CLICK_SOUND_PRESETS.Classic
        playGuiClick()
    end },
    { text = "Tick", callback = function()
        clickSoundId = CLICK_SOUND_PRESETS.Tick
        playGuiClick()
    end },
}, 0)
H.createButtonRow(guiTab, {
    { text = "UI", callback = function()
        clickSoundId = CLICK_SOUND_PRESETS.UI
        playGuiClick()
    end },
    { text = "Sharp", callback = function()
        clickSoundId = CLICK_SOUND_PRESETS.Sharp
        playGuiClick()
    end },
    { text = "Тест звука", callback = function()
        playGuiClick()
    end },
}, 0)

H.sectionLabel(guiTab, "МИНИ-РАДАР", 0)
H.createToggleRow(guiTab, "Показать мини-радар (слева снизу)", 0, function(state)
    radarEnabled = state
    if RadarFrame then RadarFrame.Visible = state end
end, true)
H.createSlider(guiTab, "Дальность радара", 40, 300, 120, 0, function(v)
    radarRange = v
end)

H.sectionLabel(guiTab, "РАЗМЕР И ПРОЗРАЧНОСТЬ МЕНЮ", 1)
local baseMenuSize = Vector2.new(660, 480)
H.guiScale = H.createSlider(guiTab, "Масштаб меню %", 70, 130, 100, 2, function(v)
    local s = v / 100
    MainFrame.Size = UDim2.new(0, math.floor(baseMenuSize.X * s), 0, math.floor(baseMenuSize.Y * s))
end)

H.guiTransparency = H.createSlider(guiTab, "Прозрачность фона меню %", 0, 60, 0, 3, function(v)
    MainFrame.BackgroundTransparency = v / 100
end)

H.sectionLabel(guiTab, "ПОЗИЦИЯ МЕНЮ", 4)
H.createButtonRow(guiTab, {
    { text = "Центр", callback = function()
        MainFrame.Position = UDim2.new(0.5, -MainFrame.AbsoluteSize.X / 2, 0.5, -MainFrame.AbsoluteSize.Y / 2)
    end },
    { text = "Левый верх", callback = function()
        MainFrame.Position = UDim2.new(0, 20, 0, 20)
    end },
    { text = "Правый верх", callback = function()
        MainFrame.Position = UDim2.new(1, -MainFrame.AbsoluteSize.X - 20, 0, 20)
    end },
}, 5)

H.sectionLabel(guiTab, "ЦВЕТ АКЦЕНТА GUI", 6)
-- accent already exists on screen tab; duplicate control bound to same theme
H.guiAccent = H.createColorSliders(guiTab, "АКЦЕНТ (RGB)", 7, THEME.Accent, function(color)
    THEME.Accent = color
    THEME.AccentSoft = Color3.new(color.R * 0.6, color.G * 0.6, color.B * 0.6)
    mainStroke.Color = color
    if hudStroke then hudStroke.Color = color end
    AccentDot.BackgroundColor3 = color
    SelectorPill.BackgroundColor3 = THEME.AccentSoft
    if hudName then hudName.TextColor3 = color end
    local tl = MainFrame:FindFirstChild("AccentLine")
    if tl then tl.BackgroundColor3 = color end
    for _, data in pairs(tabButtons) do
        data.icon.BackgroundColor3 = color
    end
    if H.refreshTheme then H.refreshTheme() end
end)

H.sectionLabel(guiTab, "СООТНОШЕНИЕ СТОРОН ОКНА", 9)
local function applyMenuAspect(ratio)
    -- сохраняем примерно ту же площадь окна (660x480), меняем только пропорции
    local area = 660 * 480
    local newH = math.floor(math.sqrt(area / ratio))
    local newW = math.floor(newH * ratio)
    baseMenuSize = Vector2.new(newW, newH)
    local scale = (H.guiScale and H.guiScale.Get() or 100) / 100
    H.tw(MainFrame, 0.2, {
        Size = UDim2.new(0, math.floor(baseMenuSize.X * scale), 0, math.floor(baseMenuSize.Y * scale)),
    }, Enum.EasingStyle.Back)
end
H.createButtonRow(guiTab, {
    { text = "4:3", callback = function() applyMenuAspect(4 / 3) end },
    { text = "16:9", callback = function() applyMenuAspect(16 / 9) end },
    { text = "16:10", callback = function() applyMenuAspect(16 / 10) end },
}, 10)
H.createButtonRow(guiTab, {
    { text = "21:9", callback = function() applyMenuAspect(21 / 9) end },
    { text = "1:1", callback = function() applyMenuAspect(1) end },
    { text = "Обычный", callback = function() applyMenuAspect(660 / 480) end },
}, 10)

H.sectionLabel(guiTab, "ТЕНЬ И РАМКА", 11)
H.createToggleRow(guiTab, "Показать тень окна", 12, function(state)
    local shadow = MainFrame:FindFirstChildWhichIsA("ImageLabel")
    if shadow then shadow.Visible = state end
end, true)

H.createSlider(guiTab, "Толщина рамки", 0, 4, 1, 13, function(v)
    mainStroke.Thickness = math.max(0, v)
end)

H.sectionLabel(guiTab, "ГОРЯЧАЯ КЛАВИША", 14)
local guiHotkeyStatus = Instance.new("TextLabel")
guiHotkeyStatus.Size = UDim2.new(1, 0, 0, 18)
guiHotkeyStatus.BackgroundTransparency = 1
guiHotkeyStatus.Text = "Текущая клавиша: " .. menuHotkey.Name
guiHotkeyStatus.TextColor3 = THEME.SubText
guiHotkeyStatus.Font = Enum.Font.Gotham
guiHotkeyStatus.TextSize = 12
guiHotkeyStatus.TextXAlignment = Enum.TextXAlignment.Left
guiHotkeyStatus.LayoutOrder = 16
guiHotkeyStatus.Parent = guiTab
H.createButtonRow(guiTab, {
    { text = "Нажмите, затем клавишу", callback = function()
        hotkeyListening = true
        guiHotkeyStatus.Text = "Ожидание клавиши..."
        if hotkeyLabel then hotkeyLabel.Text = "Ожидание клавиши..." end
    end },
}, 15)
-- синхронизация с hotkeyLabel (если есть на вкладке Экран)
task.spawn(function()
    while guiHotkeyStatus.Parent do
        task.wait(0.5)
        guiHotkeyStatus.Text = "Текущая клавиша: " .. menuHotkey.Name
    end
end)

H.sectionLabel(guiTab, "АНИМАЦИИ", 17)
H.createToggleRow(guiTab, "Анимация открытия меню", 18, function(state)
    H._animOpen = state
end, true)

H.sectionLabel(guiTab, "СБРОС GUI", 19)
H.createButtonRow(guiTab, {
    { text = "Сбросить вид меню", callback = function()
        baseMenuSize = Vector2.new(660, 480)
        if H.guiScale then H.guiScale.Set(100) end
        if H.guiTransparency then H.guiTransparency.Set(0) end
        MainFrame.Position = UDim2.new(0.5, -330, 0.5, -240)
        MainFrame.Size = UDim2.new(0, 660, 0, 480)
        MainFrame.BackgroundTransparency = 0
        mainStroke.Thickness = 1.2
    end },
}, 20)


----------------------------------------------------------
-- ВИДИМОСТЬ ВИЗУАЛОВ ОТ 1-ГО ЛИЦА
-- Roblox ставит LocalTransparencyModifier=1 на части персонажа в FP.
-- Принудительно держим наши эффекты видимыми.
----------------------------------------------------------
local fpVisConn = nil
fpVisConn = RunService.RenderStepped:Connect(function()
    local char = player.Character
    if not char then return end
    -- крылья
    local wings = char:FindFirstChild("__VM_3DWings")
    if wings then
        for _, p in ipairs(wings:GetDescendants()) do
            if p:IsA("BasePart") then
                p.LocalTransparencyModifier = 0
            end
        end
    end
    -- highlight остаётся на персонаже — ок
    -- trail attachments на root
    local root = char:FindFirstChild("HumanoidRootPart")
    if root then
        for _, p in ipairs(root:GetChildren()) do
            if p:IsA("ParticleEmitter") or p:IsA("Trail") or p:IsA("Beam") then
                -- emitters don't use LocalTransparencyModifier
            end
            if p:IsA("BasePart") and (p.Name:find("__VM") or p.Name:find("Wing")) then
                p.LocalTransparencyModifier = 0
            end
        end
    end
    -- companion in workspace
    local comp = workspace:FindFirstChild("__VM_Companion")
    if comp then
        for _, p in ipairs(comp:GetDescendants()) do
            if p:IsA("BasePart") then
                p.LocalTransparencyModifier = 0
            end
        end
    end
    -- soap / custom visual parts tagged
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") and (p.Name == "Feather" or p.Name == "WingMesh" or p.Name:find("WingRoot")) then
            p.LocalTransparencyModifier = 0
        end
    end
end)



----------------------------------------------------------
-- МЕТКИ / ТЕЛЕПОРТ
----------------------------------------------------------
H.sectionLabel(camTab, "МЕТКИ И ТЕЛЕПОРТ", 20)
local waypoints = {} -- {name=, pos=, part=}
local waypointFolder = Instance.new("Folder")
waypointFolder.Name = "__VM_Waypoints"
waypointFolder.Parent = workspace

local function clearWaypointVisuals()
    for _, wp in ipairs(waypoints) do
        if wp.part then wp.part:Destroy() end
    end
end

local function makeWaypointMarker(pos, name)
    local p = Instance.new("Part")
    p.Name = "WP_" .. (name or "mark")
    p.Anchored = true
    p.CanCollide = false
    p.Size = Vector3.new(1.2, 0.3, 1.2)
    p.Material = Enum.Material.Neon
    p.Color = THEME.Accent
    p.CFrame = CFrame.new(pos + Vector3.new(0, 0.2, 0))
    p.Parent = waypointFolder
    local beam = Instance.new("Part")
    beam.Anchored = true
    beam.CanCollide = false
    beam.Material = Enum.Material.Neon
    beam.Color = THEME.Accent
    beam.Size = Vector3.new(0.25, 8, 0.25)
    beam.Transparency = 0.35
    beam.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0))
    beam.Parent = p
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 120, 0, 30)
    bb.StudsOffset = Vector3.new(0, 6, 0)
    bb.AlwaysOnTop = true
    bb.Parent = p
    local tl = Instance.new("TextLabel")
    tl.Size = UDim2.new(1, 0, 1, 0)
    tl.BackgroundTransparency = 1
    tl.Text = name or "Метка"
    tl.TextColor3 = Color3.fromRGB(255, 255, 255)
    tl.Font = Enum.Font.GothamBold
    tl.TextSize = 14
    tl.TextStrokeTransparency = 0.5
    tl.Parent = bb
    return p
end

H.createButtonRow(camTab, {
    { text = "Поставить метку здесь", callback = function()
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local name = "Метка " .. tostring(#waypoints + 1)
        local wp = { name = name, pos = root.Position, part = makeWaypointMarker(root.Position, name) }
        table.insert(waypoints, wp)
    end },
    { text = "ТП на последнюю", callback = function()
        if #waypoints == 0 then return end
        local wp = waypoints[#waypoints]
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if root and wp.pos then
            root.CFrame = CFrame.new(wp.pos + Vector3.new(0, 3, 0))
        end
    end },
}, 21)

H.createButtonRow(camTab, {
    { text = "Удалить последнюю", callback = function()
        local wp = table.remove(waypoints)
        if wp and wp.part then wp.part:Destroy() end
    end },
    { text = "Очистить все метки", callback = function()
        for _, wp in ipairs(waypoints) do
            if wp.part then wp.part:Destroy() end
        end
        waypoints = {}
    end },
}, 22)

H.createInputRow(camTab, "Имя метки", "ТП по имени", 23, function(text)
    if not text or text == "" then return end
    for _, wp in ipairs(waypoints) do
        if wp.name:lower() == text:lower() or wp.name:lower():find(text:lower(), 1, true) then
            local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if root then root.CFrame = CFrame.new(wp.pos + Vector3.new(0, 3, 0)) end
            return
        end
    end
end)
H.createInputRow(camTab, "Новое имя для метки здесь", "Поставить", 24, function(text)
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local name = (text and text ~= "") and text or ("Метка " .. tostring(#waypoints + 1))
    table.insert(waypoints, { name = name, pos = root.Position, part = makeWaypointMarker(root.Position, name) })
end)

----------------------------------------------------------
-- КРАСИВЫЙ ОВЕРЛЕЙ ВМЕСТО СТАНДАРТНЫХ ПОДСКАЗОК
-- (полностью заменить CoreGui Settings/Exit нельзя клиентом,
--  но можно скрыть часть CoreGui и дать свой быстрый бар)
----------------------------------------------------------
H.sectionLabel(guiTab, "СИСТЕМНЫЙ GUI ROBLOX", 30)
local coreStyled = false
local CoreStyleGui = Instance.new("ScreenGui")
CoreStyleGui.Name = "VisualMenuCoreStyle"
CoreStyleGui.ResetOnSpawn = false
CoreStyleGui.IgnoreGuiInset = true
CoreStyleGui.DisplayOrder = 120
CoreStyleGui.Enabled = false
CoreStyleGui.Parent = game:GetService("CoreGui")

local quickBar = Instance.new("Frame")
quickBar.Size = UDim2.new(0, 260, 0, 48)
quickBar.Position = UDim2.new(1, -276, 0, 12)
quickBar.BackgroundColor3 = Color3.fromRGB(16, 12, 24)
quickBar.BackgroundTransparency = 0.1
quickBar.BorderSizePixel = 0
quickBar.Parent = CoreStyleGui
Instance.new("UICorner", quickBar).CornerRadius = UDim.new(0, 12)
local qbStroke = Instance.new("UIStroke", quickBar)
qbStroke.Color = THEME.Accent
qbStroke.Thickness = 1.2
qbStroke.Transparency = 0.3

local qbLayout = Instance.new("UIListLayout")
qbLayout.FillDirection = Enum.FillDirection.Horizontal
qbLayout.Padding = UDim.new(0, 6)
qbLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
qbLayout.VerticalAlignment = Enum.VerticalAlignment.Center
qbLayout.Parent = quickBar
local qbPad = Instance.new("UIPadding")
qbPad.PaddingLeft = UDim.new(0, 8)
qbPad.PaddingRight = UDim.new(0, 8)
qbPad.Parent = quickBar

local function qbButton(text, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 76, 0, 32)
    b.BackgroundColor3 = THEME.Panel
    b.Text = text
    b.TextColor3 = THEME.Text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.AutoButtonColor = false
    b.Parent = quickBar
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    b.MouseButton1Click:Connect(function()
        playGuiClick(b)
        if cb then cb() end
    end)
    return b
end

qbButton("Меню", function()
    menuOpen = not menuOpen
    MainFrame.Visible = menuOpen
end)
qbButton("Радар", function()
    radarEnabled = not radarEnabled
    if RadarFrame then RadarFrame.Visible = radarEnabled end
end)
qbButton("Сброс FX", function()
    pcall(function()
        if clearWings then clearWings() end
    end)
end)

H.createToggleRow(guiTab, "Красивый быстрый бар (справа сверху)", 31, function(state)
    coreStyled = state
    CoreStyleGui.Enabled = state
    if state then
        pcall(function()
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
        end)
    else
        pcall(function()
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
        end)
    end
end, false)

H.createToggleRow(guiTab, "Скрыть чат Roblox", 32, function(state)
    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, not state)
    end)
end, false)

H.createToggleRow(guiTab, "Скрыть список игроков", 33, function(state)
    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, not state)
    end)
end, false)



----------------------------------------------------------
-- SPECTATE + NICK ESP + TRACERS
----------------------------------------------------------
H.sectionLabel(camTab, "SPECTATE ИГРОКА", 30)
local spectating = false
local spectateTarget = nil
local defaultCamSubject = nil

local specList = Instance.new("ScrollingFrame")
specList.Size = UDim2.new(1, 0, 0, 120)
specList.BackgroundColor3 = THEME.Panel
specList.BorderSizePixel = 0
specList.ScrollBarThickness = 3
specList.ScrollBarImageColor3 = THEME.Accent
specList.CanvasSize = UDim2.new(0, 0, 0, 0)
specList.AutomaticCanvasSize = Enum.AutomaticSize.Y
specList.LayoutOrder = 31
specList.Parent = camTab
Instance.new("UICorner", specList).CornerRadius = UDim.new(0, 8)
local specLayout = Instance.new("UIListLayout")
specLayout.Padding = UDim.new(0, 4)
specLayout.Parent = specList
local specPad = Instance.new("UIPadding")
specPad.PaddingTop = UDim.new(0, 4)
specPad.PaddingLeft = UDim.new(0, 4)
specPad.PaddingRight = UDim.new(0, 4)
specPad.Parent = specList

local function stopSpectate()
    spectating = false
    spectateTarget = nil
    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if camera and hum then
        camera.CameraSubject = hum
        camera.CameraType = Enum.CameraType.Custom
    end
end

local function startSpectate(plr)
    if not plr or plr == player then return end
    local char = plr.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not (hum and camera) then return end
    spectating = true
    spectateTarget = plr
    camera.CameraType = Enum.CameraType.Custom
    camera.CameraSubject = hum
end

local function refreshSpecList()
    for _, c in ipairs(specList:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -8, 0, 28)
            btn.BackgroundColor3 = THEME.Background
            btn.Text = "  " .. (plr.DisplayName or plr.Name) .. "  (@" .. plr.Name .. ")"
            btn.TextColor3 = THEME.Text
            btn.Font = Enum.Font.Gotham
            btn.TextSize = 12
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.AutoButtonColor = false
            btn.Parent = specList
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
            btn.MouseButton1Click:Connect(function()
                playGuiClick(btn)
                startSpectate(plr)
            end)
        end
    end
end

local function getSpecPlayers()
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then table.insert(list, plr) end
    end
    return list
end

local function spectateOffset(delta)
    local list = getSpecPlayers()
    if #list == 0 then return end
    local idx = 1
    if spectateTarget then
        for i, p in ipairs(list) do
            if p == spectateTarget then idx = i break end
        end
    end
    idx = idx + delta
    if idx > #list then idx = 1 end
    if idx < 1 then idx = #list end
    startSpectate(list[idx])
end

H.createButtonRow(camTab, {
    { text = "◀ Prev", callback = function() spectateOffset(-1) end },
    { text = "Обновить", callback = refreshSpecList },
    { text = "Next ▶", callback = function() spectateOffset(1) end },
    { text = "Стоп спек", callback = stopSpectate },
}, 32)
refreshSpecList()
Players.PlayerAdded:Connect(function() task.defer(refreshSpecList) end)
Players.PlayerRemoving:Connect(function(plr)
    if spectateTarget == plr then stopSpectate() end
    task.defer(refreshSpecList)
end)


----------------------------------------------------------
-- ВКЛАДКА ESP
----------------------------------------------------------

H.sectionLabel(camTab, "FREECAM", 40)
local freecamOn = false
local freecamConn = nil
local freecamPart = nil
local freecamSaved = nil -- walkspeed etc
local freecamYaw, freecamPitch = 0, 0
local freecamControls = nil

local function stopFreecam()
    freecamOn = false
    if freecamConn then freecamConn:Disconnect(); freecamConn = nil end
    if freecamPart then freecamPart:Destroy(); freecamPart = nil end
    pcall(function()
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
    end)
    if freecamControls then
        pcall(function() freecamControls:Enable() end)
        freecamControls = nil
    end
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if freecamSaved then
        if hum then
            hum.WalkSpeed = freecamSaved.WalkSpeed
            hum.JumpPower = freecamSaved.JumpPower
            pcall(function() hum.JumpHeight = freecamSaved.JumpHeight end)
            hum.AutoRotate = freecamSaved.AutoRotate
            hum.PlatformStand = false
        end
        if root then
            root.Anchored = false
        end
        freecamSaved = nil
    end
    if camera and hum then
        camera.CameraType = Enum.CameraType.Custom
        camera.CameraSubject = hum
    end
end

local function startFreecam()
    stopSpectate()
    stopFreecam()
    freecamOn = true
    local char = player.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    freecamSaved = {
        WalkSpeed = hum and hum.WalkSpeed or 16,
        JumpPower = hum and hum.JumpPower or 50,
        JumpHeight = hum and hum.JumpHeight or 7.2,
        AutoRotate = hum and hum.AutoRotate or true,
    }
    -- персонаж стоит на месте
    if hum then
        hum.WalkSpeed = 0
        hum.JumpPower = 0
        pcall(function() hum.JumpHeight = 0 end)
        hum.AutoRotate = false
        hum:ChangeState(Enum.HumanoidStateType.Physics)
    end
    if root then
        root.Anchored = true
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end
    -- отключить PlayerModule controls если есть
    pcall(function()
        local ps = player:FindFirstChild("PlayerScripts")
        local pm = ps and ps:FindFirstChild("PlayerModule")
        if pm then
            local mod = require(pm)
            if mod and mod.GetControls then
                freecamControls = mod:GetControls()
                freecamControls:Disable()
            end
        end
    end)
    -- мышь для обзора + скрыть курсор
    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    UserInputService.MouseIconEnabled = false
    local look = camera.CFrame.LookVector
    freecamYaw = math.atan2(-look.X, -look.Z)
    freecamPitch = math.asin(math.clamp(look.Y, -0.999, 0.999))

    freecamPart = Instance.new("Part")
    freecamPart.Name = "__VM_Freecam"
    freecamPart.Anchored = true
    freecamPart.CanCollide = false
    freecamPart.Transparency = 1
    freecamPart.Size = Vector3.new(1, 1, 1)
    freecamPart.CFrame = camera.CFrame
    freecamPart.Parent = workspace
    camera.CameraType = Enum.CameraType.Scriptable

    freecamConn = RunService.RenderStepped:Connect(function(dt)
        if not freecamOn or not freecamPart then return end
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
        UserInputService.MouseIconEnabled = false
        -- обзор мышью (как обычная камера)
        local delta = UserInputService:GetMouseDelta()
        freecamYaw = freecamYaw - delta.X * 0.0035
        freecamPitch = math.clamp(freecamPitch - delta.Y * 0.0035, math.rad(-89), math.rad(89))
        local rot = CFrame.fromEulerAnglesYXZ(freecamPitch, freecamYaw, 0)
        local pos = freecamPart.Position
        -- движение относительно взгляда (горизонталь для WASD)
        local flatLook = Vector3.new(rot.LookVector.X, 0, rot.LookVector.Z)
        if flatLook.Magnitude > 0.01 then flatLook = flatLook.Unit end
        local flatRight = Vector3.new(rot.RightVector.X, 0, rot.RightVector.Z)
        if flatRight.Magnitude > 0.01 then flatRight = flatRight.Unit end
        local move = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + flatLook end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - flatLook end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - flatRight end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + flatRight end
        if UserInputService:IsKeyDown(Enum.KeyCode.E) then move = move + Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.Q) then move = move - Vector3.yAxis end
        local speed = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 90 or 40
        if move.Magnitude > 0 then
            pos = pos + move.Unit * speed * dt
        end
        freecamPart.CFrame = CFrame.new(pos) * rot
        camera.CFrame = freecamPart.CFrame
        -- держим персонажа на месте
        if root and root.Parent then
            root.AssemblyLinearVelocity = Vector3.zero
        end
    end)
end

H.createToggleRow(camTab, "Freecam (WASD + мышь, Shift быстрее)", 41, function(state)
    if state then startFreecam() else stopFreecam() end
end)

----------------------------------------------------------
-- ZOOM как в Minecraft (зажать клавишу)
----------------------------------------------------------
H.sectionLabel(camTab, "ZOOM (КАК В MINECRAFT)", 44)
local zoomOn = false
local zoomHeld = false
local zoomConn = nil
local zoomInputConn = nil
local zoomFov = 20 -- целевой FOV при зуме (как MC)
local zoomNormalFov = 70
local zoomKey = Enum.KeyCode.C
local zoomSmooth = 0 -- текущий 0..1

local function setZoomKeyFromName(name)
    local ok, key = pcall(function() return Enum.KeyCode[name] end)
    if ok and key then zoomKey = key end
end

H.createToggleRow(camTab, "Minecraft Zoom (зажать клавишу)", 45, function(state)
    zoomOn = state
    if zoomConn then zoomConn:Disconnect(); zoomConn = nil end
    if zoomInputConn then zoomInputConn:Disconnect(); zoomInputConn = nil end
    if not state then
        zoomHeld = false
        zoomSmooth = 0
        if not freecamOn then
            camera.FieldOfView = (H.fov and H.fov.Get and H.fov.Get()) or zoomNormalFov
        end
        return
    end
    zoomInputConn = UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == zoomKey then zoomHeld = true end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode == zoomKey then zoomHeld = false end
    end)
    zoomConn = RunService.RenderStepped:Connect(function(dt)
        if not zoomOn then return end
        local target = zoomHeld and 1 or 0
        zoomSmooth = zoomSmooth + (target - zoomSmooth) * math.min(1, dt * 12)
        local base = 70
        if H.fov and H.fov.Get then
            local ok, v = pcall(H.fov.Get)
            if ok and typeof(v) == "number" then base = v end
        end
        zoomNormalFov = base
        -- как в MC: сильное приближение
        local fov = base + (zoomFov - base) * zoomSmooth
        if not freecamOn then
            camera.FieldOfView = fov
        else
            camera.FieldOfView = fov
        end
    end)
end)
H.createSlider(camTab, "Zoom FOV (меньше = ближе)", 10, 40, 20, 46, function(v)
    zoomFov = v
end)
H.createButtonRow(camTab, {
    { text = "Клавиша C", callback = function() setZoomKeyFromName("C") end },
    { text = "Клавиша V", callback = function() setZoomKeyFromName("V") end },
    { text = "Клавиша Z", callback = function() setZoomKeyFromName("Z") end },
    { text = "LeftAlt", callback = function() setZoomKeyFromName("LeftAlt") end },
}, 47)

H.sectionLabel(camTab, "HIT EFFECT", 42)
local hitEffectOn = false
local hitConn = nil
H.createToggleRow(camTab, "Вспышка при получении урона", 43, function(state)
    hitEffectOn = state
    if hitConn then hitConn:Disconnect(); hitConn = nil end
    if not state then return end
    local function bind(char)
        local hum = char:WaitForChild("Humanoid", 5)
        if not hum then return end
        local last = hum.Health
        hitConn = hum.HealthChanged:Connect(function(hp)
            if not hitEffectOn then return end
            if hp < last then
                -- flash
                local cc = Instance.new("ColorCorrectionEffect")
                cc.Name = "__VM_HitFlash"
                cc.TintColor = Color3.fromRGB(255, 60, 60)
                cc.Brightness = 0.15
                cc.Contrast = 0.1
                cc.Parent = Lighting
                TweenService:Create(cc, TweenInfo.new(0.25), {Brightness = 0, Contrast = 0}):Play()
                task.delay(0.3, function() if cc then cc:Destroy() end end)
            end
            last = hp
        end)
    end
    if player.Character then bind(player.Character) end
    player.CharacterAdded:Connect(function(c)
        if hitConn then hitConn:Disconnect(); hitConn = nil end
        task.wait(0.3)
        if hitEffectOn then bind(c) end
    end)
end)


end

H.__build_ESP = function()
H.createTabButton("ESP", 12, CATEGORY_COLORS.Player)
espTab = H.createTabFrame("ESP")

H.sectionLabel(espTab, "БАЗОВЫЙ ESP", 1)
local nickEspEnabled = false
local tracersEnabled = false
local boxEspEnabled = false
local skeletonEspEnabled = false
local esp3dEnabled = false
local healthEspEnabled = false
local chamsEnabled = false
local arrowsEnabled = false
local killEffectEnabled = false
local hiddenPlayers = {}
local arrowFolder = nil


local espFolder = Instance.new("Folder")
espFolder.Name = "__VM_ESP"
espFolder.Parent = workspace
local espObjects = {}

local function clearEspFor(plr)
    local o = espObjects[plr]
    if not o then return end
    for _, k in ipairs({"bb", "beam", "att0", "att1", "hl", "bill3d", "hpBb", "chams"}) do
        if o[k] and o[k].Destroy then pcall(function() o[k]:Destroy() end) end
    end
    if o.bones then
        for _, b in pairs(o.bones) do
            if b and b.Destroy then pcall(function() b:Destroy() end) end
        end
    end
    espObjects[plr] = nil
end

local function setPlayerHidden(plr, hide)
    if not plr then return end
    hiddenPlayers[plr] = hide and true or nil
    local char = plr.Character
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            p.LocalTransparencyModifier = hide and 1 or 0
        elseif p:IsA("Decal") then
            p.Transparency = hide and 1 or 0
        end
    end
end

local function ensureEsp(plr)
    if plr == player then return end
    local char = plr.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    if hiddenPlayers[plr] then setPlayerHidden(plr, true) end

    local o = espObjects[plr]
    if not o then o = {}; espObjects[plr] = o end

    if nickEspEnabled and head then
        if not o.bb or not o.bb.Parent then
            local bb = Instance.new("BillboardGui")
            bb.Size = UDim2.new(0, 180, 0, 32)
            bb.StudsOffset = Vector3.new(0, 2.6, 0)
            bb.AlwaysOnTop = true
            bb.Adornee = head
            bb.Parent = espFolder
            local tl = Instance.new("TextLabel")
            tl.Size = UDim2.new(1, 0, 1, 0)
            tl.BackgroundTransparency = 1
            tl.Text = plr.DisplayName or plr.Name
            tl.TextColor3 = THEME.Accent
            tl.Font = Enum.Font.GothamBold
            tl.TextSize = 14
            tl.TextStrokeTransparency = 0.35
            tl.Parent = bb
            o.bb = bb
        else
            o.bb.Adornee = head
            o.bb.Enabled = true
        end
    elseif o.bb then o.bb.Enabled = false end

    if tracersEnabled then
        local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if myRoot then
            if not o.att0 or not o.att0.Parent then o.att0 = Instance.new("Attachment"); o.att0.Parent = myRoot
            else o.att0.Parent = myRoot end
            if not o.att1 or not o.att1.Parent then o.att1 = Instance.new("Attachment"); o.att1.Parent = root
            else o.att1.Parent = root end
            if not o.beam or not o.beam.Parent then
                local beam = Instance.new("Beam")
                beam.Attachment0 = o.att0
                beam.Attachment1 = o.att1
                beam.Width0 = 0.07
                beam.Width1 = 0.07
                beam.FaceCamera = true
                beam.Color = ColorSequence.new(THEME.Accent)
                beam.Transparency = NumberSequence.new(0.15, 0.55)
                beam.LightEmission = 0.85
                beam.Parent = espFolder
                o.beam = beam
            else
                o.beam.Enabled = true
                o.beam.Attachment0 = o.att0
                o.beam.Attachment1 = o.att1
            end
        end
    elseif o.beam then o.beam.Enabled = false end

    if boxEspEnabled then
        if not o.hl or not o.hl.Parent then
            local hl = Instance.new("Highlight")
            hl.Adornee = char
            hl.FillTransparency = 0.75
            hl.OutlineTransparency = 0
            hl.FillColor = THEME.Accent
            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
            hl.Parent = espFolder
            o.hl = hl
        else
            o.hl.Adornee = char
            o.hl.Enabled = true
        end
    elseif o.hl then o.hl.Enabled = false end

    if skeletonEspEnabled then
        local joints = {
            {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
            {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
            {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
            {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
            {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
            {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"}, {"Torso", "Left Leg"}, {"Torso", "Right Leg"},
        }
        if not o.bones then o.bones = {} end
        for i, pair in ipairs(joints) do
            local a = char:FindFirstChild(pair[1], true)
            local b = char:FindFirstChild(pair[2], true)
            if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
                local bone = o.bones[i]
                if not bone or not bone.Parent then
                    local att0 = Instance.new("Attachment"); att0.Parent = a
                    local att1 = Instance.new("Attachment"); att1.Parent = b
                    local beam = Instance.new("Beam")
                    beam.Attachment0 = att0
                    beam.Attachment1 = att1
                    beam.Width0 = 0.05
                    beam.Width1 = 0.05
                    beam.FaceCamera = true
                    beam.Color = ColorSequence.new(Color3.fromRGB(0, 255, 140))
                    beam.Transparency = NumberSequence.new(0.1)
                    beam.Parent = espFolder
                    o.bones[i] = beam
                else
                    bone.Enabled = true
                end
            end
        end
    elseif o.bones then
        for _, bone in pairs(o.bones) do if bone then bone.Enabled = false end end
    end

    if esp3dEnabled and head then
        if not o.bill3d or not o.bill3d.Parent then
            local bb = Instance.new("BillboardGui")
            bb.Size = UDim2.new(0, 140, 0, 50)
            bb.StudsOffset = Vector3.new(0, 3.2, 0)
            bb.AlwaysOnTop = true
            bb.Adornee = head
            bb.Parent = espFolder
            local bg = Instance.new("Frame")
            bg.Size = UDim2.new(1, 0, 1, 0)
            bg.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
            bg.BackgroundTransparency = 0.35
            bg.BorderSizePixel = 0
            bg.Parent = bb
            Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)
            local nameL = Instance.new("TextLabel")
            nameL.Size = UDim2.new(1, -8, 0, 22)
            nameL.Position = UDim2.new(0, 4, 0, 4)
            nameL.BackgroundTransparency = 1
            nameL.Text = plr.DisplayName or plr.Name
            nameL.TextColor3 = THEME.Accent
            nameL.Font = Enum.Font.GothamBold
            nameL.TextSize = 13
            nameL.Parent = bg
            local distL = Instance.new("TextLabel")
            distL.Name = "Dist"
            distL.Size = UDim2.new(1, -8, 0, 18)
            distL.Position = UDim2.new(0, 4, 0, 26)
            distL.BackgroundTransparency = 1
            distL.Text = "0m"
            distL.TextColor3 = THEME.SubText
            distL.Font = Enum.Font.Gotham
            distL.TextSize = 12
            distL.Parent = bg
            o.bill3d = bb
        else
            o.bill3d.Adornee = head
            o.bill3d.Enabled = true
            local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            local fr = o.bill3d:FindFirstChildWhichIsA("Frame")
            if myRoot and fr then
                local distL = fr:FindFirstChild("Dist")
                if distL then distL.Text = string.format("%dm", (root.Position - myRoot.Position).Magnitude) end
            end
        end
    elseif o.bill3d then o.bill3d.Enabled = false end

    -- Health ESP
    if healthEspEnabled and head then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            if not o.hpBb or not o.hpBb.Parent then
                local bb = Instance.new("BillboardGui")
                bb.Size = UDim2.new(0, 80, 0, 8)
                bb.StudsOffset = Vector3.new(0, 3.4, 0)
                bb.AlwaysOnTop = true
                bb.Adornee = head
                bb.Parent = espFolder
                local bg = Instance.new("Frame")
                bg.Size = UDim2.new(1, 0, 1, 0)
                bg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
                bg.BorderSizePixel = 0
                bg.Parent = bb
                Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)
                local fill = Instance.new("Frame")
                fill.Name = "Fill"
                fill.Size = UDim2.new(1, 0, 1, 0)
                fill.BackgroundColor3 = Color3.fromRGB(80, 255, 120)
                fill.BorderSizePixel = 0
                fill.Parent = bg
                Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
                o.hpBb = bb
            else
                o.hpBb.Adornee = head
                o.hpBb.Enabled = true
            end
            local fill = o.hpBb:FindFirstChildWhichIsA("Frame") and o.hpBb:FindFirstChildWhichIsA("Frame"):FindFirstChild("Fill")
            if fill then
                local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                fill.Size = UDim2.new(pct, 0, 1, 0)
                fill.BackgroundColor3 = Color3.fromRGB(255 * (1 - pct), 80 + 175 * pct, 80)
            end
        end
    elseif o.hpBb then o.hpBb.Enabled = false end

    -- Chams (full fill highlight)
    if chamsEnabled then
        if not o.chams or not o.chams.Parent then
            local hl = Instance.new("Highlight")
            hl.Name = "__VM_Chams"
            hl.Adornee = char
            hl.FillTransparency = 0.4
            hl.OutlineTransparency = 0.2
            hl.FillColor = THEME.Accent
            hl.OutlineColor = Color3.fromRGB(255, 255, 255)
            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            hl.Parent = espFolder
            o.chams = hl
        else
            o.chams.Adornee = char
            o.chams.Enabled = true
            o.chams.FillColor = THEME.Accent
        end
    elseif o.chams then o.chams.Enabled = false end
end

H.createToggleRow(espTab, "Nick ESP", 2, function(state) nickEspEnabled = state end)
H.createToggleRow(espTab, "Tracers ESP", 3, function(state) tracersEnabled = state end)
H.createToggleRow(espTab, "Box ESP (Highlight)", 4, function(state) boxEspEnabled = state end)
H.createToggleRow(espTab, "Skeleton ESP", 5, function(state) skeletonEspEnabled = state end)
H.createToggleRow(espTab, "3D ESP (имя + дистанция)", 6, function(state) esp3dEnabled = state end)
H.createToggleRow(espTab, "Health ESP (полоска HP)", 7, function(state) healthEspEnabled = state end)
H.createToggleRow(espTab, "Chams (заливка модели)", 8, function(state) chamsEnabled = state end)
H.createToggleRow(espTab, "Off-screen arrows", 9, function(state)
    arrowsEnabled = state
    if not state and arrowFolder then
        for _, c in ipairs(arrowFolder:GetChildren()) do c:Destroy() end
    end
end)

H.sectionLabel(espTab, "СКРЫТЬ ИГРОКА (ТОЛЬКО У СЕБЯ)", 10)
local hideList = Instance.new("ScrollingFrame")
hideList.Size = UDim2.new(1, 0, 0, 100)
hideList.BackgroundColor3 = THEME.Panel
hideList.BorderSizePixel = 0
hideList.ScrollBarThickness = 3
hideList.AutomaticCanvasSize = Enum.AutomaticSize.Y
hideList.CanvasSize = UDim2.new(0, 0, 0, 0)
hideList.LayoutOrder = 11
hideList.Parent = espTab
Instance.new("UICorner", hideList).CornerRadius = UDim.new(0, 8)
Instance.new("UIListLayout", hideList).Padding = UDim.new(0, 4)

local function refreshHideList()
    for _, c in ipairs(hideList:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -8, 0, 26)
            btn.BackgroundColor3 = hiddenPlayers[plr] and Color3.fromRGB(60, 30, 40) or THEME.Background
            btn.Text = (hiddenPlayers[plr] and "[СКРЫТ] " or "") .. (plr.DisplayName or plr.Name)
            btn.TextColor3 = THEME.Text
            btn.Font = Enum.Font.Gotham
            btn.TextSize = 12
            btn.AutoButtonColor = false
            btn.Parent = hideList
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
            btn.MouseButton1Click:Connect(function()
                playGuiClick(btn)
                setPlayerHidden(plr, not hiddenPlayers[plr])
                refreshHideList()
            end)
        end
    end
end
H.createButtonRow(espTab, {
    { text = "Обновить список", callback = refreshHideList },
    { text = "Показать всех", callback = function()
        for plr in pairs(hiddenPlayers) do setPlayerHidden(plr, false) end
        hiddenPlayers = {}
        refreshHideList()
    end },
}, 12)
refreshHideList()
Players.PlayerAdded:Connect(function() task.defer(refreshHideList) end)
Players.PlayerRemoving:Connect(function(plr)
    hiddenPlayers[plr] = nil
    task.defer(refreshHideList)
end)

H.sectionLabel(espTab, "ЭФФЕКТ ПРИ СМЕРТИ", 13)
H.createToggleRow(espTab, "Эффект когда кто-то умирает рядом", 14, function(state)
    killEffectEnabled = state
end)

local function playKillEffect(pos)
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.Size = Vector3.new(1, 1, 1)
    part.Position = pos
    part.Parent = workspace
    local em = Instance.new("ParticleEmitter")
    em.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    em.Rate = 0
    em.Lifetime = NumberRange.new(0.4, 0.9)
    em.Speed = NumberRange.new(8, 18)
    em.Size = NumberSequence.new(0.6, 0)
    em.Color = ColorSequence.new(THEME.Accent, Color3.fromRGB(255, 80, 80))
    em.LightEmission = 1
    em.SpreadAngle = Vector2.new(180, 180)
    em.Parent = part
    em:Emit(40)
    local ring = Instance.new("Part")
    ring.Anchored = true
    ring.CanCollide = false
    ring.Material = Enum.Material.Neon
    ring.Color = THEME.Accent
    ring.Size = Vector3.new(0.2, 0.2, 0.2)
    ring.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
    ring.Parent = workspace
    local mesh = Instance.new("SpecialMesh")
    mesh.MeshType = Enum.MeshType.Cylinder
    mesh.Parent = ring
    task.spawn(function()
        for i = 1, 12 do
            mesh.Scale = Vector3.new(0.05, i * 1.2, i * 1.2)
            ring.Transparency = i / 12
            task.wait(0.03)
        end
        ring:Destroy()
        task.wait(0.5)
        part:Destroy()
    end)
end

local function bindKillEffect(plr)
    local function hook(char)
        local hum = char:WaitForChild("Humanoid", 5)
        if not hum then return end
        hum.Died:Connect(function()
            if not killEffectEnabled then return end
            local root = char:FindFirstChild("HumanoidRootPart")
            local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if root and myRoot and (root.Position - myRoot.Position).Magnitude < 250 then
                playKillEffect(root.Position)
            end
        end)
    end
    if plr.Character then hook(plr.Character) end
    plr.CharacterAdded:Connect(hook)
end
for _, plr in ipairs(Players:GetPlayers()) do bindKillEffect(plr) end
Players.PlayerAdded:Connect(bindKillEffect)

RunService.Heartbeat:Connect(function()
    if not (nickEspEnabled or tracersEnabled or boxEspEnabled or skeletonEspEnabled or esp3dEnabled or healthEspEnabled or chamsEnabled or arrowsEnabled) then return end
    local seen = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            seen[plr] = true
            ensureEsp(plr)
        end
    end
    for plr in pairs(espObjects) do
        if not seen[plr] then clearEspFor(plr) end
    end
    -- Off-screen arrows
    if arrowsEnabled then
        if not arrowFolder then
            arrowFolder = Instance.new("ScreenGui")
            arrowFolder.Name = "__VM_Arrows"
            arrowFolder.ResetOnSpawn = false
            arrowFolder.IgnoreGuiInset = true
            arrowFolder.DisplayOrder = 85
            arrowFolder.Parent = game:GetService("CoreGui")
        end
        local used = {}
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                local root = plr.Character.HumanoidRootPart
                local screen, onScreen = camera:WorldToViewportPoint(root.Position)
                if not onScreen or screen.Z < 0 then
                    local vp = camera.ViewportSize
                    local cx, cy = vp.X / 2, vp.Y / 2
                    local dir = Vector2.new(screen.X - cx, screen.Y - cy)
                    if screen.Z < 0 then dir = -dir end
                    if dir.Magnitude < 1 then dir = Vector2.new(0, -1) end
                    dir = dir.Unit
                    local edge = math.min(vp.X, vp.Y) * 0.42
                    local pos = Vector2.new(cx, cy) + dir * edge
                    local arrow = arrowFolder:FindFirstChild(plr.Name)
                    if not arrow then
                        arrow = Instance.new("TextLabel")
                        arrow.Name = plr.Name
                        arrow.Size = UDim2.new(0, 24, 0, 24)
                        arrow.BackgroundTransparency = 1
                        arrow.Text = "▼"
                        arrow.TextColor3 = THEME.Accent
                        arrow.Font = Enum.Font.GothamBold
                        arrow.TextSize = 22
                        arrow.TextStrokeTransparency = 0.4
                        arrow.Parent = arrowFolder
                    end
                    arrow.Visible = true
                    arrow.Position = UDim2.new(0, pos.X - 12, 0, pos.Y - 12)
                    local ang = math.deg(math.atan2(dir.Y, dir.X)) + 90
                    arrow.Rotation = ang
                    used[plr.Name] = true
                end
            end
        end
        for _, c in ipairs(arrowFolder:GetChildren()) do
            if not used[c.Name] then c.Visible = false end
        end
    elseif arrowFolder then
        for _, c in ipairs(arrowFolder:GetChildren()) do c.Visible = false end
    end
end)
Players.PlayerRemoving:Connect(clearEspFor)

end -- конец __build_ESP

----------------------------------------------------------
-- ВКЛАДКА: ТРОЛЛИНГ (крутилка персонажа)
----------------------------------------------------------
H.__build_Trolling = function()
H.createTabButton("Троллинг", 15, CATEGORY_COLORS.Player)
trollTab = H.createTabFrame("Троллинг")

H.sectionLabel(trollTab, "КРУТИЛКА (ВРАЩЕНИЕ ПЕРСОНАЖА)", 1)

local spinEnabled = false
local spinSpeed = 40          -- 1–200, множитель для °/с
local spinConn = nil
local spinAngle = 0

local function stopSpin()
    spinEnabled = false
    if spinConn then
        spinConn:Disconnect()
        spinConn = nil
    end
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if root then
        pcall(function()
            root.AssemblyAngularVelocity = Vector3.zero
        end)
    end
end

local function startSpin()
    stopSpin()
    spinEnabled = true
    spinAngle = 0
    spinConn = RunService.Heartbeat:Connect(function(dt)
        if not spinEnabled then return end
        local char = player.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not root then return end

        -- spinSpeed 1..200 → ~72°/с .. ~14400°/с (очень быстро на максимуме)
        local degPerSec = spinSpeed * 72
        spinAngle = (spinAngle + degPerSec * dt) % 360

        local pos = root.Position
        root.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(spinAngle), 0)
        root.AssemblyAngularVelocity = Vector3.zero

        if hum then
            hum.AutoRotate = false
        end
    end)
end

H.spinToggle = H.createToggleRow(trollTab, "Включить крутилку", 2, function(state)
    if state then
        startSpin()
    else
        stopSpin()
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.AutoRotate = true
        end
    end
end)

H.spinSpeed = H.createSlider(trollTab, "Скорость вращения (1–200)", 1, 200, 40, 3, function(v)
    spinSpeed = v
end)

H.sectionLabel(trollTab, "ПОДСКАЗКА", 4)
local tip = Instance.new("TextLabel")
tip.Size = UDim2.new(1, 0, 0, 36)
tip.BackgroundTransparency = 1
tip.TextWrapped = true
tip.Text = "Крутилка вращает персонажа вокруг вертикальной оси. Скорость 1–200. При выключении AutoRotate возвращается."
tip.TextColor3 = THEME.SubText
tip.Font = Enum.Font.Gotham
tip.TextSize = 11
tip.TextXAlignment = Enum.TextXAlignment.Left
tip.TextYAlignment = Enum.TextYAlignment.Top
tip.LayoutOrder = 5
tip.Parent = trollTab

----------------------------------------------------------
-- УСКОРЕНИЕ (WALKSPEED)
----------------------------------------------------------
H.sectionLabel(trollTab, "УСКОРЕНИЕ (SPEED)", 6)
local customSpeed = 16
local speedEnabled = false

local function applyWalkSpeed(v)
    local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = v
    end
end

H.speedToggle = H.createToggleRow(trollTab, "Включить свой Speed", 7, function(state)
    speedEnabled = state
    if state then
        applyWalkSpeed(customSpeed)
    else
        applyWalkSpeed(16)
    end
end)

H.speedSlider = H.createSlider(trollTab, "WalkSpeed", 1, 200, 16, 8, function(v)
    customSpeed = v
    if speedEnabled then applyWalkSpeed(v) end
end)

H.createButtonRow(trollTab, {
    { text = "16", callback = function() if H.speedSlider then H.speedSlider.Set(16) end end },
    { text = "50", callback = function() if H.speedSlider then H.speedSlider.Set(50) end end },
    { text = "100", callback = function() if H.speedSlider then H.speedSlider.Set(100) end end },
    { text = "200", callback = function() if H.speedSlider then H.speedSlider.Set(200) end end },
}, 9)

player.CharacterAdded:Connect(function(c)
    task.wait(0.3)
    if speedEnabled then
        applyWalkSpeed(customSpeed)
    end
end)

----------------------------------------------------------
-- NOCLIP
----------------------------------------------------------
H.sectionLabel(trollTab, "NOCLIP", 9.5)
local noclipEnabled = false
local noclipConn = nil

local function setNoclip(state)
    noclipEnabled = state
    if noclipConn then
        noclipConn:Disconnect()
        noclipConn = nil
    end
    if not state then return end
    noclipConn = RunService.Stepped:Connect(function()
        if not noclipEnabled then return end
        local char = player.Character
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end)
end

H.noclipToggle = H.createToggleRow(trollTab, "Noclip (проходить сквозь стены)", 9.6, function(state)
    setNoclip(state)
end)

player.CharacterAdded:Connect(function()
    task.wait(0.2)
    if noclipEnabled then setNoclip(true) end
end)

----------------------------------------------------------
-- ТЕЛЕПОРТ К ИГРОКУ
----------------------------------------------------------
H.sectionLabel(trollTab, "ТЕЛЕПОРТ К ИГРОКУ", 10)

local tpList = Instance.new("ScrollingFrame")
tpList.Size = UDim2.new(1, 0, 0, 140)
tpList.BackgroundColor3 = THEME.Panel
tpList.BorderSizePixel = 0
tpList.ScrollBarThickness = 3
tpList.ScrollBarImageColor3 = THEME.Accent
tpList.CanvasSize = UDim2.new(0, 0, 0, 0)
tpList.AutomaticCanvasSize = Enum.AutomaticSize.Y
tpList.LayoutOrder = 11
tpList.Parent = trollTab
Instance.new("UICorner", tpList).CornerRadius = UDim.new(0, 8)
local tpLayout = Instance.new("UIListLayout")
tpLayout.Padding = UDim.new(0, 4)
tpLayout.Parent = tpList
local tpPad = Instance.new("UIPadding")
tpPad.PaddingTop = UDim.new(0, 4)
tpPad.PaddingLeft = UDim.new(0, 4)
tpPad.PaddingRight = UDim.new(0, 4)
tpPad.PaddingBottom = UDim.new(0, 4)
tpPad.Parent = tpList

local selectedTpPlayer = nil
local tpStatus = Instance.new("TextLabel")
tpStatus.Size = UDim2.new(1, 0, 0, 16)
tpStatus.BackgroundTransparency = 1
tpStatus.Text = "Выберите игрока из списка"
tpStatus.TextColor3 = THEME.SubText
tpStatus.Font = Enum.Font.Gotham
tpStatus.TextSize = 12
tpStatus.TextXAlignment = Enum.TextXAlignment.Left
tpStatus.LayoutOrder = 12
tpStatus.Parent = trollTab

local function teleportToPlayer(plr)
    if not plr then return end
    local target = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not (target and root) then
        tpStatus.Text = "Нет персонажа"
        tpStatus.TextColor3 = THEME.Error
        return
    end
    root.CFrame = target.CFrame * CFrame.new(0, 0, 3)
    tpStatus.Text = "ТП к @" .. plr.Name
    tpStatus.TextColor3 = THEME.Success
end

local function refreshTpList()
    for _, c in ipairs(tpList:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -8, 0, 28)
            btn.BackgroundColor3 = (selectedTpPlayer == plr) and THEME.AccentSoft or THEME.Background
            btn.Text = "  " .. (plr.DisplayName or plr.Name) .. "  (@" .. plr.Name .. ")"
            btn.TextColor3 = THEME.Text
            btn.Font = Enum.Font.GothamMedium
            btn.TextSize = 12
            btn.TextXAlignment = Enum.TextXAlignment.Left
            btn.AutoButtonColor = false
            btn.Parent = tpList
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
            btn.MouseButton1Click:Connect(function()
                playGuiClick(btn)
                selectedTpPlayer = plr
                tpStatus.Text = "Выбран: @" .. plr.Name
                tpStatus.TextColor3 = THEME.Accent
                refreshTpList()
            end)
        end
    end
end

H.createButtonRow(trollTab, {
    { text = "Обновить список", callback = refreshTpList },
    { text = "ТП к выбранному", callback = function()
        if selectedTpPlayer then
            teleportToPlayer(selectedTpPlayer)
        else
            tpStatus.Text = "Сначала выберите игрока"
            tpStatus.TextColor3 = THEME.Error
        end
    end },
}, 13)

H.createButtonRow(trollTab, {
    { text = "ТП к ближайшему", callback = function()
        local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not myRoot then return end
        local best, bestDist = nil, math.huge
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= player and plr.Character then
                local r = plr.Character:FindFirstChild("HumanoidRootPart")
                if r then
                    local d = (r.Position - myRoot.Position).Magnitude
                    if d < bestDist then bestDist = d; best = plr end
                end
            end
        end
        if best then
            selectedTpPlayer = best
            teleportToPlayer(best)
            refreshTpList()
        end
    end },
}, 14)

refreshTpList()
Players.PlayerAdded:Connect(function() task.defer(refreshTpList) end)
Players.PlayerRemoving:Connect(function(plr)
    if selectedTpPlayer == plr then selectedTpPlayer = nil end
    task.defer(refreshTpList)
end)

----------------------------------------------------------
-- ДВОЙНОЙ КЛИК ПО ИГРОКУ → INFO CARD (ScreenGui, клики стабильны)
----------------------------------------------------------
H.sectionLabel(trollTab, "ИНФО ОБ ИГРОКЕ (ДВОЙНОЙ КЛИК)", 16)

local inspectEnabled = true
local inspectScreen = nil
local inspectCardFrame = nil
local inspectTargetPlr = nil
local inspectTrackConn = nil
local lastClickPlr = nil
local lastClickTime = 0
local DOUBLE_CLICK_SEC = 0.4
local inspectOpenedAt = 0

local function clearInspectCard()
    if inspectTrackConn then
        inspectTrackConn:Disconnect()
        inspectTrackConn = nil
    end
    if inspectScreen then
        pcall(function() inspectScreen:Destroy() end)
    end
    inspectScreen = nil
    inspectCardFrame = nil
    inspectTargetPlr = nil
end

local function formatAccountAge(days)
    if not days or days < 0 then return "?" end
    if days < 30 then return tostring(days) .. " дн." end
    if days < 365 then return string.format("%.1f мес.", days / 30) end
    return string.format("%.1f лет", days / 365)
end

local function membershipName(mt)
    if mt == Enum.MembershipType.Premium then return "Premium"
    elseif mt == Enum.MembershipType.OutrageousBuildersClub then return "OBC"
    elseif mt == Enum.MembershipType.TurboBuildersClub then return "TBC"
    elseif mt == Enum.MembershipType.BuildersClub then return "BC"
    end
    return "None"
end

local function isPointOverGui(frame, mpos)
    if not frame or not frame.Parent then return false end
    local abs = frame.AbsolutePosition
    local asz = frame.AbsoluteSize
    return mpos.X >= abs.X and mpos.X <= abs.X + asz.X and mpos.Y >= abs.Y and mpos.Y <= abs.Y + asz.Y
end

local function showInspectCard(plr)
    clearInspectCard()
    if not plr or not plr.Character then return end
    local head = plr.Character:FindFirstChild("Head")
    local root = plr.Character:FindFirstChild("HumanoidRootPart")
    local hum = plr.Character:FindFirstChildOfClass("Humanoid")
    if not (head or root) then return end

    inspectTargetPlr = plr
    inspectOpenedAt = os.clock()

    local sg = Instance.new("ScreenGui")
    sg.Name = "__VM_InspectCard"
    sg.ResetOnSpawn = false
    sg.IgnoreGuiInset = true
    sg.DisplayOrder = 200
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = game:GetService("CoreGui")
    inspectScreen = sg

    local card = Instance.new("Frame")
    card.Name = "Card"
    card.Size = UDim2.new(0, 280, 0, 320)
    card.AnchorPoint = Vector2.new(0.5, 1)
    card.BackgroundColor3 = Color3.fromRGB(12, 10, 20)
    card.BackgroundTransparency = 0.05
    card.BorderSizePixel = 0
    card.Active = true
    card.Parent = sg
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 14)
    inspectCardFrame = card

    local stroke = Instance.new("UIStroke", card)
    stroke.Color = THEME.Accent
    stroke.Thickness = 1.8
    stroke.Transparency = 0.1

    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 4)
    topBar.BackgroundColor3 = THEME.Accent
    topBar.BorderSizePixel = 0
    topBar.Parent = card
    Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 14)

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 14)
    pad.PaddingLeft = UDim.new(0, 14)
    pad.PaddingRight = UDim.new(0, 14)
    pad.PaddingBottom = UDim.new(0, 12)
    pad.Parent = card

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 3)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = card

    local function line(text, size, color, order, bold)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, size + 3)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = color or THEME.Text
        lbl.Font = bold and Enum.Font.GothamBold or Enum.Font.GothamMedium
        lbl.TextSize = size
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextTruncate = Enum.TextTruncate.AtEnd
        lbl.LayoutOrder = order
        lbl.Parent = card
        return lbl
    end

    line(plr.DisplayName or plr.Name, 18, THEME.Accent, 1, true)
    line("@" .. plr.Name, 13, THEME.SubText, 2, false)

    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(1, 0, 0, 1)
    sep.BackgroundColor3 = Color3.fromRGB(60, 50, 90)
    sep.BorderSizePixel = 0
    sep.LayoutOrder = 3
    sep.Parent = card

    line("UserId: " .. tostring(plr.UserId), 12, THEME.Text, 4, false)
    line("Возраст аккаунта: " .. formatAccountAge(plr.AccountAge), 12, THEME.Text, 5, false)
    line("Premium: " .. membershipName(plr.MembershipType), 12, THEME.Text, 6, false)

    local hpText = "HP: —"
    local speedText = "WalkSpeed: —"
    local jumpText = "Jump: —"
    local toolText = "Tool: —"
    if hum then
        hpText = string.format("HP: %.0f / %.0f", hum.Health, hum.MaxHealth)
        speedText = string.format("WalkSpeed: %.1f", hum.WalkSpeed)
        pcall(function()
            jumpText = string.format("JumpPower: %.0f", hum.JumpPower)
        end)
    end
    if plr.Character then
        local tool = plr.Character:FindFirstChildOfClass("Tool")
        if tool then toolText = "Tool: " .. tool.Name end
    end
    line(hpText, 12, THEME.Success, 7, false)
    line(speedText, 12, THEME.SubText, 8, false)
    line(jumpText, 12, THEME.SubText, 9, false)
    line(toolText, 12, THEME.SubText, 10, false)

    local teamName = plr.Team and ("Team: " .. plr.Team.Name) or "Team: —"
    line(teamName, 12, THEME.SubText, 11, false)

    local distLbl = line("Dist: —", 12, THEME.SubText, 12, false)
    local friendLbl = line("Друг: …", 12, THEME.SubText, 13, false)
    local statusLbl = line("Status: " .. (plr:GetAttribute("Status") and tostring(plr:GetAttribute("Status")) or "—"), 12, THEME.SubText, 14, false)

    task.spawn(function()
        local ok, isFriend = pcall(function()
            return player:IsFriendsWith(plr.UserId)
        end)
        if friendLbl and friendLbl.Parent then
            friendLbl.Text = "Друг: " .. ((ok and isFriend) and "Да" or "Нет")
            friendLbl.TextColor3 = (ok and isFriend) and THEME.Success or THEME.SubText
        end
    end)

    local btnRow = Instance.new("Frame")
    btnRow.Size = UDim2.new(1, 0, 0, 30)
    btnRow.BackgroundTransparency = 1
    btnRow.LayoutOrder = 20
    btnRow.Parent = card
    local btnLayout = Instance.new("UIListLayout")
    btnLayout.FillDirection = Enum.FillDirection.Horizontal
    btnLayout.Padding = UDim.new(0, 6)
    btnLayout.Parent = btnRow

    local function smallBtn(text, cb)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0.5, -3, 1, 0)
        b.BackgroundColor3 = THEME.Panel
        b.Text = text
        b.TextColor3 = THEME.Text
        b.Font = Enum.Font.GothamBold
        b.TextSize = 12
        b.AutoButtonColor = false
        b.Active = true
        b.Selectable = true
        b.ZIndex = 5
        b.Parent = btnRow
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        -- Activated надёжнее, чем MouseButton1Click на части клиентов
        b.Activated:Connect(function()
            playGuiClick(b)
            if cb then cb() end
        end)
        b.MouseButton1Click:Connect(function()
            playGuiClick(b)
            if cb then cb() end
        end)
        return b
    end

    smallBtn("Профиль", function()
        local url = "https://www.roblox.com/users/" .. tostring(plr.UserId) .. "/profile"
        pcall(function()
            if typeof(setclipboard) == "function" then setclipboard(url) end
        end)
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = "Профиль",
                Text = "Ссылка скопирована",
                Duration = 3,
            })
        end)
    end)

    smallBtn("Закрыть", function()
        clearInspectCard()
    end)

    -- следим за позицией над головой
    inspectTrackConn = RunService.RenderStepped:Connect(function()
        if not inspectScreen or not card.Parent then return end
        local target = inspectTargetPlr
        if not target or not target.Character then
            clearInspectCard()
            return
        end
        local h = target.Character:FindFirstChild("Head") or target.Character:FindFirstChild("HumanoidRootPart")
        if not h then return end
        local pos, onScreen = camera:WorldToViewportPoint(h.Position + Vector3.new(0, 2.2, 0))
        if onScreen and pos.Z > 0 then
            card.Visible = true
            card.Position = UDim2.new(0, pos.X, 0, pos.Y)
        else
            card.Visible = false
        end
        local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local theirRoot = target.Character:FindFirstChild("HumanoidRootPart")
        if myRoot and theirRoot and distLbl and distLbl.Parent then
            distLbl.Text = string.format("Dist: %.0f studs", (myRoot.Position - theirRoot.Position).Magnitude)
        end
        local th = target.Character:FindFirstChildOfClass("Humanoid")
        if th then
            -- live HP not needed every frame on static labels
        end
    end)

    task.delay(20, function()
        if inspectScreen == sg then clearInspectCard() end
    end)
end

local function getPlayerUnderMouse()
    local mouse = player:GetMouse()
    if not mouse then return nil end
    local target = mouse.Target
    if not target then return nil end
    local model = target:FindFirstAncestorOfClass("Model")
    if not model then return nil end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum then return nil end
    return Players:GetPlayerFromCharacter(model)
end

H.inspectToggle = H.createToggleRow(trollTab, "Двойной клик по игроку → инфо-карточка", 7, function(state)
    inspectEnabled = state
    if not state then clearInspectCard() end
end, true)

UserInputService.InputBegan:Connect(function(input, gp)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    local mpos = UserInputService:GetMouseLocation()

    -- клики по самой карточке не считаем за double-click по миру
    if inspectCardFrame and isPointOverGui(inspectCardFrame, mpos) then
        return
    end
    if gp then return end
    if not inspectEnabled then return end

    if menuOpen and MainFrame and MainFrame.Visible then
        local abs = MainFrame.AbsolutePosition
        local asz = MainFrame.AbsoluteSize
        if mpos.X >= abs.X and mpos.X <= abs.X + asz.X and mpos.Y >= abs.Y and mpos.Y <= abs.Y + asz.Y then
            return
        end
    end

    -- не открываем новую карточку сразу после открытия (анти-даблклик по кнопкам)
    if inspectScreen and (os.clock() - inspectOpenedAt) < 0.25 then
        return
    end

    local plr = getPlayerUnderMouse()
    if not plr or plr == player then return end

    local now = os.clock()
    if lastClickPlr == plr and (now - lastClickTime) <= DOUBLE_CLICK_SEC then
        lastClickPlr = nil
        lastClickTime = 0
        showInspectCard(plr)
        playGuiClick()
    else
        lastClickPlr = plr
        lastClickTime = now
    end
end)

Players.PlayerRemoving:Connect(function(plr)
    if lastClickPlr == plr then lastClickPlr = nil end
    if inspectTargetPlr == plr then clearInspectCard() end
end)

-- при респавне перезапускаем крутилку
player.CharacterAdded:Connect(function()
    task.wait(0.4)
    if spinEnabled then
        startSpin()
    end
end)

----------------------------------------------------------
-- AIMBOT
----------------------------------------------------------
H.sectionLabel(trollTab, "AIMBOT", 30)

local aimbotEnabled = false
local aimbotConn = nil
local aimbotFov = 120          -- градусы конуса
local aimbotSmooth = 0.35      -- 0 = мгновенно, 1 = очень плавно
local aimbotTeamCheck = true
local aimbotPart = "Head"      -- Head | HumanoidRootPart
local aimbotWallCheck = false
local aimbotMaxDist = 400      -- studs
local aimbotMinDist = 0
local aimbotSticky = true      -- держать текущую цель пока в FOV/дистанции
local aimbotRequireHold = false
local aimbotHoldKey = Enum.KeyCode.E
local aimbotCurrentTarget = nil
local aimbotStatus = Instance.new("TextLabel")
aimbotStatus.Size = UDim2.new(1, 0, 0, 18)
aimbotStatus.BackgroundTransparency = 1
aimbotStatus.Text = "Aimbot: выкл"
aimbotStatus.TextColor3 = THEME.SubText
aimbotStatus.Font = Enum.Font.Gotham
aimbotStatus.TextSize = 12
aimbotStatus.TextXAlignment = Enum.TextXAlignment.Left
aimbotStatus.LayoutOrder = 39
aimbotStatus.Parent = trollTab

local function isEnemy(plr)
    if not plr or plr == player then return false end
    if not aimbotTeamCheck then return true end
    if not player.Team or not plr.Team then return true end
    return plr.Team ~= player.Team
end

local function hasLineOfSight(fromPos, toPos, targetChar)
    if not aimbotWallCheck then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local exclude = { player.Character }
    if targetChar then table.insert(exclude, targetChar) end
    params.FilterDescendantsInstances = exclude
    local dir = toPos - fromPos
    local result = workspace:Raycast(fromPos, dir, params)
    return result == nil
end

local function getTargetPart(plr)
    local char = plr.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return nil end
    return char:FindFirstChild(aimbotPart)
        or char:FindFirstChild("Head")
        or char:FindFirstChild("HumanoidRootPart")
end

local function isValidTargetPart(part)
    if not part or not part.Parent then return false end
    local char = part.Parent
    if not char then return false end
    local plr = Players:GetPlayerFromCharacter(char)
    if not isEnemy(plr) then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if not camera then return false end
    local dist = (part.Position - camera.CFrame.Position).Magnitude
    if dist < aimbotMinDist or dist > aimbotMaxDist then return false end
    local toTarget = (part.Position - camera.CFrame.Position)
    if toTarget.Magnitude < 1 then return false end
    local ang = math.acos(math.clamp(camera.CFrame.LookVector:Dot(toTarget.Unit), -1, 1))
    if ang > math.rad(aimbotFov) then return false end
    if not hasLineOfSight(camera.CFrame.Position, part.Position, char) then return false end
    return true
end

local function getClosestEnemy()
    if not camera then return nil end
    -- sticky: если текущая цель ещё валидна — оставляем
    if aimbotSticky and aimbotCurrentTarget and isValidTargetPart(aimbotCurrentTarget) then
        return aimbotCurrentTarget
    end
    aimbotCurrentTarget = nil

    local best, bestScore = nil, math.huge
    local camCF = camera.CFrame
    local look = camCF.LookVector

    for _, plr in ipairs(Players:GetPlayers()) do
        if isEnemy(plr) then
            local part = getTargetPart(plr)
            if part then
                local toTarget = (part.Position - camCF.Position)
                local dist = toTarget.Magnitude
                if dist >= aimbotMinDist and dist <= aimbotMaxDist and dist > 1 then
                    local dir = toTarget.Unit
                    local ang = math.acos(math.clamp(look:Dot(dir), -1, 1))
                    if ang <= math.rad(aimbotFov) and hasLineOfSight(camCF.Position, part.Position, plr.Character) then
                        -- score: угол важнее + лёгкий вес дистанции
                        local score = ang * 2 + (dist / math.max(aimbotMaxDist, 1)) * 0.5
                        if score < bestScore then
                            bestScore = score
                            best = part
                        end
                    end
                end
            end
        end
    end
    aimbotCurrentTarget = best
    return best
end

local function setAimbot(state)
    aimbotEnabled = state
    aimbotCurrentTarget = nil
    if aimbotConn then aimbotConn:Disconnect(); aimbotConn = nil end
    if not state then
        aimbotStatus.Text = "Aimbot: выкл"
        aimbotStatus.TextColor3 = THEME.SubText
        return
    end
    aimbotStatus.Text = "Aimbot: вкл"
    aimbotStatus.TextColor3 = THEME.Success
    aimbotConn = RunService.RenderStepped:Connect(function(dt)
        if not aimbotEnabled then return end
        if menuOpen and MainFrame and MainFrame.Visible then return end
        if aimbotRequireHold and not UserInputService:IsKeyDown(aimbotHoldKey) then
            aimbotStatus.Text = "Aimbot: жди " .. aimbotHoldKey.Name
            return
        end
        local target = getClosestEnemy()
        if not target or not camera then
            aimbotStatus.Text = "Aimbot: нет цели"
            aimbotStatus.TextColor3 = THEME.SubText
            return
        end
        local dist = (target.Position - camera.CFrame.Position).Magnitude
        local plr = Players:GetPlayerFromCharacter(target.Parent)
        aimbotStatus.Text = string.format("Aim → %s (%.0f st)", plr and (plr.DisplayName or plr.Name) or "?", dist)
        aimbotStatus.TextColor3 = THEME.Success
        local goal = CFrame.new(camera.CFrame.Position, target.Position)
        local alpha = math.clamp(1 - aimbotSmooth, 0.05, 1)
        alpha = math.clamp(alpha * (dt * 60), 0.05, 1)
        camera.CFrame = camera.CFrame:Lerp(goal, alpha)
    end)
end

H.aimbotToggle = H.createToggleRow(trollTab, "Включить Aimbot", 31, function(state)
    setAimbot(state)
end)

H.createToggleRow(trollTab, "Team check (не целиться в тиму)", 32, function(state)
    aimbotTeamCheck = state
end, true)

H.createToggleRow(trollTab, "Wall check (не через стены)", 33, function(state)
    aimbotWallCheck = state
end, false)

H.createToggleRow(trollTab, "Sticky aim (держать цель)", 34, function(state)
    aimbotSticky = state
end, true)

H.createToggleRow(trollTab, "Только с зажатой клавишей (E)", 35, function(state)
    aimbotRequireHold = state
end, false)

H.aimbotFov = H.createSlider(trollTab, "FOV aimbot (градусы)", 10, 180, 120, 36, function(v)
    aimbotFov = v
end)

H.aimbotMaxDist = H.createSlider(trollTab, "Макс. дистанция (studs)", 50, 2000, 400, 37, function(v)
    aimbotMaxDist = v
end)

H.aimbotMinDist = H.createSlider(trollTab, "Мин. дистанция (studs)", 0, 100, 0, 38, function(v)
    aimbotMinDist = v
end)

H.aimbotSmooth = H.createSlider(trollTab, "Плавность (0=жёстко, 100=мягко)", 0, 100, 35, 39, function(v)
    aimbotSmooth = v / 100
end)

H.createButtonRow(trollTab, {
    { text = "Цель: Head", callback = function() aimbotPart = "Head" end },
    { text = "Цель: Torso", callback = function() aimbotPart = "HumanoidRootPart" end },
}, 40)

----------------------------------------------------------
-- СМЕНА СЕРВЕРА
----------------------------------------------------------
H.sectionLabel(trollTab, "СМЕНА СЕРВЕРА", 50)

local serverStatus = Instance.new("TextLabel")
serverStatus.Size = UDim2.new(1, 0, 0, 18)
serverStatus.BackgroundTransparency = 1
serverStatus.TextWrapped = true
serverStatus.Text = "JobId: " .. tostring(game.JobId)
serverStatus.TextColor3 = THEME.SubText
serverStatus.Font = Enum.Font.Gotham
serverStatus.TextSize = 11
serverStatus.TextXAlignment = Enum.TextXAlignment.Left
serverStatus.LayoutOrder = 54
serverStatus.Parent = trollTab

local function hopSamePlace()
    serverStatus.Text = "Телепорт на другой сервер..."
    serverStatus.TextColor3 = THEME.Accent
    -- простой hop: Teleport в тот же PlaceId (Roblox подберёт сервер)
    local ok, err = pcall(function()
        TeleportService:Teleport(game.PlaceId, player)
    end)
    if not ok then
        serverStatus.Text = "Ошибка: " .. tostring(err)
        serverStatus.TextColor3 = THEME.Error
    end
end

local function hopLowestPlayers()
    serverStatus.Text = "Ищем сервер..."
    serverStatus.TextColor3 = THEME.Accent
    task.spawn(function()
        local url = string.format(
            "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=25",
            game.PlaceId
        )
        local body
        -- request / http_request / syn.request / HttpService (если разрешён)
        local reqFn = (syn and syn.request) or (http and http.request) or http_request or request
        if typeof(reqFn) == "function" then
            local ok, res = pcall(function()
                return reqFn({ Url = url, Method = "GET" })
            end)
            if ok and res then
                body = res.Body or res.body
            end
        end
        if not body then
            -- fallback: обычный teleport
            serverStatus.Text = "API недоступен → обычный hop"
            hopSamePlace()
            return
        end
        local ok, data = pcall(function()
            return HttpService:JSONDecode(body)
        end)
        if not ok or typeof(data) ~= "table" or typeof(data.data) ~= "table" then
            serverStatus.Text = "Не удалось разобрать список → hop"
            hopSamePlace()
            return
        end
        local targetId = nil
        for _, srv in ipairs(data.data) do
            if srv.id and srv.id ~= game.JobId and (srv.playing or 0) < (srv.maxPlayers or 1) then
                targetId = srv.id
                break
            end
        end
        if not targetId then
            serverStatus.Text = "Свободный сервер не найден → hop"
            hopSamePlace()
            return
        end
        serverStatus.Text = "Teleport → " .. tostring(targetId):sub(1, 8) .. "..."
        local ok2, err2 = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, targetId, player)
        end)
        if not ok2 then
            serverStatus.Text = "Ошибка: " .. tostring(err2)
            serverStatus.TextColor3 = THEME.Error
        end
    end)
end

local function rejoinSameServer()
    serverStatus.Text = "Rejoin того же сервера..."
    local ok, err = pcall(function()
        if game.JobId and game.JobId ~= "" then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
        else
            TeleportService:Teleport(game.PlaceId, player)
        end
    end)
    if not ok then
        serverStatus.Text = "Ошибка: " .. tostring(err)
        serverStatus.TextColor3 = THEME.Error
    end
end

H.createButtonRow(trollTab, {
    { text = "Сменить сервер", callback = hopSamePlace },
    { text = "Сервер поменьше", callback = hopLowestPlayers },
}, 51)

H.createButtonRow(trollTab, {
    { text = "Rejoin (тот же)", callback = rejoinSameServer },
}, 52)

end -- конец __build_Trolling

H.__buildTabs = function()
    H.__build_Sky()
    H.__build_Fx()
    H.__build_Screen()
    H.__build_Particles()
    H.__build_Wings()
    H.__build_PotatoAndParticles()
    H.__build_JumpRing()
    H.__build_Companion()
    H.__build_CharExtras()
    H.__build_Music()
    H.__build_MiniPlayer()
    H.__build_Camera()
    H.__build_ESP()
    H.__build_Trolling()
    H.__build_GUI()
end
H.__buildTabs()

----------------------------------------------------------
-- КАТЕГОРИЯ: КОНФИГИ (новая категория)
----------------------------------------------------------
-- Вынесено в ОТДЕЛЬНУЮ ФУНКЦИЮ: у функции свой лимит 200 locals,
-- иначе главный чанк упирается в "Out of local registers".
H.__initConfigs = function()
H.createCategoryHeader("КОНФИГИ", 13)
H.createTabButton("Конфиги", 14, CATEGORY_COLORS.Config)
local configTab = H.createTabFrame("Конфиги")

----------------------------------------------------------
-- СИСТЕМА КОНФИГОВ: сохранение / загрузка настроек
----------------------------------------------------------
-- Сохраняет через writefile/readfile (доступны в большинстве
-- исполнителей скриптов). Если исполнитель их не поддерживает,
-- конфиги хранятся только в памяти на время текущей сессии.
local CONFIG_FOLDER = "VisualMenuConfigs"
local AUTOLOAD_MARKER = CONFIG_FOLDER .. "/_autoload.txt"
local hasFileIO = typeof(writefile) == "function" and typeof(readfile) == "function" and typeof(isfile) == "function"

if hasFileIO then
    pcall(function()
        if typeof(isfolder) == "function" and typeof(makefolder) == "function" and not isfolder(CONFIG_FOLDER) then
            makefolder(CONFIG_FOLDER)
        end
    end)
end

local SettingsRegistry = {}
local sessionConfigs = {}
local autoloadEnabled = false

local function registerSetting(key, getFn, setFn)
    SettingsRegistry[key] = { Get = getFn, Set = setFn }
end

local function gatherSettingsTable()
    local data = {}
    for key, entry in pairs(SettingsRegistry) do
        local ok, value = pcall(entry.Get)
        if ok and value ~= nil then
            if typeof(value) == "Color3" then
                data[key] = { __color3 = true, r = value.R, g = value.G, b = value.B }
            else
                data[key] = value
            end
        end
    end
    return data
end

local function applySettingsTable(data)
    if typeof(data) ~= "table" then return 0 end
    local applied = 0
    for key, value in pairs(data) do
        local entry = SettingsRegistry[key]
        if entry and entry.Set then
            local v = value
            if typeof(v) == "table" and v.__color3 then
                v = Color3.new(tonumber(v.r) or 1, tonumber(v.g) or 1, tonumber(v.b) or 1)
            end
            if pcall(entry.Set, v) then applied = applied + 1 end
        end
    end
    return applied
end

local function setAutoloadMarker(name)
    if hasFileIO then
        pcall(writefile, AUTOLOAD_MARKER, name or "")
    end
end

function readAutoloadMarker()
    if hasFileIO and typeof(isfile) == "function" then
        local ok, exists = pcall(isfile, AUTOLOAD_MARKER)
        if ok and exists then
            local ok2, content = pcall(readfile, AUTOLOAD_MARKER)
            if ok2 and content and content ~= "" then return content end
        end
    end
    return nil
end

function saveConfig(name)
    if not name or name == "" then return false, "Введите имя конфига" end
    local data = gatherSettingsTable()
    local ok, encoded = pcall(function() return HttpService:JSONEncode(data) end)
    if not ok then return false, "Не удалось сериализовать настройки" end
    if hasFileIO then
        local success = pcall(writefile, CONFIG_FOLDER .. "/" .. name .. ".json", encoded)
        if not success then return false, "Ошибка записи файла" end
    else
        sessionConfigs[name] = encoded
    end
    if autoloadEnabled then setAutoloadMarker(name) end
    return true, "Сохранено: " .. name
end

-- всегда пишем конфиг "_last" — он автозагружается при следующем входе,
-- даже если пользователь не включил ручной «Автозагрузка»
function autoSaveLastConfig()
    local data = gatherSettingsTable()
    local ok, encoded = pcall(function() return HttpService:JSONEncode(data) end)
    if not ok then return end
    if hasFileIO then
        pcall(writefile, CONFIG_FOLDER .. "/_last.json", encoded)
        -- если автозагрузка включена и маркера нет — ставим _last
        if autoloadEnabled then
            local marker = readAutoloadMarker()
            if not marker or marker == "" then
                setAutoloadMarker("_last")
            end
        else
            -- даже без тоггла сохраняем маркер на _last, чтобы после
            -- перезахода настройки поднимались автоматически
            setAutoloadMarker("_last")
        end
    else
        sessionConfigs["_last"] = encoded
    end
end

local function listConfigNames()
    local names = {}
    if hasFileIO and typeof(listfiles) == "function" then
        local ok, files = pcall(listfiles, CONFIG_FOLDER)
        if ok then
            for _, path in ipairs(files) do
                local fname = tostring(path):match("([^/\\]+)%.json$")
                if fname and not fname:match("^_") then table.insert(names, fname) end
            end
        end
    else
        for name in pairs(sessionConfigs) do
            if not tostring(name):match("^_") then table.insert(names, name) end
        end
    end
    table.sort(names)
    return names
end

function loadConfigByName(name)
    if not name or name == "" then return false, "Нет имени конфига" end
    local encoded
    if hasFileIO then
        local path = CONFIG_FOLDER .. "/" .. name .. ".json"
        local ok, content = pcall(readfile, path)
        if ok and content and content ~= "" then encoded = content end
    end
    if not encoded then encoded = sessionConfigs[name] end
    if not encoded then return false, "Конфиг не найден: " .. tostring(name) end
    local ok, data = pcall(function() return HttpService:JSONDecode(encoded) end)
    if not ok or typeof(data) ~= "table" then return false, "Файл конфига повреждён" end
    local n = applySettingsTable(data) or 0
    if autoloadEnabled then setAutoloadMarker(name) end
    if n == 0 then return false, "0 настроек применено — сохраните конфиг заново" end
    return true, "Загружено: " .. name .. " (" .. tostring(n) .. ")"
end

local function deleteConfigByName(name)
    if hasFileIO and typeof(delfile) == "function" then
        pcall(delfile, CONFIG_FOLDER .. "/" .. name .. ".json")
    else
        sessionConfigs[name] = nil
    end
end

----------------------------------------------------------
-- ВКЛАДКА "КОНФИГИ" — интерфейс
----------------------------------------------------------
H.sectionLabel(configTab, "СОХРАНЕНИЕ И ЗАГРУЗКА НАСТРОЕК", 1)

local configInfoLabel = Instance.new("TextLabel")
configInfoLabel.Size = UDim2.new(1, 0, 0, 30)
configInfoLabel.BackgroundTransparency = 1
configInfoLabel.TextWrapped = true
configInfoLabel.Font = Enum.Font.Gotham
configInfoLabel.TextSize = 11
configInfoLabel.TextColor3 = THEME.SubText
configInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
configInfoLabel.TextYAlignment = Enum.TextYAlignment.Top
configInfoLabel.Text = hasFileIO
    and ("Конфиги пишутся в папку \"" .. CONFIG_FOLDER .. "\". Настройки автосохраняются в _last каждые 8с и поднимаются при следующем входе.")
    or "Ваш исполнитель не поддерживает файлы (writefile) — конфиги живут только до перезахода. Поставьте executor с файлами."
configInfoLabel.LayoutOrder = 2
configInfoLabel.Parent = configTab

configStatusLabel = Instance.new("TextLabel")
configStatusLabel.Size = UDim2.new(1, 0, 0, 16)
configStatusLabel.BackgroundTransparency = 1
configStatusLabel.Font = Enum.Font.GothamBold
configStatusLabel.TextSize = 11
configStatusLabel.TextColor3 = THEME.SubText
configStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
configStatusLabel.Text = ""
configStatusLabel.LayoutOrder = 4
configStatusLabel.Parent = configTab

local configListContainer = Instance.new("Frame")
configListContainer.Size = UDim2.new(1, 0, 0, 0)
configListContainer.AutomaticSize = Enum.AutomaticSize.Y
configListContainer.BackgroundTransparency = 1
configListContainer.LayoutOrder = 8
configListContainer.Parent = configTab
local configListLayout = Instance.new("UIListLayout")
configListLayout.Padding = UDim.new(0, 6)
configListLayout.SortOrder = Enum.SortOrder.LayoutOrder
configListLayout.Parent = configListContainer

local function refreshConfigList()
    for _, child in ipairs(configListContainer:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    local names = listConfigNames()
    if #names == 0 then
        local empty = Instance.new("TextLabel")
        empty.Size = UDim2.new(1, 0, 0, 20)
        empty.BackgroundTransparency = 1
        empty.Text = "Пока нет сохранённых конфигов"
        empty.TextColor3 = THEME.SubText
        empty.Font = Enum.Font.Gotham
        empty.TextSize = 12
        empty.TextXAlignment = Enum.TextXAlignment.Left
        empty.Parent = configListContainer
        return
    end
    for i, name in ipairs(names) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 30)
        row.BackgroundColor3 = THEME.Panel
        row.LayoutOrder = i
        row.Parent = configListContainer
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(1, -110, 1, 0)
        nameLbl.Position = UDim2.new(0, 10, 0, 0)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = name
        nameLbl.TextColor3 = THEME.Text
        nameLbl.Font = Enum.Font.Gotham
        nameLbl.TextSize = 12
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
        nameLbl.Parent = row

        local loadBtn = Instance.new("TextButton")
        loadBtn.Size = UDim2.new(0, 50, 0, 22)
        loadBtn.Position = UDim2.new(1, -104, 0.5, -11)
        loadBtn.BackgroundColor3 = THEME.AccentSoft
        loadBtn.Text = "Взять"
        loadBtn.TextColor3 = THEME.Text
        loadBtn.Font = Enum.Font.GothamBold
        loadBtn.TextSize = 11
        loadBtn.AutoButtonColor = false
        loadBtn.Parent = row
        Instance.new("UICorner", loadBtn).CornerRadius = UDim.new(0, 5)
        loadBtn.MouseButton1Click:Connect(function()
            local ok, msg = loadConfigByName(name)
            configStatusLabel.Text = msg
            configStatusLabel.TextColor3 = ok and THEME.Success or THEME.Error
        end)

        local delBtn = Instance.new("TextButton")
        delBtn.Size = UDim2.new(0, 46, 0, 22)
        delBtn.Position = UDim2.new(1, -50, 0.5, -11)
        delBtn.BackgroundColor3 = Color3.fromRGB(70, 40, 40)
        delBtn.Text = "Удал."
        delBtn.TextColor3 = THEME.Text
        delBtn.Font = Enum.Font.GothamBold
        delBtn.TextSize = 11
        delBtn.AutoButtonColor = false
        delBtn.Parent = row
        Instance.new("UICorner", delBtn).CornerRadius = UDim.new(0, 5)
        delBtn.Activated:Connect(function()
            local target = name
            playGuiClick(delBtn)
            -- удаляем файл + сессию + автозагрузку если совпала
            pcall(function()
                if hasFileIO and typeof(delfile) == "function" then
                    local path = CONFIG_FOLDER .. "/" .. target .. ".json"
                    if typeof(isfile) == "function" and isfile(path) then
                        delfile(path)
                    else
                        delfile(path)
                    end
                end
            end)
            sessionConfigs[target] = nil
            pcall(function()
                local last = readAutoloadMarker and readAutoloadMarker()
                if last == target then
                    setAutoloadMarker(nil)
                    if hasFileIO and typeof(delfile) == "function" and typeof(isfile) == "function" then
                        if isfile(AUTOLOAD_MARKER) then delfile(AUTOLOAD_MARKER) end
                    end
                end
            end)
            deleteConfigByName(target)
            configStatusLabel.Text = "Удалено: " .. target
            configStatusLabel.TextColor3 = THEME.Success
            task.defer(refreshConfigList)
        end)
    end
end

H.createInputRow(configTab, "Имя конфига", "Сохранить", 3, function(text)
    local ok, msg = saveConfig(text)
    configStatusLabel.Text = msg
    configStatusLabel.TextColor3 = ok and THEME.Success or THEME.Error
    refreshConfigList()
end)

H.createButtonRow(configTab, {
    { text = "Обновить список", callback = refreshConfigList },
}, 5)

autoloadToggleHandle = H.createToggleRow(configTab, "Автозагрузка последнего конфига при старте", 6, function(state)
    autoloadEnabled = state
    if not state then
        setAutoloadMarker(nil)
        pcall(function()
            if hasFileIO and typeof(delfile) == "function" and typeof(isfile) == "function" and isfile(AUTOLOAD_MARKER) then
                delfile(AUTOLOAD_MARKER)
            end
        end)
    end
end)

H.sectionLabel(configTab, "СПИСОК СОХРАНЁННЫХ КОНФИГОВ", 7)

H.sectionLabel(configTab, "СБРОС", 9)
H.createButtonRow(configTab, {
    { text = "Сбросить все настройки", callback = function()
        if defaultsSnapshot then
            applySettingsTable(defaultsSnapshot)
            configStatusLabel.Text = "Все настройки сброшены"
            configStatusLabel.TextColor3 = THEME.Success
        else
            configStatusLabel.Text = "Нет снимка defaults"
            configStatusLabel.TextColor3 = THEME.Error
        end
    end },
}, 9)

local defaultsSnapshot = nil -- заполняется ниже, после регистрации всех настроек
H.createButtonRow(configTab, {
    { text = "Сбросить всё к значениям по умолчанию", callback = function()
        if defaultsSnapshot then
            applySettingsTable(defaultsSnapshot)
            configStatusLabel.Text = "Настройки сброшены"
            configStatusLabel.TextColor3 = THEME.SubText
        end
    end },
}, 10)

----------------------------------------------------------
-- РЕГИСТРАЦИЯ НАСТРОЕК ДЛЯ СИСТЕМЫ КОНФИГОВ
----------------------------------------------------------
-- Каждая запись здесь — это то, что реально попадёт в сохранённый
-- .json конфиг. Чтобы добавить в конфиги ещё одну настройку из любой
-- вкладки, достаточно провести её через H.createToggleRow/H.createSlider/
-- H.createColorSliders (они теперь возвращают .Get()/.Set()) и добавить
-- сюда одну строку registerSetting(...).
local function safeGet(handle, method)
    if not handle then return nil end
    local ok, v = pcall(function() return handle[method]() end)
    return ok and v or nil
end
local function safeSet(handle, value)
    if not handle or not handle.Set then return end
    pcall(function() handle.Set(value, true) end)
end

registerSetting("hudEnabled", function() return hudEnabled end, function(v) safeSet(H.hudToggle, v) end)
registerSetting("hudYOffset", function() return hudYOffset end, function(v) safeSet(H.hudOffset, v) end)
registerSetting("accentColor", function() return THEME.Accent end, function(v) safeSet(H.guiAccent, v) end)
registerSetting("hotkey", function() return menuHotkey.Name end, function(v)
    local ok, keycode = pcall(function() return Enum.KeyCode[v] end)
    if ok and keycode then
        menuHotkey = keycode
        if hotkeyLabel then hotkeyLabel.Text = "Текущая клавиша: " .. keycode.Name end
    end
end)
registerSetting("crosshairEnabled", function() return safeGet(H.crosshairToggle, "Get") end, function(v) safeSet(H.crosshairToggle, v) end)
registerSetting("crosshairColor", function() return safeGet(H.crosshairColor, "Get") end, function(v) safeSet(H.crosshairColor, v) end)
registerSetting("favoriteTracks", function() return favoriteTracks end, function(v)
    if typeof(v) == "table" then favoriteTracks = v end
    if refreshFavLabel then pcall(refreshFavLabel) end
end)
registerSetting("musicVolume", function() return musicVolume end, function(v)
    musicVolume = tonumber(v) or 0.5
    if currentSound then currentSound.Volume = musicVolume end
    if mpVolFill then mpVolFill.Size = UDim2.new(musicVolume, 0, 1, 0) end
end)
registerSetting("trail", function() return safeGet(H.trailToggle, "Get") end, function(v) safeSet(H.trailToggle, v) end)
registerSetting("trailColor", function() return safeGet(H.trailColor, "Get") end, function(v) safeSet(H.trailColor, v) end)
registerSetting("trailRainbow", function() return safeGet(H.trailRainbow, "Get") end, function(v) safeSet(H.trailRainbow, v) end)
registerSetting("trailLifetime", function() return safeGet(H.trailLifetime, "Get") or 6 end, function(v) safeSet(H.trailLifetime, v) end)
registerSetting("aura", function() return safeGet(H.auraToggle, "Get") end, function(v) safeSet(H.auraToggle, v) end)
registerSetting("auraColor", function() return safeGet(H.auraColor, "Get") end, function(v) safeSet(H.auraColor, v) end)
registerSetting("highlight", function() return safeGet(H.highlightToggle, "Get") end, function(v) safeSet(H.highlightToggle, v) end)
registerSetting("highlightColor", function() return safeGet(H.highlightColor, "Get") end, function(v) safeSet(H.highlightColor, v) end)
registerSetting("highlightFill", function() return safeGet(H.highlightFill, "Get") or 100 end, function(v) safeSet(H.highlightFill, v) end)
registerSetting("footstep", function() return safeGet(H.footstepToggle, "Get") end, function(v) safeSet(H.footstepToggle, v) end)
registerSetting("glow", function() return safeGet(H.glowToggle, "Get") end, function(v) safeSet(H.glowToggle, v) end)
registerSetting("glowColor", function() return safeGet(H.glowColor, "Get") end, function(v) safeSet(H.glowColor, v) end)
registerSetting("glowRange", function() return safeGet(H.glowRange, "Get") or 8 end, function(v) safeSet(H.glowRange, v) end)
registerSetting("fov", function() return safeGet(H.fov, "Get") or 70 end, function(v) safeSet(H.fov, v) end)
registerSetting("camDist", function() return safeGet(H.camDist, "Get") or 128 end, function(v) safeSet(H.camDist, v) end)
registerSetting("firstPerson", function() return safeGet(H.firstPerson, "Get") end, function(v) safeSet(H.firstPerson, v) end)
registerSetting("fullBright", function() return safeGet(H.fullBright, "Get") end, function(v) safeSet(H.fullBright, v) end)
registerSetting("guiScale", function() return safeGet(H.guiScale, "Get") or 100 end, function(v) safeSet(H.guiScale, v) end)
registerSetting("guiTransparency", function() return safeGet(H.guiTransparency, "Get") or 0 end, function(v) safeSet(H.guiTransparency, v) end)
registerSetting("aspectRatio", function() return safeGet(H.aspectRatio, "Get") or 0 end, function(v) safeSet(H.aspectRatio, v) end)
registerSetting("bgEnabled", function() return H.bgToggle and H.bgToggle.Get() end, function(v) if H.bgToggle then H.bgToggle.Set(v) end end)
registerSetting("bgMode", function() return H.bgMode and H.bgMode.Get() end, function(v) if H.bgMode then H.bgMode.Set(v) end end)
registerSetting("bgPalette", function() return H.bgPalette and H.bgPalette.Get() end, function(v) if H.bgPalette then H.bgPalette.Set(v) end end)
registerSetting("bgSpeed", function() return H.bgSpeed and H.bgSpeed.Get() end, function(v) if H.bgSpeed then H.bgSpeed.Set(v) end end)
registerSetting("bgBright", function() return H.bgBright and H.bgBright.Get() end, function(v) if H.bgBright then H.bgBright.Set(v) end end)
registerSetting("bgDim", function() return H.bgDim and H.bgDim.Get() end, function(v) if H.bgDim then H.bgDim.Set(v) end end)
registerSetting("bgImage", function() return H.bgImage and H.bgImage.Get() end, function(v) if H.bgImage then H.bgImage.Set(v) end end)
registerSetting("fxEnabled", function() return H.fxToggle and H.fxToggle.Get() end, function(v) if H.fxToggle then H.fxToggle.Set(v) end end)
registerSetting("fxGlow", function() return H.fxGlow and H.fxGlow.Get() end, function(v) if H.fxGlow then H.fxGlow.Set(v) end end)
registerSetting("spinEnabled", function() return safeGet(H.spinToggle, "Get") end, function(v) safeSet(H.spinToggle, v) end)
registerSetting("spinSpeed", function() return safeGet(H.spinSpeed, "Get") or 40 end, function(v) safeSet(H.spinSpeed, v) end)
registerSetting("speedEnabled", function() return safeGet(H.speedToggle, "Get") end, function(v) safeSet(H.speedToggle, v) end)
registerSetting("walkSpeed", function() return safeGet(H.speedSlider, "Get") or 16 end, function(v) safeSet(H.speedSlider, v) end)
registerSetting("fpsCapEnabled", function() return fpsCapEnabled end, function(v)
    fpsCapEnabled = v and true or false
    if H.fpsCapToggle then safeSet(H.fpsCapToggle, fpsCapEnabled) end
end)
registerSetting("fpsCapValue", function() return fpsCapValue end, function(v)
    fpsCapValue = tonumber(v) or 240
    if H.fpsCapSlider then safeSet(H.fpsCapSlider, fpsCapValue) end
end)

-- слайдеры H.createSlider возвращают {Set=...} без Get — добавляем Get через обёртку
-- (для тех, у кого ещё нет)
local function ensureSliderGet(handle, fallback)
    if handle and not handle.Get then
        local last = fallback
        local oldSet = handle.Set
        handle.Set = function(v, fire)
            last = v
            oldSet(v, fire)
        end
        handle.Get = function() return last end
    end
end
ensureSliderGet(H.trailLifetime, 6)
ensureSliderGet(H.highlightFill, 100)
ensureSliderGet(H.glowRange, 8)
ensureSliderGet(H.fov, 70)
ensureSliderGet(H.camDist, 128)
ensureSliderGet(H.hudOffset, 12)
ensureSliderGet(H.aspectRatio, 0)
ensureSliderGet(H.guiScale, 100)
ensureSliderGet(H.guiTransparency, 0)
ensureSliderGet(H.spinSpeed, 40)
ensureSliderGet(H.fpsCapSlider, 240)
ensureSliderGet(H.speedSlider, 16)

-- снимок значений "по умолчанию" сразу после регистрации — используется
-- кнопкой "Сбросить всё" на этой же вкладке
defaultsSnapshot = gatherSettingsTable()
refreshConfigList()

-- автосохранение _last каждые 8 секунд, пока меню живо
task.spawn(function()
    while ScreenGui and ScreenGui.Parent do
        task.wait(8)
        pcall(autoSaveLastConfig)
    end
end)
end -- конец __initConfigs
H.__initConfigs()

----------------------------------------------------------
-- ПЕЙДЖЕР КАТЕГОРИЙ: стрелками листаем группы вкладок в сайдбаре
----------------------------------------------------------
H.__initPager = function()
local CATEGORY_DEFS = {
    { name = "МИР", tabs = { "Небо", "Эффекты", "Экран" } },
    { name = "ПЕРСОНАЖ", tabs = { "Частицы", "Музыка", "Камера", "ESP", "Троллинг" } },
    { name = "МЕНЮ", tabs = { "GUI", "Конфиги" } },
}

local Pager = Instance.new("Frame")
Pager.Size = UDim2.new(1, 0, 0, 46)
Pager.BackgroundTransparency = 1
Pager.LayoutOrder = 0
Pager.Parent = H.TabList or Sidebar

local pagerRow = Instance.new("Frame")
pagerRow.Size = UDim2.new(1, 0, 0, 26)
pagerRow.BackgroundTransparency = 1
pagerRow.Parent = Pager

local function pagerArrow(text, alignRight)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 22, 0, 22)
    b.Position = alignRight and UDim2.new(1, -22, 0, 2) or UDim2.new(0, 0, 0, 2)
    b.BackgroundColor3 = THEME.Panel
    b.Text = text
    b.TextColor3 = THEME.Text
    b.Font = Enum.Font.GothamBold
    b.TextSize = 14
    b.AutoButtonColor = false
    b.Parent = pagerRow
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = THEME.AccentSoft }):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = THEME.Panel }):Play()
    end)
    return b
end

local prevArrow = pagerArrow("<", false)
local nextArrow = pagerArrow(">", true)

local categoryLabel = Instance.new("TextLabel")
categoryLabel.Size = UDim2.new(1, -52, 1, 0)
categoryLabel.Position = UDim2.new(0, 26, 0, 0)
categoryLabel.BackgroundTransparency = 1
categoryLabel.Font = Enum.Font.GothamBold
categoryLabel.TextSize = 11
categoryLabel.TextColor3 = THEME.Text
categoryLabel.TextXAlignment = Enum.TextXAlignment.Center
categoryLabel.Parent = pagerRow

local dotsRow = Instance.new("Frame")
dotsRow.Size = UDim2.new(1, 0, 0, 14)
dotsRow.Position = UDim2.new(0, 0, 0, 30)
dotsRow.BackgroundTransparency = 1
dotsRow.Parent = Pager
local dotsLayout = Instance.new("UIListLayout")
dotsLayout.FillDirection = Enum.FillDirection.Horizontal
dotsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
dotsLayout.Padding = UDim.new(0, 5)
dotsLayout.Parent = dotsRow

local categoryDots = {}
for i in ipairs(CATEGORY_DEFS) do
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 6, 0, 6)
    dot.BackgroundColor3 = Color3.fromRGB(60, 60, 68)
    dot.BorderSizePixel = 0
    dot.Parent = dotsRow
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
    categoryDots[i] = dot
end

function showCategory(idx, skipAutoSelect)
    idx = ((idx - 1) % #CATEGORY_DEFS) + 1
    currentCategoryIndex = idx
    local def = CATEGORY_DEFS[idx]
    local activeSet = {}
    for _, tabName in ipairs(def.tabs) do
        activeSet[tabName] = true
    end
    for tabName, data in pairs(tabButtons) do
        data.button.Visible = activeSet[tabName] and true or false
    end
    categoryLabel.Text = def.name
    for i, dot in ipairs(categoryDots) do
        dot.BackgroundColor3 = (i == idx) and THEME.Accent or Color3.fromRGB(60, 60, 68)
    end
    if not skipAutoSelect then
        local alreadyVisible = false
        for _, t in ipairs(def.tabs) do
            if tabs[t] and tabs[t].Visible then
                alreadyVisible = true
            end
        end
        if not alreadyVisible then
            H.selectTab(def.tabs[1])
        end
    end
end

prevArrow.MouseButton1Click:Connect(function()
    showCategory(currentCategoryIndex - 1)
end)
nextArrow.MouseButton1Click:Connect(function()
    showCategory(currentCategoryIndex + 1)
end)
end -- конец __initPager
H.__initPager()

----------------------------------------------------------
-- ОВАЛЬНЫЙ HUD СВЕРХУ: НИК, ПИНГ, FPS, ВРЕМЯ В ПЛЕЙСЕ
-- Отдельный ScreenGui с высоким DisplayOrder, чтобы HUD
-- всегда был поверх CoreGui и не пропадал
----------------------------------------------------------
local HudGui = Instance.new("ScreenGui")
HudGui.Name = "VisualMenuHUD"
HudGui.ResetOnSpawn = false
HudGui.IgnoreGuiInset = true
HudGui.DisplayOrder = 100
HudGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
HudGui.Parent = game:GetService("CoreGui")

HudFrame = Instance.new("Frame")
HudFrame.Name = "TopHud"
HudFrame.Size = UDim2.new(0, 320, 0, 36)
HudFrame.AutomaticSize = Enum.AutomaticSize.X
HudFrame.AnchorPoint = Vector2.new(0.5, 0)
HudFrame.Position = UDim2.new(0.5, 0, 0, hudYOffset)
HudFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
HudFrame.BackgroundTransparency = 0.15
HudFrame.BorderSizePixel = 0
HudFrame.ZIndex = 10
HudFrame.Visible = hudEnabled
HudFrame.Parent = HudGui
Instance.new("UICorner", HudFrame).CornerRadius = UDim.new(1, 0)
hudStroke = Instance.new("UIStroke", HudFrame)
hudStroke.Color = THEME.Accent
hudStroke.Thickness = 1.5
hudStroke.Transparency = 0.1

local hudPad = Instance.new("UIPadding")
hudPad.PaddingLeft = UDim.new(0, 18)
hudPad.PaddingRight = UDim.new(0, 18)
hudPad.Parent = HudFrame

local hudLayout = Instance.new("UIListLayout")
hudLayout.FillDirection = Enum.FillDirection.Horizontal
hudLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
hudLayout.VerticalAlignment = Enum.VerticalAlignment.Center
hudLayout.Padding = UDim.new(0, 16)
hudLayout.Parent = HudFrame

local function hudSegment(order, initialText)
    local seg = Instance.new("TextLabel")
    seg.Size = UDim2.new(0, 0, 1, 0)
    seg.AutomaticSize = Enum.AutomaticSize.X
    seg.BackgroundTransparency = 1
    seg.Font = Enum.Font.GothamBold
    seg.TextSize = 15
    seg.TextColor3 = Color3.fromRGB(255, 255, 255)
    seg.TextStrokeColor3 = Color3.new(0, 0, 0)
    seg.TextStrokeTransparency = 0.35
    seg.LayoutOrder = order
    seg.ZIndex = 11
    seg.Text = initialText or ""
    seg.Parent = HudFrame
    return seg
end

hudName = hudSegment(1, player.DisplayName)
hudName.TextColor3 = THEME.Accent

local function hudDivider(order)
    local d = Instance.new("Frame")
    d.Size = UDim2.new(0, 1, 0, 18)
    d.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
    d.BorderSizePixel = 0
    d.LayoutOrder = order
    d.Parent = HudFrame
    return d
end

hudDivider(2)
hudPing = hudSegment(3, "PING --")
hudDivider(4)
hudFps = hudSegment(5, "FPS --")
hudDivider(6)
local hudSpeed = hudSegment(7, "0 st/s")
hudDivider(8)
local hudOnline = hudSegment(9, "ONLINE --")
hudDivider(10)
hudTime = hudSegment(11, "00:00")

local function refreshHudOnline()
    if hudOnline then
        hudOnline.Text = "ONLINE " .. tostring(#Players:GetPlayers())
    end
end
refreshHudOnline()
Players.PlayerAdded:Connect(refreshHudOnline)
Players.PlayerRemoving:Connect(function() task.defer(refreshHudOnline) end)


----------------------------------------------------------
-- МИНИ-РАДАР (слева снизу)
----------------------------------------------------------
-- radarEnabled / radarRange / RadarFrame — выше
local RadarGui = Instance.new("ScreenGui")
RadarGui.Name = "VisualMenuRadar"
RadarGui.ResetOnSpawn = false
RadarGui.IgnoreGuiInset = true
RadarGui.DisplayOrder = 90
RadarGui.Parent = game:GetService("CoreGui")

RadarFrame = Instance.new("Frame")
RadarFrame.Name = "Radar"
RadarFrame.Size = UDim2.new(0, 130, 0, 130)
RadarFrame.Position = UDim2.new(0, 16, 1, -146)
RadarFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
RadarFrame.BackgroundTransparency = 0.25
RadarFrame.BorderSizePixel = 0
RadarFrame.Parent = RadarGui
Instance.new("UICorner", RadarFrame).CornerRadius = UDim.new(0, 12)
RadarFrame.Visible = radarEnabled
local radarStroke = Instance.new("UIStroke", RadarFrame)
radarStroke.Color = THEME.Accent
radarStroke.Thickness = 1.2
radarStroke.Transparency = 0.3

-- сетка
local radarRing = Instance.new("Frame")
radarRing.Size = UDim2.new(0.7, 0, 0.7, 0)
radarRing.Position = UDim2.new(0.15, 0, 0.15, 0)
radarRing.BackgroundTransparency = 1
radarRing.Parent = RadarFrame
local ringStroke = Instance.new("UIStroke", radarRing)
ringStroke.Color = Color3.fromRGB(80, 80, 100)
ringStroke.Thickness = 1
ringStroke.Transparency = 0.5
Instance.new("UICorner", radarRing).CornerRadius = UDim.new(1, 0)

local centerDot = Instance.new("Frame")
centerDot.Size = UDim2.new(0, 8, 0, 8)
centerDot.AnchorPoint = Vector2.new(0.5, 0.5)
centerDot.Position = UDim2.new(0.5, 0, 0.5, 0)
centerDot.BackgroundColor3 = THEME.Accent
centerDot.BorderSizePixel = 0
centerDot.Parent = RadarFrame
Instance.new("UICorner", centerDot).CornerRadius = UDim.new(1, 0)

local radarTitle = Instance.new("TextLabel")
radarTitle.Size = UDim2.new(1, 0, 0, 14)
radarTitle.Position = UDim2.new(0, 0, 0, 4)
radarTitle.BackgroundTransparency = 1
radarTitle.Text = "RADAR"
radarTitle.TextColor3 = THEME.SubText
radarTitle.Font = Enum.Font.GothamBold
radarTitle.TextSize = 10
radarTitle.Parent = RadarFrame

local radarDots = {} -- [player] = frame

local function clearRadarDots()
    for _, d in pairs(radarDots) do
        if d then d:Destroy() end
    end
    radarDots = {}
end

RunService.RenderStepped:Connect(function()
    if not radarEnabled or not RadarFrame.Visible then return end
    local myChar = player.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end
    local myPos = myRoot.Position
    local myLook = myRoot.CFrame.LookVector
    local myRight = myRoot.CFrame.RightVector

    local seen = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player then
            local char = plr.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                local offset = root.Position - myPos
                local dist = offset.Magnitude
                if dist <= radarRange then
                    seen[plr] = true
                    local flat = Vector3.new(offset.X, 0, offset.Z)
                    local forward = Vector3.new(myLook.X, 0, myLook.Z)
                    local right = Vector3.new(myRight.X, 0, myRight.Z)
                    if forward.Magnitude > 0.01 then forward = forward.Unit end
                    if right.Magnitude > 0.01 then right = right.Unit end
                    local localX = flat:Dot(right) / radarRange
                    local localZ = flat:Dot(forward) / radarRange
                    -- на радаре: X вправо, -Z вверх (вперёд)
                    local px = 0.5 + localX * 0.45
                    local py = 0.5 - localZ * 0.45
                    px = math.clamp(px, 0.08, 0.92)
                    py = math.clamp(py, 0.08, 0.92)

                    local dot = radarDots[plr]
                    if not dot then
                        dot = Instance.new("Frame")
                        dot.Size = UDim2.new(0, 7, 0, 7)
                        dot.AnchorPoint = Vector2.new(0.5, 0.5)
                        dot.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
                        dot.BorderSizePixel = 0
                        dot.Parent = RadarFrame
                        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
                        radarDots[plr] = dot
                    end
                    dot.Position = UDim2.new(px, 0, py, 0)
                    dot.Visible = true
                end
            end
        end
    end
    for plr, dot in pairs(radarDots) do
        if not seen[plr] then
            if dot then dot:Destroy() end
            radarDots[plr] = nil
        end
    end
end)

Players.PlayerRemoving:Connect(function(plr)
    if radarDots[plr] then
        radarDots[plr]:Destroy()
        radarDots[plr] = nil
    end
end)

-- toggle in GUI tab will be added; default on


local hudStartClock = os.clock()

local function formatSessionTime(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    if h > 0 then
        return string.format("%02d:%02d:%02d", h, m, s)
    end
    return string.format("%02d:%02d", m, s)
end

do
    local frameCount = 0
    local fpsAccum = 0
    local lastUpdate = os.clock()
    RunService.RenderStepped:Connect(function(dt)
        frameCount = frameCount + 1
        fpsAccum = fpsAccum + dt
        if fpsAccum >= 0.5 then
            local fps = math.floor(frameCount / fpsAccum + 0.5)
            hudFps.Text = "FPS " .. fps
            hudFps.TextColor3 = fps >= 45 and THEME.Success or (fps >= 25 and Color3.fromRGB(230, 200, 80) or THEME.Error)
            frameCount = 0
            fpsAccum = 0
        end
        -- скорость
        if hudSpeed then
            local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local spd = root.AssemblyLinearVelocity.Magnitude
                hudSpeed.Text = string.format("%.0f st/s", spd)
                hudSpeed.TextColor3 = spd > 30 and THEME.Accent or Color3.fromRGB(245, 245, 250)
            else
                hudSpeed.Text = "0 st/s"
            end
        end

        local now = os.clock()
        if now - lastUpdate >= 1 then
            lastUpdate = now
            local ok, pingValue = pcall(function()
                return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
            end)
            local ping = ok and math.floor(pingValue) or -1
            if ping >= 0 then
                hudPing.Text = "PING " .. ping
                hudPing.TextColor3 = ping <= 80 and THEME.Success or (ping <= 180 and Color3.fromRGB(230, 200, 80) or THEME.Error)
            else
                hudPing.Text = "PING --"
                hudPing.TextColor3 = Color3.fromRGB(245, 245, 250)
            end
            hudTime.Text = formatSessionTime(os.clock() - hudStartClock)
        end
    end)
end

player:GetPropertyChangedSignal("DisplayName"):Connect(function()
    hudName.Text = player.DisplayName
end)

H.sectionLabel(screenTab, "ВЕРХНИЙ HUD", 19)
H.hudToggle = H.createToggleRow(screenTab, "Показать HUD (ник/пинг/фпс/время)", 20, function(state)
    hudEnabled = state
    HudFrame.Visible = state
end, true)
H.hudOffset = H.createSlider(screenTab, "Отступ HUD сверху экрана", 0, 120, hudYOffset, 25, function(v)
    hudYOffset = v
    HudFrame.Position = UDim2.new(0.5, 0, 0, hudYOffset)
end)
H.createButtonRow(screenTab, {
    { text = "Обновить HUD", callback = function()
        -- принудительно пересобирает видимость на случай если HUD
        -- "потерялся" (например, после SetCoreGuiEnabled в фото-режиме)
        HudFrame.Visible = hudEnabled
        hudName.Text = player.DisplayName
    end },
}, 26)

H.sectionLabel(screenTab, "ЛИМИТ FPS (РЕАЛЬНЫЙ)", 27)
local fpsCapInfo = Instance.new("TextLabel")
fpsCapInfo.Size = UDim2.new(1, 0, 0, 28)
fpsCapInfo.BackgroundTransparency = 1
fpsCapInfo.TextWrapped = true
fpsCapInfo.Text = hasSetFpsCap
    and "Executor поддерживает setfpscap — лимит реально ограничивает FPS клиента."
    or "setfpscap не найден в executor — слайдер не сработает. Ping изменить клиентом нельзя (сеть)."
fpsCapInfo.TextColor3 = THEME.SubText
fpsCapInfo.Font = Enum.Font.Gotham
fpsCapInfo.TextSize = 11
fpsCapInfo.TextXAlignment = Enum.TextXAlignment.Left
fpsCapInfo.LayoutOrder = 28
fpsCapInfo.Parent = screenTab

H.fpsCapToggle = H.createToggleRow(screenTab, "Включить лимит FPS (setfpscap)", 29, function(state)
    fpsCapEnabled = state
    if hasSetFpsCap then
        pcall(function()
            if state then
                setfpscap(fpsCapValue)
            else
                setfpscap(0) -- 0 / очень большое = без лимита у многих executors
            end
        end)
    end
end, false)
H.fpsCapSlider = H.createSlider(screenTab, "Лимит FPS", 30, 360, fpsCapValue, 30, function(v)
    fpsCapValue = v
    if fpsCapEnabled and hasSetFpsCap then
        pcall(function() setfpscap(v) end)
    end
end)

----------------------------------------------------------
-- ОТКРЫТИЕ / ЗАКРЫТИЕ ОКНА С АНИМАЦИЕЙ (клавиша K)
----------------------------------------------------------
local function setMenuVisible(open)
    if open == menuOpen then return end
    menuOpen = open
    if open then
        MainFrame.Visible = true
        MainFrame.Size = UDim2.new(0, 620, 0, 450)
        MainFrame.BackgroundTransparency = 0.3
        TweenService:Create(MainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 660, 0, 480),
            BackgroundTransparency = 0,
        }):Play()
        TweenService:Create(mainStroke, TweenInfo.new(0.2), {Transparency = 0.4}):Play()
    else
        local tw = TweenService:Create(MainFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            Size = UDim2.new(0, 620, 0, 450),
            BackgroundTransparency = 0.3,
        })
        TweenService:Create(mainStroke, TweenInfo.new(0.15), {Transparency = 0.8}):Play()
        tw:Play()
        tw.Completed:Wait()
        MainFrame.Visible = false
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if gameProcessedEvent then return end -- игнор если фокус в текстовом поле/чате
    if hotkeyListening then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            menuHotkey = input.KeyCode
            hotkeyListening = false
            hotkeyLabel.Text = "Текущая клавиша: " .. input.KeyCode.Name
        end
        return
    end
    if input.KeyCode == menuHotkey then
        setMenuVisible(not menuOpen)
    end
end)

----------------------------------------------------------
-- АНИМИРОВАННЫЙ ЭКРАН ЗАГРУЗКИ ПРИ АКТИВАЦИИ
----------------------------------------------------------
local LoadingOverlay = Instance.new("Frame")
LoadingOverlay.Size = UDim2.new(1, 0, 1, 0)
LoadingOverlay.BackgroundColor3 = THEME.Background
LoadingOverlay.BorderSizePixel = 0
LoadingOverlay.ZIndex = 50
LoadingOverlay.Parent = MainFrame
Instance.new("UICorner", LoadingOverlay).CornerRadius = UDim.new(0, 12)

local spinnerRing = Instance.new("Frame")
spinnerRing.Size = UDim2.new(0, 54, 0, 54)
spinnerRing.AnchorPoint = Vector2.new(0.5, 0.5)
spinnerRing.Position = UDim2.new(0.5, 0, 0.5, -30)
spinnerRing.BackgroundTransparency = 1
spinnerRing.ZIndex = 51
spinnerRing.Parent = LoadingOverlay
Instance.new("UICorner", spinnerRing).CornerRadius = UDim.new(1, 0)
local ringStroke = Instance.new("UIStroke", spinnerRing)
ringStroke.Thickness = 3
ringStroke.Color = THEME.Accent
local ringGrad = Instance.new("UIGradient", ringStroke)
ringGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0),
    NumberSequenceKeypoint.new(0.5, 1),
    NumberSequenceKeypoint.new(1, 0),
})

local logoDot = Instance.new("Frame")
logoDot.Size = UDim2.new(0, 10, 0, 10)
logoDot.AnchorPoint = Vector2.new(0.5, 0.5)
logoDot.Position = UDim2.new(0.5, 0, 0.5, -30)
logoDot.BackgroundColor3 = THEME.Accent
logoDot.ZIndex = 51
logoDot.Parent = LoadingOverlay
Instance.new("UICorner", logoDot).CornerRadius = UDim.new(1, 0)

local loadingLabel = Instance.new("TextLabel")
loadingLabel.Size = UDim2.new(1, 0, 0, 20)
loadingLabel.Position = UDim2.new(0, 0, 0.5, 34)
loadingLabel.BackgroundTransparency = 1
loadingLabel.Text = "ЗАГРУЗКА"
loadingLabel.TextColor3 = THEME.SubText
loadingLabel.Font = Enum.Font.GothamBold
loadingLabel.TextSize = 12
loadingLabel.ZIndex = 51
loadingLabel.Parent = LoadingOverlay

local barBG = Instance.new("Frame")
barBG.Size = UDim2.new(0, 160, 0, 4)
barBG.AnchorPoint = Vector2.new(0.5, 0.5)
barBG.Position = UDim2.new(0.5, 0, 0.5, 60)
barBG.BackgroundColor3 = THEME.Panel
barBG.BorderSizePixel = 0
barBG.ZIndex = 51
barBG.Parent = LoadingOverlay
Instance.new("UICorner", barBG).CornerRadius = UDim.new(1, 0)

local barFill = Instance.new("Frame")
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = THEME.Accent
barFill.BorderSizePixel = 0
barFill.ZIndex = 52
barFill.Parent = barBG
Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)

local spinning = true
task.spawn(function()
    while spinning do
        spinnerRing.Rotation = (spinnerRing.Rotation + 8) % 360
        task.wait()
    end
end)

task.spawn(function()
    local dots = 0
    while spinning do
        dots = (dots % 3) + 1
        loadingLabel.Text = "ЗАГРУЗКА" .. string.rep(".", dots)
        task.wait(0.35)
    end
end)

MainFrame.Size = UDim2.new(0, 580, 0, 420)
MainFrame.BackgroundTransparency = 0.15
mainStroke.Transparency = 0.7

TweenService:Create(barFill, TweenInfo.new(1.1, Enum.EasingStyle.Quad), {Size = UDim2.new(1, 0, 1, 0)}):Play()
task.wait(1.25)
spinning = false

TweenService:Create(MainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
    Size = UDim2.new(0, 660, 0, 480),
    BackgroundTransparency = 0,
}):Play()
TweenService:Create(mainStroke, TweenInfo.new(0.35), {Transparency = 0.4}):Play()

TweenService:Create(loadingLabel, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
TweenService:Create(barBG, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
TweenService:Create(barFill, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
local fadeOut = TweenService:Create(LoadingOverlay, TweenInfo.new(0.3), {BackgroundTransparency = 1})
fadeOut:Play()
fadeOut.Completed:Wait()
LoadingOverlay.Visible = false
LoadingOverlay:Destroy()

task.wait()
showCategory(1)

-- автозагрузка: сначала маркер, иначе файл _last (пишется автоматически каждые 8с)
do
    local lastName = readAutoloadMarker()
    if not lastName or lastName == "" then
        lastName = "_last"
    end
    local ok = loadConfigByName(lastName)
    if ok then
        if autoloadToggleHandle then
            pcall(function() autoloadToggleHandle.Set(true, false) end)
        end
        autoloadEnabled = true
        if configStatusLabel then
            configStatusLabel.Text = "Автозагружен конфиг: " .. lastName
            configStatusLabel.TextColor3 = THEME.SubText
        end
        print("[Visual Menu] Автозагружен конфиг: " .. lastName)
    else
        if lastName ~= "_last" then
            ok = loadConfigByName("_last")
            if ok then
                print("[Visual Menu] Автозагружен конфиг: _last")
            end
        end
    end
end

end
__main()
print("[Visual Menu v6] Загружено успешно. Нажмите K чтобы открыть/закрыть меню. Конфиги сохраняются автоматически (_last) и поднимаются при следующем входе.")