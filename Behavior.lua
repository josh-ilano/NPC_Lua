local ReplicatedStorage = game:GetService('ReplicatedStorage')
local PathfindingService = game:GetService('PathfindingService')
local RunService = game:GetService('RunService')
local Players = game:GetService('Players')

local Graphics = require(ReplicatedStorage.Library.Utility.Graphics)
local Silo = require(ReplicatedStorage.Library.Knit.Packages.Silo)
local NPC_Object = require(script.Parent.NpcObject)

local Behavior = {}
local random = Random.new()


local function returnValidDest(radius, position: Vector3)
	local randomPosition2D
	local destination = nil
	
	while not destination do -- keep generating random positions until we find a valid one			
		local pos_2D = Vector2.new(position.X, position.Z)
		
		randomPosition2D = Graphics:getRandomPositionIn2D(pos_2D, radius) -- 

		local randomPosition = Vector3.new(randomPosition2D.X, position.Y, randomPosition2D.Y) -- extend to 3D
		
		destination = Graphics:LocateSurface(randomPosition + (Vector3.yAxis*15), 30, "Character")
		-- see if our given destination is valid (we ignore all characters in game)

		task.wait(.25)
	end
	
	return destination
end

function NPC_Object:DetermineRender(): boolean
	
	for player, dist in self.PlayerDistances do
		if dist <= 250 then
			return true -- if ONE PLAYER IS WITHIN ENEMY, then waypath
		end
	end
	
	return false
end


function NPC_Object:FindClosestPlayer(): {}

	local min = 1000 
	local minPlayer = nil
	-- we know a player can't be this far away 

	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			local dist = (self.Position - character.PrimaryPart.Position).Magnitude
			if dist <= self.AttackRanges[1] and dist < min then
				min = dist
				minPlayer = player
			end
		end
	end
	
	return minPlayer, min
end

-- set the distances of all players
function NPC_Object:UpdateDists()

	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			self.PlayerDistances[player] = (self.Position - character.PrimaryPart.Position).Magnitude
		end
	end
end




function createPartAtPosition(position: Vector3)
	local part = Instance.new("Part")
	part.Size = Vector3.new(1, 1, 1)
	part.Position = position
	part.Anchored = true
	part.CanCollide = true
	part.BrickColor = BrickColor.new("Bright red") -- Optional color
	part.Parent = workspace
	return part
end


function NPC_Object:ReturnPath(destination)
	local resultant = Graphics:LocateSurface(self.Position + Vector3.new(0,15,0), 30, "Character")
	if resultant then self.Position = resultant end 

	local success, returned, waypoints -- under this scope
	success, returned = pcall(self.Path.ComputeAsync, self.Path,  self.Position, destination)

	if success and (self.Path.Status == Enum.PathStatus.Success) then
		
		self.ServerContainer:SetAttribute("Animation", -1) -- WALK
	 	waypoints = self.Path:GetWaypoints()
		table.remove(waypoints, 1) -- removes the beginning as it is the start

		for i, waypoint: PathWaypoint in waypoints do
			if (i+1 > #waypoints) then break end
			
			-- loops through all the waypoints, moving the npc along these tiny points
			local position = waypoint.Position
			local futurePosition = waypoints[i+1].Position
				
			--TODO: Implement concussion
			local distance; local t = 0; 
			
			if i < #waypoints then
				distance = (position - futurePosition).Magnitude	
				t = distance / self.WalkSpeed
			end

			-- if no ground position was detected, then exit out of the current path
			local p = Graphics:LocateSurface(futurePosition + Vector3.new(0,15,0), 25, "Character")
			if not p then break end 
	
			-- shows waypart positions
			Graphics:VisualizePart(true , p) -- self.Params.Visualization
			
			--self.Position = p WE ONLY CHANGE ATTRIBUTE POSITION
			self.ServerContainer:SetAttribute("Position", p)
			task.wait(t)
		end
		
		self.ServerContainer:SetAttribute("Animation", -2) -- STAY
	end

	return success 
end




--[[
ReturnPath creates tiny positional movements, changing the position
attribute. Only rendered models will move according to this attribute
ReturnPath method will only work IF all players are not within render
distance
]]--
function NPC_Object:idle()

	while true do 
		local radius = math.random(20,25)
		local destination = returnValidDest(radius, self.Position) -- where to waypath to

		-- IF WE CAN'T RENDER OR WE CAN'T WAYPATH, THEN WE TELEPORT
		self.Render = self:DetermineRender()
		if not(self.Render and self:ReturnPath(destination)) then
			task.wait(radius/self.WalkSpeed) 
			self.ServerContainer:SetAttribute("Position", destination)
		end
		
		-- self.Params.Visualization
		Graphics:VisualizePart(true, destination, 2)
		
		--self.Position = destination
		task.wait(math.random(2,3))
	end

end




function NPC_Object:aggro(pathSilo)

	local player = self.Player.Value
	local wait_time = .25
	local character = player.Character

	while player == self.Player.Value and character do
		if not character.PrimaryPart then break end
		local p = character.PrimaryPart.Position
		
		pathSilo:Dispatch(pathSilo.Actions.SetPath(coroutine.create(function()
			local success = self:ReturnPath(p) 
			if not success then wait_time = 1 else wait_time = .25 end
		end)))

		task.wait(wait_time) 
	end

end

function NPC_Object:attack(pathSilo)
	--self.ServerContainer:SetAttribute("Position", self.Position)
	--self._attack = true -- runtime key to indicate we are not changing position
	
	-- terminate prior path and set a path to the most recent position
	pathSilo:Dispatch(pathSilo.Actions.SetPath(coroutine.create(function() self:ReturnPath(self.Position) end)))


	while true do
		self.ServerContainer:SetAttribute("Animation", 3) -- we send attack
		self.vision:Disconnect()
		task.wait(self.AttackSpeed + 1)
		self.ServerContainer:SetAttribute("Animation", -1) -- we send attack
		self:EnableVision()
		task.wait(.05) 
		-- give a frame to determine player's whereabouts
	end
end

function NPC_Object:AssignBehavior()
	local minDist
	self.Player.Value, minDist = self:FindClosestPlayer() -- see if there's a player
	if self.Player.Value then 
		if minDist <= self.AttackRanges[2] then 
			self.internalBehavior.Value = 0 -- we attack
		else 
			self.internalBehavior.Value = 1 -- we chase player
		end
	else
		self.internalBehavior.Value = -1
	end
end

local function setBehavior(silo, func)
	silo:Dispatch(silo.Actions.SetBehavior(coroutine.create(func)))
end
 
function NPC_Object:EnableVision()
	self.vision = RunService.Heartbeat:Connect(function(deltaTime: number)
		self:UpdateDists() -- update player distances
		self:AssignBehavior()
	end)
end

function Behavior.new(enemy)

	local behaviorSilo = Silo.new({
		-- Initial state:
		Behavior = coroutine.create(function() end),
		Path = coroutine.create(function() end)
	}, {
		-- Modifiers are functions that modify the state:
		SetBehavior = function(state, behavior: coroutine)
			state.Behavior = behavior 
		end,
		SetPath = function(state, newPath: coroutine)
			state.Path = newPath 
		end
	
	})
	
	
	-- go from one behavior to another 
	local function transitionThread(oldThread, newthread, enemy) 
		if enemy.Maid._conn then enemy.Maid._conn:Disconnect() end 
		
		if coroutine.status(oldThread) ~= "dead" then
			coroutine.close(oldThread)
		end
		coroutine.resume(newthread, enemy, behaviorSilo)
	end
	
	
	local unsubscribe = behaviorSilo:Subscribe(function(newState, oldState)
		-- for switching behavior 
		if oldState.Behavior ~= newState.Behavior and newState.Behavior then
			transitionThread(oldState.Behavior, newState.Behavior, enemy)
		end
		
		if oldState.Path ~= newState.Path and newState.Path then
			transitionThread(oldState.Path, newState.Path, enemy)
		end

	end)
	
	
	if enemy then
		local minDist
		
		local BEHAVIOR_TABLE = {
			[-1] = NPC_Object.idle,
			[-2] = nil, 
			[0] = NPC_Object.attack,
			[1] = NPC_Object.aggro
		}
		
		-- an internal behavior (stores an integer) indicates how an NPC should move/yield.
		enemy.internalBehavior = Instance.new("IntValue")
		
		
		local behaviorListener, positionListener
		behaviorListener = enemy.internalBehavior:GetPropertyChangedSignal("Value"):Connect(function()
			enemy.ServerContainer:SetAttribute("Animation", -2)
			local behavior = enemy.internalBehavior.Value
			setBehavior(behaviorSilo, BEHAVIOR_TABLE[behavior])	
		end)
		
		
		positionListener = enemy.ServerContainer:GetAttributeChangedSignal("Position"):Connect(function()
			
			local futurePosition = enemy.ServerContainer:GetAttribute("Position")
			if not enemy.Render then enemy.Position = futurePosition return end
			if enemy._conn then enemy._conn:Disconnect() end 
			local totalTime = 0
			
			local _conn 
			local distance = (enemy.Position - futurePosition).Magnitude	
			local t = distance / enemy.WalkSpeed
			
			-- should use maid connection
			_conn = RunService.Heartbeat:Connect(function(deltaTime: number)
				if totalTime/t >= 1 then _conn:Disconnect() end
				local pos: Vector3 = enemy.Position
				enemy.Position = pos:Lerp(futurePosition, math.min((totalTime/t), 1))
				totalTime += deltaTime
			end) -- interpolates the points between the waypath points

			enemy.Maid._conn = _conn
		end)

		enemy.Maid:GiveTask(behaviorListener)
		enemy.Maid:GiveTask(positionListener)
	
		enemy.PlayerDistances = {}
		enemy.Path = PathfindingService:CreatePath({
			["AgentRadius"] = 1,
			["AgentHeight"] = 5,
			["AgentCanJump"] = false,
			["WaypointSpacing"] = 4
		})
		
		enemy:EnableVision()
		
		-- set it to idle
		enemy.internalBehavior.Value = -1
		--setBehavior(behaviorSilo, NPC_Object.idle)
	end


	return behaviorSilo
end






return Behavior
