#  Component.tcl ---
#  
#      This file is part of The Coccinella application. It implements interface
#      to the component package. 
#      
#  Copyright (c) 2007  Mats Bengtsson
#  
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#   
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#   
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#  
# $Id: Component.tcl,v 1.3 2007-11-25 15:51:59 matben Exp $
   
package require component

package provide Component 1.0

namespace eval ::Component {
    
    # Add all event hooks.
    ::hooks::register prefsInitHook  ::Component::InitPrefsHook
}

proc ::Component::Load {} {
    global  this
    upvar ::Jabber::jprefs jprefs
    
    # Since we are so early in the launch process we do it this way.
    set offL [::PrefUtils::GetValue ::Jabber::jprefs(comp,off)  jprefs_comp_off {}]
    set jprefs(comp,off) $offL
    
    component::exclude $offL
    component::lappend_auto_path $this(componentPath)
    component::load
}

proc ::Component::InitPrefsHook {} {
    upvar ::Jabber::jprefs jprefs
    
    ::PrefUtils::Add [list  \
      [list ::Jabber::jprefs(comp,off)  jprefs_comp_off  $jprefs(comp,off)] ]
}

proc ::Component::Dlg {} {
    global  prefs this wDlgs
    upvar ::Jabber::jprefs jprefs
    variable state
    
    # Check first of there are *any* components.
    set compList [component::getall]
    if {[llength $compList] == 0} {
	::UI::MessageBox -icon info -type ok -message [mc messnoplugs]
	return  
    }
    set w $wDlgs(comp)
    if {[winfo exists $w]} {
	raise $w
	return
    }
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1
    wm title $w [mc Plugins]
     
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc OK] -command [namespace code [list OK $w]]
    ttk::button $frbot.btcancel -text [mc Cancel] -command [namespace code [list Cancel $w]]

    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
    }
    pack $frbot -side bottom -fill x

    set tbox $wbox.t
    frame $tbox -bd 1 -relief sunken
    pack  $tbox -fill both -expand 1

    set wtxt $tbox.txt
    set wysc $tbox.ysc
    ttk::scrollbar $wysc -orient vertical -command [list $wtxt yview]
    text $wtxt -highlightthickness 0 -bd 0 \
      -bg white -wrap word -width 50 -height 16 -exportselection 1 \
      -yscrollcommand [list ::UI::ScrollSet $wysc \
      [list grid $wysc -column 1 -row 0 -sticky ns]]

    grid  $wtxt  -column 0 -row 0 -sticky news
    grid  $wysc  -column 1 -row 0 -sticky ns
    grid columnconfigure $tbox 0 -weight 1
    grid rowconfigure $tbox 0 -weight 1
    
    checkbutton $wtxt._tmp
    set cbwidth [winfo reqwidth $wtxt._tmp]
    destroy $wtxt._tmp
    set lm [expr {$cbwidth + 10}]

    $wtxt tag configure ttitle -foreground black \
      -spacing1 2 -spacing3 2 -lmargin1 $lm -font CociSmallBoldFont
    $wtxt tag configure ttxt -font CociSmallFont -wrap word -lmargin1 $lm \
      -lmargin2 $lm -spacing3 6
    
    set n 0
    foreach comp $compList {
	set name [lindex $comp 0]
	set text [lindex $comp 1]
	set state($name) [component::exists $name]
	
	checkbutton $wtxt.$n -variable [namespace current]::state($name) \
	  -background white
	$wtxt window create end -window $wtxt.$n -padx 4
	
	$wtxt insert end "$name\n" ttitle
	$wtxt insert end "$text\n" ttxt
	incr n
    }
    $wtxt configure -state disabled
    bind $w <Return> [list $frbot.btok invoke]

    return $w
}

proc ::Component::OK {w} {
    variable state
    upvar ::Jabber::jprefs jprefs
    
    set offL [list]
    foreach {name value} [array get state] {
	if {!$value} {
	    lappend offL $name
	}
    }
    set jprefs(comp,off) $offL
    destroy $w
}

proc ::Component::Cancel {w} {

    destroy $w
}

