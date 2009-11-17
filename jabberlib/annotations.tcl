#  annotations.tcl --
#
#      This file is part of the jabberlib. 
#      It handles annotations about roster items and other entities, 
#      as described in XEP-0145
#
#  Copyright (c) 2009 Sebastian Reitenbach 
#
# This file is distributed under BSD style license.
#
# $Id$
#
############################# USAGE ############################################
#
#   NAME
#      annotations - convenience command library for the annotations 
#      storage extension.
#
#   SYNOPSIS
#      jlib::annotations::init jlibName ?-opt value ...?
#
#   INSTANCE COMMANDS
#      jlibname annotations send_get storagens callbackProc
#      jlibname annotations send_set storagens subtags
#
################################################################################

package require jlib::private

package provide jlib::annotations 0.1

namespace eval jlib::annotations {
    
    # Rosternotes stored as {{jid Notes} ...}
    variable rosternotes {}
    variable xmlns
    set xmlns(rosternotes) "storage:rosternotes"
    set xmlns(coccinella) "storage:coccinella"
    set xmlns(bookmarks) "storage:bookmarks"

    # Note: jlib::ensamble_register is last in this file!
}

# jlib::annotations::init --
#
#       Creates a new instance of a annotations object.
#
# Arguments:
#       jlibname:     name of existing jabberlib instance
#       args:
#
# Results:
#       namespaced instance command

proc jlib::annotations::init {jlibname args} {

    return
}

# jlib::annotations::cmdproc --
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

proc jlib::annotations::cmdproc {jlibname cmd args} {
   
    # Which command? Just dispatch the command to the right procedure.
    return [eval {$cmd $jlibname} $args]
}

# jlib::annotations::send_get --
#
#       It implements the get method of stored data, for
#       for the given storage namespace.
#
# Arguments:
#       storagens:  retrieve data in given storage xmlns, e.g. rosternotes
#       cmd:        client command to be executed at the iq "result" element.
#
# Results:
#       none.

proc jlib::annotations::send_get {storagens cmd} {
    variable xmlns

    set attrlist [list xmlns $xmlns($storagens)]
    set storageElem [wrapper::createtag "storage" -attrlist $attrlist]

    ::jlib::private::send_get $storageElem $cmd
}

# jlib::annotations::send_set --
#
#       It implements the set method of stored data, for
#       the given storage namespace.
#
# Arguments:
#       storagens:   send data in given storage xmlns, e.g. rosternotes
#       subtags:     the data to be stored
#
# Results:
#       none.

proc jlib::annotations::send_set {storagens subtags} {
    variable xmlns

    ::Debug 4 "jlib::annotations::send_set: storagens=$storagens subtags=$subtags"
    set attrlist [list xmlns $xmlns($storagens)]
    set storageElem [wrapper::createtag "storage" -attrlist $attrlist \
        -subtags $subtags]

    ::jlib::private::send_set $storageElem
}

# We have to do it here since need the initProc before doing this.

namespace eval jlib::private {
 
    jlib::ensamble_register private  \
      [namespace current]::init    \
      [namespace current]::cmdproc
}
