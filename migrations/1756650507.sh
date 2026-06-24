echo "Fix JetBrains font setting"

if [[ $(omybuntu-font-current) == JetBrains* ]]; then
  omybuntu-font-set "JetBrainsMono Nerd Font"
fi
