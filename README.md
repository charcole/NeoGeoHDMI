HDMI output for NeoGeo MVS
==========================

Full write up and video coming soon. Honest :)

Summary: The digital video and audio outputs from the Neo Geo MVS are tapped off before going through the DACs. Instead an FPGA reads the data and outputs the signal over HDMI forming a direct digital to digital connection.

This project might be notable in that it's one of the very few (that I know of) that features working audio over HDMI.

The NeoGeo MVS using the default clock outputs video at 59.1 frames per second. To allow for an HDMI signal that is within the spec the NeoGeo's clock is driven from the FPGA to produce exactly 60 frames per second.

*Nb. The code was originally based off the HDMI/DVI sample code from [fpga4fun.com](http://www.fpga4fun.com/HDMI.html).*
