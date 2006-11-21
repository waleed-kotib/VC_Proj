#  vcard.tcl --
#  
#      This file is part of the jabberlib.
#      It handles vcard stuff and provides cache for it as well.
#      
#  Copyright (c) 2005-2006  Mats Bengtsson
#  
# $Id: vcard.tcl,v 1.9 2006-11-21 07:51:19 matben Exp $
# 
############################# USAGE ############################################
#
#   NAME
#      vcard - convenience command library for the vcard extension.
#      
#   SYNOPSIS
#      jlib::vcard::init jlibName ?-opt value ...?
#	
#   INSTANCE COMMANDS
#      jlibname vcard send_get jid callbackProc
#      jlibname vcard send_set jid callbackProc
#      jlibname vcard get_async jid callbackProc
#      jlibname vcard has_cache jid
#      jlibname vcard get_cache jid
#      
################################################################################

package require jlib

package provide jlib::vcard 0.1

namespace eval jlib::vcard {

    # Note: jlib::ensamble_register is last in this file!
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
    set xmlns(vcard) "vcard-temp"
	
    # Instance specific arrays.
    namespace eval ${jlibname}::vcard {
	variable state
    }
    upvar ${jlibname}::vcard::state state
    
    set state(cache) 1
    
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
#       jid:        bare JID for other users, full jid for ourself.
#       cmd:        client command to be executed at the iq "result" element.
#       
# Results:
#       none.

proc jlib::vcard::send_get {jlibname jid cmd} {
    variable xmlns
    upvar ${jlibname}::vcard::state state

    set mjid [jlib::jidmap $jid]
    set state(pending,$mjid) 1
    set attrlist [list xmlns $xmlns(vcard)]    
    set xmllist [wrapper::createtag "vCard" -attrlist $attrlist]
    jlib::send_iq $jlibname "get" [list $xmllist] -to $jid -command   \
      [list [namespace current]::send_get_cb $jlibname $jid $cmd]    
    return
}

# jlib::vcard::send_get_cb --
# 
#       Cache vcard info from above and call up.

proc jlib::vcard::send_get_cb {jlibname jid cmd type subiq} {
    upvar ${jlibname}::vcard::state state
    
    set mjid [jlib::jidmap $jid]
    unset -nocomplain state(pending,$mjid)
    if {$state(cache)} {
	set state(cache,$mjid) $subiq
    }
    InvokeStacked $jlibname $jid $type $subiq
    
    uplevel #0 $cmd [list $jlibname $type $subiq]
}

# jlib::vcard::get_async --
# 
#       Get vcard async using 'cmd' callback. 
#       If cached it is returned directly using 'cmd', if pending the cmd
#       is invoked when getting result, else we do a send_get.

proc jlib::vcard::get_async {jlibname jid cmd} {
    upvar ${jlibname}::vcard::state state

    set mjid [jlib::jidmap $jid]
    if {[info exists state(cache,$mjid)]} {
	uplevel #0 $cmd [list $jlibname result $state(cache,$mjid)]
    } elseif {[info exists state(pending,$mjid)]} {
	lappend state(invoke,$mjid) $cmd
    } else {
	send_get $jlibname $jid $cmd
    }
    return
}

proc jlib::vcard::InvokeStacked {jlibname jid type subiq} {
    upvar ${jlibname}::vcard::state state

    set mjid [jlib::jidmap $jid]
    if {[info exists state(invoke,$mjid)]} {
	foreach cmd $state(invoke,$mjid) {
	    uplevel #0 $cmd [list $jlibname $type $subiq]
	}
	unset -nocomplain state(invoke,$mjid)
    }
}

# jlib::vcard::get_own_async --
# 
#       Getting and setting owns vcard is special since lacks to attribute.

proc jlib::vcard::get_own_async {jlibname cmd} {
    upvar ${jlibname}::vcard::state state

    set jid [$jlibname myjid2]
    set mjid [jlib::jidmap $jid]
    if {[info exists state(cache,$mjid)]} {
	uplevel #0 $cmd [list $jlibname result $state(cache,$mjid)]
    } elseif {[info exists state(pending,$mjid)]} {
	lappend state(invoke,$mjid) $cmd
    } else {
	send_get_own $jlibname $cmd
    }
    return
}

proc jlib::vcard::send_get_own {jlibname cmd} {
    variable xmlns

    # A user may retrieve his or her own vCard by sending XML of the 
    # following form to his or her own JID (the 'to' attribute SHOULD NOT 
    # be included).
    set attrlist [list xmlns $xmlns(vcard)]    
    set xmllist [wrapper::createtag "vCard" -attrlist $attrlist]
    jlib::send_iq $jlibname "get" [list $xmllist] -command   \
      [list [namespace current]::send_get_own_cb $jlibname $cmd]
}

proc jlib::vcard::send_get_own_cb {jlibname cmd type subiq} {
    upvar ${jlibname}::vcard::state state
    
    set jid [$jlibname myjid2]
    set mjid [jlib::jidmap $jid]
    unset -nocomplain state(pending,$mjid)
    if {$state(cache)} {
	set state(cache,$mjid) $subiq
    }    
    InvokeStacked $jlibname $jid $type $subiq

    uplevel #0 $cmd [list $jlibname $type $subiq]
}

# jlib::vcard::set_my_photo --
# 
#       A utility to set our vCard photo.
#       If photo empty then remove photo from vCard.

proc jlib::vcard::set_my_photo {jlibname photo mime cmd} {
    
    send_get_own $jlibname  \
      [list [namespace current]::get_my_photo_cb $photo $mime $cmd]
}

proc jlib::vcard::get_my_photo_cb {photo mime cmd jlibname type subiq} {
    variable xmlns
    
    # Replace or set an element:
    # 
    # <PHOTO>
    #     <TYPE>image/jpeg</TYPE>
    #     <BINVAL>Base64-encoded-avatar-file-here!</BINVAL>
    # </PHOTO> 

    if {$type eq "result"} {
	if {$photo ne ""} {
	    set newphoto 1
	    	    
	    # Replace or add photo. But only if different.
	    set photoElem [wrapper::getfirstchildwithtag $subiq "PHOTO"]
	    if {$photoElem ne {}} {
		set binElem [wrapper::getfirstchildwithtag $photoElem "BINVAL"]
		if {$binElem ne {}} {
		    set sphoto [wrapper::getcdata $binElem]
		    
		    # Base64 code can contain undefined spaces: decode!
		    set sdata [::base64::decode $sphoto]
		    set data  [::base64::decode $photo]
		    if {[string equal $sdata $data]} {
			set newphoto 0
		    }
		}
	    }
	    if {$newphoto} {
		lappend subElems [wrapper::createtag "TYPE" -chdata $mime]
		lappend subElems [wrapper::createtag "BINVAL" -chdata $photo]
		set photoElem [wrapper::createtag "PHOTO" -subtags $subElems]
		if {$subiq eq {}} {
		    set xmllist [wrapper::createtag "vCard"  \
		      -attrlist [list xmlns $xmlns(vcard)]   \
		      -subtags [list $photoElem]]
		} else {
		    set xmllist [wrapper::setchildwithtag $subiq $photoElem]
		}
		jlib::send_iq $jlibname "set" [list $xmllist] -command \
		  [list [namespace current]::set_my_photo_cb $jlibname $cmd]
	    }
	} else {
	    
	    # Remove any photo. If there is no PHOTO no need to set.
	    set photoElem [wrapper::getfirstchildwithtag $subiq "PHOTO"]
	    if {$photoElem ne {}} {
		set xmllist [wrapper::deletechildswithtag $subiq "PHOTO"]
		jlib::send_iq $jlibname "set" [list $xmllist] -command \
		  [list [namespace current]::set_my_photo_cb $jlibname $cmd]    
	    }
	}
    } else {
	uplevel #0 $cmd [list $jlibname $type $subiq]
    }
}

proc jlib::vcard::set_my_photo_cb {jlibname cmd type subiq} {
    
    uplevel #0 $cmd [list $jlibname $type $subiq]
}

proc jlib::vcard::has_cache {jlibname jid} {
    upvar ${jlibname}::vcard::state state
    
    set mjid [jlib::jidmap $jid]
    return [info exists state(cache,$mjid)] 
}

proc jlib::vcard::get_cache {jlibname jid} {
    upvar ${jlibname}::vcard::state state
    
    set mjid [jlib::jidmap $jid]
    if {[info exists state(cache,$mjid)]} {
	return $state(cache,$mjid)
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
    variable xmlns

    set attrlist [list xmlns $xmlns(vcard)]    
    
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
    
    set jid [$jlibname myjid2]
    set xmllist [wrapper::createtag "vCard" -attrlist $attrlist \
      -subtags $subelem]
    set state(cache,$jid) $xmllist
    jlib::send_iq $jlibname "set" [list $xmllist] -command \
      [list [namespace current]::send_set_cb $jlibname $cmd]    
    return
}

proc jlib::vcard::send_set_cb {jlibname cmd type subiq args} {
    
    uplevel #0 $cmd [list $jlibname $type $subiq]
}

proc jlib::vcard::cache {jlibname args} {
    upvar ${jlibname}::vcard::state state
    
    if {[llength $args] == 1} {
	set state(cache) [lindex $args 0]
    }
    return $state(cache)
}

proc jlib::vcard::clear {jlibname {jid ""}} {
    upvar ${jlibname}::vcard::state state
    
    if {$jid eq ""} {
	array unset state "cache,*"
    } else {
	set mjid [jlib::jidmap $jid]
	array unset state "cache,[jlib::ESC $mjid]"
    }
}

# We have to do it here since need the initProc before doing this.

namespace eval jlib::vcard {

    jlib::ensamble_register vcard  \
      [namespace current]::init    \
      [namespace current]::cmdproc
}



