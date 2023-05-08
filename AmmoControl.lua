-- Register the behaviour
behaviour("AmmoControl")

function AmmoControl:Awake()
	self.gameObject.name = "AmmoControl"
end

function AmmoControl:Start()
	-- Run when behaviour is created
	GameEvents.onActorSpawn.AddListener(self,"onActorSpawn")

	self.extraPrimaryAmmo = self.script.mutator.GetConfigurationInt("primaryAmmo")
	self.extraSecondaryAmmo = self.script.mutator.GetConfigurationInt("secondaryAmmo")
	self.extraSmallGear = self.script.mutator.GetConfigurationInt("smallGear")
	self.extraLargeGear = self.script.mutator.GetConfigurationInt("largeGear")
	
	self.script.StartCoroutine(self:FindLoadoutChanger())
	self.doOnce = false

	self:Debug("Initialized version 1.0.1")

	local scavengerObj = self.gameObject.Find("Scavenger")
	if scavengerObj then
		self.scavenger = scavengerObj.GetComponent(ScriptedBehaviour)
	end

	self.ammoData = {}

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

	self:ParseString(self.script.mutator.GetConfigurationString("line1"))
	self:ParseString(self.script.mutator.GetConfigurationString("line2"))
	self:ParseString(self.script.mutator.GetConfigurationString("line3"))
	self:ParseString(self.script.mutator.GetConfigurationString("line4"))
	self:ParseString(self.script.mutator.GetConfigurationString("line5"))

	self.useBoth = self.script.mutator.GetConfigurationBool("CombineSettings")
end

function AmmoControl:ParseString(str)
	for word in string.gmatch(str, '([^,]+)') do
		local iterations = 0
		local name = ""
		local maxAmmo = nil
		local maxSpareAmmo = nil
		for wrd in string.gmatch(word,'([^|]+)') do
			if wrd ~= "-" then
				if iterations == 0 then name = wrd end
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
		self.ammoData[name] = data

		--self:Debug("Registered " .. name .. " with mag size of " .. maxAmmo .. " and max spare ammo of " .. maxSpareAmmo)
	end
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
	local data = self.ammoData[weapon.weaponEntry.name]
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
