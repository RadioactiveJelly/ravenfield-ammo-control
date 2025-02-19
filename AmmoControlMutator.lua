-- Register the behaviour
behaviour("AmmoControlMutator")

function AmmoControlMutator:Start()
	local mainObject = GameObject.Instantiate(self.targets.MainBehaviour)

	local generalSettings = {}

	generalSettings.extraPrimaryAmmo = self.script.mutator.GetConfigurationInt("primaryAmmo")
	generalSettings.extraSecondaryAmmo = self.script.mutator.GetConfigurationInt("secondaryAmmo")
	generalSettings.extraSmallGear = self.script.mutator.GetConfigurationInt("smallGear")
	generalSettings.extraLargeGear = self.script.mutator.GetConfigurationInt("largeGear")

	directSettings = {}
	table.insert(directSettings,self.script.mutator.GetConfigurationString("line1"))
	table.insert(directSettings,self.script.mutator.GetConfigurationString("line2"))
	table.insert(directSettings,self.script.mutator.GetConfigurationString("line3"))
	table.insert(directSettings,self.script.mutator.GetConfigurationString("line4"))
	table.insert(directSettings,self.script.mutator.GetConfigurationString("line5"))

	local mainBehaviour = mainObject.GetComponent(AmmoControl)
	mainBehaviour:SetGeneralSettings(generalSettings)
	mainBehaviour:SetDirectSettings(directSettings)
	mainBehaviour.useBoth = self.script.mutator.GetConfigurationBool("CombineSettings")
	mainBehaviour:Init()
end