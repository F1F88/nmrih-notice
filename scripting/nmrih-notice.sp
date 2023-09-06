#pragma newdecls required
#pragma semicolon 1

#undef  MAXPLAYERS
#define MAXPLAYERS                          9

#include <sourcemod>
#include <sdktools>

#undef REQUIRE_EXTENSIONS
#include <clientprefs>
#define REQUIRE_EXTENSIONS

#include <multicolors>
#include <vscript_proxy>

#define PLUGIN_VERSION                      "1.1.5"
#define PLUGIN_DESCRIPTION                  "Alert the player when something happens in the game"

#define CLIENT_PREFS_BIT_SHOW_BLEEDING      (1 << 0)
#define CLIENT_PREFS_BIT_SHOW_INFECTED      (1 << 1)
#define CLIENT_PREFS_BIT_SHOW_FF            (1 << 2)
#define CLIENT_PREFS_BIT_SHOW_FK            (1 << 3)
#define CLIENT_PREFS_BIT_SHOW_PASSWD        (1 << 4)
#define CLIENT_PREFS_BIT_DEFAULT            (1 << 5) - 1

public Plugin myinfo =
{
    name        = "NMRIH Notice",
    author      = "F1F88",
    description = PLUGIN_DESCRIPTION,
    version     = PLUGIN_VERSION,
    url         = "https://github.com/F1F88/nmrih-notice"
};

enum struct client_data
{
    bool already_noticed_bleeding;
    bool already_noticed_infected;
}

int             g_offset_bleedingOut
                , g_offset_m_flInfectionTimet
                , g_offset_m_flInfectionDeathTime;

bool             cv_notice_bleeding
                , cv_notice_infected
                , cv_notice_friend_fire
                , cv_notice_friend_kill
                , cv_notice_friend_kill_report
                , cv_notice_keycode ;

float           cv_notice_scan_frequency
                , cv_notice_ffmsg_interval;

int             g_clientPrefs_value[MAXPLAYERS + 1];
Cookie          g_clientPrefs_cookie;
Handle          g_timer;
client_data     g_client_data[MAXPLAYERS + 1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    MarkNativeAsOptional("Cookie.Cookie");
    MarkNativeAsOptional("Cookie.Get");
    MarkNativeAsOptional("Cookie.GetInt");
    MarkNativeAsOptional("Cookie.Set");
    MarkNativeAsOptional("Cookie.SetInt");
    MarkNativeAsOptional("SetCookieMenuItem");

    if( (g_offset_bleedingOut = FindSendPropInfo("CNMRiH_Player", "_bleedingOut")) <= 0 )
    {
        FormatEx(error, err_max, "Can't find offset 'CNMRiH_Player::_bleedingOut'!");
        return APLRes_Failure;
    }

    if( (g_offset_m_flInfectionTimet = FindSendPropInfo("CNMRiH_Player", "m_flInfectionTime")) <= 0 )
    {
        FormatEx(error, err_max, "Can't find offset 'CNMRiH_Player::m_flInfectionTime'!");
        return APLRes_Failure;
    }

    if( (g_offset_m_flInfectionDeathTime = FindSendPropInfo("CNMRiH_Player", "m_flInfectionDeathTime")) <= 0 )
    {
        FormatEx(error, err_max, "Can't find offset 'CNMRiH_Player::m_flInfectionDeathTime'!");
        return APLRes_Failure;
    }
    return APLRes_Success;
}

public void OnPluginStart()
{
    LoadTranslations("common.phrases");
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

    CreateConVar("sm_nmrih_notice_version",             PLUGIN_VERSION, PLUGIN_DESCRIPTION, FCVAR_SPONLY | FCVAR_DONTRECORD);

    AutoExecConfig(true, "nmrih-notice");

    HookEvent("player_spawn", Event_PlayerSpawn);

    if( cv_notice_friend_fire ) {
        HookEvent("player_hurt", Event_PlayerHurt);
    }

    if( cv_notice_friend_kill ) {
        HookEvent("player_death", Event_PlayerDeath);
    }

    if( cv_notice_keycode )
    {
        HookEvent("keycode_enter", Event_Keycode_Enter);
    }

    if( LibraryExists("clientprefs") )
    {
        g_clientPrefs_cookie = new Cookie("nmrih-notice clientPrefs", "nmrih-notice clientPrefs", CookieAccess_Private);
        SetCookieMenuItem(CustomCookieMenu, 0, "NMRIH Notice");
    }
}

public void On_ConVar_Change(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if ( convar == INVALID_HANDLE )
    {
        return ;
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
            HookEvent("player_hurt", Event_PlayerHurt);
        }
        else
        {
            UnhookEvent("player_hurt", Event_PlayerHurt);
        }
    }
    else if( strcmp(convar_Name, "sm_notice_fk") == 0 )
    {
        cv_notice_friend_kill = convar.BoolValue;
        if( cv_notice_friend_kill )
        {
            HookEvent("player_death", Event_PlayerHurt);
        }
        else{
            UnhookEvent("player_death", Event_PlayerHurt);
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
            HookEvent("keycode_enter", Event_Keycode_Enter);
        }
        else
        {
            UnhookEvent("keycode_enter", Event_Keycode_Enter);
        }
    }
}

public void OnMapStart()
{
    g_timer = CreateTimer(cv_notice_scan_frequency, Timer_check_player_status, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
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
            continue ;
        }

        if( IsBleedingOut(client) )
        {
            if( cv_notice_bleeding && ! g_client_data[client].already_noticed_bleeding )
            {
                g_client_data[client].already_noticed_bleeding = true;
                for(int i=1; i<=MaxClients; ++i)
                {
                    if( IsClientInGame(i) && g_clientPrefs_value[i] & CLIENT_PREFS_BIT_SHOW_BLEEDING )
                    {
                        CPrintToChat(i, "%t", "Notifice_Bleeding", client);
                    }
                }
            }
        }
        else    // 如果已治愈则重置数据
        {
            if( g_client_data[client].already_noticed_bleeding == true )
            {
                g_client_data[client].already_noticed_bleeding = false;
            }
        }

        if( IsInfected(client) )
        {
            if( cv_notice_infected && ! g_client_data[client].already_noticed_infected )
            {
                g_client_data[client].already_noticed_infected = true;
                for(int i=1; i<=MaxClients; ++i)
                {
                    if( IsClientInGame(i) && g_clientPrefs_value[i] & CLIENT_PREFS_BIT_SHOW_INFECTED )
                    {
                        CPrintToChat(i, "%t", "Notifice_Infection", client);
                    }
                }
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

    for(int i=1; i<=MaxClients; ++i)
    {
        if( IsClientInGame(i) && g_clientPrefs_value[i] & CLIENT_PREFS_BIT_SHOW_FF )
        {
            CPrintToChat(i, "%t", "Notifice_Attacked", attacker, victim);
        }
    }
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

    for(int i=1; i<=MaxClients; ++i)
    {
        if( IsClientInGame(i) && g_clientPrefs_value[i] & CLIENT_PREFS_BIT_SHOW_FK )
        {
            CPrintToChat(i, "%t", "Notifice_Kill", attacker_client, victim_client);
        }
    }

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
    // PrintToServer("Password:| %s |", correct_code);

    if( strcmp(enter_code, correct_code) == 0 )
    {
        for(int i=1; i<=MaxClients; ++i)
        {
            if( IsClientInGame(i) && g_clientPrefs_value[i] & CLIENT_PREFS_BIT_SHOW_PASSWD )
            {
                CPrintToChat(i, "%t","Notifice_InputCorrectCode", client, enter_code);
            }
        }
    }
    else
    {
        for(int i=1; i<=MaxClients; ++i)
        {
            if( IsClientInGame(i) && g_clientPrefs_value[i] & CLIENT_PREFS_BIT_SHOW_PASSWD )
            {
                CPrintToChat(i, "%t","Notifice_InputIncorrectCode", client, enter_code);
            }
        }
    }
}

public void OnClientPutInServer(int client)
{
    g_clientPrefs_value[client] = g_clientPrefs_cookie.GetInt(client, CLIENT_PREFS_BIT_DEFAULT);
}

public void OnClientDisconnect(int client)
{
    g_clientPrefs_value[client] = 0;
}

void CustomCookieMenu(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
    ShowCookiesMenu(client, 0);
}

void ShowCookiesMenu(int client, int at=0)
{
    Menu menu_cookie = new Menu(MenuHandler_Cookies, MenuAction_Select | MenuAction_Cancel);
    menu_cookie.ExitBackButton = true;
    menu_cookie.SetTitle("%T", "Notifice_PrefsMenu_Title", client);

    char item_info[16], item_display[128];
    bool item_flag;

    item_flag = g_clientPrefs_value[client] & CLIENT_PREFS_BIT_SHOW_BLEEDING ? true : false;
    FormatEx(item_display, sizeof(item_display), "%T - %T", "Notifice_PrefsMenu_Item_Bleeding", client, item_flag ? "Yes" : "No", client);
    IntToString(CLIENT_PREFS_BIT_SHOW_BLEEDING, item_info, sizeof(item_info));
    menu_cookie.AddItem(item_info, item_display, ITEMDRAW_DEFAULT);

    item_flag = g_clientPrefs_value[client] & CLIENT_PREFS_BIT_SHOW_INFECTED ? true : false;
    FormatEx(item_display, sizeof(item_display), "%T - %T", "Notifice_PrefsMenu_Item_Infected", client, item_flag ? "Yes" : "No", client);
    IntToString(CLIENT_PREFS_BIT_SHOW_INFECTED, item_info, sizeof(item_info));
    menu_cookie.AddItem(item_info, item_display, ITEMDRAW_DEFAULT);

    item_flag = g_clientPrefs_value[client] & CLIENT_PREFS_BIT_SHOW_FF ? true : false;
    FormatEx(item_display, sizeof(item_display), "%T - %T", "Notifice_PrefsMenu_Item_ff", client, item_flag ? "Yes" : "No", client);
    IntToString(CLIENT_PREFS_BIT_SHOW_FF, item_info, sizeof(item_info));
    menu_cookie.AddItem(item_info, item_display, ITEMDRAW_DEFAULT);

    item_flag = g_clientPrefs_value[client] & CLIENT_PREFS_BIT_SHOW_FK ? true : false;
    FormatEx(item_display, sizeof(item_display), "%T - %T", "Notifice_PrefsMenu_Item_fk", client, item_flag ? "Yes" : "No", client);
    IntToString(CLIENT_PREFS_BIT_SHOW_FK, item_info, sizeof(item_info));
    menu_cookie.AddItem(item_info, item_display, ITEMDRAW_DEFAULT);

    item_flag = g_clientPrefs_value[client] & CLIENT_PREFS_BIT_SHOW_PASSWD ? true : false;
    FormatEx(item_display, sizeof(item_display), "%T - %T", "Notifice_PrefsMenu_Item_passwd", client, item_flag ? "Yes" : "No", client);
    IntToString(CLIENT_PREFS_BIT_SHOW_PASSWD, item_info, sizeof(item_info));
    menu_cookie.AddItem(item_info, item_display, ITEMDRAW_DEFAULT);

    menu_cookie.DisplayAt(client, at, 30);
}

int MenuHandler_Cookies(Menu menu, MenuAction action, int param1, int param2)
{
    switch( action )
    {
        case MenuAction_Cancel:
        {
            delete menu;
            switch( param2 )
            {
                case MenuCancel_ExitBack:
                {
                    ShowCookieMenu(param1);
                }
            }
            return 0;
        }
        case MenuAction_Select:
        {
            char item_info[16];   // int - bit info
            menu.GetItem(param2, item_info, sizeof(item_info));

            g_clientPrefs_value[param1] ^= StringToInt(item_info);
            g_clientPrefs_cookie.SetInt(param1, g_clientPrefs_value[param1]);

            ShowCookiesMenu(param1, RoundToFloor(Logarithm(StringToFloat(item_info), 2.0)) / 7 * 7);
        }
    }
    return 0;
}

stock bool IsBleedingOut(int client)
{
    return GetEntData(client, g_offset_bleedingOut, 1) == 1;
}

stock bool IsInfected(int client)
{
    return GetEntDataFloat(client, g_offset_m_flInfectionTimet) > 0.0 && FloatCompare(GetEntDataFloat(client, g_offset_m_flInfectionDeathTime), GetGameTime()) == 1;
}

stock bool IsValidClient(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client);
}