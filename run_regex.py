import re

with open('Packages/GameApp/Sources/GameApp/ParityModels.swift', 'r') as f:
    code = f.read()

# TRUTHFUL COMPETITIVE

# 1. Milestone Out Of Reach
code = re.sub(
    r'replies\.append\(contentsOf: \[\n\s+"If you can\'t even get to \\\(m\.name\).*?"You\'re not built for \\\(m\.name\).*?\]\)',
    r'replies.append(Self.getOneUpBrag(metric: "milestone", lower: m.name, higher: higherM))',
    code,
    flags=re.DOTALL
)

# 2. Milestone Weighted
code = re.sub(
    r'let weightedReplies: \[\(String, Double\)\] = \[\n\s+\("Only at \\\(m\.name\)\?.*?replies\.append\(selected\)',
    r'replies.append(Self.getOneUpBrag(metric: "milestone", lower: m.name, higher: higherM))',
    code,
    flags=re.DOTALL
)

# 3. Time Out Of Reach
code = re.sub(
    r'replies\.append\(contentsOf: \[\n\s+"If you can\'t even get to \\\(posterTime\).*?"Don\'t hurt yourself trying to reach my \\\(myTimeStr\)\."\n\s+\]\)',
    r'replies.append(Self.getOneUpBrag(metric: "time", lower: posterTime, higher: myTimeStr))',
    code,
    flags=re.DOTALL
)

# 4. Time Regular
code = re.sub(
    r'replies\.append\("Celebrating \\\(posterTime\)\? I easily reached \\\(myTimeStr\)\."\)\n\s+replies\.append\("You think.*?"I don\'t even acknowledge \\\(posterTime\).*?"\)',
    r'replies.append(Self.getOneUpBrag(metric: "time", lower: posterTime, higher: myTimeStr))',
    code,
    flags=re.DOTALL
)

# 5. Streak Out Of Reach
code = re.sub(
    r'replies\.append\(contentsOf: \[\n\s+"If you can\'t even get to \\\(num\) days.*?"Keep trying with \\\(num\) days.*?"\n\s+\]\)',
    r'replies.append(Self.getOneUpBrag(metric: "streak", lower: "\\(num)", higher: "\\(higherNum)"))',
    code,
    flags=re.DOTALL
)

# 6. Streak Regular
code = re.sub(
    r'replies\.append\("Only \\\(num\) days\?.*?"Don\'t even acknowledge that double-digit streak.*?"\)',
    r'replies.append(Self.getOneUpBrag(metric: "streak", lower: "\\(num)", higher: "\\(higherNum)"))',
    code,
    flags=re.DOTALL
)

# 7. HOF Out Of Reach
code = re.sub(
    r'replies\.append\(contentsOf: \[\n\s+"If you can\'t even get to \\\(infCount\) infinities.*?"If \\\(infCount\) is impossible for you.*?"\n\s+\]\)',
    r'replies.append(Self.getOneUpBrag(metric: "hof", lower: "\\(infCount)", higher: "\\(myCount)"))',
    code,
    flags=re.DOTALL
)

# 8. HOF Regular
code = re.sub(
    r'replies\.append\("Only \\\(infCount\) infinities\?.*?"I left \\\(infCount\) infinities in the dust.*?"\)',
    r'replies.append(Self.getOneUpBrag(metric: "hof", lower: "\\(infCount)", higher: "\\(myCount)"))',
    code,
    flags=re.DOTALL
)


# CONTEXTUAL

# 1. Milestone Weighted Lower Brag
code = re.sub(
    r'let weightedReplies: \[\(String, Double\)\] = \[\n\s+\("I easily passed your \\\(cM\.name\).*?replies\.append\(selected\)',
    r'replies.append(Self.getOneUpBrag(metric: "milestone", lower: cM.name, higher: higherM))',
    code,
    flags=re.DOTALL, count=1 # Only first one! (Lower brag)
)

# 2. Milestone Weighted Regular (wantsBetter branch)
code = re.sub(
    r'let weightedReplies: \[\(String, Double\)\] = \[\n\s+\("I always do better.*?replies\.append\(selected\)',
    r'replies.append(Self.getOneUpBrag(metric: "milestone", lower: mName, higher: higherM))',
    code,
    flags=re.DOTALL
)

# 3. Milestone Regular array in `else`
code = re.sub(
    r'replies\.append\(contentsOf: \[\n\s+"I am ahead of your \\\(mName\).*?"It\'s over for you.*?"\n\s+\]\)',
    r'replies.append(Self.getOneUpBrag(metric: "milestone", lower: mName, higher: higherM))',
    code,
    flags=re.DOTALL
)

# 4. Time Lower Brag
code = re.sub(
    r'replies\.append\(contentsOf: \[\n\s+"I easily passed your \\\(cTimeStr\).*?"I blew past your \\\(cTimeStr\).*?"\n\s+\]\)',
    r'replies.append(Self.getOneUpBrag(metric: "time", lower: cTimeStr, higher: myTimeStr))',
    code,
    flags=re.DOTALL
)

# 5. Time Regular array
code = re.sub(
    r'replies\.append\(contentsOf: \[\n\s+"I am ahead of your \\\(posterTime\).*?"\\\(posterTime\) is a joke.*?"\n\s+\]\)',
    r'replies.append(Self.getOneUpBrag(metric: "time", lower: posterTime, higher: higherTime))',
    code,
    flags=re.DOTALL
)

# 6. Streak Lower Brag
code = re.sub(
    r'replies\.append\(contentsOf: \[\n\s+"You\'re bragging about \\\(cN\) days\?.*?"I left \\\(cN\) days in the dust.*?"\n\s+\]\)',
    r'replies.append(Self.getOneUpBrag(metric: "streak", lower: "\\(cN)", higher: "\\(rN)"))',
    code,
    flags=re.DOTALL
)

# 7. Streak Regular array
code = re.sub(
    r'replies\.append\(contentsOf: \[\n\s+"I am ahead of your \\\(numStr\) days.*?"Don\'t bother trying for \\\(higherNum\) days.*?"\n\s+\]\)',
    r'replies.append(Self.getOneUpBrag(metric: "streak", lower: "\\(num)", higher: "\\(higherNum)"))',
    code,
    flags=re.DOTALL
)

# 8. HOF Lower Brag
code = re.sub(
    r'replies\.append\(contentsOf: \[\n\s+"You\'re bragging about \\\(cN\)\?.*?"I left \\\(cN\) in the dust.*?"\n\s+\]\)',
    r'replies.append(Self.getOneUpBrag(metric: "hof", lower: "\\(cN)", higher: "\\(rN)"))',
    code,
    flags=re.DOTALL
)

# 9. HOF Regular array
code = re.sub(
    r'replies\.append\(contentsOf: \[\n\s+"I am ahead of your \\\(assumedNum\) entries.*?"Don\'t bother trying for \\\(higherNum\).*?"\n\s+\]\)',
    r'replies.append(Self.getOneUpBrag(metric: "hof", lower: "\\(assumedNum)", higher: "\\(higherNum)"))',
    code,
    flags=re.DOTALL
)

with open('Packages/GameApp/Sources/GameApp/ParityModels.swift', 'w') as f:
    f.write(code)
print("Regex replacement completed!")
