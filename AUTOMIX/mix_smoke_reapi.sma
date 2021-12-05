#include <amxmodx>
#include <fakemeta>
#include <engine>
#include <reapi>


new g_cvarSmokes;
new g_smokeEvent;


public plugin_init() {
	register_plugin("Mix-SMOKES-ReApi", "0.1", "tobii");
	g_smokeEvent = engfunc(EngFunc_PrecacheEvent, 1, "events/createsmoke.sc");
	g_cvarSmokes = create_cvar("sv_smokes", "1", FCVAR_SERVER, "Amount of extra smokes to render on top of a regular smoke grenade. <0 .. 64>", true, 0.0, true, 64.0);
	RegisterHookChain(RG_CGrenade_ExplodeSmokeGrenade, "CGrenade_ExplodeSmokeGrenade", true); //Post explode
}


public CGrenade_ExplodeSmokeGrenade(entId) {
	new Float:flOrigin[3];
	get_entvar(entId, var_origin, flOrigin);
	for (new n = get_pcvar_num(g_cvarSmokes); n>0; n--) {
		engfunc(EngFunc_PlaybackEvent, FEV_GLOBAL, 0, g_smokeEvent, 0.0, flOrigin, NULL_VECTOR, 0.0,0.0, 0, 1, 1, 0);
	}
	remove_entity(entId); //Remove me so I dont create extra "puffs" >:(
}


#pragma semicolon 1
