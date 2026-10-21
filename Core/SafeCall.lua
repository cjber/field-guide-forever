---@type string, BFNamespace
local _, ns = ...

-- Event handlers must not take the rest of the addon down with one bad row. Keep the last few failures so a user can
-- report what happened without a frame or a protected call being involved.
local MAX_ERRORS = 20
---@type BFError[]
local errors = {}

---@param context string
---@param fn function
---@param ... any
---@return boolean ok
---@return any result
function ns.SafeCall(context, fn, ...)
	if type(fn) ~= "function" then
		return false, "not a function"
	end
	local ok, result = pcall(fn, ...)
	if not ok then
		errors[#errors + 1] = {
			context = context,
			message = tostring(result),
			time = time and time() or 0,
		}
		while #errors > MAX_ERRORS do
			table.remove(errors, 1)
		end
		local handler = geterrorhandler and geterrorhandler()
		if handler then
			pcall(handler, tostring(result))
		end
	end
	return ok, result
end

---@return BFError[]
function ns.GetErrors()
	return errors
end

function ns.ClearErrors()
	for index = #errors, 1, -1 do
		errors[index] = nil
	end
end
