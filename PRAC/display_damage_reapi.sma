#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <csx>
#include <reapi>


#pragma semicolon 1


//new const g_szHangman[] = "  [ ]^n [ ][ ][ ]^n [ ]^n  [ ] [ ]^n  [ ] [ ]";
//new const g_szHitbox[][] = {
//	"   X ^n  X  X  X ^n  X ^n   X   X ^n   X   X ", //generic
//	"   X ^n          ^n    ^n         ^n         ", //head
//	"     ^n     X    ^n    ^n         ^n         ", //chest
//	"     ^n          ^n  X ^n         ^n         ", //stomach
//	"     ^n  X       ^n    ^n         ^n         ", //la
//	"     ^n        X ^n    ^n         ^n         ", //ra
//	"     ^n          ^n    ^n   X     ^n   X     ", //ll
//	"     ^n          ^n    ^n       X ^n       X ", //rl
//	"     ^n          ^n    ^n         ^n         "  //sh
//};
new const g_szHitbox[][] = {
	"  [X]^n [X][X][X]^n [X]^n  [X] [X]^n  [X] [X]", //generic
	"  [X]^n [ ][ ][ ]^n [ ]^n  [ ] [ ]^n  [ ] [ ]", //head
	"  [ ]^n [ ][X][ ]^n [ ]^n  [ ] [ ]^n  [ ] [ ]", //chest
	"  [ ]^n [ ][ ][ ]^n [X]^n  [ ] [ ]^n  [ ] [ ]", //stomach
	"  [ ]^n [X][ ][ ]^n [ ]^n  [ ] [ ]^n  [ ] [ ]", //la
	"  [ ]^n [ ][ ][X]^n [ ]^n  [ ] [ ]^n  [ ] [ ]", //ra
	"  [ ]^n [ ][ ][ ]^n [ ]^n  [X] [ ]^n  [X] [ ]", //ll
	"  [ ]^n [ ][ ][ ]^n [ ]^n  [ ] [X]^n  [ ] [X]", //rl
	"  [ ]^n [ ][ ][ ]^n [ ]^n  [ ] [ ]^n  [ ] [ ]"  //sh
};


new Float:g_fLastDisplayTime[33];
new g_lastDmg[33];
//new g_hudSyncDmg;
new g_hudSyncHit;
//new g_hudSyncFig;
new g_cvarEnabled;


public plugin_init() {
	register_plugin("DisplayDamage", "0.2", "tobii");
//	g_hudSyncDmg = CreateHudSyncObj();
	g_hudSyncHit = CreateHudSyncObj();
	//g_hudSyncFig = CreateHudSyncObj();
	new cvarEnabled = create_cvar("mp_display_damage", "1", FCVAR_SERVER, "Enables <1> or disables <0> display damage done.", true, 0.0, true, 1.0);
	bind_pcvar_num(cvarEnabled, g_cvarEnabled);
}


public client_damage(id, rc, dmg, wpn, hb, t) {
	if (g_cvarEnabled) {
		new Float:t = get_gametime();
		if (t == g_fLastDisplayTime[id]) {
			dmg += g_lastDmg[id];
		} else {
			g_fLastDisplayTime[id] = t;
		}
//		set_hudmessage(
//			t ? 200 : 50, //R
//			144, //G
//			30, //B
//			-1.0, 0.6, //x,y
//			0,0.5, //effects, fxtime
//			0.1, //holdtime
//			0.0,1.5); //fadein fadeout
//		ShowSyncHudMsg(id, g_hudSyncDmg, "%d", dmg);
		set_hudmessage(
			255, //R
			100, //G
			100, //B
			-1.0, 0.65, //x,y
			0,2.0, //effects, fxtime
			1.4, //holdtime
			0.1,0.2); //fadein fadeout
		ShowSyncHudMsg(id, g_hudSyncHit, "%d^n%s", dmg, g_szHitbox[hb]);
//		set_hudmessage(
//			255, //R
//			255, //G
//			255, //B
//			-1.0, 0.65, //x,y
//			0,1.8, //effects, fxtime
//			1.4, //holdtime
//			0.2,0.2); //fadein fadeout
//		ShowSyncHudMsg(id, g_hudSyncFig, "%s", g_szHangman);
		g_lastDmg[id] = dmg;
		new specs[MAX_PLAYERS], n, s;
		get_players_ex(specs, n, GetPlayers_ExcludeAlive | GetPlayers_ExcludeBots | GetPlayers_ExcludeHLTV);
		for (new i = 0; i < n; i++) {
			s = specs[i];
			if (get_entvar(s, var_iuser2) == id) {
//				set_hudmessage(
//					t ? 200 : 50, //R
//					144, //G
//					30, //B
//					-1.0, 0.6, //x,y
//					0,0.5, //effects, fxtime
//					0.1, //holdtime
//					0.0,1.5); //fadein fadeout
//				ShowSyncHudMsg(s, g_hudSyncDmg, "%d", dmg);
				set_hudmessage(
					255, //R
					100, //G
					100, //B
					-1.0, 0.65, //x,y
					0,2.0, //effects, fxtime
					1.4, //holdtime
					0.1,0.2); //fadein fadeout
				ShowSyncHudMsg(s, g_hudSyncHit, "%d^n%s", dmg, g_szHitbox[hb]);
//				set_hudmessage(
//					255, //R
//					255, //G
//					255, //B
//					-1.0, 0.65, //x,y
//					0,1.8, //effects, fxtime
//					1.4, //holdtime
//					0.2,0.2); //fadein fadeout
//				ShowSyncHudMsg(s, g_hudSyncFig, "%s", g_szHangman);
			}
		}
	}
}
