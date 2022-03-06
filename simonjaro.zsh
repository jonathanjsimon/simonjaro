#!/usr/bin/zsh

INSTALL_PKGS=0
BORG_RESTORE=0
REPO_PATH=""
PASSPHRASE=""

function binary_exists()
{

    if [ -z "${1}" ]; then
        return 1
    fi

    if (( $+commands[${1}] ))
    then
        return 0
    fi

    return 1
}

function install_packages()
{
    yay_options=("--useask" "--sudoloop" "--nocleanmenu" "--nodiffmenu" "--noconfirm")
    # ${yay_options[@]}

    # get that rust, needed for some other packages + yay
    /usr/bin/sudo pamac install  --no-confirm rustup gdb lldb yay base-devel
    rustup toolchain install stable
    rustup target add i686-unknown-linux-gnu

    # theme stuff
    yes | yay ${yay_options[@]} -S kvantum materia-kde kvantum-theme-materia materia-gtk-theme gtk-engine-murrine papirus-icon-theme

    # set the theme
    /usr/bin/lookandfeeltool -a com.github.varlesh.materia-dark
    kvantummanager --set MateriaDark

    # remove pulse, kate, etc
    yes | yay ${yay_options[@]} -Rdd pulseaudio pulseaudio-alsa pulseaudio-bluetooth pulseaudio-ctl pulseaudio-zeroconf manjaro-pulse jack2 kate
    # install pipewire
    yes | yay ${yay_options[@]} -S manjaro-pipewire gst-plugin-pipewire plasma-pa pipewire-jack easyeffects pipewire-x11-bell realtime-privileges xdg-desktop-portal-kde

    # some import starters
    yes | yay ${yay_options[@]} -S caffeine-ng gnupg kgpg kwrite 1password opendoas emacs-nox gnome-keyring brave-browser git figlet bc zsh htop bwm-ng aria2 exa unzip

    # virtualbox + linux kernel headers - DKMS should update after installation in next step
    target_kernel_headers=$(for f in `mhwd-kernel -li | awk 'NR>2 {print $2}'`; do pkgnamebase=`basename "${f%.*}"`; echo "${pkgnamebase}-headers ${pkgnamebase}-virtualbox-host-modules"; done | paste -sd ' ')
    target_kernel_headers_array=("${(@s/ /)target_kernel_headers}")
    yes | yay ${yay_options[@]} -S virtualbox virtualbox-guest-iso virtualbox-ext-oracle virtualbox-host-dkms linux-headers dkms ${target_kernel_headers_array[@]}

    # for some reason, linux414 headers get installed
    yes | yay ${yay_options[@]} -Rdd linux414-headers
    yes | yay ${yay_options[@]} -Rdd linux414-virtualbox-host-modules

    # gnome-keyring
    yes | yay ${yay_options[@]} -S libgnome-keyring

    # dock and ulauncher stuff
    yes | yay ${yay_options[@]} -S latte-dock-git ulauncher ulauncher-theme-arc-dark-git plasma5-applets-virtual-desktop-bar-git

    systemctl --user enable --now ulauncher.service

    # cloud stuff
    yes | yay ${yay_options[@]} -S dropbox nextcloud-client

    # spotify AUR installer fails sometimes
    yes | yay ${yay_options[@]} -S spotify

    # chat and email
    yes | yay ${yay_options[@]} -S teams slack-desktop mailspring ferdi-nightly-bin pnpm-bin zoom

    # borg + vorta
    yes | yay ${yay_options[@]} -S borg vorta

    # archive tool
    yes | yay ${yay_options[@]} -S atool

    # code
    yes | yay ${yay_options[@]} -S visual-studio-code-bin gitkraken

    # misc
    yes | yay ${yay_options[@]} -S discover baobab obsidian npm todoist-appimage freecad

    # dotnet core
    yes | yay ${yay_options[@]} -S dotnet-host dotnet-runtime dotnet-runtime-3.1 dotnet-sdk \
                                dotnet-sdk-3.1 dotnet-targeting-pack dotnet-targeting-pack-3.1 aspnet-runtime \
                                aspnet-runtime-3.1 aspnet-targeting-pack aspnet-targeting-pack-3.1


    # installing this separately because it seems to no longer well and I wanted to be able to comment it out
    yes | yay ${yay_options[@]} -S superpaper

    # network tools
    yes | yay ${yay_options[@]} -S speedtest-cli speedtest++ protonvpn-gui

    # other utilities
    yes | yay ${yay_options[@]} -S jq highlight bat ncdu

    # install some npm stuff
    /usr/bin/sudo npm i -g html-minifier uglify-js uglifycss sass

    # install some AUR things that take a while to compile

    # mono-git build-depends on mono so we have to install it first and then replace with mono-git
    if ! binary_exists mono;
    then
        yes | yay ${yay_options[@]} -S automake autoconf
        yes | yay ${yay_options[@]} -S mono
        yes | yay ${yay_options[@]} -S mono-git mono-msbuild
    fi
    # yes | yay ${yay_options[@]} -S mingw-w64-freetype2
    yes | yay ${yay_options[@]} -S wine-valve proton
}

function main()
{
    pushd ~

    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

    # Configure pamac and pacman now so we can install dependencies
    /usr/bin/sudo perl -p -i -e 's/^.UseSyslog/UseSyslog/g; s/^.Color/Color/g; s/^.TotalDownload/TotalDownload/g; s/^.ParallelDownloads.*/ParallelDownloads = 10/g;' /etc/pacman.conf
    /usr/bin/sudo perl -p -i -e 's/^.EnableAUR/EnableAUR/g; s/^.EnableSnap/EnableSnap/g; s/^.EnableFlatpak/EnableFlatpak/g; s/^.CheckFlatpakUpdates/CheckFlatpakUpdates/g;' /etc/pamac.conf

    if [ `grep -c 'EnableSnap' /etc/pamac.conf` -eq 0 ];
    then
        cat << EOF | /usr/bin/sudo tee -a /etc/pamac.conf
EnableSnap
EOF
    fi

    if [ `grep -c 'EnableFlatpak' /etc/pamac.conf` -eq 0 ];
    then
        cat << EOF | /usr/bin/sudo tee -a /etc/pamac.conf
EnableFlatpak
EOF
    fi

    if [ `grep -c 'CheckFlatpakUpdates' /etc/pamac.conf` -eq 0 ];
    then
        cat << EOF | /usr/bin/sudo tee -a /etc/pamac.conf
CheckFlatpakUpdates
EOF
    fi
    /usr/bin/sudo perl -p -i -e 's/^.MAKEFLAGS=.*/MAKEFLAGS="-j8"/g' /etc/makepkg.conf

    if [ ${BORG_RESTORE} -gt 0 ]
    then
        if ! binary_exists borg;
        then
            echo "borg must be installed"
            INSTALL_BORG=''
            while [ "${INSTALL_BORG:l}" != 'y' ] && [ "${INSTALL_BORG:l}" != 'n' ];
            do
                read "INSTALL_BORG?Install borg [y/N]? "
            done

            if [ "${INSTALL_BORG:l}" == 'y' ];
            then
                yes | yay ${yay_options[@]} -S borg
            fi
        fi

        if binary_exists borg;
        then
            while [ -z "${REPO_PATH}" ] || ! [ -d "${REPO_PATH}" ];
            do
                read "REPO_PATH?Borg repo path? "
            done

            while [ -z "${PASSPHRASE}" ];
            do
                read "PASSPHRASE?Repo passphrase (${REPO_PATH}): "
                if [ -n "${PASSPHRASE}" ];
                then
                    export BORG_PASSPHRASE="${PASSPHRASE}"
                    borg info "${REPO_PATH}" &> /dev/null
                    if [ $? -gt 0 ] ;
                    then
                        echo "Passphrase incorrect"
                        PASSPHRASE=""
                    fi
                fi
            done
        else
            echo "borg still not installed, ignoring borg restore request"
        fi
    fi

    cat << 'EOF' | /usr/bin/sudo tee /etc/udev/rules.d/81-wifi-powersave.rules
# never power save wifi, the chip will disconnect from the network randomly on 5GHz

ACTION=="add", SUBSYSTEM=="net", KERNEL=="wl*", RUN+="/usr/bin/iw dev $name set power_save off"
EOF

    for dev in /sys/class/net/*; do
        [ -e "$dev"/wireless ] && /usr/bin/sudo /usr/bin/iw dev ${dev##*/} set power_save off
    done

    cat << EOF | /usr/bin/sudo tee /etc/doas.conf
permit persist :wheel
EOF

    cat << EOF | /usr/bin/sudo tee /etc/sysctl.d/99-max-watchers.conf
fs.inotify.max_user_watchers = 1000000
EOF

# into ~/.config/1Password/settings/settings.json
# {
#   "ui.routes.lastUsedRoute": "{\"type\":\"ItemList\",\"content\":{\"unlockedRoute\":{\"collectionUuid\":\"everything\"},\"itemListType\":{\"type\":\"Vault\",\"content\":\"1A\"},\"category\":null,\"sortBehavior\":null}}",
#   "app.theme": "dark",
#   "passwordGenerator.size.characters": 25,
#   "passwordGenerator.includeSymbols": true,
#   "browsers.extension.enabled": true,
#   "keybinds.open": "CommandOrControl+Shift+\\",
#   "keybinds.autoFill": ""
# }

    /usr/bin/sudo sysctl --system

    /usr/bin/sudo wget -O /usr/share/konsole/base16-tomorrow-night.colorscheme https://raw.githubusercontent.com/cskeeters/base16-konsole/master/colorscheme/base16-tomorrow-night.colorscheme

    if [ ${INSTALL_PKGS} -gt 0 ];
    then
        install_packages
    fi

    if [ ${BORG_RESTORE} -gt 0 ];
    then
        LAST_SNAPSHOT=`borg list --short --last 1 "${REPO_PATH}"`
        echo "${LAST_SNAPSHOT}"
        borg --progress extract --strip-components 2 "${REPO_PATH}::${LAST_SNAPSHOT}" home/${USER}/{Desktop,Documents,Music,techsupport,Videos,VirtualBox\ VMs,Downloads,Development,Dropbox,.ssh,.gnupg,.gitconfig,/.config/BraveSoftware/Brave-Browser,.config/Ferdi,.config/superpaper,.config/obsidian}
        # borg --progress extract --strip-components 2 "${REPO_PATH}::${LAST_SNAPSHOT}" home/${USER}/.config/obsidian
    fi
}

for arg in "$@"
do
    case "$arg" in
        --borg)
            BORG_RESTORE=1
        ;;
        --borg=*)
            BORG_RESTORE=1
            REPO_PATH="${arg#--borg=}"
        ;;
        --pkgs)
            INSTALL_PKGS=1
        ;;
    esac
done

main