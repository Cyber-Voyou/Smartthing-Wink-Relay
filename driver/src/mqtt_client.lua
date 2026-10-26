-- Minimal MQTT 3.1.1 client. Commands are allowlisted to the owning Wink prefix.
local M={}; M.__index=M
local function str(s) assert(type(s)=="string" and #s<=65535,"invalid string"); return string.pack(">I2",#s)..s end
local function packet(h,b)
  local n=#b; local out={string.char(h)}
  repeat local d=n%128; n=math.floor(n/128); out[#out+1]=string.char(d+(n>0 and 128 or 0)) until n==0
  return table.concat(out)..b
end
function M.new(o,io)
  assert(type(o.host)=="string" and #o.host>=1 and #o.host<=253 and not o.host:find("[%c%s]"),"broker host invalid")
  assert(type(o.port)=="number" and o.port>=1 and o.port<=65535 and o.port%1==0,"broker port invalid")
  assert(type(o.client_id)=="string" and #o.client_id<=128,"client id required")
  assert(type(o.prefix)=="string" and #o.prefix<=96 and o.prefix:match("^[%w_-]+$"),"Wink prefix required")
  local self=setmetatable({o=o,io=io,buffer="",ready=false,stopped=false,delay=1,commands={}},M)
  self.topics={}; self.allowed={}
  for _,s in ipairs({"relays/0/state","relays/1/state","sensors/temperature","sensors/humidity","screen/state"}) do
    local t=o.prefix.."/"..s; self.topics[#self.topics+1]=t; self.allowed[t]=true
  end
  return self
end
function M:send(h,b)
  -- Explicit allowlist: CONNECT, SUBSCRIBE, PINGREQ only; no will or publish.
  assert(h==16 or h==130 or h==192 or h==48,"outgoing packet forbidden")
  assert(not self.stopped,"stopped")
  local data=packet(h,b); local i=1
  while i<=#data do
    assert(not self.stopped,"stopped")
    local sent,err,partial=self.sock:send(data:sub(i)); local n=sent or partial or 0
    if n<1 then error("send_failed",0) end
    i=i+n
    if err then error("send_failed",0) end
  end
  self.tx=self.io.gettime()
end
function M:read()
  local deadline=self.io.gettime()+10
  while true do
    assert(not self.stopped,"stopped")
    assert(self.io.gettime()<deadline,"frame_deadline")
    local b=self.buffer
    if #b>=2 then
      local n,m,pos=0,1,2
      while pos<=#b do
        local d=b:byte(pos); n=n+(d%128)*m
        assert(n<=4096,"packet_limit")
        if d<128 then
          if #b>=pos+n then self.buffer=b:sub(pos+n+1); return b:byte(1),b:sub(pos+1,pos+n) end
          break
        end
        assert(pos<5,"invalid_length"); m=m*128; pos=pos+1
      end
    end
    local data,err,partial=self.sock:receive(1)
    local chunk=data or partial or ""
    self.buffer=self.buffer..chunk
    assert(#self.buffer<=4101,"buffer_limit")
    if not data then
      if err~="timeout" then error("receive_failed",0) end
      if #self.buffer==0 then return nil end -- idle, not a lost partial frame
      if self.io.gettime()>=deadline then error("partial_frame_timeout",0) end
    end
  end
end
function M:incoming(h,b)
  if self.stopped then return end
  if h>>4==3 then
    assert((h & 6)==0 and (h & 8)==0,"unsupported_publish_flags") -- QoS 0 subscription
    assert(#b>=2,"invalid_publish")
    local n=string.unpack(">I2",b); assert(n>0 and #b>=n+2,"invalid_topic")
    local topic=b:sub(3,n+2); local payload=b:sub(n+3)
    if self.allowed[topic] then self.o.message(topic,payload,(h & 1)==1) end
  elseif h==208 then assert(#b==0 and self.ping,"unexpected_pingresp"); self.ping=nil
  else error("unexpected_packet",0) end
end
function M:publish(topic,payload)
  if self.stopped or not self.ready then return false,"not_connected" end
  local prefix=type(topic)=="string" and topic:match("^(wink_relay_[a-z]+)/relays/[01]$") or nil
  if not prefix or prefix~=self.o.prefix then return false,"topic_forbidden" end
  if payload~="ON" and payload~="OFF" then return false,"payload_forbidden" end
  if #self.commands>=8 then return false,"queue_full" end
  self.commands[#self.commands+1]={topic=topic,payload=payload}
  return true
end
function M:session()
  self.buffer=""; self.ping=nil; self.ready=false
  assert(not self.stopped,"stopped")
  local c=self.o.credentials()
  assert(type(c)=="table" and type(c.username)=="string" and #c.username>0 and #c.username<=128
    and type(c.password)=="string" and #c.password>0 and #c.password<=128,"credentials_required")
  self.sock=assert(self.io.tcp()); assert(self.sock:settimeout(1)); assert(self.sock:connect(self.o.host,self.o.port))
  assert(not self.stopped,"stopped")
  self:send(16,str("MQTT")..string.char(4,194,0,30)..str(self.o.client_id)..str(c.username)..str(c.password)); c=nil
  local h,b=self:read(); assert(h==32 and b==string.char(0,0),"connack_rejected")
  local parts={string.char(0,1)}
  for _,t in ipairs(self.topics) do parts[#parts+1]=str(t)..string.char(0) end
  self:send(130,table.concat(parts))
  local pending={}
  local until_time=self.io.gettime()+10
  repeat
    h,b=self:read()
    if h==144 then
      assert(#b==2+#self.topics and b:sub(1,2)==string.char(0,1),"invalid_suback")
      for i=3,#b do assert(b:byte(i)==0,"subscription_rejected") end
      break
    elseif h then
      assert(h>>4==3 and #pending<32,"pre_suback_limit")
      pending[#pending+1]={h,b} -- no callback before all subscriptions accepted
    end
    assert(self.io.gettime()<until_time,"suback_timeout")
  until self.stopped
  if self.stopped then return end
  self.ready=true; self.o.status(true); local started=self.io.gettime()
  for _,p in ipairs(pending) do self:incoming(p[1],p[2]) end
  pending=nil
  while not self.stopped do
    h,b=self:read(); if h then self:incoming(h,b); self.io.sleep(0) end
    while self.ready and #self.commands>0 do
      local command=table.remove(self.commands,1)
      self:send(48,str(command.topic)..command.payload)
    end
    local now=self.io.gettime()
    if self.ping and now-self.ping>=10 then error("ping_timeout",0) end
    if not self.ping and now-self.tx>=20 then self:send(192,""); self.ping=now end
    if now-started>=60 then self.delay=1 end
  end
end
function M:run()
  while not self.stopped do
    local ok=pcall(function() self:session() end)
    self:close_socket()
    self.ready=false
    pcall(self.o.status,false,ok and "stopped" or "session_failed") -- never propagate raw errors
    if not self.stopped then self.io.sleep(self.delay+math.random()*self.delay*.2); self.delay=math.min(60,self.delay*2) end
  end
end
function M:close_socket()
  local sock=self.sock; self.sock=nil
  if sock then pcall(function() sock:close() end) end
  self.buffer=""; self.ping=nil; self.ready=false
  self.commands={} -- never replay a physical command after reconnect
end
function M:start(cosock)
  assert(not self.worker and not self.stopped,"already_started_or_stopped")
  self.worker=cosock.spawn(function() self:run() end,"rezotik passive MQTT")
end
function M:stop()
  if self.stopped then return end
  self.stopped=true
  local worker=self.worker; self.worker=nil
  if worker and worker.cancel then pcall(function() worker:cancel() end) end
  self:close_socket() -- TCP close, no will, no queued data or MQTT publication
  self.o.credentials=function() return nil end
  self.o.status=function() end; self.o.message=function() end
end
return M
