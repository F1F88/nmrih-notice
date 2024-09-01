#include <sourcemod>
#include <dhooks>

#include <multicolors>

#include <nmrih_player>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_NAME                         "nmrih-notice"
#define PLUGIN_DESCRIPTION                  "Notifice the player when something happens in the game"
#define PLUGIN_VERSION                      "5.0.0"

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
    // CV_became_infected,                  // 钩子即可
    // CV_ff,
    // CV_fk,
    // CV_keycode,

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
public void OnPlayerBleedOutPost(int client) // nmrih_player api
{
    if (g_cv[CV_bleedout] && NMR_Player(client)._bleedingOut)
    {
        CPrintToChatAll("%t", "Notifice_Bleeding", client);
    }
}

// 玩家开始感染
Action UserMsg_BecameInfected(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init)
{
    RequestFrame(Frame_NotificePlayerBecameInfected, GetClientUserId(players[0]));
    return Plugin_Continue;
}

void Frame_NotificePlayerBecameInfected(int userid)
{
    int client = GetClientOfUserId(userid);
    if (IsValidClient(client) && NMR_Player(client).IsInfected()) // IsInfected() 应该是冗余的判断, 但安全起见, 而且不太可能影响性能
    {
        CPrintToChatAll("%t", "Notifice_Infection", client);
    }
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
        CPrintToChatAll("%t", "Notifice_Attacked", attacker, victim);
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
        CPrintToChatAll("%t", "Notifice_Kill", attacker, victim);

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
        CPrintToChatAll("%t", "Notifice_InputCorrectCode", client, enterCode);
    }
    else
    {
        CPrintToChatAll("%t", "Notifice_InputIncorrectCode", client, enterCode);
    }
}
