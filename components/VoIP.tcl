# VoIP.tcl --
# 
#       Testing snack streaming audio over http.
#       This is just a first sketch.
#       
# $Id: VoIP.tcl,v 1.2 2004-12-02 15:22:07 matben Exp $

namespace eval ::VoIP:: {
    
}

proc ::VoIP::Init { } {
    global  this
    
    if {[catch {
	package require snack 2.2
	package require snackogg
	package require tinyhttpd
	package require httpex
    }]} {
	return
    }
    component::register VoIP "Streaming audio over http."

    # Add event hooks.
    ::hooks::register initHook  [namespace current]::InitHook
}

proc ::VoIP::InitHook { } {
    
    
    ::tinyhttpd::registercgicommand  audio.ogg  [namespace current]::Cgibin
    
}

proc ::VoIP::Cgibin {token} {
    variable $token
    upvar 0 $token state

    ::Debug 2 "::VoIP::Cgibin"
    
    set sock $state(s)
    
    # Put header.
    ::tinyhttpd::putheader $token 200 -headers \
      {Content-Type audio/ogg-vorbis}
    
    # Create sound object and attach it to the opened socket stream
    set sname [sound -channel $sock -channels 2 -rate 44100 -fileformat ogg]

    # Set desired bitrate
    $sname config -nominalbitrate 32000

    # Start recording
    $sname record
}

proc ::VoIP::Get {url} {
    
    
    set token [::httpex::get $url -command [namespace current]::HttpCmd \
      -handler [namespace current]::PlayStream]
    
}

proc ::VoIP::HttpCmd {token} {
    variable $token
    upvar 0 $token state

    ::Debug 2 "::VoIP::HttpCmd"
    
}

proc ::VoIP::PlayStream {sock token} {
        
    fileevent $sock readable ""
    ::httpex::cleanup $token
    set sound [::snack::sound -channel $socket]
    for {set i 0} {$i < 30} {incr i} {
	after 100
	append ::status .
	update
    }
    ::Debug 2 "stream type is [$sound info]"
    update
    $sound play -blocking 0
    return 0
}

#-------------------------------------------------------------------------------
