#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <csx>
#include <reapi>
#include <reapi_gamedll>
#include <reapi_engine>
#include <bot_api>
#include <engine>


#define X 0
#define Y 1
#define Z 2

#define PITCH 0
#define YAW 1
#define ROLL 2

#define HEAD_BONE 8

//amxconst.inc
/*
new const g_szHitboxName[][] = {
	"GENERIC",
	"HEAD",
	"CHEST",
	"STOMACH",
	"LEFTARM",
	"RIGHTARM",
	"LEFTLEG",
	"RIGHTLEG",
	"SHIELD"
}
*/

//new const g_szHangman[] = "[O]^n[=][T][=]^n[|]^n[][]^n_[][]_";
//new const g_szHangman[] = "[]^n[ ][  ][ ]^n[   ]^n[][]^n_[][]_";
//new const g_szHangman[] = "0^n>--[ ]--<^n[ ]^n[| |]^n_]] [[_";

new const g_szHangman[] = "  [ ]^n [ ][ ][ ]^n [ ]^n  [ ] [ ]^n  [ ] [ ]"

new const g_szHitboxName[][] = {
	"   X ^n  X  X  X ^n  X ^n   X   X ^n   X   X ", //generic
	"   X ^n          ^n    ^n         ^n         ", //head
	"     ^n     X    ^n    ^n         ^n         ", //chest
	"     ^n          ^n  X ^n         ^n         ", //stomach
	"     ^n  X       ^n    ^n         ^n         ", //la
	"     ^n        X ^n    ^n         ^n         ", //ra
	"     ^n          ^n    ^n   X     ^n   X     ", //ll
	"     ^n          ^n    ^n       X ^n       X ", //rl
	"     ^n          ^n    ^n         ^n         "  //sh
}


new g_hudSyncDmg, g_hudSyncHit, g_hudSyncFig;


new g_iCounter;
new g_iMnnqn[MAX_PLAYERS+1];
new g_iOwner[MAX_PLAYERS+1];
new Float:g_flOrigin[MAX_PLAYERS+1][3];
new Float:g_flAngles[MAX_PLAYERS+1][3];
new g_iFlags[MAX_PLAYERS+1];
new g_iArmorValue[MAX_PLAYERS+1]
new	CsArmorType:g_armorType[MAX_PLAYERS+1];
new CsTeams:g_csTeam[MAX_PLAYERS+1];
new CsInternalModel:g_csMdl[MAX_PLAYERS+1];
new g_subMdl[MAX_PLAYERS+1];
new g_wpnId[MAX_PLAYERS+1];

new g_cvarEnabled;
new HookChain:g_hookSpawn;
new HookChain:g_hookDeathNotice;


public plugin_init() {
	register_plugin("Mannequin", "0.2", "tobii");

	register_clcmd("nightvision", "hook_nightvison");
	register_clcmd("radio3", "hook_radio3");
	register_impulse(201, "hook_impulse_201");

	g_hookSpawn = RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn", true);
	g_hookDeathNotice = RegisterHookChain(RG_CSGameRules_DeathNotice, "CSGameRules_DeathNotice", true);
	
	g_hudSyncDmg = CreateHudSyncObj();
	g_hudSyncHit = CreateHudSyncObj();
	g_hudSyncFig = CreateHudSyncObj();
	new cvarEnabled = create_cvar("sv_mannequin", "1", FCVAR_NONE, "Enables <1> or disables <0> spawning mannequins ", true, 0.0, true, 1.0);
	hook_cvar_change(cvarEnabled, "hook_cvar_enabled");
	bind_pcvar_num(cvarEnabled, g_cvarEnabled);
}



public OnConfigsExecuted() {
	hook_cvar_enabled();
}


public hook_cvar_enabled() {
	if (g_cvarEnabled) {
		EnableHookChain(g_hookSpawn);
		EnableHookChain(g_hookDeathNotice);
	} else {
		DisableHookChain(g_hookSpawn);
		DisableHookChain(g_hookDeathNotice);
		
		new id;
		new szName[MAX_NAME_LENGTH+1];
		for (new i = 0; i < sizeof(g_iOwner); i++) {
			if (is_bot(i)) {
				get_user_name(i, szName, charsmax(szName));
				id = g_iOwner[i];
				if (is_user_connected(id)) client_print_color(id, print_team_grey, "^1[^4%s^1] ^3REMOVED (auto)", szName);
				remove_bot(i);
			}
			g_iOwner[i] = 0;
		}
		for (new i = 0; i < sizeof(g_iMnnqn); i++) {
			g_iMnnqn[i] = 0;
		}
	}
}


public plugin_cfg() {
}


public hook_nightvison(id) {
	if (!g_cvarEnabled) return PLUGIN_CONTINUE;
	if (is_user_connected(id)) {
		if (is_user_alive(id)) {
			new mnqn = g_iMnnqn[id];
			if (mnqn) {
				if (get_user_button(id) & IN_USE) {
					_save_mannequin(id, mnqn);
				} else {
					//client_print(id, print_chat, "SPAWN");
					rg_join_team(mnqn, TEAM_TERRORIST);
					_spawn_mannequin(mnqn);
				}
			}
		}
	}
	return PLUGIN_HANDLED;
}


//create new bot
public hook_radio3(id) {
	if (!g_cvarEnabled) return PLUGIN_CONTINUE;
	if (is_user_connected(id)) {
		if (is_user_alive(id)) {
			new bttns = get_user_button(id);
			if (bttns & IN_USE) {
				new szTmp[32];
				formatex(szTmp, charsmax(szTmp), "_%d", g_iCounter++);
				// new bot = create_bot("BOT");
				new bot = create_bot(szTmp);
				client_print_color(id, print_team_grey, "^1[^4%02d^1] ^3CREATE", bot); // #DEBUG
				if (bot) {
					//new szName[3+1+2+1]; //"BOT_##\n"
					//formatex(szName, sizeof(szName), "BOT_%02d", bot);
					//set_user_info(bot, "name", szName);
					//client_print(id, print_chat, "NEW_BOT");
					g_iOwner[bot] = id;
					g_iMnnqn[id] = bot;
					_save_mannequin(id, bot);
					engclient_cmd(bot, "jointeam", "1");
					engclient_cmd(bot, "joinclass", "5");
					rg_join_team(bot, TEAM_TERRORIST);
					client_print_color(id, print_team_grey, "^1[^4%02d^1] ^3JOIN", bot); // #DEBUG
					_spawn_mannequin(bot);
				} else {
					client_print(id, print_chat, "Failed to create bot");
				}
			} else if (bttns & IN_RELOAD) {
				_menu_bot(id, true); //remove bot by using menu
			} else {
				_menu_bot(id, false); //select bot by using menu
			}
		}
	}
	return PLUGIN_HANDLED;
}


public hook_impulse_201(id, impulse) {
	if (!g_cvarEnabled) return PLUGIN_CONTINUE;
	new mnnqn = g_iMnnqn[id];
	if (mnnqn) {
		if (is_user_alive(mnnqn)) {
			set_aim_at_head(id, mnnqn);
		} else {
			client_print(id, print_chat, "ERROR: BOT DEAD");
		}
	}
	return PLUGIN_HANDLED;
}



public _save_mannequin(id, bot) {
	get_entvar(id, var_origin, g_flOrigin[bot]);
	get_entvar(id, var_angles, g_flAngles[bot]);
	g_iFlags[bot] = get_entvar(id, var_flags);
	g_iArmorValue[bot] = cs_get_user_armor(id, g_armorType[bot]);
	g_csTeam[bot] = cs_get_user_team(id, g_csMdl[bot]);
	g_subMdl[bot] = cs_get_user_submodel(id);
	g_wpnId[bot] = get_user_weapon(id);
}


public _spawn_mannequin(bot) {
	rg_remove_all_items(bot, .removeSuit = true);
	set_entvar(bot, var_solid, SOLID_NOT);
	set_task(0.1, "_solid", bot);
	set_entvar(bot, var_bInDuck, 0);
	set_entvar(bot, var_origin, g_flOrigin[bot]);
	set_entvar(bot, var_v_angle, g_flAngles[bot]);
	set_entvar(bot, var_angles, g_flAngles[bot]);
	set_entvar(bot, var_fixangle, 1);
	set_entvar(bot, var_flags, g_iFlags[bot]);
	if (g_iFlags[bot] & FL_DUCKING) {
		set_entvar(bot, var_bInDuck, 1);
		set_entvar(bot, var_flags, get_entvar(bot, var_flags) | FL_DUCKING);
		set_entvar(bot, var_button, IN_DUCK);
		set_bot_data(bot, bot_buttons, IN_DUCK)
	}
	cs_set_user_team(bot, g_csTeam[bot], g_csMdl[bot]);
	cs_set_user_submodel(bot, g_subMdl[bot]);
	new szWpn[20];
	get_weaponname(g_wpnId[bot], szWpn, sizeof(szWpn));
	rg_give_item(bot, szWpn, GT_REPLACE);
	cs_set_user_armor(bot, g_iArmorValue[bot], g_armorType[bot]);
	client_print_color(0, print_team_grey, "^1[^4%02d^1] ^3SPAWN", bot); // #DEBUG
}

public _solid(id) {
	if (is_user_connected(id)) set_entvar(id, var_solid, SOLID_BBOX);
}



public CBasePlayer_Spawn(id) {
	if (g_iOwner[id]) {
		set_task(0.1, "_spawn_mannequin", id);
	}
}


/* CSX fw */
public client_damage(id, rc, dmg, wpn, hb, t) {
	if (g_cvarEnabled) {
		set_hudmessage(
			t ? 200 : 50, //R
			144, //G
			30, //B
			-1.0, 0.6, //x,y
			0,0.5, //effects, fxtime
			0.1, //holdtime
			0.0,1.5); //fadein fadeout
		ShowSyncHudMsg(id, g_hudSyncDmg, "%d", dmg);
		set_hudmessage(
			255, //R
			100, //G
			40, //B
			-1.0, 0.65, //x,y
			0,2.0, //effects, fxtime
			1.4, //holdtime
			0.1,0.2); //fadein fadeout
		ShowSyncHudMsg(id, g_hudSyncHit, "%s", g_szHitboxName[hb]);
		set_hudmessage(
			255, //R
			255, //G
			255, //B
			-1.0, 0.65, //x,y
			0,1.8, //effects, fxtime
			1.4, //holdtime
			0.2,0.2); //fadein fadeout
		ShowSyncHudMsg(id, g_hudSyncFig, "%s", g_szHangman);
	}
	return PLUGIN_CONTINUE;
}

public CSGameRules_DeathNotice(victimEntIndex, killerEntIndex, inflictorEntIndex) {
	if (killerEntIndex == g_iOwner[victimEntIndex]) {
		if (get_user_button(killerEntIndex) & IN_USE) {
			new szName[MAX_NAME_LENGTH];
			get_user_name(victimEntIndex, szName, charsmax(szName));
			client_print_color(killerEntIndex, print_team_grey, "^1[^4%s^1] ^3REMOVED", szName);
			remove_bot(victimEntIndex);
			g_iOwner[victimEntIndex] = 0;
			g_iMnnqn[killerEntIndex] = 0;

			new players[MAX_PLAYERS], p, num;
			get_players_ex(players, num, GetPlayers_ExcludeHuman | GetPlayers_ExcludeHLTV);
			for (new i=0; i<num; i++) {
				p = players[i];
				if (g_iOwner[p] == killerEntIndex) {
					g_iMnnqn[killerEntIndex] = p;
					break;
				}
			}
		}
	}
}

public _menu_bot(id, bool:remove) {
	new menu;
	if (remove) {
		menu = menu_create("REMOVE BOT", "_menu_handler_remove");
	} else {
		menu = menu_create("SELECT BOT", "_menu_handler_select");
	}
	new szName[MAX_NAME_LENGTH+4] = "\w";
	new info[2];
	new players[MAX_PLAYERS], x, num;
	get_players_ex(players, num, GetPlayers_ExcludeHuman | GetPlayers_ExcludeHLTV);
	for (new i=0; i<num; i++) {
		x = players[i];
		if (g_iOwner[x] == id) {
			info[0] = x;
			get_user_name(x, szName[2], MAX_NAME_LENGTH);
			menu_additem(menu, szName, info);
		}
	}
	menu_display(id, menu);
}

public _menu_handler_remove(voter, menu, item) {
	new bot = 0;
	if (item != MENU_EXIT) {
		new info[2];
		menu_item_getinfo(menu, item, _, info, charsmax(info), _, _, _);
		bot = info[0];
	}
	menu_destroy(menu); //let's not leak memory today
	if (g_iOwner[bot] == voter) {
		g_iMnnqn[voter] = 0;
		g_iOwner[bot] = 0;
		new szName[MAX_NAME_LENGTH];
		get_user_name(bot, szName, charsmax(szName));
		client_print_color(voter, print_team_grey, "^1[^4%s^1] ^3REMOVED", szName);
		remove_bot(bot);
		new players[MAX_PLAYERS], x, num;
		get_players_ex(players, num, GetPlayers_ExcludeHuman | GetPlayers_ExcludeHLTV);
		for (new i=0; i<num; i++) {
			x = players[i];
			if (g_iOwner[x] == voter) {
				g_iMnnqn[voter] = x;
				break;
			}
		}
	}
}

public _menu_handler_select(voter, menu, item) {
	new bot = 0;
	if (item != MENU_EXIT) {
		new info[2];
		menu_item_getinfo(menu, item, _, info, charsmax(info), _, _, _);
		bot = info[0];
	}
	menu_destroy(menu); //let's not leak memory today
	if (g_iOwner[bot] == voter) {
		g_iMnnqn[voter] = bot;
	}
}

public set_aim_at_head(id, bot) {
	new Float:flHeadPos[3];
	GetBonePosition(bot, 8, flHeadPos, _);
	flHeadPos[Z] += 4.0;

	new Float:flPos[3], Float:flViewOffset[3];
	get_entvar(id, var_origin, flPos);
	get_entvar(id, var_view_ofs, flViewOffset);
	flPos[X]+=flViewOffset[X];
	flPos[Y]+=flViewOffset[Y];
	flPos[Z]+=flViewOffset[Z];

	new Float:flDelta[3];
	flDelta[X] = flHeadPos[X] - flPos[X];
	flDelta[Y] = flHeadPos[Y] - flPos[Y];
	flDelta[Z] = flHeadPos[Z] - flPos[Z];
	
	new Float:flAimAngles[3];
	vector_to_angle(flDelta, flAimAngles);
	
	flAimAngles[PITCH] *= -1;
	/*
	if (flAimAngles[YAW] >  180.0) flAimAngles[1] -= 360;
	if (flAimAngles[YAW] < -180.0) flAimAngles[1] += 360;
	if (flAimAngles[YAW] == 180.0 || flAimAngles[1]==-180.0) flAimAngles[1]=-179.999999;
	*/
	set_entvar(id, var_angles, flAimAngles);
	set_entvar(id, var_fixangle, 1);
}


#pragma semicolon 1
