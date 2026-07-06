run_logged $OMYBUNTU_INSTALL/post-install/grub-btrfs.sh
run_logged $OMYBUNTU_INSTALL/post-install/ubuntu-cleanup.sh
run_logged $OMYBUNTU_INSTALL/post-install/populate-skel.sh
source $OMYBUNTU_INSTALL/post-install/allow-reboot.sh
source $OMYBUNTU_INSTALL/post-install/finished.sh
