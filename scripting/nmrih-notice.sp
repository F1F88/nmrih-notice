#include <sourcemod>
#include <dhooks>
#include <clientprefs>

#include <multicolors>

#pragma newdecls required
#pragma semicolon 1

#include <nmrih-notice>


#define PLUGIN_NAME                         "nmrih-notice"
#define PLUGIN_DESCRIPTION                  "Alert the player when something happens in the game"
#define PLUGIN_VERSION                      "3.0.1"

public Plugin myinfo =
{
    name        = PLUGIN_NAME,
    author      = "F1F88",
    description = PLUGIN_DESCRIPTION,
    version     = PLUGIN_VERSION,
    url         = "https://github.com/F1F88/nmrih-notice"
};


#define NMR_MAXPLAYERS                      9

#define BIT_SHOW_BLEEDING                   (1 << 0)
#define BIT_SHOW_INFECTED                   (1 << 1)
#define BIT_SHOW_FF                         (1 << 2)
#define BIT_SHOW_FK                         (1 << 3)
#define BIT_SHOW_PASSWD                     (1 << 4)
#define BIT_ALL                             BIT_SHOW_BLEEDING | BIT_SHOW_INFECTED | BIT_SHOW_FF | BIT_SHOW_FK | BIT_SHOW_PASSWD
#define BIT_DEFAULT                         BIT_ALL


enum
{
    Offset_m_bIsBleedingOut,
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

Cookie          g_cookie;

int             g_offsetList[Offset_Total];

GlobalForward   g_forwardList[Forward_Total];

any             g_convarList[ConVar_Total];

// =============================== Init ===============================
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    MarkNativeAsOptional("Cookie.Cookie");
    MarkNativeAsOptional("Cookie.Get");
    MarkNativeAsOptional("Cookie.Set");
    MarkNativeAsOptional("SetCookieMenuItem");

    // Load Offset
    g_offsetList[Offset_m_bIsBleedingOut] = FindSendPropInfo("CNMRiH_Player", "_bleedingOut");
    if (g_offsetList[Offset_m_bIsBleedingOut] < 1)
    {
        SetFailState("Can't find offset CNMRiH_Player::_bleedingOut");
    }

    g_offsetList[Offset_m_bVaccinated] = FindSendPropInfo("CNMRiH_Player", "_vaccinated");
    if (g_offsetList[Offset_m_bVaccinated] < 1)
    {
        SetFailState("Can't find offset CNMRiH_Player::_vaccinated");
    }

    g_offsetList[Offset_m_flInfectionTime] = FindSendPropInfo("CNMRiH_Player", "m_flInfectionTime");
    if (g_offsetList[Offset_m_flInfectionTime] < 1)
    {
        SetFailState("Can't find offset CNMRiH_Player::m_flInfectionTime");
    }

    g_offsetList[Offset_m_flInfectionDeathTime] = FindSendPropInfo("CNMRiH_Player", "m_flInfectionDeathTime");
    if (g_offsetList[Offset_m_flInfectionDeathTime] < 1)
    {
        SetFailState("Can't find offset CNMRiH_Player::m_flInfectionDeathTime");
    }

    // Craete Natives
    CreateNative("NMR_Notice_IsBleedingOut",            Native_NMR_Notice_IsBleedingOut);
    CreateNative("NMR_Notice_IsVaccinated",             Native_NMR_Notice_IsVaccinated);
    CreateNative("NMR_Notice_IsInfected",               Native_NMR_Notice_IsInfected);
    CreateNative("NMR_Notice_GetInfectionTime",         Native_NMR_Notice_GetInfectionTime);
    CreateNative("NMR_Notice_GetInfectionDeathTime",    Native_NMR_Notice_GetInfectionDeathTime);

    // Load Forwards
    g_forwardList[Forward_bleedOut]         = new GlobalForward("NMR_Notice_OnPlayerBleedOut",          ET_Event, Param_Cell);
    g_forwardList[Forward_stopBleedingOut]  = new GlobalForward("NMR_Notice_OnPlayerStopBleedingOut",   ET_Event, Param_Cell);
    g_forwardList[Forward_becomeInfected]   = new GlobalForward("NMR_Notice_OnPlayerBecomeInfected",    ET_Event, Param_Cell, Param_Float, Param_Float);
    g_forwardList[Forward_cureInfection]    = new GlobalForward("NMR_Notice_OnPlayerCureInfection",     ET_Event, Param_Cell);

    return APLRes_Success;
}

public void OnPluginStart()
{
    // Load Traslations
    LoadTranslations("common.phrases");
    LoadTranslations("nmrih-notice.phrases");

    // Create Convars
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
    AutoExecConfig(true, PLUGIN_NAME);

    // Load GameData (Detour)
    GameData gamedata = new GameData("nmrih-notice.games");
    if (gamedata == null)
        SetFailState("Couldn't find nmrih-notice.games gamedata.");

    DynamicDetour detour;
    detour = DynamicDetour.FromConf(gamedata, "CNMRiH_Player::BleedOut");
    if (detour == null)
        SetFailState("Failed to find signature CNMRiH_Player::BleedOut");
    detour.Enable(Hook_Pre, Detour_CNMRiH_Player_BleedOut);
    delete detour;

    detour = DynamicDetour.FromConf(gamedata, "CNMRiH_Player::StopBleedingOut");
    if (detour == null)
        SetFailState("Failed to find signature CNMRiH_Player::StopBleedingOut");
    detour.Enable(Hook_Pre, Detour_CNMRiH_Player_StopBleedingOut);
    delete detour;

    detour = DynamicDetour.FromConf(gamedata, "CNMRiH_Player::BecomeInfected");
    if (detour == null)
        SetFailState("Failed to find signature CNMRiH_Player::BecomeInfected");
    detour.Enable(Hook_Pre, Detour_CNMRiH_Player_BecomeInfected);
    delete detour;

    detour = DynamicDetour.FromConf(gamedata, "CNMRiH_Player::CureInfection");
    if (detour == null)
        SetFailState("Failed to find signature CNMRiH_Player::CureInfection");
    detour.Enable(Hook_Pre, Detour_CNMRiH_Player_CureInfection);
    delete detour;
    delete gamedata;

    // Hook Events
    if (g_convarList[ConVar_notice_friend_fire])
    {
        HookEvent("player_hurt", Event_PlayerHurt);
    }

    if (g_convarList[ConVar_notice_friend_kill])
    {
        HookEvent("player_death", Event_PlayerHurt);
    }

    if (g_convarList[ConVar_notice_keycode])
    {
        HookEvent("keycode_enter", Event_PlayerHurt);
    }
}

public void OnConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    char name[64];
    convar.GetName(name, sizeof(name));

    if (StrEqual(name, "sm_notice_player_debuff_bleeding"))
    {
        g_convarList[ConVar_notice_bleeding] = convar.BoolValue;
    }
    else if (StrEqual(name, "sm_notice_player_debuff_infected"))
    {
        g_convarList[ConVar_notice_infected] = convar.BoolValue;
    }
    else if (StrEqual(name, "sm_notice_ff"))
    {
        g_convarList[ConVar_notice_friend_fire] = convar.BoolValue;
        convar.BoolValue ? HookEvent("player_hurt", Event_PlayerHurt) : UnhookEvent("player_hurt", Event_PlayerHurt);
    }
    else if (StrEqual(name, "sm_notice_fk"))
    {
        g_convarList[ConVar_notice_friend_kill] = convar.BoolValue;
        convar.BoolValue ? HookEvent("player_death", Event_PlayerDeath) : UnhookEvent("player_death", Event_PlayerDeath);
    }
    else if (StrEqual(name, "sm_notice_fk_rp"))
    {
        g_convarList[ConVar_notice_friend_kill_report] = convar.BoolValue;
    }
    else if (StrEqual(name, "sm_notice_ffmsg_interval"))
    {
        g_convarList[ConVar_notice_ffmsg_interval] = convar.FloatValue;
    }
    else if (StrEqual(name, "sm_notice_keycode_enable"))
    {
        g_convarList[ConVar_notice_keycode] = convar.BoolValue;
        convar.BoolValue ? HookEvent("keycode_enter", Event_Keycode_Enter) : UnhookEvent("keycode_enter", Event_Keycode_Enter);
    }
}

// =============================== Detour ===============================
// 玩家开始流血
MRESReturn Detour_CNMRiH_Player_BleedOut(DHookParam params)
{
    int client = params.Get(0);

    Action result;
    Call_StartForward(g_forwardList[Forward_bleedOut]);
    Call_PushCell(client);
    Call_Finish(result);
    if( result == Plugin_Handled || result == Plugin_Stop )
        return MRES_Supercede;

    return MRES_Ignored;
}

// 玩家结束流血
// Note1: 死亡不会触发
// Note2: 复活不会触发
// Note3: 使用 绷带、医疗包 后会连续触发两次
// Note4: 使用 医疗箱治疗后 只会触发一次
// Note5: 玩家 撤离后 只会触发一次
MRESReturn Detour_CNMRiH_Player_StopBleedingOut(DHookParam params)
{
    int client = params.Get(0);

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
MRESReturn Detour_CNMRiH_Player_BecomeInfected(DHookParam params)
{
    int client = params.Get(0);

    Action result;
    Call_StartForward(g_forwardList[Forward_becomeInfected]);
    Call_PushCell(client);
    Call_Finish(result);
    if( result == Plugin_Handled || result == Plugin_Stop )
        return MRES_Supercede;

    return MRES_Ignored;
}

// 玩家结束感染
// Note1: 死亡不会触发
// Note2: 复活会连续触发两次
// Note3: 使用 疫苗 后只会触发一次
MRESReturn Detour_CNMRiH_Player_CureInfection(DHookParam params)
{
    int client = params.Get(0);

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
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    if (attacker == victim || !IsValidClient(attacker) || !IsValidClient(victim))
    {
        return ;
    }

    // prevent flood
    float currentTime = GetGameTime();
    static float lastTime = 0.0;
    if (currentTime - lastTime < g_convarList[ConVar_notice_ffmsg_interval])
    {
        return ;
    }
    lastTime = currentTime;

    for (int i = 1; i <= MaxClients; ++i)
    {
        if (!IsClientInGame(i) || !CheckPrefsBit(i, BIT_SHOW_FF))
        {
            continue;
        }

        CPrintToChat(i, "%t", "Notifice_Attacked", attacker, victim);
    }
}

// 死亡通知
public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int npc = event.GetInt("npctype");
    if (npc != 0)
    {
        return ;
    }

    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    if (attacker == victim || !IsValidClient(attacker) || !IsValidClient(victim))
    {
        return ;
    }

    for (int i = 1; i <= MaxClients; ++i)
    {
        if (!IsClientInGame(i) || !CheckPrefsBit(i, BIT_SHOW_FK))
        {
            continue;
        }

        CPrintToChat(i, "%t", "Notifice_Kill", attacker, victim);
    }

    if( g_convarList[ConVar_notice_friend_kill_report] )
    {
        CPrintToChatAll("%t", "Notifice_Vote Kick", attacker);
    }
}

// 显示输入的密码
public void Event_Keycode_Enter(Event event, char[] Ename, bool dontBroadcast)
{
    char enterCode[16], correctCode[16];
    int client = event.GetInt("player");
    int keypad = event.GetInt("keypad_idx");

    event.GetString("code", enterCode, sizeof(enterCode));
    GetEntPropString(keypad, Prop_Data, "m_pszCode", correctCode, sizeof(correctCode));

    if (StrEqual(enterCode, correctCode))
    {
        for (int i = 1; i <= MaxClients; ++i)
        {
            if (!IsClientInGame(i) || !CheckPrefsBit(i, BIT_SHOW_PASSWD))
            {
                continue;
            }

            CPrintToChat(i, "%t", "Notifice_InputCorrectCode", client, enterCode);
        }
    }
    else
    {
        for (int i = 1; i <= MaxClients; ++i)
        {
            if (!IsClientInGame(i) || !CheckPrefsBit(i, BIT_SHOW_PASSWD))
            {
                continue;
            }

            CPrintToChat(i, "%t", "Notifice_InputIncorrectCode", client, enterCode);
        }
    }
}

// 提醒流血
public Action NMR_Notice_OnPlayerBleedOut(int client)
{
    for (int i = 1; i <= MaxClients; ++i)
    {
        if (!IsClientInGame(i) || !CheckPrefsBit(i, BIT_SHOW_BLEEDING))
        {
            continue;
        }

        CPrintToChat(i, "%t", "Notifice_Bleeding", client);
    }

    return Plugin_Continue;
}

// 提醒感染
public Action NMR_Notice_OnPlayerBecomeInfected(int client)
{
    if (NMR_Notice_IsVaccinated(client)) // 保险起见
    {
        return Plugin_Continue;
    }

    for (int i = 1; i <= MaxClients; ++i)
    {
        if (!IsClientInGame(i) || !CheckPrefsBit(i, BIT_SHOW_INFECTED))
        {
            continue;
        }

        CPrintToChat(i, "%t", "Notifice_Infection", client);
    }

    return Plugin_Continue;
}

// ================================= Native ==================================
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

// ================================= Stock =================================
#if !defined _gremulock_clients_methodmap_included_
stock bool IsValidClient(int client) {
    return client > 0 && client <= MaxClients && IsClientInGame(client);
}
#endif

// ================================= Client Prefs ==================================
public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual("clientprefs", name, false))
    {
        RemoveCookie();
    }
}

void RemoveCookie()
{
    if (g_cookie != null)
    {
        delete g_cookie;
    }
}

public void OnLibraryAdded(const char[] name)
{
    if (StrEqual("clientprefs", name, false))
    {
        LoadCookie();
    }
}

void LoadCookie()
{
    g_cookie = new Cookie("NMRIH Notice ClientPrefs", "NMRIH Notice ClientPrefs", CookieAccess_Private);

    SetCookieMenuItem(CookieMenuHandler, 0, "NMRIH Notice");
}

void CookieMenuHandler(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
    ShowCookiesMenu(client, 0);
}

void ShowCookiesMenu(int client, int at=0)
{
    Menu menu = new Menu(PrefsMenuHandler, MenuAction_Select | MenuAction_Cancel);
    menu.ExitBackButton = true;
    menu.SetTitle("%T", "Notifice_PrefsMenu_Title", client);

    char info[16], display[256];
    char displayDesc[256], displayOption[16];

    IntToString(BIT_SHOW_BLEEDING, info, sizeof(info));
    FormatEx(displayDesc, sizeof(displayDesc), "%T", "Notifice_PrefsMenu_Item_Bleeding", client);
    FormatEx(displayOption, sizeof(displayOption), "%T", (CheckPrefsBit(client, BIT_SHOW_BLEEDING) ? "Yes" : "No"), client);
    FormatEx(display, sizeof(display), "%s - %s", displayDesc, displayOption);
    menu.AddItem(info, display, ITEMDRAW_DEFAULT);

    IntToString(BIT_SHOW_INFECTED, info, sizeof(info));
    FormatEx(displayDesc, sizeof(displayDesc), "%T", "Notifice_PrefsMenu_Item_Infected", client);
    FormatEx(displayOption, sizeof(displayOption), "%T", (CheckPrefsBit(client, BIT_SHOW_INFECTED) ? "Yes" : "No"), client);
    FormatEx(display, sizeof(display), "%s - %s", displayDesc, displayOption);
    menu.AddItem(info, display, ITEMDRAW_DEFAULT);

    IntToString(BIT_SHOW_FF, info, sizeof(info));
    FormatEx(displayDesc, sizeof(displayDesc), "%T", "Notifice_PrefsMenu_Item_ff", client);
    FormatEx(displayOption, sizeof(displayOption), "%T", (CheckPrefsBit(client, BIT_SHOW_FF) ? "Yes" : "No"), client);
    FormatEx(display, sizeof(display), "%s - %s", displayDesc, displayOption);
    menu.AddItem(info, display, ITEMDRAW_DEFAULT);

    IntToString(BIT_SHOW_FK, info, sizeof(info));
    FormatEx(displayDesc, sizeof(displayDesc), "%T", "Notifice_PrefsMenu_Item_fk", client);
    FormatEx(displayOption, sizeof(displayOption), "%T", (CheckPrefsBit(client, BIT_SHOW_FK) ? "Yes" : "No"), client);
    FormatEx(display, sizeof(display), "%s - %s", displayDesc, displayOption);
    menu.AddItem(info, display, ITEMDRAW_DEFAULT);

    IntToString(BIT_SHOW_PASSWD, info, sizeof(info));
    FormatEx(displayDesc, sizeof(displayDesc), "%T", "Notifice_PrefsMenu_Item_passwd", client);
    FormatEx(displayOption, sizeof(displayOption), "%T", (CheckPrefsBit(client, BIT_SHOW_PASSWD) ? "Yes" : "No"), client);
    FormatEx(display, sizeof(display), "%s - %s", displayDesc, displayOption);
    menu.AddItem(info, display, ITEMDRAW_DEFAULT);

    menu.DisplayAt(client, at, 30);
}

int PrefsMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    if (!LibraryExists("clientprefs") || g_cookie == null)
    {
        delete menu;
        return 0;
    }

    switch (action)
    {
        case MenuAction_End:
        {
            delete menu;

            int option = param1;
            if (option == MenuEnd_Cancelled && option == MenuCancel_ExitBack)
            {
                ShowCookieMenu(param1);
            }
        }
        case MenuAction_Select:
        {
            int client = param1;
            int option = param2;

            // item info - bit (int)
            char info[16];
            menu.GetItem(option, info, sizeof(info));

            char oldValue[16];
            g_cookie.Get(client, oldValue, sizeof(oldValue));

            char newValue[16];
            IntToString(StringToInt(info) ^ StringToInt(oldValue), newValue, sizeof(newValue));

            g_cookie.Set(client, newValue);

            // 计算页码
            int at = RoundToFloor(Logarithm(StringToFloat(info), 2.0)) / 7 * 7;
            ShowCookiesMenu(client, at);
        }
    }
    return 0;
}

bool CheckPrefsBit(int client, int prefsBit)
{
    if (!LibraryExists("clientprefs") || g_cookie == null)
    {
        return true;
    }

    char buffer[16];
    g_cookie.Get(client, buffer, sizeof(buffer));

    return (StringToInt(buffer) & prefsBit) != 0;
}
