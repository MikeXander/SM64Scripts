print("Loading modules... ", end = '')
import cvxpy as cvx
import wafel
from math import asin, acos, pi, floor, ceil

# simulating the initial LJ in SL
#print(cvx.installed_solvers()) # <- NOTE: Mosek is required

game = wafel.Game('D:\\Programming\\Python\\wafel\\libsm64\\sm64_us.dll')
print("Complete")

u16 = lambda x: (x + 0x10000) % 0x10000
sins = lambda x: game.read(f"gSineTable[{u16(x) >> 4}]")
coss = lambda x: game.read(f"gSineTable[{(u16(x) >> 4) + 0x400}]")
equal_within = lambda a, b, epsilon=1e-6: a <= epsilon + b
effective_angle = lambda yaw: yaw >> 4 << 4

def generate_coeffs(yaw):
    return [
        sins(yaw),
        10*sins(yaw+0x4000),
        coss(yaw),
        10*coss(yaw+0x4000)
    ]

# simulate the constraints for the first long jump
def create_program(x0, z0, s0, yaw, f0=79, fn=111):
    # var[f] is the variable on frame f
    a = {} # sin(DYaw(i))
    b = {} # cos(DYaw(i))
    x = {f0: x0} # x coord
    z = {f0: z0} # z coord
    s = {f0: s0} # horizontal speed
    d = {} # fast drag indicator

    C = generate_coeffs(yaw)
    M = s0 + 1.5*(fn-f0+1) # upper bound on speed
    D = 48 # drag threshhold for a long jump
    
    constraints = []

    for f in range(f0+1, fn+1):
        a[f] = cvx.Variable()
        b[f] = cvx.Variable()
        x[f] = cvx.Variable()
        z[f] = cvx.Variable()
        s[f] = cvx.Variable()
        d[f] = cvx.Variable(boolean=True)

        constraints += [
            # relaxation on DYaw ratios: a^2 + b^2 == 1
            cvx.square(a[f])+ cvx.square(b[f]) <= 1.00000001,
            
            # speed update
            s[f] == s[f-1] + 1.5*b[f] - 0.35 - d[f],

            # enforce drag, fast: s >= D, slow: s < D
            D*d[f] <= s[f],
            D - 1e-4 >= s[f] - M*d[f],
            
            # position change
            x[f] == x[f-1] + C[0]*s[f] + C[1]*a[f],
            z[f] == z[f-1] + C[2]*s[f] + C[3]*a[f],
        ]

    constraints += [
        #  final region landing
        x[fn] <= 4343,
        z[fn] <= 651
    ]

    p = cvx.Problem(cvx.Maximize(s[fn]), constraints)
    print("Solving...")
    p.solve(solver=cvx.MOSEK)
    
    f = lambda obj: { # remove the need to index and type .value
        i: (obj[i] if type(obj[i]) == float else float(obj[i].value))
        for i in obj
    }
    p.var = {"a":f(a), "b":f(b), "x":f(x), "z":f(z), "s":f(s), "yaw":yaw}
    return p


# return (IntendedYaw, DYaw)
def IntendedYaw(yaw, sindyaw, cosdyaw, ignoreWarnings = False):
    conversion = 65536/2/pi
    dyaw = abs(asin(sindyaw)) * conversion
    lo = effective_angle(yaw - floor(dyaw))
    hi = effective_angle(yaw - ceil(dyaw))
    if lo != hi and not ignoreWarnings:
        print(f"Warning: rounding DYaw {round(dyaw,3)} changes effective angle {lo} {hi}")
    dyaw = ceil(dyaw)#round(dyaw)
    
    #if sindyaw < 0 and cosdyaw > 0: # C
    #    dyaw = dyaw
    if sindyaw > 0 and cosdyaw > 0: # A
        dyaw = -dyaw
    elif sindyaw > 0 and cosdyaw < 0: # S
        dyaw = -dyaw
    #elif sindyaw < 0 and cosdyaw < 0: # T
    #    dyaw = dyaw
    #elif sindyaw == 0.0: # 0 or 32768
    #    dyaw = dyaw
    elif cosdyaw == 0.0: # 16384 or 49152
        dyaw = -dyaw
    # else shouldnt happen since radius is 1

    # flipped from what I thought?
    return u16(yaw - dyaw), u16(dyaw)

    
def display_inputs(p, f0=79, fn=111):
    dist = lambda x1,y1,x2,y2: ((x1-x2)**2 + (y1-y2)**2)**0.5
    for f in range(f0+1, fn+1):
        a = p.var["a"][f]
        b = p.var["b"][f]
        print(
            f,
            IntendedYaw(p.var["yaw"], a, b),
            p.var["s"][f],
            round(p.var["s"][f] - p.var["s"][f-1], 3)
        )
        #print(a, b, dist(a,b,0,0))
        #print(p.var["x"][f], p.var["z"][f], p.var["s"][f])
        #d = dist(p.var["x"][f-1], p.var["z"][f-1], p.var["x"][f], p.var["z"][f])
        #print(d, d-p.var["s"][f])
        #print()

def print_lua_dyaw(p, f0=79, fn=111):
    print("local DYaw = {")
    for f in range(f0+1, fn):
        yaw, dyaw = IntendedYaw(p.var["yaw"], p.var["a"][f], p.var["b"][f], True)
        print(f"\t[{f}] = {dyaw},")
    yaw, dyaw = IntendedYaw(p.var["yaw"], p.var["a"][fn], p.var["b"][fn], True)
    print(f"\t[{fn}] = {dyaw}\n" +'}')

# Xander slwhirl.109_31.m64
p = create_program(5446.66796875, 449.85888671875, 16.9676284790039, 51621)
display_inputs(p)
print_lua_dyaw(p)

# palix
p = create_program(5446.634765625, 449.833862304688, 16.9849910736084, 51602)
print(p.var["x"][111], p.var["z"][111], p.var["s"][111])
display_inputs(p)
print_lua_dyaw(p)



