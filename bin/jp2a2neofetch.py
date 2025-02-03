import sys

# edit this line to adjust your palette
palette = (1, 4, 5, 6, 7)

for line in sys.stdin:
    converted = line.replace("\x1b[0m", "")
    for i in range(1, 8):
        if i in palette:
            replacement = "${c" + str(palette.index(i) + 1) + "}"
        else:
            replacement = ""
        converted = converted.replace(f"\x1b[3{i}m", replacement)
    print(converted[:-1])
