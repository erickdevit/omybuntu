# Set default XCompose that is triggered with CapsLock
tee ~/.XCompose >/dev/null <<EOF
# Run omybuntu-restart-xcompose to apply changes

# Include fast emoji access
include "$OMYBUNTU_PATH/default/xcompose"

# Identification
<Multi_key> <space> <n> : "$OMYBUNTU_USER_NAME"
<Multi_key> <space> <e> : "$OMYBUNTU_USER_EMAIL"
EOF
