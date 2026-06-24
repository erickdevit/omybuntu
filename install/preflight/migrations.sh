OMYBUNTU_MIGRATIONS_STATE_PATH=~/.local/state/omybuntu/migrations
mkdir -p $OMYBUNTU_MIGRATIONS_STATE_PATH

for file in "$OMYBUNTU_PATH"/migrations/*.sh; do
  touch "$OMYBUNTU_MIGRATIONS_STATE_PATH/$(basename "$file")"
done
