# entryex.tcl --
# 
#       Extended ttk::combobox widget.
# 
# Copyright (c) 2006 Mats Bengtsson
#  
# This file is distributed under BSD style license.
#       
# $Id: comboboxex.tcl,v 1.3 2007-12-22 14:52:22 matben Exp $

package require snit 1.0
package require msgcat

package provide ui::comboboxex 0.1

namespace eval ui::comboboxex {

    # New bindtag for this widget. Be sure not to override any commands.
    bind ComboboxEx <KeyPress>             { ui::EntryInsert %W %A }
    bind ComboboxEx <Control-KeyPress>     {# nothing}
    bind ComboboxEx <BackSpace>            {# nothing}
    bind ComboboxEx <Select>               {# nothing}
    bind ComboboxEx <Home>                 {# nothing}
    bind ComboboxEx <End>                  {# nothing}
    bind ComboboxEx <Delete>               {# nothing}
    bind ComboboxEx <<Cut>>                {# nothing}
    bind ComboboxEx <<Copy>>               {# nothing}
    bind ComboboxEx <<Paste>>              {# nothing}
    bind ComboboxEx <<Clear>>              {# nothing}
    bind ComboboxEx <<PasteSelection>>     {# nothing}
    bind ComboboxEx <Alt-KeyPress>         {# nothing}
    bind ComboboxEx <Meta-KeyPress>        {# nothing}
    bind ComboboxEx <Control-KeyPress>     {# nothing}
    bind ComboboxEx <Escape>               {# nothing}
    bind ComboboxEx <Return>               {# nothing}
    bind ComboboxEx <KP_Enter>             {# nothing}
    bind ComboboxEx <Tab>                  {# nothing}
    if {[string equal [tk windowingsystem] "aqua"]} {
	bind ComboboxEx <Command-KeyPress> {# nothing}
    }
}

interp alias {} ui::comboboxex {} ui::comboboxex::widget

# ui::entryex --
# 
#       Extended entry widget.

snit::widgetadaptor ui::comboboxex::widget {

    delegate option * to hull except {-type -library}
    delegate method * to hull
    
    option -library {}
    option -type    -default ttk ;#-configuremethod SetType

    
    constructor {args} {
	set type [from args -type "ttk"]
	installhull using ttk::combobox
	
	set tags [bindtags $win]
	if {[set idx [lsearch -exact $tags TCombobox]] < 0} {
	    set idx 1
	}
	bindtags $win [linsert $tags $idx ComboboxEx]
	$self configurelist $args
	return
    }
    
    method SetType {option value} {
	return -code error "-type option may not be modified after creation"
    }
}

#-------------------------------------------------------------------------------
