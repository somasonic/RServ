#!/usr/bin/env ruby
# colour codes
# they can be used in the following format
# 
# @psuedoclient.privmsg("#opers", "#{BOLD}BOLD TEXT:#{COLOR}#{RED}This text is red.#{COLOR}")
#
# thanks to rylai for this.

BOLD      = "\2"
COLOR     = "\3"
COLOUR    = "\3"
ITALIC    = "\9"
UNDERLINE = "\x1F"
 
WHITE           =   COLOR + 0
BLACK           =   COLOR + 1
DARKBLUE        =   COLOR + 2
GREEN           =   COLOR + 3
RED             =   COLOR + 4
DARKRED         =   COLOR + 5
VIOLET          =   COLOR + 6
ORANGE          =   COLOR + 7
YELLOW          =   COLOR + 8
LIGHTGREEN      =   COLOR + 9
CYAN            =   COLOR + 10
LIGHTCYAN       =   COLOR + 11
BLUE            =   COLOR + 12
LIGHTVIOLET     =   COLOR + 13
GRAY            =   COLOR + 14
LIGHTGRAY       =   COLOR + 15  