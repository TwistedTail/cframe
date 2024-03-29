if not cframe then
	cframe = {
		Count = 0,
		Contraptions = {},
		ConstraintTypes = { -- Note there is no no-collide. no-collide is not a constraint
			phys_lengthconstraint = true,
			phys_constraint = true,
			phys_hinge = true,
			phys_ragdollconstraint = true,
			gmod_winch_controller = true,
			phys_spring = true,
			phys_slideconstraint = true,
			phys_torque = true,
			phys_pulleyconstraint = true,
			phys_ballsocket = true
		},
		Callbacks = { OnConnect = {}, OnDisconnect = {}, OnInit = {}, OnPhysChange = {} }
	}
end

-------------------------------------------------- Localization

local Contraptions    = cframe.Contraptions
local ParentFilter	  = {predicted_viewmodel = true, gmod_hands = true} -- Parent trigger filters
local ConstraintTypes = cframe.ConstraintTypes
local HRUN            = hook.Run
local Callbacks       = cframe.Callbacks
local HasConstraints -- Defined later
-------------------------------------------------- Contraption creation, removal and addition

local function CreateContraption() -- Create a contraption (Two entities will be subsequently Appended)
	cframe.Count = cframe.Count + 1

	local Contraption = {
		IsContraption = true,
		Ents = {
			Count = 0,
			Physical = {},
			Parented = {}
		}
	}

	Contraptions[Contraption] = true

	HRUN("CFrame Create", Contraption)

	return Contraption
end

local function DestroyContraption(Contraption) -- Remove a contraption once it's empty
	cframe.Count = cframe.Count - 1

	Contraptions[Contraption] = nil

	HRUN("CFrame Destroy", Contraption)

	for K in pairs(Contraption) do Contraption[K] = nil end -- Little cleanup
end

local function Initialize(Entity, Physical) -- Prepare an entity for cframe
	Entity.CFWRK = {
		Connections = {},
		IsPhysical = Physical
	}

	if Callbacks.OnInit[Entity] then
		Entity:OnInit(Physical)
	end

	hook.Run("CFrame InitEntity", Entity, Physical)
end

local function Pop(Contraption, Entity, Parent) -- An entity is removed from a contraption
	if Parent then Contraption.Ents.Parented[Entity] = nil
			  else Contraption.Ents.Physical[Entity] = nil end

	Contraption.Ents.Count = Contraption.Ents.Count-1

	if Callbacks.OnDisconnect[Entity] then
		Entity:OnDisconnect(Contraption, Parent)
	end

	HRUN("CFrame Disconnect", Contraption, Entity, Parent)

	if Contraption.Ents.Count == 0 then DestroyContraption(Contraption) end

	Entity.CFWRK.Contraption = nil
	if not next(Entity.CFWRK.Connections) then Entity.CFWRK = nil end
end

local function Append(Contraption, Entity, Parent) -- An entity is added to an existing contraption
	if Parent then Contraption.Ents.Parented[Entity] = true
			  else Contraption.Ents.Physical[Entity] = true end

	Contraption.Ents.Count = Contraption.Ents.Count + 1

	Entity.CFWRK.Contraption = Contraption

	if Callbacks.OnConnect[Entity] then
		Entity:OnConnect(Contraption, Parent)
	end

	HRUN("CFrame Connect", Contraption, Entity, Parent)
end

local function Merge(A, B) -- Combine two contraptions and remove the smaller one
	local Big, Small

	if A.Ents.Count >= B.Ents.Count then Big, Small = A, B
									else Big, Small = B, A end

	for Ent in pairs(Small.Ents.Physical) do
		Pop(Small, Ent)
		Append(Big, Ent)
	end

	-- Contraption may have been comprised of only physical entities, and automatically removed when Pop was called on the last entity
	-- Check if the contraption still exists, if it does, it's because there are parented entities in it
	if Contraptions[Small] then
		for Ent in pairs(Small.Ents.Parented) do
			Pop(Small, Ent, true)
			Append(Big, Ent, true)
		end
	end

	return Big
end

-------------------------------------------------- Logic


local function FF(Entity, Filter) -- Flood filling. Depth first
	if not IsValid(Entity) then return Filter end

	Filter[Entity] = true

	for K in pairs(Entity.CFWRK.Connections) do
		if IsValid(K) and not Filter[K] then FF(K, Filter) end
	end

	return Filter
end

local function BFS(Start, Goal) -- Flood filling. Breadth first
	local Closed = {}
	local Open   = {};	for K in pairs(Start.CFWRK.Connections) do Open[K] = true end -- Quick copy
	local Count  = #Open

	while next(Open) do
		local Node = next(Open)

		Open[Node] = nil

		if not IsValid(Node) then continue end
		if Node == Goal then return true end

		Closed[Node] = true

		for K in pairs(Node.CFWRK.Connections) do
			if not Closed[K] then
				Open[K] = true
				Count = Count + 1
			end
		end
	end

	return false, Closed, Count
end

local function SetPhysical(Entity, Physical) -- Change the stored state of an entity
	if Entity.CFWRK.IsPhysical == Physical then return end -- Ignore change if its already at desired state

	Entity.CFWRK.IsPhysical = Physical

	local Ents = Entity.CFWRK.Contraption.Ents

	if Physical then
		Ents.Parented[Entity] = nil
		Ents.Physical[Entity] = true
	else
		Ents.Parented[Entity] = true
		Ents.Physical[Entity] = nil
	end

	if Callbacks.OnPhysChange[Entity] then
		Entity:OnPhysChange(Physical)
	end

	HRUN("CFrame PhysChange", Entity, Physical)
end

local function OnConnect(A, B, Parenting) -- Whenever entities are constrained/parented. In the case of parenting, A is the child and B the parent
	local AC = A.CFWRK and A.CFWRK.Contraption or nil
	local BC = B.CFWRK and B.CFWRK.Contraption or nil

	if AC and BC then
		if Parenting and not HasConstraints(A) then -- Parenting with no constraints existing makes this not physical
			SetPhysical(A, false)
		elseif A:GetParent() then -- Being already parenting and adding a constraint makes this physical
			SetPhysical(A, true)
		end

		if AC ~= BC then Merge(AC, BC) end -- Merge the contraptions if they're not the same

		-- Otherwise, do nothing, these two entities are already connected to the same contraption

	elseif AC then
		if Parenting and not HasConstraints(A) then
			SetPhysical(A, false)
		elseif A:GetParent() then
			SetPhysical(A, true)
		end

		Initialize(B, true) -- B is always the parent and is always physical at this point
		Append(AC, B) -- Append B to contraption AC
	elseif BC then
		Initialize(A, not Parenting)
		Append(BC, A, Parenting)
	else
		-- Neither entity has a contraption, make a new one and add them to it

		local Contraption = CreateContraption()

		Initialize(A, not Parenting)
		Initialize(B, true)

		Append(Contraption, A, Parenting)
		Append(Contraption, B)
	end

	local AConnect = A.CFWRK.Connections
	local BConnect = B.CFWRK.Connections

	AConnect[B] = (AConnect[B] or 0) + 1
	BConnect[A] = (BConnect[A] or 0) + 1
end

local function OnDisconnect(A, B, Parenting) -- Whenever entities lose a contraint/parent.
	-- Prove whether A is still connected to B or not
	-- If not: A new contraption is created (Assuming A and B are both connected to more than one thing)

	if Parenting then SetPhysical(A, true) end -- Removal of a parent makes A physical

	local AFrame       = A.CFWRK
	local AConnections = AFrame.Connections
	local BConnections = B.CFWRK.Connections
	local Contraption  = AFrame.Contraption

	if AConnections[B] > 1 then -- Check if the two entities are directly connected
		local Num = AConnections[B]-1

		AConnections[B] = Num
		BConnections[A] = Num

	else -- Check if the entities are indirectly connected

		AConnections[B] = nil
		BConnections[A] = nil

		-- Check if the two entities are connected to anything at all
		local SC
			if not next(AConnections) then
				Pop(Contraption, A)
				SC = true
			end

			if not next(BConnections) then
				Pop(Contraption, B)
				SC = true
			end
		if SC then return end -- One or both of the ents has nothing connected, no further checking needed

		-- Handle parents with children
		-- Parented Ents with no physical constraint always have only one connection to the contraption
		-- If the thing removed was a parent and A is not physical then the two ents are definitely not connected
		-- All entities in A's contraption must therefore be parented children and need to be transferred
		if Parenting and not AFrame.IsPhysical then
			local Collection = FF(A, {})
			local To         = CreateContraption()
			local From       = Contraption

			for Ent in pairs(Collection) do -- Move all the ents connected to the Child to the new contraption
				Pop(From, Ent)
				Append(To, Ent)
			end

			return -- Short circuit
		end

		-- Final test to prove the two Ents are no longer connected
		-- Flood filling until we find the other entity
		-- If the other entity is not found, the Ents collected during the flood fill are made into a new contraption
		local Connected, Collection, Count = BFS(A, B)

		if not Connected then -- The two Ents are no longer connected and we have created two separate contraptions
			local To   = CreateContraption()
			local From = Contraption

			if From.Ents.Count - Count < Count then Collection = FF(B, {}) end -- If this side of the split contraption has more Ents use the other side instead

			for Ent in pairs(Collection) do
				Pop(From, Ent)
				Append(To, Ent)
			end
		end
	end
end

-------------------------------------------------- Hooks

hook.Add("OnEntityCreated", "CFrame Created", function(Constraint)
	if ConstraintTypes[Constraint:GetClass()] then
		-- We must wait because the Constraint's information is set after the constraint is created
		timer.Simple(0, function()
			if not IsValid(Constraint) then return end

			Constraint.Initialized = true -- Required check for EntityRemoved to handle constraints created and deleted in the same tick

			local A, B = Constraint.Ent1, Constraint.Ent2

			if not IsValid(A) or not IsValid(B) then return end -- Contraptions consist of multiple ents not one
			if A == B then return end -- We also don't care about constraints attaching an entity to itself, see above

			OnConnect(A, B)
			HRUN("OnConstraintCreated", Constraint)
		end)
	end
end)

hook.Add("EntityRemoved", "CFrame Removed", function(Entity)
	if Entity.Initialized then -- Constraint being removed
		local A, B = Entity.Ent1, Entity.Ent2

		if not IsValid(A) or not IsValid(B) then return end
		if A == B then return end -- We don't care about constraints attaching an entity to itself

		OnDisconnect(A, B)
		HRUN("OnConstraintRemoved", Entity)
	elseif Entity.Constraints then -- Entity being removed
		for _, Con in pairs(Entity.Constraints) do
			if Con.Initialized then
				Con.Initialized = nil -- Prevent redundant disconnects of this constraint
				OnDisconnect(Con.Ent1, Con.Ent2)
			end
		end
	end
end)

hook.Add("Initialize", "CFrame Init", function() -- We only want to detour the SetParent function once
	local Meta = FindMetaTable("Entity")

	Meta.LegacyParent = Meta.SetParent

	function Meta:SetParent(Parent, Attachment)
		local OldParent = self:GetParent()

		if IsValid(OldParent) and not ParentFilter[OldParent:GetClass()] and not ParentFilter[self:GetClass()] then -- It's only an 'Unparent' if there was a previous parent
			OnDisconnect(self, OldParent, true)
			HRUN("OnUnparent", self, OldParent)
		end

		self:LegacyParent(Parent, Attachment)

		if IsValid(Parent) and not ParentFilter[Parent:GetClass()] and not ParentFilter[self:GetClass()] then
			OnConnect(self, Parent, true)
			HRUN("OnParent", self, Parent)
		end
	end

	function Meta:AddCFrameCallback(Callback)
		if Callbacks[Callback] then
			Callbacks[Callback][self] = true
		else
			error("AddCFrameCallback: invalid callback")
		end
	end

	hook.Remove("Initialize", "CFrame Init") -- No reason to keep this in memory
end)

-------------------------------------------------- Load Modules

for _, V in pairs(file.Find("cframework/modules/*", "LUA")) do
	if string.Left(V, 2) ~= "cl" then
		MsgN("[CFrame] Mounting " .. V .. " module")
		include("cframework/modules/" .. V)
	else
		MsgN("[CFrame] Sending " .. V .. " module")
		AddCSLuaFile("cframework/modules/" .. V)
	end
end

-------------------------------------------------- Contraption Framework Library
do
	function cframe.GetAll() -- Return a table of all contraptions
		return Contraptions
	end

	function cframe.Get(Entity) -- Return an entity's contraption
		if not Entity then return end

		return Entity.CFWRK and Entity.CFWRK.Contraption
	end

	function cframe.GetAllEntities(Var)
		if not Var then return {} end

		local Cont = Var.IsContraption and Var or cframe.Get(Var)
		local Out  = {}

		if Cont then
			for K in pairs(Cont.Ents.Physical) do
				Out[K] = true
			end

			if next(Cont.Ents.Parented) then
				for K in pairs(Cont.Ents.Parented) do
					Out[K] = true
				end
			end
		end

		return Out
	end

	function cframe.GetPhysicalEntities(Var)
		if not Var then return {} end

		local Cont = Var.IsContraption and Var or cframe.Get(Var)
		local Out  = {}

		if Cont then
			for K in pairs(Cont.Ents.Physical) do
				Out[K] = true
			end
		end

		return Out
	end

	function cframe.GetParentedEntities(Var)
		if not Var then return {} end

		local Cont = Var.IsContraption and Var or cframe.Get(Var)
		local Out  = {}

		if Cont and next(Cont.Ents.Parented) then
			for K in pairs(Cont.Ents.Parented) do
				Out[K] = true
			end
		end

		return Out
	end

	function cframe.GetConstraintTypes() -- Return a table of the constraint types cframe is monitoring
		local Tab = {}

		for K in pairs(ConstraintTypes) do
			Tab[K] = true
		end

		return Tab
	end

	function cframe.AddConstraint(Class) -- Add a constraint to be monitored by cframe
		ConstraintTypes[Class] = true
	end

	function cframe.RemoveConstraint(Class)
		ConstraintTypes[Class] = nil
	end

	function cframe.HasConstraints(Entity) -- Returns bool whether an entity has constraints (that cframe monitors)
		if not IsValid(Entity) then return false end
		if not Entity.Constraints then return false end
		if not next(Entity.Constraints) then return false end

		for _, V in pairs(Entity.Constraints) do
			if ConstraintTypes[V:GetClass()] then
				return true
			end
		end

		return false
	end

	HasConstraints = cframe.HasConstraints
end

-------------------------------------------------- Run Initialize hook
HRUN("CFrame Initialize")