###########################################################################
# Gen20x QEMU

function qemucpto() {
  # Create an array of all arguments except the last one
  local files=("${@:1:-1}")
  local dest=${*: -1} # Get the last argument using slicing

  PS4='+ '
  set -x

  scp "${files[@]}" root@192.168.7.2:"$dest"

  set +x
}

function qemucpfrom() {
  local benchName=$1
  # Create an array of all arguments except the last one
  local files=("${@:1:-1}")
  local dest=${*: -1} # Get the last argument using slicing

  PS4='+ '
  set -x

  scp root@192.168.7.2:"${files[@]}" "$dest"

  set +x
}

function show_qemu_taproute()
{
  {
    echo "sudo route add -host 192.168.7.2 dev tap0"
    echo "sudo ip route add 192.168.7.2 dev tap0"
    echo "sudo firewall-cmd --zone public --remove-interface tap0"
    echo "sudo firewall-cmd --zone trusted --add-interface tap0"
    echo "sudo iptables -t nat -A POSTROUTING -s 192.168.7.2/32 -j MASQUERADE"
  } | xsel --clipboard
  
  xsel -o --clipboard
}

function show_qemu_richos_ip_routing()
{
  echo "iptables -A POSTROUTING -t nat -j MASQUERADE -s 10.1.0.0/24" | xsel --clipboard

  xsel -o --clipboard
}

function show_qemu_alien_network_config() {
  {
    echo "ip rule add pref 998 lookup main"
    echo "ip route add 10.1.0.0/24 dev eth0 table local"
    echo "ip route add 192.168.7.2 dev eth0 table local"
    echo "ip route add default via 192.168.7.2"
  } | xsel --clipboard

  xsel -o --clipboard
}

alias qemutapsetup="sudo /lhome/jfujiok/mbition/richos/sources/poky/scripts/runqemu-gen-tapdevs `id -u` `id -g` 4 tmp/sysroots-components/x86_64/qemu-helper-native/usr/bin"
alias qemuroutesetup="sudo route add -host 192.168.7.2 dev tap0"
alias qemudeleteroute="sudo ip route delete 192.168.7.2 dev tap0"
alias qemussh="ssh root@192.168.7.2"
alias qemurun-prebuilt-apricote-integration-sw-test="runqemu /lhome/jfujiok/mbition/richos/build-qemu-prebuilt/apricot-image-sw-integration-test-promote-qemux86-64.wic wic kvm audio publicvnc"
alias qemurun-apricot-image-ui-dev="runqemu apricot-image-ui-dev wic kvm audio publicvnc"

###########################################################################
# Set ENVs

function setenv_starfish_aas_qemu_x86_64() {
  PS4='+ ' # remove function name from the output
  set -x  # Enable command echoing

  cd ~/mbition/apricotjol/aas;
  source build/envsetup.sh;
  lunch jolla_appsupport_starfish_x86_64-user

  set +x # Disable command echoing
}

function setenv_gen20x_qemu() {
  PS4='+ ' # remove function name from the output
  set -x  # Enable command echoing
  
  cd ~/mbition/richos
  mkdir -p build-qemu
  export TEMPLATECONF=\"$PWD/sources/meta-mbient/meta-apricot/conf/variant/qemu-x86-64\"
  source sources/poky/oe-init-build-env build-qemu/
  
  set +x # Disable command echoing
}

function setenv_gen20x_qemu_kirkstone() {
  PS4='+ ' # remove function name from the output
  set -x  # Enable command echoing
  
  cd ~/mbition/kirkstone-richos
  mkdir -p build-qemu
  export TEMPLATECONF=\"$PWD/sources/meta-mbient/meta-apricot/conf/variant/qemu-x86-64\"
  source sources/poky/oe-init-build-env build-qemu/
  
  set +x # Disable command echoing
}

function setenv_aosp_car_x86_64() {
  PS4='+ ' # remove function name from the output
  set -x  # Enable command echoing

  cd ~/projects/aosp
  source build/envsetup.sh
  lunch aosp_car_x86_64-userdebug

  set +x # Disable command echoing
}

alias setstarfish-tmux-env='tmux splitw -d -v ;\
  tmux splitw -d -v ;\
  tmux splitw -d -v ;\
  tmux splitw -d -v ;\
  tmux select-layout even-vertical ;\
  tmux splitw -d -h -l 60 ;\
  tmux send-keys -t 1.1 C-z "setenv-qemu-bitbake" Enter ;\
  sleep 0.5 ;\
  tmux send-keys -t 1.6 C-z "source /opt/mbient/1.0/environment-setup-x86-64-generic-mbient-linux" Enter ;\
  sleep 0.5 ;\
  tmux send-keys -t 1.6 C-z "cdstarfish && cd build" Enter ;\
'

###########################################################################
# MTTF

alias mttfrun="mttf-client > /dev/null 2>&1 &"
#alias mttfrun="/lhome/jfujiok/.mttf/mttf-client/mttf-client > /dev/null 2>&1 &"
# alias mttfusage-starfish="curl http://mttf-ber1.rd.corpintra.net:5010/hub/api/v1/slots -H \"X-DrivingLicense: umleise@umlaut.com\" -H \"X-Access-Level: ADMIN\" | jq '.slots | .[]' | jq -s -c 'sort_by(.nodeId) | .[] | [.nodeId, .sessionStatus, .sessionText, .accessGroups[0]]' | grep DOMAIN_STARFISH"
# alias mttfusage="curl http://mttf-ber1.rd.corpintra.net:5010/hub/api/v1/slots -H \"X-DrivingLicense: umleise@umlaut.com\" -H \"X-Access-Level: ADMIN\" | jq '.slots | .[]' | jq -s -c 'sort_by(.nodeId) | .[] | [.nodeId, .sessionStatus, .sessionText, .accessGroups[0]]'"
alias mttfusage-starfish="curl http://cmtcdeu61157006.rd.corpintra.net:5000/hub/api/v1/slots -H \"X-DrivingLicense: umleise@umlaut.com\" -H \"X-Access-Level: ADMIN\" | jq '.slots | .[]' | jq -s -c 'sort_by(.nodeId) | .[] | [.nodeId, .sessionStatus, .sessionText, .accessGroups[0]]' | grep DOMAIN_STARFISH"
alias mttfusage="curl http://cmtcdeu61157006.rd.corpintra.net:5000/hub/api/v1/slots -H \"X-DrivingLicense: umleise@umlaut.com\" -H \"X-Access-Level: ADMIN\" | jq '.slots | .[]' | jq -s -c 'sort_by(.nodeId) | .[] | [.nodeId, .sessionStatus, .sessionText, .accessGroups[0]]'"

###########################################################################
# Starfish Test Benches

function tbcpto() {
  local benchName=$1
  # Create an array of all arguments except the last one
  local files=("${@:2:-1}")
  local dest=${*: -1} # Get the last argument using slicing

  PS4='+ '
  set -x

  scp -rP 5000 "${files[@]}" root@$benchName.rd.corpintra.net:"$dest"

  set +x
}

function tbcpfrom() {
  local benchName=$1
  # Create an array of all arguments except the last one
  local files=("${@:2:-1}")
  local dest=${*: -1} # Get the last argument using slicing

  PS4='+ '
  set -x

  scp -rP 5000 root@$benchName.rd.corpintra.net:"${files[@]}" "$dest"

  set +x
}

alias tbx15ssh=" ssh -p 5000 root@x15.rd.corpintra.net"
alias tbx114ssh="ssh -p 5000 root@x114.rd.corpintra.net"
alias tbx153ssh="ssh -p 5000 root@x153.rd.corpintra.net"


###########################################################################
# Starfish Build Server


STARFISH_BS_HOSTNAME="starfish-bs01.rd.corpintra.net"
STARFISH_BS_ROOT_PRJ_DIR="/home/$USER/projects"

# SSHFS_OPT="-o idmap=user,reconnect,ServerAliveInterval=15,default_permissions,IdentityFile=~/.ssh/id_rsa"
SSHFS_OPT=(-o idmap=user -o reconnect -o ServerAliveInterval=15 -o default_permissions -o IdentityFile=~/.ssh/id_rsa)


# sshfs -o idmap=user,reconnect,ServerAliveInterval=15,default_permissions,IdentityFile=~/.ssh/id_rsa jfujiok@starfish-bs01.rd.corpintra.net:/home/jfujiok/projects /lhome/jfujiok/remote-starfish-bs01-projects/

SSHFS_LOCALHOST_REMOTE_DIR="/lhome/$USER/remote-starfish-bs01/"
SSHFS_LOCALHOST_REMOTE_PRJ_DIR="/lhome/$USER/remote-starfish-bs01-projects/"
SSHFS_BS01="$USER@$STARFISH_BS_HOSTNAME"

function bscpfrom() {
    # Last argument will be the destination on the local machine
    local dest=${*: -1}

    # Create an array of all arguments except the last one, which are the files you want to copy
    local files=("${@:1:-1}")

    # Create an array where each file is prefixed with the remote user and server details
    local remote_files=()
    for file in "${files[@]}"; do
        remote_files+=("$USER@$STARFISH_BS_HOSTNAME:/home/$USER/$file")
    done

    PS4='+ '
    set -x

    rsync -a --info=progress2 "${remote_files[@]}" "$dest"

    set +x
}

# Usage: bscpto SOURCE_FILE(s) DESTINATION_DIRECTORY
# Description:
# The `bscpto` function is designed to efficiently copy one or more source files or directories to a remote destination directory on a target host using the Rsync utility. It provides progress information during the copy process.
# Parameters:
#   - SOURCE_FILE(s): One or more source files or directories to be copied. You can specify multiple files and directories as arguments.
#   - DESTINATION_DIRECTORY: The remote destination directory where the source files/directories will be copied to.
# Usage Example:
# To copy multiple local files and directories to a remote destination directory on the host defined by "$STARFISH_BS_HOSTNAME," use the following command:
#   bscpto file1.txt folder2/ ~/remote/destination/
# Return Value:
# - The function does not return specific values. It utilizes Rsync to perform the file copy operation.
# Note:
# - Ensure that Rsync is installed on your system and that SSH access to the destination host is properly configured.
# - Progress information during the copy process is displayed, including the percentage completion.
# Example:
# bscpto file1.txt folder2/ ~/remote/destination/
function bscpto() {
  # Create an array of all arguments except the last one
  local files=("${@:1:-1}")
  local dest=${*: -1} # Get the last argument using slicing

  PS4='+ '
  set -x

  rsync -a --info=progress2 "${files[@]}" $USER@$STARFISH_BS_HOSTNAME:/home/$USER/"$dest"

  set +x
}

# Usage: bs_mount REMOTE_DIRECTORY LOCAL_DIRECTORY
# Description:
# The `bs_mount` function is designed to mount a remote directory to a local path using SSHFS. It performs checks to ensure the local directory is available and not already mounted before proceeding with the operation.
# Parameters:
#   - REMOTE_DIRECTORY: The absolute path of the remote directory you wish to mount.
#   - LOCAL_DIRECTORY: The absolute path of the local directory where the remote directory will be mounted.
# Usage Example:
# To mount a remote directory at '/home/jfujiok/projects/apricot/starfish' to a local directory '~/myremote/local/path/', use the following command:
#   bs_mount /home/jfujiok/projects/apricot/starfish ~/myremote/local/path/
# Return Value:
# - If the mounting process is successful, the function returns 0.
# - If the local directory already exists and is already mounted, the function returns 1 and displays a message indicating that it's already mounted.
# Note:
# - Ensure that SSHFS is installed on your system to use this function effectively.
# - You can customize SSHFS options by modifying the "${SSHFS_OPT[@]}" part in the function.
# Example:
# bs_mount /home/jfujiok/projects/apricot/starfish ~/myremote/local/path/
function bsmount() {
  local remote_prj_dir=$1
  local local_prj_dir=$2

  if [ ! -d $local_prj_dir ]; then
    mkdir -p $local_prj_dir
  else
    if mountpoint -q "$local_prj_dir"; then
      echo "$local_prj_dir is already mounted!"
      return 1
    fi
  fi

  sshfs "${SSHFS_OPT[@]}" $USER@$STARFISH_BS_HOSTNAME:$remote_prj_dir $local_prj_dir

  # cd $local_prj_dir

  return 0
}

# usage: ~/myremote/local/path/
function bsumount() {
  local local_prj_dir=$1

  if mountpoint -q "$local_prj_dir"; then
    umount -l $local_prj_dir
    rm -rf $local_prj_dir
  fi
}

alias bsssh="ssh $USER@$STARFISH_BS_HOSTNAME"
# alias bs-mount="sshfs $SSHFS_OPT $SSHFS_BS01 $SSHFS_LOCALHOST_REMOTE_PRJ_DIR"
# alias bs-umount="umount $SSHFS_LOCALHOST_REMOTE_PRJ_DIR"


###########################################################################
# Directories

alias cdintent="cd ~/mbition/mbient/intent/"
alias cdmbient="cd ~/mbition/mbient/"
alias cdmbientapparmor-profiles="cd ~/mbition/mbient/apparmor-profiles/"

alias cdapricotapparmor-profiles="cd ~/mbition/apricot/apparmor-profiles/"
alias cdstarfish="cd ~/mbition/apricot/starfish/"

alias cdrichos="cd ~/mbition/richos"
alias cdrichosmbient="cd ~/mbition/richos/sources/meta-mbient/"
alias cdrichosmbient-meta-mbient="cd ~/mbition/richos/sources/meta-mbient/meta-mbient/"
alias cdrichosmbient-meta-apricot="cd ~/mbition/richos/sources/meta-mbient/meta-apricot/"
alias cdstarfishjolla="cd ~/mbition/jolla/starfish"
alias cdstarfishapricotjol="cd mbition/apricotjol/aas"


###########################################################################
# Utils

alias audioreset="sudo alsa force-reload"

alias runsfcache-proxy="sfcache-proxy > /dev/null 2>&1 &"

alias vpnon="daimler-vpn -1"
alias vpnoff="daimler-vpn -0"
alias vpnstatus="daimler-vpn -s"

alias sshrmknowhosts="rm -rf ~/.ssh/known_hosts"

alias rbp="cat ~/.pwdrc | sudo -S rm -rf /etc/opt/chrome/policies; cat ~/.pwdrc | sudo -S rm -rf /etc/opt/edge/policies"

alias run-browser-monitor="/lhome/jfujiok/.scripts/systemd/bin/run-monitor-browser-policies.sh > /dev/null 2>&1 &"

###########################################################################
# aliendalvik
alias starfish-logcat="lxc-attach -n aliendalvik-central --lxcpath /tmp/appsupport -- logcat"


###########################################################################
# Docker

function dockerlogin() {
  cat ~/.docker/dockerrc | docker login -u $USER --password-stdin https://artifact.swf.daimler.com/v2
  cat ~/.docker/dockerrc | docker login -u $USER --password-stdin https://artifact.swf.i.mercedes-benz.com/v2
}

function dockerintent_run_container_as_daemon() {
  PS4='+ ' # remove function name from the output
  set -x  # Enable command echoing
 
  image="remote-cpp/mbient-yocto:dunfell"
  container_name=mbient_yocto_dunfell_remote_cpp

  cdintent

  remote_fs_dir=$PWD/build/remote-fs/usr/include
  mkdir -p $remote_fs_dir
  
  # remove the container (force stop if it's running)
  docker container rm -f $container_name > /dev/null 2>&1
  
  docker run -d \
    --user=$USER \
    --cap-add=NET_ADMIN \
    --cap-add=SYS_PTRACE \
    -p127.0.0.1:2200:22 \
    --name $container_name \
    --workdir=`pwd` \
    --env http_proxy=http://localhost:3128 \
    --env https_proxy=http://localhost:3128 \
    --env ftp_proxy=http://localhost:3128 \
    --env no_proxy="*.local, 169.254/16, *.corpintra.net, *.corpdir.net, *.corpshared.net, *.corpinter.net, .projects.luxoft.com" \
    --env GIT_PROXY_COMMAND="oe-git-proxy" \
    -v `pwd`:`pwd` \
    -v $HOME/.ssh:$HOME/.ssh \
    --mount type=volume,dst=/usr/include/,volume-driver=local,volume-opt=type=none,volume-opt=o=bind,volume-opt=device=$remote_fs_dir \
    ${image} \
    && docker exec -u root $container_name /bin/sh -c "chown -R \"$USER\":domainusers \"$remote_fs_dir\""
    # && docker exec -u root $container_name /bin/sh -c "chown -R \"$USER\":domainusers \"$remote_fs_dir\" && chmod -R 400 \"$remote_fs_dir\""

    set +x  # Disable command echoing
}

alias dockerintent_ssh="ssh -t -p 2200 $USER@localhost \"cd ~/mbition/mbient/intent/ ; bash --login\""
alias dockerintent_ssh-no-cd="ssh -p 2200 $USER@localhost"

function dockerstarfish_run_container_as_daemon() {
  PS4='+ ' # remove function name from the output
  set -x  # Enable command echoing

  cdstarfish
  
  image="remote-cpp/apricot-yocto:dunfell"
  container_name=apricot_yocto_dunfell_remote_cpp_daemon

  remote_fs_dir=$PWD/build/remote-fs/usr/include
  mkdir -p $remote_fs_dir
  
  # remove the container (force stop if it's running)
  docker container rm -f $container_name > /dev/null 2>&1
  
  docker run -d \
    --user=$USER \
    --cap-add=NET_ADMIN \
    --cap-add=SYS_PTRACE \
    -p127.0.0.1:2210:22 \
    --name $container_name \
    --workdir=`pwd` \
    --env http_proxy=http://localhost:3128 \
    --env https_proxy=http://localhost:3128 \
    --env ftp_proxy=http://localhost:3128 \
    --env no_proxy="*.local, 169.254/16, *.corpintra.net, *.corpdir.net, *.corpshared.net, *.corpinter.net, .projects.luxoft.com" \
    --env GIT_PROXY_COMMAND="oe-git-proxy" \
    -v `pwd`:`pwd` \
    -v $HOME/.ssh:$HOME/.ssh \
    --mount type=volume,dst=/usr/include/,volume-driver=local,volume-opt=type=none,volume-opt=o=bind,volume-opt=device=$remote_fs_dir \
    ${image} \
    && docker exec -u root $container_name /bin/sh -c "chown -R \"$USER\":domainusers \"$remote_fs_dir\""
    # && docker exec -u root $container_name /bin/sh -c "chown -R \"$USER\":domainusers \"$remote_fs_dir\" && chmod -R 400 \"$remote_fs_dir\""

    set +x  # Disable command echoing
}

function dockerstarfish_build_image_dunfell() {
  PS4='+ '
  set -x
  docker build --build-arg DEV_USER_NAME=$USER \
    --build-arg=DEV_USER_PWD=1234 \
    --build-arg DEV_UID=$(id -u) \
    --build-arg DOMAINUSERS_GID=$(id -g) \
    --rm -t \
    remote-cpp/apricot-yocto:dunfell \
    -f Dockerfile.remote-cpp .
  set +x
}

alias dockerstarfish_ssh="ssh -t -p 2210 $USER@localhost \"cd ~/mbition/apricot/starfish/ ; bash --login\""
alias dockerstarfish_ssh-no-cd="ssh -p 2210 $USER@localhost"
