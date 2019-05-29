E2Lib.RegisterExtension("contraption", true, "Enables interaction with Contraption Framework")

local Contraptions

hook.Add("CFrame Initialize", "E2", function() Contraptions = contraption.Contraptions end) -- Race conditions are bad mkay

--=====================================================================================--
registerType("contraption", "xcr", nil,
	nil,
	nil,
	function(retval)
		if retval == nil then return end
		if not istable(retval) then error("Return value is neither nil nor a table, but a "..type(retval).."!",0) end
	end,
	function(v)
		return not istable(v)
	end
)

-- = operator
registerOperator("ass", "xcr", "xcr", function(self, args)
	local lhs, op2, scope = args[2], args[3], args[4]
	local      rhs = op2[1](self, op2)

	self.Scopes[scope][lhs] = rhs
	self.Scopes[scope].vclk[lhs] = true
	return rhs
end)

e2function number operator_is(contraption cont)
	if cont and Contraptions[cont] then return 1
	else return 0 end
end

--=====================================================================================--

__e2setcost(5)

e2function number contraption:isValid()
	if IsValid(this) and Contraptions[this] then return 1 end

	return 0
end

-- Return an entity's contraption
e2function contraption entity:contraption()
	if not IsValid(this) then return nil end

	if this.CFrame then
		return this.CFrame.Contraption
	else
		return nil
	end
end

-- Return the E2s own contraption
e2function contraption contraption()
	if self.CFrame then
		return self.CFrame.Contraption
	else
		return nil
	end
end

-- Return an array of all contraptions
e2function array contraptions()
	local Arr = {}

	for K in pairs(Contraptions) do Arr[#Arr+1] = K end

	return Arr
end

-- Return an array of all entities in a contraption
e2function array contraption:entities()
	if not Contraptions[this] then return {} end

	local Ents  = this.Ents
	local Arr   = {}
	local Count = 0

	for K in pairs(Ents.Physical) do
		Count = Count+1
		Arr[Count] = K
	end

	if next(Ents.Parented) then
		for K in pairs(Ents.Physical) do
			Count = Count+1
			Arr[Count] = K
		end
	end

	return Arr
end

-- Return an array of all physical entities in a contraption
e2function array contraption:physicalEntities()
	if not Contraptions[this] then return {} end

	local Ents  = this.Ents
	local Arr   = {}
	local Count = 0

	for K in pairs(Ents.Physical) do
		Count = Count+1
		Arr[Count] = K
	end

	return Arr
end

-- Return an array of all parented entities in a contraption
e2function array contraption:parentedEntities()
	if not Contraptions[this] then return {} end
	if not next(Ents.Parented) then return {} end

	local Ents  = this.Ents
	local Arr   = {}
	local Count = 0

	for K in pairs(Ents.Parented) do
		Count = Count+1
		Arr[Count] = K
	end

	return Arr
end

-- Return the number of entities that make up this contraption
e2function number contraption:count()
	if not Contraptions[this] then return 0 end

	return this.Ents.Count
end

e2function number contraption:getMass()
	if not Contraptions[this] then return 0 end

	return contraption.GetMass(this)
end

e2function number contraption:getPhysicalMass()
	if not Contraptions[this] then return 0 end

	return contraption.GetPhysMass(this)
end

e2function number contraption:getParentedMass()
	if not Contraptions[this] then return 0 end

	return contraption.GetParentedMass(this)
end