# Set identification from install inputs
if [[ -n ${OMYBUNTU_USER_NAME//[[:space:]]/} ]]; then
  git config --global user.name "$OMYBUNTU_USER_NAME"
fi

if [[ -n ${OMYBUNTU_USER_EMAIL//[[:space:]]/} ]]; then
  git config --global user.email "$OMYBUNTU_USER_EMAIL"
fi
