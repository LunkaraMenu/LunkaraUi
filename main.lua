--!strict
-- LunkaraUI 2.0.0
-- Command-first Roblox UI library.
--
-- Design goals:
--   * Tiny semicolon launcher + keyboard-first command palette.
--   * No branding/logo is rendered by the library.
--   * No dimming backdrop. Click-catcher is fully transparent.
--   * Native Roblox fonts, integer-pixel geometry, no root UIScale/CanvasGroup.
--   * Optional command-specific helper panels generated from argument schemas.
--   * Player picker / number / choice / boolean / string helpers.
--   * Studio-safe client UI. No exploit-only API is required by the core.
--
-- Minimal usage:
--
-- local LunkaraUI = loadstring(game:HttpGet(RAW_URL))()
-- local UI = LunkaraUI.new({
--     Key = Enum.KeyCode.Semicolon,
--     Prefix = ";",
-- })
--
-- UI:RegisterCommand({
--     Name = "speed",
--     Aliases = { "ws" },
--     Description = "Set WalkSpeed.",
--     Arguments = {
--         { Name = "value", Type = "number", Required = true, Min = 0, Max = 150, Default = 16 },
--     },
--     Panel = true,
--     Callback = function(Context)
--         local humanoid = Context.Player.Character and Context.Player.Character:FindFirstChildOfClass("Humanoid")
--         if humanoid then humanoid.WalkSpeed = Context.Values.value end
--     end,
-- })

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local LunkaraUI = {}
LunkaraUI.__index = LunkaraUI
LunkaraUI.Version = "2.0.0"

-- Supplied project SFX. Missing/blocked assets are always skipped safely.
local DEFAULT_AUDIO = {
    Hover = "rbxassetid://107511012621133",
    Click = "rbxassetid://133216848606395",
    Open = "rbxassetid://130359997277952",
    Close = "rbxassetid://130359997277952",
    Toggle = "rbxassetid://133216848606395",
    Notification = "rbxassetid://131039887376992",
    Success = "rbxassetid://101176804827210",
    Error = "rbxassetid://128187340772806",
}

-- Opaque surfaces on purpose. The world/UI behind LunkaraUI is never dimmed.
local DEFAULT_THEME = {
    Accent = Color3.fromHex("#5B00B0"),
    AccentBright = Color3.fromHex("#7416D2"),
    AccentSoft = Color3.fromHex("#291735"),

    Border = Color3.fromHex("#2A2B2F"),
    Surface = Color3.fromHex("#121315"),
    SurfaceTop = Color3.fromHex("#17181B"),
    SurfaceRaised = Color3.fromHex("#191A1E"),
    Input = Color3.fromHex("#1B1C20"),
    InputHover = Color3.fromHex("#202126"),
    Row = Color3.fromHex("#16171A"),
    RowHover = Color3.fromHex("#1E1F24"),
    RowSelected = Color3.fromHex("#242029"),
    Track = Color3.fromHex("#292A2E"),

    Text = Color3.fromHex("#F5F5F7"),
    TextSecondary = Color3.fromHex("#C3C4C8"),
    Muted = Color3.fromHex("#898B92"),
    Disabled = Color3.fromHex("#595B61"),
    Danger = Color3.fromHex("#E15B64"),
    Success = Color3.fromHex("#6FCF97"),
}

local DEFAULT_CONFIG = {
    Parent = nil,
    Key = Enum.KeyCode.Semicolon,
    Prefix = ";",
    Accent = nil,
    Theme = nil,
    CloseOnExecute = false,
    MaxResults = 9,

    Launcher = {
        Enabled = true,
        Side = "Left", -- Left / Right
        Y = 0.58,
    },

    Audio = {
        Enabled = true,
        Volume = 0.30,
        Sounds = {},
    },

    Builtins = {
        Help = true,
    },
}

local MOTION = {
    Hover = 0.10,
    Press = 0.07,
    Open = 0.16,
    Close = 0.12,
    Helper = 0.15,
}

--==================================================
-- Utilities
--==================================================

local function copyTable(source)
    local out = {}
    for key, value in pairs(source or {}) do
        if type(value) == "table" then
            out[key] = copyTable(value)
        else
            out[key] = value
        end
    end
    return out
end

local function mergeTable(base, overrides)
    if type(overrides) ~= "table" then
        return base
    end
    for key, value in pairs(overrides) do
        if type(value) == "table" and type(base[key]) == "table" then
            mergeTable(base[key], value)
        else
            base[key] = value
        end
    end
    return base
end

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function lower(value)
    return string.lower(trim(value))
end

local function roundPixel(value)
    return math.floor(value + 0.5)
end

local function clamp(value, minimum, maximum)
    if minimum ~= nil and value < minimum then
        value = minimum
    end
    if maximum ~= nil and value > maximum then
        value = maximum
    end
    return value
end

local function snapNumber(value, step)
    step = tonumber(step)
    if not step or step <= 0 then
        return value
    end
    return math.floor((value / step) + 0.5) * step
end

local function decimalPlaces(step)
    local text = tostring(step or 1)
    local decimal = string.find(text, ".", 1, true)
    if not decimal then
        return 0
    end
    return math.min(5, #text - decimal)
end

local function formatNumber(value, step)
    local places = decimalPlaces(step)
    if places <= 0 then
        return tostring(math.floor(value + 0.5))
    end
    return string.format("%." .. tostring(places) .. "f", value)
end

local function new(className, properties)
    local object = Instance.new(className)
    if properties then
        for key, value in pairs(properties) do
            object[key] = value
        end
    end
    return object
end

local function addCorner(parent, radius)
    return new("UICorner", {
        CornerRadius = UDim.new(0, radius),
        Parent = parent,
    })
end

local function addPadding(parent, left, right, top, bottom)
    return new("UIPadding", {
        PaddingLeft = UDim.new(0, left),
        PaddingRight = UDim.new(0, right),
        PaddingTop = UDim.new(0, top),
        PaddingBottom = UDim.new(0, bottom),
        Parent = parent,
    })
end

local function resolveFont(names, fallback)
    for _, candidate in ipairs(names) do
        for _, item in ipairs(Enum.Font:GetEnumItems()) do
            if item.Name == candidate then
                return item
            end
        end
    end
    return fallback
end

-- Native Roblox typography only.
local FONT = {
    Regular = resolveFont({ "BuilderSans", "Arimo" }, Enum.Font.Gotham),
    Medium = resolveFont({ "BuilderSansMedium", "Arimo" }, Enum.Font.GothamMedium),
    Bold = resolveFont({ "BuilderSansBold", "ArimoBold" }, Enum.Font.GothamBold),
}

local TYPE = {
    Small = 12,
    Body = 13,
    Strong = 14,
    Title = 16,
}

local function makeLabel(parent, text, size, font, color, alignment)
    return new("TextLabel", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = tostring(text or ""),
        TextColor3 = color,
        TextSize = size,
        TextScaled = false,
        TextWrapped = false,
        RichText = false,
        Font = font,
        TextXAlignment = alignment or Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Parent = parent,
    })
end

local function safeCall(callback, ...)
    if type(callback) ~= "function" then
        return true
    end
    local ok, a, b, c = pcall(callback, ...)
    if not ok then
        warn("[LunkaraUI] Callback error:", a)
        return false, a
    end
    return true, a, b, c
end

local function tokenize(text)
    text = tostring(text or "")
    local result = {}
    local current = {}
    local quote = nil
    local escaped = false

    local function flush()
        if #current > 0 then
            table.insert(result, table.concat(current))
            current = {}
        end
    end

    for index = 1, #text do
        local char = string.sub(text, index, index)
        if escaped then
            table.insert(current, char)
            escaped = false
        elseif char == "\\" then
            escaped = true
        elseif quote then
            if char == quote then
                quote = nil
            else
                table.insert(current, char)
            end
        elseif char == '"' or char == "'" then
            quote = char
        elseif string.match(char, "%s") then
            flush()
        else
            table.insert(current, char)
        end
    end

    if escaped then
        table.insert(current, "\\")
    end
    flush()
    return result
end

local function quoteToken(value)
    value = tostring(value or "")
    if string.find(value, "%s") then
        return '"' .. string.gsub(value, '"', '\\"') .. '"'
    end
    return value
end

local function joinTokens(tokens)
    local out = {}
    for _, value in ipairs(tokens) do
        table.insert(out, quoteToken(value))
    end
    return table.concat(out, " ")
end

local function fuzzyScore(query, text)
    query = lower(query)
    text = lower(text)
    if query == "" then
        return 10
    end
    if text == query then
        return 1000
    end
    if string.sub(text, 1, #query) == query then
        return 850 - math.min(200, #text - #query)
    end
    local plain = string.find(text, query, 1, true)
    if plain then
        return 650 - plain
    end

    local qIndex = 1
    local firstMatch = nil
    local lastMatch = nil
    for index = 1, #text do
        if string.sub(text, index, index) == string.sub(query, qIndex, qIndex) then
            firstMatch = firstMatch or index
            lastMatch = index
            qIndex += 1
            if qIndex > #query then
                local span = (lastMatch or index) - (firstMatch or index)
                return 400 - span
            end
        end
    end
    return -1
end

--==================================================
-- Maid
--==================================================

local Maid = {}
Maid.__index = Maid

function Maid.new()
    return setmetatable({
        _items = {},
        _destroyed = false,
    }, Maid)
end

function Maid:Give(item)
    if item == nil then
        return item
    end
    if self._destroyed then
        if typeof(item) == "RBXScriptConnection" then
            item:Disconnect()
        elseif typeof(item) == "Instance" then
            item:Destroy()
        elseif type(item) == "function" then
            pcall(item)
        elseif type(item) == "table" and type(item.Destroy) == "function" then
            pcall(function() item:Destroy() end)
        end
        return item
    end
    table.insert(self._items, item)
    return item
end

function Maid:Cleanup()
    if self._destroyed then
        return
    end
    self._destroyed = true
    for index = #self._items, 1, -1 do
        local item = self._items[index]
        self._items[index] = nil
        if typeof(item) == "RBXScriptConnection" then
            item:Disconnect()
        elseif typeof(item) == "Instance" then
            item:Destroy()
        elseif type(item) == "function" then
            pcall(item)
        elseif type(item) == "table" and type(item.Destroy) == "function" then
            pcall(function() item:Destroy() end)
        end
    end
end

function Maid:Destroy()
    self:Cleanup()
end

--==================================================
-- Motion
--==================================================

local Motion = {}
Motion.__index = Motion

function Motion.new()
    return setmetatable({
        _active = setmetatable({}, { __mode = "k" }),
    }, Motion)
end

function Motion:Tween(instance, duration, easingStyle, easingDirection, goals)
    if not instance or not instance.Parent then
        return nil
    end

    local map = self._active[instance]
    if not map then
        map = {}
        self._active[instance] = map
    end

    for property in pairs(goals) do
        local previous = map[property]
        if previous then
            pcall(function() previous:Cancel() end)
            map[property] = nil
        end
    end

    local tween = TweenService:Create(
        instance,
        TweenInfo.new(duration, easingStyle or Enum.EasingStyle.Quart, easingDirection or Enum.EasingDirection.Out),
        goals
    )

    for property in pairs(goals) do
        map[property] = tween
    end

    tween.Completed:Connect(function()
        local current = self._active[instance]
        if not current then
            return
        end
        for property in pairs(goals) do
            if current[property] == tween then
                current[property] = nil
            end
        end
    end)

    tween:Play()
    return tween
end

function Motion:Cancel(instance)
    local map = self._active[instance]
    if not map then
        return
    end
    local seen = {}
    for _, tween in pairs(map) do
        if tween and not seen[tween] then
            seen[tween] = true
            pcall(function() tween:Cancel() end)
        end
    end
    self._active[instance] = nil
end

--==================================================
-- Audio
--==================================================

local Audio = {}
Audio.__index = Audio

function Audio.new(config, maid)
    local self = setmetatable({}, Audio)
    self.Enabled = config.Enabled ~= false
    self.Volume = tonumber(config.Volume) or 0.30
    self.Sounds = copyTable(DEFAULT_AUDIO)
    mergeTable(self.Sounds, config.Sounds or {})
    self._lastHover = 0

    self.Folder = new("Folder", {
        Name = "LunkaraUI_Audio",
        Parent = SoundService,
    })
    maid:Give(self.Folder)

    self._instances = {}
    for name, soundId in pairs(self.Sounds) do
        local sound = new("Sound", {
            Name = tostring(name),
            SoundId = tostring(soundId or ""),
            Volume = self.Volume,
            Parent = self.Folder,
        })
        self._instances[name] = sound
    end
    return self
end

function Audio:SetVolume(volume)
    self.Volume = clamp(tonumber(volume) or self.Volume, 0, 1)
    for _, sound in pairs(self._instances) do
        sound.Volume = self.Volume
    end
end

function Audio:SetEnabled(enabled)
    self.Enabled = enabled == true
end

function Audio:Play(name)
    if not self.Enabled then
        return
    end
    if name == "Hover" then
        local now = os.clock()
        if now - self._lastHover < 0.06 then
            return
        end
        self._lastHover = now
    end
    local sound = self._instances[name]
    if not sound or sound.SoundId == "" then
        return
    end
    pcall(function()
        sound.TimePosition = 0
        sound:Play()
    end)
end

--==================================================
-- Command helpers
--==================================================

local function normalizePanel(panel)
    if panel == nil or panel == false then
        return {
            Enabled = false,
            AutoOpen = false,
            SubmitText = "Run",
        }
    end
    if panel == true then
        return {
            Enabled = true,
            AutoOpen = true,
            SubmitText = "Run",
        }
    end
    local output = {
        Enabled = panel.Enabled ~= false,
        AutoOpen = panel.AutoOpen ~= false,
        SubmitText = tostring(panel.SubmitText or "Run"),
        Title = panel.Title and tostring(panel.Title) or nil,
        Description = panel.Description and tostring(panel.Description) or nil,
    }
    return output
end

local function normalizeArgument(argument, index)
    argument = argument or {}
    local argType = lower(argument.Type)
    if argType == "" then
        argType = "string"
    end
    local name = trim(argument.Name)
    if name == "" then
        name = "arg" .. tostring(index)
    end
    return {
        Name = name,
        Key = tostring(argument.Key or name),
        Type = argType,
        Required = argument.Required == true,
        Multiple = argument.Multiple == true,
        Greedy = argument.Greedy == true,
        Placeholder = tostring(argument.Placeholder or ""),
        Description = tostring(argument.Description or ""),
        Default = argument.Default,
        Min = tonumber(argument.Min),
        Max = tonumber(argument.Max),
        Step = tonumber(argument.Step or argument.Increment) or 1,
        Choices = type(argument.Choices) == "table" and copyTable(argument.Choices) or (type(argument.Options) == "table" and copyTable(argument.Options) or {}),
    }
end

local function commandVisible(command, context)
    if command.Hidden then
        return false
    end
    if type(command.Visible) == "function" then
        local ok, value = pcall(command.Visible, context)
        return ok and value ~= false
    end
    return command.Visible ~= false
end

local function commandEnabled(command, context)
    if command.Enabled == false then
        return false
    end
    if type(command.Enabled) == "function" then
        local ok, value = pcall(command.Enabled, context)
        return ok and value ~= false
    end
    return true
end

--==================================================
-- LunkaraUI construction
--==================================================

function LunkaraUI.new(config)
    config = mergeTable(copyTable(DEFAULT_CONFIG), config or {})

    local self = setmetatable({}, LunkaraUI)
    self.Config = config
    self.Theme = copyTable(DEFAULT_THEME)
    mergeTable(self.Theme, config.Theme or {})
    if typeof(config.Accent) == "Color3" then
        self.Theme.Accent = config.Accent
    elseif type(config.Accent) == "string" and string.match(config.Accent, "^#%x%x%x%x%x%x$") then
        self.Theme.Accent = Color3.fromHex(config.Accent)
    end

    self._maid = Maid.new()
    self._motion = Motion.new()
    self._audio = Audio.new(config.Audio or {}, self._maid)
    self._destroyed = false

    self._commands = {}
    self._commandsByName = {}
    self._aliases = {}
    self._history = {}
    self._historyIndex = 1
    self._suggestions = {}
    self._suggestionRows = {}
    self._suggestionIndex = 1
    self._helperControllers = {}
    self._activeCommand = nil
    self._activePlayerRefresh = nil
    self._openToken = 0
    self._statusToken = 0

    self:_buildRoot()
    self:_bindInput()
    self:_bindViewport()

    if config.Builtins and config.Builtins.Help ~= false then
        self:RegisterCommand({
            Name = "help",
            Aliases = { "commands", "cmds" },
            Description = "Show all available commands.",
            Hidden = false,
            CloseOnRun = false,
            Callback = function()
                self:Open("")
            end,
        })
    end

    return self
end

function LunkaraUI:_resolveParent()
    if typeof(self.Config.Parent) == "Instance" then
        return self.Config.Parent
    end
    if LocalPlayer then
        return LocalPlayer:WaitForChild("PlayerGui")
    end
    return game:GetService("CoreGui")
end

function LunkaraUI:_buildRoot()
    local theme = self.Theme

    local screen = new("ScreenGui", {
        Name = "LunkaraUI",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 10000,
        Parent = self:_resolveParent(),
    })
    self.ScreenGui = screen
    self._maid:Give(screen)

    -- Fully transparent click-catcher. Never dims the world or another UI.
    local backdrop = new("TextButton", {
        Name = "Backdrop",
        AutoButtonColor = false,
        Text = "",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Visible = false,
        ZIndex = 100,
        Parent = screen,
    })
    self.Backdrop = backdrop

    local launcher = new("TextButton", {
        Name = "Launcher",
        AutoButtonColor = false,
        Text = ";",
        TextColor3 = theme.AccentBright,
        TextSize = 18,
        TextScaled = false,
        Font = FONT.Bold,
        BackgroundColor3 = theme.SurfaceRaised,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(38, 38),
        Visible = self.Config.Launcher.Enabled ~= false,
        ZIndex = 60,
        Parent = screen,
    })
    addCorner(launcher, 13)
    self.Launcher = launcher

    -- Palette outer hairline frame + opaque inner surface.
    local paletteOuter = new("Frame", {
        Name = "PaletteOuter",
        BackgroundColor3 = theme.Border,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(620, 420),
        Visible = false,
        ZIndex = 200,
        Parent = screen,
    })
    addCorner(paletteOuter, 19)
    self.PaletteOuter = paletteOuter

    local palette = new("Frame", {
        Name = "Palette",
        BackgroundColor3 = theme.Surface,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(1, 1),
        Size = UDim2.new(1, -2, 1, -2),
        ZIndex = 201,
        Parent = paletteOuter,
    })
    addCorner(palette, 18)
    self.Palette = palette

    local gradient = new("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, theme.SurfaceTop),
            ColorSequenceKeypoint.new(0.28, theme.Surface),
            ColorSequenceKeypoint.new(1, theme.Surface),
        }),
        Parent = palette,
    })
    self._paletteGradient = gradient

    local inputOuter = new("Frame", {
        Name = "InputOuter",
        BackgroundColor3 = theme.Border,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(14, 14),
        Size = UDim2.new(1, -28, 0, 48),
        ZIndex = 203,
        Parent = palette,
    })
    addCorner(inputOuter, 14)

    local inputSurface = new("Frame", {
        Name = "InputSurface",
        BackgroundColor3 = theme.Input,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(1, 1),
        Size = UDim2.new(1, -2, 1, -2),
        ZIndex = 204,
        Parent = inputOuter,
    })
    addCorner(inputSurface, 13)
    self.InputSurface = inputSurface

    local prefix = makeLabel(inputSurface, tostring(self.Config.Prefix or ";"), TYPE.Title, FONT.Bold, theme.AccentBright, Enum.TextXAlignment.Center)
    prefix.Position = UDim2.fromOffset(10, 0)
    prefix.Size = UDim2.fromOffset(28, 46)
    prefix.ZIndex = 205
    self.PrefixLabel = prefix

    local input = new("TextBox", {
        Name = "CommandInput",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Text = "",
        PlaceholderText = "Type a command",
        PlaceholderColor3 = theme.Muted,
        TextColor3 = theme.Text,
        TextSize = TYPE.Strong,
        TextScaled = false,
        Font = FONT.Regular,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Position = UDim2.fromOffset(42, 0),
        Size = UDim2.new(1, -54, 1, 0),
        ZIndex = 205,
        Parent = inputSurface,
    })
    self.Input = input

    local listClip = new("Frame", {
        Name = "ListClip",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Position = UDim2.fromOffset(14, 74),
        Size = UDim2.new(1, -28, 1, -118),
        ZIndex = 202,
        Parent = palette,
    })

    local list = new("ScrollingFrame", {
        Name = "CommandList",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = theme.Muted,
        CanvasSize = UDim2.fromOffset(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.None,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 203,
        Parent = listClip,
    })
    self.CommandList = list

    local layout = new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
        Parent = list,
    })
    self.CommandLayout = layout

    local footer = new("Frame", {
        Name = "Footer",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 14, 1, -38),
        Size = UDim2.new(1, -28, 0, 24),
        ZIndex = 203,
        Parent = palette,
    })

    local footerLeft = makeLabel(footer, "", TYPE.Small, FONT.Medium, theme.Muted, Enum.TextXAlignment.Left)
    footerLeft.Size = UDim2.new(0.66, 0, 1, 0)
    footerLeft.ZIndex = 204
    self.FooterLeft = footerLeft

    local footerRight = makeLabel(footer, "Tab complete   Enter run   Esc close", TYPE.Small, FONT.Regular, theme.Muted, Enum.TextXAlignment.Right)
    footerRight.AnchorPoint = Vector2.new(1, 0)
    footerRight.Position = UDim2.fromScale(1, 0)
    footerRight.Size = UDim2.new(0.42, 0, 1, 0)
    footerRight.ZIndex = 204
    self.FooterRight = footerRight

    -- Command-specific helper panel. It is a separate surface and never forces
    -- the command list to re-layout while it animates.
    local helperOuter = new("Frame", {
        Name = "HelperOuter",
        BackgroundColor3 = theme.Border,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(340, 420),
        Visible = false,
        ZIndex = 230,
        Parent = screen,
    })
    addCorner(helperOuter, 19)
    self.HelperOuter = helperOuter

    local helper = new("Frame", {
        Name = "Helper",
        BackgroundColor3 = theme.Surface,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(1, 1),
        Size = UDim2.new(1, -2, 1, -2),
        ZIndex = 231,
        Parent = helperOuter,
    })
    addCorner(helper, 18)
    self.Helper = helper

    local helperTitle = makeLabel(helper, "", TYPE.Title, FONT.Bold, theme.Text, Enum.TextXAlignment.Left)
    helperTitle.Position = UDim2.fromOffset(18, 14)
    helperTitle.Size = UDim2.new(1, -72, 0, 24)
    helperTitle.ZIndex = 232
    self.HelperTitle = helperTitle

    local helperDescription = makeLabel(helper, "", TYPE.Small, FONT.Regular, theme.TextSecondary, Enum.TextXAlignment.Left)
    helperDescription.Position = UDim2.fromOffset(18, 39)
    helperDescription.Size = UDim2.new(1, -36, 0, 34)
    helperDescription.TextWrapped = true
    helperDescription.TextYAlignment = Enum.TextYAlignment.Top
    helperDescription.ZIndex = 232
    self.HelperDescription = helperDescription

    local helperClose = new("TextButton", {
        Name = "Close",
        AutoButtonColor = false,
        Text = "×",
        TextColor3 = theme.Muted,
        TextSize = 20,
        TextScaled = false,
        Font = FONT.Regular,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 10),
        Size = UDim2.fromOffset(34, 34),
        ZIndex = 233,
        Parent = helper,
    })
    self.HelperClose = helperClose

    local helperBody = new("ScrollingFrame", {
        Name = "Body",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = theme.Muted,
        Position = UDim2.fromOffset(14, 82),
        Size = UDim2.new(1, -28, 1, -142),
        CanvasSize = UDim2.fromOffset(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.None,
        ZIndex = 232,
        Parent = helper,
    })
    addPadding(helperBody, 4, 4, 0, 8)
    self.HelperBody = helperBody

    local helperLayout = new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 12),
        Parent = helperBody,
    })
    self.HelperLayout = helperLayout

    local submit = new("TextButton", {
        Name = "Submit",
        AutoButtonColor = false,
        Text = "Run",
        TextColor3 = theme.Text,
        TextSize = TYPE.Body,
        TextScaled = false,
        Font = FONT.Bold,
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 14, 1, -48),
        Size = UDim2.new(1, -28, 0, 36),
        ZIndex = 233,
        Parent = helper,
    })
    addCorner(submit, 11)
    self.HelperSubmit = submit

    -- Toast host.
    local toastHost = new("Frame", {
        Name = "ToastHost",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -16, 0, 16),
        Size = UDim2.fromOffset(320, 420),
        ZIndex = 400,
        Parent = screen,
    })
    self.ToastHost = toastHost
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Top,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
        Parent = toastHost,
    })

    self._maid:Give(backdrop.MouseButton1Click:Connect(function()
        if self.HelperOuter.Visible then
            self:_closeHelper()
        else
            self:Close()
        end
    end))

    self._maid:Give(launcher.MouseEnter:Connect(function()
        self._audio:Play("Hover")
        self._motion:Tween(launcher, MOTION.Hover, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
            BackgroundColor3 = theme.InputHover,
        })
    end))
    self._maid:Give(launcher.MouseLeave:Connect(function()
        self._motion:Tween(launcher, MOTION.Hover, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
            BackgroundColor3 = theme.SurfaceRaised,
        })
    end))
    self._maid:Give(launcher.MouseButton1Down:Connect(function()
        self._motion:Tween(launcher, MOTION.Press, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
            BackgroundColor3 = theme.AccentSoft,
        })
    end))
    self._maid:Give(launcher.MouseButton1Click:Connect(function()
        self._audio:Play("Click")
        self:Toggle()
    end))

    self._maid:Give(inputSurface.MouseEnter:Connect(function()
        self._motion:Tween(inputSurface, MOTION.Hover, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
            BackgroundColor3 = theme.InputHover,
        })
    end))
    self._maid:Give(inputSurface.MouseLeave:Connect(function()
        if not input:IsFocused() then
            self._motion:Tween(inputSurface, MOTION.Hover, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
                BackgroundColor3 = theme.Input,
            })
        end
    end))

    self._maid:Give(input.Focused:Connect(function()
        self._motion:Tween(inputSurface, MOTION.Hover, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
            BackgroundColor3 = theme.InputHover,
        })
    end))
    self._maid:Give(input.FocusLost:Connect(function()
        self._motion:Tween(inputSurface, MOTION.Hover, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
            BackgroundColor3 = theme.Input,
        })
    end))

    self._maid:Give(input:GetPropertyChangedSignal("Text"):Connect(function()
        self:_refreshSuggestions()
    end))

    -- TextBox keyboard handling lives on the TextBox itself because Roblox can
    -- mark these keys as processed while it owns focus.
    self._maid:Give(input.InputBegan:Connect(function(keyInput)
        if keyInput.UserInputType ~= Enum.UserInputType.Keyboard then
            return
        end
        if keyInput.KeyCode == Enum.KeyCode.Up then
            self:_moveSuggestion(-1)
        elseif keyInput.KeyCode == Enum.KeyCode.Down then
            self:_moveSuggestion(1)
        elseif keyInput.KeyCode == Enum.KeyCode.Tab then
            self:_applySuggestion(false)
        elseif keyInput.KeyCode == Enum.KeyCode.Return or keyInput.KeyCode == Enum.KeyCode.KeypadEnter then
            self:_activateInput()
        elseif keyInput.KeyCode == Enum.KeyCode.Escape then
            if self.HelperOuter.Visible then
                self:_closeHelper()
            else
                self:Close()
            end
        end
    end))

    self._maid:Give(helperClose.MouseButton1Click:Connect(function()
        self._audio:Play("Click")
        self:_closeHelper()
    end))

    self._maid:Give(helperSubmit.MouseEnter:Connect(function()
        self._audio:Play("Hover")
        self._motion:Tween(helperSubmit, MOTION.Hover, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
            BackgroundColor3 = theme.AccentBright,
        })
    end))
    self._maid:Give(helperSubmit.MouseLeave:Connect(function()
        self._motion:Tween(helperSubmit, MOTION.Hover, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
            BackgroundColor3 = theme.Accent,
        })
    end))
    self._maid:Give(helperSubmit.MouseButton1Click:Connect(function()
        self:_submitHelper()
    end))

    self:_updateGeometry()
end

--==================================================
-- Viewport / geometry
--==================================================

function LunkaraUI:_viewport()
    local camera = Workspace.CurrentCamera
    if camera then
        return camera.ViewportSize
    end
    return Vector2.new(1280, 720)
end

function LunkaraUI:_bindViewport()
    local cameraConnection = nil

    local function bindCamera()
        if cameraConnection then
            cameraConnection:Disconnect()
            cameraConnection = nil
        end
        local camera = Workspace.CurrentCamera
        if camera then
            cameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
                self:_updateGeometry()
            end)
        end
        self:_updateGeometry()
    end

    self._maid:Give(function()
        if cameraConnection then
            cameraConnection:Disconnect()
        end
    end)
    self._maid:Give(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera))
    bindCamera()
end

function LunkaraUI:_updateGeometry()
    if self._destroyed then
        return
    end

    local viewport = self:_viewport()
    local width = math.min(620, math.max(430, roundPixel(viewport.X - 56)))
    local height = math.min(420, math.max(330, roundPixel(viewport.Y - 64)))
    local x = roundPixel((viewport.X - width) / 2)
    local y = roundPixel((viewport.Y - height) / 2)

    self.PaletteOuter.Size = UDim2.fromOffset(width, height)
    self.PaletteOuter.Position = UDim2.fromOffset(x, y)

    local launcherSide = tostring(self.Config.Launcher.Side or "Left")
    local launcherY = clamp(tonumber(self.Config.Launcher.Y) or 0.58, 0.08, 0.92)
    local launcherPxY = roundPixel(viewport.Y * launcherY - 19)
    if string.lower(launcherSide) == "right" then
        self.Launcher.Position = UDim2.fromOffset(roundPixel(viewport.X - 48), launcherPxY)
    else
        self.Launcher.Position = UDim2.fromOffset(10, launcherPxY)
    end

    if self.HelperOuter.Visible then
        self:_positionHelper()
    end
end

function LunkaraUI:_positionHelper()
    local viewport = self:_viewport()
    local palettePos = self.PaletteOuter.Position
    local paletteSize = self.PaletteOuter.Size
    local px = palettePos.X.Offset
    local py = palettePos.Y.Offset
    local pw = paletteSize.X.Offset
    local ph = paletteSize.Y.Offset
    local helperWidth = 340
    local gap = 12

    if viewport.X >= pw + helperWidth + 72 then
        local helperX = px + pw + gap
        if helperX + helperWidth > viewport.X - 16 then
            helperX = px - helperWidth - gap
        end
        self.HelperOuter.Size = UDim2.fromOffset(helperWidth, ph)
        self.HelperOuter.Position = UDim2.fromOffset(helperX, py)
    else
        -- Compact mode: helper sits over the palette body, never off-screen.
        self.HelperOuter.Size = UDim2.fromOffset(math.max(320, pw - 28), math.max(300, ph - 28))
        self.HelperOuter.Position = UDim2.fromOffset(px + 14, py + 14)
    end
end

--==================================================
-- Input / keyboard
--==================================================

function LunkaraUI:_bindInput()
    self._maid:Give(UserInputService.InputBegan:Connect(function(input, processed)
        if self._destroyed or input.UserInputType ~= Enum.UserInputType.Keyboard then
            return
        end

        local focused = UserInputService:GetFocusedTextBox()

        -- The launcher key only acts as a launcher when the user is not typing.
        -- This prevents a semicolon typed inside any TextBox from closing/opening UI.
        if input.KeyCode == self.Config.Key and not focused and not processed then
            self:Toggle()
            return
        end

        if not self:IsOpen() then
            return
        end

        -- Escape also works when focus is elsewhere in the game. When our own
        -- command TextBox has focus it handles Escape locally above.
        if input.KeyCode == Enum.KeyCode.Escape and focused ~= self.Input then
            if self.HelperOuter.Visible then
                self:_closeHelper()
            else
                self:Close()
            end
        end
    end))
end

--==================================================
-- Public open / close API
--==================================================

function LunkaraUI:IsOpen()
    return self.PaletteOuter.Visible == true
end

function LunkaraUI:Open(initialText)
    if self._destroyed then
        return
    end

    self._openToken += 1
    local token = self._openToken
    local target = self.PaletteOuter.Position
    local start = UDim2.fromOffset(target.X.Offset, target.Y.Offset + 8)

    self.Backdrop.Visible = true
    self.PaletteOuter.Position = start
    self.PaletteOuter.Visible = true
    self.Launcher.Visible = false
    self:_closeHelper(true)

    local text = tostring(initialText or "")
    local prefix = tostring(self.Config.Prefix or ";")
    if prefix ~= "" and string.sub(text, 1, #prefix) == prefix then
        text = trim(string.sub(text, #prefix + 1))
    end
    self.Input.Text = text
    self:_refreshSuggestions()

    self._audio:Play("Open")
    self._motion:Tween(self.PaletteOuter, MOTION.Open, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, {
        Position = target,
    })

    task.defer(function()
        if self._destroyed or token ~= self._openToken or not self.PaletteOuter.Visible then
            return
        end
        self.Input:CaptureFocus()
        self.Input.CursorPosition = #self.Input.Text + 1
    end)
end

function LunkaraUI:Close()
    if self._destroyed or not self.PaletteOuter.Visible then
        return
    end

    self._openToken += 1
    local token = self._openToken
    local position = self.PaletteOuter.Position
    self:_closeHelper(true)
    self.Input:ReleaseFocus()
    self._audio:Play("Close")

    self._motion:Tween(self.PaletteOuter, MOTION.Close, Enum.EasingStyle.Quad, Enum.EasingDirection.In, {
        Position = UDim2.fromOffset(position.X.Offset, position.Y.Offset + 6),
    })

    task.delay(MOTION.Close, function()
        if self._destroyed or token ~= self._openToken then
            return
        end
        self.PaletteOuter.Visible = false
        self.Backdrop.Visible = false
        self.Launcher.Visible = self.Config.Launcher.Enabled ~= false
        self:_updateGeometry()
    end)
end

function LunkaraUI:Toggle()
    if self:IsOpen() then
        self:Close()
    else
        self:Open("")
    end
end

-- Compatibility aliases for scripts that call these names.
LunkaraUI.OpenCommandPanel = LunkaraUI.Open
LunkaraUI.ToggleCommandPanel = LunkaraUI.Toggle

function LunkaraUI:SetLauncherVisible(visible)
    self.Config.Launcher.Enabled = visible == true
    if not self:IsOpen() then
        self.Launcher.Visible = visible == true
    end
end

function LunkaraUI:SetKey(keyCode)
    if typeof(keyCode) == "EnumItem" and keyCode.EnumType == Enum.KeyCode then
        self.Config.Key = keyCode
    end
end

function LunkaraUI:SetAudioEnabled(enabled)
    self._audio:SetEnabled(enabled)
end

function LunkaraUI:SetAudioVolume(volume)
    self._audio:SetVolume(volume)
end

--==================================================
-- Command registry
--==================================================

function LunkaraUI:RegisterCommand(config)
    assert(type(config) == "table", "RegisterCommand expects a table")

    local name = lower(config.Name)
    assert(name ~= "", "Command.Name is required")

    if self._commandsByName[name] then
        self:UnregisterCommand(name)
    end

    local command = {
        Name = name,
        DisplayName = tostring(config.DisplayName or config.Name or name),
        Description = tostring(config.Description or ""),
        Category = tostring(config.Category or "General"),
        Syntax = tostring(config.Syntax or name),
        Aliases = {},
        Tags = type(config.Tags) == "table" and copyTable(config.Tags) or {},
        Arguments = {},
        Panel = normalizePanel(config.Panel),
        Callback = config.Callback,
        CanRun = config.CanRun,
        Visible = config.Visible,
        Enabled = config.Enabled,
        Hidden = config.Hidden == true,
        CloseOnRun = config.CloseOnRun,
        Notify = config.Notify == true,
        _ui = self,
    }

    for index, argument in ipairs(config.Arguments or {}) do
        table.insert(command.Arguments, normalizeArgument(argument, index))
    end

    for _, aliasValue in ipairs(config.Aliases or {}) do
        local alias = lower(aliasValue)
        if alias ~= "" and alias ~= name and not table.find(command.Aliases, alias) then
            if not self._commandsByName[alias] and not self._aliases[alias] then
                table.insert(command.Aliases, alias)
                self._aliases[alias] = name
            else
                warn("[LunkaraUI] Alias already used:", alias)
            end
        end
    end

    function command:Destroy()
        if self._ui then
            self._ui:UnregisterCommand(self.Name)
        end
    end

    function command:SetEnabled(enabled)
        self.Enabled = enabled == true
        if self._ui then
            self._ui:_refreshSuggestions()
        end
    end

    self._commandsByName[name] = command
    table.insert(self._commands, command)
    self:_refreshSuggestions()
    return command
end

function LunkaraUI:RegisterCommands(commands)
    local handles = {}
    for _, command in ipairs(commands or {}) do
        table.insert(handles, self:RegisterCommand(command))
    end
    return handles
end

function LunkaraUI:UnregisterCommand(name)
    name = lower(name)
    local canonical = self._aliases[name] or name
    local command = self._commandsByName[canonical]
    if not command then
        return false
    end

    self._commandsByName[canonical] = nil
    for _, alias in ipairs(command.Aliases) do
        if self._aliases[alias] == canonical then
            self._aliases[alias] = nil
        end
    end
    for index = #self._commands, 1, -1 do
        if self._commands[index] == command then
            table.remove(self._commands, index)
            break
        end
    end
    command._ui = nil
    self:_refreshSuggestions()
    return true
end

function LunkaraUI:GetCommand(name)
    name = lower(name)
    local canonical = self._aliases[name] or name
    return self._commandsByName[canonical]
end

function LunkaraUI:GetCommands()
    local context = self:_baseContext()
    local output = {}
    for _, command in ipairs(self._commands) do
        if commandVisible(command, context) then
            table.insert(output, command)
        end
    end
    table.sort(output, function(a, b)
        return a.DisplayName:lower() < b.DisplayName:lower()
    end)
    return output
end

--==================================================
-- Player resolution
--==================================================

function LunkaraUI:ResolvePlayers(query, multiple)
    query = lower(query)
    local allPlayers = Players:GetPlayers()

    if query == "" then
        return {}
    end
    if query == "me" then
        return LocalPlayer and { LocalPlayer } or {}
    end
    if query == "all" then
        return allPlayers
    end
    if query == "others" then
        local output = {}
        for _, player in ipairs(allPlayers) do
            if player ~= LocalPlayer then
                table.insert(output, player)
            end
        end
        return output
    end
    if query == "random" then
        if #allPlayers == 0 then
            return {}
        end
        return { allPlayers[math.random(1, #allPlayers)] }
    end

    local terms = { query }
    if multiple and string.find(query, ",", 1, true) then
        terms = {}
        for term in string.gmatch(query, "[^,]+") do
            table.insert(terms, lower(term))
        end
    end

    local output = {}
    local seen = {}
    for _, term in ipairs(terms) do
        local exact = nil
        local partials = {}
        for _, player in ipairs(allPlayers) do
            local username = string.lower(player.Name)
            local display = string.lower(player.DisplayName)
            if username == term or display == term then
                exact = player
                break
            elseif string.sub(username, 1, #term) == term or string.sub(display, 1, #term) == term then
                table.insert(partials, player)
            end
        end

        if exact and not seen[exact] then
            seen[exact] = true
            table.insert(output, exact)
        else
            table.sort(partials, function(a, b)
                return a.Name:lower() < b.Name:lower()
            end)
            for _, player in ipairs(partials) do
                if not seen[player] then
                    seen[player] = true
                    table.insert(output, player)
                    if not multiple then
                        break
                    end
                end
            end
        end
    end

    return output
end

--==================================================
-- Argument coercion / execution
--==================================================

function LunkaraUI:_coerceArgument(spec, token)
    local argType = spec.Type

    if token == nil or token == "" then
        if spec.Default ~= nil then
            return true, spec.Default
        end
        if spec.Required then
            return false, nil, spec.Name .. " is required"
        end
        return true, nil
    end

    if argType == "number" then
        local number = tonumber(token)
        if not number then
            return false, nil, spec.Name .. " must be a number"
        end
        number = snapNumber(number, spec.Step)
        number = clamp(number, spec.Min, spec.Max)
        return true, number
    elseif argType == "boolean" or argType == "bool" then
        local normalized = lower(token)
        if normalized == "true" or normalized == "on" or normalized == "yes" or normalized == "1" then
            return true, true
        elseif normalized == "false" or normalized == "off" or normalized == "no" or normalized == "0" then
            return true, false
        end
        return false, nil, spec.Name .. " must be true or false"
    elseif argType == "choice" or argType == "option" then
        local normalized = lower(token)
        local partial = nil
        for _, choice in ipairs(spec.Choices) do
            local text = tostring(choice)
            local lowered = lower(text)
            if lowered == normalized then
                return true, choice
            elseif string.sub(lowered, 1, #normalized) == normalized and partial == nil then
                partial = choice
            end
        end
        if partial ~= nil then
            return true, partial
        end
        return false, nil, spec.Name .. " is not a valid option"
    elseif argType == "player" then
        local players = self:ResolvePlayers(token, spec.Multiple)
        if #players == 0 then
            return false, nil, "No player matched " .. tostring(token)
        end
        if spec.Multiple then
            return true, players
        end
        return true, players[1]
    end

    return true, tostring(token)
end

function LunkaraUI:_parseArguments(command, args, allowMissing)
    local named = {}
    local ordered = {}
    local missing = {}
    local index = 1

    for _, spec in ipairs(command.Arguments) do
        local token = args[index]
        if spec.Greedy then
            token = index <= #args and table.concat(args, " ", index) or nil
            index = #args + 1
        else
            index += 1
        end

        local ok, value, err = self:_coerceArgument(spec, token)
        if not ok then
            if allowMissing and (token == nil or token == "") then
                table.insert(missing, spec)
                value = spec.Default
            else
                return false, nil, nil, nil, err
            end
        elseif value == nil and spec.Required then
            if allowMissing then
                table.insert(missing, spec)
            else
                return false, nil, nil, nil, spec.Name .. " is required"
            end
        end

        named[spec.Key] = value
        table.insert(ordered, value)
    end

    -- Preserve extra arguments for commands that intentionally read raw args.
    local extras = {}
    while index <= #args do
        table.insert(extras, args[index])
        index += 1
    end

    return true, named, ordered, extras, missing
end

function LunkaraUI:_baseContext()
    local context = {
        UI = self,
        Player = LocalPlayer,
        Players = Players,
    }

    context.ResolvePlayers = function(a, b, c)
        if a == context then
            return self:ResolvePlayers(b, c)
        end
        return self:ResolvePlayers(a, b)
    end
    context.Notify = function(a, b)
        self:Notify(a == context and b or a)
    end
    context.Open = function(a, b)
        self:Open(a == context and b or a)
    end
    context.Close = function()
        self:Close()
    end

    return context
end

function LunkaraUI:_canRun(command, context)
    if not commandEnabled(command, context) then
        return false, "Command is disabled"
    end
    if type(command.CanRun) == "function" then
        local ok, allowed, reason = pcall(command.CanRun, context)
        if not ok then
            return false, tostring(allowed)
        end
        if allowed == false then
            return false, tostring(reason or "Command is unavailable")
        end
    end
    return true
end

function LunkaraUI:_pushHistory(raw)
    raw = trim(raw)
    if raw == "" then
        return
    end
    if self._history[#self._history] ~= raw then
        table.insert(self._history, raw)
    end
    while #self._history > 50 do
        table.remove(self._history, 1)
    end
    self._historyIndex = #self._history + 1
end

function LunkaraUI:_runCommand(command, rawArgs, valuesOverride, metadata)
    local context = self:_baseContext()
    context.Command = command
    context.RawArguments = rawArgs or {}
    context.FromPanel = metadata and metadata.FromPanel == true or false

    local allowed, reason = self:_canRun(command, context)
    if not allowed then
        self:_setStatus(reason, true)
        self._audio:Play("Error")
        return false, reason
    end

    local named, ordered, extras
    if valuesOverride then
        named = valuesOverride
        ordered = {}
        for _, spec in ipairs(command.Arguments) do
            table.insert(ordered, named[spec.Key])
        end
        extras = {}
    else
        local ok, parsedNamed, parsedOrdered, parsedExtras, missingOrError = self:_parseArguments(command, rawArgs or {}, false)
        if not ok then
            self:_setStatus(missingOrError, true)
            self._audio:Play("Error")
            return false, missingOrError
        end
        named = parsedNamed
        ordered = parsedOrdered
        extras = parsedExtras
    end

    context.Values = named
    context.OrderedValues = ordered
    context.ExtraArguments = extras

    local ok, a, b = safeCall(command.Callback, context, named, rawArgs or {})
    if not ok then
        local message = tostring(a)
        self:_setStatus(message, true)
        self._audio:Play("Error")
        return false, message
    end

    if a == false then
        local message = tostring(b or "Command failed")
        self:_setStatus(message, true)
        self._audio:Play("Error")
        return false, message
    end

    local message = nil
    if type(a) == "string" then
        message = a
    elseif type(b) == "string" then
        message = b
    end

    if message and message ~= "" then
        self:_setStatus(message, false)
        if command.Notify then
            self:Notify({ Type = "Success", Text = message })
        end
    else
        self:_setStatus(command.DisplayName .. " executed", false)
    end

    self._audio:Play("Click")

    local shouldClose = command.CloseOnRun
    if shouldClose == nil then
        shouldClose = self.Config.CloseOnExecute == true
    end
    if shouldClose then
        self:Close()
    else
        self:_closeHelper()
        self.Input.Text = ""
        self.Input:CaptureFocus()
    end

    return true, message
end

function LunkaraUI:ExecuteCommand(raw, options)
    raw = trim(raw)
    if raw == "" then
        return false, "No command entered"
    end

    local prefix = tostring(self.Config.Prefix or ";")
    if prefix ~= "" and string.sub(raw, 1, #prefix) == prefix then
        raw = trim(string.sub(raw, #prefix + 1))
    end

    local parts = tokenize(raw)
    local commandName = lower(table.remove(parts, 1) or "")
    local command = self:GetCommand(commandName)
    if not command then
        local message = "Unknown command: " .. commandName
        self:_setStatus(message, true)
        self._audio:Play("Error")
        return false, message
    end

    self:_pushHistory(raw)

    local ok, _, _, _, missingOrError = self:_parseArguments(command, parts, true)
    if ok and type(missingOrError) == "table" and #missingOrError > 0 then
        if command.Panel.Enabled then
            self:_openHelper(command, parts)
            return true, "panel"
        end
        local message = missingOrError[1].Name .. " is required"
        self:_setStatus(message, true)
        return false, message
    end

    local strictOk, _, _, _, strictError = self:_parseArguments(command, parts, false)
    if not strictOk then
        if command.Panel.Enabled then
            self:_openHelper(command, parts)
            return true, "panel"
        end
        self:_setStatus(strictError, true)
        return false, strictError
    end

    return self:_runCommand(command, parts, nil, options)
end

--==================================================
-- Suggestions / autocomplete
--==================================================

function LunkaraUI:_inputState()
    local text = self.Input.Text
    local endedWithSpace = string.match(text, "%s$") ~= nil
    local tokens = tokenize(text)

    if #tokens == 0 then
        return {
            Tokens = {},
            Command = nil,
            CommandText = "",
            ArgumentIndex = 0,
            Partial = "",
            EndedWithSpace = endedWithSpace,
        }
    end

    local commandText = tokens[1]
    local command = self:GetCommand(commandText)
    local argumentIndex
    local partial

    if endedWithSpace then
        argumentIndex = #tokens
        partial = ""
    else
        argumentIndex = #tokens - 1
        partial = tokens[#tokens] or ""
    end

    return {
        Tokens = tokens,
        Command = command,
        CommandText = commandText,
        ArgumentIndex = argumentIndex,
        Partial = partial,
        EndedWithSpace = endedWithSpace,
    }
end

function LunkaraUI:_commandSuggestions(query)
    local context = self:_baseContext()
    local scored = {}

    for _, command in ipairs(self._commands) do
        if commandVisible(command, context) then
            local haystack = command.Name .. " " .. command.DisplayName .. " " .. command.Description .. " " .. command.Category .. " " .. table.concat(command.Aliases, " ") .. " " .. table.concat(command.Tags, " ")
            local score = fuzzyScore(query, haystack)
            if score >= 0 then
                table.insert(scored, {
                    Kind = "Command",
                    Command = command,
                    Score = score,
                    Primary = command.DisplayName,
                    Secondary = command.Description ~= "" and command.Description or command.Syntax,
                })
            end
        end
    end

    table.sort(scored, function(a, b)
        if a.Score == b.Score then
            return a.Command.DisplayName:lower() < b.Command.DisplayName:lower()
        end
        return a.Score > b.Score
    end)

    return scored
end

function LunkaraUI:_argumentSuggestions(command, spec, partial)
    local results = {}
    partial = lower(partial)

    if spec.Type == "player" then
        for _, player in ipairs(Players:GetPlayers()) do
            local haystack = player.Name .. " " .. player.DisplayName
            local score = fuzzyScore(partial, haystack)
            if score >= 0 then
                local secondary = player.DisplayName ~= player.Name and ("@" .. player.Name) or "Player"
                table.insert(results, {
                    Kind = "Argument",
                    Command = command,
                    Argument = spec,
                    Value = player.Name,
                    Score = score,
                    Primary = player.DisplayName,
                    Secondary = secondary,
                })
            end
        end
    elseif spec.Type == "choice" or spec.Type == "option" then
        for _, choice in ipairs(spec.Choices) do
            local value = tostring(choice)
            local score = fuzzyScore(partial, value)
            if score >= 0 then
                table.insert(results, {
                    Kind = "Argument",
                    Command = command,
                    Argument = spec,
                    Value = value,
                    Score = score,
                    Primary = value,
                    Secondary = spec.Name,
                })
            end
        end
    elseif spec.Type == "boolean" or spec.Type == "bool" then
        for _, value in ipairs({ "true", "false" }) do
            local score = fuzzyScore(partial, value)
            if score >= 0 then
                table.insert(results, {
                    Kind = "Argument",
                    Command = command,
                    Argument = spec,
                    Value = value,
                    Score = score,
                    Primary = value,
                    Secondary = spec.Name,
                })
            end
        end
    end

    table.sort(results, function(a, b)
        if a.Score == b.Score then
            return a.Primary:lower() < b.Primary:lower()
        end
        return a.Score > b.Score
    end)

    return results
end

function LunkaraUI:_clearSuggestionRows()
    for _, row in ipairs(self._suggestionRows) do
        if row.Maid then
            row.Maid:Cleanup()
        end
        if row.Frame and row.Frame.Parent then
            row.Frame:Destroy()
        end
    end
    self._suggestionRows = {}
end

function LunkaraUI:_refreshSuggestions()
    if self._destroyed or not self.CommandList then
        return
    end

    self:_clearSuggestionRows()
    self._suggestions = {}

    local state = self:_inputState()
    if state.Command and state.ArgumentIndex >= 1 then
        local spec = state.Command.Arguments[state.ArgumentIndex]
        if spec then
            self._suggestions = self:_argumentSuggestions(state.Command, spec, state.Partial)
        end
    end

    if #self._suggestions == 0 then
        if state.Command and state.ArgumentIndex >= 1 then
            self._suggestions = {
                {
                    Kind = "Command",
                    Command = state.Command,
                    Score = 1000,
                    Primary = state.Command.DisplayName,
                    Secondary = state.Command.Description ~= "" and state.Command.Description or state.Command.Syntax,
                },
            }
        else
            local query = state.Command and state.Command.Name or state.CommandText
            self._suggestions = self:_commandSuggestions(query)
        end
    end

    local maxResults = math.max(1, tonumber(self.Config.MaxResults) or 9)
    while #self._suggestions > maxResults do
        table.remove(self._suggestions)
    end

    self._suggestionIndex = clamp(self._suggestionIndex, 1, math.max(1, #self._suggestions))
    if #self._suggestions > 0 and self._suggestionIndex > #self._suggestions then
        self._suggestionIndex = 1
    end

    for index, suggestion in ipairs(self._suggestions) do
        self:_createSuggestionRow(index, suggestion)
    end

    self.CommandList.CanvasSize = UDim2.fromOffset(0, #self._suggestions * 58)
    self:_updateSuggestionVisuals()
    self:_updateFooter()
end

function LunkaraUI:_createSuggestionRow(index, suggestion)
    local theme = self.Theme
    local rowMaid = Maid.new()

    local row = new("TextButton", {
        Name = "Suggestion" .. tostring(index),
        AutoButtonColor = false,
        Text = "",
        BackgroundColor3 = theme.Row,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -2, 0, 52),
        LayoutOrder = index,
        ZIndex = 204,
        Parent = self.CommandList,
    })
    addCorner(row, 11)

    local title = makeLabel(row, suggestion.Primary, TYPE.Strong, FONT.Medium, theme.Text, Enum.TextXAlignment.Left)
    title.Position = UDim2.fromOffset(14, 5)
    title.Size = UDim2.new(1, -28, 0, 23)
    title.TextTruncate = Enum.TextTruncate.AtEnd
    title.ZIndex = 205

    local secondary = makeLabel(row, suggestion.Secondary or "", TYPE.Small, FONT.Regular, theme.Muted, Enum.TextXAlignment.Left)
    secondary.Position = UDim2.fromOffset(14, 28)
    secondary.Size = UDim2.new(1, -28, 0, 18)
    secondary.TextTruncate = Enum.TextTruncate.AtEnd
    secondary.ZIndex = 205

    rowMaid:Give(row.MouseEnter:Connect(function()
        self._audio:Play("Hover")
        self._suggestionIndex = index
        self:_updateSuggestionVisuals()
    end))

    rowMaid:Give(row.MouseButton1Click:Connect(function()
        self._suggestionIndex = index
        self:_applySuggestion(true)
    end))

    table.insert(self._suggestionRows, {
        Frame = row,
        Title = title,
        Secondary = secondary,
        Maid = rowMaid,
    })
end

function LunkaraUI:_updateSuggestionVisuals()
    for index, item in ipairs(self._suggestionRows) do
        local selected = index == self._suggestionIndex
        self._motion:Tween(item.Frame, MOTION.Hover, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
            BackgroundTransparency = selected and 0 or 1,
            BackgroundColor3 = selected and self.Theme.RowSelected or self.Theme.Row,
        })
        item.Title.TextColor3 = selected and self.Theme.Text or self.Theme.TextSecondary
        item.Secondary.TextColor3 = self.Theme.Muted
    end
end

function LunkaraUI:_moveSuggestion(direction)
    if #self._suggestions == 0 then
        return
    end
    self._suggestionIndex += direction
    if self._suggestionIndex < 1 then
        self._suggestionIndex = #self._suggestions
    elseif self._suggestionIndex > #self._suggestions then
        self._suggestionIndex = 1
    end
    self:_updateSuggestionVisuals()
end

function LunkaraUI:_replaceCurrentArgument(value)
    local state = self:_inputState()
    local tokens = state.Tokens
    if #tokens == 0 then
        return
    end

    if state.EndedWithSpace then
        table.insert(tokens, tostring(value))
    else
        tokens[#tokens] = tostring(value)
    end

    self.Input.Text = joinTokens(tokens) .. " "
    self.Input.CursorPosition = #self.Input.Text + 1
end

function LunkaraUI:_applySuggestion(fromClick)
    local suggestion = self._suggestions[self._suggestionIndex]
    if not suggestion then
        return
    end

    self._audio:Play("Click")

    if suggestion.Kind == "Command" then
        local command = suggestion.Command
        self.Input.Text = command.Name .. " "
        self.Input.CursorPosition = #self.Input.Text + 1

        if fromClick and command.Panel.Enabled and command.Panel.AutoOpen then
            self:_openHelper(command, {})
        else
            self.Input:CaptureFocus()
        end
    else
        self:_replaceCurrentArgument(suggestion.Value)
        self.Input:CaptureFocus()
    end
end

function LunkaraUI:_activateInput()
    local raw = trim(self.Input.Text)

    if raw == "" then
        local suggestion = self._suggestions[self._suggestionIndex]
        if suggestion and suggestion.Kind == "Command" then
            self:_applySuggestion(true)
        end
        return
    end

    local parts = tokenize(raw)
    local command = self:GetCommand(parts[1] or "")
    if not command then
        local suggestion = self._suggestions[self._suggestionIndex]
        if suggestion then
            self:_applySuggestion(false)
        end
        return
    end

    table.remove(parts, 1)
    local ok, _, _, _, missingOrError = self:_parseArguments(command, parts, true)
    if ok and type(missingOrError) == "table" and #missingOrError > 0 and command.Panel.Enabled then
        self:_pushHistory(raw)
        self:_openHelper(command, parts)
        return
    end

    self:ExecuteCommand(raw)
end

function LunkaraUI:_updateFooter()
    local suggestion = self._suggestions[self._suggestionIndex]
    if suggestion and suggestion.Command then
        local command = suggestion.Command
        local prefix = tostring(self.Config.Prefix or ";")
        self.FooterLeft.Text = prefix .. command.Syntax
    else
        self.FooterLeft.Text = ""
    end
end

function LunkaraUI:_setStatus(message, isError)
    self._statusToken += 1
    local token = self._statusToken
    self.FooterLeft.Text = tostring(message or "")
    self.FooterLeft.TextColor3 = isError and self.Theme.Danger or self.Theme.TextSecondary
    task.delay(2.4, function()
        if self._destroyed or token ~= self._statusToken then
            return
        end
        self.FooterLeft.TextColor3 = self.Theme.Muted
        self:_updateFooter()
    end)
end

--==================================================
-- Helper panel
--==================================================

function LunkaraUI:_clearHelper()
    self._activePlayerRefresh = nil
    for _, controller in ipairs(self._helperControllers) do
        if controller.Destroy then
            pcall(function() controller:Destroy() end)
        end
    end
    self._helperControllers = {}

    for _, child in ipairs(self.HelperBody:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end
end

function LunkaraUI:_closeHelper(immediate)
    if not self.HelperOuter.Visible then
        return
    end

    self._activeCommand = nil
    self:_clearHelper()

    if immediate then
        self.HelperOuter.Visible = false
        return
    end

    local position = self.HelperOuter.Position
    self._motion:Tween(self.HelperOuter, MOTION.Helper, Enum.EasingStyle.Quad, Enum.EasingDirection.In, {
        Position = UDim2.fromOffset(position.X.Offset + 6, position.Y.Offset),
    })
    task.delay(MOTION.Helper, function()
        if self._destroyed then
            return
        end
        self.HelperOuter.Visible = false
        self:_updateGeometry()
    end)
end

function LunkaraUI:_openHelper(command, seedArgs)
    if not command.Panel.Enabled then
        return
    end

    self:_clearHelper()
    self._activeCommand = command
    self.HelperTitle.Text = command.Panel.Title or command.DisplayName
    self.HelperDescription.Text = command.Panel.Description or command.Description
    self.HelperSubmit.Text = command.Panel.SubmitText or "Run"

    local seedValues = {}
    local parseOk, parsed = self:_parseArguments(command, seedArgs or {}, true)
    if parseOk and type(parsed) == "table" then
        seedValues = parsed
    end

    for index, spec in ipairs(command.Arguments) do
        local initial = seedValues[spec.Key]
        if initial == nil then
            initial = spec.Default
        end
        local controller = self:_createHelperControl(spec, initial, index)
        if controller then
            table.insert(self._helperControllers, controller)
        end
    end

    if #command.Arguments == 0 then
        local label = makeLabel(self.HelperBody, "This command has no additional options.", TYPE.Body, FONT.Regular, self.Theme.TextSecondary, Enum.TextXAlignment.Left)
        label.Size = UDim2.new(1, -4, 0, 44)
        label.TextWrapped = true
        label.LayoutOrder = 1
        label.ZIndex = 233
    end

    task.defer(function()
        if not self.HelperBody.Parent then
            return
        end
        self.HelperBody.CanvasSize = UDim2.fromOffset(0, self.HelperLayout.AbsoluteContentSize.Y + 8)
    end)

    self:_positionHelper()
    local target = self.HelperOuter.Position
    self.HelperOuter.Position = UDim2.fromOffset(target.X.Offset + 8, target.Y.Offset)
    self.HelperOuter.Visible = true
    self._motion:Tween(self.HelperOuter, MOTION.Helper, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, {
        Position = target,
    })
    self._audio:Play("Open")
end

function LunkaraUI:_submitHelper()
    local command = self._activeCommand
    if not command then
        return
    end

    local values = {}
    for _, controller in ipairs(self._helperControllers) do
        local ok, value, err = controller:Get()
        if not ok then
            self:_setStatus(err or "Invalid value", true)
            self._audio:Play("Error")
            return
        end
        values[controller.Spec.Key] = value
    end

    self:_pushHistory(command.Name)
    self:_runCommand(command, {}, values, { FromPanel = true })
end

function LunkaraUI:_createHelperControl(spec, initial, order)
    if spec.Type == "player" then
        return self:_createPlayerControl(spec, initial, order)
    elseif spec.Type == "number" then
        return self:_createNumberControl(spec, initial, order)
    elseif spec.Type == "choice" or spec.Type == "option" then
        return self:_createChoiceControl(spec, initial, order)
    elseif spec.Type == "boolean" or spec.Type == "bool" then
        return self:_createBooleanControl(spec, initial, order)
    else
        return self:_createStringControl(spec, initial, order)
    end
end

function LunkaraUI:_controlFrame(height, order)
    local frame = new("Frame", {
        BackgroundColor3 = self.Theme.SurfaceRaised,
        BorderSizePixel = 0,
        Size = UDim2.new(1, -4, 0, height),
        LayoutOrder = order,
        ZIndex = 233,
        Parent = self.HelperBody,
    })
    addCorner(frame, 13)
    return frame
end

function LunkaraUI:_createPlayerControl(spec, initial, order)
    local theme = self.Theme
    local frame = self:_controlFrame(214, order)
    local maid = Maid.new()
    local selected = {}

    if typeof(initial) == "Instance" and initial:IsA("Player") then
        selected[initial] = true
    elseif type(initial) == "table" then
        for _, player in ipairs(initial) do
            if typeof(player) == "Instance" and player:IsA("Player") then
                selected[player] = true
            end
        end
    end

    local title = makeLabel(frame, spec.Name, TYPE.Body, FONT.Bold, theme.Text, Enum.TextXAlignment.Left)
    title.Position = UDim2.fromOffset(12, 8)
    title.Size = UDim2.new(1, -24, 0, 22)
    title.ZIndex = 234

    local search = new("TextBox", {
        BackgroundColor3 = theme.Input,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Text = "",
        PlaceholderText = spec.Placeholder ~= "" and spec.Placeholder or "Find player",
        PlaceholderColor3 = theme.Muted,
        TextColor3 = theme.Text,
        TextSize = TYPE.Body,
        TextScaled = false,
        Font = FONT.Regular,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(10, 35),
        Size = UDim2.new(1, -20, 0, 34),
        ZIndex = 234,
        Parent = frame,
    })
    addCorner(search, 10)
    addPadding(search, 10, 10, 0, 0)

    local list = new("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = theme.Muted,
        Position = UDim2.fromOffset(10, 76),
        Size = UDim2.new(1, -20, 0, 128),
        CanvasSize = UDim2.fromOffset(0, 0),
        ZIndex = 234,
        Parent = frame,
    })
    local layout = new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 5),
        Parent = list,
    })

    local rowMaids = {}

    local function clearRows()
        for _, rowMaid in ipairs(rowMaids) do
            rowMaid:Cleanup()
        end
        rowMaids = {}
        for _, child in ipairs(list:GetChildren()) do
            if child:IsA("GuiObject") then
                child:Destroy()
            end
        end
    end

    local function refresh()
        clearRows()
        local query = lower(search.Text)
        local candidates = {}
        for _, player in ipairs(Players:GetPlayers()) do
            local score = fuzzyScore(query, player.Name .. " " .. player.DisplayName)
            if query == "" or score >= 0 then
                table.insert(candidates, { Player = player, Score = score })
            end
        end
        table.sort(candidates, function(a, b)
            if a.Score == b.Score then
                return a.Player.Name:lower() < b.Player.Name:lower()
            end
            return a.Score > b.Score
        end)

        for index, entry in ipairs(candidates) do
            if index > 10 then
                break
            end
            local player = entry.Player
            local rowMaid = Maid.new()
            table.insert(rowMaids, rowMaid)

            local row = new("TextButton", {
                AutoButtonColor = false,
                Text = "",
                BackgroundColor3 = selected[player] and theme.RowSelected or theme.Row,
                BorderSizePixel = 0,
                Size = UDim2.new(1, -2, 0, 36),
                LayoutOrder = index,
                ZIndex = 235,
                Parent = list,
            })
            addCorner(row, 10)

            local nameText = player.DisplayName
            if player.DisplayName ~= player.Name then
                nameText = player.DisplayName .. "  @" .. player.Name
            end
            local label = makeLabel(row, nameText, TYPE.Body, FONT.Medium, theme.TextSecondary, Enum.TextXAlignment.Left)
            label.Position = UDim2.fromOffset(10, 0)
            label.Size = UDim2.new(1, -20, 1, 0)
            label.TextTruncate = Enum.TextTruncate.AtEnd
            label.ZIndex = 236

            local function applyState()
                row.BackgroundColor3 = selected[player] and theme.RowSelected or theme.Row
                label.TextColor3 = selected[player] and theme.Text or theme.TextSecondary
            end

            rowMaid:Give(row.MouseEnter:Connect(function()
                self._audio:Play("Hover")
                if not selected[player] then
                    self._motion:Tween(row, MOTION.Hover, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
                        BackgroundColor3 = theme.RowHover,
                    })
                end
            end))
            rowMaid:Give(row.MouseLeave:Connect(applyState))
            rowMaid:Give(row.MouseButton1Click:Connect(function()
                self._audio:Play("Click")
                if spec.Multiple then
                    selected[player] = not selected[player] or nil
                else
                    selected = { [player] = true }
                end
                refresh()
            end))
        end

        list.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 2)
    end

    maid:Give(search:GetPropertyChangedSignal("Text"):Connect(refresh))
    maid:Give(Players.PlayerAdded:Connect(refresh))
    maid:Give(Players.PlayerRemoving:Connect(function(player)
        selected[player] = nil
        refresh()
    end))
    refresh()

    local controller = {
        Spec = spec,
        Frame = frame,
        _maid = maid,
    }

    function controller:Get()
        local output = {}
        for player in pairs(selected) do
            if player.Parent == Players then
                table.insert(output, player)
            end
        end
        table.sort(output, function(a, b) return a.Name < b.Name end)
        if spec.Multiple then
            if spec.Required and #output == 0 then
                return false, nil, spec.Name .. " is required"
            end
            return true, output
        end
        local value = output[1]
        if spec.Required and not value then
            return false, nil, spec.Name .. " is required"
        end
        return true, value
    end

    function controller:Destroy()
        for _, rowMaid in ipairs(rowMaids) do
            rowMaid:Cleanup()
        end
        self._maid:Cleanup()
    end

    return controller
end

function LunkaraUI:_createNumberControl(spec, initial, order)
    local theme = self.Theme
    local hasRange = spec.Min ~= nil and spec.Max ~= nil and spec.Max > spec.Min
    local frame = self:_controlFrame(hasRange and 96 or 70, order)
    local maid = Maid.new()
    local value = tonumber(initial)
    if value == nil then
        value = tonumber(spec.Default) or spec.Min or 0
    end
    value = clamp(snapNumber(value, spec.Step), spec.Min, spec.Max)

    local title = makeLabel(frame, spec.Name, TYPE.Body, FONT.Bold, theme.Text, Enum.TextXAlignment.Left)
    title.Position = UDim2.fromOffset(12, 8)
    title.Size = UDim2.new(1, -104, 0, 22)
    title.ZIndex = 234

    local box = new("TextBox", {
        BackgroundColor3 = theme.Input,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Text = formatNumber(value, spec.Step),
        PlaceholderText = spec.Placeholder,
        PlaceholderColor3 = theme.Muted,
        TextColor3 = theme.Text,
        TextSize = TYPE.Body,
        TextScaled = false,
        Font = FONT.Medium,
        TextXAlignment = Enum.TextXAlignment.Center,
        Position = UDim2.new(1, -90, 0, 7),
        Size = UDim2.fromOffset(78, 28),
        ZIndex = 234,
        Parent = frame,
    })
    addCorner(box, 9)

    local trackButton = nil
    local fill = nil
    local knob = nil
    local dragging = false

    local function setValue(nextValue, updateBox)
        nextValue = tonumber(nextValue)
        if not nextValue then
            return false
        end
        value = clamp(snapNumber(nextValue, spec.Step), spec.Min, spec.Max)
        if updateBox ~= false then
            box.Text = formatNumber(value, spec.Step)
        end
        if hasRange and fill and knob and trackButton then
            local alpha = (value - spec.Min) / (spec.Max - spec.Min)
            alpha = clamp(alpha, 0, 1)
            fill.Size = UDim2.new(alpha, 0, 1, 0)
            knob.Position = UDim2.new(alpha, -6, 0.5, -6)
        end
        return true
    end

    maid:Give(box.FocusLost:Connect(function()
        if not setValue(box.Text, true) then
            box.Text = formatNumber(value, spec.Step)
        end
    end))

    if hasRange then
        trackButton = new("TextButton", {
            AutoButtonColor = false,
            Text = "",
            BackgroundColor3 = theme.Track,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(12, 58),
            Size = UDim2.new(1, -24, 0, 5),
            ZIndex = 234,
            Parent = frame,
        })
        addCorner(trackButton, 3)

        fill = new("Frame", {
            BackgroundColor3 = theme.Accent,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(0, 1),
            ZIndex = 235,
            Parent = trackButton,
        })
        addCorner(fill, 3)

        knob = new("Frame", {
            BackgroundColor3 = theme.Text,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0, 0),
            Size = UDim2.fromOffset(12, 12),
            ZIndex = 236,
            Parent = trackButton,
        })
        addCorner(knob, 6)

        local function valueFromX(x)
            local position = trackButton.AbsolutePosition.X
            local width = math.max(1, trackButton.AbsoluteSize.X)
            local alpha = clamp((x - position) / width, 0, 1)
            return spec.Min + (spec.Max - spec.Min) * alpha
        end

        maid:Give(trackButton.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                self._audio:Play("Click")
                setValue(valueFromX(input.Position.X), true)
            end
        end))

        maid:Give(UserInputService.InputChanged:Connect(function(input)
            if not dragging then
                return
            end
            if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                setValue(valueFromX(input.Position.X), true)
            end
        end))

        maid:Give(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end))

        setValue(value, true)
    end

    local controller = {
        Spec = spec,
        Frame = frame,
        _maid = maid,
    }

    function controller:Get()
        local number = tonumber(box.Text)
        if not number then
            if spec.Required then
                return false, nil, spec.Name .. " must be a number"
            end
            return true, nil
        end
        number = clamp(snapNumber(number, spec.Step), spec.Min, spec.Max)
        return true, number
    end

    function controller:Destroy()
        self._maid:Cleanup()
    end

    return controller
end

function LunkaraUI:_createChoiceControl(spec, initial, order)
    local theme = self.Theme
    local visibleCount = math.min(5, math.max(1, #spec.Choices))
    local frame = self:_controlFrame(42 + visibleCount * 38, order)
    local maid = Maid.new()
    local selected = initial
    if selected == nil then
        selected = spec.Default
    end

    local title = makeLabel(frame, spec.Name, TYPE.Body, FONT.Bold, theme.Text, Enum.TextXAlignment.Left)
    title.Position = UDim2.fromOffset(12, 8)
    title.Size = UDim2.new(1, -24, 0, 22)
    title.ZIndex = 234

    local list = new("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = theme.Muted,
        Position = UDim2.fromOffset(8, 36),
        Size = UDim2.new(1, -16, 1, -44),
        CanvasSize = UDim2.fromOffset(0, 0),
        ZIndex = 234,
        Parent = frame,
    })
    local layout = new("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 5),
        Parent = list,
    })

    local rows = {}
    local function refreshVisuals()
        for _, item in ipairs(rows) do
            local active = tostring(item.Value) == tostring(selected)
            item.Button.BackgroundColor3 = active and theme.RowSelected or theme.Row
            item.Label.TextColor3 = active and theme.Text or theme.TextSecondary
        end
    end

    for index, choice in ipairs(spec.Choices) do
        local button = new("TextButton", {
            AutoButtonColor = false,
            Text = "",
            BackgroundColor3 = theme.Row,
            BorderSizePixel = 0,
            Size = UDim2.new(1, -2, 0, 33),
            LayoutOrder = index,
            ZIndex = 235,
            Parent = list,
        })
        addCorner(button, 10)
        local label = makeLabel(button, tostring(choice), TYPE.Body, FONT.Medium, theme.TextSecondary, Enum.TextXAlignment.Left)
        label.Position = UDim2.fromOffset(10, 0)
        label.Size = UDim2.new(1, -20, 1, 0)
        label.ZIndex = 236
        table.insert(rows, { Button = button, Label = label, Value = choice })

        maid:Give(button.MouseEnter:Connect(function()
            self._audio:Play("Hover")
            if tostring(selected) ~= tostring(choice) then
                self._motion:Tween(button, MOTION.Hover, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
                    BackgroundColor3 = theme.RowHover,
                })
            end
        end))
        maid:Give(button.MouseLeave:Connect(refreshVisuals))
        maid:Give(button.MouseButton1Click:Connect(function()
            self._audio:Play("Click")
            selected = choice
            refreshVisuals()
        end))
    end

    list.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 2)
    refreshVisuals()

    local controller = { Spec = spec, Frame = frame, _maid = maid }
    function controller:Get()
        if selected == nil and spec.Required then
            return false, nil, spec.Name .. " is required"
        end
        return true, selected
    end
    function controller:Destroy()
        self._maid:Cleanup()
    end
    return controller
end

function LunkaraUI:_createBooleanControl(spec, initial, order)
    local theme = self.Theme
    local frame = self:_controlFrame(52, order)
    local maid = Maid.new()
    local value = initial
    if value == nil then
        value = spec.Default == true
    end
    value = value == true

    local title = makeLabel(frame, spec.Name, TYPE.Body, FONT.Bold, theme.Text, Enum.TextXAlignment.Left)
    title.Position = UDim2.fromOffset(12, 0)
    title.Size = UDim2.new(1, -76, 1, 0)
    title.ZIndex = 234

    local toggle = new("TextButton", {
        AutoButtonColor = false,
        Text = "",
        BackgroundColor3 = theme.Track,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(38, 22),
        ZIndex = 234,
        Parent = frame,
    })
    addCorner(toggle, 11)

    local knob = new("Frame", {
        BackgroundColor3 = theme.Text,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(16, 16),
        ZIndex = 235,
        Parent = toggle,
    })
    addCorner(knob, 8)

    local function refresh(animated)
        local goals = {
            BackgroundColor3 = value and theme.Accent or theme.Track,
        }
        local knobGoal = {
            Position = value and UDim2.fromOffset(19, 3) or UDim2.fromOffset(3, 3),
        }
        if animated then
            self._motion:Tween(toggle, MOTION.Hover, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, goals)
            self._motion:Tween(knob, MOTION.Hover, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, knobGoal)
        else
            toggle.BackgroundColor3 = goals.BackgroundColor3
            knob.Position = knobGoal.Position
        end
    end

    maid:Give(toggle.MouseButton1Click:Connect(function()
        value = not value
        self._audio:Play("Toggle")
        refresh(true)
    end))
    refresh(false)

    local controller = { Spec = spec, Frame = frame, _maid = maid }
    function controller:Get()
        return true, value
    end
    function controller:Destroy()
        self._maid:Cleanup()
    end
    return controller
end

function LunkaraUI:_createStringControl(spec, initial, order)
    local theme = self.Theme
    local frame = self:_controlFrame(78, order)
    local maid = Maid.new()

    local title = makeLabel(frame, spec.Name, TYPE.Body, FONT.Bold, theme.Text, Enum.TextXAlignment.Left)
    title.Position = UDim2.fromOffset(12, 7)
    title.Size = UDim2.new(1, -24, 0, 22)
    title.ZIndex = 234

    local box = new("TextBox", {
        BackgroundColor3 = theme.Input,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Text = initial ~= nil and tostring(initial) or (spec.Default ~= nil and tostring(spec.Default) or ""),
        PlaceholderText = spec.Placeholder ~= "" and spec.Placeholder or spec.Name,
        PlaceholderColor3 = theme.Muted,
        TextColor3 = theme.Text,
        TextSize = TYPE.Body,
        TextScaled = false,
        Font = FONT.Regular,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(10, 36),
        Size = UDim2.new(1, -20, 0, 32),
        ZIndex = 234,
        Parent = frame,
    })
    addCorner(box, 10)
    addPadding(box, 10, 10, 0, 0)

    local controller = { Spec = spec, Frame = frame, _maid = maid }
    function controller:Get()
        local value = trim(box.Text)
        if value == "" and spec.Required then
            return false, nil, spec.Name .. " is required"
        end
        if value == "" then
            value = spec.Default
        end
        return true, value
    end
    function controller:Destroy()
        self._maid:Cleanup()
    end
    return controller
end

--==================================================
-- Notifications
--==================================================

function LunkaraUI:Notify(options)
    if self._destroyed then
        return
    end

    options = type(options) == "table" and options or { Text = tostring(options or "") }
    local text = tostring(options.Text or options.Description or options.Message or "")
    if text == "" then
        text = tostring(options.Title or "Done")
    end

    local notificationType = lower(options.Type)
    local accent = self.Theme.Accent
    local sound = "Notification"
    if notificationType == "error" then
        accent = self.Theme.Danger
        sound = "Error"
    elseif notificationType == "success" then
        accent = self.Theme.Success
        sound = "Success"
    end

    local outer = new("Frame", {
        BackgroundColor3 = self.Theme.Border,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(300, 62),
        ZIndex = 401,
        Parent = self.ToastHost,
    })
    addCorner(outer, 15)

    local surface = new("Frame", {
        BackgroundColor3 = self.Theme.SurfaceRaised,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(1, 1),
        Size = UDim2.new(1, -2, 1, -2),
        ZIndex = 402,
        Parent = outer,
    })
    addCorner(surface, 14)

    local marker = new("Frame", {
        BackgroundColor3 = accent,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(10, 10),
        Size = UDim2.fromOffset(3, 40),
        ZIndex = 403,
        Parent = surface,
    })
    addCorner(marker, 2)

    local label = makeLabel(surface, text, TYPE.Body, FONT.Medium, self.Theme.Text, Enum.TextXAlignment.Left)
    label.Position = UDim2.fromOffset(24, 7)
    label.Size = UDim2.new(1, -36, 1, -14)
    label.TextWrapped = true
    label.ZIndex = 403

    self._audio:Play(sound)

    task.delay(tonumber(options.Duration) or 2.8, function()
        if not outer.Parent then
            return
        end
        outer:Destroy()
    end)
end

--==================================================
-- History helpers
--==================================================

function LunkaraUI:GetHistory()
    return copyTable(self._history)
end

function LunkaraUI:ClearHistory()
    self._history = {}
    self._historyIndex = 1
end

--==================================================
-- Destruction
--==================================================

function LunkaraUI:Destroy()
    if self._destroyed then
        return
    end
    self._destroyed = true
    self:_clearSuggestionRows()
    self:_clearHelper()
    self._maid:Cleanup()
end

return LunkaraUI
