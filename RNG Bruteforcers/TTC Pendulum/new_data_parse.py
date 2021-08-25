import json

data = {}
good_rng = []

with open("new_data.txt", "r") as f:
    data = json.load(f)

for rng in data.keys():
    if data[rng]["sc"] == 6037: # 6040 => 10.87
        yaw = int(data[rng]["yaw"])
        # display the cog wk yaw for a given squish cancel frame
        # and the difference to the yaw used for my 10.87
        # ideal yaw is somewhere between 3000 and 6000
        print(f'RNG: %d, YAW: %d (%d)' % (int(rng), yaw, yaw - 4141))
        good_rng.append(str(rng) + '\n')

with open("new_viable_rng.txt", "w") as f:
    f.writelines(good_rng)


