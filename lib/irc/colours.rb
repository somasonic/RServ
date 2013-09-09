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
 
WHITE           =   "\30"
BLACK           =   "\31"
DARKBLUE        =   "\32"
GREEN           =   "\33"
RED             =   "\34"
DARKRED         =   "\35"
VIOLET          =   "\36"
ORANGE          =   "\37"
YELLOW          =   "\38"
LIGHTGREEN      =   "\39"
CYAN            =   "\310"
LIGHTCYAN       =   "\311"
BLUE            =   "\312"
LIGHTVIOLET     =   "\313"
GRAY            =   "\314"
LIGHTGRAY       =   "\315"  
