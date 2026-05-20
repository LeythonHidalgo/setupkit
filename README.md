# setupkit

> Interactive Bash tool to provision a Debian/Ubuntu workspace — install, update and deep-uninstall apps from their official signed repositories.

![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Debian%20%7C%20Ubuntu-blue)
![Shell](https://img.shields.io/badge/shell-bash-lightgrey)

setupkit is a menu-driven installer that sets up a development workstation in
minutes. Every application is pulled from its **official, cryptographically
signed repository** — no random scripts piped into a shell, no untrusted
mirrors.

## Features

- **Official sources only** — APT repositories with verified GPG keys.
- **Contextual actions** — install when an app is missing; update or deep-uninstall when it is present.
- **Deep uninstall** — removes packages, repositories, signing keys and (after confirmation) leftover user data.
- **Version aware** — shows the installed version and the latest one available.
- **Modular & scalable** — each category is a self-contained module and the menu builds itself.

## Requirements

- A Debian or Ubuntu based distribution
- `bash` and `sudo`
- `curl` and `ca-certificates` (installed automatically if missing)

## Usage

```bash
git clone https://github.com/LeythonHidalgo/setupkit.git
cd setupkit
chmod +x setup.sh
./setup.sh
```

Run it as your normal user — **not** as root. `sudo` is requested only when needed.

## Available apps

| Category         | Apps |
|------------------|------|
| Browsers         | Brave, Firefox Developer Edition |
| Development      | Visual Studio Code, Git, Docker &amp; Docker Compose, Postman |
| Productivity     | Notion (PWA), Obsidian, Bitwarden |
| System &amp; Network | WireGuard, Proton VPN, Mission Center |
| Remote Access    | AnyDesk, RustDesk |

More categories (Multimedia) are on the way.

## Project structure

```
setupkit/
├── setup.sh           # entry point and menus
├── lib/
│   ├── ui.sh          # colors, banner, message helpers
│   ├── system.sh      # distro detection, sudo, APT/repo helpers
│   └── registry.sh    # category/app registry
└── modules/
    ├── browsers.sh        # Browsers category
    ├── development.sh     # Development category
    ├── productivity.sh    # Productivity category
    ├── system_network.sh  # System & Network category
    └── remote_access.sh   # Remote Access category
```

Adding a new category only requires dropping a file into `modules/`.

## License

Released under the [MIT License](LICENSE) — free to use, modify and distribute.
