# SimpleRoll 2.0

**SimpleRoll** is a lightweight, highly automated World of Warcraft addon designed to streamline loot distribution for guild runs using attendance/rank-based systems. Originally developed for **WipeMeBabyOneMoreTime** on Onyxia, its logic is fully compatible with strict guild loot rules, prioritizing ranks, handling ties, and seamlessly managing PuGs.

**Author:** zombik 
Discord: `@fthepopulation`

---

## ✨ Key Features
* **Two Distinct Loot Modes:** Choose between traditional `/rw` rolling (Sync) or a modern, click-based Perpetual Loot Board (Async).
* **Smart Sorting Engine:** Automatically sorts rolls by MS > SOS > OS, factoring in Guild Ranks, PuG thresholds, and Token priorities. 
* **Bulletproof Syncing:** If a player disconnects or joins late, the addon automatically queries the Raid Leader and rebuilds their missing history and board data.
* **JSON Exporting:** Silently logs all drops, winners, and rollers in the background for easy export after the raid.
* **Auto-Updater:** Includes a batch script that automatically pulls the newest version from GitHub and wipes old database files in seconds.

---

## 📥 Installation & Updating

**For Regular Raiders:**
1. Download the [Latest Release](https://github.com/dankoxd/SimpleRoll/releases/latest/download/SimpleRoll.zip).
2. Extract the `SimpleRoll` folder into your `Interface\AddOns\` directory.
3. **Before every raid:** Run the included **`update.bat`** file. This will automatically download the newest guild rank database, update your addon files, and clear your local cache so you are ready to raid.
	*(you can create a shortcut to this file and paste it to shell:startup or hook it to your WoW executable)*

**In-Game Commands:**
* Open the main window: `/sr` or `/simpleroll`
* Open the debug log: `/sr debug`

---

## 👑 Loot Master Guide

If you are a Raid Leader, Assistant, or Guild Officer (rank index 1 or lower), you automatically gain Admin privileges. 

### Raid Setup
1. Type **`/sr mode sync`** or **`/sr mode async`** to choose your loot distribution style. *(Note: Async mode requires the entire raid to have the addon installed).*
2. Open the Menu and click **Admin Tools** -> **Start New Raid** to wipe previous session data.
3. Open the **Raider List** and click **Scan** to import all present players. Mark your Tanks and Healers (for Token priority) and click **Sync** to broadcast the roster to the raid.

### Running the Loot (Sync Mode)
* Type `/rw roll [Item Link]` or `/rw roll 2x [Item Link]` to start a session.
* Raiders type `/roll` in chat. The addon captures the rolls, automatically flags late rolls, and sorts them by rank and spec.
* Click the **Crown Icon** to force a win, or the **Red Circle** to disable a troll roll.
* Click the **Announce** button (Megaphone) to broadcast the winners to the raid and save the data to History. *(Items must be announced to be saved in the JSON log).*

### Running the Loot (Async Perpetual Board)
* Hold **Alt + Left-Click** on items in your bag to push them to the Perpetual Loot Board.
* Raiders open their UI and click the visual buttons (MS/OS/SOS) to submit their rolls silently.
* Select an item on the board and click the **Crown Icon** next to a roller's name to award the item and broadcast it to the raid.
* Use the **Delete** or **Bank/DE** buttons to manage unwanted items.

---

## ⚙️ How the Sorting Engine Works
The addon's brain uses a strict hierarchy to organize rolls. It will never randomly sort players; it follows these exact steps:

1. **Spec Tier:** Main Spec (100) beats Shaman OS (101), which beats Off-Spec (99).
2. **The PuG Threshold:** If PuG outrolls everyone, he wins. If he outrolls only some of the people, it sets up a threshold.
3. **Guild Rank:** If multiple players qualify, the highest Guild Rank (e.g., Rank 0 > Rank 1) instantly wins, regardless of the numerical roll.
4. **Token Priority:** For tier tokens: Tanks > Healers > DPS.
5. **Numerical Roll:** If players are tied in Spec, Rank, and Role, the highest numerical roll wins.

---

## 📊 Data Management
* **Loot History & Table:** View past rolls and explicitly reassign winners if a mistake was made. Reassigning a winner retroactively updates the JSON log.
* **JSON Exporting:** Open the Menu -> Admin Tools -> Export JSON. This generates a clean text block of every item awarded, the reason it was awarded, and every player who rolled on it. 
* **Safe Storage:** No data is ever lost unless you manually click "Wipe All History & Data" in the Settings menu or accept the wipe prompt when joining a new raid.
