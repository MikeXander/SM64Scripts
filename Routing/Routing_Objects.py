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

# This program outputs the best L paths as defined below
NUM_OUTPUT_PATHS = 10

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

paths = [] #[dist, path]

def updateMin(path, dist):
    if not hasRequiredPairs(path): return
    
    global points
    global paths
    
    dist += start_dist[path[0]]
    dist += end_dist[path[-1]]

    paths = sorted(paths, key = lambda path: path[0], reverse = True)
    if len(paths) < NUM_OUTPUT_PATHS:
        paths.append([dist, []])
        for node in path: paths[len(paths) - 1][1].append(points[node][0])
        
    elif dist < paths[0][0]:
        paths[0][0] = dist
        paths[0][1] = []
        for node in path: paths[0][1].append(points[node][0])


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

paths = sorted(paths, key = lambda path: path[0])
for dist, path in paths:
    for node in path: print(node, end=' ')
    print(dist)
