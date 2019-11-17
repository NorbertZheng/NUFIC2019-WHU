# PYNQ_DMA example

This repository contains a PYNQ DMA benchmark project. The Vivado design contains only the PS, the DMA and an AXI4-Stream Data FIFO. 
The FIFO is used to make a feedback loop between the MM2S and S2MM of the DMA.

![Vivado Block Design](https://github.com/Fassial/NUFIC2019-WHU/tree/master/source_code/PL/PYNQ_DMA/test/disp_design/system.png)

## Vivado Project

In the folder vivado of this repository there is a tcl script that can be used to rebuild the overlay with Vivado 2018.3. Please note that is a simplified version of the base overlay provided by Avnet.

```
vivado -mode batch -source PYNQ_DMA.tcl
```
