# 🐺 Your Aztec Node Startup

A complete all-in-one setup script to deploy an **Aztec sequencer validator node** — giving you your own fully functional RPC endpoints.

Need help or want more features added?  
Feel free to open an issue or submit a pull request.

---

## Clone the Setup Repository

Run the following in your terminal to clone this setup script:

```bash
git clone https://github.com/martinc1991/aztec-node-startup.git && chmod +x aztec-node-startup/aztec/aztec.sh && cd aztec-node-startup
```

### Directory Structure:

```
aztec-node-startup/
├── aztec/
│   └── aztec.sh
└── scripts/
```

---

# 🔪 Aztec Node Setup

Deploy and run an Aztec sequencer validator node on **Ubuntu 20.04 or higher** using this simple auto-setup script.

### Minimum Requirements:

- 8 CPU cores
- 16 GB RAM
- 100+ GB SSD

### Get Started:

1. **Enter the Aztec directory:**

   ```bash
   cd aztec
   ```

2. **Run the setup menu:**
   ```bash
   ./aztec.sh
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

---

# What currently works for me

# VPS Specs, Real Usage Example this is relatable.

I currently run the **Aztec sequencer** on a VPS.

### My VPS Specs:

- 8 CPU cores
- 30 GB RAM
- 1.2 TB SSD

### Active Resource Usage:

- **CPU:** All 8 cores
- **RAM:** ~8 GB used, ~22 GB free
- **Storage:** ~700 GB used, ~500 GB free

This real-world usage should help you decide what VPS setup best suits your needs and budget.
