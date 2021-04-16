#include <amxmodx>
#include <fakemeta>
#include <engine>
#include <reapi>


new g_cvarSmokes;
new g_smokeEvent;


public plugin_init() {
	register_plugin("Mix-SMOKES-ReApi", "0.1", "tobii");
	g_smokeEvent = engfunc(EngFunc_PrecacheEvent, 1, "events/createsmoke.sc");
	g_cvarSmokes = register_cvar("sv_smokes", "2");
	RegisterHookChain(RG_CGrenade_ExplodeSmokeGrenade, "hook_smoke", true); //post explode
}


public hook_smoke(entId) {
	new Float:flOrigin[3];
	get_entvar(entId, var_origin, flOrigin);
	for (new n = get_pcvar_num(g_cvarSmokes); n>0; n--) {
		//flOrigin[1]+=5.0; //+5 units to Y coord
		engfunc(EngFunc_PlaybackEvent, FEV_GLOBAL, 0, g_smokeEvent, 0.0, flOrigin, NULL_VECTOR, 0.0,0.0, 0, 1, 1, 0);
	}
	//set_pev(entId, pev_effects, EF_NODRAW);
	remove_entity(entId); //remove me, so i cant create "puffs" >:(
}


#pragma semicolon 1
