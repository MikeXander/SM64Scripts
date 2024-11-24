import cvxpy as cvx
import numpy as np
import wafel
from math import asin, acos, pi, floor, ceil

# Simulates the air movement from falling off the slope in SL
# to landing on the mountain

game = wafel.Game('D:\\Programming\\Python\\wafel\\libsm64\\sm64_us.dll')
u16 = lambda x: (x + 0x10000) % 0x10000
sins = lambda x: game.read(f"gSineTable[{u16(x) >> 4}]")
coss = lambda x: game.read(f"gSineTable[{(u16(x) >> 4) + 0x400}]")

FRAMES = range(210, 232)

def generate_coeffs(yaw):
    return [
        sins(yaw),
        10*sins(yaw+0x4000),
        coss(yaw),
        10*coss(yaw+0x4000)
    ]

def create_program(x0, z0, s0, yaw):
    global FRAMES
    a = {} # sin(DYaw(i))
    b = {} # cos(DYaw(i))
    x = {209: x0} # x coord on frame i
    z = {209: z0} # z coord on frame i
    s = {209: s0} # horizontal speed on frame i
    #x[209] = cvx.Variable()
    #z[209] = cvx.Variable()
    #s[209] = cvx.Variable()

    C = generate_coeffs(yaw)
    constraints = []

    for i in FRAMES:
        a[i] = cvx.Variable()
        b[i] = cvx.Variable()
        x[i] = cvx.Variable()
        z[i] = cvx.Variable()
        s[i] = cvx.Variable()

        constraints += [
            # relaxation on DYaw ratios: a^2 + b^2 == 1
            cvx.square(a[i])+ cvx.square(b[i]) <= 1.00000001,
            
            # speed update
            s[i] == s[i-1] + 1.5 * b[i] - 1.35
        ]
        if i < 231:
            constraints += [
                # position change
                x[i] == x[i-1] + C[0] * s[i] + C[1] * a[i],
                z[i] == z[i-1] + C[2] * s[i] + C[3] * a[i],
            ]

    constraints += [
        # final frame is only 2qf
        x[231] == x[230] + (C[0] * s[231] + C[1] * a[231])/2,
        z[231] == z[230] + (C[2] * s[231] + C[3] * a[231])/2,

        # avoid early qf landing on wrong slope
        x[230] + (C[0] * s[231] + C[1] * a[231])/4 <= -2142,
        z[230] + (C[2] * s[231] + C[3] * a[231])/4 <= 3081,

        # final unit square landing
        -2167 <= x[231], x[231] <= -2166,
        3096 <= z[231], z[231] <= 3099#3097
    ]

    p = cvx.Problem(cvx.Maximize(s[231]), constraints)
    p.solve()
    
    """d = 0.5
    p = cvx.Problem(
        cvx.Minimize((x[209]-x0)**2 + (z[209]-z0)**2 + (s[209]-s0)**2),
        constraints + [
            #x0 - d <= x[209], x[209] <= x0 + d,
            #z0 - d <= z[209], z[209] <= z0 + d,
            112 <= s[231],
            s[209] <= s0
        ]
    )
    p.solve()
    print(p.value, x[209].value, z[209].value, s[209].value)"""
    
    f = lambda obj: { # remove the need to index and type .value
        i: (obj[i] if type(obj[i]) == float else float(obj[i].value))
        for i in obj
    }
    p.var = {"a":f(a), "b":f(b), "x":f(x), "z":f(z), "s":f(s)}
    return p

# avoid subtraction problems
def equal_within(a, b, epsilon=1e-6):
    return a <= epsilon + b


def effective_angle(yaw):
    return yaw >> 4 << 4


# return (IntendedYaw, DYaw)
def IntendedYaw(yaw, sindyaw, cosdyaw):
    conversion = 65536/2/pi
    dyaw = abs(asin(sindyaw)) * conversion
    lo = effective_angle(yaw - floor(dyaw))
    hi = effective_angle(yaw - ceil(dyaw))
    if lo != hi:
        print(f"Warning: DYaw rounding DYaw {round(dyaw,3)} ", end='')
        print(f"changes effective angle {lo} {hi}")
    dyaw = round(dyaw)
    
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
    return yaw - dyaw, dyaw
         
    
def display_inputs(p):
    dist = lambda x1,y1,x2,y2: ((x1-x2)**2 + (y1-y2)**2)**0.5
    for f in FRAMES:
        a = p.var["a"][f]
        b = p.var["b"][f]
        print(f, IntendedYaw(55253, a, b), p.var["s"][f])
        #print(a, b, dist(a,b,0,0))
        #print(p.var["x"][f], p.var["z"][f], p.var["s"][f])
        #d = dist(p.var["x"][f-1], p.var["z"][f-1], p.var["x"][f], p.var["z"][f])
        #print(d, d-p.var["s"][f])
        #print()

# Palix slwhirl.ne6.m64
p = create_program(-162.477508544922, 1819.85034179688, 109.356353759766, 55243)
#display_inputs(p)
assert(equal_within(p.value, 111.99552154541, 0.0002))

# # Palix slwhirl.nf2.m64
p = create_program(-162.380081176758,1819.83447265625,109.330505371094, 55253)
assert(equal_within(p.value, 111.930221557617, 0.01))

# Xander slwhirl.109_354.m64
p = create_program(-162.503372192383, 1819.84826660156, 109.354393005371, 55253)
assert(equal_within(p.value, 111.99552154541, 0.0001))

# Xander slwhirl.109_31.m64
p = create_program(-162.498840332031, 1819.8515625, 109.31819152832, 55253)
#display_inputs(p)





