import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from mpl_toolkits.mplot3d import axes3d
from math import sin,cos,radians
import json

MODE = 2 # number of dimensions. Only supports 2 or 3

L = 770 # length of pendulum
short_to_deg = 360 / 2**16

data = []
with open("ttc rng data.txt") as file:
    data = json.load(file)

# accel has 2 possible values: 13 or 42
LEFT_FAST = [0,0,1] # blue
LEFT_SLOW = [0,0.6,1] # turquoise
STOPPED = [0.5,0.5,0.5] # gray
RIGHT_SLOW = [1,0.5,0] # orange
RIGHT_FAST = [1,0,0] # red
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

# Parse the data
x = []
y = []
z = []
colours = []
RNG = []
for i in range(len(data)):
    theta = radians(short_to_deg * data[i]["angle"])
    x.append(L * sin(theta))
    y.append(L - L * cos(theta))
    z.append(data[i]["wk_angle"])
    colours.append(pickColour(data[i]["speed"], data[i]["accel"]))
    RNG.append(str(data[i]["rng"]))

# Arrange the data
fig,ax,sc = 0,0,0
if MODE == 2:
    fig,ax = plt.subplots()
    sc = plt.scatter(x, z, c=colours, s=7)
elif MODE == 3:
    fig = plt.figure()
    ax = fig.add_subplot(111, projection='3d')
    sc = ax.scatter(x,z,y,c=colours)
    ax.set_zlabel("Pendulum Y")

ax.set_xlabel("Pendulum X")
ax.set_ylabel("Wallkick Angle")

# Legend
ax.set_title("TTC Pendulum Position vs Mario's Wallkick Angle\n")
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

# Annotations with hovering event from stackoverflow:
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
