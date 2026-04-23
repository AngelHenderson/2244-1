import re

content = open('/Users/angelhendersonjr/Development/2244/Packages/GameUI/Sources/GameUI/Leaderboard/LeaderboardClient.swift').read()
match = re.search(r'static let allMilestones:\s*\[String\] = \[(.*?)\]', content, re.DOTALL)
if match:
    arr_str = match.group(1)
    items = re.findall(r'"([^"]+)"', arr_str)
    
    expected = []
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
        def excelLetters(index):
            i = index
            res = ""
            while i > 0:
                rem = (i - 1) % 26
                res = chr(97 + rem) + res
                i = (i - 1) // 26
            return res
        return f"{chunks[hi]}{excelLetters(tierIndex)}"
    chunks = splitBase1000(2)
    expected.append(str(2))
    for step in range(1, 818):
        carry = 0
        for i in range(len(chunks)):
            v = chunks[i] * 2 + carry
            chunks[i] = v % 1000
            carry = v // 1000
        if carry > 0: chunks.append(carry)
        expected.append(label(chunks))
    
    for i in range(min(len(items), len(expected))):
        if items[i] != expected[i]:
            print(f"Difference at index {i}: LeaderboardClient has '{items[i]}', expected '{expected[i]}'")
            break

