# VoIP.tcl --
# 
#       Testing snack streaming audio over http.
#       This is just a first sketch.
#       
# $Id: VoIP.tcl,v 1.3 2005-03-02 13:49:40 matben Exp $

# TODO:
#   use caps to announce feature in more detail.

namespace eval ::VoIP:: {
    
}

proc ::VoIP::Init { } {
    global  this
    
    return
    
    if {[catch {
	package require snack 2.2
	package require snackogg
	package require tinyhttpd
	package require httpex
    }]} {
	return
    }
    if {![HaveSupport]} {
	return
    }
    component::register VoIP "Streaming audio over http."

    # Add event hooks.
    # We must let both jabber and the httpd server to be finished.
    ::hooks::register launchFinalHook  [namespace current]::InitHook
    
    variable voipxmlns http://coccinella.sourceforge.net/protocol/voip
    variable buffermillis 2000
    
    # state(status):
    #       ""          inactive state
    #       calling     initiated a call
    #       talking     negotiating completed and both active
    variable state
}

proc ::VoIP::InitHook { } {
    global  this prefs
    variable voipurl
    variable voipxmlns
    variable state
    
    set oggfile voip.ogg
    
    # Register a caps key so that other clients know our capability.
    ::Jabber::RegisterCapsExtKey voip_ogg_vorbis [MakeCapsElement]

    # Roster popup.
    set popMenuSpec [list "VoIP..." {user available} {::VoIP::RosterCmd $jid3}]
    ::Jabber::UI::RegisterPopupEntry roster $popMenuSpec

    # Register our cgibin handler.
    ::tinyhttpd::registercgicommand  $oggfile  [namespace current]::Cgibin
    
    # Register handler for namespaced iq element.
    ::Jabber::JlibCmd iq_register set  $voipxmlns  [namespace current]::IQSetHandler

    # Find our voip to show for others.
    set ip   [::Network::GetThisPublicIP]
    set port $prefs(httpdPort)
    set cgibinrelative [::tinyhttpd::configure -cgibinrelativepath]
    set voipurl "http://${ip}:${port}/$cgibinrelative/$oggfile"
    
    # Only a single session is allowed and the state variable keeps record.
    set state(status) ""
    
    # testing...
    
    ::tinyhttpd::registercgicommand  voip.mp3  [namespace current]::CgibinMP3
    
}

proc ::VoIP::MakeCapsElement { } {
    
    variable voipxmlns

    set xmlnsdiscoinfo "http://jabber.org/protocol/disco#info"

    set capsElem [list [wrapper::createtag "identity" -attrlist  \
      [list category hierarchy type leaf name "Ogg Vorbis VoIP"]]]
    lappend capsElem [wrapper::createtag "feature" \
      -attrlist [list var $xmlnsdiscoinfo]]
    lappend capsElem [wrapper::createtag "feature" \
      -attrlist [list var $voipxmlns]]

    return $capsElem
}

proc ::VoIP::RosterCmd {jid} {
    
    set exts [::Jabber::RosterCmd getcapsattr $jid ext]
    if {[Busy]} {
	::UI::MessageBox -title [mc Error] -icon error \
	  -message "We already have a conversation that is still open"
    } elseif {[lsearch $exts voip_ogg_vorbis] < 0} {
	::UI::MessageBox -title [mc Error] -icon error \
	  -message "The user $jid has no support for VoIP"
    } else {
	Call $jid
    }
}

proc ::VoIP::Cgibin {token} {
    variable $token
    upvar 0 $token httpstate
    variable state

    ::Debug 2 "::VoIP::Cgibin"

    set sock $httpstate(s)

    # Verify that we do not already have a stream.
    if {[info exists state(sound,record)]} {
	::tinyhttpd::putheader $token 409
	close $sock
	return
    }
    
    # Put header.
    ::tinyhttpd::putheader $token 200 -headers {Content-Type audio/ogg-vorbis}
    
    # Create sound object and attach it to the opened socket stream
    set sname [snack::sound -channel $sock -channels 2 -rate 44100  \
      -fileformat ogg -debug 0]

    # Set desired bitrate
    $sname config -nominalbitrate 32000

    # Start recording
    $sname record
    
    set state(sound,record) $sname
    set state(socket,httpd) $sock
    set state(token,httpd)  $token
}
    
proc ::VoIP::HaveSupport { } {
    
    if {[snack::audio inputDevices] == {}} {
	return 0
    }
    if {[snack::audio outputDevices] == {}} {
	return 0
    }
    return 1
}

proc ::VoIP::GetStatus { } {
    
    variable state
    
    return $state(status)
}

proc ::VoIP::Busy { } {
    
    variable state

    if {[snack::audio active]} {
	return 1
    } elseif {$state(status) != ""} {
	return 1
    } else {
	return 0
    }
}

proc ::VoIP::Call {jid} {
    
    variable voipxmlns    
    variable voipurl
    variable state
    
    puts "::VoIP::Call jid=$jid"
    
    if {$state(status) != ""} {
	return -code error "cannot make a call while active"
    }
    set state(jid)    $jid
    set state(status) "calling"
    
    set callElem [wrapper::createtag "call" -attrlist [list url $voipurl]]
    set queryElem [wrapper::createtag "query"  \
      -subtags [list $callElem] -attrlist [list xmlns $voipxmlns]]
    
    ::Jabber::JlibCmd send_iq "set" $queryElem -to $jid \
      -command [namespace current]::CallCB
}

proc ::VoIP::CallCB {type subiq args} {
    
    variable state
    
    puts "::VoIP::CallCB type=$type, subiq=$subiq"

    if {$type == "error"} {
	::UI::MessageBox -title [mc Error] -icon error \
	  -message "We failed to make a call to $state(jid)"
	# close down...
    } else {
	set cmdElem [lindex [wrapper::getchildren $subiq] 0]
	set cmd [wrapper::gettag $cmdElem]
    
	switch -- $cmd {
	    busy {
		::UI::MessageBox -title [mc Error] -icon error \
		  -message "$state(jid) is busy"
	    }
	    answer {
		set url [wrapper::getattribute $cmdElem url]
		HandleAnswer $url
	    }
	    default {
		# error
	    }
	}
    }
}

proc ::VoIP::IQSetHandler {jlibname from subiq args} {

    variable state
    
    puts "::VoIP::IQSetHandler from=$from, subiq=$subiq"
    
    array set argsArr $args
   
    # Return any id!
    set opts {}
    if {[info exists argsArr(-id)]} {
	set opts [list -id $argsArr(-id)]
    }
    lappend opts -to $from

    if {![HaveSupport]} {
	SendError "cancel" $subiq $opts
    } elseif {[Busy]} {
	set busyElem  [wrapper::createtag "busy"]
	set queryElem [wrapper::createtag "query"  \
	  -subtags [list $callElem] -attrlist [list xmlns $voipxmlns]]
	eval {::Jabber::JlibCmd send_iq "result" $queryElem} $opts
    } else {
	
	# What is this: call or close.
	set cmdElem [lindex [wrapper::getchildren $subiq] 0]
	set cmd [wrapper::gettag $cmdElem]
	
	switch -- $cmd {
	    call {
		set url [wrapper::getattribute $cmdElem url]
		HandleCall $from $url $opts
	    }
	    close {
		HandleClose
	    }
	    default {
		SendError "cancel" $subiq $opts
	    }
	}
    }
    return 1
}

proc ::VoIP::SendError {type subiq opts} {
    
    set subElem [wrapper::createtag $type -attrlist \
      [list xmlns "urn:ietf:params:xml:ns:xmpp-stanzas"]]
    set errElem [wrapper::createtag "error" -attrlist \
      [list type cancel] -subtags [list $subElem]]
    eval {::Jabber::JlibCmd send_iq "error" [list $subiq $errElem]} $opts
}

proc ::VoIP::HandleCall {from url opts} {
    
    variable state
    
    puts "::VoIP::HandleCall from=$from, url=$url"
    
    set state(status) "pending"
    set ans [::UI::MessageBox -title [mc Error] -icon info -type yesno \
      -message "$state(jid) is calling you. Do you want to answer?"]
    if {$ans == "no"} {
	set state(status) ""
    } else {
	set state(status) "answer"
	Answer $from $url $opts
	Get $url
    }
}

proc ::VoIP::HandleAnswer {url} {
    
    variable state
    
    puts "::VoIP::HandleAnswer url=$url"
        
    Get $url
}

proc ::VoIP::HandleClose { } {
    
    variable state
    
    catch {
	if {[info exists state(sound,play)]} {
	    $state(sound,play) destroy
	}
	if {[info exists state(sound,record)]} {
	    $state(sound,record) destroy
	}
    }
    catch {
	close $state(socket,play)
	close $state(socket,httpd)
    }
    unset -nocomplain state
    set state(status) ""
}

proc ::VoIP::Close { } {
    
    variable state
    
    set busyElem  [wrapper::createtag "close"]
    set queryElem [wrapper::createtag "query"  \
      -subtags [list $callElem] -attrlist [list xmlns $voipxmlns]]
    ::Jabber::JlibCmd send_iq "set" $queryElem -to $state(jid) \
      -command [namespace current]::CloseCB
}

proc ::VoIP::CloseCB {type subiq args} {
    
    variable state
    
    puts "::VoIP::CloseCB type=$type, subiq=$subiq"
    
    # We don't care what type (error or result), just kill!
    HandleClose
}

proc ::VoIP::Answer {jid url opts} {
    
    variable voipxmlns
    variable voipurl
    variable state

    puts "::VoIP::Answer"
    
    set callElem [wrapper::createtag "answer" -attrlist [list url $voipurl]]
    set queryElem [wrapper::createtag "query"  \
      -subtags [list $callElem] -attrlist [list xmlns $voipxmlns]]
    eval {::Jabber::JlibCmd send_iq "result" $queryElem} $opts
}

proc ::VoIP::SendIQ {tag} {
    
    
    
}

proc ::VoIP::Get {url} {
    
    variable state
    
    set state(status) "contacting"
    set token [::httpex::get $url -command [namespace current]::HttpCmd \
      -handler [namespace current]::PlayStream]
    set state(token) $token
}

proc ::VoIP::HttpCmd {token} {
    variable $token
    upvar 0 $token httpstate

    ::Debug 2 "::VoIP::HttpCmd [::httpex::status $token]"
    
    # Don't bother with intermediate callbacks.
    if {![string equal [::httpex::state $token] "final"]} {
	return
    } 
    
    # We are final here.
    set status  [::httpex::status $token]
    set ncode   [::httpex::ncode $token]
    set httperr [::httpex::error $token]

    switch -- $status {
	timeout {
	    ::UI::MessageBox -title [mc Error] -icon error \
	      -message "timeout $state(jid)"
	}
	error - eof {
	    ::UI::MessageBox -title [mc Error] -icon error \
	      -message "$status $state(jid)"
	}
	ok {
	    if {$ncode != 200} {

	    } else {
		::UI::MessageBox -title [mc Error] -icon error \
		  -message "http error $ncode, $state(jid)"
	    }
	}
	reset {

	}
    }
}

proc ::VoIP::PlayStream {sock token} {
        
    variable state
    variable buffermillis
    variable buffertrigger
    
    puts "::VoIP::PlayStream"
    
    # cleanup 
    fileevent $sock readable ""
    ::httpex::cleanup $token
    
    set sname [::snack::sound -channel $sock -debug 0]
    if {0} {
	after $buffermillis [list set [namespace current]::buffertrigger 1]
	tkwait variable [namespace current]::buffertrigger
	unset -ncomplain buffertrigger
    } else {
	puts -nonewline stdout "Buffering..."
	flush stdout
	for {set i 0} {$i < 30} {incr i} {
	    after 100
	    puts -nonewline stdout .
	    flush stdout
	}
    }
    puts "stream type is [$sname info]"
    update
    $sname play -blocking 0

    set state(socket,play) $sock
    set state(sound,play)  $sname
    
    # Return number of bytes read but we have already cleaned up token.
    return 0
}

# For testing only..............................................................

proc ::VoIP::CgibinMP3 {token} {
    variable $token
    upvar 0 $token httpstate
    variable state

    ::Debug 2 "::VoIP::Cgibin"

    set sock $httpstate(s)

    # Verify that we do not already have a stream.
    if {[info exists state(sound,record)]} {
	::tinyhttpd::putheader $token 409
	close $sock
	return
    }
    
    # Put header.
    ::tinyhttpd::putheader $token 200 -headers {Content-Type audio/mpeg}
    
    # Create sound object and attach it to the opened socket stream
    set sname [snack::sound -channel $sock -rate 44100  \
      -fileformat mp3 -debug 4]

    # Start recording
    $sname record
    
    set state(sound,record) $sname
    set state(socket,httpd) $sock
    set state(token,httpd)  $token
}

#-------------------------------------------------------------------------------
