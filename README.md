# easymq
simple bash script to administrate usernames, roles and ACLs using mosquitto_ctrl

Instead of looking up all parameters of mosquitto_ctrl all the time and loose overview what role and acl was set for which mqtt client, this script is more interactive.

Currently supported operations include managing users (clients), roles and ACLs. Groups can be created and deleted but currently have no functional effect.

## Dependencies
This script relies on `whiptail` for dialog boxes and `fzf` for interactive
selections. On an Ubuntu server they can be installed with:

```bash
sudo apt update
sudo apt install whiptail fzf
```

MOSQUITTO_CTRL_CMD="mosquitto_ctrl -o /root/.config/mosquitto_ctrl dynsec" needs to be adjusted according to environment. /root/.config/mosquitto_ctrl is my credential file for mosquitto_ctrl.
In the credential file there need to be:
```
-u username
-P password
-h server-ip-mosquitto
```


<img width="999" height="567" alt="image" src="https://github.com/user-attachments/assets/a2e33144-01a6-4ce9-9efe-243d8d5dea2a" />
