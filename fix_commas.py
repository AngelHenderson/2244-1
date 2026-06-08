import re

path = "/Users/angelhendersonjr/Development/2244/Packages/GameApp/Sources/GameApp/ParityModels.swift"
with open(path, "r") as f:
    content = f.read()

content = content.replace('"I might be lower right now, but"', '"I might be lower right now."')
content = content.replace('"You\'re ahead for now, but"', '"You\'re ahead for now."')
content = content.replace('"Enjoy the lead while it lasts,"', '"Enjoy the lead while it lasts."')

with open(path, "w") as f:
    f.write(content)
print("Replaced commas with periods!")
