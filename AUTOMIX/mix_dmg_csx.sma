#include <amxmodx>
#include <amxmisc>
#include <csx>
#include <reapi>


//used to clear vectors
#define VEC_33_CLEAR {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
#define DELAY 0.3


new g_cvarEnabled;

new HookChain:g_hookChainSpawn;
new HookChain:g_hookChainDeath;

new g_hudSync;

new g_iDmgDealt[33][33]; //[attacker][receiver] adj. matrix of damage dealt
new g_iShotsHit[33][33]; //[attacker][receiver] adj. matrix of shots hit


public plugin_init() {
	register_plugin("Mix-DMG-CSX", "0.1", "tobii");

	g_cvarEnabled = register_cvar("mp_display_dmg", "1"); //display dmg on death

	register_clcmd("dmg", "hook_say_dmg");
	register_clcmd("say .dmg", "hook_say_dmg");
	register_clcmd("say_team .dmg", "hook_say_dmg");

	g_hookChainSpawn = RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn", true);
	g_hookChainDeath = RegisterHookChain(RG_CSGameRules_DeathNotice, "CSGameRules_DeathNotice", true);

	g_hudSync = CreateHudSyncObj();
}


public plugin_cfg() {
	hook_cvar_change(g_cvarEnabled, "hook_cvar_enabled_changed"); //detect cvar changes to register/unregister hooks
}


public client_damage(attacker, victim, damage, wpnindex, hitplace, TA) {
	g_iDmgDealt[attacker][victim]+=damage;
	g_iShotsHit[attacker][victim]++;
	return PLUGIN_CONTINUE;
}


public hook_cvar_enabled_changed() {
	for (new i=1; i<=MaxClients; i++) {
		g_iDmgDealt[i] = VEC_33_CLEAR;
		g_iShotsHit[i] = VEC_33_CLEAR;
	}
	if (get_pcvar_bool(g_cvarEnabled)) {
		EnableHookChain(g_hookChainSpawn);
		EnableHookChain(g_hookChainDeath);
	} else {
		DisableHookChain(g_hookChainSpawn);
		DisableHookChain(g_hookChainDeath);
	}
}


public hook_say_dmg(id) {
	if (is_user_connected(id)) {
		if (get_pcvar_bool(g_cvarEnabled) ) {
			if (is_user_alive(id)) {
				client_print(id, print_chat, "You are not allowed to use this command while alive.");
			} else {
				show_stats_chat(id);
			}
		}
	}
	return PLUGIN_HANDLED;
}


public CBasePlayer_Spawn(id) {
	show_stats(id);
	g_iShotsHit[id] = VEC_33_CLEAR;
	g_iDmgDealt[id] = VEC_33_CLEAR;
}




public CSGameRules_DeathNotice(victimEntIndex, killerEntIndex, inflictorEntIndex) {
	set_task(DELAY, "show_stats", victimEntIndex);
	return PLUGIN_CONTINUE;
}


public show_stats(id) {
	if (is_user_connected(id)) {
		new szName[MAX_NAME_LENGTH+1];
		new szTmpStats[charsmax(szName) + 64];
		new lenTmp;
		new szStatsDealt[MAX_PLAYERS*charsmax(szTmpStats) + 1];
		new lenDealt;
		new dmgDealt, shotsDealt, dmgDealtTotal, shotsDealtTotal;
		for (new tmpPlayer=1; tmpPlayer<=MaxClients; tmpPlayer++) {
			if (tmpPlayer != id) { //dont show damage done to self
				shotsDealt = g_iShotsHit[id][tmpPlayer];
				if (shotsDealt) {
					dmgDealt = g_iDmgDealt[id][tmpPlayer];
					get_user_name(tmpPlayer, szName, charsmax(szName));
					lenTmp = formatex(szTmpStats, charsmax(szTmpStats), "^n%4d / %2d  -->  %s", dmgDealt, shotsDealt, szName);
					client_print(id, print_console, "*  Damage dealt to ^"%s^": %d in %d hits.", szName, dmgDealt, shotsDealt);
					copy(szStatsDealt[lenDealt], lenTmp, szTmpStats); //copy seems to work
					lenDealt += lenTmp;
					dmgDealtTotal += dmgDealt;
					shotsDealtTotal += shotsDealt;
				}
			}
		}
		if (shotsDealtTotal) {
			client_print(id, print_console, "*    TOTAL DAMAGE DEALT: %5d /%4d.", dmgDealtTotal, shotsDealtTotal);
			set_hudmessage(100,200,150, 0.1,-1.0, 1,6.0, 12.0, 0.1,0.2);
			ShowSyncHudMsg(id, g_hudSync, " ** DAMAGE **%s", szStatsDealt);
		}
	}
}


public show_stats_chat(id) {
	new szName[MAX_NAME_LENGTH+1];
	new dmgDealt, shotsDealt;
	new bool:bDidDamage = false;
	for (new tmpPlayer=1; tmpPlayer<=MaxClients; tmpPlayer++) {
		if (tmpPlayer != id) { //dont show damage done to self
			shotsDealt = g_iShotsHit[id][tmpPlayer];
			if (shotsDealt) {
				dmgDealt = g_iDmgDealt[id][tmpPlayer];
				get_user_name(tmpPlayer, szName, charsmax(szName));
				client_print_color(id, print_team_grey, "^4%5d ^3/ ^4%2d  ^3>>> ^3%s", dmgDealt, shotsDealt, szName);
				bDidDamage = true;
			}
		}
	}
	if (!bDidDamage) {
		client_print(id, print_team_grey, "^3You did no damage this round.");
	}
}


#pragma semicolon 1
