# easymq
simple bash script to administrate usernames, roles and ACLs using mosquitto_ctrl

Instead of looking up all parameters of mosquitto_ctrl all the time and loose overview what role and acl was set for which mqtt client, this script is more interactive.

Currently supported are administrating users (clients), role and acls. I didn't need groups yet, it's there, but not functional (yet).

MOSQUITTO_CTRL_CMD="mosquitto_ctrl -o /root/.config/mosquitto_ctrl dynsec" needs to be adjusted according to environment. /root/.config/mosquitto_ctrl is my crendetial file for mosquitto_ctrl.
