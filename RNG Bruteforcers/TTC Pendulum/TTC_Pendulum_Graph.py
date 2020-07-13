import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from mpl_toolkits.mplot3d import axes3d
from math import sin,cos,radians
import json

HIGHLIGHTED_RNG = 63770

mode = 1 # cog wk angle vs pendulum angle @ frame 250
mode = 2 # cog wk angle vs tj frame

# colours
HIGHLIGHTED_COLOUR = [0,1,0]
LEFT_FAST = [0,0,1] # blue
LEFT_SLOW = [0,0.6,1] # turquoise
STOPPED = [0.5,0.5,0.5] # gray
RIGHT_SLOW = [1,0.5,0] # orange
RIGHT_FAST = [1,0,0] # red

# accel has 2 possible values: 13 or 42
def pickColour(speed, accel):
    if speed == 0:
        return STOPPED
    elif speed < 0 and accel == 13:
        return LEFT_FAST
    elif speed < 0 and accel == 42:
        return LEFT_SLOW
    elif speed > 0 and accel == 13:
        return RIGHT_SLOW
    elif speed > 0 and accel == 42:
        return RIGHT_FAST

# parse the data
data = []
tj_frames = {}

with open("ttc rng data - r2.txt") as file:
    data = json.load(file)
for info in data:
    tj_frames[info["rng"]] = info["tj"]
    
with open("ttc rng data.txt") as file:
    data = json.load(file)
    
tjs = []
wk_angles = []
colours = []
RNG = []
angles = []
for item in data:
    if mode == 2 and tj_frames[item["rng"]] == 0: continue
    angles.append(item["angle"])
    wk_angles.append(item["wk_angle"])
    RNG.append(str(item["rng"]))
    tjs.append(tj_frames[item["rng"]])
    if item["rng"] == HIGHLIGHTED_RNG:
        colours.append(HIGHLIGHTED_COLOUR)
    else:
        colours.append(pickColour(item["speed"], item["accel"]))

# arrange the data
fig,ax,sc = 0,0,0
fig,ax = plt.subplots()
ax.set_ylabel("Wallkick Angle")
if mode == 1:
    ax.set_title("TTC Pendulum Angle vs Mario's Wallkick Angle\n")
    sc = plt.scatter(angles, wk_angles, c=colours, s=7)
    ax.set_xlabel("Pendulum Angle")
elif mode == 2:
    ax.set_title("TTC TJ Frame vs Mario's Wallkick Angle\n")
    sc = plt.scatter(tjs, wk_angles, c=colours, s=7)
    ax.set_xlabel("Approximate TJ Frame")

# legend
A = mpatches.Patch(color=LEFT_FAST, label='Speed < 0 (fast)')
B = mpatches.Patch(color=LEFT_SLOW, label='Speed < 0 (slow)')
C = mpatches.Patch(color=STOPPED, label='Speed = 0')
D = mpatches.Patch(color=RIGHT_SLOW, label='Speed > 0 (slow)')
E = mpatches.Patch(color=RIGHT_FAST, label='Speed > 0 (fast)')
plt.legend(handles=[A,B,C,D,E],
           bbox_to_anchor=(1.01, 0.31),
           loc='upper left',
           ncol=1)
plt.tight_layout()

# annotations with hovering event from stackoverflow:
#   https://stackoverflow.com/questions/7908636/
annot = ax.annotate("", xy=(0,0), xytext=(20,20),textcoords="offset points",
                    bbox=dict(boxstyle="round", fc="w"),
                    arrowprops=dict(arrowstyle="->"))
annot.set_visible(False)

def update_annot(ind):
    annot.xy = sc.get_offsets()[ind["ind"][0]]
    text = "RNG = " + ", ".join([RNG[n] for n in ind["ind"]])
    annot.set_text(text)

def hover(event):
    if event.inaxes == ax:
        cont, ind = sc.contains(event)
        if cont:
            update_annot(ind)
            annot.set_visible(True)
            fig.canvas.draw_idle()
        elif annot.get_visible():
            annot.set_visible(False)
            fig.canvas.draw_idle()

fig.canvas.mpl_connect("motion_notify_event", hover)

plt.show()
