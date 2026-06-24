echo "Change to omybuntu-nvim package"
omybuntu-pkg-drop omybuntu-lazyvim
omybuntu-pkg-add omybuntu-nvim

# Will trigger to overwrite configs or not to pickup new hot-reload themes
omybuntu-nvim-setup
