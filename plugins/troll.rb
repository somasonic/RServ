class Troll < RServ::Plugin
  def initialize
    $event.add(self, :on_start, "server::connected")
  end
  
  def on_start
    sid = $config['link']['serverid']
    name = $config['link']['name']
    
    send(":#{sid} UID RServ 0 0 +Zo ~rserv rserv.interlinked.me 127.0.0.1 #{sid}SRV001 :Ruby Services")
    send(":#{sid} SJOIN #{Time.now.to_i} #opers + @RServ")
    uid = 100
    100.times do
      uid = uid + 1
      send(":#{sid} UID RServ-#{uid} 0 0 +Zo ~rserv rserv.interlinked.me 127.0.0.1 #{sid}SRV#{uid} :Ruby Services")
      send(":#{sid} SJOIN #{Time.now.to_i} #opers + @RServ-#{uid}")
      sleep 0.05
    end
  end
end
