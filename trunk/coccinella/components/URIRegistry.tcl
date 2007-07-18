# URIRegistry.tcl --
# 
# <a href='xmpp:jid[?query]'/>
# 
# See: http://msdn.microsoft.com/workshop/networking/pluggable/overview/appendix_a.asp
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
# $Id: URIRegistry.tcl,v 1.8 2007-07-18 09:40:10 matben Exp $

namespace eval ::URIRegistry:: { }

proc ::URIRegistry::Init { } {
    global  tcl_platform this

    if {![string equal $tcl_platform(platform) "windows"]} {
	return
    }
    if {[catch {package require registry}]} {
	return
    }
    ::Debug 2 "::URIRegistry::Init"
    
    # Find the exe we are running. Starkits?
    if {[info exists ::starkit::topdir]} {
	set exe [file nativename [info nameofexecutable]]
	set cmd "\"$exe\" -uri \"%1\""
    } else {
	set exe [file nativename [info nameofexecutable]]
	set app [file nativename $this(script)]
	set cmd "\"$exe\" \"$app\" -uri \"%1\""
    }
    foreach name {xmpp im} {	
	if {[catch {SetProtocol $name $cmd}]} {
	    return
	}
    }
    component::register URIRegistry  \
      {Automatically adds an registry entry so that this program is\
      launched when clicking an uri <a href='xmpp:jid[?query]'/>.}
}

proc ::URIRegistry::SetProtocol {name cmd} {

    registry set HKEY_CLASSES_ROOT\\$name {} "URL:$name Protocol"
    registry set HKEY_CLASSES_ROOT\\$name "URL Protocol" {}
    registry set HKEY_CLASSES_ROOT\\$name\\Shell
    registry set HKEY_CLASSES_ROOT\\$name\\Shell\\open
    registry set HKEY_CLASSES_ROOT\\$name\\Shell\\open\\command {} $cmd
}

#-------------------------------------------------------------------------------
