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
