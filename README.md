# SM64Scripts
A collection of various scripts I've made for TASing SM64. Feel free to use these, and adapt them to your needs. If you publish it anywhere just make sure to give me credit please :D

### Running the Scripts
Open the game, playback the movie in read-only mode, and then run the desired lua script. You will need [mupen64-lua](http://adelikat.tasvideos.org/emulatordownloads/mupen64-rr/LuaExtension_r34_bin.zip) and an American (U) ROM. For scripts that point to `"D:/lua.st"`, you can instead use the savestate that is provided with the m64 file. Scripts that `require "RNG"` need `RNG.lua` in the same directory as the m64 you're playing back.

To run python scripts, download [the latest version of python](https://www.python.org/downloads/) and install any of the dependencies listed at the top of the files. Ex. run `pip install matplotlib` from a command prompt.

### RNG Brute-Forcers
In general, all of these work in the same way:

RNG does not change on the star select screen so this acts as the main starting point. In *some cases* we could change RNG part way through the TAS to shorten run time but then it would require back tracking to figure out the number of RNG calls leading up to that point (which is too much effort for me).

So, the script loads a savestate on star select screen, then advances by 1 frame and changes the RNG value. It needs to advance one frame for the savestate to actually load, otherwise the new RNG value would be overwritten. After that, it plays through the inputs, then records data on the conditions in the game, and repeats itself until it has gone through all the possible RNG values.

Typically, some type of filter is applied to the scenario or the data so that subsequent tests do not need to run though all 65114 possible RNG values.

Computers can only do so much, so with the final list of potentially-good RNG values there's a bit of classic trial and error TASing on a few of them. But hey, at this point it's a smart guess, not a random one!
