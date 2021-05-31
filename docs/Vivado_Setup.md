# Setup



Before installing on Ubuntu 20.0.4, you may need `libtinfo-dev`: https://forums.xilinx.com/t5/Installation-and-Licensing/Installation-of-Vivado-2020-2-on-Ubuntu-20-04/td-p/1185285

```
sudo apt update
sudo apt install libtinfo-dev
sudo ln -s /lib/x86_64-linux-gnu/libtinfo.so.6 /lib/x86_64-linux-gnu/libtinfo.so.5
```

After installing this, follow install instructions on Xilinx website.

## Potential issues


Vivado does not have board definition files initially. Need to add. See https://forums.xilinx.com/t5/Embedded-Development-Tools/ultra-96-v2-board-not-available-in-vivado/td-p/1051428

Potentially also see this tutorial: https://www.hackster.io/BryanF/ultra96-v2-vitis-2020-2-test-applications-9afcbe

