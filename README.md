插件需要SteamWorks扩展实现核心功能和builtinvotes扩展实现其他功能
l4d_player_time_Silent 为 1 启用静默机制，插件不再输出或响应时长信息，作为前置插件使用
Cvars：
l4d_player_rookie_kick 是否踢出低于一定时长的玩家
l4d_player_time_minimum 低于多少小时被踢出
l4d_player_time_server 是否将信息输出至服务端控制台
Natives：
GetClientTimeS GetClientTimeH\n
Forwards：
OnClientGotTimeS
详情查看inc