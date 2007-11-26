# uriencode.tcl --
#
#	Encoding of uri's and file names. Some code from tcllib.
#     Parts: Copyright (C) 2001 Pat Thoyts <Pat.Thoyts@bigfoot.com>
# 	extend the uri package to deal with URN (RFC 2141)
# 	see http://www.normos.org/ietf/rfc/rfc2141.txt
# 	
# $Id: uriencode.tcl,v 1.2 2007-11-26 15:06:21 matben Exp $

package provide uriencode 1.0

namespace eval uriencode {

    variable esc {%[0-9a-fA-F]{2}}
    variable trans {a-zA-Z0-9$_.+!*'(,):=@;-}
}

# Quote the disallowed characters according to the RFC for URN scheme.
# ref: RFC2141 sec2.2

proc uriencode::quote {str} {
    variable trans
    
    set ndx 0
    while {[regexp -start $ndx -indices -- "\[^$trans\]" $str r]} {
	set ndx [lindex $r 0]
	scan [string index $str $ndx] %c chr
	set rep %[format %.2X $chr]
	if {[string match $rep %00]} {
	    error "invalid character: character $chr is not allowed"
	}
	set str [string replace $str $ndx $ndx $rep]
	incr ndx 3
    }
    return $str
}

# uriencode::quotepath --
# 
#	Need to carefully avoid encoding any / in volume specifiers.
#	/root/...  or C:/disk/...
#       Always return path using unix separators "/"

proc uriencode::quotepath {path} {
    
    set isrel [string equal [file pathtype $path] "relative"]

    if {!$isrel} {
	
	# An absolute non mac path. 
	# Be sure to get rid of unix style "/" and windows "C:/"
  	set plist [file split [string trimleft $path /]]
	set qpath [uriencode::quote [string trimright [lindex $plist 0] /]]
	foreach str [lrange $plist 1 end] {
	    lappend qpath [uriencode::quote $str]
	}	
    } else {
	
	# A relative non mac path.
	set qpath [list]
	foreach str [file split $path] {
	    lappend qpath [uriencode::quote $str]
	}
    }
    
    # Build unix style path
    set qpath [join $qpath /]
    if {!$isrel} {
	set qpath "/$qpath"
    }
    return $qpath
}

proc uriencode::quoteurl {url} {

    # Only the file path part shall be encoded.
    if {![regexp {([^:]+://[^:/]+(:[0-9]+)?)(/.*)} $url  \
	match prepath x path]} {
	return -code error "Is not a valid url: $url"
    }
    set path [string trimleft $path /]
    return "${prepath}/[uriencode::quotepath $path]"
}

proc uriencode::decodefile {file} {

    return [uriencode::decodeurl $file]
}

proc uriencode::decodeurl {url} {

    regsub -all {\+} $url { } url
    regsub -all {%([0-9a-hA-H]{2})} $url {[format %c 0x\1]} url
    return [subst $url]
}

#-----------------------------------------------------------------------
