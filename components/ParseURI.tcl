# ParseURI.tcl --
# 
#       Parses and executes any -uri xmpp:jid[?query] command line option.
#       typically from an anchor element <a href='xmpp:jid[?query]'/>
#       in a html page.
# 
# $Id: ParseURI.tcl,v 1.4 2004-07-30 12:55:53 matben Exp $

package require uriencode

namespace eval ::ParseURI:: { 

    variable uid 0
}

proc ::ParseURI::Init { } {

    ::Debug 2 "::ParseURI::Init"
    
    ::hooks::add launchFinalHook ::ParseURI::Parse
    
    component::register ParseURI  \
      {Any command line -uri xmpp:jid[?query] is parsed and processed.}
}

# ParseURI::Parse --
# 
# 

proc ::ParseURI::Parse { } {
    global  argv
    variable uid
    
    set ind [lsearch $argv -uri]
    if {$ind < 0} {
	return
    }
    set uri [lindex $argv [incr ind]]
    set uri [uriencode::decodeurl $uri]
    ::Debug 2 "::ParseURI::Parse uri=$uri"

    # Actually parse the uri.
    if {![regexp {^xmpp:([^\?]+)(\?([^&]+)&(.+))?$} $uri match jid x op query]} {
	return
    }
    
    # Initialize the state variable, an array, that keeps is the storage.
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state

    set state(uri)    $uri
    set state(jid)    $jid
    set state(op)     $op
    set state(query)  $query
    
    # Parse the query into an array.
    foreach sub [split $query &] {
	foreach {key value} [split $sub =] {break}
	set state(query,$key) $value
    }
    
    # Use our default profile account. 
    # Keep our own jid apart from jid in uri!
    set name [::Profiles::GetSelectedName]
    set domain [::Profiles::Get $name domain]
    set state(profname) $name
    set state(domain)   $domain
    
    ::Jabber::Login::Connect $domain [list [namespace current]::ConnectCB $token]
    parray state
}

proc ::ParseURI::ConnectCB {token status {msg {}}} {
    variable $token
    upvar 0 $token state
    
    puts "::ParseURI::ConnectCB status=$status"
    
    switch $status {
	error {
	    tk_messageBox -icon error -type ok -message [FormatTextForMessageBox \
	      [mc jamessnosocket $state(domain) $msg]]
	}
	timeout {
	    tk_messageBox -icon error -type ok -message [FormatTextForMessageBox \
	      [mc jamesstimeoutserver $state(domain)]]
	}
	default {
	    # Go ahead...
	    if {[catch {
		::Jabber::Login::InitStream $state(domain) \
		  [list [namespace current]::InitStreamCB $token]
	    } err]} {
		tk_messageBox -icon error -title [mc {Open Failed}] \
		  -type ok -message [FormatTextForMessageBox $err]
	    }
	}
    }
}

proc ::ParseURI::InitStreamCB {token args} {
    variable $token
    upvar 0 $token state
    
    puts "::ParseURI::InitStreamCB args='$args'"

    array set argsArr $args

    if {![info exists argsArr(id)]} {
	tk_messageBox -icon error -type ok -message \
	  "no id for digest in receiving <stream>"
	::ParseURI::Free $token
    } else {
	
	# We may need to ask for a password before preceding.
	set profname $state(profname)
	set password [::Profiles::Get $profname password]
	set ans "ok"
	if {$password == ""} {
	    set ans [::UI::MegaDlgMsgAndEntry  \
	      [mc {Password}]  \
	      "Enter a password for your account \"$state(jid)\""  \
	      "[mc Password]:"  \
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
	    ::Jabber::Login::Authorize $state(domain) $node $res $password \
	      [list [namespace current]::AuthorizeCB $token] \
	      -streamid $argsArr(id)
	} else {
	    ::ParseURI::Free $token
	}
    }
}

proc ::ParseURI::AuthorizeCB {token type msg} {
    variable $token
    upvar 0 $token state
    
    puts "::ParseURI::AuthorizeCB type=$type, msg=$msg"
    
    if {[string equal $type "error"]} {
	tk_messageBox -icon error -type ok -title [mc Error]  \
	  -message [FormatTextForMessageBox $msg]
    } else {
	::Jabber::Login::SetStatus
    }
  
    switch -- $state(op) {
	message {
	    ::ParseURI::DoMessage $token
	}
	presence {
	    ::ParseURI::DoPresence $token	    
	}
	groupchat {
	    ::ParseURI::DoGroupchat $token	    
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
    ::ParseURI::Free $token
}

proc ::ParseURI::DoPresence {token} {
    variable $token
    upvar 0 $token state
    
    # I don't understand why we should send directed presence when
    # we just sent global presence, or is this wrong?

    ::ParseURI::Free $token
}

proc ::ParseURI::DoGroupchat {token} {
    variable $token
    upvar 0 $token state
    
    # We brutaly assumes muc room here.
    ::Jabber::MUC::EnterRoom $state(jid) $state(query,nick)
    ::ParseURI::Free $token
}

proc ::ParseURI::Free {token} {
    variable $token
    upvar 0 $token state
    
    unset -nocomplain state
}

#-------------------------------------------------------------------------------
