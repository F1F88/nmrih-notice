#include <sourcemod>
#include <dhooks>
#include <clientprefs>

#include <multicolors>

#include <nmrih_player>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_NAME                         "nmrih-notice"
#define PLUGIN_DESCRIPTION                  "Notifice the player when something happens in the game"
#define PLUGIN_VERSION                      "4.5.1"

public Plugin myinfo =
{
    name        = PLUGIN_NAME,
    author      = "F1F88",
    description = PLUGIN_DESCRIPTION,
    version     = PLUGIN_VERSION,
    url         = "https://github.com/F1F88/nmrih-notice"
};

#define BIT_SHOW_BLEEDING                   (1 << 0)
#define BIT_SHOW_INFECTED                   (1 << 1)
#define BIT_SHOW_FF                         (1 << 2)
#define BIT_SHOW_FK                         (1 << 3)
#define BIT_SHOW_PASSWD                     (1 << 4)
#define BIT_ALL                             BIT_SHOW_BLEEDING | BIT_SHOW_INFECTED | BIT_SHOW_FF | BIT_SHOW_FK | BIT_SHOW_PASSWD
#define BIT_DEFAULT                         BIT_ALL

Cookie g_cookie;

enum
{
    CV_bleedout,
    CV_ffmsg_interval,
    CV_fk_rp,

    CV_Total
}

any g_cv[CV_Total];

// =============================== Init ===============================
public void OnPluginStart()
{
    // Load Traslations
    LoadTranslations("common.phrases");
    LoadTranslations("nmrih-notice.phrases");

    // Create Convars
    CreateConVar("sm_notice_became_infected",   "1",    "提醒玩家开始感染").AddChangeHook(OnConVarChange);
    CreateConVar("sm_notice_ff",                "1",    "提醒感染玩家被队友攻击").AddChangeHook(OnConVarChange);
    CreateConVar("sm_notice_fk",                "1",    "提醒感染玩家被队友击杀").AddChangeHook(OnConVarChange);
    CreateConVar("sm_notice_keycode",           "1",    "提醒玩家输入的密码").AddChangeHook(OnConVarChange);

    ConVar convar;
    (convar = CreateConVar("sm_notice_bleedout",        "1", "提醒玩家开始流血")).AddChangeHook(OnConVarChange);
    g_cv[CV_bleedout] = convar.BoolValue;
    (convar = CreateConVar("sm_notice_ffmsg_interval",  "1.0", "重复提醒感染玩家被队友攻击的最短间隔（秒）", _, true, 0.0, true, 600.0)).AddChangeHook(OnConVarChange);
    g_cv[CV_ffmsg_interval] = convar.FloatValue;
    (convar = CreateConVar("sm_notice_fk_rp",           "0", "感染玩家被队友击杀时提醒如何举报")).AddChangeHook(OnConVarChange);
    g_cv[CV_fk_rp] = convar.BoolValue;

    AutoExecConfig(true, PLUGIN_NAME);
    CreateConVar("sm_nmrih_notice_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, FCVAR_SPONLY | FCVAR_DONTRECORD);

    // Hook
    if (FindConVar("sm_notice_became_infected").BoolValue)
    {
        HookUserMessage(GetUserMessageId("BecameInfected"), UserMsg_BecameInfected);
    }

    if (FindConVar("sm_notice_ff").BoolValue)
    {
        HookEvent("player_hurt", Event_PlayerHurt);
    }

    if (FindConVar("sm_notice_fk").BoolValue)
    {
        HookEvent("player_death", Event_PlayerDeath);
    }

    if (FindConVar("sm_notice_keycode").BoolValue)
    {
        HookEvent("keycode_enter", Event_Keycode_Enter);
    }

    LoadCookie(); // Client prefs
}

void OnConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    char name[64];
    convar.GetName(name, sizeof(name));

    if (StrEqual(name, "sm_notice_bleedout"))
    {
        g_cv[CV_bleedout] = convar.BoolValue;
    }
    else if (StrEqual(name, "sm_notice_became_infected"))
    {
        convar.BoolValue ?
            HookUserMessage(GetUserMessageId("BecameInfected"), UserMsg_BecameInfected) :
            UnhookUserMessage(GetUserMessageId("BecameInfected"), UserMsg_BecameInfected);
    }
    else if (StrEqual(name, "sm_notice_ff"))
    {
        convar.BoolValue ?
            HookEvent("player_hurt", Event_PlayerHurt) :
            UnhookEvent("player_hurt", Event_PlayerHurt);
    }
    else if (StrEqual(name, "sm_notice_fk"))
    {
        convar.BoolValue ?
            HookEvent("player_death", Event_PlayerDeath) :
            UnhookEvent("player_death", Event_PlayerDeath);
    }
    else if (StrEqual(name, "sm_notice_keycode"))
    {
        convar.BoolValue ?
            HookEvent("keycode_enter", Event_Keycode_Enter) :
            UnhookEvent("keycode_enter", Event_Keycode_Enter);
    }
    else if (StrEqual(name, "sm_notice_ffmsg_interval"))
    {
        g_cv[CV_ffmsg_interval] = convar.FloatValue;
    }
    else if (StrEqual(name, "sm_notice_fk_rp"))
    {
        g_cv[CV_fk_rp] = convar.BoolValue;
    }
}

// =============================== Notifice ===============================
// 玩家开始流血
public void OnPlayerBleedOutPost(int client)
{
    if (g_cv[CV_bleedout] && Player(client)._bleedingOut)
    {
        for (int i = 1; i <= MaxClients; ++i)
        {
            if (IsClientInGame(i) && CheckPrefsBit(i, BIT_SHOW_BLEEDING))
            {
                CPrintToChat(i, "%t", "Notifice_Bleeding", client);
            }
        }
    }
}

// 玩家开始感染
Action UserMsg_BecameInfected(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
    int client = players[0];
    for (int i = 1; i <= MaxClients; ++i)
    {
        if (IsClientInGame(i) && CheckPrefsBit(i, BIT_SHOW_INFECTED))
        {
            CPrintToChat(i, "%t", "Notifice_Infection", client);
        }
    }
    return Plugin_Continue;
}

// 感染玩家被队友攻击
void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    // prevent flood
    float currentTime = GetGameTime();
    static float lastTime = 0.0;
    if (currentTime - lastTime < g_cv[CV_ffmsg_interval])
    {
        return;
    }
    lastTime = currentTime;

    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    if (attacker != victim && IsValidClient(attacker) && IsValidClient(victim))
    {
        for (int i = 1; i <= MaxClients; ++i)
        {
            if (IsClientInGame(i) && CheckPrefsBit(i, BIT_SHOW_FF))
            {
                CPrintToChat(i, "%t", "Notifice_Attacked", attacker, victim);
            }
        }
    }
}

// 感染玩家被队友击杀
void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int npc = event.GetInt("npctype");
    if (npc != 0)
    {
        return ;
    }

    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    if (attacker != victim && IsValidClient(attacker) && IsValidClient(victim))
    {
        for (int i = 1; i <= MaxClients; ++i)
        {
            if (IsClientInGame(i) && CheckPrefsBit(i, BIT_SHOW_FK))
            {
                CPrintToChat(i, "%t", "Notifice_Kill", attacker, victim);
            }
        }

        if (g_cv[CV_fk_rp])
        {
            CPrintToChatAll("%t", "Notifice_Vote Kick", attacker);
        }
    }
}

// 玩家输入了密码
void Event_Keycode_Enter(Event event, char[] Ename, bool dontBroadcast)
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
            if (IsClientInGame(i) && CheckPrefsBit(i, BIT_SHOW_PASSWD))
            {
                CPrintToChat(i, "%t", "Notifice_InputCorrectCode", client, enterCode);
            }
        }
    }
    else
    {
        for (int i = 1; i <= MaxClients; ++i)
        {
            if (IsClientInGame(i) && CheckPrefsBit(i, BIT_SHOW_PASSWD))
            {
                CPrintToChat(i, "%t", "Notifice_InputIncorrectCode", client, enterCode);
            }
        }
    }
}

// ================================= Client Prefs ==================================
void LoadCookie()
{
    if (LibraryExists("clientprefs"))
    {
        g_cookie = new Cookie("NMRIH Notice ClientPrefs", "NMRIH Notice ClientPrefs", CookieAccess_Private);
        SetCookieMenuItem(CookieMenuHandler, 0, "NMRIH Notice");
    }
}

void CookieMenuHandler(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
    ShowCookiesMenu(client, 0);
}

void ShowCookiesMenu(int client, int at=0)
{
    if (!LibraryExists("clientprefs") || g_cookie == null)
    {
        return;
    }

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
    if (buffer[0] == 0)
    {
        return BIT_DEFAULT;
    }

    int value;
    if (StringToIntEx(buffer, value) == 0)
    {
        return BIT_DEFAULT;
    }

    return value;
}
