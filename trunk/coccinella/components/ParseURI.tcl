# ParseURI.tcl --
# 
#       Parses and executes any -uri xmpp:jid[?query] command line option.
#       typically from an anchor element <a href='xmpp:jid[?query]'/>
#       in a html page.
#       
#       Reference: 
#       RFC 4622
#       Internationalized Resource Identifiers (IRIs)
#       and Uniform Resource Identifiers (URIs) for
#       the Extensible Messaging and Presence Protocol (XMPP)
#       
#       A citation:
#       
#     xmppuri   = "xmpp" ":" hierxmpp [ "?" querycomp ] [ "#" fragment ]
#     hierxmpp  = authpath / pathxmpp                                     OR
#     authpath  = "//" authxmpp [ "/" pathxmpp ]
#     authxmpp  = nodeid "@" host
#     pathxmpp  = [ nodeid "@" ] host [ "/" resid ]
#     ...
#     querycomp = querytype [ *pair ]
#     querytype = *( unreserved / pct-encoded )
#     pair      = ";" key "=" value
#     key       = *( unreserved / pct-encoded )
#     value     = *( unreserved / pct-encoded )
#     
#       Example:
#         
#       The following XMPP IRI/URI signals the processing application to 
#       authenticate as "guest@example.com" and to send a message to 
#       "support@example.com":
#
#         xmpp://guest@example.com/support@example.com?message
# 
#       By contrast, the following XMPP IRI/URI signals the processing
#       application to authenticate as its configured default account and to
#       send a message to "support@example.com":
#
#         xmpp:support@example.com?message
#
# $Id: ParseURI.tcl,v 1.27 2006-08-06 13:22:05 matben Exp $

package require uriencode

namespace eval ::ParseURI:: { 

    variable uid 0
}

proc ::ParseURI::Init { } {

    ::Debug 2 "::ParseURI::Init"
    
    ::hooks::register launchFinalHook   ::ParseURI::Parse
    ::hooks::register relaunchHook      ::ParseURI::RelaunchHook
    
    # A bit simplified xmpp URI.
    ::Text::RegisterURI {^xmpp:.+} ::ParseURI::TextCmd
    
    component::register ParseURI  \
      {Any command line -uri xmpp:jid[?query] is parsed and processed.}
}

proc ::ParseURI::TextCmd {uri} {
    Parse -uri $uri
}

# ParseURI::Parse --
# 
#       Uses any -uri in the command line and process it accordingly.

proc ::ParseURI::Parse {args} {
    global  argv
    variable uid
    upvar ::Jabber::jprefs jprefs
    
    if {$args eq {}} {
	set args $argv
    }
    set idx [lsearch $args -uri]
    if {$idx < 0} {
	return
    }
    set uri [lindex $args [incr idx]]
    set uri [uriencode::decodeurl $uri]
    
    ::Debug 2 "::ParseURI::Parse uri=$uri"

    # Actually parse the uri.
    set re {^xmpp:([^\?#]+)(\?([^;#]+)){0,1}(;([^#]+)){0,1}(#(.+)){0,1}$}
    if {![regexp $re $uri - hierxmpp - iquerytype - querypairs - fragment]} {
	::Debug 2 "\t regexp failed"
	return
    }
    
    # authpath  = "//" authxmpp [ "/" pathxmpp ]
    set re {^//([^/]+)/(.+$)}
    if {![regexp $re $hierxmpp - authxmpp pathxmpp]} {
	set authxmpp ""
	set pathxmpp $hierxmpp
    }
    
    set jid $pathxmpp
    jlib::splitjid $jid jid2 resource
    
    # Initialize the state variable, an array, that keeps is the storage.
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state

    set state(uri)        $uri
    set state(pathxmpp)   $pathxmpp
    set state(jid)        $jid
    set state(jid2)       $jid2
    set state(resource)   $resource
    set state(authxmpp)   $authxmpp
    set state(iquerytype) $iquerytype
    set state(querypairs) $querypairs
    set state(fragment)   $fragment
    
    # Parse the query into an array.
    foreach sub [split $querypairs ";"] {
	foreach {key value} [split $sub =] {break}
	set state(query,$key) $value
    }
    
    if {$authxmpp eq ""} {
	
	# Use our default profile account. 
	# Keep our own JID apart from JID in uri!
	set name       [::Profiles::GetSelectedName]
	set authDomain [::Profiles::Get $name domain]
	set authNode   [::Profiles::Get $name node]
	set password   [::Profiles::Get $name password]
	set state(profname)   $name
	set state(authNode)   $authNode
	set state(authDomain) $authDomain
    } else {
	
	# We are given a bare JID. Try find matching profile if any.
	set name [::Profiles::FindProfileNameFromJID $authxmpp]
	set state(profname) $name
	jlib::splitjidex $authxmpp authNode authDomain -
	set state(authNode)   $authNode
	set state(authDomain) $authDomain
	if {$name ne {}} {
	    set password [::Profiles::Get $name password]
	} else {
	    set password ""
	}
    }
    
    if {[::Jabber::IsConnected]} {
	
	# How to treat any authxmpp?
	ProcessURI $token
    } elseif {$jprefs(autoLogin)} {
	
	# Wait until logged in.
	::hooks::register loginHook   [list ::ParseURI::LoginHook $token]
    } else {
	set profname $state(profname)
	set ans "ok"
	if {$password eq ""} {
	    set ans [::UI::MegaDlgMsgAndEntry  \
	      [mc {Password}] [mc enterpassword $state(jid)] "[mc Password]:" \
	      password [mc Cancel] [mc OK] -show {*}]
	}
	if {$ans eq "ok"} {
	    array set optsArr [::Profiles::Get $profname options]
	    if {[info exists optsArr(-resource)] && ($optsArr(-resource) ne "")} {
		set res $optsArr(-resource)
	    } else {
		set res "coccinella"
	    }
	    array set optsArr [::Profiles::Get $profname options]
	    
	    # We may override or set some of these options using specific 
	    # query key-value pairs from the uri.
	    foreach key {sasl ssl priority invisible ip} {
		if {[info exists state(query,$key)]} {
		    set optsArr(-$key) $state(query,$key)
		}
	    }
	    
	    # Use a "high-level" login application api for this.
	    eval {::Login::HighLogin $authDomain $authNode $res $password \
	      [list [namespace current]::LoginCB $token]} [array get optsArr]
	} else {
	    Free $token
	}
    }
}

#       Note that we have got two tokens here, the first one our own,
#       the second from the login.

proc ::ParseURI::LoginCB {token htoken {errcode ""} {errmsg ""}} {
    
    if {$errcode eq ""} {
	ProcessURI $token
    }
}

proc ::ParseURI::LoginHook {token} {
    
    ::hooks::deregister loginHook   ::ParseURI::LoginHook
    ProcessURI $token
}

proc ::ParseURI::RelaunchHook {args} {
    
    eval {Parse} $args
}

proc ::ParseURI::ProcessURI {token} {
    variable $token
    upvar 0 $token state
    
    ::Debug 2 "::ParseURI::ProcessURI iquerytype=$state(iquerytype)"
  
    switch -- $state(iquerytype) {
	message {
	    DoMessage $token
	}
	presence {
	    DoPresence $token	    
	}
	groupchat {
	    DoGroupchat $token	    
	}
    }
}

proc ::ParseURI::DoMessage {token} {
    variable $token
    upvar 0 $token state
    
    set opts {}
    foreach {key value} [array get state query,*] {
	
	switch -- $key {
	    query,body {
		lappend opts -message $value
	    }
	    query,subject {
		lappend opts -subject $value
	    }
	    query,thread {
		set thread $value
	    }
	}
    }
    
    # Chat or normal message?
    if {[info exists thread]} {
	eval {::Chat::StartThread $state(jid) -thread $thread} $opts
    } else {
	eval {::NewMsg::Build -to $state(jid)} $opts
    }
    Free $token
}

proc ::ParseURI::DoPresence {token} {
    variable $token
    upvar 0 $token state
    
    # I don't understand why we should send directed presence when
    # we just sent global presence, or is this wrong?

    Free $token
}

proc ::ParseURI::DoGroupchat {token} {
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::ParseURI::DoGroupchat"
    
    # Get groupcat service from room.
    jlib::splitjidex $state(jid) roomname service res
    set state(service) $service

    set state(discocmd)  [list ::ParseURI::DiscoInfoHook $token]

    # We should check if we've got info before setting up the hooks.
    if {[$jstate(jlib) disco isdiscoed info $service]} {
	DiscoInfoHook $token result $service {}
    } else {    
	
	# These must be one shot hooks.
	::hooks::register discoInfoHook  $state(discocmd)
    }
}

proc ::ParseURI::DiscoInfoHook {token type from subiq args} {
    variable $token
    upvar 0 $token state

    if {![jlib::jidequal $from $state(service)]} {
	return
    }
    HandleGroupchat $token
}

proc ::ParseURI::HandleGroupchat {token} {
    variable $token
    upvar 0 $token state
    
    ::hooks::deregister  discoInfoHook  $state(discocmd)
    
    ::Debug 2 "::ParseURI::HandleGroupchat................"
    ::Debug 2 [parray state]
    
    # We require a nick name (resource part).
    set nick $state(resource)
    if {$nick eq ""} {
	set ans [::UI::MegaDlgMsgAndEntry  \
	  [mc {Nick name}] \
	  "Please enter your desired nick name for the room $state(jid2)" \
	  "[mc {Nick name}]:" \
	  nick [mc Cancel] [mc OK]]
	if {($ans ne "ok") || ($nick eq "")} {
	    return
	}
    }
    
    # We brutaly assumes muc room here.
    set opts {}
    if {[info exists state(query,password)]} {
	lappend opts -password $state(query,password)
    }
    eval {::Enter::EnterRoom $state(jid2) $nick \
      -command [list [namespace current]::EnterRoomCB $token]} $opts
}

proc ::ParseURI::EnterRoomCB {token type args} {
    variable $token
    upvar 0 $token state
    
    ::Debug 2 "::ParseURI::EnterRoomCB"
        
    if {![string equal $type "error"]} {
	
	# Check that this is actually a whiteboard.
	if {[info exists state(query,xmlns)] && \
	  [string equal $state(query,xmlns) "whiteboard"]} {
	    ::Jabber::WB::NewWhiteboardTo $state(jid2) -type groupchat
	}
    }
    Free $token
}

proc ::ParseURI::Free {token} {
    variable $token
    upvar 0 $token state
    
    unset -nocomplain state
}

#-------------------------------------------------------------------------------
