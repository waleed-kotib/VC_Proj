# WSearch.tcl
#
#       Megawidget for searching a text widget.
#       
# Copyright (c) 2006 Mats Bengtsson
#       
# $Id: WSearch.tcl,v 1.1 2006-08-01 14:01:25 matben Exp $

package require snit 1.0
package require tileutils 0.1

package provide UI::WSearch 1.0

namespace eval UI::WSearch {

    # New bindtag for this widget. Be sure not to override any commands.
    # @@@ There are some more text editing commands to be added.
    # @@@ Or use -textvariable and trace it?

    bind TextSearch <KeyPress>             { [winfo parent %W] Event }
    bind TextSearch <BackSpace>            { [winfo parent %W] Event }
    bind TextSearch <Delete>               { [winfo parent %W] Event }
    bind TextSearch <<Cut>>                { [winfo parent %W] Event }
    bind TextSearch <<Copy>>               { [winfo parent %W] Event }
    bind TextSearch <<Paste>>              { [winfo parent %W] Event }
    bind TextSearch <<Clear>>              { [winfo parent %W] Event }
    bind TextSearch <<PasteSelection>>     { [winfo parent %W] Event }
    bind TextSearch <Control-KeyPress>     {# nothing}
    bind TextSearch <Select>               {# nothing}
    bind TextSearch <Home>                 {# nothing}
    bind TextSearch <End>                  {# nothing}
    bind TextSearch <Alt-KeyPress>         {# nothing}
    bind TextSearch <Meta-KeyPress>        {# nothing}
    bind TextSearch <Control-KeyPress>     {# nothing}
    bind TextSearch <Escape>               {# nothing}
    bind TextSearch <Return>               {# nothing}
    bind TextSearch <KP_Enter>             {# nothing}
    bind TextSearch <Tab>                  {# nothing}
    if {[string equal [tk windowingsystem] "aqua"]} {
	bind TextSearch <Command-KeyPress> {# nothing}
    }
    
    option add *WSearch.highlightBackground   yellow
    option add *WSearch.foundBackground       green
}

interp alias {} UI::WSearch    {} UI::WSearch::widget

# UI::WSearch --
# 
#       Search text megawidget.

snit::widgetadaptor UI::WSearch::widget {
    
    variable wtext
    variable wentry
    variable wnext
    variable idxs
    variable idxfocus
    
    delegate method * to hull
    delegate option * to hull 

    constructor {_wtext args} {
	
	set wtext $_wtext
	set wentry $win.entry
	set wnext $win.next

	installhull using ttk::frame -class WSearch
	$self configurelist $args

	set subPath [file join images 16]
	set im  [::Theme::GetImage closeAqua $subPath]
	set ima [::Theme::GetImage closeAquaActive $subPath]

	ttk::button $win.close -style Plain  \
	  -image [list $im active $ima] -compound image  \
	  -command [list $self Close]
	ttk::label $win.find -style Small.TLabel -padding {4 0 0 0}  \
	  -text "[mc Find]:"
	ttk::entry $win.entry -style Small.Search.TEntry -font CociSmallFont
	ttk::button $win.next -style Small.TButton -command [list $self Next] \
	  -text [mc Next]
	
	grid  $win.close  $win.find  $win.entry  $win.next
	grid $win.next -padx 4
	grid columnconfigure $win 2 -weight 1
	
	$wnext state {disabled}
	
	set hbg [option get $win highlightBackground {}]
	set fbg [option get $win foundBackground {}]
	
	if {[lsearch [$wtext tag names] thighlight] < 0} {
	    $wtext tag configure thighlight -background $hbg
	}
	if {[lsearch [$wtext tag names] tfound] < 0} {
	    $wtext tag configure tfound -background $fbg
	}
	set tags [bindtags $wentry]
	if {[set idx [lsearch -exact $tags TEntry]] < 0} {
	    set idx 1
	}
	bindtags $wentry [linsert $tags [incr idx] TextSearch]
	focus $wentry
	
	return
    }
    
    destructor {
	if {[winfo exists $wtext]} {
	    $wtext tag remove thighlight 1.0 end
	    $wtext tag remove tfound 1.0 end
	}
    }

    method Event {} {
	
	$wtext tag remove thighlight 1.0 end
	$wtext tag remove tfound 1.0 end
	set str [$wentry get]
	set idxs [$self FindAll]
	set idx0 [lindex $idxs 0]
	if {$idxs eq {}} {
	    $wentry state {invalid}
	} else {
	    $wentry state {!invalid}
	    $wtext see [lindex $idxs 0]
	    set len [string length $str]
	    foreach idx $idxs {
		$wtext tag add thighlight $idx "$idx + $len chars"
	    }
	    $wtext tag add tfound $idx0 "$idx0 + $len chars"
	}
	if {[llength $idxs] > 1} {
	    $wnext state {!disabled}
	} else {
	    $wnext state {disabled}
	}
	set idxfocus $idx0
    }
    
    method FindAll {} {
	set idxs {}
	set str [$wentry get]
	set len [string length $str]
	set idx [$wtext search -nocase $str 1.0]
	if {$idx ne ""} {
	    set first $idx
	    lappend idxs $idx
	    while {[set idx [$wtext search -nocase $str "$idx + $len chars"]] ne $first} {
		lappend idxs $idx
	    }
	}
	return $idxs
    }

    method Next {} {
	$wtext tag remove tfound 1.0 end
	set ind [lsearch $idxs $idxfocus]
	if {$ind >= 0} {
	    if {[expr {$ind+1}] == [llength $idxs]} {
		set ind 0
	    } else {
		incr ind
	    }
	    set idxfocus [lindex $idxs $ind]
	    set len [string length [$wentry get]]
	    $wtext tag add tfound $idxfocus "$idxfocus + $len chars"
	    $wtext see $idxfocus
	}
    }
    
    method Close {} {
	destroy $win
    }
}
    
if {0} {
    # Test code:
    set top ._bgh
    toplevel $top
    pack [text $top.t] -expand 1 -fill both
    $top.t insert end {The text command creates a new window (given by the pathName argument) and makes it into a text widget. Additional options, described above, may be specified on the command line or in the option database to configure aspects of the text such as its default background color and relief.  The text command returns the path name of the new window. 
    
    A text widget displays one or more lines of text and allows that text to be edited. Text widgets support four different kinds of annotations on the text, called tags, marks, embedded windows or embedded images. Tags allow different portions of the text to be displayed with different fonts and colors. In addition, Tcl commands can be associated with tags so that scripts are invoked when particular actions such as keystrokes and mouse button presses occur in particular ranges of the text. See TAGS below for more details.}
    
    pack [ttk::frame $top.f -padding 6] -fill x
    set w $top.f.s
    UI::WSearch $w $top.t
    pack $w -side left
    
    proc DoFind {} {
	if {![winfo exists $::w]} {
	    UI::WSearch $::w $::top.t
	    pack $::w -side left
	}
    }
    proc DoNext {} {$::w Next}
    bind $top <Command-f> DoFind
    bind $top <Command-g> DoNext
}
    

