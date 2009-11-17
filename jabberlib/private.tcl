#  private.tcl --
#
#      This file is part of the jabberlib. 
#      It handles private XML storage/retrieval, as described in XEP-0049
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
#      private - convenience command library for the private XML 
#      storage extension.
#
#   SYNOPSIS
#      jlib::private::init jlibName ?-opt value ...?
#
#   INSTANCE COMMANDS
#      jlibname private send_get subtags callbackProc
#      jlibname private send_set subtags
#
################################################################################

package require jlib

package provide jlib::private 0.1

namespace eval jlib::private {
    # Note: jlib::ensamble_register is last in this file!
}

# jlib::private::init --
#
#       Creates a new instance of a private object.
#
# Arguments:
#       jlibname:     name of existing jabberlib instance
#       args:
#
# Results:
#       namespaced instance command

proc jlib::private::init {jlibname args} {
    variable xmlns
    set xmlns(private) "jabber:iq:private"

    return
}

# jlib::private::cmdproc --
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

proc jlib::private::cmdproc {jlibname cmd args} {
   
    # Which command? Just dispatch the command to the right procedure.
    return [eval {$cmd $jlibname} $args]
}

# jlib::private::send_get --
#
#       It implements the 'jabber:iq:private' get method.
#
# Arguments:
#       subtags:    list of elements to retrieve
#       cmd:        client command to be executed at the iq "result" element.
#
# Results:
#       none.

proc jlib::private::send_get {subtags cmd} {
    variable xmlns

    set attrlist [list xmlns $xmlns(private)]
    set xmllist [wrapper::createtag "query" -attrlist $attrlist \
	-subtags [list $subtags]]
    jlib::send_iq ::jlib::jlib1 "get" [list $xmllist] -command $cmd
    return
}

# jlib::private::send_set --
#
#       It implements the 'jabber:iq:private' set method.
#
# Arguments:
#       subtags:    list of elements to store
#
# Results:
#       none.

proc jlib::private::send_set {subtags} {
    variable xmlns

    set attrlist [list xmlns $xmlns(private)]
    set xmllist [wrapper::createtag "query" -attrlist $attrlist \
        -subtags [list $subtags]]
    jlib::send_iq ::jlib::jlib1 "set" [list $xmllist]
    return
}

# We have to do it here since need the initProc before doing this.

namespace eval jlib::private {
 
    jlib::ensamble_register private  \
      [namespace current]::init    \
      [namespace current]::cmdproc
}
