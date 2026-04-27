import re

content = open('/Users/angelhendersonjr/Development/2244/Packages/GameUI/Sources/GameUI/Theme.swift').read()

print(re.search(r'func colorForStep.*?\}', content, re.DOTALL).group(0))
