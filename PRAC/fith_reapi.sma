#include <amxmodx>
#include <amxmisc>
#include <reapi>
#include <engine>


#pragma semicolon 1


public plugin_init() {
	register_plugin("FITH-ReAPI", "0.1", "tobii");
	RegisterHookChain(RG_CBasePlayer_Radio, "hook_playerRadio", false);
	RegisterHookChain(RG_ThrowHeGrenade, "hook_he", true);
	RegisterHookChain(RG_ThrowFlashbang, "hook_flash", true);
	RegisterHookChain(RG_ThrowSmokeGrenade, "hook_smoke", true);
}


public hook_playerRadio(id, msg_id[], msg_verbose[], pitch, bool:showIcon) {
	if (equal(msg_verbose, "#Fire_in_the_hole")) {
		return HC_SUPERCEDE;
	}
	return HC_CONTINUE;
}


public hook_he(id) {
	new TeamName:team = get_member(id, m_iTeam);
	new szName[MAX_NAME_LENGTH];
	get_user_name(id, szName, MAX_NAME_LENGTH);
	new players[MAX_PLAYERS], p, n, TeamName:t;
	get_players_ex(players, n, GetPlayers_ExcludeBots | GetPlayers_ExcludeHLTV);
	while (--n >= 0) {
		p = players[n];
		t = get_member(p, m_iTeam);
		if ((t == team) || (t == TEAM_SPECTATOR)) {
			client_print(p, print_radio, "%s (RADIO): #Cstrike_TitlesTXT_Fire_in_the_hole >> #Cstrike_TitlesTXT_HE_Grenade", szName);
			//client_cmd(p, "spk radio/ct_fireinhole");
		}
	}
}

public hook_flash(id) {
	new TeamName:team = get_member(id, m_iTeam);
	new szName[MAX_NAME_LENGTH];
	get_user_name(id, szName, MAX_NAME_LENGTH);
	new players[MAX_PLAYERS], p, n, TeamName:t;
	get_players_ex(players, n, GetPlayers_ExcludeBots | GetPlayers_ExcludeHLTV);
	while (--n >= 0) {
		p = players[n];
		t = get_member(p, m_iTeam);
		if ((t == team) || (t == TEAM_SPECTATOR)) {
			client_print(p, print_radio, "%s (RADIO): #Cstrike_TitlesTXT_Fire_in_the_hole >> #Cstrike_TitlesTXT_Flashbang", szName);
			//client_cmd(p, "spk radio/ct_fireinhole");
		}
	}
}

public hook_smoke(id) {
	new TeamName:team = get_member(id, m_iTeam);
	new szName[MAX_NAME_LENGTH];
	get_user_name(id, szName, MAX_NAME_LENGTH);
	new players[MAX_PLAYERS], p, n, TeamName:t;
	get_players_ex(players, n, GetPlayers_ExcludeBots | GetPlayers_ExcludeHLTV);
	while (--n >= 0) {
		p = players[n];
		t = get_member(p, m_iTeam);
		if ((t == team) || (t == TEAM_SPECTATOR)) {
			client_print(p, print_radio, "%s (RADIO): #Cstrike_TitlesTXT_Fire_in_the_hole >> #Cstrike_TitlesTXT_Smoke_Grenade", szName);
			//client_cmd(p, "spk radio/ct_fireinhole");
		}
	}
}
