#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
//#include <reapi_gamedll>


//Original Plugin: https://forums.alliedmods.net/showthread.php?p=1549133
// by MPNumB @ https://forums.alliedmods.net/member.php?u=25348

#define PLUGIN_NAME	"Accuracy Fix ReAPI"
#define PLUGIN_VERSION	"1.0"
#define PLUGIN_AUTHOR	"tobii"

#define m_flAccuracy 62
#define m_fWeaponState 74
#define WEAPONSTATE_GLOCK18_BURST_MODE (1<<1)
#define m_flDecreaseShotsFired 76

new HamHook:g_hamHooks_pre[20];
new HamHook:g_hamHooks_post[7];
new g_cvarEnabled;

new Float:g_fAccuracy;
new bool:g_bGlockDuckRemoved;
new bool:g_bGlockVelocityChanged;
new Float:g_fGlockVelocity[3];


public plugin_init() {
	new i, j;
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);
	
	g_cvarEnabled = register_cvar("sv_accuracy", "1");
	hook_cvar_change(g_cvarEnabled, "hook_cvar_enabled_changed"); //detect cvar changes for register / unregister
	
	// awp accuracy offset does not exist
	// g3sg1 accuracy offset has no effect
	// scout accuracy offset does not exist
	g_hamHooks_pre[i++] = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_ak47", "hook_ak47_pre", 0);
	g_hamHooks_pre[i++] = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_aug", "hook_aug_pre", 0);
	g_hamHooks_pre[i++] = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_famas", "hook_famas_pre", 0);
	g_hamHooks_pre[i++] = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_galil", "hook_galil_pre", 0);
	g_hamHooks_pre[i++] = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_m249", "hook_m249_pre", 0);
	g_hamHooks_pre[i++] = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_m4a1", "hook_m4a1_pre", 0);
	g_hamHooks_pre[i++] = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_mac10", "hook_mac10_pre", 0);
	g_hamHooks_pre[i++] = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_mp5navy", "hook_mp5navy_pre", 0);
	g_hamHooks_pre[i++] = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_p90", "hook_p90_pre", 0);
	g_hamHooks_pre[i++] = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_sg550", "hook_sg550_pre", 0);
	g_hamHooks_pre[i++] = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_sg552", "hook_sg552_pre", 0);
	g_hamHooks_pre[i++] = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_tmp", "hook_tmp_pre", 0);
	g_hamHooks_pre[i++] = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_ump45", "hook_ump45_pre", 0);
	
	g_hamHooks_pre[i++] = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_deagle", "hook_deagle_pre", 0);
	g_hamHooks_post[j++] = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_deagle", "hook_deagle_post", 1);
	
	g_hamHooks_pre[i++] = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_elite", "hook_elite_pre", 0);
	g_hamHooks_post[j++] = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_elite", "hook_elite_post", 1);
	
	g_hamHooks_pre[i++] = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_fiveseven", "hook_fiveseven_pre", 0);
	g_hamHooks_post[j++] = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_fiveseven", "hook_fiveseven_post", 1);
	
	g_hamHooks_pre[i++] = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_glock18", "hook_glock18_pre", 0);
	g_hamHooks_post[j++] = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_glock18", "hook_glock18_post", 1);
	
	g_hamHooks_pre[i++] = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_p228", "hook_p228_pre", 0);
	g_hamHooks_post[j++] = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_p228", "hook_p228_post", 1);
	
	g_hamHooks_pre[i++] = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_scout", "hook_scout_pre", 0);
	g_hamHooks_post[j++] = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_scout", "hook_scout_post", 1);
	
	g_hamHooks_pre[i++] = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_usp", "hook_usp_pre", 0);
	g_hamHooks_post[j++] = RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_usp", "hook_usp_post", 1);
}



public OnConfigsExecuted() {
	hook_cvar_enabled_changed();
}


public hook_cvar_enabled_changed() {
	if (get_pcvar_bool(g_cvarEnabled)) {
		_enable_hooks();
		client_print(0, print_chat, "sv_accuracy is ON");
	} else {
		_disable_hooks();
		client_print(0, print_chat, "sv_accuracy is OFF");
	}
}

stock _enable_hooks() {
	new i;
	for (i=0; i < sizeof(g_hamHooks_pre); i++) EnableHamForward(g_hamHooks_pre[i]);
	for (i=0; i < sizeof(g_hamHooks_post); i++) EnableHamForward(g_hamHooks_post[i]);
}
stock _disable_hooks() {
	new i;
	for (i=0; i < sizeof(g_hamHooks_pre); i++) DisableHamForward(g_hamHooks_pre[i]);
	for (i=0; i < sizeof(g_hamHooks_post); i++) DisableHamForward(g_hamHooks_post[i]);
}


stock Float:smooth_accuracy_transition(iSteppingId, Float:fMaxInaccuracy, iSteppingsMax) {
	//return iSteppingId >= iSteppingsMax ? fMaxInaccuracy : (float(iSteppingId)*fMaxInaccuracy)/float(iSteppingsMax);
	return (iSteppingId >= iSteppingsMax) ? fMaxInaccuracy : (iSteppingId*fMaxInaccuracy)/iSteppingsMax;
}

public plugin_unpause() {
	g_fAccuracy = 0.0;
	g_bGlockDuckRemoved = false;
	g_bGlockVelocityChanged = false;
}


public hook_ak47_pre(iEnt) {
	static s_iShotsFired;
	s_iShotsFired = get_member(iEnt, m_Weapon_iShotsFired)-1;
	if (s_iShotsFired >= 0) {
		g_fAccuracy = ((s_iShotsFired*s_iShotsFired*s_iShotsFired)/200.0) + 0.2 + smooth_accuracy_transition((s_iShotsFired+1), 0.15, 3);
		if (g_fAccuracy > 1.25) g_fAccuracy = 1.25;
		set_member(iEnt, m_Weapon_flAccuracy, g_fAccuracy);
	} else {
		static s_iOwner, s_iFlags;
		s_iOwner = get_entvar(iEnt, var_owner);
		s_iFlags = pev(s_iOwner, pev_flags);
		if (s_iFlags & FL_ONGROUND) {
			static Float:s_fVelocity[3];
			pev(s_iOwner, pev_velocity, s_fVelocity);
			if (!s_fVelocity[0] && !s_fVelocity[1]) {
				if (s_iFlags & FL_DUCKING) set_member(iEnt, m_Weapon_flAccuracy, 0.0);
				else set_member(iEnt, m_Weapon_flAccuracy, 0.1);
			} else set_member(iEnt, m_Weapon_flAccuracy, 0.2);
		} else set_member(iEnt, m_Weapon_flAccuracy, 0.2);
	}
}


public hook_aug_pre(iEnt) {
	static s_iShotsFired;
	s_iShotsFired = get_member(iEnt, m_Weapon_iShotsFired)-1;
	if (s_iShotsFired >= 0) {
		g_fAccuracy = ((s_iShotsFired*s_iShotsFired*s_iShotsFired)/215.0) + 0.2 + smooth_accuracy_transition((s_iShotsFired+1), 0.1, 2);
		if (g_fAccuracy >1.0) g_fAccuracy = 1.0;
		set_member(iEnt, m_Weapon_flAccuracy, g_fAccuracy);
	} else {
		static s_iOwner, s_iFlags;
		s_iOwner = get_entvar(iEnt, var_owner);
		s_iFlags = pev(s_iOwner, pev_flags);
		if (s_iFlags & FL_ONGROUND) {
			static Float:s_fVelocity[3];
			pev(s_iOwner, pev_velocity, s_fVelocity);
			if (!s_fVelocity[0] && !s_fVelocity[1]) {
				if(s_iFlags & FL_DUCKING) set_member(iEnt, m_Weapon_flAccuracy, 0.0);
				else set_member(iEnt, m_Weapon_flAccuracy, 0.1);
			} else set_member(iEnt, m_Weapon_flAccuracy, 0.2);
		} else set_member(iEnt, m_Weapon_flAccuracy, 0.2);
	}
}


public hook_deagle_pre(iEnt) {
	static Float:s_fLastFire;
	s_fLastFire = Float:get_member(iEnt, m_Weapon_flLastFire);
	if (!s_fLastFire) {
		static s_iOwner, s_iFlags;
		s_iOwner = get_entvar(iEnt, var_owner);
		s_iFlags = pev(s_iOwner, pev_flags);
		if (s_iFlags & FL_ONGROUND) {
			static Float:s_fVelocity[3];
			pev(s_iOwner, pev_velocity, s_fVelocity);
			if (!s_fVelocity[0] && !s_fVelocity[1]) {
				if (s_iFlags & FL_DUCKING) g_fAccuracy = 1.0;
				else g_fAccuracy = 0.96;
			} else g_fAccuracy = 0.92;
		} else g_fAccuracy = 0.92;
		set_member(iEnt, m_Weapon_flAccuracy, g_fAccuracy);
	} else if (get_member(iEnt, m_Weapon_iShotsFired) <= 0) {
		g_fAccuracy = Float:get_member(iEnt, m_Weapon_flAccuracy);
		g_fAccuracy -= (0.4-(get_gametime()-s_fLastFire))*0.35;
		if (g_fAccuracy < 0.55) g_fAccuracy = 0.55;
		else if (g_fAccuracy > 0.92) {
			static s_iOwner, s_iFlags;
			s_iOwner = get_entvar(iEnt, var_owner);
			s_iFlags = pev(s_iOwner, pev_flags);
			if (s_iFlags & FL_ONGROUND) {
				static Float:s_fVelocity[3];
				pev(s_iOwner, pev_velocity, s_fVelocity);
				if (!s_fVelocity[0] && !s_fVelocity[1]) {
					if (s_iFlags & FL_DUCKING) {
						if (g_fAccuracy > 1.0) g_fAccuracy = 1.0;
					} else if (g_fAccuracy > 0.96) g_fAccuracy = 0.96;
				} else g_fAccuracy = 0.92;
			} else g_fAccuracy = 0.92;
		}
		set_member(iEnt, m_Weapon_flAccuracy, g_fAccuracy);
	} else g_fAccuracy = -1.0;
}

public hook_deagle_post(iEnt) {
	if (g_fAccuracy > 0.92 ) set_member(iEnt, m_Weapon_flAccuracy, 0.92);
	else if (g_fAccuracy > 0.0) set_member(iEnt, m_Weapon_flAccuracy, g_fAccuracy);
}


public hook_elite_pre(iEnt) {
	static Float:s_fLastFire;
	s_fLastFire = Float:get_member(iEnt, m_Weapon_flLastFire);
	if (!s_fLastFire) {
		static s_iOwner, s_iFlags;
		s_iOwner = get_entvar(iEnt, var_owner);
		s_iFlags = pev(s_iOwner, pev_flags);
		if (s_iFlags & FL_ONGROUND) {
			static Float:s_fVelocity[3];
			pev(s_iOwner, pev_velocity, s_fVelocity);
			if (!s_fVelocity[0] && !s_fVelocity[1]) {
				if (s_iFlags & FL_DUCKING) g_fAccuracy = 1.0;
				else g_fAccuracy = 0.94;
			} else g_fAccuracy = 0.88;
		} else g_fAccuracy = 0.88;
		set_member(iEnt, m_Weapon_flAccuracy, g_fAccuracy);
	} else if (get_member(iEnt, m_Weapon_iShotsFired) <= 0 ) {
		g_fAccuracy = Float:get_member(iEnt, m_Weapon_flAccuracy);
		g_fAccuracy -= (0.325-(get_gametime()-s_fLastFire))*0.275;
		if (g_fAccuracy < 0.55) g_fAccuracy = 0.55;
		else if (g_fAccuracy>0.88) {
			static s_iOwner, s_iFlags;
			s_iOwner = get_entvar(iEnt, var_owner);
			s_iFlags = pev(s_iOwner, pev_flags);
			if (s_iFlags & FL_ONGROUND ) {
				static Float:s_fVelocity[3];
				pev(s_iOwner, pev_velocity, s_fVelocity);
				if (!s_fVelocity[0] && !s_fVelocity[1]) {
					if (s_iFlags & FL_DUCKING) {
						if (g_fAccuracy > 1.0) g_fAccuracy = 1.0;
					} else if (g_fAccuracy > 0.94) g_fAccuracy = 0.94;
				} else g_fAccuracy = 0.88;
			} else g_fAccuracy = 0.88;
		}
		set_member(iEnt, m_Weapon_flAccuracy, g_fAccuracy);
	} else g_fAccuracy = -1.0;
}

public hook_elite_post(iEnt) {
	if (g_fAccuracy > 0.88) set_member(iEnt, m_Weapon_flAccuracy, 0.88);
	else if (g_fAccuracy > 0.0) set_member(iEnt, m_Weapon_flAccuracy, g_fAccuracy);
}


public hook_famas_pre(iEnt) {
	static s_iShotsFired;
	s_iShotsFired = get_member(iEnt, m_Weapon_iShotsFired)-1;
	if (s_iShotsFired >= 0) {
		g_fAccuracy = ((s_iShotsFired*s_iShotsFired*s_iShotsFired)/215.0) + 0.2 + smooth_accuracy_transition((s_iShotsFired+1), 0.1, 2);
		if (g_fAccuracy > 1.0) g_fAccuracy = 1.0;
		set_member(iEnt, m_Weapon_flAccuracy, g_fAccuracy);
	} else {
		static s_iOwner, s_iFlags;
		s_iOwner = get_entvar(iEnt, var_owner);
		s_iFlags = pev(s_iOwner, pev_flags);
		if (s_iFlags & FL_ONGROUND) {
			static Float:s_fVelocity[3];
			pev(s_iOwner, pev_velocity, s_fVelocity);
			if (!s_fVelocity[0] && !s_fVelocity[1]) {
				if (s_iFlags & FL_DUCKING) set_member(iEnt, m_Weapon_flAccuracy, 0.0);
				else set_member(iEnt, m_Weapon_flAccuracy, 0.1);
			} else set_member(iEnt, m_Weapon_flAccuracy, 0.2);
		} else set_member(iEnt, m_Weapon_flAccuracy, 0.2);
	}
}


public hook_fiveseven_pre(iEnt) {
	static Float:s_fLastFire;
	s_fLastFire = Float:get_member(iEnt, m_Weapon_flLastFire);
	if (!s_fLastFire) {
		static s_iOwner, s_iFlags;
		s_iOwner = get_entvar(iEnt, var_owner);
		s_iFlags = pev(s_iOwner, pev_flags);
		if (s_iFlags & FL_ONGROUND) {
			static Float:s_fVelocity[3];
			pev(s_iOwner, pev_velocity, s_fVelocity);
			if (!s_fVelocity[0] && !s_fVelocity[1]) {
				if (s_iFlags & FL_DUCKING ) g_fAccuracy = 1.0;
				else g_fAccuracy = 0.96;
			} else g_fAccuracy = 0.92;
		} else g_fAccuracy = 0.92;
		set_member(iEnt, m_Weapon_flAccuracy, g_fAccuracy);
	} else if (get_member(iEnt, m_Weapon_iShotsFired) <= 0) {
		g_fAccuracy = Float:get_member(iEnt, m_Weapon_flAccuracy);
		g_fAccuracy -= (0.275-(get_gametime()-s_fLastFire))*0.25;
		if (g_fAccuracy < 0.725) g_fAccuracy = 0.725;
		else if (g_fAccuracy > 0.92) {
			static s_iOwner, s_iFlags;
			s_iOwner = get_entvar(iEnt, var_owner);
			s_iFlags = pev(s_iOwner, pev_flags);
			if (s_iFlags & FL_ONGROUND) {
				static Float:s_fVelocity[3];
				pev(s_iOwner, pev_velocity, s_fVelocity);
				if (!s_fVelocity[0] && !s_fVelocity[1]) {
					if (s_iFlags & FL_DUCKING) {
						if (g_fAccuracy > 1.0) g_fAccuracy = 1.0;
					} else if (g_fAccuracy > 0.96) g_fAccuracy = 0.96;
				} else g_fAccuracy = 0.92;
			} else g_fAccuracy = 0.92;
		}
		set_member(iEnt, m_Weapon_flAccuracy, g_fAccuracy);
	} else g_fAccuracy = -1.0;
}

public hook_fiveseven_post(iEnt) {
	if (g_fAccuracy > 0.92) set_member(iEnt, m_Weapon_flAccuracy, 0.92);
	else if (g_fAccuracy > 0.0) set_member(iEnt, m_Weapon_flAccuracy, g_fAccuracy);
}


public hook_galil_pre(iEnt) {
	static s_iShotsFired;
	s_iShotsFired = get_member(iEnt, m_Weapon_iShotsFired)-1;
	if (s_iShotsFired >= 0) {
		g_fAccuracy = ((s_iShotsFired*s_iShotsFired*s_iShotsFired)/200.0) + 0.2 + smooth_accuracy_transition((s_iShotsFired+1), 0.15, 4);
		if (g_fAccuracy > 1.25) g_fAccuracy = 1.25;
		set_member(iEnt, m_Weapon_flAccuracy, g_fAccuracy);
	} else {
		static s_iOwner, s_iFlags;
		s_iOwner = get_entvar(iEnt, var_owner);
		s_iFlags = pev(s_iOwner, pev_flags);
		if (s_iFlags & FL_ONGROUND) {
			static Float:s_fVelocity[3];
			pev(s_iOwner, pev_velocity, s_fVelocity);
			if (!s_fVelocity[0] && !s_fVelocity[1]) {
				if (s_iFlags & FL_DUCKING) set_member(iEnt, m_Weapon_flAccuracy, 0.0);
				else set_member(iEnt, m_Weapon_flAccuracy, 0.1);
			} else set_member(iEnt, m_Weapon_flAccuracy, 0.2);
		} else set_member(iEnt, m_Weapon_flAccuracy, 0.2);
	}
}


public hook_glock18_pre(iEnt) {
	static Float:s_fLastFire, bool:s_bInBurst;
	s_fLastFire = Float:get_member(iEnt, m_Weapon_flLastFire);
	s_bInBurst = ((get_member(iEnt, m_Weapon_iWeaponState) & WEAPONSTATE_GLOCK18_BURST_MODE) != 0);
	if (!s_fLastFire) {
		static s_iOwner, s_iFlags;
		s_iOwner = get_entvar(iEnt, var_owner);
		s_iFlags = pev(s_iOwner, pev_flags);
		if (s_iFlags & FL_ONGROUND) {
			pev(s_iOwner, pev_velocity, g_fGlockVelocity);
			if (!g_fGlockVelocity[0] && !g_fGlockVelocity[1]) {
				if (s_iFlags & FL_DUCKING) g_fAccuracy = 1.0;
				else g_fAccuracy = 0.95;
				if (s_bInBurst && !(s_iFlags & FL_DUCKING)) {
					g_bGlockVelocityChanged = true;
					set_pev(s_iOwner, pev_velocity, Float:{150.0, 0.0, 0.0});
				}
			} else {
				g_fAccuracy = 0.90;
				if (s_bInBurst) {
					g_bGlockVelocityChanged = true;
					set_pev(s_iOwner, pev_velocity, Float:{0.0, 0.0, 0.0});
					if (s_iFlags & FL_DUCKING) {
						g_bGlockDuckRemoved = true;
						set_pev(s_iOwner, pev_flags, (s_iFlags & ~FL_DUCKING));
					}
				}
			}
		} else g_fAccuracy = 0.90;
		set_member(iEnt, m_Weapon_flAccuracy, g_fAccuracy);
	} else if (s_bInBurst || (get_member(iEnt, m_Weapon_iShotsFired) <= 0)) {
		g_fAccuracy = Float:get_member(iEnt, m_Weapon_flAccuracy);
		g_fAccuracy -= (0.325-(get_gametime()-s_fLastFire))*0.275;
		if (g_fAccuracy < 0.6) g_fAccuracy = 0.6;
		else if (g_fAccuracy > 0.90) {
			static s_iOwner, s_iFlags;
			s_iOwner = get_entvar(iEnt, var_owner);
			s_iFlags = pev(s_iOwner, pev_flags);
			if (s_iFlags & FL_ONGROUND) {
				pev(s_iOwner, pev_velocity, g_fGlockVelocity);
				if (!g_fGlockVelocity[0] && !g_fGlockVelocity[1]) {
					if (s_iFlags & FL_DUCKING) {
						if (g_fAccuracy > 1.0) g_fAccuracy = 1.0;
					} else if (g_fAccuracy > 0.95) g_fAccuracy = 0.95;
					if (s_bInBurst) {
						if (!(s_iFlags & FL_DUCKING)) {
							g_bGlockVelocityChanged = true;
							set_pev(s_iOwner, pev_velocity, Float:{150.0, 0.0, 0.0});
						}
					}
				} else {
					g_fAccuracy = 0.90;
					if (s_bInBurst) {
						g_bGlockVelocityChanged = true;
						set_pev(s_iOwner, pev_velocity, Float:{0.0, 0.0, 0.0});
						if (s_iFlags & FL_DUCKING) {
							g_bGlockDuckRemoved = true;
							set_pev(s_iOwner, pev_flags, (s_iFlags & ~FL_DUCKING));
						}
					}
				}
			} else g_fAccuracy = 0.90;
		}
		set_member(iEnt, m_Weapon_flAccuracy, g_fAccuracy);
	} else g_fAccuracy = -1.0;
}

public hook_glock18_post(iEnt) {
	if (g_fAccuracy > 0.90) set_member(iEnt, m_Weapon_flAccuracy, 0.90);
	else if (g_fAccuracy > 0.0 ) set_member(iEnt, m_Weapon_flAccuracy, g_fAccuracy);
	static s_iOwner;
	s_iOwner = get_entvar(iEnt, var_owner);
	if (g_bGlockVelocityChanged) {
		g_bGlockVelocityChanged = false;
		set_pev(s_iOwner, pev_velocity, g_fGlockVelocity);
	}
	if (g_bGlockDuckRemoved) {
		g_bGlockDuckRemoved = false;
		set_pev(s_iOwner, pev_flags, (pev(s_iOwner, pev_flags)|FL_DUCKING));
	}
}


public hook_m249_pre(iEnt) {
	static s_iShotsFired;
	s_iShotsFired = get_member(iEnt, m_Weapon_iShotsFired)-1;
	if (s_iShotsFired >= 0) {
		g_fAccuracy = ((s_iShotsFired*s_iShotsFired*s_iShotsFired)/175.0) + 0.2 + smooth_accuracy_transition((s_iShotsFired+1), 0.2, 4);
		if (g_fAccuracy > 0.9) g_fAccuracy = 0.9;
		set_member(iEnt, m_Weapon_flAccuracy, g_fAccuracy);
	} else {
		static s_iOwner, s_iFlags;
		s_iOwner = get_entvar(iEnt, var_owner);
		s_iFlags = pev(s_iOwner, pev_flags);
		if (s_iFlags & FL_ONGROUND) {
			static Float:s_fVelocity[3];
			pev(s_iOwner, pev_velocity, s_fVelocity);
			if (!s_fVelocity[0] && !s_fVelocity[1]) {
				if (s_iFlags & FL_DUCKING) set_member(iEnt, m_Weapon_flAccuracy, 0.0);
				else set_member(iEnt, m_Weapon_flAccuracy, 0.1);
			} else set_member(iEnt, m_Weapon_flAccuracy, 0.2);
		} else set_member(iEnt, m_Weapon_flAccuracy, 0.2);
	}
}


public hook_m4a1_pre(iEnt) {
	static s_iShotsFired;
	s_iShotsFired = get_member(iEnt, m_Weapon_iShotsFired)-1;
	if (s_iShotsFired >= 0) {
		g_fAccuracy = ((s_iShotsFired*s_iShotsFired*s_iShotsFired)/220.0) + 0.2 + smooth_accuracy_transition((s_iShotsFired+1), 0.15, 3);
		if (g_fAccuracy > 1.25) g_fAccuracy = 1.25;
		set_member(iEnt, m_Weapon_flAccuracy, g_fAccuracy);
	} else {
		static s_iOwner, s_iFlags;
		s_iOwner = get_entvar(iEnt, var_owner);
		s_iFlags = pev(s_iOwner, pev_flags);
		if (s_iFlags & FL_ONGROUND) {
			static Float:s_fVelocity[3];
			pev(s_iOwner, pev_velocity, s_fVelocity);
			if (!s_fVelocity[0] && !s_fVelocity[1]) {
				if (s_iFlags & FL_DUCKING) set_member(iEnt, m_Weapon_flAccuracy, 0.0);
				else set_member(iEnt, m_Weapon_flAccuracy, 0.1);
			} else set_member(iEnt, m_Weapon_flAccuracy, 0.2);
		} else set_member(iEnt, m_Weapon_flAccuracy, 0.2);
	}
}


public hook_mac10_pre(iEnt) {
	static s_iShotsFired;
	s_iShotsFired = get_member(iEnt, m_Weapon_iShotsFired)-1;
	if (s_iShotsFired >= 0) {
		g_fAccuracy = ((s_iShotsFired*s_iShotsFired*s_iShotsFired)/200.0) + 0.15 + smooth_accuracy_transition((s_iShotsFired+1), 0.45, 8);
		if (g_fAccuracy > 1.65) g_fAccuracy = 1.65;
		set_member(iEnt, m_Weapon_flAccuracy, g_fAccuracy);
	} else {
		static s_iOwner, s_iFlags;
		s_iOwner = get_entvar(iEnt, var_owner);
		s_iFlags = pev(s_iOwner, pev_flags);
		
		if (s_iFlags & FL_ONGROUND) {
			static Float:s_fVelocity[3];
			pev(s_iOwner, pev_velocity, s_fVelocity);
			if (!s_fVelocity[0] && !s_fVelocity[1]) {
				if (s_iFlags & FL_DUCKING) set_member(iEnt, m_Weapon_flAccuracy, 0.0);
				else set_member(iEnt, m_Weapon_flAccuracy, 0.075);
			} else set_member(iEnt, m_Weapon_flAccuracy, 0.15);
		} else set_member(iEnt, m_Weapon_flAccuracy, 0.15);
	}
}


public hook_mp5navy_pre(iEnt) {
	static s_iShotsFired;
	s_iShotsFired = get_member(iEnt, m_Weapon_iShotsFired)-1;
	if (s_iShotsFired >=0) {
		g_fAccuracy = ((s_iShotsFired*s_iShotsFired)/220.0) + 0.2 + smooth_accuracy_transition((s_iShotsFired+1), 0.25, 5);
		if (g_fAccuracy > 0.75) g_fAccuracy = 0.75;
		set_member(iEnt, m_Weapon_flAccuracy, g_fAccuracy);
	} else {
		static s_iOwner, s_iFlags;
		s_iOwner = get_entvar(iEnt, var_owner);
		s_iFlags = pev(s_iOwner, pev_flags);
		if (s_iFlags & FL_ONGROUND) {
			static Float:s_fVelocity[3];
			pev(s_iOwner, pev_velocity, s_fVelocity);
			if (!s_fVelocity[0] && !s_fVelocity[1]) {
				if (s_iFlags & FL_DUCKING) set_member(iEnt, m_Weapon_flAccuracy, 0.0);
				else set_member(iEnt, m_Weapon_flAccuracy, 0.1);
			} else set_member(iEnt, m_Weapon_flAccuracy, 0.2);
		} else set_member(iEnt, m_Weapon_flAccuracy, 0.2);
	}
}


public hook_p228_pre(iEnt) {
	static Float:s_fLastFire;
	s_fLastFire = Float:get_member(iEnt, m_Weapon_flLastFire);
	if (!s_fLastFire) {
		static s_iOwner, s_iFlags;
		s_iOwner = get_entvar(iEnt, var_owner);
		s_iFlags = pev(s_iOwner, pev_flags);
		if (s_iFlags & FL_ONGROUND) {
			static Float:s_fVelocity[3];
			pev(s_iOwner, pev_velocity, s_fVelocity);
			if (!s_fVelocity[0] && !s_fVelocity[1]) {
				if (s_iFlags & FL_DUCKING) g_fAccuracy = 1.0;
				else g_fAccuracy = 0.95;
			} else g_fAccuracy = 0.90;
		} else g_fAccuracy = 0.90;
		set_member(iEnt, m_Weapon_flAccuracy, g_fAccuracy);
	} else if (get_member(iEnt, m_Weapon_iShotsFired) <= 0) {
		g_fAccuracy = Float:get_member(iEnt, m_Weapon_flAccuracy);
		g_fAccuracy -= (0.325-(get_gametime()-s_fLastFire))*0.3;
		if (g_fAccuracy < 0.6) g_fAccuracy = 0.6;
		else if (g_fAccuracy > 0.90) {
			static s_iOwner, s_iFlags;
			s_iOwner = get_entvar(iEnt, var_owner);
			s_iFlags = pev(s_iOwner, pev_flags);
			if (s_iFlags & FL_ONGROUND) {
				static Float:s_fVelocity[3];
				pev(s_iOwner, pev_velocity, s_fVelocity);
				if (!s_fVelocity[0] && !s_fVelocity[1]) {
					if (s_iFlags & FL_DUCKING) {
						if (g_fAccuracy > 1.0) g_fAccuracy = 1.0;
					} else if (g_fAccuracy > 0.95) g_fAccuracy = 0.95;
				} else g_fAccuracy = 0.90;
			} else g_fAccuracy = 0.90;
		}
		set_member(iEnt, m_Weapon_flAccuracy, g_fAccuracy);
	} else g_fAccuracy = -1.0;
}

public hook_p228_post(iEnt) {
	if (g_fAccuracy > 0.90) set_member(iEnt, m_Weapon_flAccuracy, 0.90);
	else if (g_fAccuracy > 0.0) set_member(iEnt, m_Weapon_flAccuracy, g_fAccuracy);
}


public hook_p90_pre(iEnt) {
	static s_iShotsFired;
	s_iShotsFired = get_member(iEnt, m_Weapon_iShotsFired)-1;
	if (s_iShotsFired >= 0) {
		g_fAccuracy = ((s_iShotsFired*s_iShotsFired)/175.0)+0.2+smooth_accuracy_transition((s_iShotsFired+1), 0.25, 6);
		if (g_fAccuracy > 1.0) g_fAccuracy = 1.0;
		set_member(iEnt, m_Weapon_flAccuracy, g_fAccuracy);
	} else {
		static s_iOwner, s_iFlags;
		s_iOwner = get_entvar(iEnt, var_owner);
		s_iFlags = pev(s_iOwner, pev_flags);
		if (s_iFlags & FL_ONGROUND) {
			static Float:s_fVelocity[3];
			pev(s_iOwner, pev_velocity, s_fVelocity);
			if (!s_fVelocity[0] && !s_fVelocity[1]) {
				if (s_iFlags & FL_DUCKING) set_member(iEnt, m_Weapon_flAccuracy, 0.0);
				else set_member(iEnt, m_Weapon_flAccuracy, 0.1);
			} else set_member(iEnt, m_Weapon_flAccuracy, 0.2);
		} else set_member(iEnt, m_Weapon_flAccuracy, 0.2);
	}
}


public hook_scout_pre(iEnt) {
	static s_iOwner, s_iFlags;
	s_iOwner = get_entvar(iEnt, var_owner);
	s_iFlags = pev(s_iOwner, pev_flags);
	
	if ((s_iFlags & FL_DUCKING) || (s_iFlags & ~FL_ONGROUND)) g_fAccuracy = 0.0;
	else {
		static Float:s_fVelocity[3];
		pev(s_iOwner, pev_velocity, s_fVelocity);
		if (!s_fVelocity[0] && !s_fVelocity[1]) {
			set_pev(s_iOwner, pev_flags, (s_iFlags|FL_DUCKING));
			g_fAccuracy = 1.0;
		} else g_fAccuracy = 0.0;
	}
}

public hook_scout_post(iEnt) {
	if (g_fAccuracy) {
		static s_iOwner;
		s_iOwner = get_entvar(iEnt, var_owner);
		set_pev(s_iOwner, pev_flags, (pev(s_iOwner, pev_flags) & ~FL_DUCKING));
	}
}


public hook_sg550_pre(iEnt) {
	static Float:s_fLastFire;
	s_fLastFire = Float:get_member(iEnt, m_Weapon_flLastFire);
	if (!s_fLastFire) {
		static s_iOwner, s_iFlags;
		s_iOwner = get_entvar(iEnt, var_owner);
		s_iFlags = pev(s_iOwner, pev_flags);
		if (s_iFlags & FL_ONGROUND) {
			static Float:s_fVelocity[3];
			pev(s_iOwner, pev_velocity, s_fVelocity);
			if (!s_fVelocity[0] && !s_fVelocity[1]) {
				if (s_iFlags & FL_DUCKING) g_fAccuracy = 1.0;
				else g_fAccuracy = 0.99;
			} else g_fAccuracy = 0.98;
		} else g_fAccuracy = 0.98;
		set_member(iEnt, m_Weapon_flAccuracy, g_fAccuracy);
	} else {
		g_fAccuracy = (0.65+(get_gametime()-s_fLastFire))*0.725; //*0.35; (this is way too inaccurate comparing to g3sg1)
		if (g_fAccuracy > 0.98) {
			static s_iOwner, s_iFlags;
			s_iOwner = get_entvar(iEnt, var_owner);
			s_iFlags = pev(s_iOwner, pev_flags);
			if (s_iFlags & FL_ONGROUND) {
				static Float:s_fVelocity[3];
				pev(s_iOwner, pev_velocity, s_fVelocity);
				if (!s_fVelocity[0] && !s_fVelocity[1]) {
					if (s_iFlags & FL_DUCKING) {
						if (g_fAccuracy > 1.0) g_fAccuracy = 1.0;
					} else if (g_fAccuracy > 0.99) g_fAccuracy = 0.99;
				} else g_fAccuracy = 0.98;
			} else g_fAccuracy = 0.98;
		} else if (g_fAccuracy < 0.5) g_fAccuracy = 0.5;
		set_member(iEnt, m_Weapon_flAccuracy, g_fAccuracy);
	}
}


public hook_sg552_pre(iEnt) {
	static s_iShotsFired;
	s_iShotsFired = get_member(iEnt, m_Weapon_iShotsFired)-1;
	if (s_iShotsFired >=0) {
		g_fAccuracy = ((s_iShotsFired*s_iShotsFired*s_iShotsFired)/220.0)+0.2+smooth_accuracy_transition((s_iShotsFired+1), 0.1, 3);
		if (g_fAccuracy > 1.0) g_fAccuracy = 1.0;
		set_member(iEnt, m_Weapon_flAccuracy, g_fAccuracy);
	} else {
		static s_iOwner, s_iFlags;
		s_iOwner = get_entvar(iEnt, var_owner);
		s_iFlags = pev(s_iOwner, pev_flags);
		if (s_iFlags & FL_ONGROUND) {
			static Float:s_fVelocity[3];
			pev(s_iOwner, pev_velocity, s_fVelocity);
			if (!s_fVelocity[0] && !s_fVelocity[1]) {
				if (s_iFlags & FL_DUCKING) set_member(iEnt, m_Weapon_flAccuracy, 0.0);
				else set_member(iEnt, m_Weapon_flAccuracy, 0.1);
			} else set_member(iEnt, m_Weapon_flAccuracy, 0.2);
		} else set_member(iEnt, m_Weapon_flAccuracy, 0.2);
	}
}


public hook_tmp_pre(iEnt) {
	static s_iShotsFired;
	s_iShotsFired = get_member(iEnt, m_Weapon_iShotsFired)-1;
	if (s_iShotsFired >= 0) {
		g_fAccuracy = (((s_iShotsFired*s_iShotsFired*s_iShotsFired)/220.0)+0.2+smooth_accuracy_transition((s_iShotsFired+1), 0.35, 7));
		if (g_fAccuracy > 1.4) g_fAccuracy = 1.4;
		set_member(iEnt, m_Weapon_flAccuracy, g_fAccuracy);
	} else {
		static s_iOwner, s_iFlags;
		s_iOwner = get_entvar(iEnt, var_owner);
		s_iFlags = pev(s_iOwner, pev_flags);
		if (s_iFlags & FL_ONGROUND) {
			static Float:s_fVelocity[3];
			pev(s_iOwner, pev_velocity, s_fVelocity);
			if (!s_fVelocity[0] && !s_fVelocity[1]) {
				if (s_iFlags & FL_DUCKING) set_member(iEnt, m_Weapon_flAccuracy, 0.0);
				else set_member(iEnt, m_Weapon_flAccuracy, 0.1);
			} else set_member(iEnt, m_Weapon_flAccuracy, 0.2);
		} else set_member(iEnt, m_Weapon_flAccuracy, 0.2);
	}
}


public hook_ump45_pre(iEnt) {
	static s_iShotsFired;
	s_iShotsFired = get_member(iEnt, m_Weapon_iShotsFired)-1;
	if (s_iShotsFired >= 0) {
		g_fAccuracy = (((s_iShotsFired*s_iShotsFired)/210.0)+0.2+smooth_accuracy_transition((s_iShotsFired+1), 0.3, 5));
		if (g_fAccuracy > 1.0) g_fAccuracy = 1.0;
		set_member(iEnt, m_Weapon_flAccuracy, g_fAccuracy);
	} else {
		static s_iOwner, s_iFlags;
		s_iOwner = get_entvar(iEnt, var_owner);
		s_iFlags = pev(s_iOwner, pev_flags);
		if (s_iFlags & FL_ONGROUND) {
			static Float:s_fVelocity[3];
			pev(s_iOwner, pev_velocity, s_fVelocity);
			if (!s_fVelocity[0] && !s_fVelocity[1]) {
				if (s_iFlags & FL_DUCKING) set_member(iEnt, m_Weapon_flAccuracy, 0.0);
				else set_member(iEnt, m_Weapon_flAccuracy, 0.1);
			} else set_member(iEnt, m_Weapon_flAccuracy, 0.2);
		} else set_member(iEnt, m_Weapon_flAccuracy, 0.2);
	}
}


public hook_usp_pre(iEnt) {
	static Float:s_fLastFire;
	s_fLastFire = Float:get_member(iEnt, m_Weapon_flLastFire);
	if (!s_fLastFire) {
		static s_iOwner, s_iFlags;
		s_iOwner = get_entvar(iEnt, var_owner);
		s_iFlags = pev(s_iOwner, pev_flags);
		if (s_iFlags & FL_ONGROUND) {
			static Float:s_fVelocity[3];
			pev(s_iOwner, pev_velocity, s_fVelocity);
			if (!s_fVelocity[0] && !s_fVelocity[1]) {
				if (s_iFlags & FL_DUCKING) g_fAccuracy = 1.0;
				else g_fAccuracy = 0.96;
			} else g_fAccuracy = 0.92;
		} else g_fAccuracy = 0.92;
		set_member(iEnt, m_Weapon_flAccuracy, g_fAccuracy);
	} else if (get_member(iEnt, m_Weapon_iShotsFired) <= 0) {
		g_fAccuracy = Float:get_member(iEnt, m_Weapon_flAccuracy);
		g_fAccuracy -= (0.3-(get_gametime()-s_fLastFire))*0.275;
		if (g_fAccuracy < 0.6) g_fAccuracy = 0.6;
		else if (g_fAccuracy > 0.92) {
			static s_iOwner, s_iFlags;
			s_iOwner = get_entvar(iEnt, var_owner);
			s_iFlags = pev(s_iOwner, pev_flags);
			if (s_iFlags & FL_ONGROUND) {
				static Float:s_fVelocity[3];
				pev(s_iOwner, pev_velocity, s_fVelocity);
				if (!s_fVelocity[0] && !s_fVelocity[1]) {
					if (s_iFlags & FL_DUCKING) {
						if (g_fAccuracy > 1.0) g_fAccuracy = 1.0;
					} else if (g_fAccuracy > 0.96) g_fAccuracy = 0.96;
				} else g_fAccuracy = 0.92;
			} else g_fAccuracy = 0.92;
		}
		set_member(iEnt, m_Weapon_flAccuracy, g_fAccuracy);
	} else g_fAccuracy = -1.0;
}

public hook_usp_post(iEnt) {
	if (g_fAccuracy > 0.92) set_member(iEnt, m_Weapon_flAccuracy, 0.92);
	else if (g_fAccuracy > 0.0) set_member(iEnt, m_Weapon_flAccuracy, g_fAccuracy);
}
