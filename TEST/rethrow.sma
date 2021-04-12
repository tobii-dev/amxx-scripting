#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <reapi>
#include <engine>


#define X 0
#define Y 1
#define Z 2


new g_sprSmoke;
new g_sprFlare; //FIXME unused
new g_sprLed;

new bool:g_hasPrev[MAX_PLAYERS];
new Float:g_flPos[MAX_PLAYERS][3];
new Float:g_flVel[MAX_PLAYERS][3];

new bool:g_hasExplosionPos[MAX_PLAYERS];
new Float:g_flExplosionPos[MAX_PLAYERS][3];

new g_msgScreenFade;

public plugin_precache() {
	g_sprSmoke = precache_model("sprites/smoke.spr");
	g_sprFlare = precache_model("sprites/3dmflared.spr");
	g_sprLed = precache_model("sprites/ledglow.spr");
}


public plugin_init() {
	register_plugin("ReThrow", "0.1", "tobii");

	RegisterHookChain(RG_CBasePlayer_UseEmpty, "CBasePlayer_UseEmpty", false);

	RegisterHookChain(RG_PlayerBlind, "hook_playerBlind", false);

	RegisterHookChain(RG_ThrowHeGrenade, "hook_throw", false);
	RegisterHookChain(RG_ThrowFlashbang, "hook_throw", false);
	RegisterHookChain(RG_ThrowSmokeGrenade, "hook_throw", false);

	RegisterHookChain(RG_ThrowHeGrenade, "hook_he", true);
	RegisterHookChain(RG_ThrowFlashbang, "hook_flash", true);
	RegisterHookChain(RG_ThrowSmokeGrenade, "hook_smoke", true);

	RegisterHookChain(RG_CGrenade_ExplodeHeGrenade, "hook_detonate", false);
	RegisterHookChain(RG_CGrenade_ExplodeFlashbang, "hook_detonate", false);
	RegisterHookChain(RG_CGrenade_ExplodeSmokeGrenade, "hook_detonate", false);

	g_msgScreenFade = get_user_msgid("ScreenFade");
}


public plugin_cfg() {
}



public CBasePlayer_UseEmpty(id) {
	if (get_user_button(id) & IN_RELOAD) {
		message_begin(MSG_ONE_UNRELIABLE, g_msgScreenFade, _, id);
		write_short(0); //Duration
		write_short(0);	//Hold time
		write_short(0); //Flags
		write_byte(0); //R
		write_byte(0); //G
		write_byte(0); //B
		write_byte(0); //alpha
		message_end();
		set_member(id, m_blindAlpha, 0);
		set_member(id, m_blindStartTime, 0.0);
		set_member(id, m_blindFadeTime, 0.0);
		set_member(id, m_blindHoldTime, 0.0);
	}
	if (g_hasExplosionPos[id]) {
		message_begin(MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, _, id);
		write_byte(TE_GLOWSPRITE);
		write_coord(floatround(g_flExplosionPos[id][X]));
		write_coord(floatround(g_flExplosionPos[id][Y]));
		write_coord(floatround(g_flExplosionPos[id][Z]));
		write_short(g_sprLed);
		write_byte(100); //life
		write_byte(10); //scale
		write_byte(250); //brightness
		message_end();
	}
}



public hook_playerBlind(id, inflictor, attacker, Float:fadeTime, Float:fadeHold, alpha, Float:color[3]) {
	if ((color[0]==255.0) && (color[1]==255.0) && (color[2]==255.0)) {
		new szName[MAX_NAME_LENGTH];
		get_user_name(id, szName, sizeof(szName));
		if (alpha > 200) {
			client_print_color(attacker, print_team_grey, "^3FULL-BLIND ^1[^4%.02fs^1] ^3/ ^4%.02fs ^1[^4%s^1]", fadeHold, fadeTime, szName);
		} else {
			client_print_color(attacker, print_team_grey, "^3HALF-BLIND ^1[^4%.02fs^1] ^3/ ^4%.02fs ^1[^4%s^1]", fadeHold, fadeTime, szName);
		}
		if (get_user_button(id) & IN_USE) {
			set_member(id, m_blindAlpha, 0);
			set_member(id, m_blindStartTime, 0.0);
			set_member(id, m_blindHoldTime, 0.0);
			SetHookChainArg(4, ATYPE_FLOAT, 0.1);
			SetHookChainArg(5, ATYPE_FLOAT, 0.1);
			SetHookChainArg(6, ATYPE_INTEGER, 30);
			color[0] = 0.0;
			color[1] = 0.0;
			color[2] = 40.0;
		}
	}
	return HC_CONTINUE;
}


public hook_throw(id, Float:vecSrc[3], Float:vecVel[3]) {
	if (g_hasPrev[id]) {
		if (get_user_button(id) & IN_USE) {
			vecSrc[X] = g_flPos[id][X];
			vecSrc[Y] = g_flPos[id][Y];
			vecSrc[Z] = g_flPos[id][Z];
			vecVel[X] = g_flVel[id][X];
			vecVel[Y] = g_flVel[id][Y];
			vecVel[Z] = g_flVel[id][Z];
		} else {
			g_flPos[id][X] = vecSrc[X];
			g_flPos[id][Y] = vecSrc[Y];
			g_flPos[id][Z] = vecSrc[Z];
			g_flVel[id][X] = vecVel[X];
			g_flVel[id][Y] = vecVel[Y];
			g_flVel[id][Z] = vecVel[Z];
		}
	} else {
		g_flPos[id][X] = vecSrc[X];
		g_flPos[id][Y] = vecSrc[Y];
		g_flPos[id][Z] = vecSrc[Z];
		g_flVel[id][X] = vecVel[X];
		g_flVel[id][Y] = vecVel[Y];
		g_flVel[id][Z] = vecVel[Z];
		g_hasPrev[id] = true;
	}
}


public hook_he() {
	new id = GetHookChainReturn(ATYPE_INTEGER);
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_BEAMFOLLOW);
	write_short(id); //id
	write_short(g_sprSmoke); //spr
	write_byte(35); //life
	write_byte(4); //w
	write_byte(255); //R
	write_byte(100); //G
	write_byte(100); //B
	write_byte(255); //brightness
	message_end();
}
public hook_flash() {
	new id = GetHookChainReturn(ATYPE_INTEGER);
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_BEAMFOLLOW);
	write_short(id); //id
	write_short(g_sprSmoke); //spr
	write_byte(40); //life
	write_byte(2); //w
	write_byte(100); //R
	write_byte(200); //G
	write_byte(255); //B
	write_byte(255); //brightness
	message_end();
}
public hook_smoke() {
	new id = GetHookChainReturn(ATYPE_INTEGER);
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_BEAMFOLLOW);
	write_short(id); //id
	write_short(g_sprSmoke); //spr
	write_byte(60); //life
	write_byte(2); //w
	write_byte(130); //R
	write_byte(255); //G
	write_byte(130); //B
	write_byte(255); //brightness
	message_end();
}


public hook_detonate(ent) {
	new id = get_entvar(ent, var_owner);
	if (is_user_connected(id)) {
		g_hasExplosionPos[id] = true;
		get_entvar(ent, var_origin, g_flExplosionPos[id]);
	}
}

#pragma semicolon 1
