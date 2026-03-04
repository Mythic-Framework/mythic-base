<div align="center">

![Banner](https://r2.fivemanage.com/b8BG4vav9CjKMUdz6iKnY/mythic_banner_old.png)

# mythic-base

### *Core framework powering every Mythic resource*

**Components • Callbacks • Database • Middleware**

![Lua](https://img.shields.io/badge/-Lua_5.4-2C2D72?style=for-the-badge&logo=lua&logoColor=white)
![FiveM](https://img.shields.io/badge/-FiveM-F40552?style=for-the-badge)
![MongoDB](https://img.shields.io/badge/-MongoDB-47A248?style=for-the-badge&logo=mongodb&logoColor=white)
![Node.js](https://img.shields.io/badge/-Node.js-339933?style=for-the-badge&logo=nodedotjs&logoColor=white)

[Features](#-features) • [Configuration](#-configuration)

</div>

---

## 📖 Overview

The backbone of the Mythic Framework. Provides the component registration system, RPC callbacks, middleware, database abstraction, player management, punishment system, and all the core utilities that every other resource depends on. Nothing runs without this.

---

## ✨ Features

<div align="center">
<table>
<tr>
<td width="50%">

### Core Systems
- **Component Registry** — Register, fetch, extend, and manage dependencies
- **RPC Callbacks** — Bidirectional client/server request-response
- **Middleware** — Priority-based event pipeline
- **DataStore** — Per-player data storage with auto-sync
- **Database** — MongoDB (Game + Auth) and MySQL support

</td>
<td width="50%">

### Player Management
- **Fetch** — Find players by source, SID, or data
- **Punishment** — Ban/kick with duration and permissions
- **Routing** — Bucket-based player isolation
- **Execute** — Trigger client components from server
- **NetSync** — Networked entity operations

</td>
</tr>
</table>
</div>

<div align="center">
<table>
<tr>
<td width="50%">

### Scheduling & Logging
- **Cron** — Schedule by day/hour/minute
- **Tasks** — Recurring jobs by interval
- **Logger** — Console, file, database, Discord outputs
- **Error Handling** — Global error detection and reporting

</td>
<td width="50%">

### Utilities
- **Game** — Entity spawning, streaming, raycasts
- **Sequences** — Auto-incrementing ID generation
- **Discord** — Bot integration and webhooks
- **WebAPI** — Authenticated external API calls

</td>
</tr>
</table>
</div>

---

## ⚙️ Configuration

Server convars set in your `server.cfg`:

```cfg
set sv_environment "DEV"              # DEV or PROD
set sv_access_role 0                  # Access role level
set mongodb_auth_url ""               # Auth DB connection string
set mongodb_auth_database ""          # Auth DB name
set mongodb_game_url ""               # Game DB connection string
set mongodb_game_database ""          # Game DB name
set log_level 0                       # Logging level
set mfw_version ""                    # Framework version tag
```

---

## 📦 Dependencies

| Resource | Why |
|----------|-----|
| `mythic-pwnzor` | Anti-cheat |
| `oxmysql` | MySQL driver for sequences |

---

## 🤝 Credits

<div align="center">
<table>
<tr>
<td align="center" width="50%">
<h3>Framework</h3>
<b>Alzar</b>
</td>
<td align="center" width="50%">
<h3>Maintainers</h3>
<b>Mythic Team</b>
</td>
</tr>
</table>
</div>

---

<div align="center">

[![Made for FiveM](https://img.shields.io/badge/Made_for-FiveM-F40552?style=for-the-badge)](https://fivem.net)
[![Mythic Framework](https://img.shields.io/badge/Mythic-Framework-208692?style=for-the-badge)](https://github.com/mythic-framework)

</div>
