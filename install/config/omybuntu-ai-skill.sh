# Place in each assistant's global skills directory so the Omybuntu skill is available on first install
mkdir -p ~/.agents/skills ~/.claude/skills ~/.codex/skills ~/.pi/agent/skills
ln -sfn "$OMYBUNTU_PATH/default/omybuntu-skill" ~/.agents/skills/omybuntu
ln -sfn "$OMYBUNTU_PATH/default/omybuntu-skill" ~/.claude/skills/omybuntu
ln -sfn "$OMYBUNTU_PATH/default/omybuntu-skill" ~/.codex/skills/omybuntu
ln -sfn "$OMYBUNTU_PATH/default/omybuntu-skill" ~/.pi/agent/skills/omybuntu
