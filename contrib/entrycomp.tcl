#  entrycomp.tcl ---
#  
#      This file is part of the whiteboard application. It implements an
#      entry with completion.
#      
#  Copyright (c) 2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: entrycomp.tcl,v 1.3 2003-10-25 07:22:26 matben Exp $
#
# ########################### USAGE ############################################
#
#   NAME
#      entrycomp - an entry with input completion.
#      
#   SYNOPSIS
#      entrycomp pathName liblist ?options?
#      
#   OPTIONS
#      all entry widget options
#      
#   WIDGET COMMANDS
#      Identical to the entry widget
#
# ########################### CHANGES ##########################################
#
#       0.1      first release
#       0.2      using bindtags instead

package provide entrycomp 0.2

namespace eval ::entrycomp:: {

    # The public interface.
    namespace export entrycomp

    # Globals same for all instances of this widget.
    variable priv
    
    set priv(debug) 0
    set priv(initted) 0
    
    # New bindtag for this widget. Be sure not to override any commands.
    bind EntryComp <KeyPress> [list ::entrycomp::Insert %W %A]
    bind EntryComp <Control-KeyPress> {# nothing}
    bind EntryComp <BackSpace> {# nothing}
    bind EntryComp <Select> {# nothing}
    bind EntryComp <Home> {# nothing}
    bind EntryComp <End> {# nothing}
    bind EntryComp <Delete> {# nothing}
    bind EntryComp <<Cut>> {# nothing}
    bind EntryComp <<Copy>> {# nothing}
    bind EntryComp <<Paste>> {# nothing}
    bind EntryComp <<Clear>> {# nothing}
    bind EntryComp <<PasteSelection>> {# nothing}
    bind EntryComp <Alt-KeyPress> {# nothing}
    bind EntryComp <Meta-KeyPress> {# nothing}
    bind EntryComp <Control-KeyPress> {# nothing}
    bind EntryComp <Escape> {# nothing}
    bind EntryComp <Return> {# nothing}
    bind EntryComp <KP_Enter> {# nothing}
    bind EntryComp <Tab> {# nothing}
    if {[string equal [tk windowingsystem] "classic"]
            || [string equal [tk windowingsystem] "aqua"]} {
	bind EntryComp <Command-KeyPress> {# nothing}
    }
}

proc ::entrycomp::Init { } {
    variable priv
    
    set priv(initted) 1
}

# ::entrycomp::entrycomp --
#
#       Creates an entry with pattern completion.
#       
# Arguments:
#       w           widget path
#       liblist     library list to search in
#       args        options for the entry widget
#       
# Results:
#       Wiidget path

proc ::entrycomp::entrycomp {w liblist args} {
    variable priv
    
    if {!$priv(initted)} {
	::entrycomp::Init
    }
    # Instance specific namespace
    namespace eval ::entrycomp::${w} {
	variable options
    }
    
    # Set simpler variable names.
    upvar ::entrycomp::${w}::options options
    
    set options(liblist) $liblist

    eval {entry $w} $args
    set bindList [bindtags $w]
    set ind [lsearch $bindList Entry]
    if {$ind >= 0} {
	set bindList [linsert $bindList $ind EntryComp]
	bindtags $w $bindList
    }
    
    # This allows us to clean up some things when we go away.
    bind $w <Destroy> [list [namespace current]::DestroyHandler $w]
    return $w
}

# ::entrycomp::Insert --
# 
#       Callback for <KeyPress> that replaces the Entry's binding.

proc ::entrycomp::Insert {w s} {
    variable priv
    upvar ::entrycomp::${w}::options options
    
    if {[string equal $s ""]} {
	return
    }
    catch {$w delete sel.first sel.last}
    set str [$w get]
    set insert [expr [$w index insert] + 1]
    set white [string range $str 0 $insert]
    append white $s
    $w insert insert $s
    
    # Find matches in liblist.
    set mlist [lsearch -glob -inline -all $options(liblist) ${white}*]
    if {[llength $mlist]} {
	set mstr [lindex $mlist 0]
	$w delete 0 end
	$w insert insert $mstr
	$w selection range $insert end
	$w icursor $insert
    } else {
	#$w delete $insert end
    }    
    ::tk::EntrySeeInsert $w
    
    # Stop Entry class handler from executing, else we get double characters.
    # Problem: this also stops handlers bound to the toplevel bindtag!!!!!
    return -code break
}

# entrycomp::DestroyHandler --
#
#       The exit handler of a entrycomp.
#       
# Arguments:
#       w       the widget path.
#       
# Results:
#       the internal state is cleaned up, namespace deleted.

proc ::entrycomp::DestroyHandler {w} {
    
    # Remove the namespace with the widget.
    namespace delete ::entrycomp::${w}
}

# test
if {0} {
    set liblist {abcdefg abcert abczzz abc123 zzz uuu www}
    toplevel .top
    pack [::entrycomp::entrycomp .top.ent1 $liblist]
    pack [::entrycomp::entrycomp .top.ent2 $liblist]
    pack [::entrycomp::entrycomp .top.ent3 $liblist]
}
#-------------------------------------------------------------------------------
