
#undef REQUIRE_EXTENSIONS
#include <clientprefs>
#define REQUIRE_EXTENSIONS

#pragma newdecls required
#pragma semicolon 1


#define CLIENT_PREFS_BIT_SHOW_BLEEDING      (1 << 0)
#define CLIENT_PREFS_BIT_SHOW_INFECTED      (1 << 1)
#define CLIENT_PREFS_BIT_SHOW_FF            (1 << 2)
#define CLIENT_PREFS_BIT_SHOW_FK            (1 << 3)
#define CLIENT_PREFS_BIT_SHOW_PASSWD        (1 << 4)
#define CLIENT_PREFS_BIT_ALL                CLIENT_PREFS_BIT_SHOW_BLEEDING|CLIENT_PREFS_BIT_SHOW_INFECTED|CLIENT_PREFS_BIT_SHOW_FF|CLIENT_PREFS_BIT_SHOW_FK|CLIENT_PREFS_BIT_SHOW_PASSWD
#define CLIENT_PREFS_BIT_DEFAULT            CLIENT_PREFS_BIT_ALL


bool            clientPrefs_libExists;
int             clientPrefs_clientData[MAXPLAYERS + 1];
Cookie          clientPrefs_cookie;

void ClientPrefs_MarkNativeAsOptional()
{
    MarkNativeAsOptional("Cookie.Cookie");
    MarkNativeAsOptional("Cookie.Get");
    MarkNativeAsOptional("Cookie.GetInt");
    MarkNativeAsOptional("Cookie.Set");
    MarkNativeAsOptional("Cookie.SetInt");
    MarkNativeAsOptional("SetCookieMenuItem");
}

void ClientPrefs_LoadCookie()
{
    clientPrefs_cookie = new Cookie("nmrih-notice clientPrefs", "nmrih-notice clientPrefs", CookieAccess_Private);
    SetCookieMenuItem(ClientPrefs_CookieMenuHandler, 0, "NMRIH Notice");
}

bool ClientPrefs_CheckLibExistsAndLoad()
{
    clientPrefs_libExists = LibraryExists("clientprefs");

    // 如果 clientprefs 存在, 且插件未加载 ClientPrefs Cookie
    if( clientPrefs_libExists && ( ! clientPrefs_cookie || clientPrefs_cookie == null || clientPrefs_cookie == INVALID_HANDLE) )
    {
        ClientPrefs_LoadCookie();
    }

    return clientPrefs_libExists;
}

void ClientPrefs_ReadClientData(int client)
{
    if( ! clientPrefs_libExists )
        return ;

    clientPrefs_clientData[client] = clientPrefs_cookie.GetInt(client, CLIENT_PREFS_BIT_DEFAULT);
}

void ClientPrefs_ResetClientData(int client)
{
    clientPrefs_clientData[client] = CLIENT_PREFS_BIT_DEFAULT;
}

bool ClientPrefs_CanPrint(int client, int bit)
{
    if( ! clientPrefs_libExists )
        return true;

    return clientPrefs_clientData[client] & bit != 0;
}


void ClientPrefs_CookieMenuHandler(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
    ClientPrefs_ShowCookiesMenu(client, 0);
}

void ClientPrefs_ShowCookiesMenu(int client, int at=0)
{
    if( ! clientPrefs_libExists )
        return ;

    Menu menu = new Menu(ClientPrefs_MenuHandler_Cookies, MenuAction_Select | MenuAction_Cancel);
    menu.ExitBackButton = true;
    menu.SetTitle("%T", "Notifice_PrefsMenu_Title", client);

    ClientPrefs_AddBitItem(g_convarList[ConVar_notice_bleeding],    menu, client, CLIENT_PREFS_BIT_SHOW_BLEEDING,    "Notifice_PrefsMenu_Item_Bleeding");
    ClientPrefs_AddBitItem(g_convarList[ConVar_notice_infected],    menu, client, CLIENT_PREFS_BIT_SHOW_INFECTED,    "Notifice_PrefsMenu_Item_Infected");
    ClientPrefs_AddBitItem(g_convarList[ConVar_notice_friend_fire], menu, client, CLIENT_PREFS_BIT_SHOW_FF,          "Notifice_PrefsMenu_Item_ff");
    ClientPrefs_AddBitItem(g_convarList[ConVar_notice_friend_kill], menu, client, CLIENT_PREFS_BIT_SHOW_FK,          "Notifice_PrefsMenu_Item_fk");
    ClientPrefs_AddBitItem(g_convarList[ConVar_notice_keycode],     menu, client, CLIENT_PREFS_BIT_SHOW_PASSWD,      "Notifice_PrefsMenu_Item_passwd");

    menu.DisplayAt(client, at, 30);
}

int ClientPrefs_MenuHandler_Cookies(Menu menu, MenuAction action, int param1, int param2)
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
            char item_info[16];   // int - bit info
            menu.GetItem(param2, item_info, sizeof(item_info));                 // 读取选择的 item 的 item info (对应的 bit 位)

            clientPrefs_clientData[param1] ^= StringToInt(item_info);           // 翻转选择的 bit
            clientPrefs_cookie.SetInt(param1, clientPrefs_clientData[param1]);  // 存储新值

            ClientPrefs_ShowCookiesMenu(param1, ClientPrefs_GetBitAtPage(StringToFloat(item_info)));
        }
    }
    return 0;
}

void ClientPrefs_AddBitItem(bool convarFlag, Menu menu, int client, int bit, const char[] phrases)
{
    if( ! convarFlag )
        return ;

    bool item_flag = clientPrefs_clientData[client] & bit ? true : false;
    char item_info[16], item_display[128];
    FormatEx(item_display, sizeof(item_display), "%T - %T", phrases, client, item_flag ? "Yes" : "No", client);
    IntToString(bit, item_info, sizeof(item_info));
    menu.AddItem(item_info, item_display, ITEMDRAW_DEFAULT);
}

int ClientPrefs_GetBitAtPage(float bit)
{
    return RoundToFloor(Logarithm(bit, 2.0)) / 7 * 7;
}

void ClientPrefs_LoadLate()
{
    for( int client=1; client<=MaxClients; ++client )
    {
        if( ! IsClientInGame(client) )
            continue ;

        clientPrefs_clientData[client] = CLIENT_PREFS_BIT_DEFAULT;
    }
}
