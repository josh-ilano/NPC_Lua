local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService('CollectionService')
local PathfindingService = game:GetService("PathfindingService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService('SoundService')
local Players = game:GetService("Players")


local random = Random.new()

--local TeleportVFX = ReplicatedStorage.Assets.Particles.Teleport
local Player = game.Players.LocalPlayer

--local Configuration = require(Player.PlayerScripts.GUIHandler.Configuration)
local Maid = require(ReplicatedStorage.Library.Utility.Maid)
local Graphics = require(ReplicatedStorage.Library.Utility.Graphics)
--local Library = require(Utility.Library)
--local RaycastHitbox = require(Utility.RaycastHitboxV4)

local RENDER_DISTANCE = 250 -- originally 200

local NPC = {}
NPC.__index = NPC

local function stopAnims(animationDic)
	for _, animation in animationDic do
		animation:Stop()
	end
end

local function createAnim(Animator: Animator, animation)
	return Animator:LoadAnimation(animation)
end


local EnemyCollection = ReplicatedStorage.NPC.Enemies
function NPC.new(Name, Type, AttackRanges: {IntValue}, WalkSpeed, MonsterCat, ServerContainer, Params, isAfter)
	-- if isAfter is true, indicates we have to yield until next positional change
	
	local self = setmetatable({}, NPC)

	local Enemy = EnemyCollection:FindFirstChild(Name)
	local Model = Enemy:FindFirstChild("Model")[Name] -- under models, every enemy is there
	local AnimationFolder = Enemy:FindFirstChild("Animations")
	local SoundFolder = Enemy:FindFirstChild("Sound")

	self.Orientation, self.Size = Model:GetBoundingBox() -- initial properties

	self.Model = Model:Clone()	
	
	if isAfter then 
		-- TODO: Implement cases to see which position to yield to
		ServerContainer:GetAttributeChangedSignal("Position"):Wait() 
	end
	
	self.Model.PrimaryPart.Position = ServerContainer:GetAttribute("Position")
	self.Model.Parent = ReplicatedStorage.ClientModels -- initially it is in ReplicatedStorage

	self.ServerContainer = ServerContainer
	
	if((self.Model.PrimaryPart.Position - workspace.CurrentCamera.Focus.Position).Magnitude <= RENDER_DISTANCE) then
		self.Model.Parent = ServerContainer -- will be parented out if we are close enough
	end
	
	self.Type = Type -- Range, Caster, Melee

	self.PursueRadius = AttackRanges[1] -- farthest range; range needed to pursue player
	self.AttackRadius = AttackRanges[2] -- second farthest range; range needed to perform an attack on the player

	self.WalkSpeed = WalkSpeed
	self.Category = MonsterCat
	self.Params = Params

	self.Maid = Maid.new()
	self.AnimationTracks = {}
	for _, animation in AnimationFolder:GetChildren() do
		local animationTrack = createAnim(self.Model.AnimationController.Animator, animation)
		animationTrack:SetAttribute("AnimSpeed", animation:GetAttribute("AnimSpeed")) 
		-- transfer attribute onto here
		self.AnimationTracks[animation.Name] = animationTrack
	end


	self.Sounds = SoundFolder

	-- TODO: Handle Boss later
	--if self.Params.Category == "Boss" then
	--	self.AnimationTracks.Idle:Play() 
	--	self.AnimationTracks.Idle:AdjustSpeed(self.AnimationTracks.Idle:GetAttribute("AnimSpeed") or 1)
	--end

	return self
end


function NPC:Config(HP_Progress: NumberValue, HP_Max: NumberValue)
	
	-- setup health
	local progressHealth = self.ServerContainer:GetAttribute("Health")
	local maxHealth = self.ServerContainer:GetAttribute("MaxHealth")
	local level = self.ServerContainer:GetAttribute("Level") - #Players:GetPlayers()
	
	HP_Progress.Value = progressHealth
	HP_Max.Value = maxHealth
	
	local previousBehavior = self.ServerContainer:GetAttribute("Behavior") -- poss of nil
	
	local previousHealth = progressHealth
	self.ServerContainer.AttributeChanged:Connect(function(attribute: string)
		local value = self.ServerContainer:GetAttribute(attribute)
		
		if attribute:match("Position") then
			local distFromPlr = (value - workspace.CurrentCamera.Focus.Position).Magnitude
			if distFromPlr > RENDER_DISTANCE  then
				self.Model.Parent = ReplicatedStorage.ClientModels
				self.Model:MoveTo(value) -- simply teleport
			else 
				if self._bossFrame then self._bossFrame.Visible = distFromPlr <= self.PursueRadius end
				self.Model.Parent = self.ServerContainer 				
				self:MoveTween(value)  -- interpolate movement		
			end
		elseif attribute:match("Health") then
			print("Health changed")
			local healthDelta = value - previousHealth
			HP_Progress.Value = value
			Graphics:GenerateNumber(self.Model, healthDelta)
			previousHealth = value
		elseif attribute:match("MaxHealth") then
			HP_Max.Value = value
		elseif attribute:match("Animation") then	
			if value == -2 then -- We stand still
				
				if self._bossFrame then
					coroutine.wrap(function()
						while value == -2 do -- still monitor whether player is in boss distance on standstill
							local distFromPlr = (self.ServerContainer:GetAttribute("Position") - workspace.CurrentCamera.Focus.Position).Magnitude
							self._bossFrame.Visible = distFromPlr <= self.PursueRadius 
							task.wait(.5)
						end
					end)()
				end
				
				if self.AnimationTracks.Run.IsPlaying then self.AnimationTracks.Run:Stop() end
			elseif value == -1 then -- We start moving (in idle)
				self.AnimationTracks.Run:Play()
				self.AnimationTracks.Run:AdjustSpeed(
					self.AnimationTracks.Run:GetAttribute("AnimSpeed") or 1)
			elseif value == 3 then -- We start an attack
				if self.AnimationTracks.Run.IsPlaying then self.AnimationTracks.Run:Stop() end
				self.AnimationTracks.Attack:Play()
			end
			
			previousBehavior = value
		end
	end)
	
	
	-- play idle animation on start
	self.AnimationTracks.Run.Priority = Enum.AnimationPriority.Movement
	self.AnimationTracks.Idle.Priority = Enum.AnimationPriority.Idle
	self.AnimationTracks.Idle:Play()
	self.AnimationTracks.Idle:AdjustSpeed(self.AnimationTracks.Idle:GetAttribute("AnimSpeed") or 1)
	
end


-- Moves an npc with tween
function NPC:MoveTween(destination: Vector3)

	if destination then
		local PrimaryPart = self.Model.PrimaryPart
		local start = PrimaryPart.Position

		local destination_cframe 
		
		local plr: Player = self.ServerContainer.Player.Value
		if plr then -- go to the destination while looking at player
			destination_cframe = CFrame.lookAlong(destination, (plr.Character.PrimaryPart.Position-start).Unit)
		else
			destination_cframe = CFrame.lookAlong(destination, (destination-start).Unit)
		end

	
		local x, y, z = destination_cframe:ToOrientation()
		local t = (start-destination).Magnitude / self.WalkSpeed

		-- current way of handling any 'off' teleportation

		local offset = CFrame.new()
		if self.Params.Backwards then offset *= CFrame.Angles(0, math.pi, 0) end

		local MoveTween = TweenService:Create(PrimaryPart, TweenInfo.new(t), 
			{CFrame = CFrame.new(destination_cframe.Position) * CFrame.Angles(0,y,0) * offset})
		MoveTween:Play()	

	end

end


return NPC

