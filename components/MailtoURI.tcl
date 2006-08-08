# MailtoURI.tcl --
# 
#       Parses any in-text mailto: URIs.
#       
# $Id: MailtoURI.tcl,v 1.2 2006-08-08 13:12:04 matben Exp $

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
    global  this
        
    switch -- $this(platform) {
	macosx {
	    exec open $uri
	}
	unix {
	    set mail [::Utils::UnixGetEmailClient]
	    catch {exec $mail $uri &}
	}
	windows {
	    ::Windows::OpenURI $uri
	}
    }
}


