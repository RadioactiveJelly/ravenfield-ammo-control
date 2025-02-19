-- Register the behaviour
behaviour("AmmoControl")

function AmmoControl:Awake()
	self.gameObject.name = "AmmoControl"
end

function AmmoControl:Init()
	-- Run when behaviour is created
	GameEvents.onActorSpawn.AddListener(self,"onActorSpawn")
	
	self.script.StartCoroutine(self:FindLoadoutChanger())
	self.doOnce = false

	self:Debug("Initialized version 1.0.1")

	local scavengerObj = self.gameObject.Find("Scavenger")
	if scavengerObj then
		self.scavenger = scavengerObj.GetComponent(ScriptedBehaviour)
	end

	local weaponPickup = self.gameObject.Find("[LQS]WeaponPickup(Clone)")
	if weaponPickup then
		self.weaponPickup = weaponPickup.GetComponent(ScriptedBehaviour)
		if self.weaponPickup.self.onWeaponPickUpListeners then
			local function onWeaponPickup(weapon)
				self:EvaluateWeapon(weapon,false)
			end
			self.weaponPickup.self:AddOnWeaponPickupListener("AmmoControl", onWeaponPickup)
		end
	end
end

function AmmoControl:SetGeneralSettings(generalSettings)
	self.extraPrimaryAmmo = generalSettings.extraPrimaryAmmo
	self.extraSecondaryAmmo = generalSettings.extraSecondaryAmmo
	self.extraSmallGear = generalSettings.extraSmallGear
	self.extraLargeGear = generalSettings.extraLargeGear
end

function AmmoControl:SetDirectSettings(directSettings)
	self.ammoData = {}
	for i = 1, #directSettings, 1 do
		self:ParseString(directSettings[i])
	end
end

function AmmoControl:DefaultSettings()
	self.extraPrimaryAmmo = 0
	self.extraSecondaryAmmo = 0
	self.extraSmallGear = 0
	self.extraLargeGear = 0

	self.ammoData = {}
	self.useBoth = true
end

--Parse string lines for weapon data
function AmmoControl:ParseString(str)
	for word in string.gmatch(str, '([^,]+)') do
		local iterations = 0
		local name = ""
		local maxAmmo = nil
		local maxSpareAmmo = nil
		for wrd in string.gmatch(word,'([^|]+)') do
			if wrd ~= "-" then
				if iterations == 0 then
					--name = string.gsub(wrd,"<.->","")
					name = wrd
				end
				if iterations == 1 then 
					if wrd == "∞" then maxAmmo = 9999999999
					else maxAmmo = tonumber(wrd) end
				end
				if iterations == 2 then 
					if wrd == "∞" then maxSpareAmmo = 9999999999
					else maxSpareAmmo = tonumber(wrd) end
				end
			end
			iterations = iterations + 1
			if(iterations >= 3) then break end
		end
		local data = {}
		data.maxAmmo = maxAmmo
		data.maxSpareAmmo = maxSpareAmmo
		self.ammoData[string.upper(name)] = data
	end
end

function AmmoControl:AddData(weaponName, data)
	self.ammoData[string.upper(weaponName)] = data
end

function AmmoControl:BlackListWeapon(weaponName)
	local cleanName = string.gsub(weaponName,"<.->","")

	if self.blacklist == nil then
		self.blacklist = {}
	end

	self.blacklist[string.upper(cleanName)] = true
end

function AmmoControl:IsWeaponBlacklisted(weaponName)
	local cleanName = string.gsub(weaponName,"<.->","")

	if self.blacklist == nil then
		self.blacklist = {}
	end

	local result = self.blacklist[string.upper(cleanName)]
	if result == nil then return false end

	return result
end

function AmmoControl:onActorSpawn(actor)
	if actor.isPlayer then
		self:EvaluateLoadout()
	end
end

function AmmoControl:EvaluateLoadout()
	for i, weapon in pairs(Player.actor.weaponSlots) do
		self:EvaluateWeapon(weapon,true)
	end
end

function AmmoControl:EvaluateWeapon(weapon, new)
	local cleanName = string.gsub(weapon.weaponEntry.name,"<.->","")
	local data = self.ammoData[cleanName]
	if data then
		if data.maxAmmo ~= nil then
			weapon.maxAmmo = data.maxAmmo
			if new == true then weapon.ammo = weapon.maxAmmo end
		end
		
		if data.maxSpareAmmo ~= nil then
			weapon.maxSpareAmmo = data.maxSpareAmmo
		end

		if self.useBoth then
			self:ApplyGeneralControl(weapon)
		end
	else
		self:ApplyGeneralControl(weapon)
	end

	--Only touch the spare ammo if the weapon is "new". This is for Weapon Pickup compatibility.
	if new == true then
		if self.scavenger == nil or weapon.weaponEntry.slot == WeaponSlot.Gear or weapon.weaponEntry.slot == WeaponSlot.LargeGear then
			weapon.spareAmmo = weapon.maxSpareAmmo
		elseif self.scavenger then
			weapon.spareAmmo = weapon.maxSpareAmmo * self.scavenger.self.ammoScale
		end
	end

end

function AmmoControl:ApplyGeneralControl(weapon)
	local weaponEntry = weapon.weaponEntry
	if weaponEntry and self:IsWeaponBlacklisted(weaponEntry.name) then
		return
	end

	local extraAmmo = 0
	
	if weapon.weaponEntry.slot == WeaponSlot.Primary then
		extraAmmo = self.extraPrimaryAmmo
	elseif weapon.weaponEntry.slot == WeaponSlot.Secondary then
		extraAmmo = self.extraSecondaryAmmo
	elseif weapon.weaponEntry.slot == WeaponSlot.Gear then
		extraAmmo = self.extraSmallGear
	elseif weapon.weaponEntry.slot == WeaponSlot.LargeGear then
		extraAmmo = self.extraLargeGear
	end

	if weapon.maxSpareAmmo > -2 then
		if weapon.maxSpareAmmo > 0 then
			weapon.maxSpareAmmo = weapon.maxSpareAmmo + (weapon.maxAmmo * extraAmmo)
		else
			weapon.maxSpareAmmo = extraAmmo
		end
	end
end

function AmmoControl:onOverlayClicked()
	if not Player.actor.isDead then
		self.script.StartCoroutine(self:changeSpareAmmo())
	end
end

function AmmoControl:FindLoadoutChanger()
	return function()
		coroutine.yield(WaitForSeconds(0.15))
		local loadOutChangerObj = self.gameObject.Find("LoadoutChangeScript(Clone)")
		if loadOutChangerObj then
			self.loadoutChanger = loadOutChangerObj.GetComponent(ScriptedBehaviour)
			self.loadoutChanger.self.button.GetComponent(Button).onClick.AddListener(self,"onOverlayClicked")
			self:Debug("Loadout Changer mutator found.")
		else
			self:Debug("Loadout Changer mutator not found.")
		end
	end
end

function AmmoControl:changeSpareAmmo()
	return function()
        coroutine.yield(WaitForSeconds(0.15))
		self:EvaluateLoadout()
    end
end

function AmmoControl:Debug(string)
	print("<color=#F394DC>[Ammo Control] " .. string .. "</color>")
end