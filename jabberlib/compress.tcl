#  compress.tcl --
#  
#      This file is part of jabberlib.
#      It implements stream compression as defined in XEP-0138: 
#      Stream Compression
#      
#  Copyright (c) 2006-2007  Mats Bengtsson
#  
# This file is distributed under BSD style license.
#  
#  NB: There are several zlib packages floating around the net with the same
#      name!. But we must have the one implemented for TIP 234, see
#      http://www.tcl.tk/cgi-bin/tct/tip/234.html.
#      This is currently of version 2.0.1 so we rely on this when doing
#      package require. Beware!
#      
# $Id: compress.tcl,v 1.8 2007-08-14 12:21:24 matben Exp $

package require jlib
package require -exact zlib 2.0.1

package provide jlib::compress 0.1

namespace eval jlib::compress {

    variable methods {zlib}
    
    # NB: There are two namespaces:
    #     'http://jabber.org/features/compress' 
    #     'http://jabber.org/protocol/compress' 
    variable xmlns
    array set xmlns {
	features/compress    "http://jabber.org/features/compress"
	protocol/compress    "http://jabber.org/protocol/compress"
    }
    jlib::register_instance [namespace code instance]
}

proc jlib::compress::instance {jlibname} {
    $jlibname register_reset [namespace code reset]
}

proc jlib::compress::start {jlibname cmd} {
    
    variable xmlns
    variable methods
    
    #puts "jlib::compress::start"
    
    # Instance specific namespace.
    namespace eval ${jlibname}::compress {
	variable state
    }
    upvar ${jlibname}::compress::state state
    
    set state(cmd) $cmd
    set state(-method) [lindex $methods 0]
    
    # Set up the streams for zlib.
    set state(compress)   [zlib stream compress]
    set state(decompress) [zlib stream decompress]

    # Set up callback for the xmlns that is of interest to us.
    $jlibname element_register $xmlns(protocol/compress) [namespace code parse]

    if {[$jlibname have_feature]} {
	compress $jlibname
    } else {
	$jlibname trace_stream_features [namespace code features_write]
    }
}

proc jlib::compress::features_write {jlibname} {
    
     #puts "jlib::compress::features_write"
    
     $jlibname trace_stream_features {}
     compress $jlibname
}

# jlib::compress::compress --
# 
#       Initiating Entity Requests Stream Compression.

proc jlib::compress::compress {jlibname} {
    
    variable methods
    variable xmlns
    upvar ${jlibname}::compress::state state
    
    #puts "jlib::compress::compress"
       
    # Note: If the initiating entity did not understand any of the advertised 
    # compression methods, it SHOULD ignore the compression option and 
    # proceed as if no compression methods were advertised. 

    set have_method [$jlibname have_feature compression $state(-method)]
    if {!$have_method} {
	finish $jlibname
	return
    }
    
    # @@@ MUST match methods!!!
    # A compliant implementation MUST implement the ZLIB compression method...
    
    set methodE [wrapper::createtag method -chdata $state(-method)]

    set xmllist [wrapper::createtag compress  \
      -attrlist [list xmlns $xmlns(protocol/compress)] -subtags [list $methodE]]
    $jlibname send $xmllist

    # Wait for 'compressed' or 'failure' element.
}

proc jlib::compress::parse {jlibname xmldata} {
    
    #puts "jlib::compress::parse"
    
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

proc jlib::compress::compressed {jlibname xmldata} {
    
    #puts "jlib::compress::compressed"
    
    # Example 5. Receiving Entity Acknowledges Stream Compression 
    #     <compressed xmlns='http://jabber.org/protocol/compress'/> 
    # Both entities MUST now consider the previous stream to be null and void, 
    # just as with TLS negotiation and SASL negotiation 
    # Therefore the initiating entity MUST initiate a new stream to the 
    # receiving entity: 
 
    $jlibname wrapper_reset
    
    # We must clear out any server info we've received so far.
    $jlibname stream_reset
    
    $jlibname set_socket_filter [namespace code out] [namespace code in]
    
    if {[catch {
	$jlibname sendstream -version 1.0
    } err]} {
	finish $jlibname network-failure $err
	return
    }
    finish $jlibname
}

# jlib::compress::out, in --
# 
#       Actual compression takes place here.
#       XEP says:
#       When using ZLIB for compression, the sending application SHOULD 
#       complete a partial flush of ZLIB when its current send is complete. 

proc jlib::compress::out {jlibname data} {
    upvar ${jlibname}::compress::state state

    $state(compress) put -flush $data
    return [$state(compress) get]
}

proc jlib::compress::in {jlibname cdata} {
    upvar ${jlibname}::compress::state state
    
    $state(decompress) put $cdata
    #$state(decompress) flush
    return [$state(decompress) get]
}

proc jlib::compress::failure {jlibname xmldata} {
    
    #puts "jlib::compress::failure"
    
    set c [wrapper::getchildren $xmldata]
    if {[llength $c]} {
	set errcode [wrapper::gettag [lindex $c 0]]
    } else {
	set errcode unknown-failure
    }
    finish $jlibname $errcode
}

proc jlib::compress::finish {jlibname {errcode ""} {errmsg ""}} {
    
    upvar ${jlibname}::compress::state state
    variable xmlns
    
    #puts "jlib::compress:finish errcode=$errcode, errmsg=$errmsg"

    # NB: We must keep our state array for the lifetime of the stream.
    $jlibname trace_stream_features {}
    $jlibname element_deregister $xmlns(protocol/compress) [namespace code parse]
    
    if {$errcode ne ""} {
	uplevel #0 $state(cmd) $jlibname [list $errcode $errmsg]
    } else {
	uplevel #0 $state(cmd) $jlibname
    }
}

proc jlib::compress::reset {jlibname} {
    
    upvar ${jlibname}::compress::state state

    #puts "jlib::compress::reset"
    
    if {[info exists state(compress)]} {
	$state(compress) close
	unset state(compress)
    }
    if {[info exists state(decompress)]} {
	$state(decompress) close
	unset state(decompress)
    }
    unset -nocomplain state
}

