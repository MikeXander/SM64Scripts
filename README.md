# SM64Scripts
A collection of various scripts I've made for TASing SM64. Feel free to use these, and adapt them to your needs.



### Running the Scripts
Open the game, playback the movie in read-only mode, and then run the desired lua script. You will need [mupen64-lua](http://adelikat.tasvideos.org/emulatordownloads/mupen64-rr/LuaExtension_r34_bin.zip) and an American (U) ROM. For scripts that point to `"D:/lua.st"`, you can instead use the savestate that is provided with the m64 file. Scripts that `require "RNG"` need `RNG.lua` in the same directory as the m64 you're playing back.

To run python scripts, download [the latest version of python](https://www.python.org/downloads/) and install any of the dependencies listed at the top of the files. Ex. run `pip install matplotlib` from a command prompt.



### Custom Camera (Curve-Fit & Bullet-Time)

Given an input set of points in 3D space with velocities and target frames, a simple curve fit algorithm will move the camera between the points during the playback of a TAS.

This is done by removing the render camera instructions, and instead rendering it from a calculated position. Normally, the camera affects inputs, but this only changes the *rendered* camera to prevent desyncs during playback.

If 2 points have the same target frame, it will freeze the game while it traverses between those points - creating the bullet-time effect from the movie The Matrix. This is achieved by saving a state, and editing the rendered camera within the savestate file before loading it.

<img src="/Camera/ExampleCustomCamera.gif?raw=true" width="640px">

There is also a helper lua script which will export Mario's position. This can then be used with the python script to visualize where the camera will go. The red path is Mario, the orange path is the camera, and the blue dots are the points it travels through:

![Example Cam Path Visualization (from the above video)](https://cdn.discordapp.com/attachments/196442189604192256/754367388870508554/TTC_CamPath.png)



### RNG Brute-Forcers
In general, all of these work in the same way:

RNG does not change on the star select screen so this acts as the main starting point. In *some cases* we could change RNG part way through the TAS to shorten run time but then it would require back tracking to figure out the number of RNG calls leading up to that point (which is too much effort for me).

So, the script loads a savestate on star select screen, then advances by 1 frame and changes the RNG value. It needs to advance one frame for the savestate to actually load, otherwise the new RNG value would be overwritten. After that, it plays through the inputs, then records data on the conditions in the game, and repeats itself until it has gone through all the possible RNG values.

Typically, some type of filter is applied to the scenario or the data so that subsequent tests do not need to run though all 65114 possible RNG values.

Computers can only do so much, so with the final list of potentially-good RNG values there's a bit of classic trial and error TASing on a few of them. But hey, at this point it's a smart guess, not a random one!



### Routing Scripts
This set of scripts was designed to be a starting point in TAS Competitions where the Task is to collect a subset of a certain type of object (Example: collect 7 out of 10 coins). The main script is a depth-first search which finds the minimum distance between those objects.

You can input pairs of points that you don't want included in the final path. This is for cases where the segment is obviously slow or restricted in some way but the algorithm attempts to include it.

If you're not sure what a path looks like, you can always check using the graphing script:

![Example Routing Graph](https://cdn.discordapp.com/attachments/196442189604192256/754420115625345174/RouteGraphExample.png)

A helper lua script is included to export the positions of any object matching a given graphics type.

Ideas to improve these routing scripts:
- combine the search and graph scripts could be combined into one
- Add a variable weight to travelling vertically
- Further optimize the algorithm (it's fast enough for the current, small-scale inputs)
- Adapt it to be applicable to Tasks which require alternating between objects (Ex: collect 2 red coins and 2 yellow coins, alternating colour each time)



### Input Brute-Forcers
Currently, the only script I have here was used for preliminary testing. It takes a range of frames and tries every combination of joystick input to see if that changes a future outcome.

The best known approach to input brute-forcing is random angle perturbations from a given input, which is done through executing a loop of the actual game code instead of simulating it through an emulator (to increase speed dramatically).
