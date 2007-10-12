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
# $Id: MailtoURI.tcl,v 1.6 2007-10-12 06:56:29 matben Exp $

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
    global  this
    
    switch -- $this(platform) {
	macosx {
	    exec open $uri
	}
	unix {
	    # Special.
	    set mail [::Utils::UnixGetEmailClient]
	    if {$mail eq "gmail"} {
		set base "https://mail.google.com/mail/?view=cm&tf=0&to="
		regsub {^mailto:} $uri {} uri
		
		
		::Utils::UnixOpenUrl "gmail.com"
	    } else {
		catch {exec $mail $uri &}
	    }
	}
	windows {
	    ::Windows::OpenURI $uri
	}
    }
}

if {0} {
    #when we are passed an email address like this:
    #mailto:vdog@domain.com?subject=hi%20vernon&body=please%20unsubscribe%20me%20from%20this%20mad%20list&cc=mad@max.com&bcc=jo@mama.com
    #we want to generate a uri like this:
    #http://mail.google.com/mail/?view=cm&tf=0&to=vdog@domain.com&cc=mad@max.com&bcc=jo@mama.com&su=hi%20vernon&body=please%20unsubscribe%20me%20from%20this%20mad%20list&zx=9i09cu-h33iui
    
    # remove the ? from the uri
    uri=`echo "$1" | sed -e 's/subject=/su=/' -e 's/^mailto:\([^&?]\+\)[?&]\?\(.*\)$/\1\&\2/'`
    
    if [ "$uri" ];
    then exec $BROWSER "https://mail.google.com/mail?view=cm&tf=0&to=$uri"
    fi
    
    exec $BROWSER "https://mail.google.com/" 
}

