local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local TweenService = game:GetService('TweenService')
local SoundService = game:GetService('SoundService')

local Stack = require(ReplicatedStorage.Library.Utility.Stack)
local Queue = require(ReplicatedStorage.Library.Utility.Queue)
local Knit = require(ReplicatedStorage.Library.Knit.Packages.Knit)
local NPC_Object = require(script.NPC_ClientObject)
local GUI = ReplicatedStorage.Assets.GUI

local NpcController =  Knit.CreateController { Name = "NPC_Controller",
												NPC_List = {}}

local Player = Players.LocalPlayer

local NpcService, GuiController

function NpcController:KnitInit()
	NpcService = Knit.GetService("NpcService")
	GuiController = Knit.GetController("GuiController")

	local containerStack = Stack.new()
	NpcService.CreateEnemies:Connect(function(tag, amount, isAfter, ...)
		--AttackRanges: {IntValue}, AttackType, WalkSpeed, Params
		local args = {...}

		-- first signal indicates we have finished creating server containers
		if not tag then
			-- "Creating the container stack"
			for _, container in workspace.Enemies:GetChildren() do
				containerStack:push(container)
			end
		else
			-- Popping the stack to spawn all enemies
			for i=1, amount, 1 do
				local container: Folder = containerStack:pop()
				
				coroutine.wrap(function()
					
					local isAfter = isAfter
					local Name = tag
					
					local Type, AttackRanges, WalkSpeed, MonsterCat, Params = unpack(args)	
					local enemy = NPC_Object.new(Name, Type,
						AttackRanges, WalkSpeed, MonsterCat, container, Params, isAfter)
					--[[
					Creates an enemy client object, which will be parented to its corr
					serverContainer. If isAfter is true, then it will yield 
					until a positional change is detected		
					]]
					
					local hp_progress, hp_max = self:CreateStats(enemy)
					enemy:Config(hp_progress, hp_max)
					--enemy:ActivateEyesight()
					table.insert(self.NPC_List, enemy)	
				end)()
	
			end
			
			if containerStack:isEmpty() then print("ALL ENEMIES HAVE SPAWNED") end
		end


	end)

	
	

end

function NpcController:KnitStart()
	
end



function NpcController:CreateStats(enemy)
	
	local level = NpcService.EnemyLevel:Get()
	local HP_Progress, HP_Max
	
	if enemy.Category == "Normal" then
		local topPoint = enemy.Size.Y  

		local HealthGui = GUI.HealthGui:Clone()
		local HealthBase = HealthGui.HealthBase

		HealthGui.StudsOffsetWorldSpace = Vector3.new(0, topPoint + 1, 0)
		HealthGui.Size = UDim2.fromScale(enemy.Size.X, enemy.Size.X/4.98)
		HealthGui.MaxDistance = enemy.PursueRadius * 1.5
		HealthGui.Adornee = enemy.Model.PrimaryPart
		HealthGui.Parent = enemy.Model
		
		---- these are number values
		HP_Progress, HP_Max = GuiController:AttachProgressBar(
			HealthBase, HealthBase.HealthClip, HealthBase.HealthClip.HealthBar, 
			HealthBase.Percentage, "Percentage")


		HealthGui.LevelBase.LevelImage.Level.Text = level
	else
		local BossFrame = ReplicatedStorage.Assets.GUI.BossFrame:Clone()
		BossFrame.Parent = Player.PlayerGui.BossGui.FrameContainer
		BossFrame.Visible = false

		if enemy.Params.Category == "Boss" then BossFrame.TopIcon.Image = "rbxassetid://18712712864"
		elseif enemy.Params.Category == "Miniboss" then BossFrame.TopIcon.Image = "rbxassetid://136187840300437" end
		
		local BossBase = BossFrame.BossBase
		
		HP_Progress, HP_Max = GuiController:AttachProgressBar(
			BossBase, BossBase.BossClip, BossBase.BossClip.BossBar, 
			BossBase.Percentage, "Ratio")
		
		BossBase.LevelBase.LevelImage.Level.Text = level
		enemy._bossFrame = BossFrame
	end
	
	return HP_Progress, HP_Max
end







return NpcController
