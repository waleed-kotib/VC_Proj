#  sipub.tcl --
#  
#      This file is part of the jabberlib. 
#      It provides support for the sipub prootocol (XEP-0135).
#      
#  Copyright (c) 2007  Mats Bengtsson
#  
# This file is distributed under BSD style license.
#  
# $Id: sipub.tcl,v 1.1 2007-09-30 08:37:24 matben Exp $
# 

package require jlib		
package require jlib::si
package require jlib::disco
			  
package provide jlib::sipub 0.1

namespace eval jlib::sipub {

    variable xmlns
    set xmlns(sipub) "http://jabber.org/protocol/si/profile/sipub"
	        
    jlib::disco::registerfeature $xmlns(sipub)

    # Note: jlib::ensamble_register is last in this file!
}

proc jlib::sipub::init {jlibname args} {

    
}

proc jlib::sipub::cmdproc {jlibname cmd args} {
    return [eval {$cmd $jlibname} $args]
}




# We have to do it here since need the initProc before doing this.

namespace eval jlib::sipub {
	
    jlib::ensamble_register sipub  \
      [namespace current]::init           \
      [namespace current]::cmdproc
}

#-------------------------------------------------------------------------------
