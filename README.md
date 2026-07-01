# Omybuntu

<p align="center">
  <img src="themes/omybuntu/preview.png" alt="Omybuntu Theme Preview" width="100%">
</p>

Omybuntu is an unofficial, highly optimized port of **Omarchy** and **Omakub** for the **Debian/Ubuntu** ecosystem. It maintains the original philosophy of creating an opinionated, beautiful, and developer-focused desktop environment, while providing rock-solid stability.

---

## 🚀 Key Features

* **Window Manager**: Out-of-the-box [Hyprland](https://hyprland.org/) configuration for smooth, dynamic tiling.
* **Modern Shell & Terminal**: [Foot](https://codeberg.org/dnkl/foot) terminal emulator combined with [Starship](https://starship.rs/) prompt, [zoxide](https://github.com/ajeetdsouza/zoxide), [eza](https://github.com/eza-community/eza), [fzf](https://github.com/junegunn/fzf), [lazygit](https://github.com/jesseduffield/lazygit), [tmux](https://github.com/tmux/tmux), and [btop](https://github.com/aristocratos/btop).
* **Multilingual Installer**: Interactive installation wizard supporting English, Portuguese (Brasil), and Spanish.
* **Theme Support**: Over 20+ curated themes (Catppuccin, Gruvbox, Tokyo Night, Nord, and more) switchable instantly.
* **Sleek Login & Audio**: Built-in `sddm` login manager and `swayosd` for smooth, integrated audio/brightness HUDs.

---

## 🎨 Theme Gallery

Omybuntu comes preconfigured with beautiful dark and light themes. Here are some of the popular previews:

<table align="center">
  <tr>
    <td align="center"><b>Catppuccin</b><br/><img src="themes/catppuccin/preview.png" width="350"/></td>
    <td align="center"><b>Gruvbox</b><br/><img src="themes/gruvbox/preview.png" width="350"/></td>
  </tr>
  <tr>
    <td align="center"><b>Tokyo Night</b><br/><img src="themes/tokyo-night/preview.png" width="350"/></td>
    <td align="center"><b>Nord</b><br/><img src="themes/nord/preview.png" width="350"/></td>
  </tr>
</table>

---

## 📦 Installation Options

### 1. Via Installation Script (On an existing Ubuntu System)

You can install Omybuntu directly on a clean installation of Ubuntu. Run the following command in your terminal:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/erickdevit/omybuntu/master/boot.sh)"
```

> [!TIP]
> You can target custom repositories or branches by setting environment variables prior to running the script:
> ```bash
> OMYBUNTU_REPO="erickdevit/omybuntu" OMYBUNTU_REF="master" bash -c "$(curl -fsSL https://raw.githubusercontent.com/erickdevit/omybuntu/master/boot.sh)"
> ```

### 2. Ready-to-Run ISO (Coming Very Soon! 💿)

For the ultimate clean-slate experience, we are working on a custom **Omybuntu ISO**.
- **No manual configuration**: Boot straight into the installer and get a pre-configured Ubuntu + Hyprland setup.
- **Fast installation**: Uses a prepared base image for rapid deployment.
- **Optimized**: No bloated GNOME desktop to clean up afterwards.
- **Status**: The ISO generation scripts are in active development/testing, and the official `.iso` file release will be available very soon!

---

## 🤝 Acknowledgements & Origin (Créditos)

Omybuntu would not exist without the incredible work of the projects it builds upon. **All conceptual credit, design philosophy, and thousands of hours of initial development belong to the original creators:**

* **[Omarchy](https://github.com/basecamp/omarchy)**: Omybuntu is a direct fork and port of Omarchy. We owe our entire foundation to the Omarchy contributors who built the Arch-based vision.
* **[Omakub](https://omakub.org/)**: The original visionary project created by **David Heinemeier Hansson (DHH)** and the Basecamp team. Omakub set the gold standard for what a beautiful, modern, and opinionated Linux distribution should look and feel like.

Omybuntu aims to be a faithful continuation of this vision, bridging the gap between Omarchy's bleeding-edge Arch architecture and the widespread accessibility of Ubuntu.

---

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details on our professional workflow, issue templates, and pull request standards.

## 📄 License

Omybuntu is released under the [MIT License](https://opensource.org/licenses/MIT).
