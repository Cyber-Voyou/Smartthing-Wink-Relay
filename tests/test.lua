package.path="driver/src/?.lua;"..package.path
local count=0
local function check(value,message)count=count+1;assert(value,message)end
local MQTT=require"mqtt_client"
local client=MQTT.new({host="192.168.1.10",port=1883,prefix="wink_relay_test",client_id="test",credentials=function()end,status=function()end,message=function()end},{gettime=function()return 0 end})
check(#client.topics==5,"five scoped state topics")
client.ready=true
check(client:publish("wink_relay_test/relays/0","ON"),"own upper command")
check(client:publish("wink_relay_test/relays/1","OFF"),"own lower command")
check(not client:publish("other/relays/0","ON"),"foreign prefix rejected")
check(not client:publish("wink_relay_test/screen","ON"),"screen command rejected")
check(not client:publish("wink_relay_test/command/reboot","ON"),"reboot rejected")
check(not client:publish("wink_relay_test/relays/0","TOGGLE"),"payload rejected")
client:close_socket();check(#client.commands==0,"disconnect clears commands")

local credentials=require"credentials"
local p={mqttUsername="dedicated",mqttPassword="synthetic",mqttEnabled=true,mqttRiskAccepted=true}
check(credentials.read(p).username=="dedicated","generic dedicated account")
p.mqttEnabled=false;check(credentials.read(p)==nil,"disabled gate")
p.mqttEnabled=true;p.mqttRiskAccepted=false;check(credentials.read(p)==nil,"risk gate")
p.mqttRiskAccepted=true;p.mqttPassword="";check(credentials.read(p)==nil,"empty password rejected")

local Manager=require"session_manager"
local made={}
local function factory(options)
  local object={options=options,stopped=false}
  function object:start()self.started=true end
  function object:stop()self.stopped=true end
  function object:publish()return not self.stopped end
  made[#made+1]=object;return object
end
local function device(id)return{id=id,preferences={mqttUsername="dedicated",mqttPassword="synthetic",mqttEnabled=true,mqttRiskAccepted=true}}end
local a,b=Manager.new(factory),Manager.new(factory);local da,db=device"a",device"b"
local function cb(prefix)return{host="192.168.1.10",port=1883,prefix=prefix,status=function()end,message=function()end}end
check(a:reconcile(da,cb"wink_a")=="started","first independent session")
check(b:reconcile(db,cb"wink_b")=="started","second independent session")
check(#made==2 and made[1].started and made[2].started,"parallel owners")
check(a:removed(da) and made[1].stopped and not made[2].stopped,"remove one keeps other")
check(b:reconcile(db,cb"wink_b_changed")=="started" and made[2].stopped,"prefix change rotates socket")
b:shutdown();check(made[3].stopped,"shutdown closes replacement")
print("PASS: "..count.." public-driver assertions")
