Wiring
======

Wiring is fairly straight forward. It doesn't seem worth making a schematic as it's all just point to point stuff.

FPGA to HDMI
------------

| HDMI                                                |    FPGA                                     |  
| --------------------------------------------------- | ------------------------------------------- |  
| ```Pin 1    TMDS Data2+                        ```  |    ```Pin 32    hdmip[2]             ```    |
| ```Pin 2    TMDS Data2 Shield                  ```  |    ```GND                            ```    |
| ```Pin 3    TMDS Data2−                        ```  |    ```Pin 31    hdmin[2]             ```    |
| ```Pin 4    TMDS Data1+                        ```  |    ```Pin 30    hdmip[1]             ```    |
| ```Pin 5    TMDS Data1 Shield                  ```  |    ```GND                            ```    |
| ```Pin 6    TMDS Data1−                        ```  |    ```Pin 28    hdmin[1]             ```    |
| ```Pin 7    TMDS Data0+                        ```  |    ```Pin 7     hdmip[0]             ```    |
| ```Pin 8    TMDS Data0 Shield                  ```  |    ```GND                            ```    |
| ```Pin 9    TMDS Data0−                        ```  |    ```Pin 8     hdmin[0]             ```    |
| ```Pin 10   TMDS Clock+                        ```  |    ```Pin 25    hdmiclkp             ```    |
| ```Pin 11   TMDS Clock Shield                  ```  |    ```GND                            ```    |
| ```Pin 12   TMDS Clock−                        ```  |    ```Pin 24    hdmiclkn             ```    |
| ```Pin 13   CEC                                ```  |    ```NC                             ```    |
| ```Pin 14   Reserved                           ```  |    ```NC                             ```    |
| ```Pin 15   SCL (I²C Serial Clock for DDC)     ```  |    ```NC        1K pull up to 5V     ```    |
| ```Pin 16   SDA (I²C Serial Data Line for DDC) ```  |    ```NC        1K pull up to 5V     ```    |
| ```Pin 17   DDC/CEC/ARC/HEC Ground             ```  |    ```GND                            ```    |
| ```Pin 18   +5 V                               ```  |    ```Vin       +5V (Power input)    ```    |
| ```Pin 19   Hot Plug detect                    ```  |    ```NC                             ```    |

            
Neo Geo to FPGA
---------------

| FPGA                         |  Neo Geo MVS (SvC board)                                                          |
| ---------------------------- |  -------------------------------------------------------------------------------- |
| ```Pin 64    NEOGEOCLK ```   |    ```OSC           Oscillator removed and this wired into the right hand pin ``` |
| ```Pin 75    R[0]      ```   |    ```IC7  Pin 16   Red[0] (Found 3.9Kohm to red JAMMA output)                ``` |
| ```Pin 92    R[1]      ```   |    ```IC7  Pin 2    Red[1] (Found 2.2Kohm to red JAMMA output)                ``` |
| ```Pin 90    R[2]      ```   |    ```IC7  Pin 5    Red[2] (Found 1Kohm to red JAMMA output)                  ``` |
| ```Pin 87    R[3]      ```   |    ```IC7  Pin 6    Red[3] (Found 470ohm to red JAMMA output)                 ``` |
| ```Pin 100   R[4]      ```   |    ```IC7  Pin 9    Red[4] (Found 220ohm to red JAMMA output)                 ``` |
| ```Pin 74    G[0]      ```   |    ```IC7  Pin 15   Green[0] (Found 3.9Kohm to green JAMMA output)            ``` |
| ```Pin 101   G[1]      ```   |    ```IC6  Pin 12   Green[1] (Found 2.2Kohm to green JAMMA output)            ``` |
| ```Pin 86    G[2]      ```   |    ```IC6  Pin 15   Green[2] (Found 1Kohm to green JAMMA output)              ``` |
| ```Pin 89    G[3]      ```   |    ```IC6  Pin 16   Green[3] (Found 470ohm to green JAMMA output)             ``` |
| ```Pin 91    G[4]      ```   |    ```IC6  Pin 19   Green[4] (Found 220ohm to green JAMMA output)             ``` |
| ```Pin 104   B[0]      ```   |    ```IC7  Pin 12   Blue[0] (Found 3.9Kohm to blue JAMMA output)              ``` |
| ```Pin 97    B[1]      ```   |    ```IC6  Pin 2    Blue[1] (Found 2.2Kohm to blue JAMMA output)              ``` |
| ```Pin 96    B[2]      ```   |    ```IC6  Pin 5    Blue[2] (Found 1Kohm to blue JAMMA output)                ``` |
| ```Pin 94    B[3]      ```   |    ```IC6  Pin 6    Blue[3] (Found 470ohm to blue JAMMA output)               ``` |
| ```Pin 93    B[4]      ```   |    ```IC6  Pin 9    Blue[4] (Found 220ohm to blue JAMMA output)               ``` |
| ```Pin 79    DAK       ```   |    ```IC7  Pin 19   DAK (Didn't check)                                        ``` |
| ```Pin 99    SHA       ```   |    ```IC8  Pin 4    SHA (Found 150ohm to red JAMMA output. See note)          ``` |
| ```Pin 103   SYNC      ```   |    ```IC6  Pin 1    Clear                                                     ``` |
| ```Pin 114   audioLR   ```   |    ```IC12 Pin 5    LRCK                                                      ``` |
| ```Pin 120   audioClk  ```   |    ```IC12 Pin 7    BCLK                                                      ``` |
| ```Pin 118   audioData ```   |    ```IC12 Pin 6    SDAT                                                      ``` |

Note IC8 is a 74LS05 which is open collector. Therefore we must use the inputs of the logic gate, otherwise it'd be effected by the other outputs when high. Be careful of this if transposing to a different board.

If you are doing this on an older Neo Geo with a YM3016 audio DAC then you need to change the audio connections.

| FPGA                         |  YM3016                                                                           |
| ---------------------------- |  -------------------------------------------------------------------------------- |
| ```Pin 114   audioLR   ```   |    ```Pin 8    SMP1                                                           ``` |
| ```Pin 112   audioLR2  ```   |    ```Pin 7    SMP2                                                           ``` |
| ```Pin 120   audioClk  ```   |    ```Pin 5    CLOCK                                                          ``` |
| ```Pin 118   audioData ```   |    ```Pin 4    SD                                                             ``` |

Previsional info for wiring on MV1-FS. Update coming

|IC           |Pin|Name | FPGA Pin  |
|-------------|---|-----|-----------|
|Left LS273   |2  |G480 | Pin 89    |
|Left LS273   |5  |G220 | Pin 91    |
|Left LS273   |6  |R3K8 | Pin 75    |
|Left LS273   |9  |R2K2 | Pin 92    |
|Left LS273   |12 |R1K0 | Pin 90    |
|Left LS273   |15 |R470 | Pin 87    |
|Left LS273   |16 |R220 | Pin 100   |
|Left LS273   |19 |DAK  | Pin 79    |
|Right LS273  |1  |!CLR | Pin 103   |
|Right LS273  |2  |B3K8 | Pin 104   |
|Right LS273  |5  |B2K2 | Pin 97    |
|Right LS273  |6  |B1K0 | Pin 96    |
|Right LS273  |9  |B470 | Pin 94    |
|Right LS273  |12 |B220 | Pin 93    |
|Right LS273  |15 |G3K8 | Pin 74    |
|Right LS273  |16 |G2K2 | Pin 101   |
|Right LS273  |19 |G1K0 | Pin 86    |
|LS05         |1  |!R150| Pin 99    |
|LS05         |2  |R150 |           |
|LS05         |4  |G150 |           |
|LS05         |6  |B150 |           |
|LS05         |8  |B8K3 |           |
|LS05         |10 |G8K3 |           |
|LS05         |12 |R8K3 |           |

*All lines go through 500Ohm/1KOhm resistor voltage dividers to get from 5V input to 3.3V output. Except NEOGEOCLK which is the only output from the FPGA and drives OSC input directly.*

FPGA dev board internals
------------------------

```
Pin 17    INCLK 50MHz clock
Pin 144   SWITCH
```

*INCLK goes through the PLL to generate 27MHz (pixclk) and 135MHz (pixclk72). SWITCH needs the weak internal pull up set to work.*
