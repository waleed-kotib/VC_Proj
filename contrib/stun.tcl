#  stun.tcl --
#  
#      Package for STUN - Simple Traversal of User Datagram Protocol (UDP)
#      Through Network Address Translators (NATs)
#      
#      RFC 3489
#      
#      It is so far limited to simple client requests.
#      
#  Copyright (c) 2006  Mats Bengtsson
#  BSD-style License
#  
# $Id: stun.tcl,v 1.2 2006-03-02 13:43:56 matben Exp $

# USAGE:
# 
#       Initiate a request to a STUN server:
# 
#       stun::request hostname ?-option value...?
#       
#           -command    tclProc
#                         the tclProc shall have this form:
#                         procName {token status args}
#                         where args is a list of -key value pairs
#           -myport     bind port number
#           -port       host port number
#           -timeout    milliseconds
#           
#       If -command is specified it is returned almost immedeately
#       with a token identifier. Else it waits for the response and
#       returns a list {status ?-key value...?}
#       
#       Reset an async request:
#       
#       stun::reset token
#       
#       
#  Known STUN host: stun.fwdnet.net

package require udp

package provide stun 0.1

namespace eval ::stun {

    variable MAX_INT 0x7FFFFFFF

    variable stunPort        3478
    variable stunChangedPort 3479
    
    # The address family is always 0x01, corresponding to IPv4
    variable ipv4 0x01
    
    variable stunFlag
    array set stunFlag {
	ChangeIpFlag    0x04
	ChangePortFlag  0x02
    }
    
    variable stunAttr
    array set stunAttr {
	MappedAddress        0x0001
	ResponseAddress      0x0002
	ChangeRequest        0x0003
	SourceAddress        0x0004
	ChangedAddress       0x0005
	Username             0x0006
	Password             0x0007
	MessageIntegrity     0x0008
	ErrorCode            0x0009
	UnknownAttribute     0x000A
	ReflectedFrom        0x000B
	XorMappedAddress     0x8020
	XorOnly              0x0021
	ServerName           0x8022
	SecondaryAddress     0x8050
    }
    
    variable stunType
    array set stunType {
	BindRequestMsg                   0x0001
	BindResponseMsg                  0x0101
	BindErrorResponseMsg             0x0111
	SharedSecretRequestMsg           0x0002
	SharedSecretResponseMsg          0x0102
	SharedSecretErrorResponseMsg     0x0112
    }
    
    variable options
    array set options {
	-command        ""
	-myport         0
	-timeout        10000
    }
    set options(-port) $stunPort
}

# stun::request --
# 
#       The client procedure that makes a bind request call.
#       
# Arguments:
#       host        the server hostname
#       args:       list of -key value pairs
#           -command    tclProc
#           -myport     bind port number
#           -port       host port number
#           -timeout    milliseconds
#       
# Results:
#       if -command it returns a token, else the result from the request

proc stun::request {host args} {
    variable stunType
    variable options
    
    # Primitive error checking.
    foreach {key value} $args {
	if {![info exists options($key)]} {
	    set onames [lsort [array names options -*]]
	    set usage [join $onames ", "]
	    return -code error "Unknown option $key, must be: $usage"
	}
    }  
    array set opts [array get options]
    array set opts $args
    
    if {$opts(-myport) == 0} {
	set s [udp_open]
    } else {
	set s [udp_open $opts(-myport)]
    }
    
    # Local storage.
    set token [namespace current]::$s
    variable $token
    upvar 0 $token state
    
    if {$opts(-timeout) > 0} {
	set state(afterid) [after $opts(-timeout)  \
	  [list [namespace current]::Timeout $token]]
    }

    fconfigure $s -remote [list $host $opts(-port)]  \
      -buffering none -translation binary 
    fileevent $s readable [list [namespace current]::Response $token]
    
    array set state [fconfigure $s]
    
    # Message attributes.

    set msg ""

    # The 20 byte header for the binding request.
    set type $stunType(BindRequestMsg)
    set header [binary format S2 [list $type [string length $msg]]]
    set id [NewID]
    append header $id
    set data $header$msg
    
    set state(s)      $s
    set state(id)     $id
    set state(host)   $host
    set state(errmsg) ""
    set state(status) ""
    foreach {key value} [array get opts] {
	set state(opts,$key) $value
    }

    # Send the request.
    if {[catch {puts -nonewline $s $data} err]} {
	unset state
	return -code error $err
    }
    if {$opts(-command) eq ""} {
	set state(wait) 0
	vwait $token\(wait)
	return [Finalize $token]
    } else {
	return $token
    }
}

proc stun::reset {token} {
    variable $token
    upvar 0 $token state
    
    #puts "stun::reset"
    set state(status) reset
    End $token
}

proc stun::Response {token} {
    variable $token
    upvar 0 $token state
    
    #puts "stun::Event"
    if {[info exists state(afterid)]} {
	after cancel $state(afterid)
    }
    fileevent $state(s) readable {}
    set data [read $state(s)]
    binary scan $data SSa16 type len id
    if {[expr {$state(id) != $id}]} {
	End $token "transaction id different"
    } else {
	set name [GetTypeName $type]
	#puts "name=$name, len=$len"
	if {$name ne "BindResponseMsg"} {
	    End $token "we expected a BindResponseMsg but got $name"
	} else {
	    set attr [string range $data 20 end]
	    array set state [DecodeAttributes $attr]
	}
    }
    End $token
}

proc stun::End {token {errmsg ""}} {
    variable $token
    upvar 0 $token state
   
    #puts "stun::End errmsg=$errmsg"
    if {$errmsg ne ""} {
	set state(errmsg) $errmsg
	set state(status) error
    }
    if {$state(opts,-command) eq ""} {
	# This triggers the vwait above.
	set state(wait) 1
    } else {
	Finalize $token
    }
}

# stun::Finalize --
# 
#       Closes socket, cancels any timouts, collects the results,
#       invokes any registered command.
#       
# Results:
#       a list {status -key value ...}

proc stun::Finalize {token} {
    variable $token
    upvar 0 $token state
    
    #puts "stun::Finalize"
    close $state(s)
    if {[info exists state(afterid)]} {
	after cancel $state(afterid)
    }
    if {$state(status) eq ""} {
	set status ok
    } else {
	set status $state(status)
    }
    if {$state(errmsg) ne ""} {
	set status error
    }
    if {$status eq "ok"} {
	set res [ResultList $token]
    } elseif {$state(errmsg) ne ""} {
	set res [list -errmsg $state(errmsg)]
    } else {
	set res {}
    }
    set state(status) $status
    if {$state(opts,-command) ne ""} {
	uplevel #0 $state(opts,-command) $token $status $res
    }
    unset state
    return [concat $status $res]
}

# stun::ResultList --
# 
#       Uses the state array to make the result as a -key value list.

proc stun::ResultList {token} {
    variable $token
    upvar 0 $token state
    
    set ans {}
    set addr [lindex $state(MappedAddress) 0]
    set port [lindex $state(MappedAddress) 1]
    lappend ans -address $addr -port $port
    lappend ans -myport $state(-myport)
    return $ans
}

# stun::NewID --
# 
#       Generate 128 bit random identifier.

proc stun::NewID {} {
    variable MAX_INT
    
    for {set i 0} {$i < 4} {incr i} {
	set r [expr int($MAX_INT * rand())]
	set b$i [binary format I $r]
    }
    return $b0$b1$b2$b3
}

proc stun::EncodeAttr {name value} {
    variable stunAttr
    
    set len [string length $value]
    return [binary format S2a [list $stunAttr($name) $len $value]]
}

proc stun::EncodeIP4Address {addr} {
    foreach {i3 i2 i1 i0} [split $addr .] {break}
    # @@@ do binary format here!!!
    return [expr {($i0 + ($i1 << 8) + ($i2 << 16) + ($i3 << 24)) & 0xFFFFFFFF}]
}

# stun::DecodeAttributes --
# 
#       Each attribute is TLV encoded, with a 16 bit type, 16 bit length, 
#       and variable value:

proc stun::DecodeAttributes {attr} {
    variable stunFlag
    variable stunAttr
    variable ipv4
    
    set ans {}
    
    while {[string length $attr]} {
	binary scan $attr SS type len
	
	# To get the unsigned values.
	set type [expr {$type & 0xFFFF}]
	set len  [expr {$len & 0xFFFF}]
	set name [GetAttrName $type]
	
	# Strip off the 16 bit type and 16 bit length; 4 bytes.
	set attr [string range $attr 4 end]
	#puts "\t name=$name, len=$len"
	
	switch -- $name {
	    MappedAddress - ChangedAddress - ResponseAddress -
	    SourceAddress - ReflectedFrom {
		
		# port is unsigned 16 bit short
		# address is unsigned 32 bit int
		binary scan $attr xcSI family port addr
		if {[expr {$ipv4 != $family}]} {
		    End $token "not ipv4 address family"
		}
		set port [expr {$port & 0xFFFF}]
		set addr [expr {$addr & 0xFFFFFFFF}]
		set addr [FormatIP4Address $addr]
		lappend ans $name [list $addr $port]
	    }
	    ChangeRequest {
		if {$len != 4} {
		    End $token "wrong length of ChangeRequest"
		}
		binary scan $attr I change
		set changeIP [expr {$change & $stunFlag(ChangeIpFlag)}]
		set changePort [expr {$change & $stunFlag(ChangePortFlag)}]
		lappend ans $name [list $changeIP $changePort]
	    }
	    Username - Password {
		binary scan $attr a$len value
		lappend ans $name $value
	    }
	    MessageIntegrity {
		
		# Must be last attribute.
		# The HMAC will be 20 bytes. 
		# The text used as input to HMAC is the STUN message.
		binary scan $attr a20 hmac
		lappend ans $name $hmac
	    }
	    ErrorCode {
		set rlen [expr {$len-4}]
		binary scan $attr x2cca${rlen} class number reason
		set class [expr {$class & 0xFF}]
		set number [expr {$number & 0xFF}]
		
		
	    }
	    UnknownAttribute {
		# todo
	    }
	    default {
		# error
	    }
	}
    
	# Trim off part just analyzed.
	set attr [string range $attr $len end]
    }
    return $ans
}

proc stun::FormatIP4Address {uint32} {    
    set i3 [expr {($uint32 >> 24) & 0xFF}]
    set i2 [expr {($uint32 >> 16) & 0xFF}]
    set i1 [expr {($uint32 >>  8) & 0xFF}]
    set i0 [expr {($uint32 >>  0) & 0xFF}]
    return $i3.$i2.$i1.$i0
}

proc stun::ReadULong {data index} {
    set r {}
    binary scan [string range $data $index end] cccc b1 b2 b3 b4
    # This gets us an unsigned value.
    set r [expr {$b4 + ($b3 << 8) + ($b2 << 16) + ($b1 << 24)}] 
    return $r
}

proc stun::GetAttrName {type} {
    variable stunAttr
    
    set name ""
    foreach {str num} [array get stunAttr] {
	if {[expr {$num == $type}]} {
	    set name $str
	    break
	}
    }
    return $name
}

proc stun::GetTypeName {type} {
    variable stunType
    
    set name ""
    foreach {str num} [array get stunType] {
	if {[expr {$num == $type}]} {
	    set name $str
	    break
	}
    }
    return $name
}

proc stun::NATType {token} {
    variable $token
    upvar 0 $token state
    
    # TODO
    return xxx
}

# Unreliable!
proc stun::LocalInterface {} {
    set ip ""
    if {![catch {socket -server puts 0} s]} {
	set ip [lindex [fconfigure $s -sockname] 0]
	catch {close $s}
	if {$ip eq "0.0.0.0"} {
	    set ip "127.0.0.1"
	}
    }
    return $ip
}

proc stun::Timeout {token} {
    variable $token
    upvar 0 $token state

    unset -nocomplain state(afterid)
    set state(status) timeout
    End $token
}

# --- server part --------------------------------------------------------------

# TODO

proc stun::server {args} {
    variable stunPort
    variable stunChangedPort
    
    set s [udp_open $stunPort]
    fconfigure $s -buffering none -translation binary
    fileevent $s readable [list [namespace current]::EventHandler $s]

    set s [udp_open $stunChangedPort]
    fconfigure $s -buffering none -translation binary
    fileevent $s readable [list [namespace current]::EventHandler $s]
}

proc stun::EventHandler {s} {
    variable stunType
    variable ipv4
    
    set data [read $s]
    
    binary scan $data SSa16 type len id
    set name [GetTypeName $type]

    if {$name eq "BindRequestMsg"} {
	set peer [fconfigure $s -peer]
	set paddr [lindex $peer 0]
	set pport [lindex $peer 1]
	
	set attr ""
	set uint32 [EncodeIP4Address $paddr]
	# Not sure if the uint32 is correctly formatted here!
	set mappedAddr [binary format xcSI $ipv4 $pport $uint32]
	set changedAttr""
	set sourceAddr ""
	append attr [EncodeAttr MappedAddress $mappedAddr]
	append attr [EncodeAttr ChangedAddress $changedAttr]
	append attr [EncodeAttr SourceAddress $sourceAddr]
	
	set len [string length $attr]
	set header [binary format SS $stunType(BindResponseMsg) $len]
	append header $id
    } else {
    
    }
}
    
#-------------------------------------------------------------------------------

