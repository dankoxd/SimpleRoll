# SimpleRoll
This is an addon that helps organizing guild runs that use attendance system.
Originally made for WMBOMT on Onyxia. Logic fully compatible with loot rules.

made by zombik
discord: @fthepopulation

## Usage

[Download Here](https://github.com/dankoxd/SimpleRoll/releases/download/1.0/SimpleRoll.zip)
 1. **Import** database of points into the SimpleRollDB.lua file 
 *(paste it between the [[ brackets ]] )*
 2. Addon automatically opens in-game, or you can type **/sr** or **/simpleroll**
 3. If you want to roll an item, you must do "**/rw roll [item]**"
4. The rolls will start to show. You must announce a winner via **"Announce Winner"**
5. For new rolls, just **repeat** from step 3.

## Functions, Info

 - If a player is not a Raid Leader or don't have Assistance, he can't announce or make Raider List.
 - Roll Window
	 - First roll of each player counts, duplicite rolls are ignored.
	 - You can tick "Raw" to disregard Ranks.
	 - If someone rolls and wins after announce, you must announce again
	 - Quantity rolls e.g "*/rw roll 2x[item]*" *(extra spaces or order doesn't matter)*
	 - Forced Win for token prio or other rules
 - Raider List
	 - Scan - imports all present people in the raid
	 - Drag & Drop players from groups
	 - Add players manually by double-clicking an empty space
	 - Remove players manually by right-clicking
	 - Export - a text summary of all players to give points to
 - Reset Rolls button in case something breaks.
 - Rolling window, Raider List and Loot History are saved and not lost after /reload or restart.
