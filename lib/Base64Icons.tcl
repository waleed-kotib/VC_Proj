
#  Base64Icons.tcl ---
#  
#      This file is part of The Coccinella application. It contains
#      Mime (base 64) coded icons for the tool buttons and other icons.
#      
#  Copyright (c) 2002-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: Base64Icons.tcl,v 1.12 2004-11-18 07:34:01 matben Exp $
 
### First all the tool buttons, both on and off states. ########################

# Make sure we have the namespace.
namespace eval ::UI:: {}

    
# The mac look-alike triangles.
set ::UI::icons(mactriangleopen) [image create photo -data {
    R0lGODlhCwALAPMAAP///97e3s7O/729vZyc/4yMjGNjzgAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAACH5BAEAAAEALAAAAAALAAsAAAQgMMhJq7316M1P
    OEIoEkchHURKGOUwoWubsYVryZiNVREAOw==
}]
set ::UI::icons(mactriangleclosed) [image create photo -data {
    R0lGODlhCwALAPMAAP///97e3s7O/729vZyc/4yMjGNjzgAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAACH5BAEAAAEALAAAAAALAAsAAAQiMMgjqw2H3nqE
    3h3xWaEICgRhjBi6FgMpvDEpwuCBg3sVAQA7
}]

#-------------------------------------------------------------------------------
