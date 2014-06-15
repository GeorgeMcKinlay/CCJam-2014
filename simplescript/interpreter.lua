local Interpreter = {}
Interpreter.__index = Interpreter

function Interpreter.new()
	local self = setmetatable({}, Interpreter)
	self.environment = {}
	return self
end

function Interpreter:loadPackage(file)
	table.insert(self.environment, {
		name = fs.getName(file),
		functions = dofile(file)
	})
end

function Interpreter:getPackageFunction(pkg, func)
	for _,v in ipairs(self.environment) do
		if v.name == pkg then
			for k,j in pairs(v.functions) do
				if k == func then
					return j
				end
			end
		end
	end
	
	return nil
end

local function parseParams(params)
	local tbl = {}
	
	for _,v in ipairs(params) do
		local str = v:match("^\"(.-)\"")
		if str ~= nil then
			str = str:gsub(string.char(6), ",")
			table.insert(tbl, str)
		else
			if tonumber(v) ~= nil then
				table.insert(tbl, tonumber(v))
			else
				if v == "true" then
					table.insert(tbl, true)
				elseif v == "false" then
					table.insert(tbl, false)
				else
					error("invalid parameter!")
				end
			end
		end
	end
	
	return tbl
end

function Interpreter:callFunction(pkg, func, params)
	local name = func.name
	local funct = self:getPackageFunction(pkg, name)
	if funct == nil then
		error("package '" .. tostring(pkg) .. "' has no function named '" .. tostring(name) .. "'")
	end
	return funct(unpack(parseParams(params)))
end

local statements = {
	["perchance"] = "conditional",
	["if"] = "conditional",
	["otherwise"] = "conditional_contradictory",
	["else"] = "conditional_contradictory",
	["repeat"] = "loop",
	["do"] = "loop"
}

function Interpreter:findStatement(parent, depth)
	for i=#parent,1,-1 do
		if parent[i].depth < depth then
			if parent[i].body == nil then
				parent[i].body = {}
			else
				local attempt = self:findFunctionSpace(parent[i].body, depth)
				if attempt ~= nil then
					return attempt
				end
			end

			return parent[i]
		end
	end
end

function Interpreter:findOtherwise(body)
	for i,v in ipairs(body) do
		if v.type == "label" and v.name == "otherwise" then
			return v
		end
	end
end

function Interpreter:interpret(parseTree, printRetValues)
	for _,v in ipairs(parseTree) do
		if v.type == "call" then
			for _,j in ipairs(v.funcs) do
				for i=1,j.repetition or 1 do
					local retVal = self:callFunction(v.pkg, j, j.params)
					if retVal ~= nil and printRetValues then print(retVal) end
				end
			end
		elseif v.type == "statement" then
			if statements[v.kind] == "conditional" then
				local func = v.condition.funcs[1]
				local retVal = self:callFunction(v.condition.pkg, func, func.params)
				
				if retVal then
					self:interpret(v.body, printRetValues)
				else
					local otherwise = self:findOtherwise(v.body)
					if otherwise then
						if otherwise.body == nil then
							error(otherwise.line .. ": otherwise has no body")
						end
						self:interpret(otherwise.body, printRetValues)
					end
				end
			end
		end
	end
end

return Interpreter