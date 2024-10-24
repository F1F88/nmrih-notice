#include <sourcemod>
#include <dhooks>
#include <clientprefs>

#include <multicolors>
#include <nmrih_player>

#pragma newdecls required
#pragma semicolon 1

#include <nmrih-notice>


#define PLUGIN_NAME                         "nmrih-notice"
#define PLUGIN_DESCRIPTION                  "Alert the player when something happens in the game"
#define PLUGIN_VERSION                      "3.0.8"

public Plugin myinfo =
{
    name        = PLUGIN_NAME,
    author      = "F1F88",
    description = PLUGIN_DESCRIPTION,
    version     = PLUGIN_VERSION,
    url         = "https://github.com/F1F88/nmrih-notice"
};

#if !defined NMR_MAXPLAYERS
#define NMR_MAXPLAYERS                      9
#endif

#define BIT_SHOW_BLEEDING                   (1 << 0)
#define BIT_SHOW_INFECTED                   (1 << 1)
#define BIT_SHOW_FF                         (1 << 2)
#define BIT_SHOW_FK                         (1 << 3)
#define BIT_SHOW_PASSWD                     (1 << 4)
#define BIT_ALL                             BIT_SHOW_BLEEDING | BIT_SHOW_INFECTED | BIT_SHOW_FF | BIT_SHOW_FK | BIT_SHOW_PASSWD
#define BIT_DEFAULT                         BIT_ALL


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

GlobalForward   g_forwardList[Forward_Total];

any             g_convarList[ConVar_Total];

// =============================== Init ===============================
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
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

    // Hook Events
    if (g_convarList[ConVar_notice_friend_fire])
    {
        HookEvent("player_hurt", Event_PlayerHurt);
    }

    if (g_convarList[ConVar_notice_friend_kill])
    {
        HookEvent("player_death", Event_PlayerDeath);
    }

    if (g_convarList[ConVar_notice_keycode])
    {
        HookEvent("keycode_enter", Event_Keycode_Enter);
    }

    // Client prefs
    LoadCookie();
}

void OnConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
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

// ================================= Natives ==================================
any Native_NMR_Notice_IsBleedingOut(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (!IsValidClient(client))
        ThrowNativeError(SP_ERROR_PARAM, "Invalid client (%d).", client);

    return NMR_Player(client).IsBleedingOut();
}

any Native_NMR_Notice_IsVaccinated(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (!IsValidClient(client))
        ThrowNativeError(SP_ERROR_PARAM, "Invalid client (%d).", client);

    return NMR_Player(client).IsVaccinated();
}

any Native_NMR_Notice_IsInfected(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (!IsValidClient(client))
        ThrowNativeError(SP_ERROR_PARAM, "Invalid client (%d).", client);

    return NMR_Player(client).IsInfected();
}

any Native_NMR_Notice_GetInfectionTime(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (!IsValidClient(client))
        ThrowNativeError(SP_ERROR_PARAM, "Invalid client (%d).", client);

    return NMR_Player(client).m_flInfectionTime;
}

any Native_NMR_Notice_GetInfectionDeathTime(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    if (!IsValidClient(client))
        ThrowNativeError(SP_ERROR_PARAM, "Invalid client (%d).", client);

    return NMR_Player(client).m_flInfectionDeathTime;
}

// =============================== Forwards ===============================
// 玩家开始流血
public Action OnPlayerBleedOut(int client)
{
    Action result;
    Call_StartForward(g_forwardList[Forward_bleedOut]);
    Call_PushCell(client);
    Call_Finish(result);
    return result;
}

// 玩家结束流血
// Note1: 死亡不会触发
// Note2: 复活不会触发
// Note3: 使用 绷带、医疗包 后会连续触发两次
// Note4: 使用 医疗箱治疗后 只会触发一次
// Note5: 玩家 撤离后 只会触发一次
public Action OnPlayerStopBleedingOut(int client)
{
    Action result;
    Call_StartForward(g_forwardList[Forward_stopBleedingOut]);
    Call_PushCell(client);
    Call_Finish(result);
    return result;
}

// 玩家开始感染
// Note1: 即使已注射疫苗仍会触发此绕行
public Action OnPlayerBecomeInfected(int client)
{
    Action result;
    Call_StartForward(g_forwardList[Forward_becomeInfected]);
    Call_PushCell(client);
    Call_Finish(result);
    return result;
}

// 玩家结束感染
// Note1: 死亡不会触发
// Note2: 复活会连续触发两次
// Note3: 使用 疫苗 后只会触发一次
public Action OnPlayerCureInfection(int client)
{
    Action result;
    Call_StartForward(g_forwardList[Forward_cureInfection]);
    Call_PushCell(client);
    Call_Finish(result);
    return result;
}

// =============================== Notifice ===============================
// 感染玩家被攻击通知
void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_convarList[ConVar_notice_friend_fire])
    {
        return;
    }

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
void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_convarList[ConVar_notice_friend_kill])
    {
        return;
    }

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
void Event_Keycode_Enter(Event event, char[] Ename, bool dontBroadcast)
{
    if (!g_convarList[ConVar_notice_keycode])
    {
        return;
    }

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
public void OnPlayerBleedOutPost(int client)
{
    if (!g_convarList[ConVar_notice_bleeding])
        return;

    for (int i = 1; i <= MaxClients; ++i)
    {
        if (!IsClientInGame(i) || !CheckPrefsBit(i, BIT_SHOW_BLEEDING))
        {
            continue;
        }

        CPrintToChat(i, "%t", "Notifice_Bleeding", client);
    }
}

// 提醒感染
public void OnPlayerBecomeInfectedPost(int client)
{
    if (!g_convarList[ConVar_notice_infected])
        return;

    if (!IsValidClient(client) || NMR_Player(client).IsVaccinated()) // 保险起见
        return;

    for (int i = 1; i <= MaxClients; ++i)
    {
        if (!IsClientInGame(i) || !CheckPrefsBit(i, BIT_SHOW_INFECTED))
        {
            continue;
        }

        CPrintToChat(i, "%t", "Notifice_Infection", client);
    }
}

// ================================= Client Prefs ==================================
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

            int reverseBit = StringToInt(info);

            char newValue[16];
            IntToString(reverseBit ^ GetCookieValue(client), newValue, sizeof(newValue));

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
    return (GetCookieValue(client) & prefsBit) != 0;
}

int GetCookieValue(int client)
{
    if (!LibraryExists("clientprefs") || g_cookie == null)
    {
        return BIT_DEFAULT;
    }

    char buffer[16];
    g_cookie.Get(client, buffer, sizeof(buffer));
    if (!buffer[0])
    {
        return BIT_DEFAULT;
    }

    int value;
    if (!StringToIntEx(buffer, value))
    {
        return BIT_DEFAULT;
    }

    return value;
}
