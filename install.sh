#!/usr/bin/env bash

# Increase this version number whenever you update the installer
INSTALLER_VERSION="2025-02-02" # format YYYY-MM-DD

# Test if this script is being run as root or not
if [[ $EUID -eq 0 ]]; then
    IS_ROOT=true
    SUDOX=""
else
    IS_ROOT=false
    SUDOX="sudo "
fi
ROOT_GROUP="root"
USER_GROUP="$USER"

RECOMMEND_FIXER_AFTER_INSTALL="false"
# use --automated-run to skip all user prompts
if [[ "$*" != *--silent* ]] || [[ $(ps -p 1 -o comm=) == "systemd" ]]; then
    if [[ "$(whoami)" = "root" || "$(whoami)" = "iobroker" ]]; then
        # Prompt for username
        echo "You started the installer as root or the iobroker user. This is not recommended."
        echo "For security reasons a default user should be created. Please run 'iob fix' after the installation."
        RECOMMEND_FIXER_AFTER_INSTALL="true"
    fi

    # Check and fix boot.target on systemd

    if [[ $(systemctl get-default) == "graphical.target" ]]; then
        echo -e "\nYour system is booting into 'graphical.target', which means that a user interface or desktop is available. Usually a server is running without a desktop for security reasons and to save RAM. Please run 'iob fix' after the installation to change this."
        RECOMMEND_FIXER_AFTER_INSTALL="true"
    fi

    # Check and fix timezone
    TIMEZONE=$(timedatectl show --property=Timezone --value)
    if [[ $(command -v apt-get) ]] && [[ $$TIMEZONE == *Etc/UTC* ]] || [[ $TIMEZONE == *Europe/London* ]]; then
        echo -e "\nYour timezone '$TIMEZONE' is probably wrong. Please run 'iob fix' after the installation to change this."
        RECOMMEND_FIXER_AFTER_INSTALL="true"
    fi
fi

# ------------------------------
# Increase this version number whenever you update the lib
# ------------------------------
LIBRARY_VERSION="2024-10-22" # format YYYY-MM-DD

# ------------------------------
# Supported and suggested node versions
# ------------------------------
NODE_MAJOR=20
NODE_JS_BREW_URL="https://nodejs.org/dist/v20.13.1/node-v20.13.1.pkg"

# ------------------------------
# test function of the library
# ------------------------------
function get_lib_version() { echo "$LIBRARY_VERSION"; }

# ------------------------------
# functions for ioBroker Installer/Fixer
# ------------------------------

enable_colored_output() {
    # Enable colored output
    if test -t 1; then                                  # if terminal
        ncolors=$(which tput >/dev/null && tput colors) # supports color
        if test -n "$ncolors" && test $ncolors -ge 8; then
            termcols=$(tput cols)
            bold="$(tput bold)"
            underline="$(tput smul)"
            standout="$(tput smso)"
            normal="$(tput sgr0)"
            black="$(tput setaf 0)"
            red="$(tput setaf 1)"
            green="$(tput setaf 2)"
            yellow="$(tput setaf 3)"
            blue="$(tput setaf 4)"
            magenta="$(tput setaf 5)"
            cyan="$(tput setaf 6)"
            white="$(tput setaf 7)"
        fi
    fi
}

print_step() {
    stepname="$1"
    stepnr="$2"
    steptotal="$3"

    echo
    echo "${bold}${HLINE}${normal}"
    echo "${bold}    ${stepname} ${blue}(${stepnr}/${steptotal})${normal}"
    echo "${bold}${HLINE}${normal}"
    echo
}

print_bold() {
    title="$1"
    echo
    echo "${bold}${HLINE}${normal}"
    echo
    echo "    ${bold}${title}${normal}"
    for text in "${@:2}"; do
        echo "    ${text}"
    done
    echo
    echo "${bold}${HLINE}${normal}"
    echo
}

print_msg() {
    text="$1"
    echo
    echo -e "${text}"
    echo
}

HLINE="=========================================================================="
enable_colored_output

get_platform_params() {
    # Test which platform this script is being run on
    # When adding another supported platform, also add detection for the install command
    # HOST_PLATFORM:    Name of the platform
    # INSTALL_CMD:      Command for package installation
    # INSTALL_CMD_ARGS: Arguments for $INSTALL_CMD to install something
    # INSTALL_CMD_UPD_ARGS: Arguments for $INSTALL_CMD to update something
    # IOB_DIR:          Directory where iobroker should be installed
    # IOB_USER:          The user to run ioBroker as

    INSTALL_CMD_UPD_ARGS=""

    unamestr=$(uname)
    case "$unamestr" in
    "Linux")
        HOST_PLATFORM="linux"
        INSTALL_CMD="apt-get"
        INSTALL_CMD_ARGS="install -yq"
        if [[ $(which "yum" 2>/dev/null) == *"/yum" ]]; then
            INSTALL_CMD="yum"
            # The args -y and -q have to be separate
            INSTALL_CMD_ARGS="install -q -y"
            INSTALL_CMD_UPD_ARGS="-y"
        fi
        IOB_DIR="/opt/iobroker"
        IOB_USER="iobroker"
        ;;
    "Darwin")
        # OSX and Linux are the same in terms of install procedure
        HOST_PLATFORM="osx"
        ROOT_GROUP="wheel"
        INSTALL_CMD="brew"
        INSTALL_CMD_ARGS="install"
        IOB_DIR="/usr/local/iobroker"
        IOB_USER="$USER"
        ;;
    "FreeBSD")
        HOST_PLATFORM="freebsd"
        ROOT_GROUP="wheel"
        INSTALL_CMD="pkg"
        INSTALL_CMD_ARGS="install -yq"
        IOB_DIR="/opt/iobroker"
        IOB_USER="iobroker"
        ;;
    *)
        # The following should never happen, but better be safe than sorry
        echo "Unsupported platform $unamestr"
        exit 1
        ;;
    esac
    if [ "$IS_ROOT" = true ]; then
        USER_GROUP="$ROOT_GROUP"
    fi
}

function set_some_common_params() {
    CONTROLLER_DIR="$IOB_DIR/node_modules/iobroker.js-controller"
    INSTALLER_INFO_FILE="$IOB_DIR/INSTALLER_INFO.txt"

    # Where the fixer script is located
    FIXER_URL="https://iobroker.net/fix.sh"

    # Where the diag script is located
    DIAG_URL="https://iobroker.net/diag.sh"

    # Where the nodejs Update script is located
    NODE_UPDATER_URL="https://iobroker.net/node-update.sh"

    # Remember the full path of bash
    BASH_CMDLINE=$(which bash)

    # Check if "sudo" command is available (in case we're not root)
    if [ "$IS_ROOT" != true ]; then
        if [[ $(which "sudo" 2>/dev/null) != *"/sudo" ]]; then
            echo "${red}Cannot continue because the \"sudo\" command is not available!${normal}"
            echo "Please install it first using \"$INSTALL_CMD install sudo\""
            exit 1
        fi
    fi

    # Starting with Debian 10 (Buster), we need to add the [/usr[/local]]/sbin
    # directories to PATH for non-root users
    if [ -d "/sbin" ]; then add_to_path "/sbin"; fi
    if [ -d "/usr/sbin" ]; then add_to_path "/usr/sbin"; fi
    if [ -d "/usr/local/sbin" ]; then add_to_path "/usr/local/sbin"; fi
}

install_package_linux() {
    package="$1"
    # Test if the package is installed
    dpkg -s "$package" &>/dev/null
    if [ $? -ne 0 ]; then
        if [ "$INSTALL_CMD" = "yum" ]; then
            # Install it
            errormessage=$($SUDOX $INSTALL_CMD $INSTALL_CMD_ARGS $package >/dev/null 2>&1)
        else
            # Install it
            errormessage=$($SUDOX $INSTALL_CMD update -qq && $SUDOX $INSTALL_CMD $INSTALL_CMD_ARGS --no-install-recommends -yqq $package)
        fi

        # Hide "Error: Nothing to do"
        if [ "$errormessage" != "Error: Nothing to do" ]; then
            if [ "$errormessage" != "" ]; then
                echo $errormessage
            fi
            echo "Installed $package"
        fi
    fi
}

install_package_freebsd() {
    package="$1"
    # check if package is installed (pkg is nice enough to provide us with a exitcode)
    if ! $INSTALL_CMD info "$1" >/dev/null 2>&1; then
        # Install it
        $SUDOX $INSTALL_CMD $INSTALL_CMD_ARGS "$1" >/dev/null
        echo "Installed $package"
    fi
}

install_package_macos() {
    package="$1"
    # Test if the package is installed (Use brew to install essential tools)
    $INSTALL_CMD list | grep "$package" &>/dev/null
    if [ $? -ne 0 ]; then
        # Install it
        $INSTALL_CMD $INSTALL_CMD_ARGS $package &>/dev/null
        if [ $? -eq 0 ]; then
            echo "Installed $package"
        else
            echo "$package was not installed"
        fi
    fi
}

install_package() {
    case "$HOST_PLATFORM" in
    "linux")
        install_package_linux $1
        ;;
    "osx")
        install_package_macos $1
        ;;
    "freebsd")
        install_package_freebsd $1
        ;;
    # The following should never happen, but better be safe than sorry
    *)
        echo "Unsupported platform $HOST_PLATFORM"
        ;;
    esac
}

install_necessary_packages() {
    # Determine the platform we operate on and select the installation routine/packages accordingly
    # TODO: Which other packages do we need by default?
    case "$HOST_PLATFORM" in
    "linux")
        declare -a packages=(
            "acl"         # To use setfacl
            "sudo"        # To use sudo (obviously)
            "libcap2-bin" # To give nodejs access to protected ports
            # These are used by a couple of adapters and should therefore exist:
            "build-essential"
            "gcc"
            "make"
            "libavahi-compat-libdnssd-dev"
            "libudev-dev"
            "libpam0g-dev"
            "pkg-config"
            "git"
            "curl"
            "unzip"
            "distro-info"
            # These are required for canvas
            "libcairo2-dev"
            "libpango1.0-dev"
            "libjpeg-dev"
            "libgif-dev"
            "librsvg2-dev"
            "libpixman-1-dev"
            "net-tools" # To fix issue #277
            "cmake"     # https://github.com/ioBroker/ioBroker.js-controller/issues/1604
            "polkitd"   # some LXC miss it
            "passwd"    # some LXC miss it
        )
        for pkg in "${packages[@]}"; do
            install_package $pkg
        done

        # ==================
        # Configure packages

        # Give nodejs access to protected ports and raw devices like ble
        cmdline="$SUDOX setcap"

        if running_in_docker; then
            capabilities=$(grep ^CapBnd /proc/$$/status)
            if [[ $(capsh --decode=${capabilities:(-16)}) == *"cap_net_admin"* ]]; then
                $cmdline 'cap_net_admin,cap_net_bind_service,cap_net_raw+eip' "$(eval readlink -f $(command -v node))"
            else
                $cmdline 'cap_net_bind_service,cap_net_raw+eip' "$(eval readlink -f $(command -v node))"
                echo "${yellow}Docker detected!"
                echo "If you have any adapters that need the CAP_NET_ADMIN capability,"
                echo "you need to start the docker container with the option --cap-add=NET_ADMIN"
                echo "and manually add that capability to node${normal}"
            fi
        else
            $cmdline 'cap_net_admin,cap_net_bind_service,cap_net_raw+eip' "$(eval readlink -f $(command -v node))"
        fi
        ;;
    "freebsd")
        declare -a packages=(
            "sudo"
            "git"
            "curl"
            "bash"
            "unzip"
            "avahi-libdns" # avahi gets installed along with this
            "dbus"
            "nss_mdns" # needed for the mdns host resolution
            "gcc"
            "python" # Required for node-gyp compilation
        )
        for pkg in "${packages[@]}"; do
            install_package $pkg
        done
        # we need to do some setting up things after installing the packages
        # ensure dns_sd.h is where node-gyp expect it
        ln -s /usr/local/include/avahi-compat-libdns_sd/dns_sd.h /usr/include/dns_sd.h
        # enable dbus in the avahi configuration
        sed -i -e 's/#enable-dbus/enable-dbus/' /usr/local/etc/avahi/avahi-daemon.conf
        # enable mdns usage for host resolution
        sed -i -e 's/hosts: file dns/hosts: file dns mdns/' /etc/nsswitch.conf

        # enable services avahi/dbus
        sysrc -f /etc/rc.conf dbus_enable="YES"
        sysrc -f /etc/rc.conf avahi_daemon_enable="YES"

        # start services
        service dbus start
        service avahi-daemon start
        ;;
    "osx")
        # Test if brew is installed. If it is, install some packages that are often used.
        $INSTALL_CMD -v &>/dev/null
        if [ $? -eq 0 ]; then
            declare -a packages=(
                # These are used by a couple of adapters and should therefore exist:
                "pkg-config"
                "git"
                "curl"
                "unzip"
            )
            for pkg in "${packages[@]}"; do
                install_package $pkg
            done
        else
            echo "${yellow}Since brew is not installed, frequently-used dependencies could not be installed."
            echo "Before installing some adapters, you might have to install some packages yourself."
            echo "Please check the adapter manuals before installing them.${normal}"
        fi
        ;;
    *) ;;

    esac
}

disable_npm_audit() {
    # Make sure the npmrc file exists
    $SUDOX touch .npmrc
    # If .npmrc does not contain "audit=false", we need to change it
    $SUDOX grep -q -E "^audit=false" .npmrc &>/dev/null
    if [ $? -ne 0 ]; then
        # Remember its contents (minus any possible audit=true)
        NPMRC_FILE=$($SUDOX grep -v -E "^audit=true" .npmrc)
        # And write it back
        write_to_file "$NPMRC_FILE" .npmrc
        # Append the line to disable audit
        append_to_file "# disable npm audit warnings" .npmrc
        append_to_file "audit=false" .npmrc
    fi
    # Make sure that npm can access the .npmrc
    if [ "$HOST_PLATFORM" = "osx" ]; then
        $SUDOX chown -R $USER .npmrc
    else
        $SUDOX chown -R $USER:$USER_GROUP .npmrc
    fi
}

disable_npm_updatenotifier() {
    # Make sure the npmrc file exists
    $SUDOX touch .npmrc
    # If .npmrc does not contain "update-notifier=false", we need to change it
    $SUDOX grep -q -E "^update-notifier=false" .npmrc &>/dev/null
    if [ $? -ne 0 ]; then
        # Remember its contents (minus any possible update-notifier=true)
        NPMRC_FILE=$($SUDOX grep -v -E "^update-notifier=true" .npmrc)
        # And write it back
        write_to_file "$NPMRC_FILE" .npmrc
        # Append the line to disable update-notifier
        append_to_file "# disable npm update-notifier information" .npmrc
        append_to_file "update-notifier=false" .npmrc
    fi
    # Make sure that npm can access the .npmrc
    if [ "$HOST_PLATFORM" = "osx" ]; then
        $SUDOX chown -R $USER .npmrc
    else
        $SUDOX chown -R $USER:$USER_GROUP .npmrc
    fi
}

# This is obsolete and can maybe removed
set_npm_python() {
    # Make sure the npmrc file exists
    $SUDOX touch .npmrc
    # If .npmrc does not contain "python=", we need to change it
    $SUDOX grep -q -E "^python=" .npmrc &>/dev/null
    if [ $? -ne 0 ]; then
        # Remember its contents
        NPMRC_FILE=$($SUDOX grep -v -E "^python=" .npmrc)
        # And write it back
        write_to_file "$NPMRC_FILE" .npmrc
        # Append the line to change the python binary
        append_to_file "# change link from python3 to python2.7 (needed for gyp)" .npmrc
        append_to_file "python=/usr/local/bin/python2.7" .npmrc
    fi
    # Make sure that npm can access the .npmrc
    if [ "$HOST_PLATFORM" = "osx" ]; then
        $SUDOX chown -R $USER .npmrc
    else
        $SUDOX chown -R $USER:$USER_GROUP .npmrc
    fi
}

force_strict_npm_version_checks() {
    # Make sure the npmrc file exists
    $SUDOX touch .npmrc
    # If .npmrc does not contain "engine-strict=true", we need to change it
    $SUDOX grep -q -E "^engine-strict=true" .npmrc &>/dev/null
    if [ $? -ne 0 ]; then
        # Remember its contents (minus any possible engine-strict=false)
        NPMRC_FILE=$($SUDOX grep -v -E "^engine-strict=false" .npmrc)
        # And write it back
        write_to_file "$NPMRC_FILE" .npmrc
        # Append the line to force strict version checks
        append_to_file "# force strict version checks" .npmrc
        append_to_file "engine-strict=true" .npmrc
    fi
    # Make sure that npm can access the .npmrc
    if [ "$HOST_PLATFORM" = "osx" ]; then
        $SUDOX chown -R $USER .npmrc
    else
        $SUDOX chown -R $USER:$USER_GROUP .npmrc
    fi
}

# Adds dirs to the PATH variable without duplicating entries
add_to_path() {
    case ":$PATH:" in
    *":$1:"*) : ;; # already there
    *) PATH="$1:$PATH" ;;
    esac
}

function write_to_file() {
    echo "$1" | $SUDOX tee "$2" &>/dev/null
}
function append_to_file() {
    echo "$1" | $SUDOX tee -a "$2" &>/dev/null
}

running_in_docker() {
    # Test if we're running inside a docker container or as github actions job while building docker container image
    if awk -F/ '$2 == "docker"' /proc/self/cgroup | read || awk -F/ '$2 == "buildkit"' /proc/self/cgroup | read || test -f /.dockerenv || test -f /opt/scripts/.docker_config/.thisisdocker; then
        return 0
    else
        return 1
    fi
}

change_npm_command_user() {
    # patches the npm command for the current user (if iobroker was installed as non-root),
    # so that it is executed as `iobroker` when inside the iobroker directory
    NPM_COMMAND_FIX_PATH=~/.iobroker/npm_command_fix
    NPM_COMMAND_FIX=$(
        cat <<-EOF
		# While inside the iobroker directory, execute npm as iobroker
		function npm() {
			__real_npm=\$(which npm)
			if [[ \$(pwd) == "$IOB_DIR"* ]]; then
				sudo -H -u $IOB_USER \$__real_npm \$*
			else
				eval \$__real_npm \$*
			fi
		}
		EOF
    )
    BASHRC_LINES=$(
        cat <<-EOF

		# Forces npm to run as $IOB_USER when inside the iobroker installation dir
		source ~/.iobroker/npm_command_fix
		EOF
    )

    mkdir -p ~/.iobroker
    write_to_file "$NPM_COMMAND_FIX" "$NPM_COMMAND_FIX_PATH"
    # Activate the change
    source "$NPM_COMMAND_FIX_PATH"

    # Make sure the bashrc file exists - it should, but you never know...
    touch ~/.bashrc
    # If .bashrc does not contain the source command, we need to add it
    sudo grep -q -E "^source ~/\.iobroker/npm_command_fix" ~/.bashrc &>/dev/null
    if [ $? -ne 0 ]; then
        echo "$BASHRC_LINES" >>~/.bashrc
    fi
}

change_npm_command_root() {
    # patches the npm command for the ROOT user (always! (independent of which user installed iobroker)),
    # so that it is executed as `iobroker` when inside the iobroker directory
    NPM_COMMAND_FIX_PATH=/root/.iobroker/npm_command_fix
    NPM_COMMAND_FIX=$(
        cat <<-EOF
		# While inside the iobroker directory, execute npm as iobroker
		function npm() {
			__real_npm=\$(which npm)
			if [[ \$(pwd) == "$IOB_DIR"* ]]; then
				sudo -H -u $IOB_USER \$__real_npm \$*
			else
				eval \$__real_npm \$*
			fi
		}
		EOF
    )
    BASHRC_LINES=$(
        cat <<-EOF

		# Forces npm to run as $IOB_USER when inside the iobroker installation dir
		source /root/.iobroker/npm_command_fix
		EOF
    )

    sudo mkdir -p /root/.iobroker
    write_to_file "$NPM_COMMAND_FIX" "$NPM_COMMAND_FIX_PATH"
    # Activate the change
    if [ "$IS_ROOT" = "true" ]; then
        source "$NPM_COMMAND_FIX_PATH"
    fi

    # Make sure the bashrc file exists - it should, but you never know...
    sudo touch /root/.bashrc
    # If .bashrc does not contain the source command, we need to add it
    sudo grep -q -E "^source /root/\.iobroker/npm_command_fix" /root/.bashrc &>/dev/null
    if [ $? -ne 0 ]; then
        append_to_file "$BASHRC_LINES" /root/.bashrc
    fi
}

enable_cli_completions() {
    # Performs the necessary configuration for CLI auto completion
    COMPLETIONS_PATH=~/.iobroker/iobroker_completions
    COMPLETIONS=$(
        cat <<-'EOF'
		iobroker_yargs_completions()
		{
			local cur_word args type_list

			cur_word="${COMP_WORDS[COMP_CWORD]}"
			args=("${COMP_WORDS[@]}")

			# ask yargs to generate completions.
			type_list=$(iobroker --get-yargs-completions "${args[@]}")

			COMPREPLY=( $(compgen -W "${type_list}" -- ${cur_word}) )

			# if no match was found, fall back to filename completion
			if [ ${#COMPREPLY[@]} -eq 0 ]; then
			COMPREPLY=()
			fi

			return 0
		}
		complete -o default -F iobroker_yargs_completions iobroker
		complete -o default -F iobroker_yargs_completions iob
		EOF
    )
    BASHRC_LINES=$(
        cat <<-EOF

		# Enable ioBroker command auto-completion
		source ~/.iobroker/iobroker_completions
		EOF
    )

    mkdir -p ~/.iobroker
    write_to_file "$COMPLETIONS" "$COMPLETIONS_PATH"
    # Activate the change
    source "$COMPLETIONS_PATH"

    # Make sure the bashrc file exists - it should, but you never know...
    touch ~/.bashrc
    # If .bashrc does not contain the source command, we need to add it
    sudo grep -q -E "^source ~/\.iobroker/iobroker_completions" ~/.bashrc &>/dev/null
    if [ $? -ne 0 ]; then
        echo "$BASHRC_LINES" >>~/.bashrc
    fi
}

set_root_permissions() {
    file="$1"
    $SUDOX chown root:$ROOT_GROUP $file
    $SUDOX chmod 755 $file
}

make_executable() {
    file="$1"
    $SUDOX chmod 755 $file
}

change_owner() {
    user="$1"
    file="$2"
    if [ "$HOST_PLATFORM" == "osx" ]; then
        owner="$user"
    else
        owner="$user:$user"
    fi
    cmdline="$SUDOX chown"
    if [ -d $file ]; then
        # recursively chown directories
        cmdline="$cmdline -R"
    elif [ -L $file ]; then
        # change ownership of symbolic links
        cmdline="$cmdline -h"
    fi
    $cmdline $owner $file
}

function add2sudoers() {
    local xsudoers=$1
    shift
    xarry=("$@")
    for cmd in "${xarry[@]}"; do
        # Test each command if and where it is installed
        cmd_bin=$(echo $cmd | cut -d ' ' -f1)
        cmd_path=$(which $cmd_bin 2>/dev/null)
        if [ $? -eq 0 ]; then
            # Then add the command to SUDOERS_CONTENT
            full_cmd=$(echo "$cmd" | sed -e "s|$cmd_bin|$cmd_path|")
            SUDOERS_CONTENT+=$xsudoers"NOPASSWD: $full_cmd\n"
        fi
    done
}

create_user_linux() {
    username="$1"
    id "$username" &>/dev/null
    if [ $? -ne 0 ]; then
        # User does not exist
        $SUDOX useradd -m -s /usr/sbin/nologin "$username"
        echo "User $username created"
    fi
    # Add the current non-root user to the iobroker group so he can access the iobroker dir
    if [ "$username" != "$USER" ] && [ "$IS_ROOT" = false ]; then
        sudo usermod -a -G $username $USER
    fi

    SUDOERS_CONTENT="$username ALL=(ALL) ALL\n"
    # Add the user to all groups we need and give him passwordless sudo privileges
    # Define which commands iobroker may execute as sudo without password
    declare -a iob_commands=(
        "shutdown" "halt" "poweroff" "reboot"
        "systemctl start" "systemctl stop"
        "mount" "umount" "systemd-run"
        "apt-get" "apt" "dpkg" "make"
        "ping" "fping"
        "arp-scan"
        "setcap"
        "nmcli"
        "vcgencmd"
        "cat"
        "df"
        "mysqldump"
        "ldconfig"
    )
    add2sudoers "$username ALL=(ALL) " "${iob_commands[@]}"

    # Additionally, define which iobroker-related commands may be executed by every user
    declare -a all_user_commands=(
        "systemctl start iobroker"
        "systemctl stop iobroker"
        "systemctl restart iobroker"
    )
    add2sudoers "ALL ALL=" "${all_user_commands[@]}"

    # Furthermore, allow all users to execute node iobroker.js as iobroker
    if [ "$IOB_USER" != "$USER" ]; then
        add2sudoers "ALL ALL=($IOB_USER) " "node $CONTROLLER_DIR/iobroker.js *"
    fi

    SUDOERS_FILE="/etc/sudoers.d/iobroker"
    $SUDOX rm -f $SUDOERS_FILE
    echo -e "$SUDOERS_CONTENT" >~/temp_sudo_file
    $SUDOX visudo -c -q -f ~/temp_sudo_file &&
        $SUDOX chown root:$ROOT_GROUP ~/temp_sudo_file &&
        $SUDOX chmod 440 ~/temp_sudo_file &&
        $SUDOX mv ~/temp_sudo_file $SUDOERS_FILE &&
        echo "Created $SUDOERS_FILE"
    # Add the user to all groups if they exist
    declare -a groups=(
        audio
        bluetooth
        dialout
        gpio
        i2c
        plugdev
        redis
        tty
        video
    )
    for grp in "${groups[@]}"; do
        getent group $grp &>/dev/null && $SUDOX usermod -a -G $grp $username
    done
}

create_user_freebsd() {
    username="$1"
    id "$username" &>/dev/null
    if [ $? -ne 0 ]; then
        # User does not exist
        $SUDOX pw useradd -m -s /usr/sbin/nologin -n "$username"
    fi
    # Add the user to all groups we need and give him passwordless sudo privileges
    # Define which commands may be executed as sudo without password
    SUDOERS_CONTENT="$username ALL=(ALL) ALL\n"
    # Add the user to all groups we need and give him passwordless sudo privileges
    # Define which commands iobroker may execute as sudo without password
    declare -a iob_commands=(
        "shutdown" "halt" "poweroff" "reboot"
        "service iobroker start" "service iobroker stop"
        "mount" "umount" "systemd-run"
        "pkg" "make"
        "ping" "fping"
        "arp-scan"
        "setcap"
        "nmcli"
        "vcgencmd"
        "cat"
        "df"
        "mysqldump"
        "ldconfig"
    )
    add2sudoers "$username ALL=(ALL) " "${iob_commands[@]}"

    # Additionally, define which iobroker-related commands may be executed by every user
    declare -a all_user_commands=(
        "service iobroker start"
        "service iobroker stop"
        "service iobroker restart"
    )
    add2sudoers "ALL ALL=" "${all_user_commands[@]}"

    # Furthermore, allow all users to execute node iobroker.js as iobroker
    if [ "$IOB_USER" != "$USER" ]; then
        add2sudoers "ALL ALL=($IOB_USER) " "node $CONTROLLER_DIR/iobroker.js *"
    fi

    SUDOERS_FILE="/usr/local/etc/sudoers.d/iobroker"
    $SUDOX rm -f $SUDOERS_FILE
    echo -e "$SUDOERS_CONTENT" >~/temp_sudo_file
    $SUDOX visudo -c -q -f ~/temp_sudo_file &&
        $SUDOX chown root:$ROOT_GROUP ~/temp_sudo_file &&
        $SUDOX chmod 440 ~/temp_sudo_file &&
        $SUDOX mv ~/temp_sudo_file $SUDOERS_FILE &&
        echo "Created $SUDOERS_FILE"

    # Add the user to all groups if they exist
    declare -a groups=(
        audio
        bluetooth
        dialout
        gpio
        i2c
        plugdev
        redis
        tty
        video
    )
    for grp in "${groups[@]}"; do
        getent group $grp && $SUDOX pw group mod $grp -m $username
    done
}

fix_dir_permissions() {
    # Give the user access to all necessary directories
    # When autostart is enabled, we need to fix the permissions so that `iobroker` can access it
    echo "Fixing directory permissions..."

    change_owner $IOB_USER $IOB_DIR
    # These commands are only for the fixer
    if [ "$FIXER_VERSION" != "" ]; then
        # ioBroker install dir
        change_owner $IOB_USER $IOB_DIR
        # and the npm cache dir
        if [ -d "/home/$IOB_USER/.npm" ]; then
            change_owner $IOB_USER "/home/$IOB_USER/.npm"
        fi
    fi

    if [ "$IS_ROOT" != true ]; then
        sudo usermod -a -G $IOB_USER $USER
    fi
    # Give the iobroker group write access to all files by setting the default ACL
    $SUDOX setfacl -Rdm g:$IOB_USER:rwx $IOB_DIR &>/dev/null && $SUDOX setfacl -Rm g:$IOB_USER:rwx $IOB_DIR &>/dev/null
    if [ $? -ne 0 ]; then
        # We cannot rely on default permissions on this system
        echo "${yellow}This system does not support setting default permissions.${normal}"
        echo "${yellow}Do not use npm to manually install adapters unless you know what you are doing!${normal}"
        echo "ACL enabled: false" >>$INSTALLER_INFO_FILE
    else
        echo "ACL enabled: true" >>$INSTALLER_INFO_FILE
    fi
}

install_nodejs() {
    print_bold "Node.js not found. Installing..."

    if [ "$INSTALL_CMD" = "yum" ]; then
        $SUDOX rm -f /etc/yum.repos.d/nodesource*.repo
        SYS_ARCH=$(uname -m)
        NODEJS_REPO_CONTENT="[nodesource-nodejs]
name=Node.js Packages for Linux RPM based distros - $SYS_ARCH
baseurl=https://rpm.nodesource.com/pub_${NODE_MAJOR}.x/nodistro/nodejs/$SYS_ARCH
priority=9
enabled=1
gpgcheck=1
gpgkey=https://rpm.nodesource.com/gpgkey/ns-operations-public.key
module_hotfixes=1"

        if [ "$IS_ROOT" = true ]; then
            echo "$NODEJS_REPO_CONTENT" | tee /etc/yum.repos.d/nodesource-nodejs.repo >/dev/null
            $INSTALL_CMD makecache --disablerepo="*" --enablerepo="nodesource-nodejs"
            $INSTALL_CMD $INSTALL_CMD_ARGS nodejs
        else
            echo "$NODEJS_REPO_CONTENT" | $SUDOX tee /etc/yum.repos.d/nodesource-nodejs.repo >/dev/null
            $SUDOX $INSTALL_CMD makecache --disablerepo="*" --enablerepo="nodesource-nodejs"
            $SUDOX $INSTALL_CMD $INSTALL_CMD_ARGS nodejs
        fi
    elif [ "$INSTALL_CMD" = "pkg" ]; then
        $SUDOX $INSTALL_CMD $INSTALL_CMD_ARGS node
    elif [ "$INSTALL_CMD" = "brew" ]; then
        echo "${red}Cannot install Node.js using brew.${normal}"
        echo "Please download Node.js from $NODE_JS_BREW_URL"
        echo "Then try to install ioBroker again!"
        exit 1
    else
        if [ "$IS_ROOT" = true ]; then
            $INSTALL_CMD update 2>&1 >/dev/null
            $INSTALL_CMD $INSTALL_CMD_ARGS ca-certificates curl gnupg 2>&1 >/dev/null
            mkdir -p /etc/apt/keyrings
            rm /etc/apt/keyrings/nodesource.gpg 2>&1 >/dev/null
            curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
            echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list
            echo -e "Package: nodejs\nPin: origin deb.nodesource.com\nPin-Priority: 1001" | $SUDOX tee /etc/apt/preferences.d/nodejs.pref
        else
            $SUDOX $INSTALL_CMD update 2>&1 >/dev/null
            $SUDOX $INSTALL_CMD $INSTALL_CMD_ARGS ca-certificates curl gnupg 2>&1 >/dev/null
            $SUDOX mkdir -p /etc/apt/keyrings
            $SUDOX rm /etc/apt/keyrings/nodesource.gpg 2>&1 >/dev/null
            curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | $SUDOX gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
            echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | $SUDOX tee /etc/apt/sources.list.d/nodesource.list
            echo -e "Package: nodejs\nPin: origin deb.nodesource.com\nPin-Priority: 1001" | $SUDOX tee /etc/apt/preferences.d/nodejs.pref
        fi
    fi
    install_package nodejs

    # Check if nodejs is now installed
    if [[ $(which "node" 2>/dev/null) != *"/node" ]]; then
        echo "${red}Cannot install Node.js! Please install it manually.${normal}"
        exit 1
    else
        echo "${bold}Node.js Installed successfully!${normal}"
    fi
}

detect_ip_address() {
    # Detect IP address
    local IP
    IP_COMMAND=$(type "ip" &>/dev/null && echo "ip addr show" || echo "ifconfig")
    if [ "$HOST_PLATFORM" = "osx" ]; then
        IP=$($IP_COMMAND | grep inet | grep -v inet6 | grep -v 127.0.0.1 | grep -Eo "([0-9]+\.){3}[0-9]+" | head -1)
    else
        IP=$($IP_COMMAND | grep inet | grep -v inet6 | grep -v 127.0.0.1 | grep -Eo "([0-9]+\.){3}[0-9]+\/[0-9]+" | cut -d "/" -f1 | head -1)
    fi
    echo $IP
}

echo "library: loaded"


# test one function of the library
RET=$(get_lib_version)
if [ $? -ne 0 ]; then
    echo "Installer/Fixer: library $LIB_NAME could not be loaded!"
    exit -2
fi
if [ "$RET" == "" ]; then
    echo "Installer/Fixer: library $LIB_NAME does not work."
    exit -2
fi
echo "Library version=$RET"

# Test which platform this script is being run on
get_platform_params
set_some_common_params

if [ "$IS_ROOT" = "true" ]; then
    print_bold "Welcome to the ioBroker installer!" "Installer version: $INSTALLER_VERSION"
else
    print_bold "Welcome to the ioBroker installer!" "Installer version: $INSTALLER_VERSION" "" "You might need to enter your password a couple of times."
fi

# Which npm package should be installed (default "iobroker")
INSTALL_TARGET=${INSTALL_TARGET-"iobroker"}

export AUTOMATED_INSTALLER="true"
export DEBIAN_FRONTEND=noninteractive
NUM_STEPS=4

# ########################################################
print_step "Installing prerequisites" 1 "$NUM_STEPS"

# update repos
$SUDOX $INSTALL_CMD $INSTALL_CMD_UPD_ARGS update

# Install Node.js if it is not installed
if [[ $(type -P "node" 2>/dev/null) != *"/node" ]]; then
    install_nodejs
fi

# Check if npm is installed
if [[ $(type -P "npm" 2>/dev/null) != *"/npm" ]]; then
    # If not, try to install it
    install_package npm
    if [[ $(type -P "npm" 2>/dev/null) != *"/npm" ]]; then
        echo "${red}Cannot continue because \"npm\" is not installed and could not be installed automatically!${normal}"
        exit 1
    fi
fi

# Select an npm mirror, by default use npmjs.org
REGISTRY_URL="https://registry.npmjs.org"
case "$MIRROR" in
[Tt]aobao)
    REGISTRY_URL="https://registry.npm.taobao.org"
    ;;
esac
if [ "$(npm config get registry)" != "$REGISTRY_URL" ]; then
    echo "Changing npm registry to $REGISTRY_URL"
    npm config set registry $REGISTRY_URL
fi

# Determine the platform we operate on and select the installation routine/packages accordingly
install_necessary_packages

# ########################################################
print_step "Creating ioBroker user and directory" 2 "$NUM_STEPS"

# Ensure the user "iobroker" exists and is in the correct groups
if [ "$HOST_PLATFORM" = "linux" ]; then
    create_user_linux $IOB_USER
elif [ "$HOST_PLATFORM" = "freebsd" ]; then
    create_user_freebsd $IOB_USER
fi

# Ensure the installation directory exists and take control of it
$SUDOX mkdir -p $IOB_DIR
if [ "$IS_ROOT" != true ]; then
    # During the installation we need to give the current user access to the install dir
    # On Linux, we'll fix this at the end. On OSX this is okay
    if [ "$HOST_PLATFORM" = "osx" ]; then
        sudo chown -R $USER $IOB_DIR
    else
        sudo chown -R $USER:$USER_GROUP $IOB_DIR
    fi
fi
cd $IOB_DIR
echo "Directory $IOB_DIR created"

# Log some information about the installer
touch $INSTALLER_INFO_FILE
chmod 777 $INSTALLER_INFO_FILE
echo "Installer version: $INSTALLER_VERSION" >>$INSTALLER_INFO_FILE
echo "Installation date $(date +%F)" >>$INSTALLER_INFO_FILE
echo "Platform: $HOST_PLATFORM" >>$INSTALLER_INFO_FILE

# ########################################################
print_step "Installing ioBroker" 3 "$NUM_STEPS"

# Disable any warnings related to "npm audit fix"
disable_npm_audit

# Disable any information related to npm updates
disable_npm_updatenotifier

# Enforce strict version checks before installing new packages
force_strict_npm_version_checks

# Create ioBroker's package.json and install dependencies:
PACKAGE_JSON_FILE=$(
    cat <<-EOF
	{
		"name": "iobroker.inst",
		"version": "3.0.0",
		"private": true,
		"description": "Automate your Life",
		"engines": {
			"node": ">=18.0.0"
		},
		"dependencies": {
			"iobroker.js-controller": "stable",
			"iobroker.admin": "stable",
			"iobroker.discovery": "stable",
			"iobroker.backitup": "stable"
		}
	}
	EOF
)

# Create package.json and install all dependencies
PACKAGE_JSON_FILENAME="$IOB_DIR/package.json"
write_to_file "$PACKAGE_JSON_FILE" $PACKAGE_JSON_FILENAME
npm i --production --loglevel error --unsafe-perm >/dev/null

# ########################################################
print_step "Finalizing installation" 4 "$NUM_STEPS"

# Test which init system is used:
INITSYSTEM="unknown"
if [[ "$HOST_PLATFORM" = "freebsd" && -d "/usr/local/etc/rc.d" ]]; then
    INITSYSTEM="rc.d"
elif [[ $(ps -p 1 -o comm=) = "systemd" ]] &>/dev/null; then
    INITSYSTEM="systemd"
elif [[ -f /etc/init.d/cron && ! -L /etc/init.d/cron ]]; then
    INITSYSTEM="init.d"
elif [[ "$HOST_PLATFORM" = "osx" ]]; then
    INITSYSTEM="launchctl"
    PLIST_FILE_LABEL="org.ioBroker.LaunchAtLogin"
    SERVICE_FILENAME="/Users/${IOB_USER}/Library/LaunchAgents/${PLIST_FILE_LABEL}.plist"
fi
if [[ $IOB_FORCE_INITD && ${IOB_FORCE_INITD-x} ]]; then
    INITSYSTEM="init.d"
fi
echo "init system: $INITSYSTEM" >>$INSTALLER_INFO_FILE

# #############################
# Create "iob" and "iobroker" executables
# If possible, try to always execute the iobroker CLI as the correct user
IOB_NODE_CMDLINE="node"
if [ "$IOB_USER" != "$USER" ]; then
    IOB_NODE_CMDLINE="sudo -H -u $IOB_USER node"
fi
if [ "$INITSYSTEM" = "systemd" ]; then
    # systemd needs a special executable that reroutes iobroker start/stop to systemctl
    # Make sure to only use systemd when there is exactly 1 argument
    IOB_EXECUTABLE=$(
        cat <<-EOF
		#!$BASH_CMDLINE
		if (( \$# == 1 )) && ([ "\$1" = "start" ] || [ "\$1" = "stop" ] || [ "\$1" = "restart" ]); then
            if [ "\$(id -u)" = 0 ] && [[ "\$*" != *--allow-root* ]]; then
                echo -e "\n***For security reasons ioBroker should not be run or administrated as root.***\nBy default only a user that is member of "iobroker" group can execute ioBroker commands.\nPlease execute 'iob fix'to create an appropriate setup!"
            fi
			sudo systemctl \$1 iobroker
			exit \$?
		fi
		if [ "\$(id -u)" = 0 ] && [[ "\$*" != *--allow-root* ]]; then
			echo -e "\n***For security reasons ioBroker should not be run or administrated as root.***\nBy default only a user that is member of "iobroker" group can execute ioBroker commands.\nPlease read the Documentation on how to set up such a user, if not done yet.\nOnly in very special cases you can run iobroker commands by adding the "--allow-root" option at the end of the command line.\nPlease note that this option may be disabled in the future, so please change your setup accordingly now."
			exit 1;
		elif [ "\$(id -u)" -gt 0 ] && [ "\$*" = "*--allow-root*" ]; then
			echo "Invalid option --allow-root";
			exit 1;
		fi
		if [ "\$1" = "fix" ]; then
			sudo -u $IOB_USER curl -sLf $FIXER_URL --output /home/$IOB_USER/.fix.sh && bash /home/$IOB_USER/.fix.sh "\$2"
		elif [ "\$1" = "nodejs-update" ]; then
			sudo -u $IOB_USER curl -sLf $NODE_UPDATER_URL --output /home/$IOB_USER/.nodejs-update.sh && bash /home/$IOB_USER/.nodejs-update.sh "\$2"
		elif [ "\$1" = "diag" ]; then
			sudo -u $IOB_USER curl -sLf $DIAG_URL --output /home/$IOB_USER/.diag.sh && sudo -u $IOB_USER bash /home/$IOB_USER/.diag.sh "\$2" &> /home/$IOB_USER/iob_diag.log

		else
			$IOB_NODE_CMDLINE $CONTROLLER_DIR/iobroker.js "\$@"
		fi
		EOF
    )
elif [ "$INITSYSTEM" = "launchctl" ]; then
    # launchctl needs unload service to stop iobroker
    IOB_EXECUTABLE=$(
        cat <<-EOF
		#!$BASH_CMDLINE
		if (( \$# == 1 )) && ([ "\$1" = "start" ]); then
			launchctl load -w $SERVICE_FILENAME
		elif (( \$# == 1 )) && ([ "\$1" = "stop" ]); then
			launchctl unload -w $SERVICE_FILENAME
			$IOB_NODE_CMDLINE $CONTROLLER_DIR/iobroker.js stop
		elif [ "\$1" = "fix" ]; then
			sudo -u $IOB_USER curl -sLf $FIXER_URL --output /Users/$IOB_USER/.fix.sh && bash /Users/$IOB_USER/.fix.sh "\$2"
		elif [ "\$1" = "nodejs-update" ]; then
			sudo -u $IOB_USER curl -sLf $NODE_UPDATER_URL --output /Users/$IOB_USER/.nodejs-update.sh && bash /Users/$IOB_USER/.nodejs-update.sh "\$2"
		elif [ "\$1" = "diag" ]; then
		  sudo -u $IOB_USER curl -sLf $DIAG_URL --output /Users/$IOB_USER/.diag.sh && bash /Users/$IOB_USER/.diag.sh "\$2" | sudo -u $IOB_USER tee /Users/$IOB_USER/iob_diag.log
		else
			$IOB_NODE_CMDLINE $CONTROLLER_DIR/iobroker.js "\$@"
		fi
		EOF
    )
else
    IOB_EXECUTABLE=$(
        cat <<-EOF
		#!$BASH_CMDLINE
		if [ "\$1" = "fix" ]; then
			sudo -u $IOB_USER curl -sLf $FIXER_URL --output /home/$IOB_USER/.fix.sh && bash /home/$IOB_USER/.fix.sh "\$2"
		elif [ "\$1" = "nodejs-update" ]; then
			sudo -u $IOB_USER curl -sLf $NODE_UPDATER_URL --output /home/$IOB_USER/.nodejs-update.sh && bash /home/$IOB_USER/.nodejs-update.sh "\$2"
		elif [ "\$1" = "diag" ]; then
		  sudo -u $IOB_USER curl -sLf $DIAG_URL --output /home/$IOB_USER/.diag.sh && bash /home/$IOB_USER/.diag.sh "\$2" | sudo -u $IOB_USER tee /home/$IOB_USER/iob_diag.log
		else
			$IOB_NODE_CMDLINE $CONTROLLER_DIR/iobroker.js "\$@"
		fi
		EOF
    )
fi
if [ "$HOST_PLATFORM" = "linux" ]; then
    IOB_BIN_PATH=/usr/bin
elif [ "$HOST_PLATFORM" = "freebsd" ] || [ "$HOST_PLATFORM" = "osx" ]; then
    IOB_BIN_PATH=/usr/local/bin
fi

# Symlink the global binaries iob and iobroker
$SUDOX ln -sfn $IOB_DIR/iobroker $IOB_BIN_PATH/iobroker
$SUDOX ln -sfn $IOB_DIR/iobroker $IOB_BIN_PATH/iob
# Symlink the local binary iob
$SUDOX ln -sfn $IOB_DIR/iobroker $IOB_DIR/iob

# Create executables in the ioBroker directory
# TODO: check if this must be fixed like in in the FIXER for #216
write_to_file "$IOB_EXECUTABLE" $IOB_DIR/iobroker
make_executable "$IOB_DIR/iobroker"

# TODO: check if this is necessary, like in the FIXER
## and give them the correct ownership
#change_owner $IOB_USER "$IOB_DIR/iobroker"
#change_owner $IOB_USER "$IOB_DIR/iob"

# #############################
# Enable autostart
# From https://unix.stackexchange.com/questions/18209/detect-init-system-using-the-shell/326213
# if [[ `/sbin/init --version` =~ upstart ]]; then echo using upstart;
# elif [[ `systemctl` =~ -\.mount ]]; then echo using systemd;
# elif [[ -f /etc/init.d/cron && ! -h /etc/init.d/cron ]]; then echo using sysv-init;
# else echo cannot tell; fi

# Enable autostart
if [[ "$INITSYSTEM" = "init.d" ]]; then
    echo "Enabling autostart..."

    # Write a script into init.d that automatically detects the correct node executable and runs ioBroker
    INITD_FILE=$(
        cat <<-EOF
		#!$BASH_CMDLINE
		### BEGIN INIT INFO
		# Provides:          iobroker.sh
		# Required-Start:    \$network \$local_fs \$remote_fs
		# Required-Stop:     \$network \$local_fs \$remote_fs
		# Should-Start:      redis-server
		# Should-Stop:       redis-server
		# Default-Start:     2 3 4 5
		# Default-Stop:      0 1 6
		# Short-Description: starts ioBroker
		# Description:       starts ioBroker
		### END INIT INFO
		PIDF=$CONTROLLER_DIR/lib/iobroker.pid
		NODECMD=\$(which node)
		RETVAL=0

		start() {
			echo -n "Starting ioBroker"
			su - $IOB_USER -s "$BASH_CMDLINE" -c "\$NODECMD $CONTROLLER_DIR/iobroker.js start"
			RETVAL=\$?
		}

		stop() {
			echo -n "Stopping ioBroker"
			su - $IOB_USER -s "$BASH_CMDLINE" -c "\$NODECMD $CONTROLLER_DIR/iobroker.js stop"
			RETVAL=\$?
		}
		if [ "\$1" = "start" ]; then
			start
		elif [ "\$1" = "stop" ]; then
			stop
		elif [ "\$1" = "restart" ]; then
			stop
			start
		else
			echo "Usage: iobroker \{start\|stop\|restart\}"
			exit 1
		fi
		exit \$RETVAL
		EOF
    )

    # Create the startup file, give it the correct permissions and start ioBroker
    SERVICE_FILENAME="/etc/init.d/iobroker.sh"
    write_to_file "$INITD_FILE" $SERVICE_FILENAME
    set_root_permissions $SERVICE_FILENAME
    $SUDOX bash $SERVICE_FILENAME

    echo "Autostart enabled!"
    # Remember what we did
    if [[ $IOB_FORCE_INITD && ${IOB_FORCE_INITD-x} ]]; then
        echo "Autostart: init.d (forced)" >>"$INSTALLER_INFO_FILE"
    else
        echo "Autostart: init.d" >>"$INSTALLER_INFO_FILE"
    fi
elif [ "$INITSYSTEM" = "systemd" ]; then
    echo "Enabling autostart..."

    # Write an systemd service that automatically detects the correct node executable and runs ioBroker
    SYSTEMD_FILE=$(
        cat <<-EOF
		[Unit]
		Description=ioBroker Server
		Documentation=http://iobroker.net
		After=network.target redis.service influxdb.service mysql-server.service mariadb-server.service
		Wants=redis.service influxdb.service mysql-server.service mariadb-server.service

		[Service]
		Type=simple
		User=$IOB_USER
		Environment="NODE=\$(which node)"
		ExecStart=$BASH_CMDLINE -c '\${NODE} $CONTROLLER_DIR/controller.js'
		Restart=on-failure
		RestartSec=3s

		[Install]
		WantedBy=multi-user.target
		EOF
    )

    # Create the startup file and give it the correct permissions
    SERVICE_FILENAME="/lib/systemd/system/iobroker.service"
    write_to_file "$SYSTEMD_FILE" $SERVICE_FILENAME
    if [ "$IS_ROOT" != true ]; then
        sudo chown root:$ROOT_GROUP $SERVICE_FILENAME
    fi
    $SUDOX chmod 644 $SERVICE_FILENAME
    $SUDOX systemctl daemon-reload
    $SUDOX systemctl enable iobroker
    $SUDOX systemctl start iobroker
    echo "Autostart enabled!"
    echo "Autostart: systemd" >>"$INSTALLER_INFO_FILE"

elif [ "$INITSYSTEM" = "rc.d" ]; then
    echo "Enabling autostart..."

    PIDFILE="$CONTROLLER_DIR/lib/iobroker.pid"

    # Write an rc.d service that automatically detects the correct node executable and runs ioBroker
    RCD_FILE=$(
        cat <<-EOF
		#!$BASH_CMDLINE
		#
		# PROVIDE: iobroker
		# REQUIRE: DAEMON
		# KEYWORD: shutdown

		. /etc/rc.subr

		name="iobroker"
		rcvar="iobroker_enable"

		load_rc_config \$name

		iobroker_enable=\${iobroker_enable-"NO"}
		iobroker_pidfile=\${iobroker_pidfile-"$PIDFILE"}

		iobroker_start()
		{
			iobroker start
		}

		iobroker_stop()
		{
			iobroker stop
		}

		iobroker_status()
		{
			iobroker status
		}

		PATH="\${PATH}:/usr/local/bin"
		pidfile="\${iobroker_pidfile}"

		start_cmd=iobroker_start
		stop_cmd=iobroker_stop
		status_cmd=iobroker_status

		run_rc_command "\$1"
		EOF
    )

    # Create the startup file, give it the correct permissions and start ioBroker
    SERVICE_FILENAME="/usr/local/etc/rc.d/iobroker"
    write_to_file "$RCD_FILE" $SERVICE_FILENAME
    set_root_permissions $SERVICE_FILENAME

    # Make sure that $IOB_USER may access the pidfile
    $SUDOX touch "$PIDFILE"
    $SUDOX chown $IOB_USER:$IOB_USER $PIDFILE

    # Enable startup and start the service
    sysrc iobroker_enable=YES
    service iobroker start

    echo "Autostart enabled!"
    echo "Autostart: rc.d" >>"$INSTALLER_INFO_FILE"

elif [ "$INITSYSTEM" = "launchctl" ]; then
    echo "Enabling autostart..."

    NODECMD=$(which node)
    # osx use launchd.plist init system.
    PLIST_FILE=$(
        cat <<-EOF
		<?xml version="1.0" encoding="UTF-8"?>
		<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
		<plist version="1.0">
		<dict>
			<key>Label</key>
			<string>${PLIST_FILE_LABEL}</string>
			<key>ProgramArguments</key>
			<array>
				<string>${NODECMD}</string>
				<string>${CONTROLLER_DIR}/iobroker.js</string>
				<string>start</string>
			</array>
			<key>KeepAlive</key>
			<true/>
			<key>RunAtLoad</key>
			<true/>
			<key>EnvironmentVariables</key>
			<dict>
				<key>PATH</key>
				<string>/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin</string>
			</dict>
		</dict>
		</plist>
		EOF
    )

    # Create the startup file, give it the correct permissions and start ioBroker
    echo "$PLIST_FILE" >$SERVICE_FILENAME

    # Enable startup and start the service
    launchctl list ${PLIST_FILE_LABEL} &>/dev/null
    if [ $? -eq 0 ]; then
        echo "Reloading service ${PLIST_FILE_LABEL}"
        launchctl unload -w $SERVICE_FILENAME
    fi
    launchctl load -w $SERVICE_FILENAME

    echo "Autostart enabled!"
    echo "Autostart: launchctl" >>"$INSTALLER_INFO_FILE"

else
    echo "${yellow}Unsupported init system, cannot enable autostart!${normal}"
    echo "Autostart: false" >>"$INSTALLER_INFO_FILE"
fi

# Raspberry image has as last line in /etc/rc.local the ioBroker installer. It must be removed
if [ -f /etc/rc.local ]; then
    if [ -w /etc/rc.local ]; then
        if [ "$IS_ROOT" != true ]; then
            sudo sed -i 's/curl -sLf https:\/\/iobroker.net\/install\.sh | bash -//g' /etc/rc.local
        else
            sed -i 's/curl -sLf https:\/\/iobroker.net\/install\.sh | bash -//g' /etc/rc.local
        fi
    fi
fi

# Enable auto-completion for ioBroker commands
enable_cli_completions

# Test again which platform this script is being run on
# This is necessary because FreeBSD does crazy stuff
get_platform_params

# Make sure that the app dir belongs to the correct user
# Don't do it on OSX, because we'll install as the current user anyways
if [ "$HOST_PLATFORM" != "osx" ]; then
    fix_dir_permissions
fi
# Force npm to run as iobroker when inside IOB_DIR
if [[ "$IS_ROOT" != true && "$USER" != "$IOB_USER" ]]; then
    change_npm_command_user
fi
change_npm_command_root

unset AUTOMATED_INSTALLER

# Detect IP address
IP=$(detect_ip_address)
print_bold "${green}ioBroker was installed successfully${normal}" "Open http://$IP:8081 in a browser and start configuring!"

print_msg "${yellow}You need to re-login before doing anything else on the console!${normal}"

if [ "$RECOMMEND_FIXER_AFTER_INSTALL" = "true" ]; then
    print_bold "${red}Please run 'iob fix' after the required re-login to fix some common issues.${normal}"
fi
exit 0