
#  Base64Icons.tcl ---
#  
#      This file is part of The Coccinella application. It contains
#      Mime (base 64) coded icons for the tool buttons and other icons.
#      
#  Copyright (c) 2002-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: Base64Icons.tcl,v 1.11 2004-11-15 08:51:14 matben Exp $
 
### First all the tool buttons, both on and off states. ########################

# Make sure we have the namespace.
namespace eval ::UI:: {}


# General icon for minimal popup menu button.
set ::UI::icons(popupbt) [image create photo -data {
    R0lGODdhEAAOALMAAP///+/v797e3s7Ozr29va2trZycnJSUlIyMjHl5eXR0
    dHNzc2NjY1JSUkJCQgAAACwAAAAAEAAOAAAEYLDIIqoYg5A5iQhVthkGR4HY
    JhkI0gWgphUkspRn5ey8Yy+S0CDRcxRsjOAlUzwuGkERQcGjGZ6S1IxHWjCS
    hZkEcTC2vEAOieRDNlyrNevMaKQnrIXe+71zkF8MC3ASEQA7
}]
set ::UI::icons(popupbtpush) [image create photo -data {
    R0lGODdhEAAOAMQAAP///9DQ0M7Ozr29va2trZycnI2NjYyMjHZ2dnV1dXR0
    dHNzc29vb2NjY1JSUkJCQgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAACwAAAAAEAAOAAAFbqAgCsTSOGhTjMLgmk0s
    O4s7EGW8HEVxHKYDjnCI8Vy4HnBoWhBsN+WigIsVBoGHdvtQCAm0qwDBfRAS
    TvDUVjYs0g6VjbEluL/WIWELnOKKPD0FdAQKbzc4b4EHBg9vUyRDP5N9kFGC
    UjtULT0hADs=
}]
    
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
