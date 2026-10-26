local Driver=require"st.driver"
local capabilities=require"st.capabilities"
local socket=require"cosock.socket"
local status_cap=capabilities["outsideclever46212.rezotikWinkStatus"]
assert(status_cap and status_cap.ID)

local managers,values={},{}
local function profile(device)
  return device.preferences.singleLight==true and "wink-relay-single" or "wink-relay-dual"
end
local function endpoint(device)
  local p=device.preferences or{}
  local host=p.mqttHost
  local port=tonumber(p.mqttPort or 1883)
  local prefix=p.mqttPrefix
  if type(host)~="string"or#host<1 or#host>253 or host:find("[%c%s]")then return nil,"host_invalid"end
  if not port or port<1 or port>65535 or port%1~=0 then return nil,"port_invalid"end
  if type(prefix)~="string"or#prefix<1 or#prefix>96 or not prefix:match("^[%w_-]+$")then return nil,"prefix_invalid"end
  return{host=host,port=port,prefix=prefix}
end
local function emit(device,event)pcall(function()device:emit_event(event)end)end
local function emit_switch(device,component,payload)
  local state=payload=="ON"and"on"or payload=="OFF"and"off"or nil
  if not state or(component=="lower"and device.preferences.singleLight==true)then return end
  pcall(function()local target=device.profile.components[component];if target then device:emit_component_event(target,capabilities.switch.switch[state]())end end)
end
local function summary(device)
  local v=values[device.id]or{}
  local function x(key)return v[key]or"?"end
  local text=device.preferences.singleLight==true and("Light "..x"upper".." · Screen "..x"screen")or("Upper "..x"upper".." · Lower "..x"lower".." · Screen "..x"screen")
  emit(device,status_cap.summary(text))
end
local function factory(options)
  options.client_id="st-wink-"..options.prefix.."-"..math.floor(socket.gettime()*1000)
  local mqtt=require("mqtt_client").new(options,socket)
  return{start=function()mqtt:start(require"cosock")end,stop=function()mqtt:stop()end,publish=function(_,topic,payload)return mqtt:publish(topic,payload)end}
end
local function manager(device)
  local current=managers[device.id]
  if not current then current=require("session_manager").new(factory);managers[device.id]=current end
  return current
end
local function callbacks(device,settings)
  return{host=settings.host,port=settings.port,prefix=settings.prefix,
    status=function(ok)print("wink_relay mqtt "..(ok and"subscribed"or"disconnected"));if ok then summary(device)end end,
    message=function(topic,payload)
      if topic:sub(1,#settings.prefix+1)~=settings.prefix.."/"then return end
      local suffix=topic:sub(#settings.prefix+2);local v=values[device.id]or{};values[device.id]=v
      if suffix=="relays/0/state"then v.upper=payload;emit_switch(device,"main",payload)
      elseif suffix=="relays/1/state"then v.lower=payload;emit_switch(device,"lower",payload)
      elseif suffix=="screen/state"then v.screen=payload
      elseif suffix=="sensors/temperature"then local n=tonumber(payload);if n and n>=-100 and n<=150 then emit(device,capabilities.temperatureMeasurement.temperature({value=n,unit="C"}))end
      elseif suffix=="sensors/humidity"then local n=tonumber(payload);if n and n>=0 and n<=100 then emit(device,capabilities.relativeHumidityMeasurement.humidity(n))end end
      summary(device)
    end}
end
local function index(_,device)
  local want=profile(device);local has_lower=device.profile and device.profile.components and device.profile.components.lower~=nil
  if has_lower~=(want=="wink-relay-dual")then
    local current=managers[device.id];if current then current:stop()end
    device:try_update_metadata({profile=want});return
  end
  local settings,reason=endpoint(device)
  if not settings then local current=managers[device.id];if current then current:stop()end;print("wink_relay configuration "..reason);return end
  print("wink_relay reconcile "..manager(device):reconcile(device,callbacks(device,settings)))
end
local function removed(_,device)
  local current=managers[device.id];if current then current:removed(device);current:shutdown();managers[device.id]=nil end
  values[device.id]=nil
end
local function command(_,device,command)
  local settings=endpoint(device);if not settings then return end
  local component=command.component or"main"
  if device.preferences.singleLight==true and component~="main"then return end
  local relay=component=="main"and"0"or component=="lower"and"1"or nil;if not relay then return end
  local payload=command.command=="on"and"ON"or command.command=="off"and"OFF"or nil;if not payload then return end
  local current=managers[device.id];if not current then return end
  local ok,reason=current:publish(settings.prefix.."/relays/"..relay,payload);print("wink_relay command "..(ok and"queued"or reason))
end
local function discovery(driver)
  local suffix=tostring(math.floor(socket.gettime()*1000))
  driver:try_create_device({type="LAN",device_network_id="wink-relay-mqtt-"..suffix,label="Wink Relay MQTT",profile="wink-relay-dual",manufacturer="Community",model="Wink Relay MQTT"})
end
local function shutdown()for _,current in pairs(managers)do current:shutdown()end;managers={}end
local driver=Driver("smartthings-wink-relay-mqtt",{supported_capabilities={capabilities.switch,status_cap,capabilities.temperatureMeasurement,capabilities.relativeHumidityMeasurement},discovery=discovery,lifecycle_handlers={init=index,added=index,infoChanged=index,removed=removed},driver_lifecycle=function(_,event)if event=="shutdown"then shutdown();os.exit(0)end end,capability_handlers={[capabilities.switch.ID]={on=command,off=command}}})
print("wink_relay public driver ready")
local ok=pcall(function()driver:run()end);shutdown();if not ok then error("wink_relay runtime failed",0)end
