Motivation
----------

I made a small supergun board last year which was featured on Hack-a-Day. A
lot of the comments focused on the output being SCART, a Europian video
standard that supports RGB which isn't common in other parts of the world. The
obvious solution seemed to be a supergun with HDMI output. I didn't really
have a huge amount of motivation to do it and it ended up on the back burner.
Over Christmas I had some time though and had recently been messing around
with cheap FPGA dev boards from eBay. The FPGA could be used to generate the
HDMI signal (just) and as it has a small amount of fast memory to be able to
upscale the image to the 480p. However I'd gone off the HDMI supergun concept
a bit by this point. Firstly I didn't have any ADCs fast enough to process video on hand and
secondly SCART to HDMI adapters aren't all that expensive anymore (although
this solution is admittedly clunkier). So, a slightly different idea came to
me. The Neo Geo the digitised video signal is easy to get before it's converted to
an analogue signal so by tapping it from there we can get a direct digital to
digital connection theorectially giving the best possible video quality.
Hopefully this will able to be extended to the audio too giving the best
possible sound quality too.
Nb. This isn't totally original. Half way through I found a NeoGAF post, when
searching for some video timings info, where someone was doing something very
similar although it looked to end up with a VGA signal so not a fully digital
connection. I also wondered about extending the concept to old video consoles
but many of the really old consoles have analogue video coming out of their
custom chips. The newer the console the easier it looks to be. Dreamcast,
Gamecube, N64 and possibly SNES look feasible. N64 looks to have been done
before though.

Clock trouble
-------------

_This second is outdated as I now overclock the Neo Geo to get the clock I need_

The obvious clock to use is the clock on the video output latches.
It's 6.?MHz which gives us a nice multiple to get to around 25MHz.
Also in sync with the video data is it's the latch.
However 6MHz is too slow to use the PLL on the Cyclone II.
Therefore we can use the 12MHz CPU clock as it's fairly easy to get as it's on a big pin close to the video data.
Next problem was all the voltages are 5V which is above the maximum input voltage for the FPGA inputs.
I originally tried a 1Kohm resistor and 3.3V Zener to do the voltage division but looking on the oscilloscope it performed awfully (800 mVpp)!
So I then went back to the obvious of just a resistor voltage divider. This worked fine at 6MHz but was too attenuated at 12MHz to be used.
Adding a 1uF capacitor across the first resistor reduced the attenuation enough to finally become usable.
Next problem was that to produce a 250MHz signal which is needed for the FPGA4FUN HDMI output because it's not a possible multipler for the PLL.
To get around this a DDR type scheme was used. The original code shifted data 10 times a pixel.
Using a DDR scheme I shift data 5 times a pixel but route the first or second bit based on the level of the input clock.
This allowed a 125MHz clock to drive the HDMI output and so now have all the clocks needed.

Video DAC
---------

The video DAC on the MVS is fairly simple resistor divider.
Each digital output is connected via a resistor to the RGB output terminals.
A digital output that's on contributes to the resistance at the top.
A digital output that's off contributes to the resistance at the bottom of the divider.
The monitor would have an input resistance (probably 75 ohms) which also adds to the bottom of the divider.
The two slightly different and originally confusing part are two digital inputs which effect red, green and blue simulataneously.
Shadow and DAK (Darken?). Both of these go through not gates which crucially are open collector outputs.
This means they only sync current and so their resistors only add to the bottom of the divider.
Shadow effectively darkens the output by 0.75.
DAK seems very ineffective. It looks like it should add a new LSB but due to the use of an open collector it has much less effect especially at the low range.
The video ramp in general is reasonably linear but has gaps due to the resistors being common values and not precisely what's needed.
I decided to avoid the bad ramp and ineffective DAK input as the intention for a linear ramp and an additional LSB seems obvious and it's probably an improvement over the original.
Shadow was implemented as a 0.75 multiply however it seems at least on the game I have neither shadow or DAK are used.

Scan doubling
-------------

The JAMMA video standard is basically NTSC (the old TV standard) but with RGB and sync pre seperated.
HDMI won't allow any resolution lower than 640x480. NTSC is 640x240 each frame as it's interlaced so each frame only has the odd or even lines.
Therefore the signal can't be fed in directly. Instead each line has to be sent twice to meet the minimum requirements.
This is done by using the small amount of RAM on the FPGA.
Over the course of two lines the data read from the MVS is stored into RAM.
While this is happening the last line of data is being output twice.
This doesn't work perfectly. The original image was interlaced and it's obvious on some effects that they are not like they used to be.
For example the shadows now obviously flicker instead of looking stripey on the a CRT.
To get some of this effect alternate lines are dimmed each frame (black made the whole image too dim).
It'd be better to have the dimmed data from the last frame (recreating the phosperous on a TV slowly fading) but the amount of RAM availible is only another for a handful of lines and nothing like a whole frame.

Synchronisation
---------------

At this stage the whole image was now being displayed correctly but it wasn't synced at all so the image appeared somewhere randomly on screen.
The obvious thing to use would be the SYNC output that goes to the JAMMA connector.
Unfortunately there isn't a nice place to tap it out apart form the JAMMA connector and that'd interfer with connecting a JAMMA connector.
Luckily the video latches have a CLEAR input to stop data being clocked out when HSYNC or VSYNC are active. This is effectively exactly the same as the SYNC output at the JAMMA connector.
While clocking out HDMI data if we see CLEAR being high when we're displaying data the counters are reset.
And finally we now have a syncronised, scan doubled video output.

Sound
-----

After so many issues with video sound actually turned out to be incredibly
straight forward. The chip on my board was a BU9480F which is a stereo DAC. It
has three lines: Clock, Data and LRCK. Clock and Data form a simple two line
serial interface. The LRCK is high for data intended for the left channel, low
for the right channel. When LRCK transitions all the data for that channel has
been transfered.

The tricky bit is that the frequency of LRCK is 55.6KHz which means we get
55.6KHz audio. Unfortunately this is not a nice multiple of any standard audio
frequency. Also the HDMI spec says we can only assume 32KHz audio support. I
implemented very basic downsampling (just point sampling at 32KHz) which isn't
the best quality possible but the output sounds good to my ear.

Sound over HDMI
---------------

This was a huge, huge pain to get working. Mainly due to getting the data islands working correctly (the difference between a DVI signal and a HDMI one). After this it was just a case of getting the channel status bit stream working correctly and the parity bits correct. Hopefully this code will serve as a help to people that try this after me.

Overclocking
------------

The test monitor I used accepted a 24MHz pixel clock and that the signal
timing was out of spec (only 768 horizontal pixels including control periods
instead of 800 and an extra 3 lines on the vertical. My TVs proved a lot
fussier though. So, I knew I had to get to a standard timing. The biggest
problem was that the Neo Geo was outputing just 59.1fps. Therefore whatever I
did I couldn't achieve a standard timing without having enough memory to store
an entire frame (and accept screen tearing). I needed to overclock the NeoGeo
to get to 60fps. Hopefully the speed up would be so small as to be
inperceptable.

To get 60 I would need to overclock the NeoGeo to 24.33024MHz. We aren't luck
enough for that to be a standard frequency and it isn't a nice multiple of any
of the pixel clocks. Therefore I decided to drive the NeoGeo from the FPGA and
overclock the occational cycle so that the NeoGeo would complete a frame every
60th of a second.

I chose to run the pixel clock at 27MHz (rate for 720x480p at 60) which meant
the DDR TMDS clock was only 135MHz. Every positive edge of the TMDS clock I
checked to see if enough time had passed that I needed to toggle the NeoGeo
clock. This effectively meant running at 24.54MHz (with uneven duty cycle)
with the occational downclock to 22.5MHz. The NeoGeo didn't seem to mind this
luckily.

All that was left to do was split the pixel reading (based on the NeoGeo's
new clock) from the output (pixel clock based). The 3 fewer vertical lines
on the output meant that the line buffer had to be big enough to allow the
NeoGeo to run up to 3 lines ahead but that was a trivial change. All this work
meant we were now perfectly in spec.
