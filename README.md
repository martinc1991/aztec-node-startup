# Aztec-Setup

A complete all-in-one setup script to deploy an **Aztec sequencer validator node** — giving you your own fully functional RPC endpoint.

_Can't afford a paid RPC or a powerful VPS right now?
No worries — I'm happy to share access to my self-hosted Sepolia RPC for just $5. It's stable, fast, and perfect if you just need something that works._

Need help or want more features added?  
Follow me on [X (Twitter)](https://x.com/dlordkendex) and tag **@dlordkendex** with your request.

---

## 🚀 Quick Start

Run this single command to download and start the Aztec node setup:

```bash
[ -f "aztec.sh" ] && rm aztec.sh; curl -sSL -o aztec.sh https://raw.githubusercontent.com/martinc1991/aztec-node-startup/main/aztec/aztec.sh && chmod +x aztec.sh && ./aztec.sh
```

That's it! The setup menu will launch automatically. 🎉

### Alternative Menu Interface

If you prefer a different menu interface, you can also use:

```bash
[ -f "menu.sh" ] && rm menu.sh; curl -sSL -o menu.sh https://raw.githubusercontent.com/martinc1991/aztec-node-startup/main/scripts/menu.sh && chmod +x menu.sh && ./menu.sh
```

---

# 🔪 Aztec Node Setup

Deploy and run an Aztec sequencer validator node on **Ubuntu 20.04 or higher** using this simple auto-setup script.

### Minimum Requirements:

- 8 CPU cores
- 16 GB RAM
- 100+ GB SSD

### Get Started:

**Run the setup menu:**

```bash
[ -f "aztec.sh" ] && rm aztec.sh; curl -sSL -o aztec.sh https://raw.githubusercontent.com/martinc1991/aztec-node-startup/main/aztec/aztec.sh && chmod +x aztec.sh && ./aztec.sh
```

**Or use the alternative menu:**

```bash
[ -f "menu.sh" ] && rm menu.sh; curl -sSL -o menu.sh https://raw.githubusercontent.com/martinc1991/aztec-node-startup/main/scripts/menu.sh && chmod +x menu.sh && ./menu.sh
```

### Menu Options:

- **[1] Install/Reinstall**: Installs the Aztec Docker image
- **[2] Edit .env file**: Configure your environment variables
- **[3] Start/Restart**: Starts the Aztec node
- **[4] Logs**: View node logs (press `Ctrl + C` to exit)
- **[5] Status**: Check node status
- **[6] Stop**: Stop the node
- **[7] Shell**: Enter the node container shell
- **[10] Info**: Retrieve block number, proof, and peer ID
- **[RESET]**: Factory reset — use only if necessary
- **[0] Exit**: Exit the menu

### Need Help?

Join the [Aztec Discord](https://discord.gg/aztecprotocol) — check the `#operators | starts-here` channel.
