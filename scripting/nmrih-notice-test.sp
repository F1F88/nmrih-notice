#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>

#include <nmrih-notice>                     // native and forward


#define PLUGIN_NAME                         "NMRIH Notice Test"
#define PLUGIN_DESCRIPTION                  "Test NMRIH Notice Func"
#define PLUGIN_VERSION                      "2.0.0"


public Plugin myinfo =
{
    name        = PLUGIN_NAME,
    author      = "F1F88",
    description = PLUGIN_DESCRIPTION,
    version     = PLUGIN_VERSION,
    url         = "https://github.com/F1F88/nmrih-notice"
};

public void OnPluginStart()
{
    RegConsoleCmd("sm_nmr_notice_test_native", CMD_test_native);
}

Action CMD_test_native(int client, int args)
{
    for(int i=1; i<=MaxClients; ++i)
    {
        if( ! IsClientInGame(i) )
            continue ;

        bool isBleedingOut          = NMR_Notice_IsBleedingOut(i);
        bool isInfected             = NMR_Notice_IsInfected(i);
        float infectionTime         = NMR_Notice_GetInfectionTime(i);
        float infectionDeathTime    = NMR_Notice_GetInfectionDeathTime(i);

        PrintToServer("[NMR-Notice-Test]  %d - %N | %d | %d | %f | %f |"
            , i, i, isBleedingOut, isInfected, infectionTime, infectionDeathTime
        );

        PrintToChatAll("[NMR-Notice-Test]  %d - %N | %d | %d | %f | %f |"
            , i, i, isBleedingOut, isInfected, infectionTime, infectionDeathTime
        );
    }
    return Plugin_Handled;
}

public Action NMR_Notice_OnPlayerBleedOut(int client)
{
    PrintToServer("[NMR-Notice-Test] %d - %N BleedOut", client, client);
    PrintToChatAll("[NMR-Notice-Test] %d - %N BleedOut", client, client);
    return Plugin_Continue;
}

public Action NMR_Notice_OnPlayerStopBleedingOut(int client)
{
    PrintToServer("[NMR-Notice-Test] %d - %N StopBleedingOut", client, client);
    PrintToChatAll("[NMR-Notice-Test] %d - %N StopBleedingOut", client, client);
    return Plugin_Continue;
}

public Action NMR_Notice_OnPlayerBecomeInfected(int client)
{
    PrintToServer("[NMR-Notice-Test] %d - %N BecomeInfected | %f | %f |", client, client);
    PrintToChatAll("[NMR-Notice-Test] %d - %N BecomeInfected | %f | %f |", client, client);
    return Plugin_Continue;
}

public Action NMR_Notice_OnPlayerCureInfection(int client)
{
    PrintToServer("[NMR-Notice-Test] %d - %N CureInfection", client, client);
    PrintToChatAll("[NMR-Notice-Test] %d - %N CureInfection", client, client);
    return Plugin_Continue;
}
