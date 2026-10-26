local M={}
local function clean(value,limit)
  return type(value)=="string" and #value>=1 and #value<=limit and not value:find("[%z\1-\31\127]")
end
function M.read(preferences)
  local p=preferences or {}
  if p.mqttEnabled~=true then return nil,"disabled" end
  if p.mqttRiskAccepted~=true then return nil,"risk_not_accepted" end
  if not clean(p.mqttUsername,128) or not clean(p.mqttPassword,128) then return nil,"credentials_invalid" end
  return {username=p.mqttUsername,password=p.mqttPassword}
end
return M
