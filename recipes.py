import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = sys.argv[1] if len(sys.argv) > 1 else r'C:\Projects\Linked-Inn\docs\data-viz\tables\recipes_forever.json'
OUT = os.path.join(HERE, 'LifeOnAzeroth_Market', 'Recipes.lua')
PROFS = ['Alchemy', 'Blacksmithing', 'Cooking', 'Enchanting', 'Engineering', 'First Aid', 'Leatherworking', 'Mining', 'Tailoring']
KEY = {'alchemy': 0, 'blacksmithing': 1, 'cooking': 2, 'enchanting': 3, 'engineering': 4, 'firstaid': 5, 'leatherworking': 6, 'mining': 7, 'tailoring': 8}

data = json.load(open(SRC, encoding='utf8'))
rows = []
for spell, r in sorted(data.items(), key=lambda kv: int(kv[0])):
    reag = [x.split(':') for x in (r.get('r') or '').split(';') if x]
    if not reag or r.get('p') not in KEY:
        continue
    item = int(r.get('item') or 0)
    icon = 0 if item else int(r.get('i') or 0)
    rg = ';'.join('%d:%d' % (int(a), int(b)) for a, b in reag)
    rows.append('"%d %d %d %d %d %s"' % (item, int(spell), KEY[r['p']], int(r.get('skill') or 0), icon, rg))

lua = 'local ADDON, NS = ...\n\nNS.PROFS = { %s }\n\nNS.RECIPES = {\n%s\n}\n' % (
    ', '.join('"%s"' % p for p in PROFS), ',\n'.join(rows))
open(OUT, 'w', encoding='utf8', newline='\n').write(lua)
print('%d recipes, %d KB' % (len(rows), os.path.getsize(OUT) // 1024))
