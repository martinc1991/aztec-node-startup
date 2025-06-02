# 🐺 Aztec Node Startup

A complete all-in-one setup script to deploy an **Aztec sequencer validator node** — giving you your own fully functional RPC endpoints.

Need help or want more features added?  
Feel free to open an issue or submit a pull request.

---

## 🚀 Quick Start (Remote Execution)

Run these commands directly on your server without cloning the repository:

### 1. Setup and Install Dependencies

```bash
[ -f "aztec.sh" ] && rm aztec.sh; curl -sSL -o aztec.sh https://raw.githubusercontent.com/martinc1991/aztec-node-startup/main/aztec.sh && chmod +x aztec.sh && ./aztec.sh
```

### 2. Alternative Menu Interface

```bash
[ -f "menu.sh" ] && rm menu.sh; curl -sSL -o menu.sh https://raw.githubusercontent.com/martinc1991/aztec-node-startup/main/menu.sh && chmod +x menu.sh && ./menu.sh
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

## 📖 Quick Reference Commands

### Remote Execution (Recommended)

**Main setup script:**

```bash
[ -f "aztec.sh" ] && rm aztec.sh; curl -sSL -o aztec.sh https://raw.githubusercontent.com/martinc1991/aztec-node-startup/main/aztec.sh && chmod +x aztec.sh && ./aztec.sh
```

**Alternative menu:**

```bash
[ -f "menu.sh" ] && rm menu.sh; curl -sSL -o menu.sh https://raw.githubusercontent.com/martinc1991/aztec-node-startup/main/menu.sh && chmod +x menu.sh && ./menu.sh
```

### Manual Docker Commands

**Check node logs:**

```bash
sudo docker logs -f --tail 100 $(docker ps -q --filter ancestor=aztecprotocol/aztec:latest | head -n 1)
```

**Stop all Aztec containers:**

```bash
sudo docker stop $(sudo docker ps -q --filter ancestor=aztecprotocol/aztec:latest)
```

**Remove Aztec containers:**

```bash
sudo docker rm $(sudo docker ps -a -q --filter ancestor=aztecprotocol/aztec:latest)
```

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
