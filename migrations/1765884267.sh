echo "Change to openai-codex instead of openai-codex-bin"

if omybuntu-pkg-present openai-codex-bin; then
    omybuntu-pkg-drop openai-codex-bin
    omybuntu-pkg-add openai-codex
fi
