import wafel
from RNG import RNG
import json

# note: pendulum star rng value: 33795

start_frame = 5805
cog_wk_frame = 5990
end_frame = 6060

PENDULUM_SLOT = 8 # Memory Processing order in stroop, but 0 indexed

TJ_GOAL_ANGLE = 6300 # once the pendulum passes this angle the tj will tie the old record
SQUISH_CANCEL_ANGLE = 3208 # the frame in idle is: 3507

data = {}

game = wafel.Game('D:\\Programming\\Python\\wafel\\libsm64\\sm64_jp.dll')
power_on = game.save_state()
level_start = power_on
m64 = wafel.load_m64('./ttc_pendulum_from_start.m64')

def set_inputs(game, inputs):
    game.write('gControllerPads[0].button', inputs.buttons)
    game.write('gControllerPads[0].stick_x', inputs.stick_x)
    game.write('gControllerPads[0].stick_y', inputs.stick_y)

def GetPendulumAccel():
    return game.read("gObjectPool[8].oTTCPendulumAngleAccel")

def GetPendulumAngle():
    return game.read("gObjectPool[8].oTTCPendulumAngle")

def GetMarioYaw():
    yaw = game.read('gMarioState.faceAngle')[1]
    return (yaw + 65536) % 65536


# simple way to display progress every so often
previous_rng = 0
def display_rng(rng):
    global previous_rng
    if (rng - previous_rng) > 1000:
        print(rng)
        previous_rng = rng - (rng % 1000)


# make a savestate at level start and ensure inputs work on the proper RNG
for frame in range(len(m64[1])):
    set_inputs(game, m64[1][frame])
    game.advance()
    if frame == start_frame:
        level_start = game.save_state()
        game.write("gRandomSeed16", 33795) # RNG that works with inputs
    elif frame == cog_wk_frame:
        assert(game.read("gMarioState.action") == game.constant("ACT_WALL_KICK_AIR"))
        assert(game.read('gMarioState.pos')[1] == -1736.00)
        assert(GetMarioYaw() == 4751)
    elif frame == 6006:
        assert(GetPendulumAccel() == 42.0)
        assert(GetPendulumAngle() == 3728.0)
        assert(GetMarioYaw() == 44421)
    
        
print("brute forcing start...")

for value in RNG():
    display_rng(value)
    game.load_state(level_start)
    game.write("gRandomSeed16", value)
    
    data[value] = {
        "sc": 99999, # arbitrary invalid values that can be filtered out
        "tj": 99999,
        "yaw": 99999
    }
    
    for frame in range(start_frame, end_frame):
        set_inputs(game, m64[1][frame + 1])
        game.advance()

        if frame == cog_wk_frame:
            #if game.read("gMarioState.action") != game.constant("ACT_WALL_KICK_AIR"):
                #break
            y = game.read('gMarioState.pos')[1]
            if -1800 < y < 0: # y >= 2253 in castle
                data[value]["yaw"] = GetMarioYaw()
                #print("RNG:", value, "WK YAW:", data[value]["yaw"])
            else:
                break

        elif frame > cog_wk_frame:
            if GetPendulumAngle() == SQUISH_CANCEL_ANGLE:
                data[value]["sc"] = frame
                #print("RNG:", value, "Squish Cancel:", frame)
                
            elif GetPendulumAngle() >= TJ_GOAL_ANGLE:
                data[value]["tj"] = frame
                break

with open('new_data.txt', 'w') as f:
    f.write(json.dumps(data, indent = 4))

