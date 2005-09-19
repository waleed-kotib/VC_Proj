# entryex.tcl --
# 
#       Extended entry widget.
# 
# Copyright (c) 2005 Mats Bengtsson
#       
# $Id: entryex.tcl,v 1.1 2005-09-19 06:37:20 matben Exp $

package require snit 1.0
package require tile
package require msgcat

package provide ui::entryex 0.1

namespace eval ui::entryex {

    # New bindtag for this widget. Be sure not to override any commands.
    bind EntryEx <KeyPress>             { ui::entryex::Insert %W %A }
    bind EntryEx <Control-KeyPress>     {# nothing}
    bind EntryEx <BackSpace>            {# nothing}
    bind EntryEx <Select>               {# nothing}
    bind EntryEx <Home>                 {# nothing}
    bind EntryEx <End>                  {# nothing}
    bind EntryEx <Delete>               {# nothing}
    bind EntryEx <<Cut>>                {# nothing}
    bind EntryEx <<Copy>>               {# nothing}
    bind EntryEx <<Paste>>              {# nothing}
    bind EntryEx <<Clear>>              {# nothing}
    bind EntryEx <<PasteSelection>>     {# nothing}
    bind EntryEx <Alt-KeyPress>         {# nothing}
    bind EntryEx <Meta-KeyPress>        {# nothing}
    bind EntryEx <Control-KeyPress>     {# nothing}
    bind EntryEx <Escape>               {# nothing}
    bind EntryEx <Return>               {# nothing}
    bind EntryEx <KP_Enter>             {# nothing}
    bind EntryEx <Tab>                  {# nothing}
    if {[string equal [tk windowingsystem] "aqua"]} {
	bind EntryEx <Command-KeyPress> {# nothing}
    }
}

interp alias {} ui::entryex {} ui::entryex::widget

# ui::entryex --
# 
#       Extended entry widget.

snit::widgetadaptor ui::entryex::widget {

    delegate option * to hull except {-type -library}
    delegate method * to hull
    
    option -library {}
    option -type    -default ttk -configuremethod SetType

    
    constructor {args} {
	set type $options(-type)
	if {![regexp {^(tk|ttk)$} $type]} {
	    return -code error "style must be one of: tk, ttk"
	}
	if {$type eq "tk"} {
	    set wtype entry
	} elseif {$type eq "ttk"} {
	    set wtype ttk::entry
	}
	installhull using $wtype
	
	set tags [bindtags $win]
	if {$type eq "tk"} {
	    set wclass Entry
	} elseif {$type eq "ttk"} {
	    set wclass TEntry
	}
	if {[set idx [lsearch -exact $tags $wclass]] < 0} {
	    set idx 1
	}
	bindtags $win [linsert $tags $idx EntryEx]
	$self configurelist $args
	return
    }
    
    method SetType {option value} {
	return -code error "-type option may not be modified after creation"
    }
}

# ui::EntryExInsert --
# 
#       Private method to ui::entryex. 
#       Needed since 'break' is not propagated internally in snit!

proc ui::entryex::Insert {win s} {
    if {![string length $s]} {
	return
    }
    catch {$win delete sel.first sel.last}
    set str [$win get]
    set insert [expr {[$win index insert] + 1}]
    set white [string range $str 0 $insert]
    append white $s
    $win insert insert $s
    
    set library [$win cget -library]
    set type    [$win cget -type]
    
    # Find matches in 'library'. Protect glob characters.
    set white [string map {* \\* ? \\? [ \\[ ] \\] \\ \\\\} $white]
    set mlist [lsearch -glob -inline -all $library ${white}*]
    if {[llength $mlist]} {
	set mstr [lindex $mlist 0]
	$win delete 0 end
	$win insert insert $mstr
	$win selection range $insert end
	$win icursor $insert
    } else {
	#$win delete $insert end
    }    
    if {$type eq "tk"} {
	::tk::EntrySeeInsert $win
    } else {
	tile::entry::See $win insert
    }
    
    # Stop class handler from executing, else we get double characters.
    # @@@ Problem: this also stops handlers bound to the toplevel bindtag!!!!!
    return -code break
}

#-------------------------------------------------------------------------------
