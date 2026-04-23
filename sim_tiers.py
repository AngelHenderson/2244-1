def splitBase1000(n):
    out = []
    while n > 0:
        out.append(n % 1000)
        n //= 1000
    return out

def label(chunks):
    hi = len(chunks) - 1
    if hi == 0: return str(chunks[0])
    if hi == 1:
        total = chunks[1]*1000 + chunks[0]
        if total < 10000: return str(total)
        return f"{chunks[1]}K"
    if hi == 2: return f"{chunks[2]}M"
    if hi == 3: return f"{chunks[3]}B"
    
    tierIndex = hi - 3
    # excel letters
    # 1 -> a, 26 -> z, 27 -> aa
    def excelLetters(index):
        i = index
        res = ""
        while i > 0:
            rem = (i - 1) % 26
            res = chr(97 + rem) + res
            i = (i - 1) // 26
        return res
    return f"{chunks[hi]}{excelLetters(tierIndex)}"

start = 2
chunks = splitBase1000(start)

tier_counts = {}

for step in range(1, 818):
    carry = 0
    for i in range(len(chunks)):
        v = chunks[i] * 2 + carry
        chunks[i] = v % 1000
        carry = v // 1000
    if carry > 0:
        chunks.append(carry)
    
    l = label(chunks)
    import re
    m = re.match(r'\d+([a-zA-Z]+)', l)
    if m:
        letter = m.group(1)
        tier_counts[letter] = tier_counts.get(letter, 0) + 1

for k, v in list(tier_counts.items())[:5]:
    print(k, v)
print("...")
for k, v in list(tier_counts.items())[-5:]:
    print(k, v)

# Let's find any tiers that don't have exactly 10 steps.
non_10 = {k: v for k, v in tier_counts.items() if v != 10}
print("Tiers without 10 steps:")
for k, v in non_10.items():
    print(k, v)

