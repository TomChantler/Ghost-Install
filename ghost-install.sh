# ghost-install.sh
# https://tomssl.com/the-best-way-to-install-ghost-on-your-server
# So far I have only tested this on a new machine.
# There are some sleep statements in here to make it nicer to run interactively. 
export NCURSES_NO_UTF8_ACS=1
function ensure_package_installed() {
    # $1 is package name, $2 Package description, $3 Start Percentage, $4 End Percentage
    # $5 Exit Code # 0 means package was already installed, 1 means this function installed it.
    local __resultvar=$5
    local myresult='0'
    if [ $(dpkg-query -W -f='${Status}' $1 2>/dev/null | grep -c -e "^install ok installed$") -eq 1 ]; then
        if [ ! -t 1 ]; then
            echo "XXX"
            echo $4
        fi
        echo "$2 ($1) is already installed"
        if [ ! -t 1 ]; then echo "XXX"; fi
    else
        if [ ! -t 1 ]; then
            echo "XXX"
            echo $3
        fi
        echo Installing $2...
        if [ ! -t 1 ]; then echo "XXX"; fi
        sudo apt-get install -y $1 &>/dev/null || exit 1
        echo $4
        local myresult=1
    fi
    eval $__resultvar="'$myresult'" # 0 = package was already installed. 1 = package installed in here.
}
#
function input_box() {
    # $1 is Title, $2 Prompt, $3 Default Value, $4 VARIABLE
    declare -n result=$4
    declare -n result_code=$4_EXITCODE
    set +e
    result=$(dialog --stdout --title "$1" --inputbox "$2" 0 0 "$3")
    result_code=$?
    set -e
}
#
if [[ $EUID -ne 0 ]]; then
    echo This script must be run as root. Try again with sudo.
    exit 1
fi
#
sudo apt-get update &>/dev/null
ensure_package_installed "dialog" "Dialog"
#
DEFAULT_GHOSTUSER=ghostuser
DEFAULT_SITEDIRECTORY=ghostblog
input_box "Set Ghost Username" \
"We need to create a user for Ghost
\n\nWe suggest $DEFAULT_GHOSTUSER, but it's up to you.
\n\nGhost Username:" \
"$DEFAULT_GHOSTUSER" \
GHOSTUSER
if [ -z "$GHOSTUSER" ]; then
    # user hit ESC/cancel
    exit
fi
input_box "Set Ghost Blog Directory" \
"Now it's time to create a directory inside /var/www/ to install \
your first Ghost blog.
\n\nI have suggested $DEFAULT_SITEDIRECTORY, but you should probably change that.
\n\nBlog Directory (inside /var/www/):" \
"$DEFAULT_SITEDIRECTORY" \
SITEDIRECTORY
if [ -z "$DEFAULT_SITEDIRECTORY" ]; then
    # user hit ESC/cancel
    exit
fi
#
(
    sleep 1
    echo "XXX"
    echo 1
    echo "Adding $GHOSTUSER user..."
    echo "XXX"
    sleep 1
    adduser --disabled-password --gecos "" $GHOSTUSER &>/dev/null &&
        echo "User $GHOSTUSER added. To set password, run 'sudo passwd $GHOSTUSER'"
    sleep 1
    echo "XXX"
    echo 3
    echo "Modifying permissions of $GHOSTUSER..."
    echo "XXX"
    sleep 1
    usermod -aG sudo $GHOSTUSER || echo "Couldn't modify user"
    echo "XXX"
    echo 5
    echo "Permissions modified"
    echo "XXX"
    sleep 1
    ensure_package_installed "nginx" "Nginx" "10" "15" result
    ensure_package_installed "ufw" "ufw [Firewall]" "16" "20" result
    echo "XXX": echo 21
    echo "Configuring ufw..."
    echo "XXX"
    sudo ufw default deny incoming >/dev/null &&
        sudo ufw default allow outgoing >/dev/null &&
        sudo ufw allow ssh >/dev/null &&
        sudo ufw allow 'Nginx Full' >/dev/null
    yes | sudo ufw enable >/dev/null || exit 1
    echo "XXX"
    echo 30
    echo "XXX"
    ensure_package_installed "mysql-server" "MySQL" "31" "40" result
    if [ $result -eq 1 ]; then
        # We just installed mysql-server, so we should set the root password
		sleep 1;
        data="something"
        until [ "$data" = "$data2" ]; do
            data=$(dialog --title "Set MySQL root password" --insecure --passwordbox "Please enter a password for the mysql root user. You will need this password when you install each of your Ghost blogs." 10 60 3>&1- 1>&2- 2>&3-)
            data2=$(dialog --title "Set MySQL root password" --insecure --passwordbox "Please re-enter your password." 10 60 3>&1- 1>&2- 2>&3-)
        done
        sql="ALTER USER 'root'@'localhost' IDENTIFIED BY '$data';FLUSH PRIVILEGES;"
        mysql -u root -e "$sql" >/home/ghostuser/sqlfrominsidescript.txt
        echo "XXX"
        echo 50
        echo "MySQL installed and root password set"
        echo "XXX"
		clear
    fi
    #
    echo "XXX"
    echo 51
    echo "Installing Node.js v10.x source repo"
    echo "XXX"
    curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash &>/dev/null
    ensure_package_installed "nodejs" "Node.js" "65" "75" result
    echo "XXX";
    echo "Ensuring latest Ghost-CLI installed..."
    echo "XXX"
    sudo npm install ghost-cli@latest -g --quiet --no-progress &>/dev/null
    echo "XXX"
    echo 95
    echo "Going to create directory /var/www/$SITEDIRECTORY and sort out permissions"
    echo "XXX"
    sudo mkdir -p /var/www/$SITEDIRECTORY
    sudo chown $GHOSTUSER:$GHOSTUSER /var/www/$SITEDIRECTORY
    sudo chmod 775 /var/www/$SITEDIRECTORY
    echo "XXX"
    echo 100
    echo "Now you just need to run:\nsu - $GHOSTUSER\ncd /var/www/$SITEDIRECTORY\nghost install --v1 # if upgrading from Ghost 0.x\nghost install # for installing/upgrading > v1.x"
    echo "XXX"
) | dialog --title "Installing Ghost..." --gauge "Installing required packages..." 10 60 0
cd /var/www/$SITEDIRECTORY
su $GHOSTUSER
#End