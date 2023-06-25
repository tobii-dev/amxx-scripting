#include <amxmodx>
#include <reapi>
#include <fakemeta>

#pragma semicolon 1

#define MIN_TIME 0.02

new bool:bDucking[33];
//new Float:fAirStartTime[33];
//new Float:fOrigin[33][3];

new bool:bAirborne[33];
//new bool:bPassedZ[33];


new Float:g_cvarRenderingAlpha;
new Float:g_cvarRGB[3];



//https://github.com/s1lentq/ReGameDLL_CS/blob/5044d4ed131d683cd38a3728941723aa352bcbdb/regamedll/pm_shared/pm_shared.cpp#L1886
public plugin_init() {
	register_plugin("DoubleDuckNerf-ReAPI", "0.2", "tobii");
	RegisterHookChain(RG_CBasePlayer_Duck, "CBasePlayer_Duck");
	RegisterHookChain(RG_PM_AirMove, "PM_AirMove");
	RegisterHookChain(RG_PM_Move, "PM_Move");

	//RegisterHookChain(RG_CBasePlayer_TakeDamage, "CBasePlayer_TakeDamage_Pre", .post=false);
	RegisterHookChain(RG_CBasePlayer_TraceAttack, "CBasePlayer_TraceAttack_Pre", .post=false);

	new cvarRenderingR = create_cvar("sv_doubleduck_r", "86.0", FCVAR_SERVER, "Set render RED amount during doubleduck.", true, 0.0, true, 255.0);
	bind_pcvar_float(cvarRenderingR, g_cvarRGB[0]);
	new cvarRenderingG = create_cvar("sv_doubleduck_g", "48.0", FCVAR_SERVER, "Set render GREEN amount during doubleduck.", true, 0.0, true, 255.0);
	bind_pcvar_float(cvarRenderingG, g_cvarRGB[1]);
	new cvarRenderingB = create_cvar("sv_doubleduck_b", "4.0", FCVAR_SERVER, "Set render BLUE amount during doubleduck.", true, 0.0, true, 255.0);
	bind_pcvar_float(cvarRenderingB, g_cvarRGB[2]);
	new cvarRenderingAlpha = create_cvar("sv_doubleduck_alpha", "2.0", FCVAR_SERVER, "Set render alpha during doubleduck.", true, 0.0, true, 256.0);
	bind_pcvar_float(cvarRenderingAlpha, g_cvarRenderingAlpha);
}


stock _set_fx(id) {
	set_entvar(id, var_renderfx, kRenderFxGlowShell);
	set_entvar(id, var_rendercolor, g_cvarRGB);
	set_entvar(id, var_rendermode, kRenderNormal);
	set_entvar(id, var_renderamt, g_cvarRenderingAlpha);
}

stock _reset_fx(id) {
	set_entvar(id, var_renderfx, kRenderNormal);
	set_entvar(id, var_rendercolor, NULL_VECTOR);
	set_entvar(id, var_rendermode, kRenderNormal);
	set_entvar(id, var_renderamt, 0.0);
}


public CBasePlayer_Duck(id) {
	if (get_entvar(id, var_flags) & FL_ONGROUND) {
		if (get_entvar(id, var_flags) & FL_DUCKING) {
			bDucking[id] = false;
		} else {
			bDucking[id] = true;
		}
	} else {
		bDucking[id] = false;
	}
}


public PM_AirMove(id) {
	if (bDucking[id]) {
		if (get_entvar(id, var_button) & IN_DUCK) {
			//client_print_color(id, print_team_grey, "^3PM_AirMove (^4Jump?^3)");
		} else {
			bAirborne[id] = true;
			//bPassedZ[id] = false;
			//get_entvar(id, var_origin, fOrigin[id]);
			//fAirStartTime[id] = get_gametime();
			// // _set_fx(id);
			//client_print_color(id, print_team_grey, "^3PM_AirMove");
		}
	} else {
		//nop
	}
	bDucking[id] = false;
}


public PM_Move(id) {
	if (get_entvar(id, var_flags) & FL_ONGROUND) {
		if (bAirborne[id]) {
			bAirborne[id] = false;
			//bPassedZ[id] = true;
			//new Float:fK[3];
			//get_entvar(id, var_origin, fK);
			//new Float:fDelta = get_gametime() - fAirStartTime[id];
			// //_reset_fx(id);
			//client_print_color(id, print_team_grey, "^3PM_Move ^4%fs ^3& ^4%fu", fDelta, fK[2]-fOrigin[id][2]);
		}
	} else {
		/*
		if (bAirborne[id] && !bPassedZ[id]) {
			new Float:fK[3];
			get_entvar(id, var_origin, fK);
			if (fK[2] < fOrigin[id][2]) {
				bPassedZ[id] = true;
				new Float:fDelta = get_gametime() - fAirStartTime[id];
				client_print_color(id, print_team_grey, "^3PM_Move ^4bPassedZ ^3@ ^4%fs", fDelta);
			}
		}
		*/
	}
}


public CBasePlayer_TraceAttack_Pre(const id, pevAttacker, Float:flDamage, Float:vecDir[3], tracehandle, bitsDamageType) {
	if ((bitsDamageType & DMG_BULLET) && bAirborne[id]) {
		new HitBoxGroup:h = HitBoxGroup:get_tr2(tracehandle, TR_iHitgroup);
		if (h == HITGROUP_CHEST) {
			set_tr2(tracehandle, TR_iHitgroup, HITGROUP_HEAD);
		} else if ((h == HITGROUP_LEFTARM) || (h == HITGROUP_RIGHTARM)) {
			set_tr2(tracehandle, TR_iHitgroup, HITGROUP_CHEST);
		} else if ((h == HITGROUP_LEFTLEG) || (h == HITGROUP_RIGHTLEG)) {
			set_tr2(tracehandle, TR_iHitgroup, HITGROUP_STOMACH);
		}
	}
	return HC_CONTINUE;
}


//https://github.com/s1lentq/ReGameDLL_CS/blob/bc2c3176e46e2c32ebc0110e7df879ea7ddbfafa/regamedll/dlls/player.cpp#L591
public CBasePlayer_TakeDamage_Pre(id, const pevInflictor, const pevAttacker, const Float:flDamage, const bitsDamageType) {
	if ((bitsDamageType & DMG_BULLET) && bAirborne[id]) {
		//HITGROUP_GENERIC
		//HITGROUP_HEAD
		//HITGROUP_CHEST
		//HITGROUP_STOMACH
		//HITGROUP_LEFTARM
		//HITGROUP_RIGHTARM
		//HITGROUP_LEFTLEG
		//HITGROUP_RIGHTLEG
		//HITGROUP_SHIELD
		new HitBoxGroup:h = HitBoxGroup:get_member(id, m_LastHitGroup);
		if (h == HITGROUP_CHEST) {
			//client_print_color(id, print_team_grey, "^4DMG HITGROUP_CHEST(%f) -> HITGROUP_HEAD(%f).", flDamage, flDamage*4);
			SetHookChainArg(4, ATYPE_FLOAT, flDamage*4);
			set_member(id, m_LastHitGroup, HITGROUP_HEAD);
		} else if ((h == HITGROUP_LEFTARM) || (h == HITGROUP_RIGHTARM)) {
			//client_print_color(id, print_team_grey, "^4DMG HITGROUP_*ARM(%f) -> HITGROUP_CHEST(%f).", flDamage, flDamage*1.25);
			SetHookChainArg(4, ATYPE_FLOAT, flDamage*1.25);
			set_member(id, m_LastHitGroup, HITGROUP_CHEST);
		} else if ((h == HITGROUP_LEFTLEG) || (h == HITGROUP_RIGHTLEG)) {
			//client_print_color(id, print_team_grey, "^4DMG HITGROUP_*LEG(%f) -> HITGROUP_STOMACH(%f).", flDamage, flDamage*1.25);
			SetHookChainArg(4, ATYPE_FLOAT, flDamage*1.25);
			set_member(id, m_LastHitGroup, HITGROUP_STOMACH);
		}
	}
	return HC_CONTINUE;
}
