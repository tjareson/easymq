#!/bin/bash

# Define the mosquitto_ctrl command with options for convenience
MOSQUITTO_CTRL_CMD="mosquitto_ctrl -o /root/.config/mosquitto_ctrl dynsec"

# Helper function to select an item from a list using fzf
select_with_fzf() {
    local list="$1"
    local prompt="$2"
    # Clear previous output to keep fzf window tidy
    clear
    echo "$list" | \
        fzf --prompt="$prompt" --height=40% --border \
            --color=16,bg+:blue,fg+:white,bg:blue,fg:white,\
info:white,prompt:cyan,pointer:red,marker:red,border:white
}

# ------------------- User Management -------------------
create_user() {
    local username client_id
    username=$(whiptail --inputbox "Enter username" 8 40 3>&1 1>&2 2>&3) || return
    client_id=$(whiptail --inputbox "Enter client ID for $username" 8 40 3>&1 1>&2 2>&3) || return
    $MOSQUITTO_CTRL_CMD createClient "$username" -c "$client_id"
    whiptail --msgbox "User '$username' created." 8 40
}

delete_user() {
    local users selected_user
    users=$($MOSQUITTO_CTRL_CMD listClients)
    if [ -z "$users" ]; then
        whiptail --msgbox "No users found." 8 40
        return
    fi
    selected_user=$(select_with_fzf "$users" "Delete user > ") || return
    [ -z "$selected_user" ] && return
    whiptail --yesno "Delete user '$selected_user'?" 8 40 || return
    $MOSQUITTO_CTRL_CMD deleteClient "$selected_user"
    whiptail --msgbox "User '$selected_user' deleted." 8 40
}

list_users() {
    local users tmp
    users=$($MOSQUITTO_CTRL_CMD listClients)
    if [ -z "$users" ]; then
        whiptail --msgbox "No users found." 8 40
        return
    fi
    tmp=$(mktemp)
    while read -r user; do
        {
            echo "User: $user"
            $MOSQUITTO_CTRL_CMD getClient "$user"
            echo
        } >> "$tmp"
    done <<< "$users"
    whiptail --scrolltext --textbox "$tmp" 20 70
    rm -f "$tmp"
}

manage_users_menu() {
    while true; do
        local choice
        choice=$(whiptail --title "Manage Users" --menu "Choose an option" 15 60 4 \
            1 "Create User" \
            2 "Delete User" \
            3 "List Users" \
            4 "Back" 3>&1 1>&2 2>&3) || return
        case $choice in
            1) create_user ;;
            2) delete_user ;;
            3) list_users ;;
            4) return ;;
        esac
    done
}

# ------------------- Group Management -------------------
create_group() {
    local group
    group=$(whiptail --inputbox "Enter group name" 8 40 3>&1 1>&2 2>&3) || return
    $MOSQUITTO_CTRL_CMD createGroup "$group"
    whiptail --msgbox "Group '$group' created." 8 40
}

delete_group() {
    local groups selected
    groups=$($MOSQUITTO_CTRL_CMD listGroups)
    if [ -z "$groups" ]; then
        whiptail --msgbox "No groups found." 8 40
        return
    fi
    selected=$(select_with_fzf "$groups" "Delete group > ") || return
    [ -z "$selected" ] && return
    whiptail --yesno "Delete group '$selected'?" 8 40 || return
    $MOSQUITTO_CTRL_CMD deleteGroup "$selected"
    whiptail --msgbox "Group '$selected' deleted." 8 40
}

list_groups() {
    local groups
    groups=$($MOSQUITTO_CTRL_CMD listGroups)
    if [ -z "$groups" ]; then
        whiptail --msgbox "No groups found." 8 40
    else
        whiptail --msgbox "$groups" 20 60
    fi
}

manage_groups_menu() {
    while true; do
        local choice
        choice=$(whiptail --title "Manage Groups" --menu "Choose an option" 15 60 4 \
            1 "Create Group" \
            2 "Delete Group" \
            3 "List Groups" \
            4 "Back" 3>&1 1>&2 2>&3) || return
        case $choice in
            1) create_group ;;
            2) delete_group ;;
            3) list_groups ;;
            4) return ;;
        esac
    done
}

# ------------------- Role Management -------------------
create_role() {
    local role_name existing_roles selected_role_to_copy acls_to_copy acl
    role_name=$(whiptail --inputbox "Enter role name" 8 40 3>&1 1>&2 2>&3) || return
    $MOSQUITTO_CTRL_CMD createRole "$role_name"
    if whiptail --yesno "Copy ACLs from existing role?" 8 40; then
        existing_roles=$($MOSQUITTO_CTRL_CMD listRoles)
        if [ -z "$existing_roles" ]; then
            whiptail --msgbox "No roles available to copy from." 8 40
        else
            selected_role_to_copy=$(select_with_fzf "$existing_roles" "Copy from > ") || true
            if [ -n "$selected_role_to_copy" ]; then
                acls_to_copy=$( $MOSQUITTO_CTRL_CMD getRole "$selected_role_to_copy" | \
                    grep -E '^\s{10,}|^ACLs:' | sed -e 's/^ACLs:\s*//' -e 's/^\s\{10,\}//' -e 's/(priority: [0-9]\+)//' -e 's/()//' )
                while read -r acl; do
                    [ -z "$acl" ] && continue
                    acl_type=$(echo "$acl" | awk -F' : ' '{print $1}' | xargs)
                    action=$(echo "$acl" | awk -F' : ' '{print $2}' | xargs)
                    topic=$(echo "$acl" | awk -F' : ' '{print $3}' | xargs)
                    $MOSQUITTO_CTRL_CMD addRoleACL "$role_name" "$acl_type" "$topic" "$action" 5
                done <<< "$acls_to_copy"
            fi
        fi
    fi
    whiptail --msgbox "Role '$role_name' created." 8 40
}

delete_role() {
    local roles selected
    roles=$($MOSQUITTO_CTRL_CMD listRoles)
    if [ -z "$roles" ]; then
        whiptail --msgbox "No roles found." 8 40
        return
    fi
    selected=$(select_with_fzf "$roles" "Delete role > ") || return
    [ -z "$selected" ] && return
    whiptail --yesno "Delete role '$selected'?" 8 40 || return
    $MOSQUITTO_CTRL_CMD deleteRole "$selected"
    whiptail --msgbox "Role '$selected' deleted." 8 40
}

list_roles() {
    local roles
    roles=$($MOSQUITTO_CTRL_CMD listRoles)
    if [ -z "$roles" ]; then
        whiptail --msgbox "No roles found." 8 40
    else
        whiptail --msgbox "$roles" 20 60
    fi
}

assign_role_to_user() {
    local users selected_user roles selected_role
    users=$($MOSQUITTO_CTRL_CMD listClients)
    [ -z "$users" ] && { whiptail --msgbox "No users found." 8 40; return; }
    selected_user=$(select_with_fzf "$users" "Select user > ") || return
    [ -z "$selected_user" ] && return
    roles=$($MOSQUITTO_CTRL_CMD listRoles)
    [ -z "$roles" ] && { whiptail --msgbox "No roles found." 8 40; return; }
    selected_role=$(select_with_fzf "$roles" "Assign role > ") || return
    [ -z "$selected_role" ] && return
    $MOSQUITTO_CTRL_CMD addClientRole "$selected_user" "$selected_role"
    whiptail --msgbox "Role '$selected_role' assigned to '$selected_user'." 8 50
}

remove_role_from_user() {
    local users selected_user roles_lines selected_role
    users=$($MOSQUITTO_CTRL_CMD listClients)
    [ -z "$users" ] && { whiptail --msgbox "No users found." 8 40; return; }
    selected_user=$(select_with_fzf "$users" "Select user > ") || return
    [ -z "$selected_user" ] && return
    roles_lines=$( $MOSQUITTO_CTRL_CMD getClient "$selected_user" | grep -oP '^Roles:\s+\K.*$|^\s{10}\K.*$' )
    if [ -z "$roles_lines" ]; then
        whiptail --msgbox "User has no roles." 8 40
        return
    fi
    selected_role=$(select_with_fzf "$roles_lines" "Remove role > " | awk '{print $1}') || return
    [ -z "$selected_role" ] && return
    whiptail --yesno "Remove role '$selected_role' from '$selected_user'?" 8 50 || return
    $MOSQUITTO_CTRL_CMD removeClientRole "$selected_user" "$selected_role"
    whiptail --msgbox "Role '$selected_role' removed from '$selected_user'." 8 50
}

manage_roles_menu() {
    while true; do
        local choice
        choice=$(whiptail --title "Manage Roles" --menu "Choose an option" 15 60 6 \
            1 "Create Role" \
            2 "Delete Role" \
            3 "List Roles" \
            4 "Assign Role to User" \
            5 "Remove Role from User" \
            6 "Back" 3>&1 1>&2 2>&3) || return
        case $choice in
            1) create_role ;;
            2) delete_role ;;
            3) list_roles ;;
            4) assign_role_to_user ;;
            5) remove_role_from_user ;;
            6) return ;;
        esac
    done
}

# ------------------- ACL Management -------------------
add_acl() {
    local roles selected_role acl_type topic action_option action
    roles=$($MOSQUITTO_CTRL_CMD listRoles)
    if [ -z "$roles" ]; then
        whiptail --msgbox "No roles found." 8 40
        return
    fi
    selected_role=$(select_with_fzf "$roles" "Role > ") || return
    [ -z "$selected_role" ] && return
    acl_type=$(whiptail --title "ACL Type" --menu "Select ACL type" 15 60 6 \
        "publishClientSend" "publishClientSend" \
        "publishClientReceive" "publishClientReceive" \
        "subscribeLiteral" "subscribeLiteral" \
        "subscribePattern" "subscribePattern" \
        "unsubscribeLiteral" "unsubscribeLiteral" \
        "unsubscribePattern" "unsubscribePattern" 3>&1 1>&2 2>&3) || return
    topic=$(whiptail --inputbox "Enter topic filter" 8 40 3>&1 1>&2 2>&3) || return
    action_option=$(whiptail --title "ACL Action" --menu "Allow or Deny" 10 40 2 1 "Allow" 2 "Deny" 3>&1 1>&2 2>&3) || return
    case $action_option in
        1) action="allow" ;;
        2) action="deny" ;;
    esac
    $MOSQUITTO_CTRL_CMD addRoleACL "$selected_role" "$acl_type" "$topic" "$action" 5
    whiptail --msgbox "ACL added to '$selected_role'." 8 40
}

remove_acl() {
    local roles selected_role acls selected_acl acl_type topic
    roles=$($MOSQUITTO_CTRL_CMD listRoles)
    if [ -z "$roles" ]; then
        whiptail --msgbox "No roles found." 8 40
        return
    fi
    selected_role=$(select_with_fzf "$roles" "Role > ") || return
    [ -z "$selected_role" ] && return
    acls=$( $MOSQUITTO_CTRL_CMD getRole "$selected_role" | \
        grep -E '^\s{10,}|^ACLs:' | sed -e 's/^ACLs:\s*//' -e 's/^\s\{10,\}//' -e 's/(priority: [0-9]\+)//' -e 's/()//' )
    if [ -z "$acls" ]; then
        whiptail --msgbox "No ACLs found for this role." 8 40
        return
    fi
    selected_acl=$(select_with_fzf "$acls" "Remove ACL > ") || return
    [ -z "$selected_acl" ] && return
    acl_type=$(echo "$selected_acl" | awk -F' : ' '{print $1}' | xargs)
    topic=$(echo "$selected_acl" | awk -F' : ' '{print $3}' | xargs)
    whiptail --yesno "Remove ACL '$acl_type $topic' from '$selected_role'?" 8 50 || return
    $MOSQUITTO_CTRL_CMD removeRoleACL "$selected_role" "$acl_type" "$topic"
    whiptail --msgbox "ACL removed from '$selected_role'." 8 40
}

list_acls() {
    local roles selected_role acls tmp
    roles=$($MOSQUITTO_CTRL_CMD listRoles)
    if [ -z "$roles" ]; then
        whiptail --msgbox "No roles found." 8 40
        return
    fi
    selected_role=$(select_with_fzf "$roles" "Role > ") || return
    [ -z "$selected_role" ] && return
    acls=$( $MOSQUITTO_CTRL_CMD getRole "$selected_role" | \
        grep -E '^\s{10,}|^ACLs:' | sed -e 's/^ACLs:\s*//' -e 's/^\s\{10,\}//' -e 's/(priority: [0-9]\+)//' -e 's/()//' )
    if [ -z "$acls" ]; then
        whiptail --msgbox "No ACLs found for this role." 8 40
        return
    fi
    tmp=$(mktemp)
    echo "$acls" > "$tmp"
    whiptail --scrolltext --textbox "$tmp" 20 70
    rm -f "$tmp"
}

manage_acls_menu() {
    while true; do
        local choice
        choice=$(whiptail --title "Manage ACLs" --menu "Choose an option" 15 60 4 \
            1 "Add ACL to Role" \
            2 "Remove ACL from Role" \
            3 "List ACLs for Role" \
            4 "Back" 3>&1 1>&2 2>&3) || return
        case $choice in
            1) add_acl ;;
            2) remove_acl ;;
            3) list_acls ;;
            4) return ;;
        esac
    done
}

# ------------------- Main Menu -------------------
while true; do
    choice=$(whiptail --title "EasyMQ" --menu "Select an option" 15 60 5 \
        1 "Manage Users" \
        2 "Manage Groups" \
        3 "Manage Roles" \
        4 "Manage ACLs" \
        5 "Exit" 3>&1 1>&2 2>&3) || exit 0
    case $choice in
        1) manage_users_menu ;;
        2) manage_groups_menu ;;
        3) manage_roles_menu ;;
        4) manage_acls_menu ;;
        5) exit 0 ;;
    esac
done
