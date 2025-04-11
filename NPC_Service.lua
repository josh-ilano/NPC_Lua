local ServerStorage = game:GetService('ServerStorage')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')


local NPC_Object = require(script.NpcObject)
local Packages = ReplicatedStorage.Library.Knit.Packages
local BehaviorState =  require(script.BehaviorState)
local Knit = require(Packages.Knit)


local NpcService = Knit.CreateService { -- Create the SaveService
	Name = "NpcService",

	
	Client = {
		EnemyLevel = Knit.CreateProperty(1),
		CreateEnemies = Knit.CreateSignal() -- create batches of a certain type
	},

	NPC_Dic = {}
}


function NpcService:KnitInit()
	game.Close:Connect(function() 
		for i, v in self.NPC_Dic do
			v.Maid:Destroy()
			self.NPC_Dic[i] = nil
		end
	end)
end



function NpcService:CreateEnemies(player: Player, level)
	
	self.enemyDic = {}

	self.Client.EnemyLevel:Set(level)


	-- we go through the spawnpoints, and spawn enemies based on their tags
	for _, spawnpoint in workspace.EnemySpawn:GetChildren() do

		local tag = string.split(spawnpoint.Name, "_")[2] -- the enemy type tag
		local enemy_tag = string.format("%s_%s", NPC_Object.Constants.MAP_ABBREV, tag) -- e.g. "GY_Melee1"

		if not tag:match("Quest") then
			-- get all attributes
			local AttackLen, AttackRanges, AttackType, MonsterCat, WalkSpeed = NPC_Object.ReturnInfo(enemy_tag)
			if AttackLen then -- if we have attack animation length registered
				AttackLen += 0.01


				if table.find(NPC_Object.Constants.SPAWN_CATS, tag) then
			
					local enemy = NPC_Object.new(enemy_tag,
						AttackType, -- Type (Melee, Caster, Range),
						AttackRanges, -- Attack Ranges
						WalkSpeed, -- studs/sec
						MonsterCat,
						AttackLen,
						spawnpoint, -- given instance part
						NPC_Object.Constants.ENEMY_EXCEPTION_DATA[enemy_tag]) -- exceptions as a dic

				
					enemy:Configure(level); -- set their stats
					self.NPC_Dic[enemy] = BehaviorState.new(enemy) -- assign their behavior
		
					if not self.enemyDic[enemy_tag] then self.enemyDic[enemy_tag] = 1
					else self.enemyDic[enemy_tag] += 1 end

				end
			end


			--if MonsterCat == "Boss" then Boss_NPC.AssignBoss(enemy); 
			--	createProxPrompt(spawnpoint.Position + Vector3.new(0,10,0)) end 
		end
		
	end
		
	
	self:SyncEnemies(player, false)
	-- sync as the first player (with initial positions)	
	
end


function NpcService:SyncEnemies(player, isAfter)
	self.Client.CreateEnemies:Fire(player) -- let client know we begin creating enemies
	for enemy_tag, amount in self.enemyDic do

		local AttackLen, AttackRanges, AttackType, MonsterCat, WalkSpeed = NPC_Object.ReturnInfo(enemy_tag)

		--Name (tag), Type (attackType), AttackRanges, WalkSpeed, container, Params, isAfter
		-- if isAfter is true, then we sync with yielding for next positional change
		self.Client.CreateEnemies:Fire(player, enemy_tag, amount, isAfter, -- necessary args
			AttackType, AttackRanges, WalkSpeed, MonsterCat, NPC_Object.Constants.ENEMY_EXCEPTION_DATA[enemy_tag])
		

	end
end

return NpcService
