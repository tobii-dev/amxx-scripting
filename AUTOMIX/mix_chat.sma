#include <amxmodx>
#include <amxmisc> //get_players_ex()
#include <cstrike> //CsTeams:


#pragma semicolon 1


new g_msgSayText;

new const szChannel[][] = {
	"#Cstrike_Chat_T",
	"#Cstrike_Chat_T_Dead",
	"#Cstrike_Chat_CT",
	"#Cstrike_Chat_CT_Dead",
	"#Cstrike_Chat_Spec",
	"#Cstrike_Chat_AllSpec",
	"#Cstrike_Chat_All",
	"#Cstrike_Chat_AllDead",
};


stock _get_channel(CsTeams:team, bool:isAlive, bool:isTeam) {
	new ch = 6; //Cstrike_Chat_All
	if (isTeam) {
		switch (team) {
			case CS_TEAM_T: {
				ch = 0; //Cstrike_Chat_T
			} case CS_TEAM_CT: {
				ch = 2; //Cstrike_Chat_CT
			} case CS_TEAM_SPECTATOR: {
				ch = 4; //Cstrike_Chat_Spec
			} 
		}
	}
	return isAlive ? ch : ch+1;
}


public plugin_init() {
	register_plugin("MIX-Chat", "0.3", "tobii");
	g_msgSayText = get_user_msgid("SayText");
}


public plugin_cfg() {
	register_clcmd("say", "clcmd_say");
	register_clcmd("say_team", "clcmd_say_team");
}


public clcmd_say(id) {
	new szMsg[192];
	read_args(szMsg, sizeof(szMsg));
	remove_quotes(szMsg);
	trim(szMsg);
	if (szMsg[0]) {
		new bool:isAlive = (is_user_alive(id) != 0);
		new CsTeams:team = cs_get_user_team(id);
		new ch = _get_channel(team, isAlive, false);
		message_begin(MSG_ALL, g_msgSayText);
		write_byte(id);
		write_string(szChannel[ch]);
		write_string("");
		write_string(szMsg);
		message_end();
	}
	return PLUGIN_HANDLED;
}


public clcmd_say_team(id) {
	new szMsg[192];
	read_args(szMsg, sizeof(szMsg));
	remove_quotes(szMsg);
	trim(szMsg);
	if (szMsg[0]) {
		new bool:isAlive = (is_user_alive(id) != 0);
		new CsTeams:team = cs_get_user_team(id);
		new ch = _get_channel(team, isAlive, true);
		new players[MAX_PLAYERS], p, n, CsTeams:t;
		get_players_ex(players, n, GetPlayers_ExcludeBots);
		while (--n >= 0) {
			p = players[n];
			t = cs_get_user_team(p);
			if ((t == team) || (t == CS_TEAM_SPECTATOR)) {
				message_begin(MSG_ONE, g_msgSayText, .player=p);
				write_byte(id);
				write_string(szChannel[ch]);
				write_string("");
				write_string(szMsg);
				message_end();
			}
		}
	}
	return PLUGIN_HANDLED;
}
