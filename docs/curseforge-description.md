# CurseForge page (kept in sync by hand)

Paste into authors.curseforge.com → project → Description (Markdown mode).
Images load from the public GitHub repo (`media/`), so replacing a file there
with the same name updates the page.

**Summary (one line):**

> Prices, trends and item history for your own auction house in WoW Forever, right inside the game.

**Description:**

```markdown
# Life on Azeroth: Market

The auction house market from [lifeonazeroth.com](https://lifeonazeroth.com/#economy), inside **WoW Forever**.

Is Iron Ore cheap right now, or did everyone just undercut each other this morning? Are herbs climbing all week? Is that green sword worth listing, or will it sit there for two days? Open the Market and you'll know before you post.

**Prices update every hour.** Every auction house in every region is read once an hour, so you're looking at real prices and real history, not a guess from the last time you checked the AH. The last three days are kept hour by hour, and older history is kept at a coarser step so the data stays small.

> **Found a bug?** If something looks off, please [open an issue](https://github.com/sanredz/LifeOnAzeroth-Addon/issues).

![The Market: indexes on the left, a chart comparing them, and the hover tooltip](https://raw.githubusercontent.com/sanredz/LifeOnAzeroth-Addon/main/media/market.png)

## The Market

- **Indexes** work like a stock index. Each one follows a group of items from the day tracking began, starting at 100: the whole market, trade goods, ore and bars, cloth, herbs, potions, green gear by level and more. 70 means prices are about 30% lower than when it started.
- **Trends at a glance:** every index has a small trend line and its change over the time range you pick on the chart: the last 6 hours, a day, a week, a month or all time. The prices behind them update every hour.
- **Compare up to five** indexes or items on one chart. Hover the chart to see every line's value at that hour.
- **Search any item** seen on the auction house and get its typical price, cheapest listing and 24-hour change as you type.
- **Your picks stay put.** The chart remembers what you were watching the next time you log in.
- **Prices in item tooltips:** hover anything in your bags, the bank, loot or chat and see its typical price on your auction house, and the price of the whole stack. `/market tooltip` turns it off.

## Every item has its own page

Click any item to see:

- **Typical price** (the middle of what's listed, so one silly auction can't throw it off) and the **cheapest** listing right now.
- **How many auctions** are up, how many items are for sale and what a vendor pays for it.
- **Price history** with both lines, plus a bar chart of how many were for sale each hour.
- **The price in every region**, so you can see that Cerulean Dye goes for 31s in Europe and 54s in Taiwan.
- **Similar items** on the auction house right now, one click away.
- The game's own tooltip on the icon, and **Shift-click** to link the item in chat.

![An item page with price history and prices in every region](https://raw.githubusercontent.com/sanredz/LifeOnAzeroth-Addon/main/media/item.png)

## Your own auction house

Every ruleset has three auction houses, Alliance, Horde and the neutral Blackwater, and they have very different prices. The Market shows the prices on **your** auction house, picked from the realm you're on and your character's faction, so the numbers match what you see when you open the AH. You can switch to any other ruleset or house with one click.

## Getting prices into the game

Addons can't go online, so a small companion app does that part.

1. Download **LifeOnAzerothCompanion.exe** from the [latest release on GitHub](https://github.com/sanredz/LifeOnAzeroth-Addon/releases/latest) and run it. There's nothing to install.
2. It finds your game folder and downloads fresh prices **every hour** into a small **Life on Azeroth: Data** addon. Keep that one enabled.
3. Type `/reload` in game, or **Shift-click** the coin by your minimap, and the newest prices are loaded.

The app sits quietly in the tray, can start with Windows and never pops up while you play. Windows may say it's unrecognised the first time: click **More info**, then **Run anyway**.

![The companion app](https://raw.githubusercontent.com/sanredz/LifeOnAzeroth-Addon/main/media/companion.png)

## Usage

Open the Market with `/market`, `/loa` or the coin by your minimap. `/market minimap` hides or shows the minimap button.

## What it touches

The addon only draws its own window. It doesn't change the auction house, Blizzard's UI or anything else in your game, and it never sends anything.

The companion app only talks to lifeonazeroth.com, and only writes to the Life on Azeroth folders in your AddOns folder. The one thing it reads is your game's region setting, so it knows which prices to fetch. It doesn't touch your account, your characters or anything else on your PC.

Source and issues: [github.com/sanredz/LifeOnAzeroth-Addon](https://github.com/sanredz/LifeOnAzeroth-Addon)
```
