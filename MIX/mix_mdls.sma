#include <amxmodx>

#define NULL_HULL_VEC {0,0,0}

new const g_szMdl[][] = {
	"models/player/arctic/arctic.mdl",
	"models/player/gign/gign.mdl",
	"models/player/gsg9/gsg9.mdl",
	"models/player/guerilla/guerilla.mdl",
	"models/player/leet/leet.mdl",
	"models/player/sas/sas.mdl",
	"models/player/terror/terror.mdl",
	"models/player/urban/urban.mdl",
	"models/player/vip/vip.mdl"
}


public plugin_init() {
	register_plugin("Mix-MDLs", "0.1", "tobii");
}


public plugin_precache() {
	for(new i=0; i<sizeof(g_szMdl); i++) {
		precache_generic(g_szMdl[i]);
		force_unmodified(force_exactfile, NULL_HULL_VEC, NULL_HULL_VEC, g_szMdl[i]);
	}
}

#pragma semicolon 1
