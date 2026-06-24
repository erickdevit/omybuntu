echo "Make new Osaka Jade theme available as new default"

if [[ ! -L ~/.config/omybuntu/themes/osaka-jade ]]; then
  rm -rf ~/.config/omybuntu/themes/osaka-jade
  git -C ~/.local/share/omybuntu checkout -f themes/osaka-jade
  ln -nfs ~/.local/share/omybuntu/themes/osaka-jade ~/.config/omybuntu/themes/osaka-jade
fi
