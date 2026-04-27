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

start = 2
chunks = splitBase1000(start)

for step in range(1, 818):
    carry = 0
    for i in range(len(chunks)):
        v = chunks[i] * 2 + carry
        chunks[i] = v % 1000
        carry = v // 1000
    if carry > 0:
        chunks.append(carry)
    
    l = label(chunks)
    if l == "1y": print("1y is step", step)
    if l == "994y": print("994y is step", step)
    if l == "1z": print("1z is step", step)
    if l == "1aa": print("1aa is step", step)
    if l == "1al": print("1al is step", step)

