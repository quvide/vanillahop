#include <sourcemod>
#include <clientprefs>

public Plugin:myinfo =
{
	name = "vanillahop",
	author = "viderizer",
	description = "hold space to jump!",
	version = "0.3",
	url = ""
};

bool autohopEnabled[MAXPLAYERS + 1] = {true, ...};
ConVar sm_autohop_enabled;
ConVar sm_bhop_enabled;
ConVar sv_staminajumpcost;
ConVar sv_staminalandcost;
ConVar sv_enablebunnyhopping;
float staminajumpcost;
float staminalandcost;
bool enablebunnyhopping
Handle cookie_sm_autohop;

public void OnPluginStart()
{
	AutoExecConfig(true);

	// Server-side
	sm_autohop_enabled = CreateConVar("sm_autohop_enable", "1", "Enables autohop (0/1)", FCVAR_NOTIFY);
	sm_bhop_enabled = CreateConVar("sm_bhop_enable", "1", "Enables bhop (0/1)", FCVAR_NOTIFY);

	// Store stamina costs - when bhop is enabled they will be set to 0,
	// we will restore them if bhop is turned off
	// Useful for eg. warmpup time only bunnyhopping
	sv_staminajumpcost = FindConVar("sv_staminajumpcost");
	sv_staminalandcost = FindConVar("sv_staminalandcost");
	sv_enablebunnyhopping = FindConVar("sv_enablebunnyhopping")
	// fake onbhopchange to save original values and enable minimal bunnyhopping settings
	OnBhopChange(sm_bhop_enabled, "", "");
	HookConVarChange(sm_bhop_enabled, OnBhopChange);

	// Client-side
	RegConsoleCmd("sm_autohop", command_sm_autohop);
	cookie_sm_autohop = RegClientCookie("sm_autohop", "enable autohop", CookieAccess_Private);

	// Lateload client cookies
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientConnected(i) && IsClientInGame(i) && AreClientCookiesCached(i)) {
			OnClientCookiesCached(i);
		}
	}
}

public void OnBhopChange(ConVar cvar, const char[] oldValue, const char[] newValue)
{
	if (cvar.BoolValue) {
		// Save original values and enable minimal bhop settings
		staminajumpcost = sv_staminajumpcost.FloatValue;
		staminalandcost = sv_staminalandcost.FloatValue;
		enablebunnyhopping = sv_staminajumpcost.BoolValue;
		sv_staminajumpcost.FloatValue = 0.0;
		sv_staminalandcost.FloatValue = 0.0;
		sv_enablebunnyhopping.BoolValue = true;
	} else {
		// Restore original values
		sv_staminajumpcost.FloatValue = staminajumpcost;
		sv_staminalandcost.FloatValue = staminalandcost;
		sv_enablebunnyhopping.BoolValue = enablebunnyhopping;
	}
}

public Action command_sm_autohop(int client, int argc)
{
	// Toggle per-client autohop
	autohopEnabled[client] = !autohopEnabled[client];

	if (AreClientCookiesCached(client)) {
		SetClientCookie(client, cookie_sm_autohop, autohopEnabled[client] ? "1" : "0");
	}

	ReplyToCommand(client, "Type \x07/autohop\x01 to %s autohop again!", autohopEnabled[client] ? "disable" : "enable");

	return Plugin_Handled;
}

public void OnClientCookiesCached(int client) {
	// Read cookie from client
	char cookieBuffer[2];
	GetClientCookie(client, cookie_sm_autohop, cookieBuffer, sizeof cookieBuffer);
	autohopEnabled[client] = StringToInt(cookieBuffer) ? true : false;
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	/*
		Explanation:
		Bunnyhopping traditionally works by jumping again on the same tick you hit the ground.
		We fake your buttons so that the server thinks you are not holding space while in air
		and hit it just as you hit the ground.
	*/
	if (sm_bhop_enabled.BoolValue && sm_autohop_enabled.BoolValue && autohopEnabled[client] && IsPlayerAlive(client) && !(GetEntityFlags(client) & FL_ONGROUND) && !(GetEntityMoveType(client) & MOVETYPE_LADDER) && GetEntProp(client, Prop_Data, "m_nWaterLevel") <= 1) {
		buttons &= ~IN_JUMP;
	}

	return Plugin_Continue;
}
