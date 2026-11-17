-- luacheck: read globals scenario
-- Ownership models only, never load downloaded companion code. Sources are the Interface 16001 releases:
-- Plater v664-Forever (CurseForge 100547, file 9628184):
-- Plater.lua:2936-2941 creates plate.unitFrame (distinct from plate.UnitFrame),
-- :3904-3908 suppresses Blizzard and shows its own frame, :4628-4670 hides an unprotected UnitFrame,
-- :6704/:7787 colours its fill/name, :9539-9540 textures/colours healthBar.background.
-- Threat Plates 13.3.8 (CurseForge 21217, file 9526802):
-- Nameplate.lua:897-918 suppresses Blizzard (Hide for an unprotected frame),
-- :1023-1054 reanchors on every pooled acquire, :1092 creates plate.TPFrame; Elements/Healthbar.lua:
-- :381-393 creates its own bar/Background, :353-359 colours them, :520-521 positions from the profile;
-- Elements/Name.lua:128 colours its own name. Neither build writes the global TargetFrame.
-- Both have a protected-frame detach path too; this model covers their unprotected Hide path.
-- Companion bars sit centred on the plate. Layout is printed for reference only: shipped profiles are
-- player-configurable, so this scenario proves ownership, not where a given profile draws its bar.

local methods = {
	"SetVertexColor",
	"SetColorTexture",
	"SetTexture",
	"SetAtlas",
	"SetStatusBarColor",
	"SetTextColor",
	"SetAlpha",
	"Hide",
	"Show",
	"SetPoint",
}

-- Watch every pre-existing client/companion widget, including the target fixture's descendants.
-- Stack attribution lets Blizzard and the model update their own widgets while catching FGF's writes, even
-- through a native helper (SetStatusBarColor -> SetVertexColor). Record instead of throwing: SafeCall catches errors.
local function watchForeign(sim)
	local writes = {}
	for _, region in ipairs(sim.widgets.all) do
		for _, method in ipairs(methods) do
			local original = region[method]
			if type(original) == "function" then
				region[method] = function(self, ...)
					local level = 2
					while true do
						local info = debug.getinfo(level, "S")
						if not info then
							break
						end
						if info.source:find("@FieldGuideForever/", 1, true) == 1 then
							writes[#writes + 1] = (self:GetName() or self:GetObjectType()) .. ":" .. method
							break
						end
						level = level + 1
					end
					return original(self, ...)
				end
			end
		end
	end
	return function()
		assert(#writes == 0, "FGF wrote foreign regions: " .. table.concat(writes, ", "))
	end
end

local function frame(G, parent, width, height, x, y, kind)
	local result = G.CreateFrame(kind or "Frame", nil, parent)
	result:SetSize(width, height)
	result:SetPoint("CENTER", parent, "CENTER", x or 0, y or 0)
	return result
end

local function unitFrame(G, parent, width, height, x, y)
	local result = frame(G, parent, width, height, x, y)
	result.healthBar = frame(G, result, width, height, 0, 0, "StatusBar")
	result.healthBar:SetStatusBarTexture("Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
	result.healthBar.bgTexture = result.healthBar:CreateTexture(nil, "BACKGROUND")
	result.healthBar.bgTexture:SetAllPoints(result.healthBar)
	result.name = result:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	return result
end

local function guidFor(ns, tier)
	for index = 1, 100000 do
		local guid = string.format("Creature-0-1-0-1-1001-%010X", index)
		if ns.Model.SpawnTier(guid) == tier then
			return guid
		end
	end
	error("no fixture GUID for " .. tier)
end

local function rect(sim, region)
	local r = assert(sim.widgets.rect(region), "no layout rectangle")
	return string.format("(%.1f,%.1f,%.1f,%.1f)", unpack(r))
end

for _, companion in ipairs({ "stock", "Plater-like", "Threat-Plates-like" }) do
	scenario("rarity companion ownership: " .. companion, function(sim)
		dofile("tests/sim/forever_core.lua").install(sim)
		sim:login()
		sim:setGamepad(true)
		local G = sim.G
		local ns = sim.loader.addons.FieldGuideForever.ns
		-- A scenario catalogue exercises the production lookup and sightings path, without a preview-tier override.
		local species = { id = 1001, name = "Companion fixture", minLevel = 1, maxLevel = 1 }
		local zone = { id = 1454, name = "Orgrimmar", species = { species } }
		ns.Zones = { zone }
		ns.BuildCatalogue()
		sim.impl.GetZoneText = function()
			return zone.name
		end
		local rare = { name = species.name, guid = guidFor(ns, "silver"), level = 1 }
		local common = { name = species.name, guid = guidFor(ns, "bronze"), level = 1 }

		-- The sim has no nameplate native/driver. Supply only the native lookup and a client-shaped region tree;
		-- use its existing world unit reads, widgets and real event dispatch. No vendored simulator code changes.
		local plate = frame(G, G.UIParent, 160, 40, 0, 0)
		plate.UnitFrame = unitFrame(G, plate, 110, 12, 0, 0)
		local blizzard = plate.UnitFrame
		blizzard.AurasFrame = frame(G, blizzard, 50, 25, -100, 0)
		blizzard.AurasFrame.BuffListFrame = frame(G, blizzard.AurasFrame, 50, 25, 0, 0)
		blizzard.AurasFrame:Hide()
		blizzard.AurasFrame.UpdateShownState = function() end
		blizzard.AurasFrame.RefreshAuras = function() end
		blizzard.RaidTargetFrame = frame(G, blizzard, 22, 22, 0, 0)
		blizzard.RaidTargetFrame:ClearAllPoints()
		blizzard.RaidTargetFrame:SetPoint("RIGHT", blizzard.healthBar, "LEFT")
		blizzard.ClassificationFrame = frame(G, blizzard, 20, 20, 0, 0)
		blizzard.ClassificationFrame:ClearAllPoints()
		blizzard.ClassificationFrame:SetPoint("RIGHT", blizzard.RaidTargetFrame, "LEFT")
		local visible = blizzard
		if companion == "Plater-like" then
			plate.unitFrame = unitFrame(G, plate, 160, 40, 0, 0)
			visible = plate.unitFrame
			visible.healthBar:SetSize(140, 14)
			visible.healthBar:SetPoint("CENTER", visible, "CENTER")
			visible.healthBar.background = visible.healthBar.bgTexture
			visible.healthBar.bgTexture = nil
			visible.healthBar.barTexture = visible.healthBar:GetStatusBarTexture()
			visible.unitName = visible.name
		elseif companion == "Threat-Plates-like" then
			plate.TPFrame = unitFrame(G, plate, 160, 40, 0, 0)
			plate.TPFrame:SetPoint("CENTER", blizzard, "CENTER")
			visible = plate.TPFrame
			visible.healthBar:SetSize(140, 14)
			visible.healthBar:SetPoint("CENTER", visible, "CENTER")
			visible.healthBar.Background = visible.healthBar.bgTexture
			visible.healthBar.bgTexture = nil
			visible.visual = { healthbar = visible.healthBar, NameText = visible.name }
		end
		local active
		G.C_NamePlate = {
			GetNamePlateForUnit = function(unit)
				return active == unit and plate or nil
			end,
		}
		-- TargetFrame is not booted by forever_sim either. Model its Rarity-facing regions locally, leaving
		-- the simulator's real Blizzard UI running. This proves ownership, not the native target layout.
		local target = unitFrame(G, G.UIParent, 192, 67, -300, 200)
		target.TargetFrameContainer = frame(G, target, 192, 67, 0, 0)
		local container = target.TargetFrameContainer
		container.FrameTexture = container:CreateTexture(nil, "ARTWORK")
		container.FrameTexture:SetAllPoints(container)
		container.Portrait = container:CreateTexture(nil, "ARTWORK")
		container.Portrait:SetSize(64, 64)
		container.Portrait:SetPoint("CENTER", container, "CENTER", 55, 0)
		target.healthbar = target.healthBar
		G.TargetFrame = target
		local clean = watchForeign(sim)
		local function fire(event, unit)
			sim.events.fire(event, unit)
			sim:tick(0.1)
			clean()
		end
		active = "nameplate1"
		sim.world.units[active] = rare
		fire("NAME_PLATE_UNIT_ADDED", active)
		local marker = assert(plate.FGFRarityMarker, "missing marker")
		assert(marker:IsShown() and marker:GetParent() == plate, "rare marker must belong to the plate")
		assert(ns.FindSpecies(rare.name, ns.CurrentZone()) == species, "unit must resolve in the catalogue")
		if companion ~= "stock" then
			blizzard:Hide()
			assert(marker:IsVisible(), "hiding Blizzard UnitFrame must not hide FGF's marker")
		end
		sim.world.units.target = rare
		fire("PLAYER_TARGET_CHANGED")
		assert(target.FGFRarityArt and target.FGFRarityArt.ornament:IsShown(), "rare target ornament did not show")

		-- Update both the skin's own regions and Blizzard's bgTexture while the marker is active. The latter is
		-- a deliberate competing writer probe, not a claim that either companion uses Blizzard's background.
		local function background(f)
			return f.healthBar.background or f.healthBar.Background or f.healthBar.bgTexture
		end
		local function repaint(f)
			if f.healthBar.barTexture then
				f.healthBar.barTexture:SetVertexColor(0.12, 0.34, 0.56, 1)
			else
				f.healthBar:SetStatusBarColor(0.12, 0.34, 0.56, 1)
			end
			background(f):SetTexture("Interface\\Buttons\\WHITE8X8")
			background(f):SetVertexColor(0.65, 0.43, 0.21, 1)
			f.name:SetTextColor(0.22, 0.44, 0.66, 1)
		end
		repaint(target)
		container.FrameTexture:SetVertexColor(0.65, 0.43, 0.21, 1)
		repaint(visible)
		if visible ~= blizzard then
			repaint(blizzard)
		end
		local function colour(getter, region, r, g, b)
			local actualR, actualG, actualB, actualA = getter(region)
			assert(actualR == r and actualG == g and actualB == b and actualA == 1, "new colour was lost")
		end
		local function retained(f)
			colour(f.healthBar.GetStatusBarColor, f.healthBar, 0.12, 0.34, 0.56)
			colour(background(f).GetVertexColor, background(f), 0.65, 0.43, 0.21)
			assert(background(f):GetTexture() == "Interface\\Buttons\\WHITE8X8", "new texture was lost")
			colour(f.name.GetTextColor, f.name, 0.22, 0.44, 0.66)
		end
		local anchor = marker.fgfAnchor == blizzard.healthBar and "Blizzard.healthBar" or "Blizzard.ClassificationFrame"
		print(
			string.format(
				"layout %s: RIGHT -> %s.%s x=%d marker=%s visibleBar=%s",
				companion,
				anchor,
				marker.fgfRelPoint,
				marker.fgfOffsetX,
				rect(sim, marker),
				rect(sim, visible.healthBar)
			)
		)
		sim.world.units.target = nil
		fire("PLAYER_TARGET_CHANGED")
		assert(not target.FGFRarityArt.ornament:IsShown(), "target ornament did not clear")
		assert(marker:IsVisible(), "target change must preserve the rare plate marker")
		-- Native lookup may already have dropped the plate when removal arrives; FGF must use its stored plate.
		active = nil
		fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
		assert(not marker:IsShown(), "removed plate marker stayed shown")
		retained(target)
		colour(container.FrameTexture.GetVertexColor, container.FrameTexture, 0.65, 0.43, 0.21)
		retained(visible)
		retained(blizzard)
		sim.world.units.nameplate1 = nil
		active = "nameplate2"
		sim.world.units[active] = common
		fire("NAME_PLATE_UNIT_ADDED", active)
		assert(plate.FGFRarityMarker == marker and not marker:IsShown(), "reused common plate kept a rare marker")
		retained(target)
		colour(container.FrameTexture.GetVertexColor, container.FrameTexture, 0.65, 0.43, 0.21)
		retained(visible)
		retained(blizzard)
		clean()
		sim:gamepadNavigate()
		sim:bindingSetChange()
	end)
end
