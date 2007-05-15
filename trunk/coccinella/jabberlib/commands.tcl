#  commands.tcl --
#  
#      This file is part of the jabberlib. 
#      It provides support for XEP-0050: Ad-Hoc Commands
#      
#  Copyright (c) 2007  Mats Bengtsson
#  
# $Id: commands.tcl,v 1.1 2007-05-15 14:09:34 matben Exp $
# 
############################# USAGE ############################################
#
#   NAME
#      commands - convenience library for ad-hoc commands.
#      
#   SYNOPSIS
#
#
#   OPTIONS
#
#	
#   INSTANCE COMMANDS
#      jlibName commands ...
#      
################################################################################

package require jlib
package require jlib::disco

package provide jlib::commands 0.1

namespace eval jlib::commands {
    variable xmlns
    set xmlns(x-avatar)   "http://jabber.org/protocol/commands"

    jlib::ensamble_register commands \
      [namespace current]::init      \
      [namespace current]::cmdproc
        
    # Note: jlib::ensamble_register is last in this file!
}

proc jlib::commands::init {jlibname args} {

    variable xmlns
    
    # Instance specific arrays:
    namespace eval ${jlibname}::commands {
	variable state
    }
    upvar ${jlibname}::commands::state   state


    return
}

proc jlib::commands::reset {jlibname} {
    upvar ${jlibname}::avatar::state state


}

# jlib::commands::cmdproc --
#
#       Just dispatches the command to the right procedure.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       cmd:        
#       args:       all args to the cmd procedure.
#       
# Results:
#       none.

proc jlib::commands::cmdproc {jlibname cmd args} {
    
    # Which command? Just dispatch the command to the right procedure.
    return [eval {$cmd $jlibname} $args]
}


# We have to do it here since need the initProc before doing this.

namespace eval jlib::avatar {

    jlib::ensamble_register avatar \
      [namespace current]::init    \
      [namespace current]::cmdproc
}

#-------------------------------------------------------------------------------
