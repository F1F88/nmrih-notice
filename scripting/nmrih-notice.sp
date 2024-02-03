#pragma newdecls required
#pragma semicolon 1

#undef  MAXPLAYERS
#define MAXPLAYERS 9                        // The maximum number of players in nmrih is only 9

#include <sourcemod>
#include <sdktools>
#include <dhooks>

#include <clients_methodmap>

#include "common/native/nmrih-notice.inc"   // native and forward
#include "common/utils/InitializeUtils.inc"
#include "common/utils/EventUtils.inc"
#include "common/utils/ClientPrefsUtils.inc"


#define PLUGIN_NAME                         "nmrih_notice"
#define PLUGIN_DESCRIPTION                  "Alert the player when something happens in the game"
#define PLUGIN_VERSION                      "2.1.0"

public Plugin myinfo =
{
    name        = PLUGIN_NAME,
    author      = "F1F88",
    description = PLUGIN_DESCRIPTION,
    version     = PLUGIN_VERSION,
    url         = "https://github.com/F1F88/nmrih-notice"
};

#define CLIENT_PREFS_NAME                   "NMRIH Notice ClientPrefs"
#define CLIENT_PREFS_DESCRIPTION            CLIENT_PREFS_NAME
#define CLIENT_PREFS_MENU_ITEM              "NMRIH Notice"
#define CLIENT_PREFS_BIT_SHOW_BLEEDING      (1 << 0)
#define CLIENT_PREFS_BIT_SHOW_INFECTED      (1 << 1)
#define CLIENT_PREFS_BIT_SHOW_FF            (1 << 2)
#define CLIENT_PREFS_BIT_SHOW_FK            (1 << 3)
#define CLIENT_PREFS_BIT_SHOW_PASSWD        (1 << 4)
#define CLIENT_PREFS_BIT_ALL                CLIENT_PREFS_BIT_SHOW_BLEEDING|CLIENT_PREFS_BIT_SHOW_INFECTED|CLIENT_PREFS_BIT_SHOW_FF|CLIENT_PREFS_BIT_SHOW_FK|CLIENT_PREFS_BIT_SHOW_PASSWD
#define CLIENT_PREFS_BIT_DEFAULT            CLIENT_PREFS_BIT_ALL

CookieEx        g_cookie;

int             g_offsetList[Offset_Total];

GlobalForward   g_forwardList[Forward_Total];

any             g_convarList[ConVar_Total];

enum
{
    Offset_m_bIsBleedingOut,                // Speculative name
    Offset_m_bVaccinated,
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

// =============================== Init ===============================
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    MarkClientPrefsNativeAsOptional();      // 客户偏好 - 标记函数为可选

    LoadOffset();                           // 加载类的属性的偏移量

    LoadNativeAndForward();                 // 提供外部 native 和 forward

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
}

// =============================== Cookie Menu ===============================
public void OnAllPluginsLoaded()
{
	LoadCookie();
}

public void OnLibraryAdded(const char[] name)
{
    LoadCookie();
}


// =============================== Detour ===============================
// 玩家开始流血
MRESReturn Detour_CNMRiH_Player_BleedOut(int client, DHookReturn ret, DHookParam params)
{
    // PrintToServer("Func BleedOut | client = %d | %N |", client, client);

    Action result;
    Call_StartForward(g_forwardList[Forward_bleedOut]);
    Call_PushCell(client);
    Call_Finish(result);
    if( result == Plugin_Handled || result == Plugin_Stop )
        return MRES_Supercede;

    g_cookie.CPrintToChatAllExI(CLIENT_PREFS_BIT_DEFAULT, CLIENT_PREFS_BIT_SHOW_BLEEDING, "Notifice_Bleeding", client);

    return MRES_Ignored;
}

// 玩家结束流血
// Note1: 死亡不会触发
// Note2: 复活不会触发
// Note3: 使用 绷带、医疗包 后会连续触发两次
// Note4: 使用 医疗箱治疗后 只会触发一次
// Note5: 玩家 撤离后 只会触发一次
MRESReturn Detour_CNMRiH_Player_StopBleedingOut(int client, DHookReturn ret, DHookParam params)
{
    // PrintToServer("Func Stop Bleed | client = %d | %N |", client, client);

    Action result;
    Call_StartForward(g_forwardList[Forward_stopBleedingOut]);
    Call_PushCell(client);
    Call_Finish(result);
    if( result == Plugin_Handled || result == Plugin_Stop )
        return MRES_Supercede;

    return MRES_Ignored;
}

// 玩家开始感染
// Note1: 即使已注射疫苗仍会触发此绕行
MRESReturn Detour_CNMRiH_Player_BecomeInfected(int client, DHookReturn ret, DHookParam params)
{
    // PrintToServer("Func Become Infecte | client = %d | %N |", client, client);

    Action result;
    Call_StartForward(g_forwardList[Forward_becomeInfected]);
    Call_PushCell(client);
    Call_Finish(result);
    if( result == Plugin_Handled || result == Plugin_Stop )
        return MRES_Supercede;

    if( ! NMR_Notice_IsVaccinated(client) )
        g_cookie.CPrintToChatAllExI(CLIENT_PREFS_BIT_DEFAULT, CLIENT_PREFS_BIT_SHOW_INFECTED, "Notifice_Infection", client);

    return MRES_Ignored;
}

// 玩家结束感染
// Note1: 死亡不会触发
// Note2: 复活会连续触发两次
// Note3: 使用 疫苗 后只会触发一次
MRESReturn Detour_CNMRiH_Player_CureInfection(int client, DHookReturn ret, DHookParam params)
{
    // PrintToServer("Func Cure Infecte | client = %d | %N |", client, client);

    Action result;
    Call_StartForward(g_forwardList[Forward_cureInfection]);
    Call_PushCell(client);
    Call_Finish(result);
    if( result == Plugin_Handled || result == Plugin_Stop )
        return MRES_Supercede;

    return MRES_Ignored;
}


// =============================== Event CallBack ===============================
// 感染玩家被攻击通知
public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    float curTime = GetGameTime();
    static float lastTime = 0.0;
    int victim = GetClientOfUserId( event.GetInt("userid") );
    int attacker = GetClientOfUserId( event.GetInt("attacker") );

    // prevent flood
    if( curTime - lastTime < g_convarList[ConVar_notice_ffmsg_interval] || victim == attacker || ! IsValidClient(attacker) || ! IsValidClient(victim) )
        return ;

    lastTime = curTime;

    g_cookie.CPrintToChatAllExII(CLIENT_PREFS_BIT_DEFAULT, CLIENT_PREFS_BIT_SHOW_FF, "Notifice_Attacked", attacker, victim);
}

// 死亡通知
public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId( event.GetInt("userid") );
    if( ! IsValidClient(victim) || event.GetInt("npctype") != 0 )
        return ;

    int attacker = GetClientOfUserId( event.GetInt("attacker") );
    if( attacker == victim || ! IsValidClient(attacker) )
        return ;

    g_cookie.CPrintToChatAllExII(CLIENT_PREFS_BIT_DEFAULT, CLIENT_PREFS_BIT_SHOW_FK, "Notifice_Kill", attacker, victim);

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
        g_cookie.CPrintToChatAllExIS(CLIENT_PREFS_BIT_DEFAULT, CLIENT_PREFS_BIT_SHOW_PASSWD, "Notifice_InputCorrectCode", client, enter_code);
    }
    else
    {
        g_cookie.CPrintToChatAllExIS(CLIENT_PREFS_BIT_DEFAULT, CLIENT_PREFS_BIT_SHOW_PASSWD, "Notifice_InputIncorrectCode", client, enter_code);
    }
}

// =================================== 封装 ====================================
void LoadOffset()
{
    g_offsetList[Offset_m_bIsBleedingOut]       = UTIL_LoadOffsetOrFail("CNMRiH_Player", "_bleedingOut");
    g_offsetList[Offset_m_bVaccinated]          = UTIL_LoadOffsetOrFail("CNMRiH_Player", "_vaccinated");
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
        EventUtils.ChangeHook(g_convarList[ConVar_notice_friend_fire], "player_hurt", Event_PlayerHurt);
    }
    else if( ! strcmp(convarName, "sm_notice_fk") )
    {
        g_convarList[ConVar_notice_friend_kill] = convar.BoolValue;
        EventUtils.ChangeHook(g_convarList[ConVar_notice_friend_kill], "player_death", Event_PlayerDeath);
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
        EventUtils.ChangeHook(g_convarList[ConVar_notice_keycode], "keycode_enter", Event_Keycode_Enter);
    }
}

void LoadHookEvent()
{
    if( g_convarList[ConVar_notice_friend_fire] )
        EventUtils.ChangeHook(true, "player_hurt", Event_PlayerHurt);

    if( g_convarList[ConVar_notice_friend_kill] )
        EventUtils.ChangeHook(true, "player_death", Event_PlayerDeath);

    if( g_convarList[ConVar_notice_keycode] )
        EventUtils.ChangeHook(true, "keycode_enter", Event_Keycode_Enter);
}

// ================================= Native ==================================
public void LoadNativeAndForward()
{
    CreateNative("NMR_Notice_IsBleedingOut",            Native_NMR_Notice_IsBleedingOut);
    CreateNative("NMR_Notice_IsVaccinated",             Native_NMR_Notice_IsVaccinated);
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
    if( ! IsValidClient(client) )
        ThrowError("NMR_Notice_IsBleedingOut %d is invalid client", client);

    return GetEntData(client, g_offsetList[Offset_m_bIsBleedingOut], 1);
}

public any Native_NMR_Notice_IsVaccinated(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if( ! IsValidClient(client) )
        ThrowError("NMR_Notice_IsVaccinated %d is invalid client", client);

    return GetEntData(client, g_offsetList[Offset_m_bVaccinated], 1);
}

public any Native_NMR_Notice_IsInfected(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if( ! IsValidClient(client) )
        ThrowError("NMR_Notice_IsInfected %d is invalid client", client);

    return GetEntDataFloat(client, g_offsetList[Offset_m_flInfectionTime]) != -1.0;
}

public any Native_NMR_Notice_GetInfectionTime(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if( ! IsValidClient(client) )
        ThrowError("NMR_Notice_IsBleedingOut %d is invalid client", client);

    return GetEntDataFloat(client, g_offsetList[Offset_m_flInfectionTime]);
}

public any Native_NMR_Notice_GetInfectionDeathTime(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if( ! IsValidClient(client) )
        ThrowError("NMR_Notice_IsInfected %d is invalid client", client);

    return GetEntDataFloat(client, g_offsetList[Offset_m_flInfectionDeathTime]);
}


// ================================= Client Prefs ==================================
void LoadCookie()
{
    // 避免需要重复注册, 否则 settings 菜单会有多个选项
    if( g_cookie.isValid )
        return ;

    g_cookie = new CookieEx(CLIENT_PREFS_NAME, CLIENT_PREFS_DESCRIPTION, CookieAccess_Private);

    // 如果注册失败, 则不要在 settings 菜单中添加 item
    if( ! g_cookie.isValid )
        return ;

    SetCookieMenuItem(CookieMenuHandler, 0, CLIENT_PREFS_MENU_ITEM);
}

void CookieMenuHandler(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
    ShowCookiesMenu(client, 0);
}

void ShowCookiesMenu(int client, int at=0)
{
    if( ! g_cookie.isValid )
        return ;

    Menu menu = new Menu(PrefsMenuHandler, MenuAction_Select | MenuAction_Cancel);
    menu.ExitBackButton = true;
    menu.SetTitle("%T", "Notifice_PrefsMenu_Title", client);

    g_cookie.AddBitItem(client, CLIENT_PREFS_BIT_DEFAULT, CLIENT_PREFS_BIT_SHOW_BLEEDING,    menu,   "Notifice_PrefsMenu_Item_Bleeding");
    g_cookie.AddBitItem(client, CLIENT_PREFS_BIT_DEFAULT, CLIENT_PREFS_BIT_SHOW_INFECTED,    menu,   "Notifice_PrefsMenu_Item_Infected");
    g_cookie.AddBitItem(client, CLIENT_PREFS_BIT_DEFAULT, CLIENT_PREFS_BIT_SHOW_FF,          menu,   "Notifice_PrefsMenu_Item_ff");
    g_cookie.AddBitItem(client, CLIENT_PREFS_BIT_DEFAULT, CLIENT_PREFS_BIT_SHOW_FK,          menu,   "Notifice_PrefsMenu_Item_fk");
    g_cookie.AddBitItem(client, CLIENT_PREFS_BIT_DEFAULT, CLIENT_PREFS_BIT_SHOW_PASSWD,      menu,   "Notifice_PrefsMenu_Item_passwd");

    menu.DisplayAt(client, at, 30);
}

int PrefsMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch( action )
    {
        case MenuAction_End:
        {
            delete menu;
            if( param1 == MenuEnd_Cancelled && param2 == MenuCancel_ExitBack )
            {
                ShowCookieMenu(param1);
            }
        }
        case MenuAction_Select:
        {
            // int - bit info
            char item_info[MAX_CLIENT_PREFS_ITEM_INFO_LEN];

            // 读取选择的 item 的 item info (对应的 bit 位)
            menu.GetItem(param2, item_info, sizeof(item_info));

            // 翻转选择的 bit, 并存储新值
            g_cookie.SwitchBitItem(param1, CLIENT_PREFS_BIT_DEFAULT, StringToInt(item_info));

            int at = GetBitItemAtPage( StringToFloat(item_info) );
            ShowCookiesMenu(param1, at);
        }
    }
    return 0;
}
