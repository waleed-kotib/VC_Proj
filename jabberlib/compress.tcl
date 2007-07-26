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
#  Note: with zlib 1.0 it seems that we can import zlib compression
#        on the socket channel using zlib stream socket ... ???
#  
# $Id: compress.tcl,v 1.6 2007-07-26 14:18:54 matben Exp $

package require jlib
#package require zlib

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
}

proc jlib::compress::start {jlibname cmd} {
    
    variable xmlns
    variable methods
    
    puts "jlib::compress::start"
    
    # Instance specific namespace.
    namespace eval ${jlibname}::compress {
	variable state
    }
    upvar ${jlibname}::compress::state state
    
    set state(cmd) $cmd
    set state(-method) [lindex $methods 0]

    # Set up callback for the xmlns that is of interest to us.
    $jlibname element_register $xmlns(protocol/compress) [namespace code parse]

    if {[$jlibname have_feature]} {
	compress $jlibname
    } else {
	$jlibname trace_stream_features [namespace code features_write]
    }
}

proc jlib::compress::features_write {jlibname} {
    
     puts "jlib::compress::features_write"
    
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
    
    puts "jlib::compress::compress"
       
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
    
    puts "jlib::compress::parse"
    
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
    
    puts "jlib::compress::compressed"
    
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
}

# jlib::compress::out, in --
# 
#       Actual compression takes place here.

proc jlib::compress::out {data} {
    puts "jlib::compress::out¬¬¬¬¬¬¬¬¬¬¬¬¬¬¬¬¬¬¬¬¬¬¬"
    return [zlib compress $data]
}

set jlib::compress::n -1

proc jlib::compress::in {data} {
    variable n
    puts "jlib::compress::in...................."
    set ::_data([incr n]) $data
    return
    
    # This just crashes or gives "data error"
    return [zlib decompress $data]
}

proc jlib::compress::failure {jlibname xmldata} {
    
    puts "jlib::compress::failure"
    
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
    
    puts "jlib::compress:finish errcode=$errcode, errmsg=$errmsg"

    $jlibname trace_stream_features {}
    $jlibname element_deregister $xmlns(protocol/compress) [namespace code parse]
    
    if {$errcode ne ""} {
	uplevel #0 $state(cmd) $jlibname [list $errcode $errmsg]
    } else {
	uplevel #0 $state(cmd) $jlibname
    }
    unset state
}


