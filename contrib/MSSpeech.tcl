#  MSSpeech.tcl ---
#  
#      This file is part of The Coccinella application. It implements
#      glue to Microsoft Speech via tcom for connecting to COM.
#      
#  Copyright (c) 2002  Mats Bengtsson
#  
#  This source file is distributed under the BSD license.
#  
#  See the README file for license, bugs etc.
#  
# $Id: MSSpeech.tcl,v 1.6 2007-07-19 06:28:11 matben Exp $

namespace eval ::MSSpeech:: {

    # Main speech object.
    variable idVoice
    variable voiceName2ObjectArr
}

proc ::MSSpeech::Init { } {
        
    variable idVoice
    variable voiceName2ObjectArr
    variable allVoices

    if {[catch {package require tcom} ret]} {
	error "Failed finding the tcom extension"
	return
    }
    if {[catch {::tcom::ref createobject Sapi.SpVoice} ret]} {
	error "Failed finding Speech COM object"
    } else {
	set idVoice $ret
	set idVoiceToken [$idVoice Voice]
	set name [$idVoiceToken GetDescription]
	set voiceName2ObjectArr($name) $idVoice
	set allVoices [GetVoices]
    }
}

proc ::MSSpeech::Speak {msg {voice ""}} {
        
    variable idVoice
    variable voiceName2ObjectArr
    variable allVoices

    # 1 means async.
    if {$voice == ""} {
	$idVoice Speak $msg 1
    } else {
	set ind [lsearch $allVoices $voice]
	if {$ind < 0} {
	    $idVoice Speak $msg 1
	} else {
	    if {![info exists voiceName2ObjectArr($voice)]} {
		if {[catch {::tcom::ref createobject Sapi.SpVoice} ret]} {
		    error "Failed finding Speech COM object"
		} else {
		    set id $ret
		    set idVoicesToken [$id GetVoices]
		    $id Voice [$idVoicesToken Item $ind] 
		    set voiceName2ObjectArr($voice) $id
		}
	    }
	    $voiceName2ObjectArr($voice) Speak $msg 1
	}
    }
}

proc ::MSSpeech::GetVoices { } {
    
    variable idVoice
    
    set voices {}
    set idVoicesToken [$idVoice GetVoices]
    ::tcom::foreach item $idVoicesToken {
	lappend voices [$item GetDescription]
    }
    return $voices
}

# If this fails, package loading fails.
::MSSpeech::Init

package require tcom
package provide MSSpeech 1.0

#-------------------------------------------------------------------------------




