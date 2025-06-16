## KoboldCpp with Open-WebUI

Everyone asking for a drop-in Ollama replacement that works with Open-WebUI, well, here it is.

![Nobold](nobold.png)

**This will install KoboldCpp as a service on your machine! You have been warned.**

## Instructions

# Windows

Run nobold.bat

# Linux

Debian based distros:

Set execute permissions:

`chmod +x ./nobold-linux.sh`

Set which model you want to run by editing default.kcppt and adding the huggingface link to the appropriate fields. Also change context size, etc.

`nano default.kcppt`

Install:

`./nobold-linux.sh`

Enable PATH:

`source ~/.bashrc`

Enable kobold service on boot:

`sudo systemctl enable koboldcpp.service`

Start service:

`sudo systemctl start koboldcpp.service`

Start OpenWeb-UI:

`~/.koboldcpp/scripts/open-webui-start.sh`

To uninstall:

`./nobold-linux --uninstall`