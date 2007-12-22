# entryex.tcl --
# 
#       Extended entry widget.
# 
# Copyright (c) 2005 Mats Bengtsson
#  
# This file is distributed under BSD style license.
#       
# $Id: entryex.tcl,v 1.6 2007-12-22 14:52:22 matben Exp $

package require snit 1.0
package require msgcat

package provide ui::entryex 0.1

namespace eval ui::entryex {

    # New bindtag for this widget. Be sure not to override any commands.
    bind EntryEx <KeyPress>             { ui::EntryInsert %W %A }
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

interp alias {} ui::entryex    {} ui::entryex::widget

# ui::entryex --
# 
#       Extended entry widget.

snit::widgetadaptor ui::entryex::widget {

    delegate option * to hull except {-type -library}
    delegate method * to hull
    
    option -library {}
    option -type    -default ttk ;#-configuremethod SetType

    
    constructor {args} {
	set type [from args -type "ttk"]
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

#-------------------------------------------------------------------------------
