#  vcard.tcl --
#  
#      This file is part of the jabberlib.
#      It handles vcard stuff and provides cache for it as well.
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: vcard.tcl,v 1.1 2005-11-04 15:14:55 matben Exp $

package require jlib

package provide jlib::vcard 0.1

namespace eval jlib::vcard {

    jlib::ensamble_register vcard  \
      [namespace current]::init    \
      [namespace current]::cmdproc
}

# jlib::vcard::init --
# 
#       Creates a new instance of a vcard object.
#       
# Arguments:
#       jlibname:     name of existing jabberlib instance
#       args:
# 
# Results:
#       namespaced instance command

proc jlib::vcard::init {jlibname args} {
    
    variable xmlns
	
    # Instance specific arrays.
    namespace eval ${jlibname}::vcard {
	variable state
    }
    upvar ${jlibname}::vcard::state state
    
    return
}

# jlib::vcard::cmdproc --
#
#       Just dispatches the command to the right procedure.
#
# Arguments:
#       jlibname:   name of existing jabberlib instance
#       cmd:        
#       args:       all args to the cmd procedure.
#       
# Results:
#       none.

proc jlib::vcard::cmdproc {jlibname cmd args} {
    
    # Which command? Just dispatch the command to the right procedure.
    return [eval {$cmd $jlibname} $args]
}

# jlib::vcard::send_get --
#
#       It implements the 'jabber:iq:vcard-temp' get method.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       to:         bare JID for other users, full jid for ourself.
#       cmd:        client command to be executed at the iq "result" element.
#       
# Results:
#       none.

proc jlib::vcard::send_get {jlibname to cmd} {
    upvar ${jlibname}::vcard::state state

    set state(pending,$to)
    set attrlist [list xmlns vcard-temp]    
    set xmllist [wrapper::createtag "vCard" -attrlist $attrlist]
    send_iq $jlibname "get" [list $xmllist] -to $to -command   \
      [list [namespace current]::send_get_cb $jlibname $to $cmd]
    
    return
}

# jlib::vcard::send_get_cb --
# 
#       Cache vcard info from above and call up.

proc jlib::vcard::send_get_cb {jlibname jid cmd type subiq} {
    upvar ${jlibname}::vcard::state state
    
    unset -nocomplain state(pending,$jid)
    set state(cache,$jid) $subiq
    invoke_stacked $jlibname $jid $type $subiq
    
    uplevel #0 $cmd [list $jlibname $type $subiq]
}

# jlib::vcard::get_async --
# 
#       Get vcard async using 'cmd' callback. 
#       If cached it is returned directly using 'cmd', if pending the cmd
#       is invoked when getting result, else we do a send_get.

proc jlib::vcard::get_async {jlibname jid cmd} {
    upvar ${jlibname}::vcard::state state

    if {[info exists state(cache,$jid)]} {
	uplevel #0 $cmd [list $jlibname result $state(cache,$jid)]
    } elseif {[info exists state(pending,$jid)]} {
	lappend state(invoke,$jid) $cmd
    } else {
	send_get $jlibname $jid $cmd
    }
    return
}

proc jlib::vcard::invoke_stacked {jlibname jid type subiq} {
    upvar ${jlibname}::vcard::state state

    if {[info exists state(invoke,$jid)]} {
	foreach cmd $state(invoke,$jid) {
	    uplevel #0 $cmd [list $jlibname $type $subiq]
	}
	unset -nocomplain state(invoke,$jid)
    }
}

proc jlib::vcard::has_cache {jlibname jid} {
    upvar ${jlibname}::vcard::state state
    
   return [info exists state(cache,$jid)] 
}

proc jlib::vcard::get_cache {jlibname jid} {
    upvar ${jlibname}::vcard::state state
    
   if {[info exists state(cache,$jid)]} {
       return $state(cache,$jid)
   } else {
       return
   }
}

# jlib::vcard::send_set --
#
#       Sends our vCard to the server. Internally we use all lower case
#       but the spec (JEP-0054) says that all tags be all upper case.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       cmd:        client command to be executed at the iq "result" element.
#       args:       All keys are named so that the element hierarchy becomes
#                   vcardElement_subElement_subsubElement ... and so on;
#                   all lower case.
#                   
# Results:
#       none.

proc jlib::vcard::send_set {jlibname cmd args} {

    set attrlist [list xmlns vcard-temp]    
    
    # Form all the sub elements by inspecting the -key.
    array set arr $args
    set subelem {}
    set subsubelem {}
    
    # All "sub" elements with no children.
    foreach tag {fn nickname bday url title role desc} {
	if {[info exists arr(-$tag)]} {
	    lappend subelem [wrapper::createtag [string toupper $tag] \
	      -chdata $arr(-$tag)]
	}
    }
    if {[info exists arr(-email_internet_pref)]} {
	set elem {}
	lappend elem [wrapper::createtag "INTERNET"]
	lappend elem [wrapper::createtag "PREF"]
	lappend subelem [wrapper::createtag "EMAIL" \
	  -chdata $arr(-email_internet_pref) -subtags $elem]
    }
    if {[info exists arr(-email_internet)]} {
	foreach email $arr(-email_internet) {
	    set elem {}
	    lappend elem [wrapper::createtag "INTERNET"]
	    lappend subelem [wrapper::createtag "EMAIL" \
	      -chdata $email -subtags $elem]
	}
    }
    
    # All "subsub" elements.
    foreach tag {n org} {
	set elem {}
	foreach key [array names arr "-${tag}_*"] {
	    regexp -- "-${tag}_(.+)" $key match sub
	    lappend elem [wrapper::createtag [string toupper $sub] \
	      -chdata $arr($key)]
	}
    
	# Insert subsub elements where they belong.
	if {[llength $elem]} {
	    lappend subelem [wrapper::createtag [string toupper $tag] \
	      -subtags $elem]
	}
    }
    
    # The <adr><home/>, <adr><work/> sub elements.
    foreach tag {adr_home adr_work} {
	regexp -- {([^_]+)_(.+)} $tag match head sub
	set elem [list [wrapper::createtag [string toupper $sub]]]
	set haveThisTag 0
	foreach key [array names arr "-${tag}_*"] {
	    set haveThisTag 1
	    regexp -- "-${tag}_(.+)" $key match sub
	    lappend elem [wrapper::createtag [string toupper $sub] \
	      -chdata $arr($key)]
	}		
	if {$haveThisTag} {
	    lappend subelem [wrapper::createtag [string toupper $head] \
	      -subtags $elem]
	}
    }	
    
    # The <tel> sub elements.
    foreach tag [array names arr "-tel_*"] {
	if {[regexp -- {-tel_([^_]+)_([^_]+)} $tag match second third]} {
	    set elem {}
	    lappend elem [wrapper::createtag [string toupper $second]]
	    lappend elem [wrapper::createtag [string toupper $third]]
	    lappend subelem [wrapper::createtag "TEL" -chdata $arr($tag) \
	      -subtags $elem]
	}
    }
    
    # The <photo> sub elements.
    if {[info exists arr(-photo_binval)]} {
	set elem {}
	lappend elem [wrapper::createtag "BINVAL" -chdata $arr(-photo_binval)]
	if {[info exists arr(-photo_type)]} {
	    lappend elem [wrapper::createtag "TYPE" -chdata $arr(-photo_type)]
	}
	lappend subelem [wrapper::createtag "PHOTO" -subtags $elem]
    }
    
    set xmllist [wrapper::createtag vCard -attrlist $attrlist \
      -subtags $subelem]
    send_iq $jlibname "set" [list $xmllist] -command \
      [list [namespace current]::invoke_iq_callback?????? $jlibname $cmd]    
    return
}

proc jlib::vcard::clear {{jid ""}} {
    upvar ${jlibname}::vcard::state state
    
    if {$jid eq ""} {
	array unset state "cache,*"
    } else {
	array unset state "cache,[jlib::ESC $jid]"
    }
}



