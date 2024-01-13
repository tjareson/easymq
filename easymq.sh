#!/bin/bash

# Define the mosquitto_ctrl command with options for convenience
MOSQUITTO_CTRL_CMD="mosquitto_ctrl -o /root/.config/mosquitto_ctrl dynsec"

# Function to display menu options
show_menu() {
    echo "1. Manage Users"
    echo "2. Manage Groups"
    echo "3. Manage Roles"
    echo "4. Manage ACLs"
    echo "5. Exit"
    echo -n "Please choose an option: "
}

# Function to manage users
manage_users() {
    echo "1. Create User"
    echo "2. Delete User"
    echo "3. List Users"
    echo -n "Choose an option: "
    read option

    case $option in
        1)
            echo -n "Enter username to create: "
            read username
            echo
            $MOSQUITTO_CTRL_CMD createClient "$username"
            ;;
        2)
            echo "Fetching list of users..."
            users=$($MOSQUITTO_CTRL_CMD listClients)
            if [ -z "$users" ]; then
                echo "No users found."
                return
            fi

            echo "Select the user to delete:"
            IFS=$'\n' read -rd '' -a user_array <<< "$users"
            for i in "${!user_array[@]}"; do
                echo "$((i+1)). ${user_array[i]}"
            done

            read -p "Enter the number of the user to delete: " user_number
            if [[ $user_number -lt 1 || $user_number -gt ${#user_array[@]} ]]; then
                echo "Invalid selection. Operation cancelled."
                return
            fi

            selected_user=${user_array[$((user_number-1))]}
            read -p "Are you sure you want to delete user '$selected_user'? [y/N]: " confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                $MOSQUITTO_CTRL_CMD deleteClient "$selected_user"
                echo "User '$selected_user' deleted."
            else
                echo "Operation cancelled."
            fi
            ;;
3)
    echo "Fetching list of users and their details..."
    users=$($MOSQUITTO_CTRL_CMD listClients)
    if [ -z "$users" ]; then
        echo "No users found."
        return
    fi

    IFS=$'\n' read -rd '' -a user_array <<< "$users"
    for user in "${user_array[@]}"; do
        echo "User: $user"
        # Displaying the complete output from getClient for each user
        $MOSQUITTO_CTRL_CMD getClient "$user"
    done
    ;;

        *)
            echo "Invalid option"
            ;;
    esac
}

# Function to manage groups
manage_groups() {
    echo "1. Create Group"
    echo "2. Delete Group"
    echo "3. List Groups"
    echo -n "Choose an option: "
    read option

    case $option in
        1)
            echo -n "Enter group name to create: "
            read group_name
            $MOSQUITTO_CTRL_CMD createGroup "$group_name"
            ;;
        2)
            echo -n "Enter group name to delete: "
            read group_name
            $MOSQUITTO_CTRL_CMD deleteGroup "$group_name"
            ;;
        3)
            $MOSQUITTO_CTRL_CMD listGroups
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
}

# Function to manage roles
manage_roles() {
    echo "1. Create Role"
    echo "2. Delete Role"
    echo "3. List Roles"
    echo "4. Assign Role to User"
    echo "5. Remove Role from User"
    echo -n "Choose an option: "
    read option

    case $option in
1)
    echo -n "Enter role name to create: "
    read role_name
    $MOSQUITTO_CTRL_CMD createRole "$role_name"

    read -p "Do you want to copy ACLs from an existing role? [y/N]: " copy_acl_confirm
    if [[ $copy_acl_confirm =~ ^[Yy]$ ]]; then
        echo "Fetching list of existing roles..."
        roles=$($MOSQUITTO_CTRL_CMD listRoles)
        if [ -z "$roles" ]; then
            echo "No existing roles found."
            return
        fi

        echo "Select a role to copy ACLs from:"
        IFS=$'\n' read -rd '' -a role_array <<< "$roles"
        for i in "${!role_array[@]}"; do
            echo "$((i+1)). ${role_array[i]}"
        done

        read -p "Enter the number of the role: " role_number
        if [[ -z "$role_number" || $role_number -lt 1 || $role_number -gt ${#role_array[@]} ]]; then
            echo "Invalid selection. Operation cancelled."
            return
        fi

        selected_role_to_copy=${role_array[$((role_number-1))]}
        echo "Copying ACLs from role '$selected_role_to_copy' to '$role_name'..."

        # Adjusted parsing logic to include the first ACL
        acls_to_copy=$($MOSQUITTO_CTRL_CMD getRole "$selected_role_to_copy" | grep -E '^\s{10,}|^ACLs:' | sed -e 's/^ACLs:\s*//' -e 's/^\s\{10,\}//' -e 's/\(priority: [0-9]\+\)//' -e 's/()//')
        IFS=$'\n' read -rd '' -a acl_array <<< "$acls_to_copy"
        for acl in "${acl_array[@]}"; do
            acl_type=$(echo "$acl" | awk -F' : ' '{print $1}' | xargs)
            action=$(echo "$acl" | awk -F' : ' '{print $2}' | xargs)
            topic=$(echo "$acl" | awk -F' : ' '{print $3}' | xargs)
            $MOSQUITTO_CTRL_CMD addRoleACL "$role_name" "$acl_type" "$topic" "$action" 5
        done
        echo "All ACLs copied to role '$role_name'."
    fi
    ;;

        2)
            echo "Fetching list of roles..."
            roles=$($MOSQUITTO_CTRL_CMD listRoles)
            if [ -z "$roles" ]; then
                echo "No roles found."
                return
            fi

            echo "Select the role to delete:"
            IFS=$'\n' read -rd '' -a role_array <<< "$roles"
            for i in "${!role_array[@]}"; do
                echo "$((i+1)). ${role_array[i]}"
            done

            read -p "Enter the number of the role to delete: " role_number
            if [[ $role_number -lt 1 || $role_number -gt ${#role_array[@]} ]]; then
                echo "Invalid selection. Operation cancelled."
                return
            fi

            selected_role=${role_array[$((role_number-1))]}
            read -p "Are you sure you want to delete role '$selected_role'? [y/N]: " confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                $MOSQUITTO_CTRL_CMD deleteRole "$selected_role"
                echo "Role '$selected_role' deleted."
            else
                echo "Operation cancelled."
            fi
            ;;
        3)
            $MOSQUITTO_CTRL_CMD listRoles
            ;;
	 4)
            echo "Select a user to assign a role to:"
            users=$($MOSQUITTO_CTRL_CMD listClients)
            IFS=$'\n' read -rd '' -a user_array <<< "$users"
            for i in "${!user_array[@]}"; do
                echo "$((i+1)). ${user_array[i]}"
            done

            read -p "Enter the number of the user: " user_number
            selected_user=${user_array[$((user_number-1))]}
            echo "User '$selected_user' currently has the following roles:"
            $MOSQUITTO_CTRL_CMD getClient "$selected_user"

            echo "Select a role to assign to the user:"
            roles=$($MOSQUITTO_CTRL_CMD listRoles)
            IFS=$'\n' read -rd '' -a role_array <<< "$roles"
            for i in "${!role_array[@]}"; do
                echo "$((i+1)). ${role_array[i]}"
            done

            read -p "Enter the number of the role: " role_number
            selected_role=${role_array[$((role_number-1))]}
            $MOSQUITTO_CTRL_CMD addClientRole "$selected_user" "$selected_role"
            echo "Role '$selected_role' assigned to user '$selected_user'."
            ;;
    5)
        echo "Select a user to remove a role from:"
        users=$($MOSQUITTO_CTRL_CMD listClients)
        IFS=$'\n' read -rd '' -a user_array <<< "$users"
        for i in "${!user_array[@]}"; do
            echo "$((i+1)). ${user_array[i]}"
        done

        read -p "Enter the number of the user: " user_number
        if [[ -z "$user_number" || $user_number -lt 1 || $user_number -gt ${#user_array[@]} ]]; then
            echo "Invalid selection. Operation cancelled."
            return
        fi

        selected_user=${user_array[$((user_number-1))]}
        echo "User '$selected_user' currently has the following roles:"
        user_details=$($MOSQUITTO_CTRL_CMD getClient "$selected_user")
        IFS=$'\n' read -rd '' -a roles_lines <<< "$(echo "$user_details" | grep -oP '^Roles:\s+\K.*$|^          \K.*$')"

        if [ ${#roles_lines[@]} -eq 0 ]; then
            echo "No roles found for this user."
            return
        fi

        for i in "${!roles_lines[@]}"; do
            role_name=$(echo "${roles_lines[i]}" | awk '{print $1}')
            echo "$((i+1)). $role_name"
        done

        read -p "Enter the number of the role to remove: " role_number
        if [[ -z "$role_number" || $role_number -lt 1 || $role_number -gt ${#roles_lines[@]} ]]; then
            echo "Invalid selection. Operation cancelled."
            return
        fi

        selected_role=$(echo "${roles_lines[$((role_number-1))]}" | awk '{print $1}')
        read -p "Are you sure you want to remove role '$selected_role' from user '$selected_user'? [y/N]: " confirm
        if [[ $confirm =~ ^[Yy]$ ]]; then
            $MOSQUITTO_CTRL_CMD removeClientRole "$selected_user" "$selected_role"
            echo "Role '$selected_role' removed from user '$selected_user'."
        else
            echo "Operation cancelled."
        fi
        ;;
        *)
            echo "Invalid option"
            ;;
    esac
}


# Function to manage ACLs
manage_acls() {
    echo "1. Add ACL to Role"
    echo "2. Remove ACL from Role"
    echo "3. List ACLs for Roles"
    echo -n "Choose an option: "
    read option

    case $option in
    1)
	echo "Fetching list of roles..."
        roles=$($MOSQUITTO_CTRL_CMD listRoles)
        if [ -z "$roles" ]; then
            echo "No roles found."
            return
        fi

        echo "Select the role to add ACL to:"
            IFS=$'\n' read -rd '' -a role_array <<< "$roles"
	for i in "${!role_array[@]}"; do
        	echo "$((i+1)). ${role_array[i]}"
	done

        read -p "Enter the number of the role: " role_number
	if [[ $role_number -lt 1 || $role_number -gt ${#role_array[@]} ]]; then
            echo "Invalid selection. Operation cancelled."
            return
        fi
        selected_role=${role_array[$((role_number-1))]}

        echo "Select the ACL type:"
        declare -a acl_types=("publishClientSend" "publishClientReceive" "subscribeLiteral" "subscribePattern" "unsubscribeLiteral" "unsubscribePattern")
        for i in "${!acl_types[@]}"; do
            echo "$((i+1)). ${acl_types[i]}"
        done

	read -p "Enter the number of the ACL type: " acl_type_number
        if [[ $acl_type_number -lt 1 || $acl_type_number -gt ${#acl_types[@]} ]]; then
	    echo "Invalid selection. Operation cancelled."
            return
        fi
        selected_acl_type=${acl_types[$((acl_type_number-1))]}

        echo "Enter topic filter: "
        read topic_filter

    echo "Choose action for ACL:"
    echo "1. Allow"
    echo "2. Deny"
    read -p "Select an option (1 for Allow, 2 for Deny): " action_option
    case $action_option in
        1) action="allow" ;;
        2) action="deny" ;;
        *) echo "Invalid selection. Operation cancelled."
           return ;;
    esac

    $MOSQUITTO_CTRL_CMD addRoleACL "$selected_role" "$selected_acl_type" "$topic_filter" "$action" 5
    echo "ACL added to role '$selected_role'."
    ;;


        2)
            echo "Fetching list of roles..."
            roles=$($MOSQUITTO_CTRL_CMD listRoles)
            if [ -z "$roles" ]; then
                echo "No roles found."
                return
            fi

            echo "Select the role to remove ACL from:"
            IFS=$'\n' read -rd '' -a role_array <<< "$roles"
            for i in "${!role_array[@]}"; do
                echo "$((i+1)). ${role_array[i]}"
            done

            read -p "Enter the number of the role: " role_number
            if [[ $role_number -lt 1 || $role_number -gt ${#role_array[@]} ]]; then
                echo "Invalid selection. Operation cancelled."
                return
            fi

            selected_role=${role_array[$((role_number-1))]}

            echo "Fetching ACLs for role '$selected_role'..."
	    acls=$($MOSQUITTO_CTRL_CMD getRole "$selected_role" | grep -E '^\s{10,}|^ACLs:' | sed -e 's/^\s\{10,\}//' -e 's/^ACLs:\s*//' -e 's/\(priority: [0-9]\+\)//' -e 's/()//')

            if [ -z "$acls" ]; then
                echo "No ACLs found for this role."
                return
            fi

            echo "Select the ACL to remove:"
            IFS=$'\n' read -rd '' -a acl_array <<< "$acls"
            for i in "${!acl_array[@]}"; do
                echo "$((i+1)). ${acl_array[i]}"
            done

            read -p "Enter the number of the ACL to remove: " acl_number
            if [[ $acl_number -lt 1 || $acl_number -gt ${#acl_array[@]} ]]; then
                echo "Invalid selection. Operation cancelled."
                return
            fi

            selected_acl=${acl_array[$((acl_number-1))]}
	    acl_type=$(echo "$selected_acl" | awk -F' : ' '{print $1}' | xargs)
	    action=$(echo "$selected_acl" | awk -F' : ' '{print $2}' | xargs)
	    topic=$(echo "$selected_acl" | awk -F' : ' '{print $3}' | xargs)


            read -p "Are you sure you want to remove ACL '$acl_type $topic' from role '$selected_role'? [y/N]: " confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                $MOSQUITTO_CTRL_CMD removeRoleACL "$selected_role" "$acl_type" "$topic"
                echo "ACL '$acl_type $topic' removed from role '$selected_role'."
            else
                echo "Operation cancelled."
            fi
            ;;
        3)
            $MOSQUITTO_CTRL_CMD listRoles | while read -r role; do
                echo "Role: $role"
                $MOSQUITTO_CTRL_CMD getRole "$role"
                echo
            done
            ;;
        *)
            echo "Invalid option"
            ;;
    esac
}


# Main loop
while true; do
    show_menu
    read choice
    case $choice in
        1) manage_users ;;
        2) manage_groups ;;
        3) manage_roles ;;
        4) manage_acls ;;
        5) exit 0 ;;
        *) echo "Invalid choice, please try again." ;;
    esac
    echo
done

