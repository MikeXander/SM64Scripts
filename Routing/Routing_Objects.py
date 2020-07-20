# Brute Force Routing Script by ERGC | Xander
# This finds the shortest distance (in units) between objects

# Input is as follows:
# Note: "Points" are a label followed by 3 floats (coordinates) on the same line

# The first line has 2 space separated numbers, N, the number of objects, and
# the number of required objects.

# The next line is the start Point
# Then N Points
# Then the end Point

# Then 1 integer, M, the number of "Banned Pairs"
# These are pairs that you do not want to consider in the route
# The next M lines are space separated labels (names of the points)

# Then 1 integer, K, the number of "Required Pairs"
# These are pairs that must appear in your route
# The next K lines are space separated labels (names of the points)

'''
Sample Input:
3 2
start 0 0 0
a 1 1 1
b 3 4 5
c 7 8 9
end 10 10 10
0
0

>>> [a, b]
>>> 17.605304096404897


TAS Tournament Round 4 Sample Input:
10 8
start 604.716 -1116 -3211.966
0 3169.815 212 -3660.273
1 -3412.884 1152.978 -22.28
2 -2671.604 2464 -66.016
3 5795.959 3333 -2334.091
4 5046.201 2000 304.377
5 2819.269 -1016 -30.343
6 3554 5006 -2343
7 -2552.281 3479 -5511.287
8 -6286.799 4042 -2140.868
9 1587.481 1040 -180.28
star -134.584 3949 -2347.358
0
1
start 2

>>> ['2', '1', '9', '5', '0', '4', '3', '6']
>>> 32964.51012547283
'''

num_reds, num_required = map(int, input().split(' '))

def dist(a, b):
    d = 0
    for i in range(1,4):
        d += (a[i] - b[i]) ** 2
    return d ** 0.5

def point_input(num):
    def convert(lst):
        lst[1:] = list(map(float, lst[1:]))
        return lst
    result = [convert(input().split(' ')) for _ in range(num)]
    return result[0] if num == 1 else result

start = point_input(1)
points = point_input(num_reds)
end = point_input(1)

start_dist = [dist(start, points[i]) for i in range(num_reds)]
end_dist = [dist(end, points[i]) for i in range(num_reds)]

num_banned_pairs = int(input())
banned_pairs = [input().split(' ') for _ in range(num_banned_pairs)]

num_required_pairs = int(input())
required_pairs = [input().split(' ') for _ in range(num_required_pairs)]

def hasRequiredPairs(path):
    global required_pairs
    global points
    for pair in required_pairs:
        
        if pair[0] == start[0]:
            if points[path[0]][0] != pair[1]: return False
            
        elif pair[1] == end[0]:
            if points[path[-1]][0] != pair[0]: return False
            
        else:
            for i in range(len(path) - 1):
                if points[path[i]][0] == pair[0] and points[path[i+1]][0] == pair[1]:
                    break
            else:
                return False
            
    return True

min_dist = -1
best_path = []
paths = [] #[dist, path]

def updateMin(path, dist):
    if not hasRequiredPairs(path): return
    
    global min_dist
    global best_path
    global points
    
    dist += start_dist[path[0]]
    dist += end_dist[path[-1]]
    
    if min_dist == -1 or dist < min_dist:
        min_dist = dist
        best_path = []
        for node in path: best_path.append(points[node][0])


def search(path, dist_so_far):
    if len(path) == num_required:
        updateMin(path, dist_so_far)
    else:
        for i in range(num_reds):
            if not i in path and not [path[-1], i] in banned_pairs:
                new_path = [coin for coin in path]
                new_path.append(i)
                extra_dist = dist(points[i], points[path[-1]])
                search(new_path, dist_so_far + extra_dist)


for red in range(num_reds):
    search([red], 0)
print(best_path)
print(min_dist)
