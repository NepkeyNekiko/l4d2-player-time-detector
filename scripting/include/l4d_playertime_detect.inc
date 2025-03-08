#if defined _l4d_playertime_detect_included_
	#endinput
#endif
#define _l4d_playertime_detect_included_

/**
 * 获取目标客户端游戏时长（单位：秒）
 *
 * @param client        目标客户端
 * @param seconds       容器
 *
 * @return 如果成功获取，返回true，否则返回false
 */
native bool	 GetClientTimeS(int client, int &seconds);

/**
 * 获取目标客户端游戏时长（单位：小时）
 *
 * @param client        目标客户端
 * @param hours         容器
 *
 * @return 如果成功获取，返回true，否则返回false
 */
native bool	 GetClientTimeH(int client, float &hours);

/**
 * 在客户端成功获取到时间后调用。
 * 发生于每次OnClientPostAdminCheck()后
 *
 * @param client 成功获取时间的客户端
 * @param seconds 时间（单位：秒）
 */
forward void OnClientGotTimeS(int client, int seconds);

public SharedPlugin __pl_l4d_playertime_detect = {
	name = "l4d_playertime_detect",
	file = "l4d_playertime_detect.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN

public void __pl_l4d_playertime_detect_SetNTVOptional()
{
	MarkNativeAsOptional("GetClientTimeS");
	MarkNativeAsOptional("GetClientTimeH");
}
#endif