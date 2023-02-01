#!/bin/bash
echo "Setting up vault local cluster - only works on a MAC"

sudo ifconfig lo0 alias 127.0.0.2
sudo ifconfig lo0 alias 127.0.0.3
sudo ifconfig lo0 alias 127.0.0.4

