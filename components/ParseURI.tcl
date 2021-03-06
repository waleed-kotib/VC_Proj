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
#       Reference:
#       RFC 3860
#       Common Profile for Instant Messaging (CPIM)
#
#     The syntax follows the existing mailto: URI syntax specified in RFC
#     2368.  The ABNF is:
#
#     IM-URI         = "im:" [ to ] [ headers ]
#     to             =  mailbox
#     headers        =  "?" header *( "&" header )
#     header         =  hname "=" hvalue
#     ...
#
#       Reference:
#       XMPP URI/IRI Querytypes 
#       XEP-0147: XMPP URI Scheme Query Components 
#
#  Copyright (c) 2007 Mats Bengtsson
#  
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#   
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#   
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# $Id: ParseURI.tcl,v 1.50 2008-06-09 09:50:59 matben Exp $

package require uriencode

namespace eval ::ParseURI { 

    component::define ParseURI "Command line XMPP uri parsing and processing"

    variable uid 0
}

proc ::ParseURI::Init {} {

    ::Debug 2 "::ParseURI::Init"
    
    ::hooks::register launchFinalHook   ::ParseURI::Parse
    ::hooks::register relaunchHook      ::ParseURI::RelaunchHook
    
    # A bit simplified xmpp URI.
    ::Text::RegisterURI {^xmpp:.+} ::ParseURI::TextCmd
    ::Text::RegisterURI {^im:.+}   ::ParseURI::TextCmd
    
    component::register ParseURI
}

proc ::ParseURI::TextCmd {uri} {
    Parse -uri $uri
}

# ParseURI::Parse --
# 
#       Uses any -uri in the command line and process it accordingly.

proc ::ParseURI::Parse {args} {
    global  argv jprefs
    variable uid
    
    if {$args eq {}} {
	set args $argv
    }
    set idx [lsearch $args -uri]
    if {$idx < 0} {
	return
    }
    set uri [lindex $args [incr idx]]
    set uri [::uri::urn::unquote $uri]
    
    ::Debug 2 "::ParseURI::Parse uri=$uri"

    # Actually parse the uri.

    set xmppRE {^xmpp:([^\?#]+)(\?([^;#]+)){0,1}(;([^#]+)){0,1}(#(.+)){0,1}$}
    set imRE {^im:([^\?]+)(\?(.+)){0,1}$}
    
    if {[regexp $xmppRE $uri - hierxmpp - iquerytype - querypairs - fragment]} {
	set type xmpp

	# authpath  = "//" authxmpp [ "/" pathxmpp ]
	set RE {^//([^/]+)/(.+$)}
	if {![regexp $RE $hierxmpp - authxmpp pathxmpp]} {
	    set authxmpp ""
	    set pathxmpp $hierxmpp
	}
	set querylist [list]
	foreach sub [split $querypairs ";"] {
	    foreach {key value} [split $sub =] {break}
	    lappend querylist $key $value
	}
    } elseif {[regexp $imRE $uri - mailbox - headers]} {
	
	# Interpret this in terms of the xmpp format.
	set type im
	set authxmpp ""
	set pathxmpp $mailbox
	set iquerytype message
	set fragment ""
	set querypairs $headers
	set querylist [list]
	foreach sub [split $querypairs "&"] {
	    foreach {key value} [split $sub =] {break}
	    lappend querylist $key $value
	}	
    } else {
	::Debug 2 "\t regexp failed"
	return
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

    foreach {key value} $querylist {
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
	variable ans "ok"
	if {$password eq ""} {
	    set w [ui::dialog -message [mc "Enter the password for your account %s" $state(jid)]  \
	      -icon info -type okcancel -modal 1  \
	      -variable [namespace current]::ans]
	    set fr [$w clientframe]
	    ttk::entry $fr.e -show {*}  \
	      -textvariable [namespace current]::password
	    pack $fr.e -side top -fill x
	    $w grab
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
	unset -nocomplain ans
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
	disco       -  
	invite      -
	join        -
	message     -
	probe       -
	pubsub      -
	recvfile    -
	register    -
	remove      -
	roster      -
	sendfile    -
	subscribe   -
	unregister  -
	unsubscribe - 
	vcard         {
	    Do[string totitle $state(iquerytype)] $token
	}
    }
}

proc ::ParseURI::DoDisco {token} {
    variable $token
    upvar 0 $token state
    
    set node ""
    set request info
    set type get
    set opts [list]
    foreach {key value} [array get state query,*] {
	
	switch -- $key {
	    query,node {
		lappend opts -node $value
	    }
	    query,request {
		set request $value
	    }
	    query,type {
		set type $value
	    }
	}
    }
    set cmd ::ParseURI::Noop
    if {$type eq "get"} {
	eval {::Jabber::Jlib disco send_get $request $cmd $state(jid)} $opts
    } else {
	# Not implemented
    }
    Free $token
}

proc ::ParseURI::DoInvite {token} {
    
    # Description: enables simultaneously joining a groupchat room and 
    # inviting others.
    HandleJoinGroupchat $token
}

proc ::ParseURI::DoJoin {token} {
    HandleJoinGroupchat $token
}

# This is old code where we first disco. This stage is now skipped.

proc ::ParseURI::DoJoinBU {token} {
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::ParseURI::DoJoin"
    
    # Get groupcat service from room.
    jlib::splitjidex $state(jid) roomname service res
    set state(service) $service
    set state(discocmd)  [list ::ParseURI::DiscoInfoHook $token]

    # We should check if we've got info before setting up the hooks.
    if {[set pathA([incr i]) disco isdiscoed info $service]} {
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
    HandleJoinGroupchat $token
}

proc ::ParseURI::HandleJoinGroupchat {token} {
    variable $token
    upvar 0 $token state
    
    ::Debug 2 "::ParseURI::HandleJoinGroupchat................"
    ::Debug 2 "state=[array get state]"
    
    # We require a nick name (resource part).
    set state(nick) $state(resource)
    if {$state(nick) eq ""} {
	variable ans
	set str [mc "Please enter your desired nickname for the chatroom %s" $state(jid2)]
	set w [ui::dialog -message $str -title [mc "Nickname"]  \
	  -icon info -type okcancel -modal 1  \
	  -variable [namespace current]::ans]
	set fr [$w clientframe]
	ttk::label $fr.l -text [mc "Nickname"]:
	ttk::entry $fr.e -textvariable $token\(nick)
	pack $fr.l -side left
	pack $fr.e -side top -fill x
	$w grab	
	if {($ans ne "ok") || ($state(nick) eq "")} {
	    Free $token
	    return
	}
	unset -nocomplain ans
    }
    
    # We brutaly assumes muc room here.
    set opts [list]
    if {[info exists state(query,password)]} {
	lappend opts -password $state(query,password)
    }
    eval {::Enter::EnterRoom $state(jid2) $state(nick) \
      -command [list [namespace current]::EnterRoomCB $token]} $opts
}

proc ::ParseURI::EnterRoomCB {token type args} {
    variable $token
    upvar 0 $token state
    
    ::Debug 2 "::ParseURI::EnterRoomCB"
        
    if {![string equal $type "error"]} {
	
	if {$state(iquerytype) eq "invite"} {
	    if {[info exists state(query,jid)]} {
		set tojid $state(query,jid)
		jlib::splitjid $state(jid) roomjid res
		::Jabber::Jlib muc invite $roomjid $tojid
	    }
	    
	    # Check that this is actually a whiteboard.
	} elseif {[info exists state(query,xmlns)] && \
	  [string equal $state(query,xmlns) "whiteboard"]} {
	    if {[::Jabber::HaveWhiteboard]} {
		::JWB::NewWhiteboardTo $state(jid2) -type groupchat
	    }
	}
    }
    Free $token
}

proc ::ParseURI::DoMessage {token} {
    variable $token
    upvar 0 $token state
    
    set opts [list]
    set type normal
    foreach {key value} [array get state query,*] {
	
	switch -- $key {
	    query,body {
		lappend opts -message $value
	    }
	    query,from {
		lappend opts -from $value
	    }
	    query,subject {
		lappend opts -subject $value
	    }
	    query,thread {
		lappend opts -thread $value
	    }
	    query,type {
		set type $value
	    }
	}
    }
        
    switch -- $type {
	normal {
	    eval {::NewMsg::Build -to $state(jid)} $opts	    
	}
	chat {
	    eval {::Chat::StartThread $state(jid)} $opts	    
	}
	groupchat {
	    # Not implemented since I don't understand it. Enter room first?
	}
    }
    Free $token
}

proc ::ParseURI::DoProbe {token} {
    variable $token
    upvar 0 $token state

    ::Jabber::Jlib send_presence -to $state(jid) -type "probe"
    Free $token
}

proc ::ParseURI::DoPubsub {token} {
    variable $token
    upvar 0 $token state

    set opts [list]
    set action subscribe
    foreach {key value} [array get state query,*] {
	
	switch -- $key {
	    query,action {
		set action $value
	    }
	    query,node {
		lappend opts -node $value
	    }
	}
    }
    if {![regexp {^(subscribe|unsubscribe)$} $action]} {
	Free $token
	return
    }
    set myjid [::Jabber::Jlib myjid]
    set myjid2 [jlib::barejid $myjid]
    eval {::Jabber::Jlib pubsub $action $state(jid) $myjid2} $opts
    Free $token
}

# set uri [jlib::ftrans::uri mari@jabber.se/z /Users/matben/Desktop/splash.svg image/svg]

proc ::ParseURI::DoRecvfile {token} {
    variable $token
    upvar 0 $token state

    # xmpp:romeo@montague.net/orchard?recvfile;sid=pub234;mime-type=text%2Fplain;name=reply.txt;size=2048 

    array set queryA [ExtractKeyValuePairs $token]
    
    # Without a 'sid' we can't continue.
    if {![info exists queryA(sid)]} {
	Free $token
	return
    }
    
    # We do a sipub request to get the file.
    ::Jabber::Jlib sipub start $state(jid) $queryA(sid) \
      [namespace code [list DoRecvfileCB $token]]
}

proc ::ParseURI::DoRecvfileCB {token type startingE} {
    global  prefs
    variable $token
    upvar 0 $token state
    
    # Some basic error checking.
    if {[wrapper::gettag $startingE] ne "starting"} {
	Free $token
	return
    }
    
    if {$type eq "result"} {
	
	set sid [wrapper::getattribute $startingE sid]

	set queryA(name) ""
	array set queryA [ExtractKeyValuePairs $token]

	set userDir [::Utils::GetDirIfExist $prefs(userPath)]
	set fileName [tk_getSaveFile -title [mc "Save File"] \
	  -initialfile $queryA(name) -initialdir $userDir]
	if {$fileName ne ""} {
	
	    set prefs(userPath) [file dirname $fileName]
	    set fd [open $fileName w]
	
	    set dlgtoken [::FTrans::ObjectReceive $state(jid) $fileName $queryA(size)]	    
	    
	    # We shall be prepared to get the si-set request.
	    ::Jabber::Jlib sipub set_accept_handler $sid \
	      -channel $fd \
	      -progress [list ::FTrans::TProgress $dlgtoken] \
	      -command  [list ::FTrans::TCommand $dlgtoken]
	}
    } else {
	ui::dialog -icon error -message ""
    }
    Free $token
}

proc ::ParseURI::DoRegister {token} {
    variable $token
    upvar 0 $token state

    ::GenRegister::NewDlg -server $state(jid) -autoget 1
    Free $token
}

proc ::ParseURI::DoRemove {token} {
    variable $token
    upvar 0 $token state

    ::Jabber::Jlib roster send_remove $state(jid)
    Free $token
}

proc ::ParseURI::DoRoster {token} {
    variable $token
    upvar 0 $token state

    set opts [list]
    foreach {key value} [array get state query,*] {
	
	switch -- $key {
	    query,group {
		lappend opts -groups [list $value]
	    }
	    query,name {
		lappend opts -name $value
	    }
	}
    }
    eval {::Jabber::Jlib roster send_set $state(jid)} $opts
    Free $token
}

proc ::ParseURI::DoSendfile {token} {
    variable $token
    upvar 0 $token state

    ::FTrans::Send $state(jid)
    Free $token
}

proc ::ParseURI::DoSubscribe {token} {
    variable $token
    upvar 0 $token state

    ::Jabber::Jlib roster send_set $state(jid)
    ::Jabber::Jlib send_presence -to $state(jid) -type "subscribe"
    Free $token
}

proc ::ParseURI::DoUnregister {token} {
    variable $token
    upvar 0 $token state

    ::Register::Remove $state(jid)
    Free $token
}

proc ::ParseURI::DoUnsubscribe {token} {
    variable $token
    upvar 0 $token state

    ::Jabber::Jlib send_presence -to $state(jid) -type "unsubscribe"
    Free $token
}

proc ::ParseURI::DoVcard {token} {
    variable $token
    upvar 0 $token state

    ::VCard::Fetch "other" $state(jid)
    Free $token
}

proc ::ParseURI::ExtractKeyValuePairs {token} {
    variable $token
    upvar 0 $token state

    set keyValueL [list]
    foreach {key value} [array get state query,*] {
	set bkey [string map [list "query," ""] $key]
	lappend keyValueL $bkey $value
    }
    return $keyValueL
}

proc ::ParseURI::Noop {args} { }

proc ::ParseURI::Free {token} {
    variable $token
    upvar 0 $token state
    
    unset -nocomplain state
}

#-------------------------------------------------------------------------------
