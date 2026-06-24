echo "Change omybuntu-screenrecord to use gpu-screen-recorder"
omybuntu-pkg-drop wf-recorder wl-screenrec

# Add slurp in case it hadn't been picked up from an old migration
omybuntu-pkg-add slurp gpu-screen-recorder
