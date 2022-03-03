#!/usr/bin/zsh

pushd ~

INSTALL_PKGS=0
REPO_PATH="${1}"

if [ -z "${REPO_PATH}" ] || ! [ -d "${REPO_PATH}" ];
then
    echo "Invalid repo path"
    exit 1
fi

PASSPHRASE=''
read "PASSPHRASE?Repo passphrase (${REPO_PATH}): "

if [ -z "${PASSPHRASE}" ];
then
    echo "Must supply repo passphrase"
    exit 2
fi

export BORG_PASSPHRASE="${PASSPHRASE}"
borg info "${REPO_PATH}" &> /dev/null
if [ $? -gt 0 ] ;
then
    echo "Passhrase incorrect"
    exit 3
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

/usr/bin/sudo sysctl --system

/usr/bin/sudo wget -O /usr/share/konsole/base16-tomorrow-night.colorscheme https://raw.githubusercontent.com/cskeeters/base16-konsole/master/colorscheme/base16-tomorrow-night.colorscheme

if [ ${INSTALL_PKGS} -gt 0 ];
then
    /usr/bin/sudo perl -p -i -e 's/^.UseSyslog/UseSyslog/g; s/^.Color/Color/g; s/^.TotalDownload/TotalDownload/g; s/^.ParallelDownloads.*/ParallelDownloads = 10/g' /etc/pacman.conf
    /usr/bin/sudo perl -p -i -e 's/^.MAKEFLAGS=.*/MAKEFLAGS="-j8"/g' /etc/makepkg.conf

    # remove some things
    pamac remove kate

    # some import starters
    pamac install --no-confirm caffeine-ng gnupg kgpg kwrite 1password opendoas emacs-nox gnome-keyring brave-browser git figlet bc dkms linux-headers zsh htop bwm-ng aria2 exa unzip

    # remove pulse
    sudo pacman -Rdd pulseaudio pulseaudio-alsa pulseaudio-bluetooth pulseaudio-ctl pulseaudio-zeroconf
    # install pipewire
    sudo pacman -S manjaro-pipewire gst-plugin-pipewire plasma-pa pipewire-jack easyeffects pipewire-x11-bell realtime-privileges xdg-desktop-portal-kde

    # theme stuff
    pamac install --no-confirm kvantum materia-kde kvantum-theme-materia materia-gtk-theme gtk-engine-murrine papirus-icon-theme plasma5-applets-virtual-desktop-bar-git

    # dock and ulauncher stuff
    pamac install --no-confirm latte-dock-git ulauncher ulauncher-theme-arc-dark-git

    # cloud stuff
    pamac install --no-confirm dropbox nextcloud-client

    # spotify AUR installer fails sometimes
    pamac install --no-confirm spotify

    # chat and email
    pamac install --no-confirm teams slack-desktop mailspring ferdi-bin pnpm-bin

    # archive tool
    pamac install --no-confirm atool

    # code
    pamac install --no-confirm visual-studio-code-bin

    # VMs
    pamac install --no-confirm virtualbox virtualbox-guest-iso virtualbox-ext-oracle

    # rust
    pamac install --no-confirm rustup gdb lldb

    # misc
    pamac install --no-confirm discover baobab obsidian npm

    # dotnet core
    pamac install --no-confirm dotnet-host dotnet-runtime dotnet-runtime-3.1 dotnet-sdk \
                                dotnet-sdk-3.1 dotnet-targeting-pack dotnet-targeting-pack-3.1 aspnet-runtime \
                                aspnet-runtime-3.1 aspnet-targeting-pack aspnet-targeting-pack-3.1


    # installing this separately because it seems to no longer well and I wanted to be able to comment it out
    pamac install --no-confirm superpaper

    # get that rust
    rustup toolchain install stable
    rustup target add i686-unknown-linux-gnu

    # install some npm stuff
    sudo npm i -g html-minifier uglify-js uglifycss sass

    # mono, gotta check if mono-git is already installed so we don't do this twice
    pamac install --no-confirm mono
    # install some AUR things that take a while to compile
    # mono-git build-depends on mono which is installed in the prior steps
    pamac install --no-confirm mono-git wine-valve proton

    # set icons this way cuz I can
    /usr/lib/plasma-changeicons Papirus-Dark
fi

LAST_SNAPSHOT=`borg list --short --last 1 "${REPO_PATH}"`
echo "${LAST_SNAPSHOT}"
borg --progress extract --strip-components 2 "${REPO_PATH}::${LAST_SNAPSHOT}" home/${USER}/{Desktop,Documents,Music,techsupport,Videos,VirtualBox\ VMs,Downloads,Development,Dropbox,.ssh,.gnupg,.gitconfig,/.config/BraveSoftware/Brave-Browser,.config/Ferdi,.config/superpaper,.config/obsidian}

# borg --progress extract --strip-components 2 "${REPO_PATH}::${LAST_SNAPSHOT}" home/${USER}/.config/obsidian