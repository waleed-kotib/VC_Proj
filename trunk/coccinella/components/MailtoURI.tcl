# MailtoURI.tcl --
# 
#       Parses any in-text mailto: URIs.
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
# $Id: MailtoURI.tcl,v 1.8 2007-10-13 12:58:20 matben Exp $

package require uri
package require uriencode

namespace eval ::MailtoURI {}

proc ::MailtoURI::Init {} {

    # Perhaps we shal simplify this to: {^mailto:.+}
    variable mailtoRE $::uri::mailto::url
    
    ::Text::RegisterURI $mailtoRE ::MailtoURI::TextCmd
    component::register MaitoURI "Parses in-text mailto: URIs"
}

proc ::MailtoURI::TextCmd {uri} {
    global  this prefs
    
    if {$prefs(mailClient) eq "gmail"} {

	# http://gentoo-wiki.com/HOWTO_Open_mailto:_links_in_gmail
	# http://www.howtogeek.com/howto/ubuntu/set-gmail-as-default-mail-client-in-ubuntu/#comment-16706
	set base "https://mail.google.com/mail/?view=cm&tf=0&to="
	regsub {^mailto:([^&?]+)[&?]?(.*)$} $uri {\1\&\2} guri
	regsub {subject=} $guri {su=} guri
	set gmailuri $base$guri
	
	::Utils::OpenURLInBrowser $gmailuri
    } else {
	switch -- $this(platform) {
	    macosx {
		exec open $uri
	    }
	    unix {
		# Special.
		set mail [::Utils::UnixGetEmailClient]
		catch {exec $mail $uri &}
	    }
	    windows {
		::Windows::OpenURI $uri
	    }
	}
    }
}
