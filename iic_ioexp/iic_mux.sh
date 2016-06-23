#!/bin/bash
echo cape-universal > /sys/devices/bone_capemgr.*/slots
cat /sys/devices/bone_capemgr.*/slots
config-pin p9.17 i2c
config-pin p9.18 i2c
config-pin -q p9.17
config-pin -q p9.18
