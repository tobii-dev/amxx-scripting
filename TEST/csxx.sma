#include <amxmodx>
#include <csx>


public plugin_init() {
	register_plugin("CSXX TEST", "0.1", "tobii");
}


public client_damage(attacker, victim, damage, wpnindex, hitplace, TA) {
	client_print(0, print_chat, " <> client_damage(attacker=%i, victim=%i, damage=%i, wpnindex=%i, hitplace=%i, TA=%i", attacker, victim, damage, wpnindex, hitplace, TA);
}

#pragma semicolon 1

