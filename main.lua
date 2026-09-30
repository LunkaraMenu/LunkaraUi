--!strict
-- LunkaraUI V1.1.0
-- Production-oriented Roblox Studio UI library + visual Command Center.
-- Client-side UI only. No exploit-only APIs.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local HttpService = game:GetService("HttpService")

local LunkaraUI = {}
LunkaraUI.__index = LunkaraUI
LunkaraUI.Version = "1.1.0"

local DEFAULT_ICONS = {
	Home = "rbxassetid://130068439240504",
	Search = "rbxassetid://122573675988962",
	Widgets = "rbxassetid://18500828732",
	Settings = "rbxassetid://7059346373",
	Info = "rbxassetid://12707252279",
	Minimize = "rbxassetid://77150878131724",
	Maximize = "rbxassetid://117273761878755",
	Close = "rbxassetid://135341415849911",
	Dropdown = "rbxassetid://115283585599534",
	Check = "rbxassetid://9754130783",
	Notification = "rbxassetid://115224157672228",
	Warning = "rbxassetid://14863060512",
	Success = "rbxassetid://15828137559",
}

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

local DEFAULT_THEME = {
	Background = Color3.fromHex("#0F0F0F"),
	BackgroundDeep = Color3.fromHex("#090909"),
	Rail = Color3.fromHex("#0A0A0A"),
	RailDivider = Color3.fromHex("#181818"),
	Header = Color3.fromHex("#0E0E0E"),
	Panel = Color3.fromHex("#131313"),
	PanelHeader = Color3.fromHex("#171717"),
	PanelHover = Color3.fromHex("#181818"),
	Control = Color3.fromHex("#1A1A1A"),
	ControlHover = Color3.fromHex("#1B1B1B"),
	ControlPressed = Color3.fromHex("#202020"),
	Input = Color3.fromHex("#1C1C1C"),
	InputHover = Color3.fromHex("#222222"),
	Accent = Color3.fromHex("#5B00B0"),
	AccentBright = Color3.fromHex("#7500E0"),
	AccentDark = Color3.fromHex("#3E0078"),
	AccentSurface = Color3.fromHex("#1C1027"),
	Text = Color3.fromHex("#F2F2F2"),
	TextSecondary = Color3.fromHex("#BDBDBD"),
	Muted = Color3.fromHex("#747474"),
	Disabled = Color3.fromHex("#505050"),
	Danger = Color3.fromRGB(215, 85, 85),
}

local MOTION = {
	Snap = 0.075,
	Travel = 0.12,
	Settle = 0.16,
	PageCover = 0.055,
	PageReveal = 0.085,
}

-- Typography is intentionally kept on Roblox-native font enum items.
-- Typography stays on native Roblox fonts and integer-pixel layout.
-- No root UIScale, CanvasGroup fade, or TextScaled fallback is used.
local function resolveFont(preferredNames, fallback)
	local items = Enum.Font:GetEnumItems()
	for _, preferred in ipairs(preferredNames) do
		for _, item in ipairs(items) do
			if item.Name == preferred then
				return item
			end
		end
	end
	return fallback
end

local FONT = {
	Regular = resolveFont({ "Arimo", "BuilderSans" }, Enum.Font.Gotham),
	Medium = resolveFont({ "Arimo", "BuilderSansMedium" }, Enum.Font.GothamMedium),
	Bold = resolveFont({ "ArimoBold", "BuilderSansBold" }, Enum.Font.GothamBold),
}

local TYPE = {
	Credit = 11,
	Meta = 11,
	Description = 12,
	Value = 12,
	Body = 13,
	Section = 13,
	Header = 15,
}

local function roundPixel(value)
	return math.floor(value + 0.5)
end

local function evenPixel(value)
	local rounded = roundPixel(value)
	if rounded % 2 ~= 0 then
		rounded -= 1
	end
	return rounded
end

local function copyTable(source)
	local target = {}
	for key, value in pairs(source) do
		if type(value) == "table" then
			target[key] = copyTable(value)
		else
			target[key] = value
		end
	end
	return target
end

local function merge(target, override)
	if type(override) ~= "table" then
		return target
	end
	for key, value in pairs(override) do
		if type(value) == "table" and type(target[key]) == "table" then
			merge(target[key], value)
		else
			target[key] = value
		end
	end
	return target
end

local function normalizeAsset(value)
	if value == nil then
		return nil
	end
	if type(value) == "number" then
		return "rbxassetid://" .. tostring(value)
	end
	if type(value) == "string" then
		if value == "" then
			return nil
		end
		if string.find(value, "rbxassetid://", 1, true) == 1 then
			return value
		end
		local n = tonumber(value)
		if n then
			return "rbxassetid://" .. tostring(math.floor(n))
		end
		return value
	end
	return nil
end

local function safeCallback(callback, ...)
	if type(callback) ~= "function" then
		return
	end
	local ok, err = pcall(callback, ...)
	if not ok then
		warn("[LunkaraUI] Callback error:", err)
	end
end

local function new(className, properties, children)
	local object = Instance.new(className)
	if properties then
		for key, value in pairs(properties) do
			object[key] = value
		end
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = object
		end
	end
	return object
end

local function corner(parent, radius)
	return new("UICorner", {
		CornerRadius = UDim.new(0, radius),
		Parent = parent,
	})
end

local function padding(parent, left, right, top, bottom)
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, left),
		PaddingRight = UDim.new(0, right),
		PaddingTop = UDim.new(0, top),
		PaddingBottom = UDim.new(0, bottom),
		Parent = parent,
	})
end

local function makeTextLabel(parent, text, size, font, color, align)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = text or "",
		TextSize = size,
		TextScaled = false,
		TextWrapped = false,
		RichText = false,
		Font = font,
		TextColor3 = color,
		TextXAlignment = align or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = parent,
	})
end

local function pointInside(guiObject, position)
	if not guiObject or not guiObject.Parent or not guiObject.Visible then
		return false
	end
	local p = guiObject.AbsolutePosition
	local s = guiObject.AbsoluteSize
	return position.X >= p.X and position.X <= p.X + s.X
		and position.Y >= p.Y and position.Y <= p.Y + s.Y
end

local function offsetUDim2(value, x, y)
	return UDim2.new(
		value.X.Scale, value.X.Offset + x,
		value.Y.Scale, value.Y.Offset + y
	)
end

local function applyAccentFamily(theme, accent)
	local h, s, v = accent:ToHSV()
	theme.Accent = accent
	theme.AccentBright = Color3.fromHSV(h, math.clamp(s * 0.98, 0, 1), math.clamp(v * 1.27, 0, 1))
	theme.AccentDark = Color3.fromHSV(h, s, math.clamp(v * 0.68, 0, 1))
	theme.AccentSurface = theme.Background:Lerp(accent, 0.14)
end

local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({ _tasks = {} }, Maid)
end

function Maid:Give(taskItem)
	if taskItem == nil then
		return nil
	end
	table.insert(self._tasks, taskItem)
	return taskItem
end

function Maid:Cleanup()
	for i = #self._tasks, 1, -1 do
		local item = self._tasks[i]
		self._tasks[i] = nil
		local kind = typeof(item)
		if kind == "RBXScriptConnection" then
			if item.Connected then
				item:Disconnect()
			end
		elseif kind == "Instance" then
			item:Destroy()
		elseif type(item) == "function" then
			pcall(item)
		elseif type(item) == "table" then
			if type(item.Destroy) == "function" then
				pcall(function() item:Destroy() end)
			elseif type(item.Cleanup) == "function" then
				pcall(function() item:Cleanup() end)
			end
		end
	end
end

local Motion = {}
Motion.__index = Motion

function Motion.new(intensity)
	return setmetatable({
		_intensity = math.clamp(tonumber(intensity) or 1, 0, 2),
		_active = setmetatable({}, { __mode = "k" }),
	}, Motion)
end

function Motion:_duration(base)
	if self._intensity <= 0 then
		return 0
	end
	local factor = 0.72 + (0.28 * self._intensity)
	return base * factor
end

function Motion:Cancel(instance, properties)
	local records = self._active[instance]
	if not records then
		return
	end
	local propertySet = nil
	if properties then
		propertySet = {}
		for _, property in ipairs(properties) do
			propertySet[property] = true
		end
	end
	for i = #records, 1, -1 do
		local record = records[i]
		local conflict = propertySet == nil
		if propertySet then
			for property in pairs(record.properties) do
				if propertySet[property] then
					conflict = true
					break
				end
			end
		end
		if conflict then
			record.tween:Cancel()
			table.remove(records, i)
		end
	end
	if #records == 0 then
		self._active[instance] = nil
	end
end

function Motion:Tween(instance, duration, style, direction, goals)
	if not instance or not instance.Parent then
		return nil
	end
	local propertyNames = {}
	for property in pairs(goals) do
		table.insert(propertyNames, property)
	end
	self:Cancel(instance, propertyNames)
	local finalDuration = self:_duration(duration)
	if finalDuration <= 0 then
		for property, value in pairs(goals) do
			instance[property] = value
		end
		return nil
	end
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(finalDuration, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out),
		goals
	)
	local properties = {}
	for property in pairs(goals) do
		properties[property] = true
	end
	local record = { tween = tween, properties = properties }
	local records = self._active[instance]
	if not records then
		records = {}
		self._active[instance] = records
	end
	table.insert(records, record)
	local completedConnection
	completedConnection = tween.Completed:Connect(function()
		if completedConnection then
			completedConnection:Disconnect()
		end
		local current = self._active[instance]
		if current then
			for i = #current, 1, -1 do
				if current[i] == record then
					table.remove(current, i)
					break
				end
			end
			if #current == 0 then
				self._active[instance] = nil
			end
		end
	end)
	tween:Play()
	return tween
end

local Audio = {}
Audio.__index = Audio

function Audio.new(config, maid)
	local self = setmetatable({}, Audio)
	self.Enabled = config.Enabled ~= false
	self.Volume = math.clamp(tonumber(config.Volume) or 0.35, 0, 1)
	self.Assets = merge(copyTable(DEFAULT_AUDIO), config.Assets or {})
	self._sounds = {}
	self._lastHover = 0
	self._folder = new("Folder", { Name = "LunkaraUI_Audio", Parent = SoundService })
	maid:Give(self._folder)
	return self
end

function Audio:_get(name)
	if self._sounds[name] then
		return self._sounds[name]
	end
	local id = normalizeAsset(self.Assets[name])
	if not id then
		return nil
	end
	local sound = new("Sound", {
		Name = name,
		SoundId = id,
		Volume = self.Volume,
		RollOffMode = Enum.RollOffMode.Inverse,
		Parent = self._folder,
	})
	self._sounds[name] = sound
	return sound
end

function Audio:Play(name)
	if not self.Enabled then
		return
	end
	if name == "Hover" then
		local now = os.clock()
		if now - self._lastHover < 0.055 then
			return
		end
		self._lastHover = now
	end
	local sound = self:_get(name)
	if not sound then
		return
	end
	pcall(function()
		sound.Volume = self.Volume
		sound.TimePosition = 0
		sound:Play()
	end)
end

local Overlay = {}
Overlay.__index = Overlay

function Overlay.new(ui)
	local self = setmetatable({}, Overlay)
	self.UI = ui
	self.Current = nil
	self.Blocker = new("TextButton", {
		Name = "OverlayBlocker",
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 900,
		Parent = ui._overlayRoot,
	})
	ui._maid:Give(self.Blocker.MouseButton1Click:Connect(function()
		self:Close("outside")
	end))
	return self
end

function Overlay:Close(reason)
	local current = self.Current
	if not current then
		return
	end
	self.Current = nil
	self.Blocker.Visible = false
	self.Blocker.BackgroundTransparency = 1
	if current.onClose then
		safeCallback(current.onClose, reason)
	end
	if current.frame and current.frame.Parent then
		current.frame:Destroy()
	end
end

function Overlay:Open(frame, anchor, options)
	options = options or {}
	self:Close("replace")
	frame.Parent = self.UI._overlayRoot
	frame.ZIndex = 920
	self.Blocker.Visible = true
	self.Blocker.BackgroundTransparency = 1 -- backdrops are intentionally invisible
	self.Current = {
		frame = frame,
		anchor = anchor,
		onClose = options.OnClose,
	}

	RunService.Heartbeat:Wait()
	if not self.Current or self.Current.frame ~= frame or not frame.Parent then
		return
	end

	local viewport = self.UI._overlayRoot.AbsoluteSize
	local popupSize = frame.AbsoluteSize
	local margin = 10
	local x, y
	if options.Center then
		x = roundPixel((viewport.X - popupSize.X) * 0.5)
		y = roundPixel((viewport.Y - popupSize.Y) * 0.5)
	else
		if not anchor or not anchor.Parent then return end
		local anchorPos = anchor.AbsolutePosition - self.UI._overlayRoot.AbsolutePosition
		local anchorSize = anchor.AbsoluteSize
		x = anchorPos.X + anchorSize.X - popupSize.X
		y = anchorPos.Y + anchorSize.Y + 6
		if x + popupSize.X > viewport.X - margin then x = viewport.X - popupSize.X - margin end
		if x < margin then x = margin end
		if y + popupSize.Y > viewport.Y - margin then y = anchorPos.Y - popupSize.Y - 6 end
		if y < margin then y = margin end
	end

	x, y = roundPixel(x), roundPixel(y)
	frame.Position = UDim2.fromOffset(x, y + 4)
	frame.Visible = true
	self.UI._motion:Tween(frame, MOTION.Travel, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, {
		Position = UDim2.fromOffset(x, y),
	})
end

local function cloneArray(values)
	local out = {}
	for _, value in ipairs(values or {}) do table.insert(out, value) end
	return out
end

-- Public read-only-by-convention registries. Copy before mutating in application code.
LunkaraUI.Assets = {
	Icons = DEFAULT_ICONS,
	SFX = DEFAULT_AUDIO,
}


local ControlBase = {}
ControlBase.__index = ControlBase

function ControlBase:SetVisible(visible)
	self._frame.Visible = visible ~= false
	return self
end

function ControlBase:SetDisabled(disabled)
	self._disabled = disabled == true
	if self._applyDisabled then
		self:_applyDisabled()
	end
	return self
end

function ControlBase:SetTitle(title)
	self.Title = tostring(title or "")
	if self._titleLabel then
		self._titleLabel.Text = self.Title
	end
	return self
end

function ControlBase:SetDescription(description)
	self.Description = description and tostring(description) or nil
	if self._descriptionLabel then
		self._descriptionLabel.Text = self.Description or ""
		self._descriptionLabel.Visible = self.Description ~= nil and self.Description ~= ""
	end
	return self
end

function ControlBase:Destroy()
	if self._destroyed then return end
	self._destroyed = true
	if self.Flag and self._ui and self._ui._flagControls[self.Flag] == self then
		self._ui._flagControls[self.Flag] = nil
	end
	if self._ui and self._ui._capturingKeybind == self then self._ui._capturingKeybind = nil end
	if self._maid then self._maid:Cleanup() end
	if self._frame then self._frame:Destroy() end
end

local Section = {}
Section.__index = Section

local Subpage = {}
Subpage.__index = Subpage

local Page = {}
Page.__index = Page

local Window = {}
Window.__index = Window

local function createControlShell(section, config, height, rightReserve)
	local ui = section._ui
	local theme = ui.Theme
	local control = setmetatable({}, ControlBase)
	control._ui = ui
	control._section = section
	control._maid = Maid.new()
	control._disabled = config.Disabled == true
	control._hovered = false
	control.Title = tostring(config.Title or "Control")
	control.Description = config.Description and tostring(config.Description) or nil
	control.Flag = config.Flag
	control.Tags = type(config.Tags) == "table" and cloneArray(config.Tags) or {}

	local frame = new("Frame", {
		Name = "Control_" .. control.Title,
		BackgroundColor3 = theme.ControlHover,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, height),
		Parent = section._frame,
	})
	corner(frame, 4)
	control._frame = frame

	local hit = new("TextButton", {
		Name = "Hit",
		AutoButtonColor = false,
		Text = "",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = frame,
	})
	control._hit = hit

	local reserve = tonumber(rightReserve) or 178
	local title = makeTextLabel(frame, control.Title, TYPE.Body, FONT.Medium, theme.Text, Enum.TextXAlignment.Left)
	title.Position = UDim2.fromOffset(10, control.Description and 5 or 0)
	title.Size = UDim2.new(1, -reserve, 0, control.Description and 21 or height)
	title.ZIndex = 3
	control._titleLabel = title

	if control.Description then
		local description = makeTextLabel(frame, control.Description, TYPE.Description, FONT.Regular, theme.Muted, Enum.TextXAlignment.Left)
		description.Position = UDim2.fromOffset(10, 24)
		description.Size = UDim2.new(1, -reserve, 0, 15)
		description.ZIndex = 3
		control._descriptionLabel = description
	end

	control._maid:Give(hit.MouseEnter:Connect(function()
		if control._disabled then
			return
		end
		control._hovered = true
		ui._audio:Play("Hover")
		ui._motion:Tween(frame, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
			BackgroundTransparency = 0,
		})
	end))
	control._maid:Give(hit.MouseLeave:Connect(function()
		control._hovered = false
		if control._disabled then
			return
		end
		ui._motion:Tween(frame, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
			BackgroundTransparency = 1,
		})
	end))

	function control:_applyDisabled()
		hit.Active = not self._disabled
		title.TextColor3 = self._disabled and theme.Disabled or theme.Text
		if self._descriptionLabel then
			self._descriptionLabel.TextColor3 = self._disabled and theme.Disabled or theme.Muted
		end
		ui._motion:Tween(frame, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
			BackgroundTransparency = self._disabled and 0 or (self._hovered and 0 or 1),
			BackgroundColor3 = self._disabled and theme.BackgroundDeep or theme.ControlHover,
		})
	end

	control:_applyDisabled()
	return control
end

function Section:_registerControl(control)
	control._frame.LayoutOrder = #self._controls + 1
	table.insert(self._controls, control)
	if control.Flag then
		self._ui._flagControls[control.Flag] = control
	end
	table.insert(self._ui._searchControls, control)
	self._maid:Give(control)
	return control
end

function Section:AddToggle(config)
	config = config or {}
	local control = createControlShell(self, config, config.Description and 48 or 34, 62)
	control._kind = "Toggle"
	local ui = self._ui
	local theme = ui.Theme
	local value = config.Default == true
	control.Value = value

	local box = new("Frame", {
		Name = "ToggleBox",
		BackgroundColor3 = value and theme.Accent or theme.Input,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -19, 0.5, 0),
		Size = UDim2.fromOffset(17, 17),
		ZIndex = 4,
		Parent = control._frame,
	})
	corner(box, 3)

	local check = new("ImageLabel", {
		Name = "Check",
		BackgroundTransparency = 1,
		Image = ui.Icons.Check,
		ImageColor3 = theme.Text,
		ImageTransparency = value and 0 or 1,
		ScaleType = Enum.ScaleType.Fit,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(11, 11),
		ZIndex = 5,
		Parent = box,
	})

	local function render(animated)
		local duration = animated and MOTION.Travel or 0
		ui._motion:Tween(box, duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, {
			BackgroundColor3 = control.Value and theme.Accent or theme.Input,
		})
		ui._motion:Tween(check, duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
			ImageTransparency = control.Value and 0 or 1,
		})
	end

	function control:SetValue(nextValue, silent)
		if self._destroyed then
			return self
		end
		nextValue = nextValue == true
		if self.Value == nextValue then
			return self
		end
		self.Value = nextValue
		if self.Flag then
			ui.Flags[self.Flag] = nextValue
		end
		render(true)
		if not silent then
			ui._audio:Play("Toggle")
			safeCallback(config.Callback, nextValue)
		end
		return self
	end
	control.Set = control.SetValue

	control._maid:Give(control._hit.MouseButton1Click:Connect(function()
		if control._disabled then
			return
		end
		control:SetValue(not control.Value)
	end))

	if control.Flag then
		ui.Flags[control.Flag] = value
	end
	render(false)
	return self:_registerControl(control)
end

function Section:AddSlider(config)
	config = config or {}
	local control = createControlShell(self, config, config.Description and 64 or 52, 76)
	control._kind = "Slider"
	local ui = self._ui
	local theme = ui.Theme
	local minValue = tonumber(config.Min) or 0
	local maxValue = tonumber(config.Max) or 100
	if maxValue <= minValue then
		maxValue = minValue + 1
	end
	local step = math.abs(tonumber(config.Step) or 1)
	if step == 0 then
		step = 1
	end
	local decimals = tonumber(config.Decimals)
	if decimals == nil then
		local stepText = tostring(step)
		local dot = string.find(stepText, ".", 1, true)
		decimals = dot and (#stepText - dot) or 0
	end
	decimals = math.clamp(math.floor(decimals), 0, 4)
	local suffix = tostring(config.Suffix or "")
	local value = math.clamp(tonumber(config.Default) or minValue, minValue, maxValue)
	control.Value = value

	local valueLabel = makeTextLabel(control._frame, "", TYPE.Value, FONT.Medium, theme.TextSecondary, Enum.TextXAlignment.Right)
	valueLabel.AnchorPoint = Vector2.new(1, 0)
	valueLabel.Position = UDim2.new(1, -10, 0, config.Description and 5 or 0)
	valueLabel.Size = UDim2.fromOffset(64, config.Description and 21 or 30)
	valueLabel.ZIndex = 4

	local bar = new("Frame", {
		Name = "SliderBar",
		BackgroundColor3 = theme.Input,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 10, 1, -13),
		Size = UDim2.new(1, -20, 0, 3),
		ZIndex = 4,
		Parent = control._frame,
	})
	corner(bar, 2)
	local fill = new("Frame", {
		Name = "Fill",
		BackgroundColor3 = theme.Accent,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 5,
		Parent = bar,
	})
	corner(fill, 2)
	local handle = new("Frame", {
		Name = "Handle",
		BackgroundColor3 = theme.AccentBright,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(9, 9),
		ZIndex = 6,
		Parent = bar,
	})
	corner(handle, 5)

	local dragHit = new("TextButton", {
		Name = "SliderHit",
		AutoButtonColor = false,
		Text = "",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 6, 1, -24),
		Size = UDim2.new(1, -12, 0, 22),
		ZIndex = 8,
		Parent = control._frame,
	})

	local function quantize(raw)
		local units = math.floor(((raw - minValue) / step) + 0.5)
		return math.clamp(minValue + units * step, minValue, maxValue)
	end

	local function textValue(v)
		if decimals == 0 then
			return tostring(math.floor(v + 0.5)) .. suffix
		end
		return string.format("%." .. tostring(decimals) .. "f", v) .. suffix
	end

	local function render(animated)
		local alpha = (control.Value - minValue) / (maxValue - minValue)
		valueLabel.Text = textValue(control.Value)
		if animated then
			ui._motion:Tween(fill, MOTION.Travel, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, {
				Size = UDim2.fromScale(alpha, 1),
			})
			ui._motion:Tween(handle, MOTION.Travel, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, {
				Position = UDim2.fromScale(alpha, 0.5),
			})
		else
			ui._motion:Cancel(fill, { "Size" })
			ui._motion:Cancel(handle, { "Position" })
			fill.Size = UDim2.fromScale(alpha, 1)
			handle.Position = UDim2.fromScale(alpha, 0.5)
		end
	end

	local function assign(nextValue, silent, animated)
		nextValue = quantize(tonumber(nextValue) or minValue)
		if math.abs(control.Value - nextValue) < 1e-7 then
			return false
		end
		control.Value = nextValue
		if control.Flag then
			ui.Flags[control.Flag] = nextValue
		end
		render(animated)
		if not silent then
			safeCallback(config.Callback, nextValue)
		end
		return true
	end

	function control:SetValue(nextValue, silent)
		assign(nextValue, silent, true)
		return self
	end
	control.Set = control.SetValue

	local function setFromX(x, silent)
		if control._disabled then
			return
		end
		local width = math.max(bar.AbsoluteSize.X, 1)
		local alpha = math.clamp((x - bar.AbsolutePosition.X) / width, 0, 1)
		assign(minValue + (maxValue - minValue) * alpha, silent, false)
	end

	control._maid:Give(dragHit.InputBegan:Connect(function(input)
		if control._disabled then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		ui._audio:Play("Click")
		local startX = input.Position.X
		local currentAlpha = (control.Value - minValue) / (maxValue - minValue)
		local handleCenter = bar.AbsolutePosition.X + (bar.AbsoluteSize.X * currentAlpha)
		local grabOffset = 0
		if math.abs(startX - handleCenter) <= 13 then
			grabOffset = startX - handleCenter
		else
			setFromX(startX, false)
		end

		ui._motion:Tween(handle, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
			Size = UDim2.fromOffset(11, 11),
			BackgroundColor3 = theme.Text,
		})
		ui._motion:Tween(valueLabel, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
			TextColor3 = theme.AccentBright,
		})

		ui:_beginDrag(function(position)
			setFromX(position.X - grabOffset, false)
		end, function()
			ui._motion:Tween(handle, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
				Size = UDim2.fromOffset(9, 9),
				BackgroundColor3 = theme.AccentBright,
			})
			ui._motion:Tween(valueLabel, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
				TextColor3 = theme.TextSecondary,
			})
		end)
	end))
	control._maid:Give(dragHit.MouseEnter:Connect(function()
		if not control._disabled and ui._activeDrag == nil then
			ui._motion:Tween(handle, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
				Size = UDim2.fromOffset(10, 10),
			})
		end
	end))
	control._maid:Give(dragHit.MouseLeave:Connect(function()
		if ui._activeDrag == nil then
			ui._motion:Tween(handle, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
				Size = UDim2.fromOffset(9, 9),
			})
		end
	end))

	if control.Flag then
		ui.Flags[control.Flag] = value
	end
	render(false)
	return self:_registerControl(control)
end

function Section:AddDropdown(config)
	config = config or {}
	local control = createControlShell(self, config, config.Description and 48 or 38, 180)
	control._kind = "Dropdown"
	local ui = self._ui
	local theme = ui.Theme
	local options = {}
	for _, option in ipairs(config.Options or {}) do
		table.insert(options, tostring(option))
	end
	local value = config.Default and tostring(config.Default) or options[1]
	if value and not table.find(options, value) then
		value = options[1]
	end
	control.Value = value
	control.Options = options
	control._open = false

	local field = new("TextButton", {
		Name = "DropdownField",
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = theme.Input,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -9, 0.5, 0),
		Size = UDim2.fromOffset(154, 26),
		ZIndex = 5,
		Parent = control._frame,
	})
	corner(field, 4)
	local valueLabel = makeTextLabel(field, value or "Select", TYPE.Value, FONT.Medium, theme.TextSecondary, Enum.TextXAlignment.Left)
	valueLabel.Position = UDim2.fromOffset(9, 0)
	valueLabel.Size = UDim2.new(1, -30, 1, 0)
	valueLabel.ZIndex = 6
	local arrow = new("ImageLabel", {
		Name = "Arrow",
		BackgroundTransparency = 1,
		Image = ui.Icons.Dropdown,
		ImageColor3 = theme.Muted,
		ScaleType = Enum.ScaleType.Fit,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(12, 12),
		ZIndex = 6,
		Parent = field,
	})

	local function updateValue(nextValue, silent)
		if nextValue == nil then
			return
		end
		nextValue = tostring(nextValue)
		if not table.find(control.Options, nextValue) then
			return
		end
		if control.Value == nextValue then
			return
		end
		control.Value = nextValue
		valueLabel.Text = nextValue
		if control.Flag then
			ui.Flags[control.Flag] = nextValue
		end
		if not silent then
			safeCallback(config.Callback, nextValue)
		end
	end

	function control:SetValue(nextValue, silent)
		updateValue(nextValue, silent)
		return self
	end
	control.Set = control.SetValue

	function control:SetOptions(nextOptions)
		self.Options = {}
		for _, option in ipairs(nextOptions or {}) do
			table.insert(self.Options, tostring(option))
		end
		if self.Value and not table.find(self.Options, self.Value) then
			self.Value = self.Options[1]
			valueLabel.Text = self.Value or "Select"
		end
		return self
	end

	local function closePopup()
		if not control._open then
			return
		end
		control._open = false
		ui._motion:Tween(arrow, MOTION.Travel, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, {
			Rotation = 0,
			ImageColor3 = theme.Muted,
		})
		ui._motion:Tween(field, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
			BackgroundColor3 = theme.Input,
		})
	end

	local function openPopup()
		if control._disabled or control._open then
			return
		end
		control._open = true
		ui._audio:Play("Open")
		ui._motion:Tween(arrow, MOTION.Travel, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, {
			Rotation = 180,
			ImageColor3 = theme.AccentBright,
		})
		ui._motion:Tween(field, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
			BackgroundColor3 = theme.AccentSurface,
		})

		local popupWidth = math.max(154, field.AbsoluteSize.X)
		local popup = new("Frame", {
			Name = "DropdownPopup",
			BackgroundColor3 = theme.Panel,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(popupWidth, math.max(34, (#control.Options * 29) + 10)),
			Visible = false,
		})
		corner(popup, 5)
		padding(popup, 5, 5, 5, 5)
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 1),
			Parent = popup,
		})

		for index, option in ipairs(control.Options) do
			local selected = option == control.Value
			local optionButton = new("TextButton", {
				Name = "Option_" .. option,
				AutoButtonColor = false,
				Text = "",
				BackgroundColor3 = selected and theme.AccentSurface or theme.ControlHover,
				BackgroundTransparency = selected and 0 or 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, 28),
				LayoutOrder = index,
				ZIndex = 925,
				Parent = popup,
			})
			corner(optionButton, 3)
			local marker = new("Frame", {
				BackgroundColor3 = theme.Accent,
				BackgroundTransparency = selected and 0 or 1,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, 6),
				Size = UDim2.fromOffset(2, 16),
				ZIndex = 926,
				Parent = optionButton,
			})
			corner(marker, 1)
			local label = makeTextLabel(optionButton, option, TYPE.Value, FONT.Medium, selected and theme.Text or theme.TextSecondary, Enum.TextXAlignment.Left)
			label.Position = UDim2.fromOffset(9, 0)
			label.Size = UDim2.new(1, -18, 1, 0)
			label.ZIndex = 926
			optionButton.MouseEnter:Connect(function()
				if not selected then
					ui._motion:Tween(optionButton, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
						BackgroundTransparency = 0,
					})
				end
			end)
			optionButton.MouseLeave:Connect(function()
				if not selected then
					ui._motion:Tween(optionButton, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
						BackgroundTransparency = 1,
					})
				end
			end)
			optionButton.MouseButton1Click:Connect(function()
				ui._audio:Play("Click")
				updateValue(option, false)
				ui._overlay:Close("select")
			end)
		end

		ui._overlay:Open(popup, field, {
			OnClose = function()
				closePopup()
			end,
		})
	end

	control._maid:Give(field.MouseButton1Click:Connect(function()
		if control._disabled then
			return
		end
		if control._open then
			ui._overlay:Close("toggle")
		else
			openPopup()
		end
	end))
	control._maid:Give(field.MouseEnter:Connect(function()
		if not control._disabled and not control._open then
			ui._motion:Tween(field, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
				BackgroundColor3 = theme.InputHover,
			})
		end
	end))
	control._maid:Give(field.MouseLeave:Connect(function()
		if not control._open then
			ui._motion:Tween(field, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
				BackgroundColor3 = theme.Input,
			})
		end
	end))

	if control.Flag then
		ui.Flags[control.Flag] = value
	end
	return self:_registerControl(control)
end

function Section:AddButton(config)
	config = config or {}
	local control = createControlShell(self, config, config.Description and 48 or 38, 104)
	control._kind = "Button"
	local ui = self._ui
	local theme = ui.Theme
	local actionText = tostring(config.Action or config.Text or "RUN")
	local emphasis = config.Emphasis ~= false

	local action = new("TextButton", {
		Name = "Action",
		AutoButtonColor = false,
		Text = string.upper(actionText),
		TextSize = TYPE.Meta,
		TextScaled = false,
		Font = FONT.Bold,
		TextColor3 = emphasis and theme.Text or theme.TextSecondary,
		BackgroundColor3 = emphasis and theme.Accent or theme.Input,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -9, 0.5, 0),
		Size = UDim2.fromOffset(math.max(68, 24 + (#actionText * 6)), 26),
		ZIndex = 5,
		Parent = control._frame,
	})
	corner(action, 4)

	local function idleColor()
		return emphasis and theme.Accent or theme.Input
	end

	control._maid:Give(action.MouseEnter:Connect(function()
		if control._disabled then
			return
		end
		ui._audio:Play("Hover")
		ui._motion:Tween(action, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
			BackgroundColor3 = emphasis and theme.AccentBright or theme.InputHover,
		})
	end))
	control._maid:Give(action.MouseLeave:Connect(function()
		if control._disabled then
			return
		end
		ui._motion:Tween(action, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
			BackgroundColor3 = idleColor(),
		})
	end))
	control._maid:Give(action.MouseButton1Down:Connect(function()
		if control._disabled then
			return
		end
		ui._motion:Tween(action, 0.045, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
			BackgroundColor3 = emphasis and theme.AccentDark or theme.ControlPressed,
		})
	end))
	control._maid:Give(action.MouseButton1Up:Connect(function()
		if control._disabled then
			return
		end
		ui._motion:Tween(action, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
			BackgroundColor3 = emphasis and theme.AccentBright or theme.InputHover,
		})
	end))
	control._maid:Give(action.MouseButton1Click:Connect(function()
		if control._disabled then
			return
		end
		ui._audio:Play("Click")
		safeCallback(config.Callback)
	end))

	return self:_registerControl(control)
end


local function cloneArray(values)
	local out = {}
	for _, value in ipairs(values or {}) do
		table.insert(out, value)
	end
	return out
end

local function arrayContains(values, wanted)
	for _, value in ipairs(values or {}) do
		if value == wanted then
			return true
		end
	end
	return false
end

local function removeArrayValue(values, wanted)
	for i = #values, 1, -1 do
		if values[i] == wanted then
			table.remove(values, i)
			return
		end
	end
end

local function colorToHex(color)
	return string.format("#%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

local function parseColor(value, fallback)
	if typeof(value) == "Color3" then
		return value
	end
	if type(value) == "string" then
		local hex = value:gsub("#", "")
		if #hex == 6 and hex:match("^[%x]+$") then
			local ok, result = pcall(Color3.fromHex, "#" .. hex)
			if ok then
				return result
			end
		end
	end
	return fallback or Color3.new(1, 1, 1)
end

function Section:AddRangeSlider(config)
	config = config or {}
	local control = createControlShell(self, config, config.Description and 66 or 54, 112)
	control._kind = "Range Slider"
	local ui = self._ui
	local theme = ui.Theme
	local minValue = tonumber(config.Min) or 0
	local maxValue = tonumber(config.Max) or 100
	if maxValue <= minValue then
		maxValue = minValue + 1
	end
	local step = math.abs(tonumber(config.Step) or 1)
	if step == 0 then step = 1 end
	local suffix = tostring(config.Suffix or "")
	local decimals = math.clamp(math.floor(tonumber(config.Decimals) or 0), 0, 4)
	local defaultLow = tonumber(config.DefaultMin or (type(config.Default) == "table" and config.Default[1])) or minValue
	local defaultHigh = tonumber(config.DefaultMax or (type(config.Default) == "table" and config.Default[2])) or maxValue

	local function quantize(raw)
		local units = math.floor(((raw - minValue) / step) + 0.5)
		return math.clamp(minValue + units * step, minValue, maxValue)
	end
	local low = quantize(math.min(defaultLow, defaultHigh))
	local high = quantize(math.max(defaultLow, defaultHigh))
	control.Value = { low, high }

	local valueLabel = makeTextLabel(control._frame, "", TYPE.Value, FONT.Medium, theme.TextSecondary, Enum.TextXAlignment.Right)
	valueLabel.AnchorPoint = Vector2.new(1, 0)
	valueLabel.Position = UDim2.new(1, -10, 0, config.Description and 5 or 0)
	valueLabel.Size = UDim2.fromOffset(100, config.Description and 21 or 30)
	valueLabel.ZIndex = 4

	local bar = new("Frame", {
		Name = "RangeBar",
		BackgroundColor3 = theme.Input,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 10, 1, -13),
		Size = UDim2.new(1, -20, 0, 3),
		ZIndex = 4,
		Parent = control._frame,
	})
	corner(bar, 2)
	local fill = new("Frame", {
		Name = "RangeFill",
		BackgroundColor3 = theme.Accent,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = bar,
	})
	corner(fill, 2)
	local lowHandle = new("Frame", {
		Name = "LowHandle",
		BackgroundColor3 = theme.AccentBright,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(9, 9),
		ZIndex = 6,
		Parent = bar,
	})
	corner(lowHandle, 5)
	local highHandle = new("Frame", {
		Name = "HighHandle",
		BackgroundColor3 = theme.AccentBright,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(9, 9),
		ZIndex = 6,
		Parent = bar,
	})
	corner(highHandle, 5)
	local dragHit = new("TextButton", {
		Name = "RangeHit",
		AutoButtonColor = false,
		Text = "",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 6, 1, -25),
		Size = UDim2.new(1, -12, 0, 24),
		ZIndex = 8,
		Parent = control._frame,
	})

	local function formatValue(v)
		if decimals <= 0 then
			return tostring(math.floor(v + 0.5)) .. suffix
		end
		return string.format("%." .. tostring(decimals) .. "f", v) .. suffix
	end
	local function render(animated)
		local a = (control.Value[1] - minValue) / (maxValue - minValue)
		local b = (control.Value[2] - minValue) / (maxValue - minValue)
		valueLabel.Text = formatValue(control.Value[1]) .. "  –  " .. formatValue(control.Value[2])
		local goalsFill = { Position = UDim2.fromScale(a, 0), Size = UDim2.fromScale(math.max(0, b - a), 1) }
		local goalsLow = { Position = UDim2.fromScale(a, 0.5) }
		local goalsHigh = { Position = UDim2.fromScale(b, 0.5) }
		if animated then
			ui._motion:Tween(fill, MOTION.Travel, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, goalsFill)
			ui._motion:Tween(lowHandle, MOTION.Travel, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, goalsLow)
			ui._motion:Tween(highHandle, MOTION.Travel, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, goalsHigh)
		else
			fill.Position, fill.Size = goalsFill.Position, goalsFill.Size
			lowHandle.Position, highHandle.Position = goalsLow.Position, goalsHigh.Position
		end
	end
	local function assign(nextLow, nextHigh, silent, animated)
		nextLow = quantize(tonumber(nextLow) or control.Value[1])
		nextHigh = quantize(tonumber(nextHigh) or control.Value[2])
		if nextLow > nextHigh then
			nextLow, nextHigh = nextHigh, nextLow
		end
		control.Value = { nextLow, nextHigh }
		if control.Flag then ui.Flags[control.Flag] = cloneArray(control.Value) end
		render(animated)
		if not silent then safeCallback(config.Callback, nextLow, nextHigh) end
	end
	function control:SetValue(value, silent)
		if type(value) == "table" then assign(value[1], value[2], silent, true) end
		return self
	end
	function control:SetRange(nextLow, nextHigh, silent)
		assign(nextLow, nextHigh, silent, true)
		return self
	end
	control.Set = control.SetValue

	control._maid:Give(dragHit.InputBegan:Connect(function(input)
		if control._disabled then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		local function valueFromX(x)
			local width = math.max(1, bar.AbsoluteSize.X)
			local alpha = math.clamp((x - bar.AbsolutePosition.X) / width, 0, 1)
			return quantize(minValue + ((maxValue - minValue) * alpha))
		end
		local initial = valueFromX(input.Position.X)
		local lowDistance = math.abs(initial - control.Value[1])
		local highDistance = math.abs(initial - control.Value[2])
		local activeLow = lowDistance <= highDistance
		ui:_beginDrag(function(position)
			local nextValue = valueFromX(position.X)
			if activeLow then
				assign(math.min(nextValue, control.Value[2]), control.Value[2], false, false)
			else
				assign(control.Value[1], math.max(nextValue, control.Value[1]), false, false)
			end
		end, nil)
	end))

	if control.Flag then ui.Flags[control.Flag] = cloneArray(control.Value) end
	render(false)
	return self:_registerControl(control)
end

function Section:AddMultiDropdown(config)
	config = config or {}
	local control = createControlShell(self, config, config.Description and 50 or 40, 190)
	control._kind = "Multi Dropdown"
	local ui = self._ui
	local theme = ui.Theme
	control.Options = {}
	for _, option in ipairs(config.Options or {}) do table.insert(control.Options, tostring(option)) end
	control.Value = {}
	for _, item in ipairs(config.Default or {}) do
		item = tostring(item)
		if arrayContains(control.Options, item) and not arrayContains(control.Value, item) then table.insert(control.Value, item) end
	end
	control._open = false

	local field = new("TextButton", {
		Name = "MultiDropdownField", AutoButtonColor = false, Text = "",
		BackgroundColor3 = theme.Input, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -9, 0.5, 0),
		Size = UDim2.fromOffset(166, 27), ZIndex = 5, Parent = control._frame,
	})
	corner(field, 4)
	local valueLabel = makeTextLabel(field, "", TYPE.Value, FONT.Medium, theme.TextSecondary, Enum.TextXAlignment.Left)
	valueLabel.Position = UDim2.fromOffset(9, 0)
	valueLabel.Size = UDim2.new(1, -31, 1, 0)
	valueLabel.ZIndex = 6
	local arrow = new("ImageLabel", {
		BackgroundTransparency = 1, Image = ui.Icons.Dropdown, ImageColor3 = theme.Muted,
		ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(12, 12), ZIndex = 6, Parent = field,
	})

	local function updateLabel()
		if #control.Value == 0 then
			valueLabel.Text = "None"
		elseif #control.Value <= 2 then
			valueLabel.Text = table.concat(control.Value, ", ")
		else
			valueLabel.Text = control.Value[1] .. ", " .. control.Value[2] .. "  +" .. tostring(#control.Value - 2)
		end
	end
	local function commit(silent)
		if control.Flag then ui.Flags[control.Flag] = cloneArray(control.Value) end
		updateLabel()
		if not silent then safeCallback(config.Callback, cloneArray(control.Value)) end
	end
	function control:SetValue(values, silent)
		local nextValues = {}
		for _, value in ipairs(type(values) == "table" and values or {}) do
			value = tostring(value)
			if arrayContains(self.Options, value) and not arrayContains(nextValues, value) then table.insert(nextValues, value) end
		end
		self.Value = nextValues
		commit(silent)
		return self
	end
	control.Set = control.SetValue
	function control:SetOptions(options)
		self.Options = {}
		for _, value in ipairs(options or {}) do table.insert(self.Options, tostring(value)) end
		local filtered = {}
		for _, value in ipairs(self.Value) do if arrayContains(self.Options, value) then table.insert(filtered, value) end end
		self.Value = filtered
		commit(true)
		return self
	end

	local function openPopup()
		if control._disabled or control._open then return end
		control._open = true
		ui._audio:Play("Open")
		ui._motion:Tween(arrow, MOTION.Travel, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, { Rotation = 180, ImageColor3 = theme.AccentBright })
		local popupHeight = math.min(230, math.max(40, #control.Options * 30 + 10))
		local popup = new("Frame", { Name = "MultiDropdownPopup", BackgroundColor3 = theme.Panel, BorderSizePixel = 0, Size = UDim2.fromOffset(176, popupHeight), Visible = false })
		corner(popup, 5)
		local scroll = new("ScrollingFrame", {
			BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 2, ScrollBarImageColor3 = theme.AccentDark,
			Position = UDim2.fromOffset(5, 5), Size = UDim2.new(1, -10, 1, -10), CanvasSize = UDim2.fromOffset(0, #control.Options * 30),
			Parent = popup,
		})
		local list = new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 2), Parent = scroll })
		for index, option in ipairs(control.Options) do
			local row = new("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = theme.ControlHover, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, -2, 0, 28), LayoutOrder = index, ZIndex = 925, Parent = scroll })
			corner(row, 3)
			local box = new("Frame", { BackgroundColor3 = arrayContains(control.Value, option) and theme.Accent or theme.Input, BorderSizePixel = 0, Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(16, 16), ZIndex = 926, Parent = row })
			corner(box, 3)
			local check = new("ImageLabel", { BackgroundTransparency = 1, Image = ui.Icons.Check, ImageColor3 = theme.Text, ImageTransparency = arrayContains(control.Value, option) and 0 or 1, ScaleType = Enum.ScaleType.Fit, Position = UDim2.fromOffset(3, 3), Size = UDim2.fromOffset(10, 10), ZIndex = 927, Parent = box })
			local label = makeTextLabel(row, option, TYPE.Value, FONT.Medium, theme.TextSecondary, Enum.TextXAlignment.Left)
			label.Position = UDim2.fromOffset(30, 0); label.Size = UDim2.new(1, -36, 1, 0); label.ZIndex = 926
			row.MouseButton1Click:Connect(function()
				if arrayContains(control.Value, option) then removeArrayValue(control.Value, option) else table.insert(control.Value, option) end
				local selected = arrayContains(control.Value, option)
				ui._motion:Tween(box, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { BackgroundColor3 = selected and theme.Accent or theme.Input })
				ui._motion:Tween(check, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { ImageTransparency = selected and 0 or 1 })
				commit(false)
			end)
		end
		ui._overlay:Open(popup, field, { OnClose = function()
			control._open = false
			ui._motion:Tween(arrow, MOTION.Travel, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, { Rotation = 0, ImageColor3 = theme.Muted })
		end })
	end
	control._maid:Give(field.MouseButton1Click:Connect(function()
		if control._open then ui._overlay:Close("toggle") else openPopup() end
	end))
	if control.Flag then ui.Flags[control.Flag] = cloneArray(control.Value) end
	updateLabel()
	return self:_registerControl(control)
end

function Section:AddTextbox(config)
	config = config or {}
	local control = createControlShell(self, config, config.Description and 50 or 40, 194)
	control._kind = "Textbox"
	local ui = self._ui
	local theme = ui.Theme
	control.Value = tostring(config.Default or "")
	local box = new("TextBox", {
		Name = "Textbox", BackgroundColor3 = theme.Input, BorderSizePixel = 0, ClearTextOnFocus = false,
		Text = control.Value, PlaceholderText = tostring(config.Placeholder or "Enter value"), PlaceholderColor3 = theme.Muted,
		TextColor3 = theme.TextSecondary, TextSize = TYPE.Value, TextScaled = false, Font = FONT.Medium,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -9, 0.5, 0), Size = UDim2.fromOffset(170, 27), ZIndex = 6, Parent = control._frame,
	})
	corner(box, 4); padding(box, 9, 9, 0, 0)
	local function commit(value, silent)
		control.Value = tostring(value or "")
		box.Text = control.Value
		if control.Flag then ui.Flags[control.Flag] = control.Value end
		if not silent then safeCallback(config.Callback, control.Value) end
	end
	function control:SetValue(value, silent) commit(value, silent); return self end
	control.Set = control.SetValue
	control._maid:Give(box.Focused:Connect(function()
		ui._motion:Tween(box, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { BackgroundColor3 = theme.AccentSurface, TextColor3 = theme.Text })
	end))
	control._maid:Give(box.FocusLost:Connect(function(enterPressed)
		ui._motion:Tween(box, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { BackgroundColor3 = theme.Input, TextColor3 = theme.TextSecondary })
		commit(box.Text, false)
		if enterPressed then ui._audio:Play("Click") end
	end))
	if control.Flag then ui.Flags[control.Flag] = control.Value end
	return self:_registerControl(control)
end

function Section:AddKeybind(config)
	config = config or {}
	local control = createControlShell(self, config, config.Description and 50 or 40, 124)
	control._kind = "Keybind"
	local ui = self._ui
	local theme = ui.Theme
	local default = config.Default
	if type(default) == "string" then default = Enum.KeyCode[default] end
	if typeof(default) ~= "EnumItem" then default = Enum.KeyCode.Unknown end
	control.Value = default
	control._capturing = false
	control._callback = config.Callback
	local button = new("TextButton", {
		Name = "Keybind", AutoButtonColor = false, Text = "", BackgroundColor3 = theme.Input, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -9, 0.5, 0), Size = UDim2.fromOffset(98, 27), ZIndex = 6, Parent = control._frame,
	})
	corner(button, 4)
	local label = makeTextLabel(button, "", TYPE.Meta, FONT.Bold, theme.TextSecondary, Enum.TextXAlignment.Center)
	label.Size = UDim2.fromScale(1, 1); label.ZIndex = 7
	local function display()
		if control._capturing then return "PRESS KEY" end
		if control.Value == Enum.KeyCode.Unknown then return "NONE" end
		return string.upper(control.Value.Name)
	end
	local function render()
		label.Text = display()
		ui._motion:Tween(button, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { BackgroundColor3 = control._capturing and theme.AccentSurface or theme.Input })
		ui._motion:Tween(label, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { TextColor3 = control._capturing and theme.AccentBright or theme.TextSecondary })
	end
	function control:SetValue(value, silent)
		if type(value) == "string" then value = Enum.KeyCode[value] end
		if typeof(value) ~= "EnumItem" then return self end
		self.Value = value
		if self.Flag then ui.Flags[self.Flag] = value end
		render()
		if not silent then safeCallback(config.Changed, value) end
		return self
	end
	control.Set = control.SetValue
	control._maid:Give(button.MouseButton1Click:Connect(function()
		if control._disabled then return end
		if ui._capturingKeybind and ui._capturingKeybind ~= control then
			ui._capturingKeybind._capturing = false
			if ui._capturingKeybind._renderKeybind then ui._capturingKeybind:_renderKeybind() end
		end
		control._capturing = true
		ui._capturingKeybind = control
		render()
	end))
	function control:_renderKeybind() render() end
	if control.Flag then ui.Flags[control.Flag] = control.Value end
	table.insert(ui._keybinds, control)
	render()
	return self:_registerControl(control)
end

function Section:AddLabel(config)
	config = type(config) == "table" and config or { Text = tostring(config or "") }
	local frame = new("Frame", { Name = "Label", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 28), Parent = self._frame })
	local label = makeTextLabel(frame, tostring(config.Text or config.Title or "Label"), TYPE.Body, config.Bold and FONT.Bold or FONT.Medium, self._ui.Theme.TextSecondary, Enum.TextXAlignment.Left)
	label.Position = UDim2.fromOffset(10, 0); label.Size = UDim2.new(1, -20, 1, 0)
	local control = setmetatable({ _ui = self._ui, _section = self, _maid = Maid.new(), _frame = frame, _titleLabel = label, Title = label.Text, _kind = "Label" }, ControlBase)
	function control:SetValue(value) self:SetTitle(value); return self end
	control.Set = control.SetValue
	return self:_registerControl(control)
end

function Section:AddParagraph(config)
	config = config or {}
	local frame = new("Frame", { Name = "Paragraph", BackgroundColor3 = self._ui.Theme.ControlHover, BackgroundTransparency = 1, BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), Parent = self._frame })
	corner(frame, 4); padding(frame, 10, 10, 8, 8)
	local layout = new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3), Parent = frame })
	local title = makeTextLabel(frame, tostring(config.Title or ""), TYPE.Body, FONT.Bold, self._ui.Theme.Text, Enum.TextXAlignment.Left)
	title.AutomaticSize = Enum.AutomaticSize.Y; title.Size = UDim2.new(1, 0, 0, 0); title.TextWrapped = true; title.LayoutOrder = 1
	local body = makeTextLabel(frame, tostring(config.Text or config.Description or ""), TYPE.Description, FONT.Regular, self._ui.Theme.TextSecondary, Enum.TextXAlignment.Left)
	body.AutomaticSize = Enum.AutomaticSize.Y; body.Size = UDim2.new(1, 0, 0, 0); body.TextWrapped = true; body.TextYAlignment = Enum.TextYAlignment.Top; body.LayoutOrder = 2
	local control = setmetatable({ _ui = self._ui, _section = self, _maid = Maid.new(), _frame = frame, _titleLabel = title, _descriptionLabel = body, Title = title.Text, Description = body.Text, _kind = "Paragraph" }, ControlBase)
	function control:SetValue(value) body.Text = tostring(value or ""); self.Description = body.Text; return self end
	control.Set = control.SetValue
	return self:_registerControl(control)
end

function Section:AddProgress(config)
	config = config or {}
	local control = createControlShell(self, config, config.Description and 60 or 48, 76)
	control._kind = "Progress"
	local ui = self._ui
	local theme = ui.Theme
	control.Value = math.clamp(tonumber(config.Default) or 0, 0, 100)
	local valueLabel = makeTextLabel(control._frame, "", TYPE.Value, FONT.Bold, theme.TextSecondary, Enum.TextXAlignment.Right)
	valueLabel.AnchorPoint = Vector2.new(1, 0); valueLabel.Position = UDim2.new(1, -10, 0, config.Description and 5 or 0); valueLabel.Size = UDim2.fromOffset(64, 24); valueLabel.ZIndex = 4
	local bar = new("Frame", { BackgroundColor3 = theme.Input, BorderSizePixel = 0, Position = UDim2.new(0, 10, 1, -13), Size = UDim2.new(1, -20, 0, 3), ZIndex = 4, Parent = control._frame })
	corner(bar, 2)
	local fill = new("Frame", { BackgroundColor3 = theme.Accent, BorderSizePixel = 0, Size = UDim2.fromScale(control.Value / 100, 1), ZIndex = 5, Parent = bar })
	corner(fill, 2)
	function control:SetValue(value, silent)
		self.Value = math.clamp(tonumber(value) or 0, 0, 100)
		valueLabel.Text = tostring(math.floor(self.Value + 0.5)) .. "%"
		ui._motion:Tween(fill, MOTION.Travel, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, { Size = UDim2.fromScale(self.Value / 100, 1) })
		if self.Flag then ui.Flags[self.Flag] = self.Value end
		if not silent then safeCallback(config.Callback, self.Value) end
		return self
	end
	control.Set = control.SetValue
	control:SetValue(control.Value, true)
	return self:_registerControl(control)
end

function Section:AddImage(config)
	config = config or {}
	local height = math.clamp(math.floor(tonumber(config.Height) or 120), 48, 320)
	local frame = new("Frame", { Name = "Image", BackgroundColor3 = self._ui.Theme.ControlHover, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, height), Parent = self._frame })
	corner(frame, 5)
	local image = new("ImageLabel", { BackgroundTransparency = 1, Image = normalizeAsset(config.Image) or "", ScaleType = config.ScaleType or Enum.ScaleType.Crop, Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8), Parent = frame })
	corner(image, 4)
	local control = setmetatable({ _ui = self._ui, _section = self, _maid = Maid.new(), _frame = frame, _image = image, Title = tostring(config.Title or "Image"), _kind = "Image" }, ControlBase)
	function control:SetValue(value) image.Image = normalizeAsset(value) or ""; return self end
	control.Set = control.SetValue
	return self:_registerControl(control)
end

function Section:AddColorPicker(config)
	config = config or {}
	local control = createControlShell(self, config, config.Description and 50 or 40, 178)
	control._kind = "Color Picker"
	local ui = self._ui
	local theme = ui.Theme
	control.Value = parseColor(config.Default, theme.Accent)
	control._open = false
	local field = new("TextButton", { Name = "ColorField", AutoButtonColor = false, Text = "", BackgroundColor3 = theme.Input, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -9, 0.5, 0), Size = UDim2.fromOffset(154, 27), ZIndex = 6, Parent = control._frame })
	corner(field, 4)
	local swatch = new("Frame", { BackgroundColor3 = control.Value, BorderSizePixel = 0, Position = UDim2.fromOffset(7, 6), Size = UDim2.fromOffset(15, 15), ZIndex = 7, Parent = field })
	corner(swatch, 3)
	local valueLabel = makeTextLabel(field, colorToHex(control.Value), TYPE.Meta, FONT.Bold, theme.TextSecondary, Enum.TextXAlignment.Right)
	valueLabel.Position = UDim2.fromOffset(29, 0); valueLabel.Size = UDim2.new(1, -38, 1, 0); valueLabel.ZIndex = 7
	local function commit(color, silent)
		control.Value = color
		swatch.BackgroundColor3 = color
		valueLabel.Text = colorToHex(color)
		if control.Flag then ui.Flags[control.Flag] = color end
		if not silent then safeCallback(config.Callback, color) end
	end
	function control:SetValue(value, silent) commit(parseColor(value, self.Value), silent); return self end
	control.Set = control.SetValue

	local function openPicker()
		if control._disabled or control._open then return end
		control._open = true
		local h, sat, val = control.Value:ToHSV()
		local popup = new("Frame", { Name = "ColorPickerPopup", BackgroundColor3 = theme.Panel, BorderSizePixel = 0, Size = UDim2.fromOffset(238, 210), Visible = false })
		corner(popup, 5); padding(popup, 10, 10, 10, 10)
		local sv = new("Frame", { Name = "SV", BackgroundColor3 = Color3.fromHSV(h, 1, 1), BorderSizePixel = 0, Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(188, 150), ZIndex = 923, Parent = popup })
		corner(sv, 4)
		local whiteLayer = new("Frame", { BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, Size = UDim2.fromScale(1,1), ZIndex = 924, Parent = sv })
		corner(whiteLayer, 4)
		new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0,0), NumberSequenceKeypoint.new(1,1) }), Parent = whiteLayer })
		local blackLayer = new("Frame", { BackgroundColor3 = Color3.new(0,0,0), BorderSizePixel = 0, Size = UDim2.fromScale(1,1), ZIndex = 925, Parent = sv })
		corner(blackLayer, 4)
		new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0,1), NumberSequenceKeypoint.new(1,0) }), Parent = blackLayer })
		local cursor = new("Frame", { BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5,0.5), Size = UDim2.fromOffset(6,6), ZIndex = 928, Parent = sv })
		corner(cursor, 3)
		local hue = new("Frame", { Name = "Hue", BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, Position = UDim2.fromOffset(198,0), Size = UDim2.fromOffset(18,150), ZIndex = 923, Parent = popup })
		corner(hue, 4)
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255,0,0)), ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255,255,0)),
			ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0,255,0)), ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0,255,255)),
			ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0,0,255)), ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255,0,255)),
			ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255,0,0)),
		}), Parent = hue })
		local hueCursor = new("Frame", { BackgroundColor3 = theme.Text, BorderSizePixel = 0, AnchorPoint = Vector2.new(0,0.5), Position = UDim2.fromScale(0,h), Size = UDim2.new(1,0,0,2), ZIndex = 928, Parent = hue })
		local hex = makeTextLabel(popup, colorToHex(control.Value), TYPE.Value, FONT.Bold, theme.Text, Enum.TextXAlignment.Left)
		hex.Position = UDim2.fromOffset(0, 160); hex.Size = UDim2.fromOffset(110, 28); hex.ZIndex = 928
		local preview = new("Frame", { BackgroundColor3 = control.Value, BorderSizePixel = 0, Position = UDim2.fromOffset(185, 165), Size = UDim2.fromOffset(31, 22), ZIndex = 928, Parent = popup })
		corner(preview, 4)

		local function renderLocal(notify)
			sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
			cursor.Position = UDim2.fromScale(sat, 1 - val)
			hueCursor.Position = UDim2.fromScale(0, h)
			local color = Color3.fromHSV(h, sat, val)
			preview.BackgroundColor3 = color
			hex.Text = colorToHex(color)
			commit(color, not notify)
		end
		local svHit = new("TextButton", { AutoButtonColor = false, Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1,1), ZIndex = 930, Parent = sv })
		local hueHit = new("TextButton", { AutoButtonColor = false, Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1,1), ZIndex = 930, Parent = hue })
		local function setSV(pos)
			sat = math.clamp((pos.X - sv.AbsolutePosition.X) / math.max(1, sv.AbsoluteSize.X), 0, 1)
			val = 1 - math.clamp((pos.Y - sv.AbsolutePosition.Y) / math.max(1, sv.AbsoluteSize.Y), 0, 1)
			renderLocal(true)
		end
		local function setHue(pos)
			h = math.clamp((pos.Y - hue.AbsolutePosition.Y) / math.max(1, hue.AbsoluteSize.Y), 0, 1)
			renderLocal(true)
		end
		svHit.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
			setSV(input.Position); ui:_beginDrag(setSV, nil)
		end)
		hueHit.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
			setHue(input.Position); ui:_beginDrag(setHue, nil)
		end)
		renderLocal(false)
		ui._overlay:Open(popup, field, { OnClose = function() control._open = false end })
	end
	control._maid:Give(field.MouseButton1Click:Connect(function()
		if control._open then ui._overlay:Close("toggle") else openPicker() end
	end))
	if control.Flag then ui.Flags[control.Flag] = control.Value end
	return self:_registerControl(control)
end

function Subpage:_createContent()
	local ui = self._ui
	local theme = ui.Theme
	local frame = new("Frame", {
		Name = "Subpage_" .. self.Title,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ClipsDescendants = false,
		Parent = self._page._contentHost,
	})
	self._frame = frame
	self._compactLayout = false

	local scroll = new("ScrollingFrame", {
		Name = "Scroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = theme.AccentDark,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.fromOffset(0, 0),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = frame,
	})
	self._scroll = scroll

	local left = new("Frame", {
		Name = "LeftColumn",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(0.5, -5, 0, 0),
		Parent = scroll,
	})
	local right = new("Frame", {
		Name = "RightColumn",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.new(0.5, 5, 0, 0),
		Size = UDim2.new(0.5, -5, 0, 0),
		Parent = scroll,
	})
	local leftLayout = new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
		Parent = left,
	})
	local rightLayout = new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
		Parent = right,
	})
	self._left = left
	self._right = right
	self._leftLayout = leftLayout
	self._rightLayout = rightLayout

	local function refreshCanvas()
		local leftHeight = leftLayout.AbsoluteContentSize.Y
		local rightHeight = rightLayout.AbsoluteContentSize.Y
		if self._compactLayout then
			left.Position = UDim2.fromOffset(0, 0)
			left.Size = UDim2.new(1, 0, 0, leftHeight)
			right.Position = UDim2.fromOffset(0, leftHeight + 10)
			right.Size = UDim2.new(1, 0, 0, rightHeight)
			scroll.CanvasSize = UDim2.fromOffset(0, leftHeight + rightHeight + 18)
		else
			left.Position = UDim2.fromOffset(0, 0)
			left.Size = UDim2.new(0.5, -5, 0, leftHeight)
			right.Position = UDim2.new(0.5, 5, 0, 0)
			right.Size = UDim2.new(0.5, -5, 0, rightHeight)
			scroll.CanvasSize = UDim2.fromOffset(0, math.max(leftHeight, rightHeight) + 6)
		end
	end
	self._refreshCanvas = refreshCanvas
	self._maid:Give(leftLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(refreshCanvas))
	self._maid:Give(rightLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(refreshCanvas))
	refreshCanvas()
end

function Subpage:_refreshLayout(compact)
	if not self._frame then
		return
	end
	self._compactLayout = compact == true
	if self._refreshCanvas then
		self._refreshCanvas()
	end
end

function Subpage:AddSection(config)
	config = config or {}
	local section = setmetatable({}, Section)
	section._ui = self._ui
	section._subpage = self
	section._maid = Maid.new()
	section._controls = {}
	section.Title = tostring(config.Title or "Section")
	section.LayoutOrder = #self._sections + 1
	section.Column = config.Column
	section.Tags = type(config.Tags) == "table" and cloneArray(config.Tags) or {}

	local parentColumn
	if config.Column == "Right" then
		parentColumn = self._right
	elseif config.Column == "Left" then
		parentColumn = self._left
	else
		parentColumn = (section.LayoutOrder % 2 == 1) and self._left or self._right
	end

	local frame = new("Frame", {
		Name = "Section_" .. section.Title,
		BackgroundColor3 = self._ui.Theme.Panel,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = section.LayoutOrder,
		Parent = parentColumn,
	})
	corner(frame, 4)
	padding(frame, 10, 10, 8, 8)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 2),
		Parent = frame,
	})
	section._frame = frame

	local titleRow = new("Frame", {
		Name = "SectionHeader",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 28),
		LayoutOrder = 0,
		Parent = frame,
	})

	local marker = new("Frame", {
		Name = "AccentMarker",
		BackgroundColor3 = self._ui.Theme.Accent,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 7),
		Size = UDim2.fromOffset(2, 14),
		Parent = titleRow,
	})
	corner(marker, 1)

	local titleLabel = makeTextLabel(titleRow, section.Title, TYPE.Section, FONT.Bold, self._ui.Theme.Text, Enum.TextXAlignment.Left)
	titleLabel.Position = UDim2.fromOffset(10, 0)
	titleLabel.Size = UDim2.new(1, -10, 1, 0)
	section._titleLabel = titleLabel

	function section:SetTitle(title)
		self.Title = tostring(title or "")
		self._titleLabel.Text = self.Title
		return self
	end

	function section:SetVisible(visible)
		self._frame.Visible = visible ~= false
		return self
	end

	function section:Destroy()
		self._maid:Cleanup()
		self._frame:Destroy()
	end

	table.insert(self._sections, section)
	self._maid:Give(section)
	self:_refreshLayout(self._page._window._compact)
	return section
end

function Page:_ensureDefaultSubpage()
	if #self._subpages > 0 then
		return self._subpages[1]
	end
	return self:AddSubpage({ Title = "General", HiddenTab = true })
end

function Page:AddSection(config)
	return self:_ensureDefaultSubpage():AddSection(config)
end

function Page:AddSubpage(config)
	config = config or {}
	local subpage = setmetatable({}, Subpage)
	subpage._ui = self._ui
	subpage._page = self
	subpage._maid = Maid.new()
	subpage._sections = {}
	subpage.Title = tostring(config.Title or ("Tab " .. tostring(#self._subpages + 1)))
	subpage.HiddenTab = config.HiddenTab == true
	subpage.Tags = type(config.Tags) == "table" and cloneArray(config.Tags) or {}
	subpage:_createContent()
	table.insert(self._subpages, subpage)
	self._maid:Give(subpage)
	if #self._subpages == 1 then
		self._activeSubpage = subpage
		subpage._frame.Visible = true
	end
	if self._window._activePage == self then
		self._window:_rebuildSubtabs()
		self._window:_updateHeaderContext()
	end
	return subpage
end

function Subpage:Destroy()
	self._maid:Cleanup()
	if self._frame then
		self._frame:Destroy()
	end
end

function Page:SelectSubpage(target)
	local subpage = target
	if type(target) == "string" then
		for _, candidate in ipairs(self._subpages) do
			if candidate.Title == target then
				subpage = candidate
				break
			end
		end
	end
	if type(subpage) ~= "table" or subpage._page ~= self then
		return self
	end
	if self._activeSubpage == subpage then
		return self
	end
	local old = self._activeSubpage
	self._activeSubpage = subpage
	self._ui._overlay:Close("subpage-change")
	self._window:_transitionContent(old and old._frame or nil, subpage._frame)
	self._window:_refreshSubtabStates()
	self._window:_updateHeaderContext()
	self._ui._audio:Play("Click")
	return self
end

function Page:SetVisible(visible)
	self._navButton.Visible = visible ~= false
	return self
end

function Page:SetTitle(title)
	self.Title = tostring(title or "")
	if self._window._activePage == self then
		self._window:_updateHeaderContext()
	end
	return self
end

function Page:Destroy()
	self._maid:Cleanup()
	if self._navButton then
		self._navButton:Destroy()
	end
	if self._contentHost then
		self._contentHost:Destroy()
	end
end

function Window:_updateHeaderContext()
	local page = self._activePage
	if not page then
		return
	end
	self._pageTitle.Text = page.Title
	local subpage = page._activeSubpage or page._subpages[1]
	if self._contextLabel then
		-- Hidden/default subpages do not need redundant breadcrumb text.
		self._contextLabel.Text = ""
		self._contextLabel.Visible = false
	end
end

function Window:_transitionContent(oldFrame, newFrame)
	if not newFrame then return end
	self._transitionToken += 1
	local token = self._transitionToken
	if oldFrame == newFrame then
		newFrame.Visible = true
		newFrame.Position = UDim2.fromOffset(0, 0)
		return
	end

	local wash = self._transitionWash
	local line = self._transitionLine
	self._ui._motion:Cancel(wash)
	self._ui._motion:Cancel(line)
	wash.Visible = true
	wash.BackgroundTransparency = 1
	line.BackgroundTransparency = 0
	line.Position = UDim2.fromOffset(0, 0)
	line.Size = UDim2.fromOffset(0, 2)

	self._ui._motion:Tween(line, 0.075, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, {
		Size = UDim2.fromOffset(72, 2),
	})

	task.delay(0.045, function()
		if self._destroyed or token ~= self._transitionToken then return end
		if oldFrame and oldFrame.Parent then oldFrame.Visible = false end
		if newFrame and newFrame.Parent then
			newFrame.Position = UDim2.fromOffset(0, 0)
			newFrame.Visible = true
		end
	end)

	task.delay(0.085, function()
		if self._destroyed or token ~= self._transitionToken then return end
		self._ui._motion:Tween(line, 0.09, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(96, 2),
		})
		task.delay(0.11, function()
			if self._destroyed or token ~= self._transitionToken then return end
			wash.Visible = false
			line.BackgroundTransparency = 1
			line.Size = UDim2.fromOffset(0, 2)
		end)
	end)
end

function Window:_setActivePage(page)
	if self._activePage == page then
		return
	end
	local old = self._activePage
	self._activePage = page
	self._ui._overlay:Close("page-change")

	for _, candidate in ipairs(self._pages) do
		local selected = candidate == page
		self:_renderNav(candidate, selected)
		if candidate ~= page and candidate ~= old then
			candidate._contentHost.Visible = false
		end
	end

	local active = page._activeSubpage or page._subpages[1]
	if active then
		page._activeSubpage = active
		for _, subpage in ipairs(page._subpages) do
			subpage._frame.Visible = subpage == active and (old == nil)
			subpage._frame.Position = UDim2.fromOffset(0, 0)
		end
	end

	self:_rebuildSubtabs()
	self:_updateHeaderContext()

	if old and old._contentHost and old ~= page then
		page._contentHost.Visible = false
		if active then
			active._frame.Visible = true
		end
		self:_transitionContent(old._contentHost, page._contentHost)
	else
		page._contentHost.Visible = true
		page._contentHost.Position = UDim2.fromOffset(0, 0)
		if active then
			active._frame.Visible = true
		end
	end

	if old then
		self._ui._audio:Play("Click")
	end
end

function Window:_renderNav(page, selected)
	local theme = self._ui.Theme
	local button = page._navButton
	local icon = page._navIcon
	local marker = page._navMarker
	if not button then
		return
	end
	page._navSelected = selected
	self._ui._motion:Tween(button, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
		BackgroundTransparency = 1,
		BackgroundColor3 = theme.PanelHover,
	})
	if icon then
		self._ui._motion:Tween(icon, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
			ImageColor3 = selected and theme.AccentBright or theme.Muted,
		})
	elseif page._navLabel then
		self._ui._motion:Tween(page._navLabel, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
			TextColor3 = selected and theme.AccentBright or theme.Muted,
		})
	end
	self._ui._motion:Tween(marker, MOTION.Travel, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, {
		BackgroundTransparency = selected and 0 or 1,
		Size = UDim2.fromOffset(2, selected and 22 or 8),
	})
end

function Window:_refreshSubtabStates()
	local page = self._activePage
	if not page then
		return
	end
	for _, subpage in ipairs(page._subpages) do
		local button = subpage._tabButton
		local underline = subpage._tabUnderline
		if button and underline then
			local selected = page._activeSubpage == subpage
			button.Font = selected and FONT.Bold or FONT.Medium
			self._ui._motion:Tween(button, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
				TextColor3 = selected and self._ui.Theme.Text or self._ui.Theme.Muted,
			})
			self._ui._motion:Tween(underline, MOTION.Travel, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, {
				BackgroundTransparency = selected and 0 or 1,
				Size = UDim2.fromOffset(selected and math.min((subpage._tabWidth or 58) - 18, 34) or 8, 2),
			})
		end
	end
end

function Window:_rebuildSubtabs()
	if self._subtabMaid then
		self._subtabMaid:Cleanup()
	end
	for _, child in ipairs(self._subtabHost:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for _, candidatePage in ipairs(self._pages) do
		for _, subpage in ipairs(candidatePage._subpages) do
			subpage._tabButton = nil
			subpage._tabUnderline = nil
			subpage._tabWidth = nil
		end
	end

	local page = self._activePage
	if not page then
		self._subtabUsedWidth = 0
		return
	end
	local visibleSubpages = {}
	for _, subpage in ipairs(page._subpages) do
		if not subpage.HiddenTab then
			table.insert(visibleSubpages, subpage)
		end
	end
	if #visibleSubpages <= 1 then
		self._subtabUsedWidth = 0
		return
	end

	local x = 0
	for _, subpage in ipairs(visibleSubpages) do
		local width = roundPixel(math.max(60, 22 + (#subpage.Title * 7)))
		local selected = page._activeSubpage == subpage
		local button = new("TextButton", {
			AutoButtonColor = false,
			Text = subpage.Title,
			TextSize = TYPE.Value,
			TextScaled = false,
			Font = selected and FONT.Bold or FONT.Medium,
			TextColor3 = selected and self._ui.Theme.Text or self._ui.Theme.Muted,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.fromOffset(width, 50),
			Parent = self._subtabHost,
		})
		local underline = new("Frame", {
			BackgroundColor3 = self._ui.Theme.Accent,
			BackgroundTransparency = selected and 0 or 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -1),
			Size = UDim2.fromOffset(selected and math.min(width - 18, 34) or 8, 2),
			Parent = button,
		})
		corner(underline, 1)
		subpage._tabButton = button
		subpage._tabUnderline = underline
		subpage._tabWidth = width

		self._subtabMaid:Give(button.MouseEnter:Connect(function()
			if page._activeSubpage ~= subpage then
				self._ui._motion:Tween(button, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
					TextColor3 = self._ui.Theme.TextSecondary,
				})
			end
		end))
		self._subtabMaid:Give(button.MouseLeave:Connect(function()
			if page._activeSubpage ~= subpage then
				self._ui._motion:Tween(button, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
					TextColor3 = self._ui.Theme.Muted,
				})
			end
		end))
		self._subtabMaid:Give(button.MouseButton1Click:Connect(function()
			page:SelectSubpage(subpage)
		end))
		x += width + 4
	end
	self._subtabUsedWidth = x
end


function Window:_clampToViewport(target)
	if self._destroyed then
		return
	end
	target = target or self._shell
	if not target or not target.Parent then
		return
	end
	local rootSize = self._ui._root.AbsoluteSize
	local rootPos = self._ui._root.AbsolutePosition
	local size = target.AbsoluteSize
	if rootSize.X <= 0 or rootSize.Y <= 0 or size.X <= 0 or size.Y <= 0 then
		return
	end
	local margin = 8
	local localTopLeft = target.AbsolutePosition - rootPos
	local maxX = math.max(margin, rootSize.X - size.X - margin)
	local maxY = math.max(margin, rootSize.Y - size.Y - margin)
	local x = math.clamp(localTopLeft.X, margin, maxX)
	local y = math.clamp(localTopLeft.Y, margin, maxY)
	local anchor = target.AnchorPoint
	target.Position = UDim2.fromOffset(
		math.floor(x + (size.X * anchor.X) + 0.5),
		math.floor(y + (size.Y * anchor.Y) + 0.5)
	)
end

function Window:_updateResponsive()
	if self._destroyed then
		return
	end
	local viewport = self._ui._root.AbsoluteSize
	if viewport.X <= 0 or viewport.Y <= 0 then
		return
	end

	local width
	local height
	if self._maximized then
		width = evenPixel(math.max(620, viewport.X - 24))
		height = roundPixel(math.max(420, viewport.Y - 24))
	else
		width = evenPixel(math.min(self._targetSize.X, math.max(620, viewport.X - 32)))
		height = roundPixel(math.min(self._targetSize.Y, math.max(420, viewport.Y - 32)))
	end

	self._shell.Size = UDim2.fromOffset(width, height)

	if self._maximized then
		self._shell.Position = UDim2.fromOffset(
			roundPixel((viewport.X - width) * 0.5),
			roundPixel((viewport.Y - height) * 0.5)
		)
		self._positionInitialized = true
	elseif not self._positionInitialized then
		self._shell.Position = UDim2.fromOffset(
			roundPixel((viewport.X - width) * 0.5),
			roundPixel((viewport.Y - height) * 0.5)
		)
		self._positionInitialized = true
	end
	self._compact = width < 760
	if self._searchButton then
		self._searchButton.Size = self._compact and UDim2.fromOffset(30, 28) or UDim2.fromOffset(118, 28)
		if self._searchText then self._searchText.Visible = not self._compact end
	end
	for _, page in ipairs(self._pages) do
		for _, subpage in ipairs(page._subpages) do
			subpage:_refreshLayout(self._compact)
		end
	end

	if not self._maximized then
		task.defer(function()
			if not self._destroyed and self._shell and self._shell.Parent then
				self:_clampToViewport(self._shell)
			end
		end)
	end
end

function Window:_toggleMaximize()
	if self._destroyed or self._minimized then
		return
	end
	self._ui._overlay:Close("maximize")
	if not self._maximized then
		self._restorePosition = self._shell.Position
		self._maximized = true
	else
		self._maximized = false
		if self._restorePosition then
			self._shell.Position = self._restorePosition
		end
	end
	self._ui._audio:Play("Click")
	self:_updateResponsive()
end

function Window:_setMinimized(minimized)
	if self._minimized == minimized then
		return
	end
	self._minimized = minimized
	if minimized then
		self._ui._audio:Play("Close")
		self._ui._overlay:Close("minimize")
		self._miniBar.Position = self._shell.Position
		self._miniBar.Visible = true
		self._miniBar.Position = offsetUDim2(self._miniBar.Position, 0, 5)
		self._shell.Visible = false
		self._ui._motion:Tween(self._miniBar, MOTION.Settle, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, {
			Position = offsetUDim2(self._miniBar.Position, 0, -5),
		})
	else
		self._ui._audio:Play("Open")
		local targetPosition = self._miniBar.Position
		self._shell.Position = offsetUDim2(targetPosition, 0, 5)
		self._shell.Visible = true
		self._miniBar.Visible = false
		self:_updateResponsive()
		self._ui._motion:Tween(self._shell, MOTION.Settle, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, {
			Position = targetPosition,
		})
	end
end

function Window:AddPage(config)
	config = config or {}
	local page = setmetatable({}, Page)
	page._ui = self._ui
	page._window = self
	page._maid = Maid.new()
	page._subpages = {}
	page.Title = tostring(config.Title or ("Page " .. tostring(#self._pages + 1)))
	page.Dock = config.Dock == "Bottom" and "Bottom" or "Top"
	page.Tags = type(config.Tags) == "table" and cloneArray(config.Tags) or {}
	if type(config.Icon) == "string" and self._ui.Icons[config.Icon] then
		page.Icon = self._ui.Icons[config.Icon]
	else
		page.Icon = normalizeAsset(config.Icon)
	end
	page.LayoutOrder = #self._pages + 1

	local parentHost = page.Dock == "Bottom" and self._bottomNavHost or self._navHost
	local button = new("TextButton", {
		Name = "Nav_" .. page.Title,
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = self._ui.Theme.PanelHover,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(42, 40),
		LayoutOrder = page.LayoutOrder,
		Parent = parentHost,
	})
	corner(button, 5)
	local marker = new("Frame", {
		Name = "SelectionMarker",
		BackgroundColor3 = self._ui.Theme.Accent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(2, 8),
		Parent = button,
	})
	corner(marker, 1)
	local icon = nil
	local fallbackLabel = nil
	if page.Icon then
		icon = new("ImageLabel", {
			BackgroundTransparency = 1,
			Image = page.Icon,
			ImageColor3 = self._ui.Theme.Muted,
			ScaleType = Enum.ScaleType.Fit,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(17, 17),
			Parent = button,
		})
	else
		fallbackLabel = makeTextLabel(button, string.upper(string.sub(page.Title, 1, 1)), TYPE.Body, FONT.Bold, self._ui.Theme.Muted, Enum.TextXAlignment.Center)
		fallbackLabel.Size = UDim2.fromScale(1, 1)
		warn("[LunkaraUI] Page '" .. page.Title .. "' has no valid icon. Using a text fallback instead of a mismatched asset.")
	end
	page._navButton = button
	page._navIcon = icon
	page._navLabel = fallbackLabel
	page._navMarker = marker

	local contentHost = new("Frame", {
		Name = "Page_" .. page.Title,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ClipsDescendants = false,
		Parent = self._contentHost,
	})
	page._contentHost = contentHost

	page._maid:Give(button.MouseEnter:Connect(function()
		if self._activePage == page then
			return
		end
		self._ui._audio:Play("Hover")
		self._ui._motion:Tween(button, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
			BackgroundTransparency = 0,
			BackgroundColor3 = self._ui.Theme.PanelHover,
		})
		if icon then
			self._ui._motion:Tween(icon, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { ImageColor3 = self._ui.Theme.TextSecondary })
		elseif fallbackLabel then
			self._ui._motion:Tween(fallbackLabel, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { TextColor3 = self._ui.Theme.TextSecondary })
		end
	end))
	page._maid:Give(button.MouseLeave:Connect(function()
		if self._activePage == page then
			return
		end
		self._ui._motion:Tween(button, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
			BackgroundTransparency = 1,
		})
		if icon then
			self._ui._motion:Tween(icon, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { ImageColor3 = self._ui.Theme.Muted })
		elseif fallbackLabel then
			self._ui._motion:Tween(fallbackLabel, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { TextColor3 = self._ui.Theme.Muted })
		end
	end))
	page._maid:Give(button.MouseButton1Click:Connect(function()
		self:_setActivePage(page)
	end))

	table.insert(self._pages, page)
	self._maid:Give(page)
	if #self._pages == 1 then
		self:_setActivePage(page)
	end
	return page
end


function Window:SetTitle(title)
	self.Title = tostring(title or "")
	if self._activePage == nil and self._pageTitle then self._pageTitle.Text = self.Title end
	return self
end

function Window:SetVisible(visible)
	visible = visible ~= false
	self._shell.Visible = visible and not self._minimized
	self._miniBar.Visible = visible and self._minimized
	return self
end

function Window:SetMinimized(minimized)
	self:_setMinimized(minimized == true)
	return self
end

function Window:OpenCommands(initialText)
	self._ui:OpenCommandPanel(self, initialText)
	return self
end

function Window:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self._ui:_endDrag()
	self._ui._overlay:Close("window-destroy")
	for i = #self._ui.Windows, 1, -1 do
		if self._ui.Windows[i] == self then
			table.remove(self._ui.Windows, i)
			break
		end
	end
	self._maid:Cleanup()
	if self._shell then
		self._shell:Destroy()
	end
	if self._miniBar then
		self._miniBar:Destroy()
	end
end

function LunkaraUI:_beginDrag(onMove, onEnd)
	if self._activeDrag then
		self:_endDrag()
	end
	self._activeDrag = {
		onMove = onMove,
		onEnd = onEnd,
	}
end

function LunkaraUI:_endDrag()
	local drag = self._activeDrag
	self._activeDrag = nil
	if drag and drag.onEnd then
		safeCallback(drag.onEnd)
	end
end

local function serializeConfigValue(value)
	local kind = typeof(value)
	if kind == "Color3" then
		return { __type = "Color3", value = colorToHex(value) }
	elseif kind == "EnumItem" then
		return { __type = "EnumItem", enum = value.EnumType.Name, name = value.Name }
	elseif type(value) == "table" then
		local out = {}
		for key, child in pairs(value) do out[key] = serializeConfigValue(child) end
		return out
	end
	return value
end

local function deserializeConfigValue(value)
	if type(value) ~= "table" then return value end
	if value.__type == "Color3" then return parseColor(value.value, Color3.new(1, 1, 1)) end
	if value.__type == "EnumItem" and type(value.enum) == "string" and type(value.name) == "string" then
		local enumType = Enum[value.enum]
		if enumType then
			local ok, item = pcall(function() return enumType[value.name] end)
			if ok and item then return item end
		end
		return Enum.KeyCode.Unknown
	end
	local out = {}
	for key, child in pairs(value) do out[key] = deserializeConfigValue(child) end
	return out
end

function LunkaraUI:GetFlag(flag)
	return self.Flags[flag]
end

function LunkaraUI:SetFlag(flag, value, silent)
	local control = self._flagControls[flag]
	if control and not control._destroyed and type(control.SetValue) == "function" then
		control:SetValue(value, silent)
	else
		self.Flags[flag] = value
	end
	return self
end

function LunkaraUI:ExportConfig()
	local payload = { Version = 1, Library = LunkaraUI.Version, Flags = {} }
	for key, value in pairs(self.Flags) do payload.Flags[key] = serializeConfigValue(value) end
	return HttpService:JSONEncode(payload)
end

function LunkaraUI:ImportConfig(encoded, silent)
	if type(encoded) ~= "string" then return false, "Config must be a JSON string" end
	local ok, payload = pcall(HttpService.JSONDecode, HttpService, encoded)
	if not ok or type(payload) ~= "table" or type(payload.Flags) ~= "table" then
		return false, "Invalid LunkaraUI config"
	end
	for key, value in pairs(payload.Flags) do self:SetFlag(key, deserializeConfigValue(value), silent ~= false) end
	return true
end

function LunkaraUI:Notify(config)
	config = type(config) == "table" and config or { Title = tostring(config or "Notification") }
	if self._destroyed then return nil end
	local theme = self.Theme
	local kind = tostring(config.Type or "Info")
	local iconKey = kind == "Success" and "Success" or (kind == "Warning" and "Warning" or (kind == "Error" and nil or "Notification"))
	local accent = kind == "Success" and theme.AccentBright or (kind == "Error" and theme.Danger or theme.Accent)
	local host = self._notificationHost
	local frame = new("Frame", {
		Name = "Notification", BackgroundColor3 = theme.Panel, BorderSizePixel = 0,
		Size = UDim2.fromOffset(306, config.Description and 72 or 56), ZIndex = 960, Parent = host,
	})
	corner(frame, 5)
	local marker = new("Frame", { BackgroundColor3 = accent, BorderSizePixel = 0, Size = UDim2.fromOffset(2, frame.Size.Y.Offset), ZIndex = 961, Parent = frame })
	local textX = 14
	if iconKey and self.Icons[iconKey] then
		new("ImageLabel", { BackgroundTransparency = 1, Image = self.Icons[iconKey], ImageColor3 = accent, ScaleType = Enum.ScaleType.Fit, Position = UDim2.fromOffset(13, 14), Size = UDim2.fromOffset(18, 18), ZIndex = 961, Parent = frame })
		textX = 42
	end
	local title = makeTextLabel(frame, tostring(config.Title or "Notification"), TYPE.Body, FONT.Bold, theme.Text, Enum.TextXAlignment.Left)
	title.Position = UDim2.fromOffset(textX, 7); title.Size = UDim2.new(1, -(textX + 12), 0, 28); title.ZIndex = 961
	if config.Description then
		local description = makeTextLabel(frame, tostring(config.Description), TYPE.Description, FONT.Regular, theme.TextSecondary, Enum.TextXAlignment.Left)
		description.Position = UDim2.fromOffset(textX, 31); description.Size = UDim2.new(1, -(textX + 12), 0, 30); description.TextWrapped = true; description.TextYAlignment = Enum.TextYAlignment.Top; description.ZIndex = 961
	end
	frame.Position = UDim2.fromOffset(18, 0)
	self._motion:Tween(frame, MOTION.Settle, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, { Position = UDim2.fromOffset(0, 0) })
	self._audio:Play(kind == "Success" and "Success" or (kind == "Error" and "Error" or "Notification"))
	local closed = false
	local function close()
		if closed or not frame.Parent then return end
		closed = true
		self._motion:Tween(frame, MOTION.Travel, Enum.EasingStyle.Quart, Enum.EasingDirection.In, { Position = UDim2.fromOffset(18, 0) })
		task.delay(MOTION.Travel + 0.03, function() if frame.Parent then frame:Destroy() end end)
	end
	frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then close() end
	end)
	task.delay(math.max(1.2, tonumber(config.Duration) or 3.5), close)
	return { Close = close, Frame = frame }
end

function LunkaraUI:Dialog(config)
	config = config or {}
	local theme = self.Theme
	local dialog = new("Frame", { Name = "Dialog", BackgroundColor3 = theme.Panel, BorderSizePixel = 0, Size = UDim2.fromOffset(430, 178), Visible = false })
	corner(dialog, 6)
	local marker = new("Frame", { BackgroundColor3 = theme.Accent, BorderSizePixel = 0, Position = UDim2.fromOffset(16, 18), Size = UDim2.fromOffset(2, 18), ZIndex = 923, Parent = dialog })
	corner(marker, 1)
	local title = makeTextLabel(dialog, tostring(config.Title or "Confirm"), 15, FONT.Bold, theme.Text, Enum.TextXAlignment.Left)
	title.Position = UDim2.fromOffset(28, 10); title.Size = UDim2.new(1, -44, 0, 34); title.ZIndex = 923
	local body = makeTextLabel(dialog, tostring(config.Text or config.Description or "Continue with this action?"), TYPE.Body, FONT.Regular, theme.TextSecondary, Enum.TextXAlignment.Left)
	body.Position = UDim2.fromOffset(18, 52); body.Size = UDim2.new(1, -36, 0, 58); body.TextWrapped = true; body.TextYAlignment = Enum.TextYAlignment.Top; body.ZIndex = 923
	local buttonHost = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -14), Size = UDim2.fromOffset(238, 30), ZIndex = 923, Parent = dialog })
	local list = new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8), Parent = buttonHost })
	local cancel = new("TextButton", { AutoButtonColor = false, Text = string.upper(tostring(config.CancelText or "Cancel")), TextSize = TYPE.Meta, TextScaled = false, Font = FONT.Bold, TextColor3 = theme.TextSecondary, BackgroundColor3 = theme.Input, BorderSizePixel = 0, Size = UDim2.fromOffset(104, 30), LayoutOrder = 1, ZIndex = 924, Parent = buttonHost })
	corner(cancel, 4)
	local confirm = new("TextButton", { AutoButtonColor = false, Text = string.upper(tostring(config.ConfirmText or "Confirm")), TextSize = TYPE.Meta, TextScaled = false, Font = FONT.Bold, TextColor3 = theme.Text, BackgroundColor3 = config.Danger and theme.Danger or theme.Accent, BorderSizePixel = 0, Size = UDim2.fromOffset(116, 30), LayoutOrder = 2, ZIndex = 924, Parent = buttonHost })
	corner(confirm, 4)
	local function finish(accepted)
		self._overlay:Close(accepted and "confirm" or "cancel")
		if accepted then safeCallback(config.Callback or config.OnConfirm) else safeCallback(config.OnCancel) end
	end
	cancel.MouseButton1Click:Connect(function() finish(false) end)
	confirm.MouseButton1Click:Connect(function() finish(true) end)
	self._overlay:Open(dialog, nil, { Center = true })
	return dialog
end


LunkaraUI.Confirm = LunkaraUI.Dialog

function LunkaraUI:Prompt(config)
	config = config or {}
	local theme = self.Theme
	local dialog = new("Frame", { Name = "Prompt", BackgroundColor3 = theme.Panel, BorderSizePixel = 0, Size = UDim2.fromOffset(430, 194), Visible = false })
	corner(dialog, 6)
	local title = makeTextLabel(dialog, tostring(config.Title or "Input"), 15, FONT.Bold, theme.Text, Enum.TextXAlignment.Left)
	title.Position = UDim2.fromOffset(18, 10); title.Size = UDim2.new(1, -36, 0, 34); title.ZIndex = 923
	local body = makeTextLabel(dialog, tostring(config.Text or config.Description or "Enter a value."), TYPE.Description, FONT.Regular, theme.TextSecondary, Enum.TextXAlignment.Left)
	body.Position = UDim2.fromOffset(18, 43); body.Size = UDim2.new(1, -36, 0, 28); body.TextWrapped = true; body.ZIndex = 923
	local field = new("TextBox", {
		BackgroundColor3 = theme.Input, BorderSizePixel = 0, ClearTextOnFocus = false,
		Text = tostring(config.Default or ""), PlaceholderText = tostring(config.Placeholder or "Type here"), PlaceholderColor3 = theme.Muted,
		TextColor3 = theme.Text, TextSize = TYPE.Body, TextScaled = false, Font = FONT.Medium, TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(18, 78), Size = UDim2.new(1, -36, 0, 34), ZIndex = 924, Parent = dialog,
	})
	corner(field, 4); padding(field, 10, 10, 0, 0)
	local cancel = new("TextButton", { AutoButtonColor = false, Text = string.upper(tostring(config.CancelText or "Cancel")), TextSize = TYPE.Meta, TextScaled = false, Font = FONT.Bold, TextColor3 = theme.TextSecondary, BackgroundColor3 = theme.Input, BorderSizePixel = 0, Position = UDim2.new(1, -238, 1, -46), Size = UDim2.fromOffset(104, 30), ZIndex = 924, Parent = dialog })
	corner(cancel, 4)
	local confirm = new("TextButton", { AutoButtonColor = false, Text = string.upper(tostring(config.ConfirmText or "Apply")), TextSize = TYPE.Meta, TextScaled = false, Font = FONT.Bold, TextColor3 = theme.Text, BackgroundColor3 = theme.Accent, BorderSizePixel = 0, Position = UDim2.new(1, -126, 1, -46), Size = UDim2.fromOffset(108, 30), ZIndex = 924, Parent = dialog })
	corner(confirm, 4)
	local function finish(accepted)
		local value = field.Text
		self._overlay:Close(accepted and "prompt-confirm" or "prompt-cancel")
		if accepted then safeCallback(config.Callback or config.OnConfirm, value) else safeCallback(config.OnCancel) end
	end
	cancel.MouseButton1Click:Connect(function() finish(false) end)
	confirm.MouseButton1Click:Connect(function() finish(true) end)
	field.FocusLost:Connect(function(enterPressed) if enterPressed and config.SubmitOnEnter ~= false then finish(true) end end)
	self._overlay:Open(dialog, nil, { Center = true })
	task.defer(function() if field.Parent then field:CaptureFocus() end end)
	return dialog
end

function LunkaraUI:ContextMenu(anchor, options)
	options = options or {}
	local theme = self.Theme
	local width = math.max(160, tonumber(options.Width) or 184)
	local items = options.Items or options
	local count = #items
	local popup = new("Frame", { Name = "ContextMenu", BackgroundColor3 = theme.Panel, BorderSizePixel = 0, Size = UDim2.fromOffset(width, math.max(38, count * 31 + 10)), Visible = false })
	corner(popup, 5); padding(popup, 5, 5, 5, 5)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 1), Parent = popup })
	for index, item in ipairs(items) do
		local disabled = item.Disabled == true
		local button = new("TextButton", { AutoButtonColor = false, Text = tostring(item.Title or item.Text or ("Action " .. index)), TextSize = TYPE.Value, TextScaled = false, Font = FONT.Medium, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = disabled and theme.Disabled or theme.TextSecondary, BackgroundColor3 = theme.ControlHover, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = index, ZIndex = 925, Parent = popup })
		corner(button, 3); padding(button, 9, 9, 0, 0)
		if not disabled then
			button.MouseEnter:Connect(function() self._motion:Tween(button, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { BackgroundTransparency = 0, TextColor3 = theme.Text }) end)
			button.MouseLeave:Connect(function() self._motion:Tween(button, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { BackgroundTransparency = 1, TextColor3 = theme.TextSecondary }) end)
			button.MouseButton1Click:Connect(function() self._overlay:Close("context-select"); safeCallback(item.Callback, item) end)
		end
	end
	self._overlay:Open(popup, anchor, {})
	return popup
end

function LunkaraUI:ShowTooltip(anchor, textValue)
	if not anchor or not anchor.Parent then return nil end
	local theme = self.Theme
	local text = type(textValue) == "table" and tostring(textValue.Text or "") or tostring(textValue or "")
	if text == "" then return nil end
	local label = new("TextLabel", { Name = "Tooltip", BackgroundColor3 = theme.Panel, BorderSizePixel = 0, Text = text, TextSize = TYPE.Meta, TextScaled = false, Font = FONT.Medium, TextColor3 = theme.TextSecondary, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0), ZIndex = 980, Parent = self._overlayRoot })
	corner(label, 4); padding(label, 8, 8, 6, 6)
	RunService.Heartbeat:Wait()
	local pos = anchor.AbsolutePosition - self._overlayRoot.AbsolutePosition
	local size = anchor.AbsoluteSize
	local viewport = self._overlayRoot.AbsoluteSize
	local x = math.clamp(roundPixel(pos.X + size.X + 8), 8, math.max(8, viewport.X - label.AbsoluteSize.X - 8))
	local y = math.clamp(roundPixel(pos.Y + (size.Y - label.AbsoluteSize.Y) * 0.5), 8, math.max(8, viewport.Y - label.AbsoluteSize.Y - 8))
	label.Position = UDim2.fromOffset(x, y)
	local closed = false
	local function close() if not closed then closed = true; if label.Parent then label:Destroy() end end end
	return { Frame = label, Close = close }
end


function LunkaraUI:_collectSearchEntries(window)
	local entries = {}
	local windows = window and { window } or self.Windows
	local function tagsText(tags)
		if type(tags) ~= "table" then return "" end
		local out = {}; for _, value in ipairs(tags) do table.insert(out, tostring(value)) end; return table.concat(out, " ")
	end
	for _, currentWindow in ipairs(windows) do
		for _, page in ipairs(currentWindow._pages or {}) do
			table.insert(entries, { Title = page.Title, Type = "Page", Page = page, Haystack = string.lower(page.Title .. " " .. tagsText(page.Tags)) })
			for _, subpage in ipairs(page._subpages or {}) do
				if not subpage.HiddenTab then
					table.insert(entries, { Title = subpage.Title, Type = "Tab", Page = page, Subpage = subpage, Haystack = string.lower(page.Title .. " " .. subpage.Title .. " " .. tagsText(subpage.Tags)) })
				end
				for _, section in ipairs(subpage._sections or {}) do
					table.insert(entries, { Title = section.Title, Type = "Section", Page = page, Subpage = subpage, Section = section, Haystack = string.lower(page.Title .. " " .. subpage.Title .. " " .. section.Title .. " " .. tagsText(section.Tags)) })
					for _, control in ipairs(section._controls or {}) do
						if not control._destroyed then
							local desc = tostring(control.Description or "")
							local kind = tostring(control._kind or "Control")
							table.insert(entries, { Title = tostring(control.Title or kind), Description = desc, Type = kind, Page = page, Subpage = subpage, Section = section, Control = control, Haystack = string.lower(page.Title .. " " .. subpage.Title .. " " .. section.Title .. " " .. tostring(control.Title or "") .. " " .. desc .. " " .. kind .. " " .. tagsText(control.Tags)) })
						end
					end
				end
			end
		end
	end
	return entries
end

function LunkaraUI:OpenSearch(anchor, window, initialQuery)
	if self._destroyed then return end
	local theme = self.Theme
	local popup = new("Frame", { Name = "GlobalSearch", BackgroundColor3 = theme.Panel, BorderSizePixel = 0, Size = UDim2.fromOffset(430, 306), Visible = false })
	corner(popup, 6)
	local top = new("Frame", { BackgroundColor3 = theme.Input, BorderSizePixel = 0, Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 38), ZIndex = 923, Parent = popup })
	corner(top, 4)
	local icon = new("ImageLabel", { BackgroundTransparency = 1, Image = self.Icons.Search, ImageColor3 = theme.AccentBright, ScaleType = Enum.ScaleType.Fit, Position = UDim2.fromOffset(11, 10), Size = UDim2.fromOffset(18, 18), ZIndex = 924, Parent = top })
	local box = new("TextBox", { BackgroundTransparency = 1, ClearTextOnFocus = false, Text = tostring(initialQuery or ""), PlaceholderText = "Search pages, sections and controls", PlaceholderColor3 = theme.Muted, TextColor3 = theme.Text, TextSize = TYPE.Body, TextScaled = false, Font = FONT.Medium, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(39, 0), Size = UDim2.new(1, -48, 1, 0), ZIndex = 924, Parent = top })
	local results = new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(8, 54), Size = UDim2.new(1, -16, 1, -62), CanvasSize = UDim2.fromOffset(0, 0), ScrollBarThickness = 2, ScrollBarImageColor3 = theme.AccentDark, ZIndex = 923, Parent = popup })
	local layout = new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3), Parent = results })
	local entries = self:_collectSearchEntries(window)
	local resultMaid = Maid.new()
	local function clear()
		resultMaid:Cleanup(); resultMaid = Maid.new()
		for _, child in ipairs(results:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
	end
	local function navigate(entry)
		local page = entry.Page
		if page and page._window then page._window:_setActivePage(page) end
		if page and entry.Subpage and page._activeSubpage ~= entry.Subpage then page:SelectSubpage(entry.Subpage) end
		self._overlay:Close("search-select")
		local target = entry.Control and entry.Control._frame or (entry.Section and entry.Section._frame)
		local subpage = entry.Subpage
		if target and subpage and subpage._scroll then
			task.defer(function()
				RunService.Heartbeat:Wait()
				if target.Parent and subpage._scroll.Parent then
					local relative = target.AbsolutePosition.Y - subpage._scroll.AbsolutePosition.Y + subpage._scroll.CanvasPosition.Y
					subpage._scroll.CanvasPosition = Vector2.new(0, math.max(0, relative - 18))
					local original = target.BackgroundColor3
					local originalTransparency = target.BackgroundTransparency
					self._motion:Tween(target, 0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { BackgroundColor3 = theme.AccentSurface, BackgroundTransparency = 0 })
					task.delay(0.28, function() if target.Parent then self._motion:Tween(target, 0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { BackgroundColor3 = original, BackgroundTransparency = originalTransparency }) end end)
				end
			end)
		end
	end
	local function refresh()
		clear()
		local query = string.lower(box.Text):gsub("^%s+", ""):gsub("%s+$", "")
		local count = 0
		for _, entry in ipairs(entries) do
			if query == "" or string.find(entry.Haystack, query, 1, true) then
				count += 1
				if count > 10 then break end
				local row = new("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = theme.ControlHover, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, -2, 0, 48), LayoutOrder = count, ZIndex = 924, Parent = results })
				corner(row, 4)
				local title = makeTextLabel(row, entry.Title, TYPE.Body, FONT.Bold, theme.Text, Enum.TextXAlignment.Left)
				title.Position = UDim2.fromOffset(10, 4); title.Size = UDim2.new(1, -20, 0, 22); title.ZIndex = 925
				local meta = makeTextLabel(row, (entry.Page and entry.Page.Title or "") .. "    " .. entry.Type, TYPE.Meta, FONT.Medium, theme.Muted, Enum.TextXAlignment.Left)
				meta.Position = UDim2.fromOffset(10, 25); meta.Size = UDim2.new(1, -20, 0, 17); meta.ZIndex = 925
				resultMaid:Give(row.MouseEnter:Connect(function() self._motion:Tween(row, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { BackgroundTransparency = 0 }) end))
				resultMaid:Give(row.MouseLeave:Connect(function() self._motion:Tween(row, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { BackgroundTransparency = 1 }) end))
				resultMaid:Give(row.MouseButton1Click:Connect(function() navigate(entry) end))
			end
		end
		results.CanvasSize = UDim2.fromOffset(0, count * 51)
	end
	box:GetPropertyChangedSignal("Text"):Connect(refresh)
	self._overlay:Open(popup, anchor, { Center = anchor == nil, OnClose = function() resultMaid:Cleanup() end })
	task.defer(function() if box.Parent then box:CaptureFocus(); refresh() end end)
end


local function trimText(value)
	return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function tokenizeCommandLine(text)
	text = tostring(text or "")
	local tokens = {}
	local current = {}
	local quote = nil
	local escaped = false
	local function flush()
		if #current > 0 then
			table.insert(tokens, table.concat(current))
			current = {}
		end
	end
	for i = 1, #text do
		local ch = string.sub(text, i, i)
		if escaped then
			table.insert(current, ch)
			escaped = false
		elseif ch == "\\" then
			escaped = true
		elseif quote then
			if ch == quote then quote = nil else table.insert(current, ch) end
		elseif ch == '"' or ch == "'" then
			quote = ch
		elseif string.match(ch, "%s") then
			flush()
		else
			table.insert(current, ch)
		end
	end
	if escaped then table.insert(current, "\\") end
	flush()
	return tokens
end

local function normalizedCommandName(value)
	return string.lower(trimText(value))
end

function LunkaraUI:RegisterCommand(config)
	assert(type(config) == "table", "RegisterCommand expects a table")
	local name = normalizedCommandName(config.Name)
	assert(name ~= "", "Command.Name is required")
	if self._commandsByName[name] then
		self:UnregisterCommand(name)
	end
	local previousAliasOwner = self._commandAliases[name]
	if previousAliasOwner then
		self._commandAliases[name] = nil
		local owner = self._commandsByName[previousAliasOwner]
		if owner then
			for i = #owner.Aliases, 1, -1 do if owner.Aliases[i] == name then table.remove(owner.Aliases, i) end end
		end
	end
	local command = {
		Name = name,
		DisplayName = tostring(config.DisplayName or config.Name or name),
		Aliases = {},
		Category = tostring(config.Category or "General"),
		Description = tostring(config.Description or ""),
		Syntax = tostring(config.Syntax or name),
		Callback = config.Callback,
		Hidden = config.Hidden == true,
		Tags = type(config.Tags) == "table" and cloneArray(config.Tags) or {},
		_ui = self,
	}
	for _, alias in ipairs(config.Aliases or {}) do
		alias = normalizedCommandName(alias)
		if alias ~= "" and alias ~= name and not table.find(command.Aliases, alias) then
			local existing = self._commandAliases[alias]
			if self._commandsByName[alias] then
				warn("[LunkaraUI] Command alias '" .. alias .. "' conflicts with an existing command name.")
			elseif not existing then
				table.insert(command.Aliases, alias)
				self._commandAliases[alias] = name
			else
				warn("[LunkaraUI] Command alias '" .. alias .. "' is already owned by '" .. existing .. "'.")
			end
		end
	end
	function command:Destroy()
		if self._ui then self._ui:UnregisterCommand(self.Name) end
	end
	self._commandsByName[name] = command
	table.insert(self._commands, command)
	return command
end

function LunkaraUI:UnregisterCommand(name)
	name = normalizedCommandName(name)
	local canonical = self._commandAliases[name] or name
	local command = self._commandsByName[canonical]
	if not command then return false end
	self._commandsByName[canonical] = nil
	for _, alias in ipairs(command.Aliases) do
		if self._commandAliases[alias] == canonical then self._commandAliases[alias] = nil end
	end
	for i = #self._commands, 1, -1 do
		if self._commands[i] == command then table.remove(self._commands, i); break end
	end
	command._ui = nil
	return true
end

function LunkaraUI:GetCommand(name)
	name = normalizedCommandName(name)
	local canonical = self._commandAliases[name] or name
	return self._commandsByName[canonical]
end

function LunkaraUI:GetCommands(category)
	local result = {}
	local wanted = category and string.lower(tostring(category)) or nil
	for _, command in ipairs(self._commands) do
		if not command.Hidden and (not wanted or string.lower(command.Category) == wanted) then
			table.insert(result, command)
		end
	end
	table.sort(result, function(a, b)
		if a.Category == b.Category then return a.DisplayName < b.DisplayName end
		return a.Category < b.Category
	end)
	return result
end

function LunkaraUI:_pushCommandHistory(raw)
	raw = trimText(raw)
	if raw == "" then return end
	if self._commandHistory[#self._commandHistory] ~= raw then table.insert(self._commandHistory, raw) end
	while #self._commandHistory > 40 do table.remove(self._commandHistory, 1) end
end

function LunkaraUI:ExecuteCommand(raw, context)
	raw = trimText(raw)
	if raw == "" then return false, "No command entered" end
	local prefix = tostring(self.Config.Commands.Prefix or ";")
	if prefix ~= "" and string.sub(raw, 1, #prefix) == prefix then raw = trimText(string.sub(raw, #prefix + 1)) end
	local parts = tokenizeCommandLine(raw)
	local typedName = normalizedCommandName(table.remove(parts, 1) or "")
	local command = self:GetCommand(typedName)
	if not command then
		local message = "Unknown command: " .. typedName
		self:Notify({ Type = "Error", Title = "Command", Description = message, Duration = 2.6 })
		return false, message
	end
	self:_pushCommandHistory(raw)
	local ctx = type(context) == "table" and context or {}
	ctx.UI = self
	ctx.Window = ctx.Window or self.Windows[1]
	ctx.Player = Players.LocalPlayer
	ctx.Raw = raw
	ctx.Command = command
	ctx.Arguments = parts
	local ok, result, secondary = pcall(function()
		if type(command.Callback) == "function" then return command.Callback(ctx, parts) end
		return true
	end)
	if not ok then
		local message = tostring(result)
		self:Notify({ Type = "Error", Title = command.DisplayName, Description = message, Duration = 3.2 })
		return false, message
	end
	if result == false then
		local message = tostring(secondary or "Command failed")
		self:Notify({ Type = "Error", Title = command.DisplayName, Description = message, Duration = 2.8 })
		return false, message
	end
	local message = nil
	if type(result) == "string" then message = result elseif type(secondary) == "string" then message = secondary end
	return true, message or "Executed " .. command.DisplayName
end

function LunkaraUI:_registerBuiltinCommands()
	self:RegisterCommand({
		Name = "help", Aliases = { "commands", "cmds" }, Category = "Lunkara",
		Description = "Open the visual command center. Optionally prefilter commands.", Syntax = "help [query]",
		Callback = function(ctx, args)
			local query = table.concat(args, " ")
			task.defer(function() self:OpenCommandPanel(ctx.Window, query) end)
			return "Command Center opened"
		end,
	})
	self:RegisterCommand({
		Name = "search", Category = "Lunkara", Description = "Open global UI search.", Syntax = "search <query>",
		Callback = function(ctx, args)
			local query = table.concat(args, " ")
			task.defer(function() self:OpenSearch(nil, ctx.Window, query) end)
			return "Search opened"
		end,
	})
	self:RegisterCommand({
		Name = "page", Category = "UI", Description = "Switch the active LunkaraUI page by title.", Syntax = "page <title>",
		Callback = function(ctx, args)
			local wanted = string.lower(table.concat(args, " "))
			if wanted == "" then return false, "Page title is required" end
			local window = ctx.Window
			if not window then return false, "No window exists" end
			for _, page in ipairs(window._pages or {}) do
				if string.lower(page.Title) == wanted then window:_setActivePage(page); return "Opened " .. page.Title end
			end
			return false, "Page not found: " .. table.concat(args, " ")
		end,
	})
	self:RegisterCommand({
		Name = "notify", Category = "UI", Description = "Show a LunkaraUI notification.", Syntax = "notify <text>",
		Callback = function(_, args)
			local textValue = table.concat(args, " ")
			if textValue == "" then return false, "Notification text is required" end
			self:Notify({ Title = "Command", Description = textValue })
			return "Notification shown"
		end,
	})
	self:RegisterCommand({
		Name = "toggleui", Aliases = { "ui" }, Category = "UI", Description = "Show or hide the active window.", Syntax = "toggleui",
		Callback = function(ctx)
			local window = ctx.Window
			if not window then return false, "No window exists" end
			local visible = window._shell.Visible or window._miniBar.Visible
			window:SetVisible(not visible)
			return visible and "UI hidden" or "UI shown"
		end,
	})
	self:RegisterCommand({
		Name = "minimize", Category = "UI", Description = "Minimize the active window.", Syntax = "minimize",
		Callback = function(ctx)
			if not ctx.Window then return false, "No window exists" end
			ctx.Window:SetMinimized(true); return "Window minimized"
		end,
	})
	self:RegisterCommand({
		Name = "restore", Category = "UI", Description = "Restore the active window.", Syntax = "restore",
		Callback = function(ctx)
			if not ctx.Window then return false, "No window exists" end
			ctx.Window:SetVisible(true); ctx.Window:SetMinimized(false); return "Window restored"
		end,
	})
	self:RegisterCommand({
		Name = "flags", Category = "Utility", Description = "Report the number of registered state flags.", Syntax = "flags",
		Callback = function()
			local count = 0; for _ in pairs(self.Flags) do count += 1 end
			return tostring(count) .. " flags registered"
		end,
	})
	self:RegisterCommand({
		Name = "clearhistory", Category = "Utility", Description = "Clear Command Center history.", Syntax = "clearhistory",
		Callback = function()
			self._commandHistory = {}; return "Command history cleared"
		end,
	})
end

function LunkaraUI:OpenCommandPanel(window, initialText)
	if self._destroyed or self.Config.Commands.Enabled == false then return end
	window = window or self.Windows[1]
	local theme = self.Theme
	local viewport = self._root.AbsoluteSize
	local width = math.min(780, math.max(360, roundPixel(viewport.X - 48)))
	local height = math.min(438, math.max(320, roundPixel(viewport.Y - 48)))
	local panel = new("Frame", {
		Name = "CommandCenter", BackgroundColor3 = theme.BackgroundDeep, BorderSizePixel = 0,
		Size = UDim2.fromOffset(width, height), Visible = false,
	})
	corner(panel, 5)

	local top = new("Frame", { Name = "Header", BackgroundColor3 = theme.Header, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 46), ZIndex = 923, Parent = panel })
	local topMarker = new("Frame", { BackgroundColor3 = theme.Accent, BorderSizePixel = 0, Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(2, 18), ZIndex = 924, Parent = top })
	corner(topMarker, 1)
	local title = makeTextLabel(top, "Command Center", 15, FONT.Bold, theme.Text, Enum.TextXAlignment.Left)
	title.Position = UDim2.fromOffset(26, 0); title.Size = UDim2.fromOffset(190, 46); title.ZIndex = 924
	local status = makeTextLabel(top, "", TYPE.Value, FONT.Medium, theme.TextSecondary, Enum.TextXAlignment.Right)
	status.AnchorPoint = Vector2.new(1, 0); status.Position = UDim2.new(1, -46, 0, 0); status.Size = UDim2.fromOffset(250, 46); status.ZIndex = 924
	local close = new("TextButton", { Name = "Close", AutoButtonColor = false, Text = "", BackgroundTransparency = 1, BorderSizePixel = 0, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(26, 26), ZIndex = 925, Parent = top })
	new("ImageLabel", { BackgroundTransparency = 1, Image = self.Icons.Close, ImageColor3 = theme.Muted, ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5,0.5), Position = UDim2.fromScale(0.5,0.5), Size = UDim2.fromOffset(12,12), ZIndex = 926, Parent = close })

	local bodyY = 54
	local bottomH = 48
	local categoryW = 146
	local inspectorW = width >= 710 and 220 or 0
	local listX = categoryW + 18
	local listW = width - listX - inspectorW - (inspectorW > 0 and 18 or 10)
	local bodyH = height - bodyY - bottomH - 8

	local categories = new("Frame", { Name = "Categories", BackgroundColor3 = theme.Panel, BorderSizePixel = 0, Position = UDim2.fromOffset(10, bodyY), Size = UDim2.fromOffset(categoryW, bodyH), ZIndex = 923, Parent = panel })
	corner(categories, 4); padding(categories, 8, 8, 8, 8)
	local categoryTitle = makeTextLabel(categories, "Commands", TYPE.Section, FONT.Bold, theme.Text, Enum.TextXAlignment.Left)
	categoryTitle.Size = UDim2.new(1,0,0,24); categoryTitle.ZIndex = 924
	local categoryHost = new("Frame", { BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1,0,1,-28), ZIndex = 924, Parent = categories })
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,2), Parent = categoryHost })

	local listPanel = new("Frame", { Name = "Commands", BackgroundColor3 = theme.Panel, BorderSizePixel = 0, Position = UDim2.fromOffset(listX, bodyY), Size = UDim2.fromOffset(listW, bodyH), ZIndex = 923, Parent = panel })
	corner(listPanel, 4); padding(listPanel, 6, 6, 6, 6)
	local list = new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1,1), CanvasSize = UDim2.fromOffset(0,0), ScrollBarThickness = 2, ScrollBarImageColor3 = theme.AccentDark, ZIndex = 924, Parent = listPanel })
	local listLayout = new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0,2), Parent = list })

	local inspector = nil
	local inspectorName, inspectorSyntax, inspectorDescription, inspectorAliases, inspectorCategory
	if inspectorW > 0 then
		inspector = new("Frame", { Name = "Inspector", BackgroundColor3 = theme.Panel, BorderSizePixel = 0, Position = UDim2.fromOffset(width - inspectorW - 10, bodyY), Size = UDim2.fromOffset(inspectorW, bodyH), ZIndex = 923, Parent = panel })
		corner(inspector, 4); padding(inspector, 12, 12, 10, 10)
		inspectorName = makeTextLabel(inspector, "Select a command", 14, FONT.Bold, theme.Text, Enum.TextXAlignment.Left); inspectorName.Size = UDim2.new(1,0,0,26); inspectorName.ZIndex = 924
		inspectorSyntax = makeTextLabel(inspector, "", TYPE.Value, FONT.Medium, theme.AccentBright, Enum.TextXAlignment.Left); inspectorSyntax.Position = UDim2.fromOffset(0,30); inspectorSyntax.Size = UDim2.new(1,0,0,24); inspectorSyntax.ZIndex = 924
		inspectorDescription = makeTextLabel(inspector, "", TYPE.Description, FONT.Regular, theme.TextSecondary, Enum.TextXAlignment.Left); inspectorDescription.Position = UDim2.fromOffset(0,60); inspectorDescription.Size = UDim2.new(1,0,0,88); inspectorDescription.TextWrapped = true; inspectorDescription.TextYAlignment = Enum.TextYAlignment.Top; inspectorDescription.ZIndex = 924
		inspectorCategory = makeTextLabel(inspector, "", TYPE.Value, FONT.Bold, theme.TextSecondary, Enum.TextXAlignment.Left); inspectorCategory.Position = UDim2.fromOffset(0,154); inspectorCategory.Size = UDim2.new(1,0,0,22); inspectorCategory.ZIndex = 924
		inspectorAliases = makeTextLabel(inspector, "", TYPE.Description, FONT.Regular, theme.Muted, Enum.TextXAlignment.Left); inspectorAliases.Position = UDim2.fromOffset(0,181); inspectorAliases.Size = UDim2.new(1,0,0,50); inspectorAliases.TextWrapped = true; inspectorAliases.TextYAlignment = Enum.TextYAlignment.Top; inspectorAliases.ZIndex = 924
	end

	local commandBar = new("Frame", { Name = "CommandBar", BackgroundColor3 = theme.Panel, BorderSizePixel = 0, Position = UDim2.fromOffset(10, height - 44), Size = UDim2.new(1, -20, 0, 34), ZIndex = 923, Parent = panel })
	corner(commandBar, 4)
	local prefix = makeTextLabel(commandBar, tostring(self.Config.Commands.Prefix or ";"), 15, FONT.Bold, theme.AccentBright, Enum.TextXAlignment.Center)
	prefix.Position = UDim2.fromOffset(8,0); prefix.Size = UDim2.fromOffset(22,34); prefix.ZIndex = 924
	local run = new("TextButton", { AutoButtonColor = false, Text = "RUN", TextSize = TYPE.Meta, TextScaled = false, Font = FONT.Bold, TextColor3 = theme.Text, BackgroundColor3 = theme.Accent, BorderSizePixel = 0, AnchorPoint = Vector2.new(1,0.5), Position = UDim2.new(1,-5,0.5,0), Size = UDim2.fromOffset(62,24), ZIndex = 925, Parent = commandBar })
	corner(run, 3)
	local box = new("TextBox", { Name = "Input", BackgroundTransparency = 1, ClearTextOnFocus = false, Text = tostring(initialText or ""), PlaceholderText = "Type a command or filter the list", PlaceholderColor3 = theme.Muted, TextColor3 = theme.Text, TextSize = TYPE.Body, TextScaled = false, Font = FONT.Medium, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(34,0), Size = UDim2.new(1,-106,1,0), ZIndex = 924, Parent = commandBar })

	local resultMaid = Maid.new()
	local categoryMaid = Maid.new()
	local selectedCategory = "All"
	local selectedCommand = nil
	local historyIndex = #self._commandHistory + 1

	local function setStatus(textValue, errorState)
		status.Text = tostring(textValue or "")
		status.TextColor3 = errorState and theme.Danger or theme.TextSecondary
	end
	local function showDetails(command)
		selectedCommand = command
		if not inspector then return end
		if not command then
			inspectorName.Text = "Select a command"; inspectorSyntax.Text = ""; inspectorDescription.Text = ""; inspectorCategory.Text = ""; inspectorAliases.Text = ""; return
		end
		inspectorName.Text = command.DisplayName
		inspectorSyntax.Text = tostring(self.Config.Commands.Prefix or ";") .. command.Syntax
		inspectorDescription.Text = command.Description
		inspectorCategory.Text = command.Category
		inspectorAliases.Text = #command.Aliases > 0 and ("Aliases: " .. table.concat(command.Aliases, ", ")) or ""
	end
	local function firstTypedWord()
		local raw = trimText(box.Text)
		local p = tostring(self.Config.Commands.Prefix or ";")
		if p ~= "" and string.sub(raw,1,#p) == p then raw = trimText(string.sub(raw,#p+1)) end
		return normalizedCommandName(tokenizeCommandLine(raw)[1] or "")
	end
	local function clearRows()
		resultMaid:Cleanup(); resultMaid = Maid.new()
		for _, child in ipairs(list:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
	end
	local function refreshRows()
		clearRows()
		local query = firstTypedWord()
		local count = 0
		local first = nil
		for _, command in ipairs(self:GetCommands()) do
			local inCategory = selectedCategory == "All" or command.Category == selectedCategory
			local haystack = string.lower(command.Name .. " " .. command.DisplayName .. " " .. command.Description .. " " .. table.concat(command.Aliases, " ") .. " " .. table.concat(command.Tags, " "))
			if inCategory and (query == "" or string.find(haystack, query, 1, true)) then
				count += 1
				if not first then first = command end
				local row = new("TextButton", { AutoButtonColor = false, Text = "", BackgroundColor3 = theme.ControlHover, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1,-2,0,46), LayoutOrder = count, ZIndex = 925, Parent = list })
				corner(row, 3)
				local marker = new("Frame", { BackgroundColor3 = theme.Accent, BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0,8), Size = UDim2.fromOffset(2,30), ZIndex = 926, Parent = row }); corner(marker,1)
				local nameLabel = makeTextLabel(row, command.DisplayName, TYPE.Body, FONT.Bold, theme.Text, Enum.TextXAlignment.Left); nameLabel.Position = UDim2.fromOffset(10,2); nameLabel.Size = UDim2.new(1,-20,0,23); nameLabel.ZIndex = 926
				local desc = makeTextLabel(row, command.Description ~= "" and command.Description or command.Syntax, TYPE.Description, FONT.Regular, theme.TextSecondary, Enum.TextXAlignment.Left); desc.Position = UDim2.fromOffset(10,23); desc.Size = UDim2.new(1,-20,0,18); desc.ZIndex = 926
				resultMaid:Give(row.MouseEnter:Connect(function() self._motion:Tween(row,MOTION.Snap,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,{BackgroundTransparency=0}); self._motion:Tween(marker,MOTION.Snap,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,{BackgroundTransparency=0}) end))
				resultMaid:Give(row.MouseLeave:Connect(function() self._motion:Tween(row,MOTION.Snap,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,{BackgroundTransparency=1}); self._motion:Tween(marker,MOTION.Snap,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,{BackgroundTransparency=1}) end))
				resultMaid:Give(row.MouseButton1Click:Connect(function()
					showDetails(command)
					box.Text = command.Name .. " "
					box.CursorPosition = #box.Text + 1
					box:CaptureFocus()
				end))
			end
		end
		list.CanvasSize = UDim2.fromOffset(0, count * 48)
		showDetails(selectedCommand or first)
	end
	local function buildCategories()
		categoryMaid:Cleanup(); categoryMaid = Maid.new()
		for _, child in ipairs(categoryHost:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
		local categoriesSeen = { All = true }
		local names = { "All" }
		for _, command in ipairs(self:GetCommands()) do
			if not categoriesSeen[command.Category] then categoriesSeen[command.Category] = true; table.insert(names, command.Category) end
		end
		table.sort(names, function(a,b) if a == "All" then return true elseif b == "All" then return false else return a < b end end)
		for index, name in ipairs(names) do
			local selected = name == selectedCategory
			local button = new("TextButton", { AutoButtonColor = false, Text = name, TextSize = TYPE.Value, TextScaled = false, Font = selected and FONT.Bold or FONT.Medium, TextColor3 = selected and theme.Text or theme.TextSecondary, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1,0,0,30), LayoutOrder = index, ZIndex = 925, Parent = categoryHost })
			padding(button, 9, 4, 0, 0)
			local marker = new("Frame", { BackgroundColor3 = theme.Accent, BackgroundTransparency = selected and 0 or 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0,8), Size = UDim2.fromOffset(2,14), ZIndex = 926, Parent = button }); corner(marker,1)
			categoryMaid:Give(button.MouseButton1Click:Connect(function() selectedCategory = name; buildCategories(); refreshRows() end))
			categoryMaid:Give(button.MouseEnter:Connect(function() if selectedCategory ~= name then button.TextColor3 = theme.Text end end))
			categoryMaid:Give(button.MouseLeave:Connect(function() if selectedCategory ~= name then button.TextColor3 = theme.TextSecondary end end))
		end
	end
	local function executeCurrent()
		local raw = trimText(box.Text)
		if raw == "" and selectedCommand then raw = selectedCommand.Name end
		if raw == "" then setStatus("Type a command", true); return end
		local ok, message = self:ExecuteCommand(raw, { Window = window })
		setStatus(message, not ok)
		if ok then box.Text = ""; historyIndex = #self._commandHistory + 1; refreshRows() end
	end

	close.MouseButton1Click:Connect(function() self._overlay:Close("command-close") end)
	run.MouseButton1Click:Connect(executeCurrent)
	box:GetPropertyChangedSignal("Text"):Connect(refreshRows)
	box.FocusLost:Connect(function(enterPressed) if enterPressed then executeCurrent() end end)
	box.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if input.KeyCode == Enum.KeyCode.Tab then
			local query = firstTypedWord()
			for _, command in ipairs(self:GetCommands(selectedCategory ~= "All" and selectedCategory or nil)) do
				if query == "" or string.sub(command.Name,1,#query) == query then box.Text = command.Name .. " "; box.CursorPosition = #box.Text + 1; break end
			end
		elseif input.KeyCode == Enum.KeyCode.Up then
			if #self._commandHistory > 0 then historyIndex = math.clamp(historyIndex - 1, 1, #self._commandHistory); box.Text = self._commandHistory[historyIndex] or box.Text; box.CursorPosition = #box.Text + 1 end
		elseif input.KeyCode == Enum.KeyCode.Down then
			if #self._commandHistory > 0 then historyIndex = math.clamp(historyIndex + 1, 1, #self._commandHistory + 1); box.Text = historyIndex <= #self._commandHistory and self._commandHistory[historyIndex] or ""; box.CursorPosition = #box.Text + 1 end
		end
	end)

	self._overlay:Open(panel, nil, { Center = true, OnClose = function() resultMaid:Cleanup(); categoryMaid:Cleanup(); self._commandPanel = nil end })
	self._commandPanel = panel
	task.defer(function() if panel.Parent then buildCategories(); refreshRows(); box:CaptureFocus(); box.CursorPosition = #box.Text + 1 end end)
end

function LunkaraUI:ToggleCommandPanel(window)
	if self._commandPanel and self._commandPanel.Parent then self._overlay:Close("command-toggle") else self:OpenCommandPanel(window) end
end

function LunkaraUI.new(config)
	config = config or {}
	local self = setmetatable({}, LunkaraUI)
	self._maid = Maid.new()
	self._destroyed = false
	self.Flags = {}
	self.Windows = {}
	self._flagControls = {}
	self._searchControls = {}
	self._keybinds = {}
	self._capturingKeybind = nil
	self._commands = {}
	self._commandsByName = {}
	self._commandAliases = {}
	self._commandHistory = {}
	self._commandPanel = nil
	self.Theme = copyTable(DEFAULT_THEME)
	self.Icons = copyTable(DEFAULT_ICONS)

	if config.Theme then
		merge(self.Theme, config.Theme)
	end
	if config.Accent then
		local accent = config.Accent
		if typeof(accent) == "Color3" then
			applyAccentFamily(self.Theme, accent)
		elseif type(accent) == "string" then
			local ok, parsed = pcall(Color3.fromHex, accent)
			if ok then
				applyAccentFamily(self.Theme, parsed)
			end
		end
	end
	if config.Icons then
		merge(self.Icons, config.Icons)
	end

	self.Config = merge({
		Branding = {
			Name = "LunkaraUI",
			Logo = nil,
		},
		Audio = {
			Enabled = true,
			Volume = 0.35,
			Assets = {},
		},
		Motion = {
			Intensity = 1,
		},
		Commands = {
			Enabled = true,
			Key = Enum.KeyCode.Semicolon,
			Prefix = ";",
		},
	}, config)

	self._motion = Motion.new(self.Config.Motion.Intensity)
	self._audio = Audio.new(self.Config.Audio, self._maid)

	local player = Players.LocalPlayer
	assert(player, "LunkaraUI must be required from a LocalScript/client context")
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = new("ScreenGui", {
		Name = "LunkaraUI",
		IgnoreGuiInset = false,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 120,
		Parent = playerGui,
	})
	self._screenGui = screenGui
	self._maid:Give(screenGui)

	local root = new("Frame", {
		Name = "Root",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = screenGui,
	})
	self._root = root

	local overlayRoot = new("Frame", {
		Name = "OverlayRoot",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 890,
		Parent = root,
	})
	self._overlayRoot = overlayRoot
	self._overlay = Overlay.new(self)

	local notificationHost = new("Frame", {
		Name = "NotificationHost", BackgroundTransparency = 1, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(306, 520), ZIndex = 950, Parent = root,
	})
	new("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8), Parent = notificationHost })
	self._notificationHost = notificationHost

	self._maid:Give(UserInputService.InputChanged:Connect(function(input)
		if not self._activeDrag then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			self._activeDrag.onMove(input.Position)
		end
	end))
	self._maid:Give(UserInputService.InputEnded:Connect(function(input)
		if not self._activeDrag then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self:_endDrag()
		end
	end))
	self._maid:Give(UserInputService.InputBegan:Connect(function(input, processed)
		if self._capturingKeybind then
			if input.UserInputType == Enum.UserInputType.Keyboard then
				local control = self._capturingKeybind
				self._capturingKeybind = nil
				control._capturing = false
				if input.KeyCode == Enum.KeyCode.Escape then
					control:SetValue(Enum.KeyCode.Unknown, false)
				else
					control:SetValue(input.KeyCode, false)
				end
				if control._renderKeybind then control:_renderKeybind() end
			end
			return
		end
		if processed then return end
		if input.KeyCode == Enum.KeyCode.Escape then
			self._overlay:Close("escape")
			return
		end
		if input.UserInputType == Enum.UserInputType.Keyboard and self.Config.Commands.Enabled ~= false and input.KeyCode == self.Config.Commands.Key then
			self:ToggleCommandPanel(self.Windows[1])
			return
		end
		if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.K and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
			self:OpenSearch(nil, self.Windows[1])
			return
		end
		if input.UserInputType == Enum.UserInputType.Keyboard then
			for _, control in ipairs(self._keybinds) do
				if not control._destroyed and not control._disabled and control.Value == input.KeyCode and control.Value ~= Enum.KeyCode.Unknown then
					safeCallback(control._callback, input.KeyCode)
				end
			end
		end
	end))

	self:_registerBuiltinCommands()
	return self
end

function LunkaraUI:CreateWindow(config)
	config = config or {}
	local window = setmetatable({}, Window)
	window._ui = self
	window._maid = Maid.new()
	window._subtabMaid = Maid.new()
	window._maid:Give(window._subtabMaid)
	window._pages = {}
	window._activePage = nil
	window._transitionToken = 0
	window._destroyed = false
	window._targetSize = Vector2.new(860, 520)
	window._compact = false
	window._minimized = false
	window._maximized = false
	window._subtabUsedWidth = 0
	window.Title = tostring(config.Title or self.Config.Branding.Name or "LunkaraUI")
	if config.Size and typeof(config.Size) == "Vector2" then
		window._targetSize = config.Size
	end

	local theme = self.Theme
	window._positionInitialized = false
	local shell = new("Frame", {
		Name = "Window",
		BackgroundColor3 = theme.Background,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(window._targetSize.X, window._targetSize.Y),
		ClipsDescendants = true,
		Parent = self._root,
	})
	corner(shell, 7)
	window._shell = shell

	local railWidth = 64
	local rail = new("Frame", {
		Name = "Rail",
		BackgroundColor3 = theme.Rail,
		BorderSizePixel = 0,
		Size = UDim2.new(0, railWidth, 1, 0),
		Parent = shell,
	})
	window._rail = rail

	new("Frame", {
		Name = "RailDivider",
		BackgroundColor3 = theme.RailDivider,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 1, 1, 0),
		Parent = rail,
	})

	local logo = normalizeAsset(self.Config.Branding.Logo)
	local brandHeight = logo and 58 or 30
	local brandHost = new("Frame", {
		Name = "BrandHost",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, brandHeight),
		Parent = rail,
	})
	if logo then
		new("ImageLabel", {
			Name = "Logo",
			BackgroundTransparency = 1,
			Image = logo,
			ImageColor3 = theme.Text,
			ScaleType = Enum.ScaleType.Fit,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(27, 27),
			Parent = brandHost,
		})
	else
		local brandName = tostring(self.Config.Branding.Name or "LunkaraUI")
		local monogram = string.upper(string.sub(brandName, 1, 1))
		local brandText = makeTextLabel(brandHost, monogram, 16, FONT.Bold, theme.AccentBright, Enum.TextXAlignment.Center)
		brandText.Size = UDim2.fromScale(1, 1)
	end

	local navHost = new("Frame", {
		Name = "PrimaryNavigation",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(11, brandHeight + 9),
		Size = UDim2.new(1, -22, 1, -(brandHeight + 150)),
		Parent = rail,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
		Parent = navHost,
	})
	window._navHost = navHost

	local bottomNavHost = new("Frame", {
		Name = "UtilityNavigation",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 11, 1, -30),
		Size = UDim2.fromOffset(42, 96),
		Parent = rail,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
		Parent = bottomNavHost,
	})
	window._bottomNavHost = bottomNavHost

	local credit = makeTextLabel(rail, "LUNKARA UI", TYPE.Credit, FONT.Bold, theme.TextSecondary, Enum.TextXAlignment.Center)
	credit.AnchorPoint = Vector2.new(0.5, 1)
	credit.Position = UDim2.new(0.5, 0, 1, -7)
	credit.Size = UDim2.new(1, -6, 0, 14)

	local workspace = new("Frame", {
		Name = "Workspace",
		BackgroundColor3 = theme.Background,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(railWidth, 0),
		Size = UDim2.new(1, -railWidth, 1, 0),
		Parent = shell,
	})
	window._workspace = workspace

	local headerHeight = 54
	local header = new("Frame", {
		Name = "Header",
		BackgroundColor3 = theme.Header,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, headerHeight),
		Parent = workspace,
	})
	window._header = header

	local headerMarker = new("Frame", {
		Name = "HeaderMarker",
		BackgroundColor3 = theme.Accent,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(14, 18),
		Size = UDim2.fromOffset(2, 14),
		Parent = header,
	})
	corner(headerMarker, 1)

	local pageTitle = makeTextLabel(header, window.Title, TYPE.Header, FONT.Bold, theme.Text, Enum.TextXAlignment.Left)
	pageTitle.Position = UDim2.fromOffset(23, 0)
	pageTitle.Size = UDim2.fromOffset(142, headerHeight)
	window._pageTitle = pageTitle

	local contextLabel = makeTextLabel(header, "", TYPE.Meta, FONT.Medium, theme.AccentBright, Enum.TextXAlignment.Left)
	contextLabel.Position = UDim2.fromOffset(124, 0)
	contextLabel.Size = UDim2.fromOffset(120, headerHeight)
	contextLabel.Visible = false
	window._contextLabel = contextLabel

	local subtabHost = new("Frame", {
		Name = "Subtabs",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(174, 0),
		Size = UDim2.new(1, -470, 1, 0),
		Parent = header,
	})
	window._subtabHost = subtabHost

	local searchButton = new("TextButton", {
		Name = "Search", AutoButtonColor = false, Text = "", BackgroundColor3 = theme.ControlHover, BackgroundTransparency = 1, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -98, 0.5, 0), Size = UDim2.fromOffset(112, 28), Parent = header,
	})
	corner(searchButton, 4)
	local searchIcon = new("ImageLabel", { BackgroundTransparency = 1, Image = self.Icons.Search, ImageColor3 = theme.Muted, ScaleType = Enum.ScaleType.Fit, Position = UDim2.fromOffset(9, 7), Size = UDim2.fromOffset(14, 14), Parent = searchButton })
	local searchText = makeTextLabel(searchButton, "Search", TYPE.Meta, FONT.Medium, theme.TextSecondary, Enum.TextXAlignment.Left)
	searchText.Position = UDim2.fromOffset(31, 0); searchText.Size = UDim2.new(1, -38, 1, 0)
	window._searchButton = searchButton
	window._searchText = searchText
	window._maid:Give(searchButton.MouseEnter:Connect(function()
		self._motion:Tween(searchButton, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { BackgroundTransparency = 0, BackgroundColor3 = theme.ControlHover })
		self._motion:Tween(searchIcon, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { ImageColor3 = theme.AccentBright })
	end))
	window._maid:Give(searchButton.MouseLeave:Connect(function()
		self._motion:Tween(searchButton, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { BackgroundTransparency = 1, BackgroundColor3 = theme.ControlHover })
		self._motion:Tween(searchIcon, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { ImageColor3 = theme.Muted })
	end))
	window._maid:Give(searchButton.MouseButton1Click:Connect(function() self:OpenSearch(searchButton, window) end))

	local commandButton = nil
	if self.Config.Commands.Enabled ~= false then
		commandButton = new("TextButton", {
			Name = "CommandCenter", AutoButtonColor = false, Text = "CMD", TextSize = TYPE.Meta, TextScaled = false, Font = FONT.Bold,
			TextColor3 = theme.TextSecondary, BackgroundColor3 = theme.ControlHover, BackgroundTransparency = 1, BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -218, 0.5, 0), Size = UDim2.fromOffset(52, 28), Parent = header,
		})
		corner(commandButton, 4)
		window._maid:Give(commandButton.MouseEnter:Connect(function()
			self._motion:Tween(commandButton, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { BackgroundTransparency = 0, TextColor3 = theme.AccentBright })
		end))
		window._maid:Give(commandButton.MouseLeave:Connect(function()
			self._motion:Tween(commandButton, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { BackgroundTransparency = 1, TextColor3 = theme.TextSecondary })
		end))
		window._maid:Give(commandButton.MouseButton1Click:Connect(function() self:OpenCommandPanel(window) end))
	end
	window._commandButton = commandButton

	local controlsHost = new("Frame", {
		Name = "WindowControls",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(82, 30),
		Parent = header,
	})
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 3),
		Parent = controlsHost,
	})

	local function makeWindowButton(name, iconId, order, danger)
		local button = new("TextButton", {
			Name = name,
			AutoButtonColor = false,
			Text = "",
			BackgroundColor3 = theme.ControlHover,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(24, 24),
			LayoutOrder = order,
			Parent = controlsHost,
		})
		corner(button, 4)
		local image = new("ImageLabel", {
			BackgroundTransparency = 1,
			Image = iconId,
			ImageColor3 = theme.Muted,
			ScaleType = Enum.ScaleType.Fit,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(12, 12),
			Parent = button,
		})
		window._maid:Give(button.MouseEnter:Connect(function()
			self._audio:Play("Hover")
			self._motion:Tween(button, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
				BackgroundTransparency = 0,
			})
			self._motion:Tween(image, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
				ImageColor3 = danger and theme.Danger or theme.TextSecondary,
			})
		end))
		window._maid:Give(button.MouseLeave:Connect(function()
			self._motion:Tween(button, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
				BackgroundTransparency = 1,
			})
			self._motion:Tween(image, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
				ImageColor3 = theme.Muted,
			})
		end))
		return button
	end

	local minimizeButton = makeWindowButton("Minimize", self.Icons.Minimize, 1, false)
	local maximizeButton = makeWindowButton("Maximize", self.Icons.Maximize, 2, false)
	local closeButton = makeWindowButton("Close", self.Icons.Close, 3, true)

	local contentHost = new("Frame", {
		Name = "ContentHost",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 62),
		Size = UDim2.new(1, -24, 1, -74),
		ClipsDescendants = true,
		Parent = workspace,
	})
	window._contentHost = contentHost

	local transitionWash = new("Frame", {
		Name = "TransitionWash",
		BackgroundColor3 = theme.Background,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 40,
		Parent = contentHost,
	})
	window._transitionWash = transitionWash
	local transitionLine = new("Frame", {
		Name = "TransitionLine",
		BackgroundColor3 = theme.Accent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(0, 2),
		ZIndex = 41,
		Parent = transitionWash,
	})
	corner(transitionLine, 1)
	window._transitionLine = transitionLine

	local miniBar = new("Frame", {
		Name = "MinimizedBar",
		BackgroundColor3 = theme.Background,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(286, 46),
		Visible = false,
		Parent = self._root,
	})
	corner(miniBar, 6)
	window._miniBar = miniBar

	local miniAccent = new("Frame", {
		BackgroundColor3 = theme.Accent,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 13),
		Size = UDim2.fromOffset(2, 20),
		Parent = miniBar,
	})
	corner(miniAccent, 1)
	local miniTitle = makeTextLabel(miniBar, window.Title, TYPE.Body, FONT.Bold, theme.Text, Enum.TextXAlignment.Left)
	miniTitle.Position = UDim2.fromOffset(13, 0)
	miniTitle.Size = UDim2.new(1, -82, 1, 0)
	local miniState = makeTextLabel(miniBar, "", TYPE.Credit, FONT.Bold, theme.Muted, Enum.TextXAlignment.Left)
	miniState.Visible = false

	local function makeMiniButton(name, iconId, xOffset, danger)
		local button = new("TextButton", {
			Name = name,
			AutoButtonColor = false,
			Text = "",
			BackgroundColor3 = theme.ControlHover,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, xOffset, 0.5, 0),
			Size = UDim2.fromOffset(27, 27),
			Parent = miniBar,
		})
		corner(button, 4)
		local image = new("ImageLabel", {
			BackgroundTransparency = 1,
			Image = iconId,
			ImageColor3 = danger and theme.Muted or theme.AccentBright,
			ScaleType = Enum.ScaleType.Fit,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(12, 12),
			Parent = button,
		})
		window._maid:Give(button.MouseEnter:Connect(function()
			self._motion:Tween(button, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
				BackgroundTransparency = 0,
			})
			self._motion:Tween(image, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
				ImageColor3 = danger and theme.Danger or theme.Text,
			})
		end))
		window._maid:Give(button.MouseLeave:Connect(function()
			self._motion:Tween(button, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
				BackgroundTransparency = 1,
			})
			self._motion:Tween(image, MOTION.Snap, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
				ImageColor3 = danger and theme.Muted or theme.AccentBright,
			})
		end))
		return button
	end

	local restoreButton = makeMiniButton("Restore", self.Icons.Maximize, -38, false)
	local miniCloseButton = makeMiniButton("Close", self.Icons.Close, -8, true)

	window._maid:Give(minimizeButton.MouseButton1Click:Connect(function()
		window:_setMinimized(true)
	end))
	window._maid:Give(restoreButton.MouseButton1Click:Connect(function()
		window:_setMinimized(false)
	end))
	window._maid:Give(maximizeButton.MouseButton1Click:Connect(function()
		window:_toggleMaximize()
	end))
	window._maid:Give(closeButton.MouseButton1Click:Connect(function()
		self._audio:Play("Close")
		window:Destroy()
	end))
	window._maid:Give(miniCloseButton.MouseButton1Click:Connect(function()
		self._audio:Play("Close")
		window:Destroy()
	end))

	-- Main and minimized window dragging use one coordinate space (InputObject.Position)
	-- so pressing the header never causes the old inset-related jump.
	window._maid:Give(UserInputService.InputBegan:Connect(function(input)
		if window._destroyed then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local start = Vector2.new(input.Position.X, input.Position.Y)

		if window._minimized and miniBar.Visible and pointInside(miniBar, start) then
			if pointInside(restoreButton, start) or pointInside(miniCloseButton, start) then
				return
			end
			local startPosition = miniBar.Position
			self:_beginDrag(function(movePosition)
				local current = Vector2.new(movePosition.X, movePosition.Y)
				local delta = current - start
				miniBar.Position = offsetUDim2(startPosition, roundPixel(delta.X), roundPixel(delta.Y))
			end, function()
				window:_clampToViewport(miniBar)
			end)
			return
		end

		if window._minimized or window._maximized or not shell.Visible or not pointInside(header, start) then
			return
		end
		if pointInside(controlsHost, start) or pointInside(searchButton, start) or (commandButton and pointInside(commandButton, start)) then
			return
		end
		if window._subtabUsedWidth > 0 then
			local subtabPosition = subtabHost.AbsolutePosition
			local subtabSize = subtabHost.AbsoluteSize
			if start.X >= subtabPosition.X
				and start.X <= subtabPosition.X + math.min(window._subtabUsedWidth, subtabSize.X)
				and start.Y >= subtabPosition.Y
				and start.Y <= subtabPosition.Y + subtabSize.Y
			then
				return
			end
		end

		local startPosition = shell.Position
		self._overlay:Close("window-drag")
		self:_beginDrag(function(movePosition)
			local current = Vector2.new(movePosition.X, movePosition.Y)
			local delta = current - start
			shell.Position = offsetUDim2(startPosition, roundPixel(delta.X), roundPixel(delta.Y))
		end, function()
			window:_clampToViewport(shell)
		end)
	end))

	window._maid:Give(self._root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		window:_updateResponsive()
	end))

	window:_updateResponsive()
	table.insert(self.Windows, window)
	self._maid:Give(window)
	return window
end

-- Public API aliases kept intentionally small and semantic.
Window.AddCategory = Window.AddPage
Page.AddGroup = Page.AddSubpage
Subpage.AddGroup = Subpage.AddSection

function LunkaraUI:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	self:_endDrag()
	if self._overlay then
		self._overlay:Close("destroy")
	end
	self._maid:Cleanup()
end

return LunkaraUI
