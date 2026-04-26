LiveGhostLua aka CoTAS is a set of scripts meant to connect players remotely, appearing as a ghost in each other's game.

To run this script you need to build/compile the socket and mime modules for your system. After doing so, add the following files to this folder:
```
LiveGhostLua/
└── Lib
    ├── mime
    │   └── core.dll
    ├── socket
    │   ├── core.dll
    │   ├── ftp.lua
    │   ├── headers.lua
    │   ├── http.lua
    │   ├── ltn12.lua
    │   └── smtp.lua
    └── socket.lua

```
You may also need to create a copy of the `lua.dll` that is in the same folder as your `mupen64.exe` and rename it to `lua54.dll`.

Then, edit `Config.lua` to contain your desired settings, have one player run `Host.lua` and then other players can run `Client.lua`. Note that you will need to be connected on the same network for this to work, my personal recommendation is [Radmin VPN](https://www.radmin-vpn.com/).