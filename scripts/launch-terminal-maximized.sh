#!/bin/bash
gnome-terminal &
sleep 0.5
wmctrl -r :ACTIVE: -b add,maximized_vert,maximized_horz

