#include <amxmodx>
#include <amxconst>
#include <amxmisc>
#include <cstrike>
#include <reapi>

//TODO refactor to ReAPI methods (easier to read & faster to load)

#define PLUGIN	"Mix-ReAPI"
#define VERSION "0.4"
#define AUTHOR	"tobii"

#define cfg(%1) "exec pug_reapi/" + #%1 + ".cfg"

#define VOTE_TASK_ID 127

new bool:g_bLive = false;
new bool:g_bGamePaused = false; //is the game currently paused? (say /pause)

enum eMixState {
	N, //normal
	W, //warmup
	K, //knife
	L, //live
	O, //overtime
};
new eMixState:gameState = N; //default

new g_iScoreTs, g_iScoreCTs, g_iScoreTotal, g_iScoreLastTie; //store the scores //TODO reapi has a method for this, need to test it
new g_msgTeamScore; //used for updating team scores on the scoreboard
new g_msgScoreInfo; //user for updating player scores on the scoreboard
new g_iFrags[MAX_PLAYERS+1];
new g_iDeaths[MAX_PLAYERS+1];


new g_menuVoteSide; //voting menu for stay/switch
new g_iVotesCounter[2]; //voting results
new g_iVotingPlayersCounter; //how many players are currently voting
new CsTeams:g_knifeWinnerTeam = CS_TEAM_UNASSIGNED; //team that won the knife round

new g_hudMoneyCTs, g_hudMoneyTs; //hud sync ids for displaying money msg

new bool:g_bDemoRecording = false;
new g_szDemoName[256];
new g_iDemoCounter = 0;



public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);

	//admin cmds
	register_clcmd("say /warmup", "clcmd_say_warmup");
	register_clcmd("say /normal", "clcmd_say_normal");
	register_clcmd("say /spec", "clcmd_say_spec");
	register_clcmd("say /live", "clcmd_say_live");
	register_clcmd("say /stop", "clcmd_say_stop");

	register_clcmd("say /pause", "clcmd_say_pause");
	register_clcmd("say /unpause", "clcmd_say_unpause");

	//user cmds starting
	register_clcmd("say .score", "clcmd_say_score");
	register_clcmd("say .demo", "clcmd_say_demo");

	register_clcmd("say .money", "clcmd_say_money");
	register_clcmd("say_team .money", "clcmd_say_money");
	register_clcmd("say $", "clcmd_say_money");
	register_clcmd("say_team $", "clcmd_say_money");
	register_clcmd("say .$", "clcmd_say_money");
	register_clcmd("say_team .$", "clcmd_say_money");

	g_hudMoneyCTs = CreateHudSyncObj();
	g_hudMoneyTs = CreateHudSyncObj();

	g_msgTeamScore = get_user_msgid("TeamScore");
	g_msgScoreInfo = get_user_msgid("ScoreInfo");

	register_message(g_msgTeamScore, "hook_teamscore"); //hook teamscore msg last

	RegisterHookChain(RG_CBasePlayer_Spawn, "hook_spawn", true); //called POST spawn
	RegisterHookChain(RG_RoundEnd, "hook_round_end", false); //pre round end
	RegisterHookChain(RG_CSGameRules_CleanUpMap, "hook_freezetime_start", true); // post freezetime start
	RegisterHookChain(RG_CSGameRules_OnRoundFreezeEnd, "hook_freezetime_end", true); //post freezetime end
}


public hook_spawn(id) {
	if ((gameState == W) && is_user_alive(id)) {
		cs_set_user_money(id, 16000, 1);
	}
}


public hook_round_end(WinStatus:status, ScenarioEventEndRound:event, Float:tmDelay) {
	if (event == ROUND_GAME_COMMENCE) {
		//set_member_game(m_bGameStarted, true);
		SetHookChainReturn(ATYPE_BOOL, false);
		return HC_SUPERCEDE;
	} else if (g_bLive && (event != ROUND_GAME_RESTART)) {
		if (status == WINSTATUS_TERRORISTS) {
			g_iScoreTs++;
			g_knifeWinnerTeam = CS_TEAM_T;
		} else if (status == WINSTATUS_CTS) {
			g_knifeWinnerTeam = CS_TEAM_CT;
			g_iScoreCTs++;
		}
		g_iScoreTotal = g_iScoreTs + g_iScoreCTs;
		switch (gameState) {
			case K: {
				if (g_knifeWinnerTeam != CS_TEAM_UNASSIGNED) {
					set_task(0.3, "vote_swap");
				}
			} case L: {
				if (g_iScoreTotal == 15) {
					_get_stats();
					rg_swap_all_players(); //test this
					_scores_swap();
					server_cmd("sv_restart 3");
					set_task(3.2, "_set_stats");
				} else if (g_iScoreTs >= 16) {
					display_T_win_msg();
					end_match();
				} else if (g_iScoreCTs >= 16) {
					display_CT_win_msg();
					end_match();
				} else if (g_iScoreTotal >= 30) {
					g_iScoreLastTie = 15;
					_get_stats();
					_start(O);
					server_cmd("sv_restart 3");
					set_task(3.2, "_set_stats");
				}
			} case O: {
				if (g_iScoreTotal == (g_iScoreLastTie*2)+3) { //overtime swap
					rg_swap_all_players(); //test this
					_get_stats();
					_scores_swap();
					server_cmd("sv_restart 3");
					set_task(3.2, "_set_stats");
				} else if (g_iScoreTs >= g_iScoreLastTie+4) { //Ts win overtime
					display_T_win_msg();
					end_match();
				} else if (g_iScoreCTs >= g_iScoreLastTie+4) { //CTs win overtime
					display_CT_win_msg();
					end_match();
				} else if ((g_iScoreTs == g_iScoreLastTie+3) && (g_iScoreCTs == g_iScoreLastTie+3)) { //another draw, do more overime
					g_iScoreLastTie = g_iScoreTs;
					_get_stats();
					_start(O);
					server_cmd("sv_restart 3");
					set_task(3.2, "_set_stats");
				}
			}
		}
	}
	return HC_CONTINUE;
}


public hook_freezetime_start() {
	switch (gameState) {
		case W: {
			client_print(0, print_chat, "WARMUP :: RESPAWNING ENABLED");
		} case K: {
			client_print(0, print_chat, "LIVE :: KNIFE ROUND");
			//set_member_game(m_bGameStarted, true);
		} case L: {
			if (g_iScoreTotal < 15) {
				client_print(0, print_chat, "LIVE :: FIRST HALF -- ROUND #%d", g_iScoreTotal+1);
			} else {
				client_print(0, print_chat, "LIVE :: SECOND HALF -- ROUND #%d", g_iScoreTotal+1);
			}
			_util_print_scores(0);
		} case O: {
			if (g_iScoreTotal < 15) {
				client_print(0, print_chat, "LIVE :: OVERTIME -- FIRST HALF -- ROUND #%d", g_iScoreTotal+1);
			} else {
				client_print(0, print_chat, "LIVE :: OVERTIME -- SECOND HALF -- ROUND #%d", g_iScoreTotal+1);
			}
			_util_print_scores(0);
		}
	}
}
public hook_freezetime_end() {
	//TODO do we need to do anything here?
}


public hook_teamscore(iMsgId, msgDest , iMsgEntity) {
	if (g_bLive) {
		new szTeam[2];
		get_msg_arg_string(1, szTeam, charsmax(szTeam));
		if (szTeam[0] == 'T') {
			set_msg_arg_int(2, ARG_SHORT, g_iScoreTs); //set msg arg to display "REAL Ts (mix)" score
		} else if (szTeam[0] == 'C') {
			set_msg_arg_int(2, ARG_SHORT, g_iScoreCTs); //same but for CTs
		}
	}
	return PLUGIN_CONTINUE;
}


public server_cfg() {
	server_cmd(cfg(default)); //load default settings
}


public _start(eMixState:x) {
	switch (x) {
		case N: {
			gameState = N;
			server_cmd(cfg(default));
			client_print(0, print_chat, "Game is now in normal mode, respawning is off.");
			g_bLive = false;
		} case W: {
			gameState = W;
			server_cmd(cfg(warmup));
			client_print(0, print_chat, "Warmup has started. Enjoy!");
			g_bLive = false;
		} case K: {
			gameState = K;
			server_cmd(cfg(knife));
			_scores_reset();
			g_bLive = true;
			//set_member_game(m_bGameStarted, true);
		} case L: {
			demo_record();
			gameState = L;
			_scores_reset();
			server_cmd(cfg(live));
			g_bLive = true;
		} case O: {
			gameState = O;
			server_cmd(cfg(extra));
			g_bLive = true;
		}
	}
}


public end_match() {
	_scores_reset();
	g_bLive = false;
	if (g_bDemoRecording) {
		demo_stop();
	}
	_start(W);
	server_cmd("sv_restart 3");
}


public clcmd_say_warmup(id) {
	if (get_user_flags(id) & ADMIN_LEVEL_H) {
		if (g_bLive) {
			client_print(id, print_chat, "Stop the match before entering warmup.");
			return PLUGIN_HANDLED;
		} else {
			_start(W);
			server_cmd("sv_restart 1");
		}
	} else {
		client_print(id, print_chat, "You must be admin to use that command.");
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}


public clcmd_say_normal(id) {
	if (get_user_flags(id) & ADMIN_LEVEL_H) {
		if (g_bLive) {
			client_print(id, print_chat, "Stop the match before entering normal mode.");
			return PLUGIN_HANDLED;
		} else {
			_start(N);
			server_cmd("sv_restart 1");
		}
	} else {
		client_print(id, print_chat, "You must be admin to use that command.");
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}


public clcmd_say_spec(id) {
	if (get_user_flags(id) & ADMIN_LEVEL_H) {
		if (g_bLive) {
			client_print(id, print_chat, "Game is live. Can't transfer to spectator.");
			return PLUGIN_HANDLED;
		} else {
			new players[32], num, player;
			get_players_ex(players, num, GetPlayers_ExcludeHLTV);
			client_print(0, print_chat, "Transferring players to spectators");
			for (new i=0; i<num; i++) {
				player = players[i];
				user_silentkill(player);
				cs_set_user_team(player, CS_TEAM_SPECTATOR);
			}
			rg_restart_round();
		}
	} else {
		client_print(id, print_chat, "You must be admin to use that command.");
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}


public clcmd_say_live(id) {
	if (get_user_flags(id) & ADMIN_LEVEL_H) {
		if (g_bLive) { //called only in warmup or normal state
			client_print(id, print_chat, "Game is already live!");
			return PLUGIN_HANDLED;
		} else {
			_start(K);
			//set_member_game(m_bGameStarted, true);
			server_cmd("sv_restart 1");
		}
	} else {
		client_print(id, print_chat, "You must be admin to use that command.");
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}


public clcmd_say_stop(id) {
	if (get_user_flags(id) & ADMIN_LEVEL_H) {
		if (g_bLive) {
			end_match();
		} else {
			client_print(id, print_chat, "Match is not live...");
			return PLUGIN_HANDLED;
		}
	} else {
		client_print(id, print_chat, "You must be admin to use that command.");
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}

public clcmd_say_pause(id) {
	if (get_user_flags(id) & ADMIN_LEVEL_H) {
		if (g_bGamePaused) {
			client_print(id, print_chat, "Game is alreaded paused. Type /unpause if you want to unpause");
		} else {
			g_bGamePaused = true;
			server_cmd("pausable 1");
			client_cmd(id, "pause");
			client_print(0, print_chat, "Game has been paused.");
		}
	} else {
		client_print(id, print_chat, "You must be admin to use that command.");
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}
public clcmd_say_unpause(id) {
	if (get_user_flags(id) & ADMIN_LEVEL_H) {
		if (g_bGamePaused) {
			g_bGamePaused = false;
			client_cmd(id, "pause");
			client_print(0, print_chat, "Game has been unpaused! LIVE LIVE LIVE!");
		} else {
			client_print(id, print_chat, "Game is already live. Type /pause if you want to pause.");
		}
	} else {
		client_print(id, print_chat, "You must be admin to use that command.");
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}


public clcmd_say_score(id) {
	if (g_bLive) {
		_util_print_scores(id);
	} else {
		client_print(id, print_chat, "Match has to be live to show score.");
	}
	return PLUGIN_HANDLED;
}

public clcmd_say_demo(id) {
	if (g_bLive) {
		client_print(id, print_chat, "Recording demo: cstrike/%s.dem", g_szDemoName);
	} else {
		client_print(id, print_chat, "Match has to be live before demo recording starts.");
	}
	return PLUGIN_HANDLED;
}

public clcmd_say_money(id) {
	new CsTeams:team = cs_get_user_team(id);
	switch (team) {
		case CS_TEAM_SPECTATOR: {
			_show_money_t(id);
			_show_money_ct(id);
		} case CS_TEAM_T: {
			_show_money_t(id);
		} case CS_TEAM_CT: {
			_show_money_ct(id);
		}
	}
	return PLUGIN_HANDLED;
}


_scores_swap() {
	new tmp = g_iScoreTs;
	g_iScoreTs = g_iScoreCTs;
	g_iScoreCTs = tmp;
}
_scores_reset() {
	g_iScoreTs = 0;
	g_iScoreCTs = 0;
	g_iScoreTotal = 0;
}
_util_print_scores(id) {
	if (id) {
		new CsTeams:team = cs_get_user_team(id);
		switch (team) {
			case CS_TEAM_SPECTATOR: {
				client_print_color(id, print_team_grey, "^3[^4%d^3] CT ^1||^3 T [^4%d^3]", g_iScoreCTs, g_iScoreTs);
			} case CS_TEAM_T: {
				client_print_color(id, print_team_grey, "^3[^1%d^3] CT ^1||^3 T [^4%d^3]", g_iScoreCTs, g_iScoreTs);
			} case CS_TEAM_CT: {
				client_print_color(id, print_team_grey, "^3[^4%d^3] CT ^1||^3 T [^1%d^3]", g_iScoreCTs, g_iScoreTs);
			}
		}
	} else {
		new players[32], n;
		get_players_ex(players, n, GetPlayers_ExcludeBots | GetPlayers_ExcludeHLTV);
		while (n>0) _util_print_scores(players[--n]);
	}
}

demo_record() {
	new szMapName[MAX_MAPNAME_LENGTH+1];
	get_mapname(szMapName, charsmax(szMapName));
	new szTime[26]; //1999-11-30_23h58m19s+100
	get_time("%F_%Hh%Mm%Ss_%z", szTime, charsmax(szTime));
	
	formatex(g_szDemoName, charsmax(g_szDemoName), "MIX[%s][%s]", szMapName, szTime); //demo name len = 64 + 26 + 9 + 2 + 1
	client_cmd(0, "record %s", g_szDemoName);
	g_bDemoRecording = true;
}
demo_stop() {
	client_print(0, print_console, "Saving demo: cstrike/%s.dem", g_szDemoName);
	client_cmd(0, "stop");
	g_bDemoRecording = false;
}


public client_putinserver(id) {
	if (!is_user_hltv(id) && !is_user_bot(id) && g_bDemoRecording) {
		set_task(2.0, "client_record_after_disconnect", id);
	}
	return PLUGIN_CONTINUE;
}
public client_record_after_disconnect(id) {
	client_cmd(id, "record %s_%i", g_szDemoName, ++g_iDemoCounter);
}



display_T_win_msg() {
	set_dhudmessage(255,100,50, -1.0,-1.0, 0,0.5, 45.0, 0.08,2.0);
	show_dhudmessage(0, "TERRORISTS WON THE MATCH!");
}

display_CT_win_msg() {
	set_dhudmessage(50,150,255, -1.0,-1.0, 0,0.5, 45.0, 0.08,2.0);
	show_dhudmessage(0, "COUNTER-TERRORISTS WON THE MATCH!");
}


public vote_swap() {
	g_iVotingPlayersCounter = 0;
	g_iVotesCounter[0] = 0;
	g_iVotesCounter[1] = 0;
	g_menuVoteSide = menu_create("\rChoose option:", "menu_handler");
	menu_additem(g_menuVoteSide, "Stay", "", 0);
	menu_additem(g_menuVoteSide, "Switch", "", 0);
	new players[32], pnum, id;
	get_players_ex(players, pnum, GetPlayers_ExcludeBots | GetPlayers_ExcludeHLTV);
	for (new i=0; i<pnum; i++) {
		id = players[i];
		if (cs_get_user_team(id) == g_knifeWinnerTeam) {
			menu_display(id, g_menuVoteSide, 0);
			g_iVotingPlayersCounter++; //Increase how many players are voting
		}
	}
	set_task(10.0, "task_count_votes", VOTE_TASK_ID); //End the vote in 10 seconds
	return PLUGIN_HANDLED;
}

public menu_handler(id, menu, item) {
	if (g_iVotingPlayersCounter && (item != MENU_EXIT)) {
		g_iVotesCounter[item]++; //then count that vote
		g_iVotingPlayersCounter--; //they can only cast one vote
		if (g_iVotingPlayersCounter == 0) { //if all players have voted
			remove_task(VOTE_TASK_ID); // we dont all need to wait the whole 10s for the results
			task_count_votes(); //because we can count them right now
		}
	}
	return PLUGIN_HANDLED; //then we are done...
}

public task_count_votes() {
	menu_destroy(g_menuVoteSide);
	if (g_iVotesCounter[0] > g_iVotesCounter[1]) { //first option recieved the most votes (stay)
		client_print(0, print_chat, "The voting result is STAY!");
	} else if (g_iVotesCounter[0] < g_iVotesCounter[1]) { //second option recieved the most votes (switch)
		client_print(0, print_chat, "The voting result is SWITCH!");
		rg_swap_all_players();
	} else { //the vote tied
		client_print(0, print_chat, "The vote was a tie, so the result is STAY.");
	}
	_start(L); //start first half
	server_cmd("sv_restart 1");
}


//helper funcs for money
public _show_money_ct(id) {
	new szName[MAX_NAME_LENGTH+1];
	new szTmpLine[charsmax(szName)+9], lenTmp, lenTotal;
	new szMoney[charsmax(szTmpLine)*32];
	new players[32], num, tmp;
	get_players_ex(players, num, GetPlayers_MatchTeam, "CT");
	for (new i=0; i<num; i++) {
		tmp = players[i];
		get_user_name(tmp, szName, charsmax(szName));
		lenTmp = formatex(szTmpLine, charsmax(szTmpLine), "^n$%6d  %s", cs_get_user_money(tmp), szName);
		copy(szMoney[lenTotal], lenTmp, szTmpLine);
		lenTotal += lenTmp;
	}
	set_hudmessage(0,100,200, 0.2,0.2, 0,6.0, 12.0,0.1,0.2, -1);
	ShowSyncHudMsg(id, g_hudMoneyCTs, "CT's FINANCIAL REPORT: %s", szMoney);
}
public _show_money_t(id) {
	new szName[MAX_NAME_LENGTH+1];
	new szTmpLine[charsmax(szName)+9], lenTmp, lenTotal;
	new szMoney[charsmax(szTmpLine)*32];
	new players[32], num, tmp;
	get_players_ex(players, num, GetPlayers_MatchTeam, "TERRORIST");
	for (new i=0; i<num; i++) {
		tmp = players[i];
		get_user_name(tmp, szName, charsmax(szName));
		lenTmp = formatex(szTmpLine, charsmax(szTmpLine), "^n$%6d  %s", cs_get_user_money(tmp), szName);
		copy(szMoney[lenTotal], lenTmp, szTmpLine);
		lenTotal += lenTmp;
	}
	set_hudmessage(200,100,0, 0.7,0.7, 0,6.0, 12.0,0.1,0.2, -1);
	ShowSyncHudMsg(id, g_hudMoneyTs, "T's JIHAD BUDGET: %s", szMoney);
}

public _get_stats() {
	new players[MAX_PLAYERS], n, p;
	get_players_ex(players, n, GetPlayers_ExcludeHLTV);
	for (new i=0; i<n; i++) {
		p = players[i];
		g_iFrags[p] = floatround(Float:get_entvar(p, var_frags));
		g_iDeaths[p] = get_member(p, m_iDeaths);
		client_print(p, print_console, "**DEBUG** _get_stats()");
	}
}
public _set_stats() {
	new players[MAX_PLAYERS], n, p, f, d;
	get_players_ex(players, n, GetPlayers_ExcludeHLTV);
	for (new i=0; i<n; i++) {
		p = players[i];
		f = g_iFrags[p];
		d = g_iDeaths[p];
		set_entvar(p, var_frags, float(f));
		set_member(p, m_iDeaths, d);
		message_begin(MSG_ALL, g_msgScoreInfo); //https://wiki.alliedmods.net/Half-life_1_game_events#ScoreInfo
		write_byte(p); //player id
		write_short(f); //frags
		write_short(d); //deaths
		write_short(0); //classId is always 0 @cs1.6
		write_short(0); //teamId http://www.amxmodx.org/api/cstrike_const#counter-strike-team-id-constants
		message_end();
		//client_print(p, print_console, "_set_stats()");
	}
}


#pragma semicolon 1
