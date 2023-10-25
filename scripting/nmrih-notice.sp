#pragma newdecls required
#pragma semicolon 1

#undef  MAXPLAYERS
#define MAXPLAYERS 9                        // The maximum number of players in nmrih is only 9

#include <sourcemod>
#include <sdktools>
#include <dhooks>

#include <multicolors>

#include <nmrih-notice>                     // native and forward


#define PLUGIN_NAME                         "NMRIH Notice"
#define PLUGIN_DESCRIPTION                  "Alert the player when something happens in the game"
#define PLUGIN_VERSION                      "2.0.1"


public Plugin myinfo =
{
    name        = PLUGIN_NAME,
    author      = "F1F88",
    description = PLUGIN_DESCRIPTION,
    version     = PLUGIN_VERSION,
    url         = "https://github.com/F1F88/nmrih-notice"
};


enum
{
    Offset_m_bIsBleedingOut,                // Speculative name
    Offset_m_flInfectionTime,
    Offset_m_flInfectionDeathTime,

    Offset_Total
}

enum
{
    Forward_bleedOut,
    Forward_stopBleedingOut,
    Forward_becomeInfected,
    Forward_cureInfection,

    Forward_Total
}

enum
{
    ConVar_notice_bleeding,
    ConVar_notice_infected,
    ConVar_notice_friend_fire,
    ConVar_notice_friend_kill,
    ConVar_notice_friend_kill_report,
    ConVar_notice_keycode,
    ConVar_notice_ffmsg_interval,

    ConVar_Total
}

bool            g_loadLate;

int             g_offsetList[Offset_Total];

GlobalForward   g_forwardList[Forward_Total];

any             g_convarList[ConVar_Total];


#include "nmrih-notice/client-preference.sp"


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    ClientPrefs_MarkNativeAsOptional();     // 客户偏好 - 标记函数为可选

    LoadOffset();                           // 加载类的属性的偏移量

    LoadNativeAndForward();                 // 提供外部 native 和 forward

    g_loadLate = late;

    return APLRes_Success;
}

public void OnPluginStart()
{
    LoadTranslations("common.phrases");
    LoadTranslations("nmrih-notice.phrases");

    LoadConVar();
    AutoExecConfig(true, PLUGIN_NAME);

    LoadGameData();                         // 加载需要绕行的函数

    LoadHookEvent();                        // 加载监听事件

    LoadLateSupport();                      // 支持延迟加载插件
}


// 玩家开始流血
MRESReturn Detour_CNMRiH_Player_BleedOut(int client, DHookReturn ret, DHookParam params)
{
    PrintToServer("Func BleedOut | client = %d | %N |", client, client);

    Action result;
    Call_StartForward(g_forwardList[Forward_bleedOut]);
    Call_PushCell(client);
    Call_Finish(result);
    if( result == Plugin_Handled || result == Plugin_Stop )
        return MRES_Supercede;

    UTIL_CPrintToChatAll(g_convarList[ConVar_notice_bleeding], CLIENT_PREFS_BIT_SHOW_BLEEDING, "%t", "Notifice_Bleeding", client);

    return MRES_Ignored;
}

// 玩家结束流血
// Note1: 死亡不会触发
// Note2: 复活不会触发
// Note3: 使用 绷带、医疗包 后会连续触发两次
// Note4: 使用 医疗箱治疗后 只会触发一次
MRESReturn Detour_CNMRiH_Player_StopBleedingOut(int client, DHookReturn ret, DHookParam params)
{
    PrintToServer("Func Stop Bleed | client = %d | %N |", client, client);

    Action result;
    Call_StartForward(g_forwardList[Forward_stopBleedingOut]);
    Call_PushCell(client);
    Call_Finish(result);
    if( result == Plugin_Handled || result == Plugin_Stop )
        return MRES_Supercede;

    return MRES_Ignored;
}

// 玩家开始感染
MRESReturn Detour_CNMRiH_Player_BecomeInfected(int client, DHookReturn ret, DHookParam params)
{
    PrintToServer("Func Become Infecte | client = %d | %N |", client, client);

    Action result;
    Call_StartForward(g_forwardList[Forward_becomeInfected]);
    Call_PushCell(client);
    Call_Finish(result);
    if( result == Plugin_Handled || result == Plugin_Stop )
        return MRES_Supercede;

    UTIL_CPrintToChatAll(g_convarList[ConVar_notice_bleeding], CLIENT_PREFS_BIT_SHOW_BLEEDING, "%t", "Notifice_Infection", client);

    return MRES_Ignored;
}

// 玩家结束感染
// Note1: 死亡不会触发
// Note2: 复活会连续触发两次
// Note3: 使用 疫苗 后只会触发一次
MRESReturn Detour_CNMRiH_Player_CureInfection(int client, DHookReturn ret, DHookParam params)
{
    PrintToServer("Func Cure Infecte | client = %d | %N |", client, client);

    Action result;
    Call_StartForward(g_forwardList[Forward_cureInfection]);
    Call_PushCell(client);
    Call_Finish(result);
    if( result == Plugin_Handled || result == Plugin_Stop )
        return MRES_Supercede;

    return MRES_Ignored;
}


// 感染玩家被攻击通知
public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    float curTime = GetGameTime();
    static float lastTime = 0.0;
    int victim = GetClientOfUserId( event.GetInt("userid") );
    int attacker = GetClientOfUserId( event.GetInt("attacker") );

    // prevent flood
    if( curTime - lastTime < g_convarList[ConVar_notice_ffmsg_interval] || victim == attacker || ! UTIL_IsValidClient(attacker) || ! UTIL_IsValidClient(victim) )
        return ;

    lastTime = curTime;

    UTIL_CPrintToChatAll(g_convarList[ConVar_notice_friend_fire], CLIENT_PREFS_BIT_SHOW_FF, "%t", "Notifice_Attacked", attacker, victim);
}

// 死亡通知
public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId( event.GetInt("userid") );
    if( ! UTIL_IsValidClient(victim) || event.GetInt("npctype") != 0 )
        return ;

    int attacker = GetClientOfUserId( event.GetInt("attacker") );
    if( attacker == victim || ! UTIL_IsValidClient(attacker) )
        return ;

    UTIL_CPrintToChatAll(g_convarList[ConVar_notice_friend_kill], CLIENT_PREFS_BIT_SHOW_FK, "%t", "Notifice_Kill", attacker, victim);

    if( g_convarList[ConVar_notice_friend_kill_report] )
    {
        CPrintToChatAll("%t", "Notifice_Vote Kick", attacker);
    }
}


// 显示输入的密码
public void Event_Keycode_Enter(Event event, char[] Ename, bool dontBroadcast)
{
    char enter_code[16], correct_code[16];
    int client = event.GetInt("player");
    int keypad = event.GetInt("keypad_idx");

    event.GetString("code", enter_code, sizeof(enter_code));
    GetEntPropString(keypad, Prop_Data, "m_pszCode", correct_code, sizeof(correct_code));
    // PrintToServer("Password:| %s |", correct_code);

    if( ! strcmp(enter_code, correct_code) )
    {
        UTIL_CPrintToChatAll(g_convarList[ConVar_notice_keycode], CLIENT_PREFS_BIT_SHOW_PASSWD, "%t", "Notifice_InputCorrectCode", client, enter_code);
    }
    else
    {
        UTIL_CPrintToChatAll(g_convarList[ConVar_notice_keycode], CLIENT_PREFS_BIT_SHOW_PASSWD, "%t", "Notifice_InputIncorrectCode", client, enter_code);
    }
}

// =============================== Cookie Menu ===============================
public void OnAllPluginsLoaded()
{
	ClientPrefs_CheckLibExistsAndLoad();
}

public void OnLibraryAdded(const char[] name)
{
    ClientPrefs_CheckLibExistsAndLoad();
}

public void OnLibraryRemoved(const char[] name)
{
    ClientPrefs_CheckLibExistsAndLoad();
}

public void OnClientPutInServer(int client)
{
    ClientPrefs_ReadClientData(client);
}

public void OnClientDisconnect(int client)
{
    ClientPrefs_ResetClientData(client);
}

// =============================== 封装 ======================================
void LoadOffset()
{
    g_offsetList[Offset_m_bIsBleedingOut]       = UTIL_LoadOffsetOrFail("CNMRiH_Player", "_bleedingOut");
    g_offsetList[Offset_m_flInfectionTime]      = UTIL_LoadOffsetOrFail("CNMRiH_Player", "m_flInfectionTime");
    g_offsetList[Offset_m_flInfectionDeathTime] = UTIL_LoadOffsetOrFail("CNMRiH_Player", "m_flInfectionDeathTime");
}

void LoadGameData()
{
    GameData gamedata = new GameData("nmrih-notice.games");
    if( ! gamedata)
        SetFailState("Couldn't find nmrih-notice.games gamedata.");

    DynamicDetour detour;
    detour = DynamicDetour.FromConf(gamedata, "CNMRiH_Player::BleedOut");
    if( ! detour )
        SetFailState("Failed to find signature CNMRiH_Player::BleedOut");
    detour.Enable(Hook_Pre, Detour_CNMRiH_Player_BleedOut);
    delete detour;

    detour = DynamicDetour.FromConf(gamedata, "CNMRiH_Player::StopBleedingOut");
    if( ! detour )
        SetFailState("Failed to find signature CNMRiH_Player::StopBleedingOut");
    detour.Enable(Hook_Pre, Detour_CNMRiH_Player_StopBleedingOut);
    delete detour;

    detour = DynamicDetour.FromConf(gamedata, "CNMRiH_Player::BecomeInfected");
    if( ! detour )
        SetFailState("Failed to find signature CNMRiH_Player::BecomeInfected");
    detour.Enable(Hook_Pre, Detour_CNMRiH_Player_BecomeInfected);
    delete detour;

    detour = DynamicDetour.FromConf(gamedata, "CNMRiH_Player::CureInfection");
    if( ! detour )
        SetFailState("Failed to find signature CNMRiH_Player::CureInfection");
    detour.Enable(Hook_Pre, Detour_CNMRiH_Player_CureInfection);
    delete detour;

    delete gamedata;
}

void LoadConVar()
{
    ConVar convar;
    (convar = CreateConVar("sm_notice_bleeding",        "1", "在聊天框提示玩家流血",            _, true, 0.0, true, 1.0)).AddChangeHook(OnConVarChange);
    g_convarList[ConVar_notice_bleeding] = convar.BoolValue;
    (convar = CreateConVar("sm_notice_infected",        "1", "在聊天框提示玩家感染",            _, true, 0.0, true, 1.0)).AddChangeHook(OnConVarChange);
    g_convarList[ConVar_notice_infected] = convar.BoolValue;
    (convar = CreateConVar("sm_notice_ff",              "1", "在聊天框提示队友攻击",            _, true, 0.0, true, 1.0)).AddChangeHook(OnConVarChange);
    g_convarList[ConVar_notice_friend_fire] = convar.BoolValue;
    (convar = CreateConVar("sm_notice_fk",              "1", "在聊天框提示队友击杀",            _, true, 0.0, true, 1.0)).AddChangeHook(OnConVarChange);
    g_convarList[ConVar_notice_friend_kill] = convar.BoolValue;
    (convar = CreateConVar("sm_notice_fk_rp",           "0", "在聊天框提示队友击杀如何举报",    _, true, 0.0, true, 1.0)).AddChangeHook(OnConVarChange);
    g_convarList[ConVar_notice_friend_kill_report] = convar.BoolValue;
    (convar = CreateConVar("sm_notice_ffmsg_interval",  "1.0", "每条友伤提醒最短间隔（秒）",    _, true, 0.0, true, 600.0)).AddChangeHook(OnConVarChange);
    g_convarList[ConVar_notice_ffmsg_interval] = convar.FloatValue;
    (convar = CreateConVar("sm_notice_keycode",         "1", "在聊天框提示键盘输入的密码",      _, true, 0.0, true, 1.0)).AddChangeHook(OnConVarChange);
    g_convarList[ConVar_notice_keycode] = convar.BoolValue;

    CreateConVar("sm_nmrih_notice_version",             PLUGIN_VERSION, PLUGIN_DESCRIPTION, FCVAR_SPONLY | FCVAR_DONTRECORD);
}

public void OnConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    char convarName[64];
    convar.GetName(convarName, 64);

    if( ! strcmp(convarName, "sm_notice_player_debuff_bleeding") )
    {
        g_convarList[ConVar_notice_bleeding] = convar.BoolValue;
    }
    else if( ! strcmp(convarName, "sm_notice_player_debuff_infected") )
    {
        g_convarList[ConVar_notice_infected] = convar.BoolValue;
    }
    else if( ! strcmp(convarName, "sm_notice_ff") )
    {
        g_convarList[ConVar_notice_friend_fire] = convar.BoolValue;
        UTIL_ChangeHookEvent(g_convarList[ConVar_notice_friend_fire], "player_hurt", Event_PlayerHurt);
    }
    else if( ! strcmp(convarName, "sm_notice_fk") )
    {
        g_convarList[ConVar_notice_friend_kill] = convar.BoolValue;
        UTIL_ChangeHookEvent(g_convarList[ConVar_notice_friend_kill], "player_death", Event_PlayerDeath);
    }
    else if( ! strcmp(convarName, "sm_notice_fk_rp") )
    {
        g_convarList[ConVar_notice_friend_kill_report] = convar.BoolValue;
    }
    else if( ! strcmp(convarName, "sm_notice_ffmsg_interval") )
    {
        g_convarList[ConVar_notice_ffmsg_interval] = convar.FloatValue;
    }
    else if( ! strcmp(convarName, "sm_notice_keycode_enable") )
    {
        g_convarList[ConVar_notice_keycode] = convar.BoolValue;
        UTIL_ChangeHookEvent(g_convarList[ConVar_notice_keycode], "keycode_enter", Event_Keycode_Enter);
    }
}

void LoadHookEvent()
{
    if( g_convarList[ConVar_notice_friend_fire] )
        HookEvent("player_hurt", Event_PlayerHurt);

    if( g_convarList[ConVar_notice_friend_kill] )
        HookEvent("player_death", Event_PlayerDeath);

    if( g_convarList[ConVar_notice_keycode] )
        HookEvent("keycode_enter", Event_Keycode_Enter);
}

void LoadLateSupport()
{
    if( ! g_loadLate )
        return ;

    ClientPrefs_LoadLate();
}

// =============================== UTIL ======================================
stock int UTIL_LoadOffsetOrFail(const char[] cls, const char[] prop, PropFieldType &type=view_as<PropFieldType>(0), int &num_bits=0, int &local_offset=0, int &array_size=0)
{
    int offset = FindSendPropInfo(cls, prop, type, num_bits, local_offset, array_size);
    if( offset < 1 )
        SetFailState("Can't find offset [%s] [%s]", cls, prop);
    return offset;
}

// 根据 isHook 执行 HookEvent 或 UnhookEvent
stock void UTIL_ChangeHookEvent(bool isHook, const char[] name, EventHook callback, EventHookMode mode=EventHookMode_Post)
{
    isHook ? HookEvent(name, callback) : UnhookEvent(name, callback);
}

// 根据 convar 和 clientPrefBit 判断是否输出
stock void UTIL_CPrintToChatAll(bool convar, int bit, const char[] message, any ...)
{
    if( ! convar )
        return ;

    char formatMessage[512];
    for( int client=1; client<=MaxClients; ++client )
    {
        if( IsClientInGame(client) && ClientPrefs_CanPrint(client, bit) )
        {
            VFormat(formatMessage, sizeof(formatMessage), message, 4);
            CPrintToChat(client, formatMessage);
        }
    }
}

stock bool UTIL_IsValidClient(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client);
}

// =============================== Native ====================================
public void LoadNativeAndForward()
{
    CreateNative("NMR_Notice_IsBleedingOut",            Native_NMR_Notice_IsBleedingOut);
    CreateNative("NMR_Notice_IsInfected",               Native_NMR_Notice_IsInfected);
    CreateNative("NMR_Notice_GetInfectionTime",         Native_NMR_Notice_GetInfectionTime);
    CreateNative("NMR_Notice_GetInfectionDeathTime",    Native_NMR_Notice_GetInfectionDeathTime);

    g_forwardList[Forward_bleedOut]         = new GlobalForward("NMR_Notice_OnPlayerBleedOut",          ET_Event, Param_Cell);
    g_forwardList[Forward_stopBleedingOut]  = new GlobalForward("NMR_Notice_OnPlayerStopBleedingOut",   ET_Event, Param_Cell);
    g_forwardList[Forward_becomeInfected]   = new GlobalForward("NMR_Notice_OnPlayerBecomeInfected",    ET_Event, Param_Cell, Param_Float, Param_Float);
    g_forwardList[Forward_cureInfection]    = new GlobalForward("NMR_Notice_OnPlayerCureInfection",     ET_Event, Param_Cell);
}


public any Native_NMR_Notice_IsBleedingOut(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if( ! UTIL_IsValidClient(client) )
        ThrowError("NMR_Notice_IsBleedingOut %d is invalid client", client);

    return GetEntData(client, g_offsetList[Offset_m_bIsBleedingOut], 1) == 1;
}

public any Native_NMR_Notice_IsInfected(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if( ! UTIL_IsValidClient(client) )
        ThrowError("NMR_Notice_IsInfected %d is invalid client", client);

    return GetEntDataFloat(client, g_offsetList[Offset_m_flInfectionTime]) != -1.0;
}

public any Native_NMR_Notice_GetInfectionTime(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if( ! UTIL_IsValidClient(client) )
        ThrowError("NMR_Notice_IsBleedingOut %d is invalid client", client);

    return GetEntDataFloat(client, g_offsetList[Offset_m_flInfectionTime]);
}

public any Native_NMR_Notice_GetInfectionDeathTime(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if( ! UTIL_IsValidClient(client) )
        ThrowError("NMR_Notice_IsInfected %d is invalid client", client);

    return GetEntDataFloat(client, g_offsetList[Offset_m_flInfectionDeathTime]);
}
