HDMI output for NeoGeo MVS
==========================

Summary: The digital video and audio outputs from the Neo Geo MVS are tapped off before going through the DACs. Instead an FPGA reads the data and outputs the signal over HDMI forming a direct digital to digital connection.

This video should explain things:

<a href="http://www.youtube.com/watch?feature=player_embedded&v=bTamCo2C6kg
" target="_blank"><img src="http://img.youtube.com/vi/bTamCo2C6kg/0.jpg" 
alt="IMAGE ALT TEXT HERE" width="640" height="480" border="10" /></a>

The FPGA generates the HDMI video signal with data islands to embed the audio. It also controls the clock of the Neo Geo MVS so it can produce the exact 720x480p at 60fps timing that the HDMI specification demands. See the [notes](Notes.md) for more details.

If you've built hardware based on older releases of the [wiring](Wiring.md) information then note that in the new build I've changed pin 73 to pin 104 for the lowest bit of the blue channel. This is because pin 73 was connected to the power rail on the dev board.

*This project might also be notable in that it's one of the very few (that I know of) that features working audio over HDMI.*

*Nb. The code was originally based off the HDMI/DVI sample code from [fpga4fun.com](http://www.fpga4fun.com/HDMI.html).*
