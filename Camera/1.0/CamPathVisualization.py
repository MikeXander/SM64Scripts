import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from mpl_toolkits.mplot3d import axes3d
import json

'''
    Points
    x,y,z: coordinates in 3D space (y = height)
    vx,vy,vz: the velocity of the camera at that point
    f: the frame you want to arrive at the point
    d: the duration it takes to arrivate at that point (only for freeze frames)
'''
def point(x, y, z, vx, vy, vz, f, d = 0):
    return {
        "pos": [x, y, z],
        "vel": [vx, vy, vz],
        "frame": f,
        "duration": d
    }

points = [ # VCutM Points
    point(-2150, -2600, -4150, 10, 0, -50, 375),
    point(-2000, -2000, -5900, 20, 10, -40, 433),
    point(-2000, -2000, -5900, -90, -30, -40, 434),
    point(-1000, -1800, -7000, 50, 20, 10, 445),
    point(-1000, -1800, -7000, 50, -10, -20, 446),
    point(1500, -100, -7000, 40, 0, 20, 505),
    point(2500,  -800, -6900, 60, 10, 5, 530),
    point(3300, 0, -6700, 50, 0, 10, 549),
    point(4900, 300, -5300, -15, 50, -10, 582)
]

# Curvefit math
# Source: https://stackoverflow.com/questions/4362498/curve-fitting-points-in-3d-space
Tf = 0

a = [0,0,0]
def fa(X0, V0, Xf, Vf):
    global Tf
    return (6 * (Tf*Tf*V0 + Tf*Tf*Vf + 2*Tf*X0 - 2*Tf*Xf)) / (Tf*Tf*Tf*Tf)

b = [0,0,0]
def fb(X0, V0, Xf, Vf):
    global Tf
    return (2 * (-2*Tf*Tf*Tf*V0 - Tf*Tf*Tf*Vf - 3*Tf*Tf*X0 + 3*Tf*Tf*Xf)) / (Tf*Tf*Tf*Tf)

def fx(a, b, t, X0, Xf):
    global Tf
    return (3*b*t*t*Tf + a*t*t*t*Tf - 3*b*t*Tf*Tf - a*t*Tf*Tf*Tf - 6*t*X0 + 6*Tf*X0 + 6*t*Xf) / (6*Tf)

# p1, p2 = {pos = {n,n,n}, vel = {n,n,n}, frame = n}
# duration = the time between each point
def getPositionFunction(p1, p2, duration):
    global Tf, a, b
    Tf = duration
    for i in range(3):
        a[i] = fa(p1["pos"][i], p1["vel"][i], p2["pos"][i], p2["vel"][i])
        b[i] = fb(p1["pos"][i], p1["vel"][i], p2["pos"][i], p2["vel"][i])
    return lambda frame: [fx(a[i], b[i], frame - p1["frame"], p1["pos"][i], p2["pos"][i]) for i in range(3)]



# additional functions for testing
def vel(p1, p2):
    return [p2[i] - p1[i] for i in range(3)]
'''
print(vel(
    [5, -2128, -1065],
    [22.32684100115744, -2110.012550636574, -1081.908890335648]
))
'''

def printPath(p1, p2):
    if p2["duration"] > 0: p2["frame"] += p2["duration"]
    position = getPositionFunction(p1, p2, p2["frame"] - p1["frame"])
    for i in range(p2["frame"] - p1["frame"]):
        x,y,z = position(i + p1["frame"])
        frame = i + p1["frame"]
        vx,vy,vz = vel(p2["pos"], position(i + p1["frame"]))
        if i < p2["frame"] - p1["frame"] - 1:
            vx,vy,vz = vel(position(i + p1["frame"] + 1), position(i + p1["frame"]))
        print('point(%1.1f, %1.1f, %1.1f, %1.1f, %1.1f, %1.1f, %d)' % (x,y,z,vx,vy,vz,frame))
'''
printPath(
    point(3300, 0, -6700, 50, 0, 10, 549),
    point(4900, 300, -5300, -15, 50, -10, 582)
)
'''

# given 2 consecutive points, inserts 2 more
def smoothTransition(p1, p2):
    pos = getPositionFunction(p1, p2, p2["frame"] - p1["frame"])
    p1_1 = {
        "pos": pos(p2["frame"] - 5),
        "vel": vel(pos(p2["frame"] - 5), pos(p2["frame"] - 4)),
        "frame": p2["frame"] - 1,
        "duration": 0
    }
    p1_2 = {
        "pos": pos(p2["frame"] - 1),
        "vel": vel(pos(p2["frame"] - 1), pos(p2["frame"])),
        "frame": p2["frame"] - 1,
        "duration": 2
    }

    global points
    new_points = []
    inserted = False
    for point in points:
        if point["frame"] == p2["frame"] and not inserted:
            new_points.append(p1_1)
            new_points.append(p1_2)
            new_points.append(p2)
            inserted = True
        else:
            new_points.append(point)
    points = []
    for p in new_points:
        print("point(" + str(p["pos"][0]) + ", " + str(p["pos"][1]) + ", " + str(p["pos"][2]) + ", " + str(p["vel"][0]) + ", " + str(p["vel"][1]) + ", " + str(p["vel"][2]) + ", " + str(p["frame"]) + ", " + str(p["duration"]) + "),")
        points.append(p)
#smoothTransition(points[0], points[1])


# setup graph
fig,ax,sc = 0,0,0
fig = plt.figure()
ax = fig.add_subplot(111, projection='3d')
ax.set_xlabel("Z") # these are weird to match the game
ax.set_ylabel("X")
ax.set_zlabel("Y")

x = []
y = []
z = []
colours = []
frames = []

# add point to plot
def add_point(point, colour, frame):
    global x, y, z
    for i in range(3):
        [x, y, z][i].append(point[i])
    colours.append(colour)
    frames.append(str(frame))


# main loop to add cam path
for i in range(len(points) - 1):
    p1 = points[i]
    p2 = points[i + 1]
    if p1["frame"] == p2["frame"]:
        position = getPositionFunction(p1, p2, p2["duration"])
        for j in range(p2["duration"]):
            add_point(position(j + p1["frame"]), "orange", p1["frame"])
    else:
        position = getPositionFunction(p1, p2, p2["frame"] - p1["frame"])
        for frame in range(p1["frame"], p2["frame"]):
            add_point(position(frame), "orange", frame)

# highlight the points
for point in points:
    add_point(point["pos"], "blue", point["frame"])

# add Mario's path from file
data = []
with open("MarioPos.txt") as file:
    data = json.load(file)

HIGHLIGHT_FRAMES = [156, 295]
for point in data:
    colour = "black" if point[3] in HIGHLIGHT_FRAMES else "red"
    add_point(point, colour, point[3])

sc = ax.scatter(z,x,y,c=colours)


# show frame numbers
# annotations with hovering event from stackoverflow:
#   https://stackoverflow.com/questions/7908636/
annot = ax.annotate("", xy=(0,0), xytext=(20,20),textcoords="offset points",
                    bbox=dict(boxstyle="round", fc="w"),
                    arrowprops=dict(arrowstyle="->"))
annot.set_visible(False)

def update_annot(ind):
    annot.xy = sc.get_offsets()[ind["ind"][0]]
    text = str(frames[ind["ind"][0]])
    if len(ind["ind"]) > 1:
        text += " to " + str(frames[ind["ind"][-1]])
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
