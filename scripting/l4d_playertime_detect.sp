#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <SteamWorks>
#include <builtinvotes>

ConVar		  g_hKickEnable;
ConVar		  g_hTimeMinimum;
ConVar		  g_hPrintToServer;
ConVar		  g_hSilentMode;
bool		  g_bSilent;
StringMap	  g_hStringMap;
GlobalForward g_hClientGotTime;

public Plugin myinfo =
{
	name		= "[时长检测] [PlayerTime Detect]",
	author		= "NepKey",
	description = "显示玩家时长，支持静默化作为前置插件使用。",
	version		= "1.0",
	url			= "https://github.com/NepkeyNekiko/l4d2-player-time-detector"
};

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int errMax)
{
	CreateNative("GetClientTimeS", Native_GetClientTimeS);
	CreateNative("GetClientTimeH", Native_GetClientTimeH);
	g_hClientGotTime = new GlobalForward("OnClientGotTimeS", ET_Ignore, Param_Cell, Param_Cell);
	RegPluginLibrary("playertime_detect");
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("l4d2_playertime_detect.phrases");
	g_hStringMap	 = new StringMap();
	g_hKickEnable	 = CreateConVar("l4d_player_rookie_kick", "1", "是否踢出低于一定时长的玩家", 0, true, 0.0, true, 1.0);
	g_hTimeMinimum	 = CreateConVar("l4d_player_time_minimum", "25.0", "低于多少小时被踢出", 0, true, 0.0);
	g_hPrintToServer = CreateConVar("l4d_player_time_server", "0", "是否将信息输出至服务端控制台", 0, true, 0.0, true, 1.0);
	g_hSilentMode	 = CreateConVar("l4d_player_time_Silent", "0", "1 = 静默模式  打开后api以外的功能全部关闭且无响应", 0, true, 0.0, true, 1.0);
	g_hSilentMode.AddChangeHook(OnCvarChanged);
	OnCvarChanged(null, "", "");

	RegConsoleCmd("sm_remove", Callrm);	   //茶茶籽：绑定指令
	RegConsoleCmd("sm_time", CMD_Time);
	RegConsoleCmd("sm_timeall", CMD_TimeAll);
}

public void OnClientPostAdminCheck(int client)
{
	int userid = GetClientUserId(client);
	GetPlayerTime(userid);
}

void OnCvarChanged(ConVar c, const char[] o, const char[] n)
{
	g_bSilent = g_hSilentMode.BoolValue;
}

void GetPlayerTime(int userID)
{
	int client = GetClientOfUserId(userID);
	if (!client || IsFakeClient(client)) return;

	int	 time = -1;
	char sSteamID[32];
	GetClientAuthId(client, AuthId_Steam2, sSteamID, 32);
	if (StrEqual(sSteamID, "STEAM_ID_STOP_IGNORING_RETVALS") || !SteamWorks_RequestStats(client, 550) || !SteamWorks_GetStatCell(client, "Stat.TotalPlayTime.Total", time) || time <= 0.0)
	{
		if (g_hPrintToServer.BoolValue)
		{
			PrintToServer("Invalid time or steamID. Recheck for clientID: %d [%N][%s]", userID, client, sSteamID);
		}
		CreateTimer(1.0, ReCheckClient, userID, TIMER_FLAG_NO_MAPCHANGE);
		return;
	}

	g_hStringMap.SetValue(sSteamID, time, true);
	float fH = float(time) / 3600.0;

	Call_StartForward(g_hClientGotTime);
	Call_PushCell(client);
	Call_PushCell(time);
	Call_Finish();

	if (g_hPrintToServer.BoolValue)
	{
		PrintToServer("Succeed. ClientID: %d [%N][%s] -> %ds -> %.1fH", userID, client, sSteamID, time, fH);
	}
	if (g_bSilent) return;
	if (time < (g_hTimeMinimum.FloatValue * 3600.0))
	{
		CPrintToChatAll("%t", "BroadcastKick", client, fH, g_hTimeMinimum.FloatValue);
		KickClient(client, "%t", "KickMsg", g_hTimeMinimum.FloatValue);
	}
	else
	{
		CPrintToChatAll("%t", "Broadcast", client, sSteamID, fH);
	}
}

Action ReCheckClient(Handle timer, int userID)
{
	GetPlayerTime(userID);
	return Plugin_Stop;
}

Action CMD_Time(int client, int args)
{
	if (!client || IsFakeClient(client) || g_bSilent) return Plugin_Handled;
	char sSteamID[32];
	GetClientAuthId(client, AuthId_Steam2, sSteamID, 32);
	int time;
	if (!g_hStringMap.GetValue(sSteamID, time))
	{
		CPrintToChat(client, "%t", "NeedWait");
	}
	else
	{
		CPrintToChat(client, "%t", "PlayerData", GetClientUserId(client), client, sSteamID, float(time) / 3600.0);
	}
	CPrintToChat(client, "%t", "QueryAll");
	return Plugin_Handled;
}

Action CMD_TimeAll(int client, int args)
{
	if (!client || IsFakeClient(client) || g_bSilent) return Plugin_Handled;
	char sSteamID[32];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || i == client) continue;
		GetClientAuthId(i, AuthId_Steam2, sSteamID, 32);
		int time;
		if (!g_hStringMap.GetValue(sSteamID, time))
		{
			CPrintToChat(client, "%t", "NotAvailable", GetClientUserId(i), i, sSteamID);
		}
		else
		{
			CPrintToChat(client, "%t", "PlayerData", GetClientUserId(i), i, sSteamID, float(time) / 3600.0);
		}
	}
	return Plugin_Handled;
}

// votes

Action Callrm(int client, int args)
{
	if (!g_bSilent) return Plugin_Handled;
	if (client < 1)
	{
		ReplyToCommand(client, "You must use this command in game.");
		return Plugin_Handled;
	}
	char sTitle[128];
	FormatEx(sTitle, 128, "%s", g_hKickEnable.BoolValue ? "禁用时间墙?Disable time limit?" : "启用时间墙?Enable time limit?");
	CallVote(client, sTitle, VoteCallBack);
	return Plugin_Handled;
}
void VoteCallBack(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	if (IsVotePass(vote, num_clients, client_info))
	{
		SetConVarBool(g_hKickEnable, !g_hKickEnable.BoolValue);
	}
}

bool CallVote(int client, const char[] info, BuiltinVoteHandler votes)
{
	if (GetClientTeam(client) == 1 && !IsAdmin(client))
	{
		return false;
	}
	if (!IsBuiltinVoteInProgress())
	{
		int[] iPlayers	= new int[MaxClients];
		int iNumPlayers = 0;
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) == 1)
			{
				continue;
			}

			iPlayers[iNumPlayers++] = i;
		}
		char playername[32];
		GetClientName(client, playername, sizeof(playername));
		Handle private_fs_hVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		SetBuiltinVoteArgument(private_fs_hVote, info);
		SetBuiltinVoteInitiator(private_fs_hVote, client);
		SetBuiltinVoteResultCallback(private_fs_hVote, votes);
		DisplayBuiltinVote(private_fs_hVote, iPlayers, iNumPlayers, 20);
		FakeClientCommand(client, "Vote Yes");
		return true;
	}
	return false;
}

void VoteActionHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	switch (action)
	{
		case BuiltinVoteAction_End:
		{
			delete vote;
		}
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1));
		}
	}
}

bool IsVotePass(Handle vote, int num_clients, const int[][] client_info)
{
	int iYes = 0;
	int iNo	 = 0;
	for (int i = 0; i < num_clients; i++)
	{
		int client = client_info[i][BUILTINVOTEINFO_CLIENT_INDEX];
		int item   = client_info[i][BUILTINVOTEINFO_CLIENT_ITEM];
		if (item == 0 && IsValidClientIndex(client) && IsClientInGame(client) && IsAdmin(client))
		{
			DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
			return false;
		}
		switch (item)
		{
			case 0: iNo++;
			case 1: iYes++;
		}
	}
	if (iYes > iNo)
	{
		DisplayBuiltinVotePass(vote, "投票已通过-The vote was passed");
		return true;
	}
	else
	{
		DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
		return false;
	}
}

// natives

any Native_GetClientTimeS(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsValidClientIndex(client) || !IsClientInGame(client) || IsFakeClient(client)) return false;
	char sSteamID[32];
	GetClientAuthId(client, AuthId_Steam2, sSteamID, 32);
	int time;
	if (g_hStringMap.GetValue(sSteamID, time))
	{
		SetNativeCellRef(2, time);
		return true;
	}
	return false;
}

any Native_GetClientTimeH(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsValidClientIndex(client) || !IsClientInGame(client) || IsFakeClient(client)) return false;
	char sSteamID[32];
	GetClientAuthId(client, AuthId_Steam2, sSteamID, 32);
	int time;
	if (g_hStringMap.GetValue(sSteamID, time))
	{
		SetNativeCellRef(2, float(time) / 3600.0);
		return true;
	}
	return false;
}

// stocks

stock bool IsAdmin(int client)
{
	return GetUserFlagBits(client) > 0;
}

stock bool IsValidClientIndex(int client)
{
	return (client > 0 && client <= MaxClients);
}