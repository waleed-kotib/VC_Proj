# ParseURI.tcl --
# 
#       Parses and executes any -uri xmpp:jid[?query] command line option.
#       typically from an anchor element <a href='xmpp:jid[?query]'/>
#       in a html page.
#       
#       Most recent reference at the time of writing:
#       http://www.ietf.org/internet-drafts/draft-saintandre-xmpp-uri-06.txt
# 
# $Id: ParseURI.tcl,v 1.15 2004-11-11 15:38:28 matben Exp $

package require uriencode

namespace eval ::ParseURI:: { 

    variable uid 0
}

proc ::ParseURI::Init { } {

    ::Debug 2 "::ParseURI::Init"
    
    ::hooks::register launchFinalHook ::ParseURI::Parse
    ::hooks::register relaunchHook    ::ParseURI::RelaunchHook
    
    component::register ParseURI  \
      {Any command line -uri xmpp:jid[?query] is parsed and processed.}
}

# ParseURI::Parse --
# 
#       Uses any -uri in the command line and process it accordingly.

proc ::ParseURI::Parse {args} {
    global  argv
    variable uid
    upvar ::Jabber::jprefs jprefs
    
    if {$args == {}} {
	set args $argv
    }
    set ind [lsearch $args -uri]
    if {$ind < 0} {
	return
    }
    set uri [lindex $args [incr ind]]
    set uri [uriencode::decodeurl $uri]
    
    ::Debug 2 "::ParseURI::Parse uri=$uri"

    # Actually parse the uri.
    # {^xmpp:([^\?]+)(\?([^&]+)&(.+))?$}
    set reexp {^xmpp:([^\?#]+)(\?([^&]+)&([^#]+))?(#(.+))?$}
    set reexp {^xmpp:([^\?#]+)(\?([^&]+))?(&([^#]+))?(#(.+))?$}
    if {![regexp $reexp $uri match jid x querytype y query z fragment]} {
	return
    }
    jlib::splitjid $jid jid2 resource
    
    # Initialize the state variable, an array, that keeps is the storage.
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state

    set state(uri)       $uri
    set state(jid)       $jid
    set state(jid2)      $jid2
    set state(resource)  $resource
    set state(querytype) $querytype
    set state(query)     $query
    set state(fragment)  $fragment
    
    # Parse the query into an array.
    foreach sub [split $query &] {
	foreach {key value} [split $sub =] {break}
	set state(query,$key) $value
    }
    
    # Use our default profile account. 
    # Keep our own jid apart from jid in uri!
    set name   [::Profiles::GetSelectedName]
    set domain [::Profiles::Get $name domain]
    set state(profname) $name
    set state(domain)   $domain
    
    if {[::Jabber::IsConnected]} {
	ProcessURI $token
    } elseif {$jprefs(autoLogin)} {
	
	# Wait until logged in.
	::hooks::register loginHook   [list ::ParseURI::LoginHook $token]
    } else {
	set profname $state(profname)
	set password [::Profiles::Get $profname password]
	set ans "ok"
	if {$password == ""} {
	    set ans [::UI::MegaDlgMsgAndEntry  \
	      [mc {Password}] [mc enterpassword $state(jid)] "[mc Password]:" \
	      password [mc Cancel] [mc OK] -show {*}]
	}
	if {$ans == "ok"} {
	    set node [::Profiles::Get $profname node]
	    array set optsArr [::Profiles::Get $profname options]
	    if {[info exists optsArr(-resource)] && ($optsArr(-resource) != "")} {
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
	    eval {::Jabber::Login::HighLogin $state(domain) $node $res $password \
	      [list [namespace current]::LoginCB $token]} [array get optsArr]
	} else {
	    Free $token
	}
    }
}

#       Note that we have got two tokens here, the first one our own,
#       the second from the login.

proc ::ParseURI::LoginCB {token logtoken status {errmsg ""}} {
    
    ::Jabber::Login::ShowAnyMessageBox $logtoken $status $errmsg
    if {$status == "ok"} {
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
  
    switch -- $state(querytype) {
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
	eval {::Jabber::Chat::StartThread $state(jid) -thread $thread} $opts
    } else {
	eval {::Jabber::NewMsg::Build -to $state(jid)} $opts
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
    
    # Get groupcat service from room.
    jlib::splitjidex $state(jid) roomname service res
    set state(service) $service

    set state(browsecmd) [list ::ParseURI::BrowseSetHook $token]
    set state(discocmd)  [list ::ParseURI::DiscoInfoHook $token]

    # We should check if we've got info before setting up the hooks.
    if {[$jstate(disco) isdiscoed info $service]} {
	DiscoInfoHook $token result $service {}
    } elseif {[$jstate(browse) isbrowsed $service]} {
	BrowseSetHook $token $service {}
    } else {    
	
	# These must be one shot hooks.
	::hooks::register browseSetHook  $state(browsecmd)
	::hooks::register discoInfoHook  $state(discocmd)
    }
}

proc ::ParseURI::BrowseSetHook {token from subiq} {
    variable $token
    upvar 0 $token state
    
    set server [::Jabber::GetServerJid]
    if {![jlib::jidequal $from $server]} {
	return
    }
    HandleGroupchat $token
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
    
    ::hooks::deregister  browseSetHook  $state(browsecmd)
    ::hooks::deregister  discoInfoHook  $state(discocmd)
    
    ::Debug 2 [parray state]
    
    # We require a nick name (resource part).
    set nick $state(resource)
    if {$nick == ""} {
	set ans [::UI::MegaDlgMsgAndEntry  \
	  [mc {Nick name}] \
	  "Please enter your desired nick name for the room $state(jid2)" \
	  "[mc {Nick name}]:" \
	  nick [mc Cancel] [mc OK]]
	if {($ans != "ok") || ($nick == "")} {
	    return
	}
    }
    
    # We brutaly assumes muc room here.
    set opts {}
    if {[info exists state(query,password)]} {
	lappend opts -password $state(query,password)
    }
    eval {::Jabber::MUC::EnterRoom $state(jid2) $nick \
      -command [list [namespace current]::EnterRoomCB $token]} $opts
}

proc ::ParseURI::EnterRoomCB {token type args} {
    variable $token
    upvar 0 $token state
        
    if {![string equal $type "error"]} {
	
	# Check that this is actually a whiteboard.
	if {[info exists state(query,xmlns)] && \
	  [string equal $state(query,xmlns) "whiteboard"]} {
	    ::Jabber::WB::NewWhiteboardTo $state(jid)
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
