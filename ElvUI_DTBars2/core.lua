local E, L, V, P, G = unpack(ElvUI);
local AddOnName, Engine = ...

local DT = E:GetModule('DataTexts')
local DB = E:NewModule('DTBars2', 'AceTimer-3.0', 'AceHook-3.0', 'AceEvent-3.0')

local _G = _G
local ACCEPT, CANCEL = ACCEPT, CANCEL
local pairs, tinsert, type, error, format, collectgarbage = pairs, tinsert, type, error, format, collectgarbage
local tcopy = table.copy
local IsInInstance = IsInInstance
local ReloadUI = ReloadUI
local InCombatLockdown = InCombatLockdown
local UnitInVehicle = UnitInVehicle

P['dtbars'] = {}
G['dtbars'] = {}
G['dtbarsSetup'] = {
	['advanced'] = false,
	['name'] = "",
	['anchor'] = "CENTER",
	['point'] = "CENTER",
	['x'] = 0,
	['y'] = 0,
	['slots'] = 3,
	['growth'] = 'HORIZONTAL',
	['width'] = 300,
	['height'] = 22,
	['strata'] = "LOW",
	['transparent'] = false,
	['hide'] = false,
	['mouseover'] = false,
	['combatHide'] = false,
	['vehicleHide'] = false,
	['border'] = true,
}

--Rearranging pointLoc indexes cause 2 point DT panel looks weird with point being called 'middle'
DT.PointLocation = {}

for i = 1, 9 do
	DT.PointLocation[i] = 'slot' .. i
end

DB.DefaultPanel = {
	['enable'] = true,
	['growth'] = 'HORIZONTAL',
	['width'] = 300,
	['height'] = 22,
	['transparent'] = false,
	['mouseover'] = false,
	['combatHide'] = false,
	['vehicleHide'] = false,
	['border'] = true,
}


E.PopupDialogs["DT_Slot_Changed"] = {
	button1 = ACCEPT,
	button2 = CANCEL,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = false,
}

E.PopupDialogs["DT_Panel_Add"] = {
	text = L["Are you sure you want to create a panel with those parameters?\nThis action will require a reload."],
	button1 = ACCEPT,
	button2 = CANCEL,
	OnAccept = function()
		local s = E.global.dtbarsSetup; DB:InsertPanel(s.name, s.slots, s.growth, s.width, s.transparent, s.anchor,
			s.point, s.x, s.y, s.strata, s.hide, s.border); ReloadUI()
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = false,
}

E.PopupDialogs["DT_Panel_Delete"] = {
	text = L["Deleting the panel will erase all it's setting and you'll not be able to restore them. Continue?"],
	button1 = ACCEPT,
	button2 = CANCEL,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = false,
}

local function Bar_OnEnter(self)
	if E.db.dtbars[self.Name].mouseover then
		E:UIFrameFadeIn(self, 0.2, self:GetAlpha(), 1)
	end
end

local function Button_OnEnter(self)
	local bar = self:GetParent()
	if E.db.dtbars[bar.Name].mouseover then
		E:UIFrameFadeIn(bar, 0.2, bar:GetAlpha(), 1)
	end
end

local function Bar_OnLeave(self)
	if E.db.dtbars[self.Name].mouseover then
		E:UIFrameFadeOut(self, 0.2, self:GetAlpha(), 0)
	end
end

local function Button_OnLeave(self)
	local bar = self:GetParent()
	if E.db.dtbars[bar.Name].mouseover then
		E:UIFrameFadeOut(bar, 0.2, bar:GetAlpha(), 0)
	end
end

--overwrite of ElvUI's functions since I can't really hook to them
function DT:RegisterPanel(panel, numPoints, anchor, xOff, yOff)
	DT.RegisteredPanels[panel:GetName()] = panel
	panel.dataPanels = {}
	panel.numPoints = numPoints

	panel.xOff = xOff
	panel.yOff = yOff
	panel.anchor = anchor
	for i = 1, numPoints do
		local pointIndex = 'slot' .. i
		if not panel.dataPanels[pointIndex] then
			panel.dataPanels[pointIndex] = CreateFrame('Button', 'DataText' .. i, panel)
			panel.dataPanels[pointIndex]:RegisterForClicks("AnyUp")
			panel.dataPanels[pointIndex].text = panel.dataPanels[pointIndex]:CreateFontString(nil, 'OVERLAY')
			panel.dataPanels[pointIndex].text:SetAllPoints()
			panel.dataPanels[pointIndex].text:FontTemplate()
			panel.dataPanels[pointIndex].text:SetJustifyH("CENTER")
			panel.dataPanels[pointIndex].text:SetJustifyV("MIDDLE")
		end

		panel.dataPanels[pointIndex]:Point(DT:GetDataPanelPoint(panel, i, numPoints))
	end

	panel:SetScript('OnSizeChanged', DT.UpdateAllDimensions)
	DT.UpdateAllDimensions(panel)
end

function DT:UpdateAllDimensions()
	for panelName, panel in pairs(DT.RegisteredPanels) do
		local vert = false
		if E.global.dtbars and E.global.dtbars[panelName] then
			if not E.db.dtbars[panelName] then DB:ProfileHandle(panelName, E.global.dtbars[panelName]) end
			vert = E.db.dtbars[panelName].growth == "VERTICAL" and true or false
		end
		local width = vert and panel:GetWidth() - 4 or (panel:GetWidth() / panel.numPoints) - 4
		local height = vert and (panel:GetHeight() / panel.numPoints) - 4 or panel:GetHeight() - 4
		for i = 1, panel.numPoints do
			local pointIndex = 'slot' .. i
			panel.dataPanels[pointIndex]:Width(width)
			panel.dataPanels[pointIndex]:Height(height)
			panel.dataPanels[pointIndex]:ClearAllPoints()
			panel.dataPanels[pointIndex]:Point(DT:GetDataPanelPoint(panel, i, panel.numPoints))
		end
	end
end

function DT:GetDataPanelPoint(panel, i, numPoints)
	local name = panel:GetName()
	local vert = false
	if E.global.dtbars and E.global.dtbars[name] then
		vert = E.db.dtbars[name].growth == "VERTICAL"
	end

	if numPoints >= 1 then
		local point, relativeTo, relativePoint, x, y
		if vert then
			point = "TOP"
			relativeTo = panel
			relativePoint = "TOP"
			x = 0
			y = -((i - 1) * (panel:GetHeight() / numPoints))
		else
			point = "LEFT"
			relativeTo = panel
			relativePoint = "LEFT"
			x = ((i - 1) * (panel:GetWidth() / numPoints))
			y = 0
		end
		return point, relativeTo, relativePoint, x, y
	else
	end
end

local LDB = LibStub:GetLibrary("LibDataBroker-1.1");
local LSM = LibStub("LibSharedMedia-3.0")

function DT:LoadDataTexts()
	LDB:UnregisterAllCallbacks(self)

	local fontTemplate = LSM:Fetch("font", self.db.font)
	local enableBGPanel = self.isInPVP and not self.ForceHideBGStats and self.db.battleground
	local pointIndex, showBGPanel

	if ElvConfigToggle then
		ElvConfigToggle.text:FontTemplate(fontTemplate, self.db.fontSize, self.db.fontOutline)
	end

	for panelName, panel in pairs(DT.RegisteredPanels) do
		showBGPanel = enableBGPanel and (panelName == "LeftChatDataPanel" or panelName == "RightChatDataPanel")

		--Restore Panels
		for i = 1, panel.numPoints do
			local pointIndex = 'slot' .. i
			panel.dataPanels[pointIndex]:UnregisterAllEvents()
			panel.dataPanels[pointIndex]:SetScript("OnUpdate", nil)
			panel.dataPanels[pointIndex]:SetScript("OnEnter", nil)
			panel.dataPanels[pointIndex]:SetScript("OnLeave", nil)
			panel.dataPanels[pointIndex]:SetScript("OnClick", nil)
			panel.dataPanels[pointIndex].text:FontTemplate(fontTemplate, self.db.fontSize, self.db.fontOutline)
			panel.dataPanels[pointIndex].text:SetWordWrap(self.db.wordWrap)
			panel.dataPanels[pointIndex].text:SetText(nil)
			panel.dataPanels[pointIndex].pointIndex = pointIndex

			if showBGPanel then
				panel.dataPanels[pointIndex]:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
				panel.dataPanels[pointIndex]:SetScript("OnEvent", DT.UPDATE_BATTLEFIELD_SCORE)
				panel.dataPanels[pointIndex]:SetScript("OnEnter", DT.BattlegroundStats)
				panel.dataPanels[pointIndex]:SetScript("OnLeave", DT.Data_OnLeave)
				panel.dataPanels[pointIndex]:SetScript("OnClick", DT.HideBattlegroundTexts)
				DT.UPDATE_BATTLEFIELD_SCORE(panel.dataPanels[pointIndex])
			else
				for name, data in pairs(DT.RegisteredDataTexts) do
					for option, value in pairs(self.db.panels) do
						if value and type(value) == "table" then
							if option == panelName and self.db.panels[option][pointIndex] and self.db.panels[option][pointIndex] == name then
								DT:AssignPanelToDataText(panel.dataPanels[pointIndex], data)
							end
						elseif value and type(value) == "string" and value == name then
							if option == panelName then
								DT:AssignPanelToDataText(panel.dataPanels[pointIndex], data)
							end
						end
					end
				end				
			end
			if E.global.dtbars and E.global.dtbars[panelName] then
				panel.dataPanels[pointIndex]:HookScript("OnEnter", Button_OnEnter)
				panel.dataPanels[pointIndex]:HookScript("OnLeave", Button_OnLeave)
			end
		end
	end

	if DT.ForceHideBGStats then
		DT.ForceHideBGStats = nil
	end
end

function DB:ProfileHandle(name, data)
	if not E.db.dtbars then E.db.dtbars = {} end
	if not E.db.dtbars[name] then E.db.dtbars[name] = CopyTable(DB.DefaultPanel) end
	if not E.db.dtbars[name].height then E.db.dtbars[name].height = 22 end

	if not P.datatexts.panels[name] then P.datatexts.panels[name] = {} end
	if not E.db.datatexts.panels[name] then E.db.datatexts.panels[name] = {} end

	for i = 1, data.slots do
		local slotName = 'slot' .. i
		if slotName then
			if not P.datatexts.panels[name][slotName] then P.datatexts.panels[name][slotName] = "" end
			if not E.db.datatexts.panels[name][slotName] then E.db.datatexts.panels[name][slotName] = "" end
		end
	end
end

function DB:InsertPanel(name, slots, growth, width, transparent, anchor, point, x, y, strata, hide, border)
	if name == "" then return end
	name = "DTB2_" .. name
	if not E.global.dtbars[name] then
		E.global.dtbars[name] = {
			['anchor'] = anchor,
			['point'] = point,
			['slots'] = slots,
			['strata'] = strata,
			['hide'] = hide,
		}
		--insert profile based data of the panel to every existing profile
		for profile, data in pairs(ElvDB.profiles) do
			if not data.dtbars then data.dtbars = {} end
			if not data.dtbars[name] then
				data.dtbars[name] = {
					['enable'] = true,
					['growth'] = growth,
					['width'] = width,
					['transparent'] = transparent,
					['border'] = border,
				}
			end
		end
	else
		error(format(L["Panel with the name %s already exist. Please choose another one."], name))
	end
end

function DB:DeletePanel(name)
	if E.global.dtbars[name] then
		E.global.dtbars[name] = nil
		--remove profile based data of the panel from every existing profile
		for profile, data in pairs(ElvDB.profiles) do
			if data.dtbars and data.dtbars[name] then data.dtbars[name] = nil end
			if data.datatexts and data.datatexts.panels[name] then data.datatexts.panels[name] = nil end
			if data.movers and data.movers[name .. "_Mover"] then data.movers[name .. "_Mover"] = nil end
		end
	end
	ReloadUI()
end

function DB:ChangeSlots(panel)
	for profile, data in pairs(ElvDB.profiles) do
		if (data.datatexts and data.datatexts.panels) and data.datatexts.panels[panel] then data.datatexts.panels[panel] = nil end
	end
	ReloadUI()
end

function DB:Resize()
	if not E.db.dtbars then E.db.dtbars = {} end
	for name, data in pairs(E.global.dtbars) do
		if name and _G[name] then
			local db = E.db.dtbars[name]
			if not db.width and not db.height then return end
			local height = db.height * (db.growth == "VERTICAL" and data.slots or 1)
			_G[name]:SetSize(db.width, height)
		end
	end
	DT:UpdateAllDimensions()
end

function DB:ExtraDataBarSetup()
	for name, data in pairs(E.global.dtbars) do
		if name then
			local db = E.db.dtbars[name]
			if db.enable then
				_G[name]:Show()
				if E.db.dtbars[name].mouseover then Bar_OnLeave(_G[name]) end
				E:EnableMover(_G[name].mover:GetName())
			else
				_G[name]:Hide()
				E:DisableMover(_G[name].mover:GetName())
			end
			if not E.global.dtbars[name].hide then
				if db.transparent then
					_G[name]:SetTemplate("Transparent")
				else
					_G[name]:SetTemplate("Default", true)
				end
			end
		end
	end
end

function DB:OnEvent(event, unit)
	if unit and unit ~= "player" then return end

	if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
		self:UpdateVisibility()
	elseif event == "UNIT_ENTERING_VEHICLE" or event == "UNIT_EXITING_VEHICLE" then
		self:UpdateVisibility()
	end
end

function DB:UpdateVisibility()
	local inCombat = InCombatLockdown()
	local inVehicle = UnitInVehicle("player")
	for name, _ in pairs(E.global.dtbars) do
		if name then
			local db = E.db.dtbars[name]
			if (inCombat and db.combatHide) or (inVehicle and db.vehicleHide) then
				_G[name]:Hide()
			else
				_G[name]:Show()
			end
		end
	end
end

function DB:MoverCreation()
	if not E.db.dtbars then E.db.dtbars = {} end
	for name, data in pairs(E.global.dtbars) do
		if name and not _G[name .. "_Mover"] then
			E:CreateMover(_G[name], name .. "_Mover", name, nil, nil, nil, "ALL,MISC,DTBars")
		end
	end
end

function DB:MouseOver()
	for name, data in pairs(E.global.dtbars) do
		if name and _G[name] then
			local db = E.db.dtbars[name]
			if E.db.dtbars[name].mouseover then
				_G[name]:SetAlpha(0)
			else
				_G[name]:SetAlpha(1)
			end
		end
	end
end

function DB:CreateFrames()
	if not E.db.dtbars then E.db.dtbars = {} end
	for name, data in pairs(E.global.dtbars) do
		if name and not _G[name] then
			self:ProfileHandle(name, data)
			local db = E.db.dtbars[name]
			local bar = CreateFrame("Frame", name, E.UIParent)
			bar:SetFrameStrata(data.strata or "LOW")
			bar:SetPoint(data.point or "CENTER", E.UIParent, data.anchor or "CENTER", data.x or 0, data.y or 0)
			DT:RegisterPanel(bar, data.slots or 3, 'ANCHOR_BOTTOM', 0, -4)
			bar.Name = name
			bar:Hide()

			if not data.hide then
				if db.transparent then
					bar:SetTemplate("Transparent")
				else
					bar:SetTemplate("Default", true)
				end
			end

			if db.mouseover then
				bar:SetAlpha(0)
				bar:SetScript("OnEnter", Bar_OnEnter)
				bar:SetScript("OnLeave", Bar_OnLeave)
			end
		end
	end
end

function DB:Update()
	for name, data in pairs(E.global.dtbars) do
		DB:ProfileHandle(name, data)
	end

	DB:ExtraDataBarSetup()
	DB:Resize()
	DB:MouseOver()
end

function DB:Initialize()
	tinsert(E.ConfigModeLayouts, #(E.ConfigModeLayouts) + 1, "DTBars")
	E.ConfigModeLocalizedStrings["DTBars"] = "DTBars"
	DB:CreateFrames()
	DB:Resize()
	DB:MoverCreation()
	DB:ExtraDataBarSetup()
	DB:MouseOver()
	hooksecurefunc(E, "UpdateAll", DB.Update)
	DB:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEvent")
	DB:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
	DB:RegisterEvent("UNIT_ENTERING_VEHICLE", "OnEvent")
	DB:RegisterEvent("UNIT_EXITING_VEHICLE", "OnEvent")
	DT:LoadDataTexts()
	LibStub("LibElvUIPlugin-1.0"):RegisterPlugin(AddOnName, DB.GetOptions)
end

local function InitializeCallback()
	DB:Initialize()
end

E:RegisterModule(DB:GetName(), InitializeCallback)
