-- Owns at most one client. Dependencies are injected; never stores secrets in fields/datastore.
local credentials=require "credentials"
local M={}; M.__index=M
function M.new(factory)
  return setmetatable({factory=factory,generation=0,closed=false},M)
end
function M:stop()
  self.generation=self.generation+1 -- invalidate callbacks before close/cancel
  local client=self.client
  self.client=nil; self.owner=nil; self.current=nil
  if client then client:stop() end
end
function M:reconcile(device,callbacks)
  if self.closed then return "shutdown" end
  if self.owner and self.owner~=device.id then return "duplicate_owner" end
  local c,reason
  c,reason=credentials.read(device.preferences)
  if not c then self:stop(); return reason end
  if self.client and self.current.username==c.username and self.current.password==c.password
    and self.current.host==callbacks.host and self.current.port==callbacks.port and self.current.prefix==callbacks.prefix then
    return "unchanged"
  end
  self:stop() -- synchronous cancellation/close before any replacement worker
  self.owner=device.id; self.current={username=c.username,password=c.password,host=callbacks.host,port=callbacks.port,prefix=callbacks.prefix}
  local generation=self.generation
  local function active() return not self.closed and generation==self.generation and self.owner==device.id end
  local options={host=callbacks.host,port=callbacks.port,prefix=callbacks.prefix,
    credentials=function() if active() then return {username=c.username,password=c.password} end end,
    status=function(...) if active() then callbacks.status(...) end end,
    message=function(...) if active() then callbacks.message(...) end end}
  local ok,client=pcall(self.factory,options)
  if not ok then self:stop(); return "client_start_failed" end
  self.client=client
  local started=pcall(function() client:start() end)
  if not started then self:stop(); return "client_start_failed" end
  return "started"
end
function M:removed(device)
  if self.owner==device.id then self:stop(); return true end
  return false
end
function M:publish(topic,payload)
  if self.closed or not self.client or not self.client.publish then return false,"not_connected" end
  return self.client:publish(topic,payload)
end
function M:shutdown() self.closed=true; self:stop() end
return M
