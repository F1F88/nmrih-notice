#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION	   "1.0.0"

public Plugin myinfo =
{
    name        = "Player highlight",
    author      = "F1F88",
    description = "Alert the player when something happens in the game",
    version     = PLUGIN_VERSION,
    url         = "https://github.com/F1F88/nmrih-notice"
};

#include <sourcemod>
#include <sdktools>
#include <multicolors>
#include <vscript_proxy>

enum struct client_data {
    bool already_noticed_bleeding;
    bool already_noticed_infected;
}

bool             cv_notice_bleeding
                , cv_notice_infected
                , cv_notice_friend_fire
                , cv_notice_friend_kill
                , cv_notice_friend_kill_report
                , cv_notice_keycode ;

float           cv_notice_scan_frequency
                , cv_notice_ffmsg_interval;

Handle          g_timer;
client_data     g_client_data[MAXPLAYERS + 1];
int             g_vscript_proxy;

public void OnPluginStart()
{
    LoadTranslations("nmrih-notice.phrases");

    ConVar convar;
    (convar = CreateConVar("sm_notice_scan_feq",        "0.2", "检查玩家是否感染的速率 (越小检查越快, 性能消耗越大。单位-秒)", _, true, 0.1)).AddChangeHook(On_ConVar_Change);
    cv_notice_scan_frequency = convar.FloatValue;
    (convar = CreateConVar("sm_notice_bleeding",        "1", "在聊天框提示玩家流血")).AddChangeHook(On_ConVar_Change);
    cv_notice_bleeding = convar.BoolValue;
    (convar = CreateConVar("sm_notice_infected",        "1", "在聊天框提示玩家感染")).AddChangeHook(On_ConVar_Change);
    cv_notice_infected = convar.BoolValue;

    (convar = CreateConVar("sm_notice_ff",              "1", "在聊天框提示队友攻击")).AddChangeHook(On_ConVar_Change);
    cv_notice_friend_fire = convar.BoolValue;
    (convar = CreateConVar("sm_notice_fk",              "1", "在聊天框提示队友击杀")).AddChangeHook(On_ConVar_Change);
    cv_notice_friend_kill = convar.BoolValue;
    (convar = CreateConVar("sm_notice_fk_rp",           "0", "在聊天框提示队友击杀如何举报")).AddChangeHook(On_ConVar_Change);
    cv_notice_friend_kill_report = convar.BoolValue;
    (convar = CreateConVar("sm_notice_ffmsg_interval",  "1.0", "队友攻击的每条消息之间最短时间间隔（秒）")).AddChangeHook(On_ConVar_Change);
    cv_notice_ffmsg_interval = convar.FloatValue;

    (convar = CreateConVar("sm_notice_keycode",         "1", "键盘输入事件提示类型 | 0: 关闭 | 1: 显示输入的密码 | ")).AddChangeHook(On_ConVar_Change);
    cv_notice_keycode = convar.BoolValue;

    CreateConVar("sm_nmrih_notice_version",             PLUGIN_VERSION);

    AutoExecConfig(true, "nmrih-notice");

    HookEvent("nmrih_reset_map",                        Event_Reset_Map);
    HookEvent("player_spawn",                           Event_PlayerSpawn);

    if( cv_notice_friend_fire ) {
        HookEvent("player_hurt",                        Event_PlayerHurt);
    }

    if( cv_notice_friend_kill ) {
        HookEvent("player_death",                       Event_PlayerDeath);
    }

    if( cv_notice_keycode )
    {
        HookEvent("keycode_enter",                      Event_Keycode_Enter);
    }
}

public void On_ConVar_Change(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if ( convar == INVALID_HANDLE )
    {
        return;
    }
    char convar_Name[64];
    convar.GetName(convar_Name, 64);

    if( strcmp(convar_Name, "sm_notice_player_debuff_scan_feq") == 0 )
    {
        cv_notice_scan_frequency = convar.FloatValue;
        if( g_timer != INVALID_HANDLE )
        {
            CloseHandle(g_timer);
        }
        g_timer = CreateTimer(cv_notice_scan_frequency, Timer_check_player_status, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    }
    else if( strcmp(convar_Name, "sm_notice_player_debuff_bleeding") == 0 )
    {
        cv_notice_bleeding = convar.BoolValue;
    }
    else if( strcmp(convar_Name, "sm_notice_player_debuff_infected") == 0 )
    {
        cv_notice_infected = convar.BoolValue;
    }
    else if( strcmp(convar_Name, "sm_notice_ff") == 0 )
    {
        cv_notice_friend_fire = convar.BoolValue;
        if( cv_notice_friend_fire )
        {
            HookEvent("player_hurt",                    Event_PlayerHurt);
        }
        else
        {
            UnhookEvent("player_hurt",                  Event_PlayerHurt);
        }
    }
    else if( strcmp(convar_Name, "sm_notice_fk") == 0 )
    {
        cv_notice_friend_kill = convar.BoolValue;
        if( cv_notice_friend_kill )
        {
            HookEvent("player_death",                   Event_PlayerHurt);
        }
        else{
            UnhookEvent("player_death",                 Event_PlayerHurt);
        }
    }
    else if( strcmp(convar_Name, "sm_notice_fk_rp") == 0 )
    {
        cv_notice_friend_kill_report = convar.BoolValue;
    }
    else if( strcmp(convar_Name, "sm_notice_ffmsg_interval") == 0 )
    {
        cv_notice_ffmsg_interval = convar.FloatValue;
    }
    else if( strcmp(convar_Name, "sm_notice_keycode_enable") == 0 )
    {
        cv_notice_keycode = convar.BoolValue;
        if( cv_notice_keycode )
        {
            HookEvent("keycode_enter",                  Event_Keycode_Enter);
        }
        else
        {
            UnhookEvent("keycode_enter",                Event_Keycode_Enter);
        }
    }
}

public void OnMapStart()
{
    if( g_vscript_proxy <= 0 )
    {
        g_vscript_proxy = GetVscriptProxy();
    }
    g_timer = CreateTimer(cv_notice_scan_frequency, Timer_check_player_status, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void Event_Reset_Map(Event event, const char[] name, bool dontBroadcast)
{
    g_vscript_proxy = GetVscriptProxy();
}

// 玩家复活时初始化流血、感染数组
public void Event_PlayerSpawn(Event event, char[] name, bool bDontBroadcast )
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    g_client_data[client].already_noticed_bleeding = false;
    g_client_data[client].already_noticed_infected = false;
}

// 每隔一段时间检查玩家是否流血、感染
public Action Timer_check_player_status(Handle timer, any data)
{
    static int client;
    for( client=1; client<=MaxClients; ++client )
    {
        if( ! IsClientInGame(client) || ! IsPlayerAlive(client) )
        {
            return Plugin_Continue;
        }

        if( GetEntProp(client, Prop_Send, "_bleedingOut") == 1 )
        {
            if( cv_notice_bleeding && ! g_client_data[client].already_noticed_bleeding )
            {
                g_client_data[client].already_noticed_bleeding = true;
                CPrintToChatAll("%t", "Notifice_Bleeding", client);
            }
        }
        else    // 如果已治愈则重置数据
        {

            if( g_client_data[client].already_noticed_bleeding == true )
            {
                g_client_data[client].already_noticed_bleeding = false;
            }
        }

        if( RunEntVScriptBool(client, "IsInfected()", g_vscript_proxy) == true )
        {
            if( cv_notice_infected && ! g_client_data[client].already_noticed_infected )
            {
                g_client_data[client].already_noticed_infected = true;
                CPrintToChatAll("%t", "Notifice_Infection", client);
            }
        }
        else    // 如果已治愈则重置数据
        {
            if( g_client_data[client].already_noticed_infected == true )
            {
                g_client_data[client].already_noticed_infected = false;
            }
        }
    }
    return Plugin_Continue;
}


// 感染玩家被攻击通知
public void Event_PlayerHurt(Event hEvent, char[] szEventName, bool bDontBroadcast )
{
    float curTime = GetGameTime();
    static float lastTime = 0.0;
    int victim = GetClientOfUserId( GetEventInt( hEvent, "userid" ) );
    int attacker = GetClientOfUserId( GetEventInt( hEvent, "attacker" ) );

    if( curTime - lastTime < cv_notice_ffmsg_interval || victim == attacker || ! IsValidClient(attacker) || ! IsValidClient(victim) )
    {
        return ;
    }

    lastTime = curTime;

    CPrintToChatAll("%t", "Notifice_Attacked", attacker, victim);
}

// 死亡通知
public void Event_PlayerDeath(Event hEvent, char[] szEventName, bool bDontBroadcast )
{
    int victim_client = GetClientOfUserId( GetEventInt(hEvent, "userid") );
    if( ! IsValidClient(victim_client) )
    {
        return ;
    }

    if( GetEventInt( hEvent, "npctype" ) != 0 )
    {
        return ;
    }

    int attacker_client = GetClientOfUserId( GetEventInt( hEvent, "attacker" ) );
    if( victim_client == attacker_client || ! IsValidClient(attacker_client) )
    {
        return;
    }

    CPrintToChatAll("%t", "Notifice_Kill", attacker_client, victim_client);
    if( cv_notice_friend_kill_report )
    {
        CPrintToChatAll("%t", "Notifice_Vote Kick", attacker_client);
    }
}


// 显示输入的密码
public void Event_Keycode_Enter(Event event, char[] Ename, bool dontBroadcast)
{
    char enter_code[16], correct_code[16];
    int client = event.GetInt("player");
    int keypad = event.GetInt("keypad_idx");

    event.GetString("code", enter_code, 16);
    GetEntPropString(keypad, Prop_Data, "m_pszCode", correct_code, 16);

    if( strcmp(enter_code, correct_code) == 0 )
        CPrintToChatAll("%t","Notifice_InputCorrectCode", client, enter_code);
    else
        CPrintToChatAll("%t","Notifice_InputIncorrectCode", client, enter_code);
}


stock int GetVscriptProxy()
{
    int proxy = CreateEntityByName("logic_script_proxy");
    if( proxy == -1 )
    {
        ThrowError("Failed to Get VScript proxy.");
    }
    // DispatchSpawn(proxy);
    return proxy;
}

stock bool IsValidClient(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client);
}