# ParseURI.tcl --
# 
#       Parses and executes any -uri xmpp:jid[?query] command line option.
#       typically from an anchor element <a href='xmpp:jid[?query]'/>
#       in a html page.
# 
# $Id: ParseURI.tcl,v 1.1 2004-07-27 14:24:23 matben Exp $

package require uriencode

namespace eval ::ParseURI:: { }

proc ::ParseURI::Init { } {

    ::Debug 2 "::ParseURI::Init"
    
    ::hooks::add launchFinalHook ::ParseURI::Parse
    
    component::register ::ParseURI::Init  \
      {Any command line -uri xmpp:jid[?query] is parsed and processed.}
}

# ParseURI::Parse --
# 
# 

proc ::ParseURI::Parse { } {
    global  argv
    
    set ind [lsearch $argv -uri]
    if {$ind < 0} {
	return
    }
    set uri [lindex $argv [incr ind]]
    set uri [uriencode::decodeurl $uri]
    ::Debug 2 "::ParseURI::Parse uri=$uri"

    if {![regexp {^xmpp:([^\?]+)(\?([^&]+)&(.+))?$} $uri match jid x op query]} {
	return
    }
    jlib::splitjidex $jid node domain res
    puts "jid=$jid, op=$op, query='$query'"
     
    # Parse the query into an array.
    foreach sub [split $query &] {
	foreach {key value} [split $sub =] {break}
	set queryArr($key) $value
    }
    parray queryArr

    switch -- $op {
	message {
	    
	}
	presence {
	    
	}
	groupchat {
	    
	}
    }
}

#-------------------------------------------------------------------------------
