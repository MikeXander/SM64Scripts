-- simple script for disabling all input because I am too lazy to de-map then re-map my controller hotkeys
x = {R=false, A=false, B=false, Cup=false, left=false, Cright=false, up=false, Cleft=false, X=0, Y=0, Z=false, Cdown=false, L=false, down=false, start=false, right=false}
emu.atinput(function() joypad.set(1, x) end)
