#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <reapi>
#include <engine>
#include <fakemeta>


#define X 0
#define Y 1
#define Z 2

#define PITCH 0
#define YAW 1
#define ROLL 2


new g_cvarEnabled;


new g_ghostID;
new g_ghostHost;
new g_frame;
new g_msec;

new Array:g_replayData[33];
enum _:ReplayData {
	Float:fAng[3],
	Float:fPos[3],
	Float:fVel[3],
	iBttn,
};


new bool:g_bRecording[33];


new g_iArmorValue[33];
new CsArmorType:g_armorType[33];
new CsTeams:g_csTeam[33];
new CsInternalModel:g_csMdl[33];
new g_subMdl[33];
new g_wpnId[33];

new HookChain:g_hookSpawn;
new HookChain:g_hookThink;


public plugin_init() {
	register_plugin("Ghosts-ReAPI", "0.1", "tobii");

	register_clcmd("radio3", "hook_radio3");

	g_hookSpawn = RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn", true);
	g_hookThink = RegisterHookChain(RG_CBasePlayer_PreThink, "CBasePlayer_PreThink", true);
	
	new cvarEnabled = create_cvar("sv_ghosts", "1", FCVAR_NONE, "Enables <1> or disables <0> ghosts.", true, 0.0, true, 1.0);
	hook_cvar_change(cvarEnabled, "hook_cvar_enabled");
	bind_pcvar_num(cvarEnabled, g_cvarEnabled);

	for (new i = 0; i < sizeof(g_replayData); i++) {
		g_replayData[i] = ArrayCreate(ReplayData, 1);
	}

}



public OnConfigsExecuted() {
	hook_cvar_enabled();
	g_msec = floatround(get_global_float(GL_frametime) * 1000);
}


public hook_cvar_enabled() {
	if (g_cvarEnabled) {
		EnableHookChain(g_hookSpawn);
		EnableHookChain(g_hookThink);
	} else {
		DisableHookChain(g_hookSpawn);
		DisableHookChain(g_hookThink);
	}
}


public plugin_cfg() {
}

public client_disconnected(id) {
	if (id == g_ghostID) {
		g_ghostID = 0;
	}
	ArrayClear(g_replayData[id]);
}


public hook_radio3(id) {
	if (g_cvarEnabled) {
		_menu(id);
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}

public client_authorized(id) {
	ArrayClear(g_replayData[id]);
}


public _start_replay(id) {
	new ghost = _spawn_ghost(id);
	if (ghost) {
		client_print_color(id, print_team_grey, "^3BOT!");
		g_ghostID = ghost;
		g_ghostHost = id;
		g_frame = 0;

	} else {
		client_print_color(id, print_team_grey, "^3NOT BOT!");
	}
}


public _spawn_ghost(id) {
	new ghost = engfunc(EngFunc_CreateFakeClient, "blyat");
	if (is_valid_ent(ghost)) {
		set_user_info(ghost, "rate", "10000");
		set_user_info(ghost, "cl_updaterate", "60");
		set_user_info(ghost, "cl_cmdrate", "60");
		set_user_info(ghost, "cl_lw", "1");
		set_user_info(ghost, "cl_lc", "1");
		set_user_info(ghost, "cl_dlmax", "128");
		set_user_info(ghost, "cl_righthand", "1");
		set_user_info(ghost, "_vgui_menus", "0");
		set_user_info(ghost, "_ah", "0");
		set_user_info(ghost, "dm", "0");
		set_user_info(ghost, "tracker", "0");
		set_user_info(ghost, "friends", "0");
		set_user_info(ghost, "*bot", "1");

		set_pev(ghost, pev_flags, pev(ghost, pev_flags) | FL_FAKECLIENT);
		//set_entvar(ghost, var_flags, get_entvar(ghost, var_flags) | FL_FAKECLIENT);
		set_pev(ghost, pev_colormap, ghost);
		//set_entvar(ghost, var_colormap, ghost);

		dllfunc(DLLFunc_ClientConnect, ghost, "Ghost", "127.0.0.1");
		dllfunc(DLLFunc_ClientPutInServer, ghost);

		//cs_set_user_team(ghost, g_csTeam);
		//cs_set_user_model(ghost, "sas");
		cs_set_user_team(ghost, g_csTeam[id], g_csMdl[id]);

		if (!is_user_alive(ghost)) dllfunc(DLLFunc_Spawn, ghost);
		//set_pev(ghost, pev_takedamage, DAMAGE_NO);
	} else {
		ghost = 0;
	}
	return ghost;
}


public _remove_ghost(id) {
	server_cmd("kick #%d", get_user_userid(g_ghostID))
	g_ghostHost = 0;
	g_ghostID = 0;
	g_frame = 0;
}


public _ghost_think(id) {

	if (!is_user_alive(id)) {
		set_task(0.1, "_start_replay", g_ghostHost);
		_remove_ghost(id);
		g_frame = 0;
	}
	if (g_frame == 0) {
		cs_set_user_submodel(id, g_subMdl[g_ghostHost]);
		cs_set_user_armor(id, g_iArmorValue[g_ghostHost], g_armorType[g_ghostHost]);
		new szWpn[32];
		rg_get_weapon_info(g_wpnId[g_ghostHost], WI_NAME, szWpn, charsmax(szWpn));
		rg_give_item(id, szWpn);
		engclient_cmd(id, szWpn);
		client_print_color(0, print_team_grey, "^3_ghost_think(): frame #0!");
	}
	if (g_frame < ArraySize(g_replayData[g_ghostHost])) {
		new data[ReplayData];
		ArrayGetArray(g_replayData[g_ghostHost], g_frame, data);
		engfunc(EngFunc_RunPlayerMove, id, data[fAng], data[fVel][X], data[fVel][Y], data[fVel][Z], data[iBttn], 0, g_msec);
		set_entvar(id, var_v_angle, data[fAng]);
		data[fAng][0] /= -3.0;
		set_entvar(id, var_angles, data[fAng]);
		set_entvar(id, var_origin, data[fPos]);
		set_entvar(id, var_velocity, data[fVel]);
		set_entvar(id, var_button, data[iBttn]);
		g_frame++;
	} else {
		client_print_color(0, print_team_grey, "^3_ghost_think(): frame > ArraySize[g_replayData[_]);
		g_frame = 0;
	}
}


public CBasePlayer_Spawn(id) {
}


public CBasePlayer_PreThink(id) {
	if (g_bRecording[id]) {
		new data[ReplayData];
		get_entvar(id, var_v_angle, data[fAng]);
		get_entvar(id, var_origin, data[fPos]);
		get_entvar(id, var_velocity, data[fVel]);
		data[iBttn] = get_entvar(id, var_button);
		ArrayPushArray(g_replayData[id], data);
	} else if (id == g_ghostHost) {
		_ghost_think(g_ghostID);
	}
}


public _menu(id) {
	new menu = menu_create("\wGhosts", "_menu_handler");
	new info[2];
	if (g_bRecording[id]) {
		info[0] = 1;
		menu_additem(menu, "\wCUT", info); // stop recording current
		menu_additem(menu, "\rPlay", info); // cant view while recording
	} else {
		menu_additem(menu, "\wACTION", info); // start new recording
		if (ArraySize(g_replayData[id]) > 0) { // user has replay ready
			if (g_ghostID) { // there is a bot on serv
				if (g_ghostHost == id) { // its our bot
					menu_additem(menu, "\yEND", info); // kick our own bot
				} else {
					menu_additem(menu, "\rEND", info); // we cant kick someone elses bot
				}
			} else { // no bot on server
				menu_additem(menu, "\wPlay", info); // play our own
			}
		} else {
			menu_additem(menu, "\rPlay", info); // we cant play our own cause we dont have our own
		}
	}
	menu_display(id, menu);
}

public _menu_handler(id, menu, item) {
	if (item != MENU_EXIT) {
		new info[2];
		menu_item_getinfo(menu, item, _, info, charsmax(info), _, _, _);
		switch (item) {
			case 0: {
				if (g_bRecording[id]) {
					//menu_additem(menu, "\wCUT", info); // stop recording current
					g_bRecording[id] = false;
					client_print_color(id, print_team_grey, "^3SAVED.");
				} else {
					//menu_additem(menu, "\wACTION", info); // start new recording
					_start_recording(id);
					client_print_color(id, print_team_grey, "^3STARTED.");
				}
			} case 1: {
				if (g_bRecording[id]) {
					//menu_additem(menu, "\rView", info); // cant view while recording
					client_print_color(id, print_team_grey, "^3Can't view while recording bot.");
				} else {
					if (g_ghostID) { // there is a bot on serv
						if (g_ghostHost == id) { // its our bot
							//menu_additem(menu, "\yEND", info); // kick our own bot
							_remove_ghost(id);
							client_print_color(id, print_team_grey, "^3Kicked own bot.");
						} else {
							//menu_additem(menu, "\rEND", info); // we cant kick someone elses bot
							_remove_ghost(id);
							client_print_color(id, print_team_grey, "^3Can't kick someone else's bot.");
						}
					} else { // no bot on server
						if (ArraySize(g_replayData[id]) > 0) { // user has replay ready
							//menu_additem(menu, "\wPlay", info); // play our own
							client_print_color(id, print_team_grey, "^3Playing own replay.");
							_start_replay(id);
						} else {
							//menu_additem(menu, "\rPlay", info); // we cant play our own cause we dont have our own
							client_print_color(id, print_team_grey, "^3Make a recording first!");
						}
					}
				}
			} default: {
				client_print_color(id, print_team_grey, "^3Unhandled menu option: %d", item);
			}
		}
		menu_destroy(menu);
		_menu(id);
	} else {
		menu_destroy(menu);
	}
}

public _start_recording(id) {
	g_iArmorValue[id] = cs_get_user_armor(id, g_armorType[id]);
	g_csTeam[id] = cs_get_user_team(id, g_csMdl[id]);
	g_subMdl[id] = cs_get_user_submodel(id);
	g_wpnId[id] = cs_get_user_weapon(id);

	ArrayClear(g_replayData[id]);
	g_bRecording[id] = true;
}


#pragma semicolon 1
