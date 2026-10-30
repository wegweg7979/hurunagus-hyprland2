# hurunagus-hyprland

Declarative, atomic, immutable Linux system. Fedora 44 base, from ublue, with the
Hyprland + Omarchy desktop (for Hurunagus), automatic weekly updates and all the
apps I need preinstalled.

Reason to exist: making all my computers run identical systems, administered in
one place, from a single repo. Automatic builds once a week on a Tuesday.

Dont use this — make your own, it is not too difficult and quite fun.
https://github.com/ublue-os/image-template

If you didn't listen to the line above and insist on installing from scratch,
grab the installer ISO:

```text
https://drive.google.com/file/d/1a5cKI8DIOkMS1URaBouHjLXrVkTheixX/view?usp=sharing
```

Be aware installed apps and features will be added or removed as I see fit at
anytime. Hence the warning to not consider this a "stable" OS for anyone except
myself. It is, in fact, a rock solid, efficient and fully featured operating
system suitable for multimedia and modern computing in 2026. If you are the admin
for more than one machine, you should really take the time to make one yourself
for exactly YOUR needs.

OR: to rebase an existing atomic Fedora installation (tested from Bluefin and
Silverblue) to the latest build:

- First rebase to the unsigned image, to get the proper signing keys and policies
  installed:
  ```sh
  rpm-ostree rebase ostree-unverified-registry:ghcr.io/wegweg7979/hurunagus-hyprland:latest
  ```
- Reboot to complete the rebase:
  ```sh
  systemctl reboot
  ```
- Then rebase to the signed image, like so:
  ```sh
  rpm-ostree rebase ostree-image-signed:docker://ghcr.io/wegweg7979/hurunagus-hyprland:latest
  ```
- Reboot again to complete the installation:
  ```sh
  systemctl reboot
  ```

## Desktop

This image ships **Hyprland** with **Omarchy** dotfiles, based on the omadora
variant of Omarchy. Highlights:

- **Hyprland** as the window manager (replaces Niri / Dank Material Shell).
- **Omarchy** dotfiles under `~/.config/hypr` and `~/.config/omarchy` for the
  look & feel, keybindings and first-boot provisioning.
- **1080p default** — the desktop starts at 1920×1080 regardless of what the
  display advertises.
- **Scrolling window layout** as the default Hyprland layout.
- **Wallpapers imported** from the original project into
  `~/.local/share/backgrounds` and `/usr/share/backgrounds/hurunagus`.
- **Flatpak list imported** so all of the favourite apps are installed on first
  boot.

## Project structure

```text
.
├── Containerfile          # Builds the image from ghcr.io/ublue-os/base-main
├── build_files/
│   ├── build.sh           # Image build script (packages + system files + services)
│   ├── fedora.toml        # Package map: Arch → Fedora (omadora/omarchy lists)
│   ├── fedora-baseline.packages
│   ├── omarchy-base.packages
│   ├── fedora-resolve.py  # Resolves Arch package lists to Fedora RPM names
│   └── __pycache__/       # Compiled fedora-resolve.py
├── disk_config/
│   ├── disk.toml          # Bootc image builder config (qcow2/raw)
│   └── iso-gnome.toml     # Bootc image builder config (ISO)
├── system_files/          # Files copied verbatim into the image
│   ├── etc/sddm.conf.d/   # SDDM greeter config (wayland, omarchy theme)
│   ├── etc/skel/.config/hypr/   # Hyprland config (scrolling layout, 1080p)
│   ├── etc/skel/.config/omarchy/  # Omarchy dotfiles + screensaver
│   ├── usr/libexec/       # First-boot scripts (install flatpaks, user groups)
│   ├── usr/share/backgrounds/hurunagus/  # Wallpapers (18)
│   ├── usr/share/gnome-background-properties/  # Background property files
│   ├── usr/share/sddm/themes/omarchy/  # SDDM login theme
│   └── usr/share/wayland-sessions/hurunagus.desktop
├── system-flatpaks.list   # Flatpak app list to install on first boot
├── Justfile               # Build/run/helpers for podman/bib
├── image-template.env     # build parameters (IMAGE_NAME etc.)
├── artifacthub-repo.yml   # Artifact Hub metadata (optional)
└── README.md
```

## Build

```sh
# Build the container image (Podman)
just build

# Build a bootable disk image (Bootc Image Builder)
just build-qcow2

# Or from the Justfile directly
just _rebuild-bib localhost/wegweg7979/hurunagus-hyprland latest qcow2 disk_config/disk.toml
```

## Install

```sh
# Rebase an existing atomic Fedora install
rpm-ostree rebase ostree-unverified-registry:ghcr.io/wegweg7979/hurunagus-hyprland:latest
systemctl reboot

# Then switch to the signed image
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/wegweg7979/hurunagus-hyprland:latest
systemctl reboot
```

## References

- ublue-os image-template: https://github.com/ublue-os/image-template
- Omarchy: https://github.com/omacom/omarchy
- Omedora (omeadora): https://github.com/AndrewGaspar/omadora
- Original Hurunagus ublue project: https://github.com/wegweg7979/hurunagus-ublue
