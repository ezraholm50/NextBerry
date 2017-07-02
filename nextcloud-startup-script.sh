#!/bin/bash
# shellcheck disable=2034,2059
true
# shellcheck source=lib.sh
NCDB=1 && MYCNFPW=1 && FIRST_IFACE=1 && CHECK_CURRENT_REPO=1 . <(curl -sL https://raw.githubusercontent.com/techandme/NextBerry/master/lib.sh)
unset FIRST_IFACE
unset CHECK_CURRENT_REPO
unset MYCNFPW
unset NCDB

# Tech and Me © - 2017, https://www.techandme.se/

## If you want debug mode, please activate it further down in the code at line ~60

# DEBUG mode
if [ "$DEBUG" -eq 1 ]
then
    set -e
    set -x
else
    sleep 1
fi

is_root() {
    if [[ "$EUID" -ne 0 ]]
    then
        return 1
    else
        return 0
    fi
}

network_ok() {
    echo "Testing if network is OK..."
    service networking restart
    if wget -q -T 20 -t 2 http://github.com -O /dev/null
    then
        return 0
    else
        return 1
    fi
}

# Whiptail size
WT_HEIGHT=17
WT_WIDTH=$(tput cols)

if [ -z "$WT_WIDTH" ] || [ "$WT_WIDTH" -lt 60 ]; then
  WT_WIDTH=80
fi
if [ "$WT_WIDTH" -gt 178 ]; then
  WT_WIDTH=120
fi
WT_MENU_HEIGHT=$((WT_HEIGHT-7))

# Whiptail check
if [ "$(dpkg-query -W -f='${Status}' whiptail 2>/dev/null | grep -c "ok installed")" -eq 1 ]; then
      echo "Whiptail is already installed..."
      clear
else

  {
  i=1
  while read -r line; do
      i=$(( i + 1 ))
      echo $i
  done < <("$APT" update; "$APT" install whiptail -y)
} | whiptail --title "Progress" --gauge "Please wait while installing Whiptail..." 6 60 0

fi

# Check network
echo "Testing if network is OK..."
service networking restart
    curl -s http://github.com > /dev/null
if [ $? -eq 0 ]
then
    echo -e "\e[32mOnline!\e[0m"
else
echo "Setting correct interface..."
# Set correct interface
{ sed '/# The primary network interface/q' /etc/network/interfaces; printf 'auto %s\niface %s inet dhcp\n# This is an autoconfigured IPv6 interface\niface %s inet6 auto\n' "$IFACE" "$IFACE" "$IFACE"; } > /etc/network/interfaces.new
mv /etc/network/interfaces.new /etc/network/interfaces
service networking restart
fi

# Check network
echo "Testing if network is OK..."
service networking restart
    curl -s http://github.com > /dev/null
if [ $? -eq 0 ]
then
    echo -e "\e[32mOnline!\e[0m"
else
    echo
    echo "Network NOT OK. You must have a working Network connection to run this script."
    echo "Please report this issue here: https://github.com/techandme/NextBerry/issues/new"
    exit 1
fi

echo
echo "Getting scripts from GitHub to be able to run the first setup..."

# Get passman script
if [ -f "$SCRIPTS"/passman.sh ]
then
    rm "$SCRIPTS"/passman.sh
    wget -q "$APP"/passman.sh -P "$SCRIPTS"
else
    wget -q "$APP"/passman.sh -P "$SCRIPTS"
fi
if [ -f "$SCRIPTS"/passman.sh ]
then
    sleep 0.1
else
    echo "passman failed"
    echo "Script failed to download. Please run: 'sudo bash $SCRIPTS/nextcloud-startup-script.sh' again."
    exit 1
fi

# Get nextant script
if [ -f "$SCRIPTS"/nextant.sh ]
then
    rm "$SCRIPTS"/nextant.sh
    wget -q "$APP"/nextant.sh -P "$SCRIPTS"
else
    wget -q "$APP"/nextant.sh -P "$SCRIPTS"
fi
if [ -f "$SCRIPTS"/nextant.sh ]
then
    sleep 0.1
else
    echo "nextant failed"
    echo "Script failed to download. Please run: 'sudo bash $SCRIPTS/nextcloud-startup-script.sh' again."
    exit 1
fi

# Check network
if network_ok
then
    printf "${Green}Online!${Color_Off}\n"
else
    echo "Setting correct interface..."
    [ -z "$IFACE" ] && IFACE=$(lshw -c network | grep "logical name" | awk '{print $3; exit}')
    # Set correct interface
    {
        sed '/# The primary network interface/q' /etc/network/interfaces
        printf 'auto %s\niface %s inet dhcp\n# This is an autoconfigured IPv6 interface\niface %s inet6 auto\n' "$IFACE" "$IFACE" "$IFACE"
    } > /etc/network/interfaces.new
    mv /etc/network/interfaces.new /etc/network/interfaces
    service networking restart
    # shellcheck source=lib.sh
    CHECK_CURRENT_REPO=1 . <(curl -sL https://raw.githubusercontent.com/techandme/NextBerry/master/lib.sh)
    unset CHECK_CURRENT_REPO
fi

# Check network
if network_ok
then
    printf "${Green}Online!${Color_Off}\n"
else
    printf "\nNetwork NOT OK. You must have a working Network connection to run this script.\n"
    printf "Please report this issue here: $ISSUES"
    exit 1
fi

systemctl daemon-reload

echo
echo "Getting scripts from GitHub to be able to run the first setup..."
# All the shell scripts in static (.sh)
download_static_script temporary-fix
download_static_script security
download_static_script update
download_static_script trusted
download_static_script ip
download_static_script test_connection
download_static_script setup_secure_permissions_nextcloud
download_static_script change_mysql_pass
download_static_script nextberry-upgrade
download_static_script nextcloud
download_static_script update-config
download_static_script index
download_le_script activate-ssl


mv "$SCRIPTS"/index.php $HTML/index.php && rm -f $HTML/html/index.html
chmod 750 $HTML/index.php && chown www-data:www-data $HTML/index.php

# Change 000-default to $WEB_ROOT
sed -i "s|DocumentRoot /var/www/html|DocumentRoot $HTML|g" /etc/apache2/sites-available/000-default.conf

# Make $SCRIPTS excutable
chmod +x -R "$SCRIPTS"
chown root:root -R "$SCRIPTS"

# Allow $UNIXUSER to run figlet script
chown "$UNIXUSER":"$UNIXUSER" "$SCRIPTS/nextcloud.sh"

clear
echo "+--------------------------------------------------------------------+"
echo "| This script will configure your Nextcloud and activate SSL.        |"
echo "| It will also do the following:                                     |"
echo "|                                                                    |"
echo "| - Generate new SSH keys for the server                             |"
echo "| - Generate new MARIADB password                                    |"
echo "| - Configure UTF8mb4 (4-byte support for MARIADB)                   |"
echo "| - Install phpMyadmin and make it secure                            |"
echo "| - Install selected apps and automatically configure them           |"
echo "| - Detect and set hostname                                          |"
echo "| - Upgrade your system and Nextcloud to latest version              |"
echo "| - Set secure permissions to Nextcloud                              |"
echo "| - Set new passwords to Linux and Nextcloud                         |"
echo "| - Set new keyboard layout                                          |"
echo "| - Change timezone                                                  |"
echo "| - Set static IP to the system (you have to set the same IP in      |"
echo "|   your router) https://www.techandme.se/open-port-80-443/          |"
echo "|   We don't set static IP if you run this on a *remote* VPS.        |"
echo "|                                                                    |"
echo "|   The script will take about 30 minutes to finish,                 |"
echo "|   depending on your internet connection.                           |"
echo "|                                                                    |"
echo "| ####################### Tech and Me - 2017 ####################### |"
echo "+--------------------------------------------------------------------+"
any_key "Press any key to start the script..."
clear

# Set keyboard layout
echo "Current keyboard layout is $(localectl status | grep "Layout" | awk '{print $3}')"
if [[ "no" == $(ask_yes_or_no "Do you want to change keyboard layout?") ]]
then
    echo "Not changing keyboard layout..."
    sleep 1
    clear
else
    dpkg-reconfigure keyboard-configuration
clear
fi

# Pretty URLs
echo "Setting RewriteBase to \"/\" in config.php..."
chown -R www-data:www-data $NCPATH
sudo -u www-data php $NCPATH/occ config:system:set htaccess.RewriteBase --value="/"
sudo -u www-data php $NCPATH/occ maintenance:update:htaccess
bash $SECURE & spinner_loading

# Generate new SSH Keys
printf "\nGenerating new SSH keys for the server...\n"
rm -v /etc/ssh/ssh_host_*
dpkg-reconfigure openssh-server

# Generate new MARIADB password
echo "Generating new MARIADB password..."
if bash "$SCRIPTS/change_mysql_pass.sh" && wait
then
   rm "$SCRIPTS/change_mysql_pass.sh"
   {
   echo
   echo "[mysqld]"
   echo "innodb_large_prefix=on"
   echo "innodb_file_format=barracuda"
   echo "innodb_flush_neighbors=0"
   echo "innodb_adaptive_flushing=1"
   echo "innodb_flush_method = O_DIRECT"
   echo "innodb_doublewrite = 0"
   echo "innodb_file_per_table = 1"
   echo "innodb_flush_log_at_trx_commit=1"
   echo "init-connect='SET NAMES utf8mb4'"
   echo "collation_server=utf8mb4_unicode_ci"
   echo "character_set_server=utf8mb4"
   echo "skip-character-set-client-handshake"
   
   echo "[mariadb]"
   echo "innodb_use_fallocate = 1"
   echo "innodb_use_atomic_writes = 1"
   echo "innodb_use_trim = 1"
   } >> /root/.my.cnf
fi

# Enable UTF8mb4 (4-byte support)
printf "\nEnabling UTF8mb4 support on $NCCONFIGDB....\n"
echo "Please be patient, it may take a while."
sudo /etc/init.d/mysql restart & spinner_loading
RESULT="mysqlshow --user=root --password=$MARIADBMYCNFPASS $NCCONFIGDB| grep -v Wildcard | grep -o $NCCONFIGDB"
if [ "$RESULT" == "$NCCONFIGDB" ]; then
    check_command mysql -u root -e "ALTER DATABASE $NCCONFIGDB CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
    wait
fi
check_command sudo -u www-data $NCPATH/occ config:system:set mysql.utf8mb4 --type boolean --value="true"
check_command sudo -u www-data $NCPATH/occ maintenance:repair
clear

cat << LETSENC
+-----------------------------------------------+
|  The following script will install a trusted  |
|  SSL certificate through Let's Encrypt.       |
+-----------------------------------------------+
LETSENC

# Let's Encrypt
if [[ "yes" == $(ask_yes_or_no "Do you want to install SSL?") ]]
then
    bash "$SCRIPTS"/activate-ssl.sh
else
    echo
    echo "OK, but if you want to run it later, just type: sudo bash $SCRIPTS/activate-ssl.sh"
    any_key "Press any key to continue..."
fi
cd
clear

# Change Timezone
echo "Current timezone is $(cat /etc/timezone)"
echo "You must change it to your timezone"
any_key "Press any key to change timezone..."
dpkg-reconfigure tzdata
sleep 3
clear

whiptail --title "Which apps do you want to install?" --checklist --separate-output "Automatically configure and install selected apps\nSelect by pressing the spacebar" "$WT_HEIGHT" "$WT_WIDTH" 4 \
"Fail2ban" "(Extra Bruteforce protection)   " OFF \
"phpMyadmin" "(*SQL GUI)       " OFF \
"Collabora" "(Online editing 2GB RAM)   " OFF \
"OnlyOffice" "(Online editing 4GB RAM)   " OFF \
"Nextant" "(Full text search)   " OFF \
"Passman" "(Password storage)   " OFF \
"Spreed.ME" "(Video calls)      " OFF 2>results

while read -r -u 9 choice
do
    case $choice in
        Fail2ban)
            run_app_script fail2ban
            
        ;;
        phpMyadmin)
            run_app_script phpmyadmin_install_ubuntu16
        ;;
        
        OnlyOffice)
            run_app_script onlyoffice
        ;;
        
        Collabora)
            run_app_script collabora
        ;;

        Nextant)
            run_app_script nextant
        ;;

        Passman)
            run_app_script passman
        ;;

        Spreed.ME)
            run_app_script spreedme
        ;;

        *)
        ;;
    esac
done 9< results
rm -f results
clear
clear

# Add extra security
if [[ "yes" == $(ask_yes_or_no "Do you want to add extra security, based on this: http://goo.gl/gEJHi7 ?") ]]
then
    echo "security.sh:" >> "$SCRIPTS"/logs
    bash "$SCRIPTS"/security.sh
    rm "$SCRIPTS"/security.sh
else
    echo
    echo "OK, but if you want to run it later, just type: sudo bash $SCRIPTS/security.sh"
    any_key "Press any key to continue..."
fi
clear

# Change password
printf "${Color_Off}\n"
echo "For better security, change the system user password for [$UNIXUSER]"
any_key "Press any key to change password for system user..."
while true
do
    sudo passwd "$UNIXUSER" && break
done
echo
clear
NCADMIN=$(sudo -u www-data php $NCPATH/occ user:list | awk '{print $3}')
printf "${Color_Off}\n"
echo "For better security, change the Nextcloud password for [$NCADMIN]"
echo "The current password for $NCADMIN is [$NCPASS]"
any_key "Press any key to change password for Nextcloud..."
while true
do
    sudo -u www-data php "$NCPATH/occ" user:resetpassword "$NCADMIN" && break
done
clear

a2dismod status
service apache2 reload

# Increase max filesize (expects that changes are made in /etc/php/7.0/apache2/php.ini)
# Here is a guide: https://www.techandme.se/increase-max-file-size/
VALUE="# php_value upload_max_filesize 513M"
if ! grep -Fxq "$VALUE" $NCPATH/.htaccess
then
    sed -i 's/  php_value upload_max_filesize 513M/# php_value upload_max_filesize 511M/g' "$NCPATH"/.htaccess
    sed -i 's/  php_value post_max_size 513M/# php_value post_max_size 511M/g' "$NCPATH"/.htaccess
    sed -i 's/  php_value memory_limit 512M/# php_value memory_limit 512M/g' "$NCPATH"/.htaccess
fi

# Install latest updates
echo "nextberry-upgrade.sh:" >> "$SCRIPTS"/logs
bash "$SCRIPTS"/nextberry-upgrade.sh

# Add temporary fix if needed
echo "temporary-fix.sh:" >> "$SCRIPTS"/logs
bash $SCRIPTS/temporary-fix.sh
rm "$SCRIPTS"/temporary-fix.sh

# Cleanup 1
sudo -u www-data php "$NCPATH/occ" maintenance:repair
rm -f "$SCRIPTS/ip.sh"
rm -f "$SCRIPTS/test_connection.sh"
rm -f "$SCRIPTS/instruction.sh"
rm -f "$NCDATA/nextcloud.log"
rm -f "$SCRIPTS/nextcloud-startup-script.sh"
find /root "/home/$UNIXUSER" -type f \( -name '*.sh*' -o -name '*.html*' -o -name '*.tar*' -o -name '*.zip*' \) -delete
sed -i "s|instruction.sh|nextcloud.sh|g" "/home/$UNIXUSER/.profile"

truncate -s 0 \
    /root/.bash_history \
    "/home/$UNIXUSER/.bash_history" \
    /var/spool/mail/root \
    "/var/spool/mail/$UNIXUSER" \
    /var/log/apache2/access.log \
    /var/log/apache2/error.log \
    /var/log/cronjobs_success.log

sed -i "s|sudo -i||g" "/home/$UNIXUSER/.profile"
cat << RCLOCAL > "/etc/rc.local"
#!/bin/sh -e
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

exit 0

RCLOCAL
clear

ADDRESS2=$(grep "address" /etc/network/interfaces | awk '$1 == "address" { print $2 }')

# Cleanup 2
"$APT" autoremove -y
"$APT" autoclean
CLEARBOOT=$(dpkg -l linux-* | awk '/^ii/{ print $2}' | grep -v -e "$(uname -r | cut -f1,2 -d"-")" | grep -e "[0-9]" | xargs sudo apt-get -y purge)
echo "$CLEARBOOT"

ADDRESS2=$(grep "address" /etc/network/interfaces | awk '$1 == "address" { print $2 }')
# Success!
clear
printf "%s\n""${Green}"
echo    "+--------------------------------------------------------------------+"
echo    "|      Congratulations! You have successfully installed Nextcloud!   |"
echo    "|                                                                    |"
printf "|         ${Color_Off}Login to Nextcloud in your browser: ${Cyan}\"$ADDRESS2\"${Green}         |\n"
echo    "|                                                                    |"
printf "|         ${Color_Off}Publish your server online! ${Cyan}https://goo.gl/iUGE2U${Green}          |\n"
echo    "|                                                                    |"
printf "|         ${Color_Off}To login to MARIADB just type: ${Cyan}'mysql -u root'${Green}             |\n"
echo    "|                                                                    |"
printf "|   ${Color_Off}To update this VM just type: ${Cyan}'sudo bash /var/scripts/update.sh'${Green}  |\n"
echo    "|                                                                    |"
printf "|    ${IRed}#################### Tech and Me - 2017 ####################${Green}    |\n"
echo    "+--------------------------------------------------------------------+"
printf "${Color_Off}\n"
clear

# Set trusted domain in config.php
if [ -f "$SCRIPTS"/trusted.sh ]
then
    echo "trusted.sh:" >> "$SCRIPTS"/logs
    bash "$SCRIPTS"/trusted.sh
    rm -f "$SCRIPTS"/trusted.sh
fi

# Prefer IPv6
#sed -i "s|precedence ::ffff:0:0/96  100|#precedence ::ffff:0:0/96  100|g" /etc/gai.conf

# Remove MySQL pass from log files
grep "password" $MYCNF > /root/.tmp
sed -i 's|password=||g' /root/.tmp
sed -i "s|'||g" /root/.tmp
PW=$(cat /root/.tmp)
sed -i "s|$PW|XXX-SQL-PASS-XXX|g" "$SCRIPTS"/logs
rm /root/.tmp

# Log file
echo "pastebinit -i $SCRIPTS/logs -a nextberry_$DATE -b paste.ubuntu.com > $SCRIPTS/.pastebinit" > /usr/sbin/install-log
echo "clear" >> /usr/sbin/install-log
echo "exec $SCRIPTS/nextcloud.sh" >> /usr/sbin/install-log
chmod 750 /usr/sbin/install-log
chown ncadmin "$SCRIPTS/logs"
chmod 750 "$SCRIPTS/logs"

# Reboot
any_key "Installation finished, press any key to reboot system..."
rm -f "$SCRIPTS/nextcloud-startup-script.sh"
reboot
