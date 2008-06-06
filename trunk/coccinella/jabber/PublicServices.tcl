#  PublicServices.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements groupchat enter UI independent of protocol used.
#      
#  Copyright (c) 2008  Mats Bengtsson
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
# $Id: PublicServices.tcl,v 1.1 2008-06-06 14:36:25 matben Exp $

package provide PublicServices 1.0

namespace eval ::PublicServices { 

    # List urls of known services. The key shall respond to the 
    # category/type of http://www.xmpp.org/registrar/disco-categories.html
    variable url
    set url(server/im)          "http://www.jabberes.org/servers/servers.xml"
    set url(gateway/msn)        "http://www.jabberes.org/servers/msn.xml"
    set url(gateway/icq)        "http://www.jabberes.org/servers/icq.xml"
    set url(gateway/irc)        "http://www.jabberes.org/servers/irc.xml"
    set url(proxy/bytestreams)  "http://www.jabberes.org/servers/irc.xml"
    
}

proc ::PublicServices::Exists {key} {
    variable url
    return [info exists url($key)]
}

proc ::PublicServices::Get {key cmd} {    
    variable url
    
    if {![info exists url($key)]} {
	return -code error "unknown service $key"
    }
    ::httpex::geturl $url($key) \
      -command [namespace code [list HttpCB $cmd $key]]
}

proc ::PublicServices::HttpCB {cmd key token} {    

    puts "::PublicServices::HttpCB [::httpex::status $token]"
    if {[::httpex::status $token] eq "ok"} {
	set ncode [httpex::ncode $token]
	puts "ncode=$ncode"
	if {$ncode == 200} {
	    set xml [::httpex::data $token]    
	    set xtoken [tinydom::parse $xml]
	    set xmllist [tinydom::documentElement $xtoken]
	    if {[tinydom::tagname $xmllist] ne "servers"} {
		#
	    }
	    foreach serverE [tinydom::children $xmllist] {
		foreach componentE [tinydom::children $serverE] {
		    if {[tinydom::getattribute $componentE available] eq "yes"} {
			set type [tinydom::getattribute $componentE type]
			if {$type eq "icq"} {
			    set jid [tinydom::getattribute $componentE jid]
			    puts "icq: $jid"
			}
		    }
		}
	    }
	}
	
    } else {
	
    }
    uplevel #0 $cmd
    ::httpex::cleanup $token
}






