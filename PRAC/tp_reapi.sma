#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <reapi>


#define MAX_SAVES 5

#define X 0
#define Y 1
#define Z 2

#define PITCH 0
#define YAW 1
#define ROLL 2

new g_iSavedPositions[MAX_PLAYERS+1];
new Float:g_flOrigin[MAX_PLAYERS+1][MAX_SAVES+1][3];
new Float:g_flAngles[MAX_PLAYERS+1][MAX_SAVES+1][3];
new bool:g_bInDuck[MAX_PLAYERS+1][MAX_SAVES+1];

new bool:g_bHasLast[MAX_PLAYERS+1];

new g_cvarEnabled;
new HookChain:g_hookSpawn;
new HookChain:g_hookDeathNotice;


public plugin_init() {
	register_plugin("Teleports-ReAPI", "0.1", "tobii");

	register_clcmd("tp", "clcmd_tp");
	register_clcmd("radio2", "hook_radio2");

	g_hookSpawn = RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn", true);
	g_hookDeathNotice = RegisterHookChain(RG_CSGameRules_DeathNotice, "CSGameRules_DeathNotice", true);
	
	new cvarEnabled = create_cvar("mp_teleports", "1", FCVAR_SERVER, "Enables <1> or disables <0> teleports.", true, 0.0, true, 1.0);
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
	}
}


public plugin_cfg() {
}


public clcmd_tp(id) {
	if (g_cvarEnabled) {
		if (is_user_alive(id)) {
			new argc = read_argc();
			switch (argc) {
				case 1: {
				} case 2: {
					new n = read_argv_int(1);
					if (n == -1) {
						if (g_bHasLast[id]) {
							new Float:flOrigin[3];
							new Float:flAngles[3];
							new bool:bInDuck;

							get_entvar(id, var_origin, flOrigin);
							get_entvar(id, var_angles, flAngles);
							bInDuck = bool:get_entvar(id, var_bInDuck);

							_set_pos(id, MAX_SAVES);

							g_flOrigin[id][MAX_SAVES][0] = flOrigin[0];
							g_flOrigin[id][MAX_SAVES][1] = flOrigin[1];
							g_flOrigin[id][MAX_SAVES][2] = flOrigin[2];

							g_flAngles[id][MAX_SAVES][0] = flAngles[0];
							g_flAngles[id][MAX_SAVES][1] = flAngles[1];
							g_flAngles[id][MAX_SAVES][2] = flAngles[2];

							g_bInDuck[id][MAX_SAVES] = bInDuck;
						} else {
							// no last
						}
					} else if (n > 0) {
						if (n <= g_iSavedPositions[id]) {
							_set_pos(id, n-1);
						} else {
							// n too big men
						}
					} else {
						// idk this n
					}
				} default: {
					// odd cmd=?
				}
			}
		} else {
			// client ded?!
		}
		return PLUGIN_HANDLED;
	} 
	return PLUGIN_CONTINUE;
}


public hook_radio2(id) {
	if (g_cvarEnabled && is_user_connected(id) && (get_user_flags(id) & ADMIN_IMMUNITY) && is_user_alive(id)) {
		new bttns = get_entvar(id, var_button);
		if (bttns & IN_USE) {
			//client_print_color(id, print_team_grey, "^1[^4IN_USE^1] ^3//TODO");
		} else if (bttns & IN_RELOAD) {
			//client_print_color(id, print_team_grey, "^1[^4IN_RELOAD^1] ^3//TODO");
			_menu(id);
		} else {
			//client_print_color(id, print_team_grey, "^1[^4MENU^1] ^3//TODO");
		}
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}


public _save_pos(id, n) {
	client_print_color(0, print_team_grey, "_save_pos(%d, %d)", id, n);
	if (is_user_connected(id)) {
		get_entvar(id, var_origin, g_flOrigin[id][n]);
		//get_entvar(id, var_angles, g_flAngles[id][n]);
		get_entvar(id, var_v_angle, g_flAngles[id][n]);
		g_bInDuck[id][n] = bool:get_entvar(id, var_bInDuck);
	} else {
	}
}


public _set_pos(id, n) {
	if (is_user_connected(id)) {
		client_print_color(0, print_team_grey, "_set_pos(%d, %d)", id, n);
		set_entvar(id, var_velocity, NULL_VECTOR);
		set_entvar(id, var_origin, g_flOrigin[id][n]);
		//set_entvar(id, var_v_angle, g_flAngles[id][n]);
		set_entvar(id, var_angles, g_flAngles[id][n]);
		set_entvar(id, var_fixangle, 1);
		set_entvar(id, var_bInDuck, g_bInDuck[id][n]);
	} else {
		client_print_color(0, print_team_grey, "INVALID ID _set_pos(%d, %d)", id, n);
	}
}


public CBasePlayer_Spawn(id) {
	//set_task(0.1, "_spawn_mannequin", id);
}


public CSGameRules_DeathNotice(victimEntIndex, killerEntIndex, inflictorEntIndex) {
}



public _menu(id) {
	new menu = menu_create("Teleport menu", "_menu_handler");
	new info[2];
	if (g_bHasLast[id]) {
		info[0] = 1;
		menu_additem(menu, "\wPrev", info);
	} else {
		info[0] = 0;
		menu_additem(menu, "\dPrev", info);
	}
	if (g_iSavedPositions[id] > 0) {
		info[0] = 1;
		menu_additem(menu, "\yTeleport to postion", info);
	} else {
		info[0] = 0;
		menu_additem(menu, "\dTeleport to postion", info);
	}
	menu_additem(menu, "\ySave current postion", info);
	menu_display(id, menu);
}


public _menu_handler(id, menu, item) {
	if (item != MENU_EXIT) {
		if (is_user_alive(id)) {
			new info[2];
			menu_item_getinfo(menu, item, _, info, charsmax(info), _, _, _);
			switch (item) {
				case 0: {
					if (info[0]) {
						if (g_bHasLast[id]) {
							new Float:flOrigin[3];
							new Float:flAngles[3];
							new bool:bInDuck;

							get_entvar(id, var_origin, flOrigin);
							get_entvar(id, var_angles, flAngles);
							bInDuck = bool:get_entvar(id, var_bInDuck);

							_set_pos(id, MAX_SAVES);

							g_flOrigin[id][MAX_SAVES][0] = flOrigin[0];
							g_flOrigin[id][MAX_SAVES][1] = flOrigin[1];
							g_flOrigin[id][MAX_SAVES][2] = flOrigin[2];

							g_flAngles[id][MAX_SAVES][0] = flAngles[0];
							g_flAngles[id][MAX_SAVES][1] = flAngles[1];
							g_flAngles[id][MAX_SAVES][2] = flAngles[2];

							g_bInDuck[id][MAX_SAVES] = bInDuck;
							client_print_color(id, print_team_grey, "^1[^4_menu_handler^1] ^3//TODO OK -- OK");
						} else {
							client_print_color(id, print_team_grey, "^1[^4_menu_handler^1] ^3//TODO NOT OK OK OK -- OK");
						}
					} else {
						client_print_color(id, print_team_grey, "^1[^4_menu_handler^1] ^3//TODO user not prev?");
					}
					menu_destroy(menu);
					_menu(id);
				} case 1: {
					menu_destroy(menu);
					if (info[0]) {
						_menu_tp(id);
					} else {
						client_print_color(id, print_team_grey, "^1[^4_menu_handler^1] ^3//TODO user not saved?");
						_menu(id);
					}
				} case 2: {
					client_print_color(id, print_team_grey, "^1[^4_menu_handler^1] ^3//TODO open _menu_save");
					menu_destroy(menu);
					_menu_save(id);
				} default: {
					menu_destroy(menu);
				}
			}
		}
	}
}


public _menu_tp(id) {
	new menu = menu_create("Teleport to", "_menu_tp_handler");
	new szMenuEntry[128];
	new info[2];
	new n = g_iSavedPositions[id];
	for (new i = 0; i < n; i++) {
		info[0] = i;
		formatex(szMenuEntry, charsmax(szMenuEntry), "\wTeleport to \r#%d\w", i+1);
		menu_additem(menu, szMenuEntry, info);
	}
	menu_display(id, menu);
}



public _menu_tp_handler(id, menu, item) {
	if (item != MENU_EXIT) {
		if (is_user_alive(id)) {
			new info[2];
			menu_item_getinfo(menu, item, _, info, charsmax(info), _, _, _);
			new n = info[0];
			new c = g_iSavedPositions[id];
			//client_print_color(id, print_team_grey, "^1[^4_menu_tp_handler^1] ^3//TODO set pos to %d", n+1);
			if (n >= 0) {
				if (n < c) {
					if (n < MAX_SAVES) {
						client_print_color(id, print_team_grey, "^1[^4_menu_tp_handler^1] ^3//TODO set pos to %d", n+1);
						_save_pos(id, MAX_SAVES);
						g_bHasLast[id] = true;
						_set_pos(id, n);
					} else {
						client_print_color(id, print_team_grey, "^1[^4_menu_tp_handler^1] ^3//TODO n > MAX_SAVES? (%d/%d), c=%d", n, MAX_SAVES, c);
					}
				} else {
					client_print_color(id, print_team_grey, "^1[^4_menu_tp_handler^1] ^3//TODO n > c? (%d/%d)", n, c);
				}
			} else {
				client_print_color(id, print_team_grey, "^1[^4_menu_tp_handler^1] ^3//TODO n < 0? (%d)", n);
			}
			menu_destroy(menu);
			_menu_tp(id);
		} else {
			menu_destroy(menu);
			//client ded
		}
	} else {
		menu_destroy(menu);
		//exit
	}
}



public _menu_save(id) {
	new menu = menu_create("Save position to", "_menu_save_handler");
	new info[2];
	new n = g_iSavedPositions[id];
	info[0] = n;
	new szMenuEntry[128];
	if (n < MAX_SAVES) {
		formatex(szMenuEntry, charsmax(szMenuEntry), "\yNEW (\w#%d\w/\w%d\y)", n+1, MAX_SAVES);
	} else {
		formatex(szMenuEntry, charsmax(szMenuEntry), "\dNEW (\r#%d\d/\r%d\y)", n+1, MAX_SAVES);
	}
	menu_additem(menu, szMenuEntry, info);
	for (new i = 0; i < n; i++) {
		info[0] = i;
		formatex(szMenuEntry, charsmax(szMenuEntry), "\wOVERWRITE \r#%d\w", i+1);
		menu_additem(menu, szMenuEntry, info);
	}
	menu_display(id, menu);
}


public _menu_save_handler(id, menu, item) {
	if (item != MENU_EXIT) {
		if (is_user_alive(id)) {
			new info[2];
			menu_item_getinfo(menu, item, _, info, charsmax(info), _, _, _);
			new n = info[0];
			new c = g_iSavedPositions[id];
			if (n < MAX_SAVES) {
				if (n < c) {
					_save_pos(id, n);
					client_print_color(id, print_team_grey, "^1[^4_menu_save_handler^1] ^3//TODO OVERWRITE = #%d / %d", n+1, c);
				} else if (n == c) {
					_save_pos(id, n);
					client_print_color(id, print_team_grey, "^1[^4_menu_save_handler^1] ^3//TODO SAVED NEW @n=%d/%d", n, c+1);
					g_iSavedPositions[id] = c+1;
				} else {
					// n > c?
					client_print_color(id, print_team_grey, "^1[^4_menu_save_handler^1] ^3//TODO ERROR? n = %d; c = %d", n, c);
				}
			} else {
				// full
				client_print_color(id, print_team_grey, "^1[^4_menu_save_handler^1] ^3//TODO ERROR? n = %d; c = %d, MAX_SAVES = %d", n, c, MAX_SAVES);
			}
			menu_destroy(menu);
			_menu_save(id);
		} else {
			menu_destroy(menu);
			//clein ded
		}
	} else {
		menu_destroy(menu);
		//was exit
	}
}




#pragma semicolon 1
