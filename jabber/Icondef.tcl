#  Icondef.tcl --
#  
#       This file is part of The Coccinella application. 
#       It implements parsing of iconsets as specified by the format in common
#       use within the jabber community. It can appear in three variants:
#       
#         1) a selfcontained icondef.xml file with all data base64 encoded
#         2) a folder with all data in separate files with an icondef.xml
#            describing their usage
#         3) as 2 but zipped up with a .jisp extension
#      
#       It is so far only written for roster style formats and not the
#       slightly different emoticon format.
#      
#       Format:
#      
#      	<icon>
#		<x xmlns='name'>status/away</x>
#		<object mime='image/png'>away.png</object>
#	</icon>
#	
#       is parsed into 'imageArr(status/away) [Image away.png]'
#
#  Copyright (c) 2005  Mats Bengtsson
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
# $Id: Icondef.tcl,v 1.3 2007-09-13 08:25:39 matben Exp $

package provide Icondef 1.0

namespace eval ::Icondef:: {

    variable priv
    
    set priv(havezip) 0
    set priv(initted) 0
    
    # We must have support for these.
    set priv(formats) {gif png}
}

proc ::Icondef::Init { } {
    variable priv
    
    # We need the 'vfs::zip' package and if not using starkit we also need
    # the 'Memchan' package which is not automatically checked for.
    # 'rechan' is the tclkits built in version of 'Memchan'.
    if {[catch {package require vfs::zip}]} {
	set priv(havezip) 0
    } elseif {![catch {package require rechan}]} {
	set priv(havezip) 1
    } elseif {![catch {package require Memchan}]} {
	set priv(havezip) 1
    } else {
	set priv(havezip) 0
    }    
    set priv(initted) 1
}

# Icondef::Load --
# 
#       Loads an icon set and creates the necessary images.
#       
# Arguments:
#       path        file path to dir or jisp dir.
#       imageArr    name of array to store mapping key -> image
#       metaArr     name of array for meta data
#       
# Results:
#       name of iconset from file or dir name.

proc ::Icondef::Load {path imageArr metaArr} {    
    variable priv
    
    if {!$priv(initted)} {
	Init
    }
    
    # The dir variable points to the (virtual) directory containing it all.
    set dir $path
    set name [file rootname [file tail $path]]
    
    if {[string equal [file extension $path] ".jisp"]} {
	if {$priv(havezip)} {
	    set mountpath [file join [file dirname $path] $name]
	    if {[catch {
		set fdzip [vfs::zip::Mount $path $mountpath]
	    } err]} {
		return -code error $err
	    }
	    
	    # We cannot be sure of that the name of the archive is identical 
	    # with the name of the original directory.
	    set zipdir [lindex [glob -nocomplain -directory $mountpath *] 0]
	    set dir $zipdir
	} else {
	    return -code error "Cannot read jisp archive without vfs::zip"
	}
    }
    set icondefPath [file join $dir icondef.xml]
    if {![file isfile $icondefPath]} {
	return -code error "missing icondef.xml file in archive"
    }
    set fd [open $icondefPath]
    fconfigure $fd -encoding utf-8
    set xmldata [read $fd]
    close $fd
	
    # Parse data.
    ParseIconDef $imageArr $metaArr $dir $xmldata
    
    if {[info exists mountpath]} {
	vfs::zip::Unmount $fdzip $mountpath
    }
    return $name
}

proc ::Icondef::ParseIconDef {imageArr metaArr dir xmldata} {

    set token [tinydom::parse $xmldata]
    set xmllist [tinydom::documentElement $token]
    
    foreach elem [tinydom::children $xmllist] {
	
	switch -- [tinydom::tagname $elem] {
	    meta {
		ParseMeta $metaArr $dir $elem
	    }
	    icon {
		ParseIcon $imageArr $dir $elem
	    }
	}
    }
    tinydom::cleanup $token
}

proc ::Icondef::ParseMeta {metaArr dir xmllist} {
    upvar #0 $metaArr meta
    
    foreach elem [tinydom::children $xmllist] {
	set tag [tinydom::tagname $elem]
	lappend meta($tag) [tinydom::chdata $elem]
    }
}

proc ::Icondef::ParseIcon {imageArr dir xmllist} {    
    upvar #0 $imageArr imArr
    variable priv

    set mime ""
    
    foreach elem [tinydom::children $xmllist] {
	set tag [tinydom::tagname $elem]
	
	switch -- $tag {
	    x {
		set key [tinydom::chdata $elem]
	    }
	    data {
		# base64 coded image data
		set data [tinydom::chdata $elem]
		array set attr [tinydom::attrlist $elem]
		set mime $attr(mime)
	    }
	    object {
		set object [tinydom::chdata $elem]
		array set attr [tinydom::attrlist $elem]
		set mime $attr(mime)
	    }
	}
    }
    
    set format [lindex [split $mime /] 1]
    if {[lsearch $priv(formats) $format] < 0} {
	return
    }
    
    if {[info exists data]} {
	set im [image create photo -format $format -data $data]
    } else {
	set im [image create photo -format $format  \
	  -file [file join $dir $object]]
    }
    set imArr($key) $im
}
