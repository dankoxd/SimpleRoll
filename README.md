# SimpleRoll
This is an addon that helps organizing guild runs that use attendance system.
Originally made for WMBOMT on Onyxia. Logic fully compatible with loot rules.

made by zombik
discord: @fthepopulation

## Usage
[Download Here](https://github.com/dankoxd/SimpleRoll/releases/download/1.2/SimpleRoll.zip)
### Regular raider
 1. **Run update.bat** to download/update current rank database *(you can hook it to WoW.exe or copy it into shell:startup folder)*
 2. Addon automatically opens in-game, or you can type **/sr** or **/simpleroll**
 3. Done. When you join a raid, the addon asks if you want to delete your roll database

### Loot Master
 4. Type **/sr mode sync** or **/sr mode async** to choose the mode *(async mode requires everyone to have the addon)*
 5. Start a New Raid in Admin Menu
 6. After you gather players, go to Raider List - Scan and mark players with their role *(DPS/Heal/Tank)*
 7. In sync mode, do /rw roll [item]  *(/rw roll 2x [item], /rw [item])*
 8. In async mode, Alt + L.Click to add items from your bags to populate Loot Board
 9. At the end of the raid, export JSON data

### Functions, Info
 - Addon Privileges, RL and assistants have access to everything.

 - Main Roll Window
	 - First roll of each player counts, duplicite rolls are ignored.
	 - You can tick "Raw" to disregard Ranks
     - Knows all guild loot rules besides BiS>MS
     - Ability to delete player rolls
     - Ability to Force a Win
 	 - Optional Timer
     
 - Raider List
	 - Works just like the WoWs Raid window.
	 - Scan - imports all present people in the raid group
	 - Add players manually by double-clicking an empty space
	 - Remove players manually by right-clicking
	 - Export - a text summary of all players to give points to
     - Sync to send your Raider List for everyone 

 - Loot History, Loot Table
	- Works the same, displays differently
    - You can reassign winners historically
 
 - No data will be lost unless you delete your data in Settings
 - If you got disconnected or joined late, the addon will gather all the data you don't have
