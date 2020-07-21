import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from mpl_toolkits.mplot3d import axes3d

# Input:
# N, number of reds
# Followed by N+2 lines of Points (Start + N + End)
# Followed by a line with N space separated labels (route to graph)

# ToDo: Add a loop that allows you to refresh the graph with
#       a different path

'''
Sample Input:
10
Start 2685.03 2560 1902.55
29 -250.00 2950.00 1770.00
30 1746.00 3620.00 -3120.00
31 2177.00 2600.00 250.00
32 3385.00 2395.00 -280.00
33 650.00 2600.00 -1420.00
34 2700.00 3600.00 -900.00
35 -2549.00 2600.00 -571.00
36 -1270.00 2620.00 1650.00
113 -2498.53 1892.00 -66.32
138 450.37 3684.00 208.69
End2 -2500.00 1500.00 -750.00
31 138 29 36 113
'''

num_reds = int(input())

def point_input(num):
    def convert(lst):
        lst[1:] = list(map(float, lst[1:]))
        return lst
    result = [convert(input().split(' ')) for _ in range(num)]
    return result[0] if num == 1 else result

start = point_input(1)
reds = point_input(num_reds)
end = point_input(1)

reds_dict = {}
for coin in reds: reds_dict[coin[0]] = [coin[1], coin[2], coin[3]]

x = []
y = []
z = []
colours = []

def add_point(point, colour):
    global x, y, z
    for i in range(3):
        [x, y, z][i].append(point[i + 1])
    colours.append(colour)
    
add_point(start, 'yellow')
for coin in reds: add_point(coin, 'red')
add_point(end, 'yellow')

fig,ax,sc = 0,0,0
fig = plt.figure()
ax = fig.add_subplot(111, projection='3d')
sc = ax.scatter(z,x,y,c=colours)
ax.set_xlabel("Z")
ax.set_ylabel("X")
ax.set_zlabel("Y")

def add_line(p1, p2, colour):
    xs = p1[0], p2[0]
    ys = p1[1], p2[1]
    zs = p1[2], p2[2]
    line = axes3d.art3d.Line3D(zs, xs, ys, color=colour)
    global ax
    ax.add_line(line)

route = list(input().split(' '))

for i in range(1, len(route)):
    add_line(reds_dict[route[i - 1]], reds_dict[route[i]], 'black')
add_line(start[1::], reds_dict[route[0]], 'green')
add_line(end[1::], reds_dict[route[-1]], 'blue')
    
plt.show()
