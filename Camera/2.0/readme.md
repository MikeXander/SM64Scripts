# Custom Camera 2.0

Now with consolidated scripts and a GUI to set keyframes for camera and focus positions as well as slow-mo keyframes.

The essential steps for using this are:
1. get your tas, make sure the starting `.st` attached to the tas starts with the level loaded
2. edit `Config.lua` to point to your TAS
3. run `ConvertTASToGhost.lua` to get a ghost file
4. use `CustomCameraCreator.lua` to set keyframes for the camera and focus paths, as well as slow-mo.
5. save the points, then start your TAS playback, then run `CustomCameraPlayback.lua` to edit the camera with the actual TAS

All buttons have tooltips when you hover your cursor over them. This has only been tested on the U ROM.

Attributions:
- Icons are taken or derived from Google's [Material Design Icons](https://github.com/google/material-design-icons)
- The UI framework is a modified version of [ugui](https://github.com/mupen64/ugui)
- Special thanks to Frame, MKDasher & pfedak, and Eddio0141 for making ghost visualizations, render camera editing, and savestate modifying (respectively) possible