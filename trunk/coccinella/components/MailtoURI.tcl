# MailtoURI.tcl --
# 
#       Parses any in-text mailto: URIs.
#       
# $Id: MailtoURI.tcl,v 1.1 2006-08-07 12:36:55 matben Exp $

package require uri
package require uriencode

namespace eval ::MailtoURI {}

proc ::MailtoURI::Init { } {

    # Perhaps we shal simplify this to: {^mailto:.+}
    variable mailtoRE $::uri::mailto::url
    
    ::Text::RegisterURI $mailtoRE ::MailtoURI::TextCmd
    component::register MaitoURI {Parses any in-text mailto: URIs}
}

proc ::MailtoURI::TextCmd {uri} {
    global  this prefs
    
    set prefs(mailClient) ""
    
    switch -- $this(platform) {
	macosx {
	    exec open $uri
	}
	unix {
	    if {[info exists env(MAIL)]} {
		if {[llength [auto_execok $env(MAIL)]] > 0} {
		    set mailClient $env(MAIL)
		}
	    }
	    set cmd [auto_execok $prefs(mailClient)]
	    if {$cmd == {}} {
		foreach name {thunderbird kmail} {
		    if {[llength [set e [auto_execok $name]]] > 0} {
			set mailClient [lindex $e 0]
			break
		    }
		}
	    }
	    set prefs(mailClient) $mailClient
	    catch {
		exec $mailClient $uri
	    }
	}
	windows {
	    ::Windows::OpenURI $uri
	}
    }
}


