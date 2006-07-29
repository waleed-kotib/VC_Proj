#  compress.tcl --
#  
#      This file is part of jabberlib.
#      It implements stream compression as defined in JEP-0138: 
#      Stream Compression
#      
#  Copyright (c) 2006  Mats Bengtsson
#  
# $Id: compress.tcl,v 1.1 2006-07-29 13:12:59 matben Exp $

package require jlib
package require zlib 1.0

package provide jlib::compress 0.1

namespace eval jlib::compress {

    variable methods {zlib}
    
    variable xmlns
    array set xmlns {
	compress    "http://jabber.org/features/compress"
    }
}

proc jlib::compress::start {jlibname cmd} {
    
    variable xmlns
    variable methods
    
    # Instance specific namespace.
    namespace eval ${jlibname}::compress {
	variable state
    }
    upvar ${jlibname}::compress::state state
    
    set state(cmd) $cmd
    set state(-method) [lindex $methods 0]

    # Set up callbacks for the xmlns that is of interest to us.
    element_register $jlibname $xmlns(compress) [namespace current]::parse

    if {[have_feature $jlibname]} {
	compress $jlibname
    } else {
	trace_stream_features $jlibname [namespace current]::tls_features_write
    }
}

proc jlib::compress::parse {jlibname xmldata} {
    
    set tag [wrapper::gettag $xmldata]
    
    switch -- $tag {
	compressed {
	    compressed $jlibname $xmldata
	}
	failure {
	    failure $jlibname $xmldata
	}
	default {
	    finish $jlibname compress-protocol-error
	}
    }
    return
}

proc jlib::compress::compress {jlibname} {
    
    variable methods
    variable xmlns
    
    # Note: If the initiating entity did not understand any of the advertised 
    # compression methods, it SHOULD ignore the compression option and 
    # proceed as if no compression methods were advertised. 

    set have_method [$jlibname have_feature compression $state(-method)]
    if {!$have_method} {
	finish $jlibname
	return
    }
    set methodE [wrapper::createtag method -chdata $method]

    set xmllist [wrapper::createtag compress  \
      -attrlist [list xmlns $xmlns(compress)] -subtags [list $methodE]]
    send $jlibname $xmllist

    # Wait for 'compressed' or 'failure' element.
}

proc jlib::compress::compressed {jlibname xmldata} {
    
    
}

proc jlib::compress::failure {jlibname xmldata} {
    
    set c [wrapper::getchildren $xmldata]
    if {[llength $c]} {
	set errcode [wrapper::gettag [lindex $c 0]]
    } else {
	set errcode ""
    }
    finish $jlibname $errcode
}

proc jlib::compress:finish {jlibname {errcode ""} {msg ""}} {
    
    upvar ${jlibname}::compress::state state
    variable xmlns

    trace_stream_features $jlibname {}
    element_deregister $jlibname $xmlns(compress) [namespace current]::parse
    
    if {$errcode ne ""} {
	uplevel #0 $state(cmd) $jlibname [list $errcode $errmsg]
    } else {
	uplevel #0 $state(cmd) $jlibname
    }
}