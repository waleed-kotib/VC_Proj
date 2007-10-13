# XMLConsole.tcl --
# 
#       A simple XML console.
#       This is just a first sketch.
#
#  Copyright (c) 2007 Mats Bengtsson and Antonio Camas
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
# $Id: XMLConsole.tcl,v 1.1 2007-10-13 12:58:20 matben Exp $

namespace eval ::XMLConsole { 

    # TODO
    option add *XMLConsole*Text.tabsX                   4        widgetDefault
    option add *XMLConsole*Text.recvForeground          blue     widgetDefault
    option add *XMLConsole*Text.sendForeground          red      widgetDefault
}

proc ::XMLConsole::Init {} {
    global  this
    
    component::register XMLConsole "Simple XML console ($this(modkey)-Shift-D)"
    
    ::hooks::register prefsInitHook  [namespace code InitPrefsHook]
    
    bind all <$this(modkey)-Shift-Key-D> [namespace code OnCmd]
}

proc ::XMLConsole::OnCmd {} {
    Build   
}

proc ::XMLConsole::InitPrefsHook {} {
    variable opts
    
    set opts(pretty) 1
    
    ::PrefUtils::Add [list [list ::Totd::opts(pretty) xmlconsole_pretty $opts(pretty)]]
}

proc ::XMLConsole::Build {} {
    global  config
    variable opts
    
    set w .cmpnt_xml
    if {[winfo exists $w]} {
	raise $w
	return
    }
    set token [namespace current]::$w
    variable $w
    upvar 0 $w state    

    ::UI::Toplevel $w -class XMLConsole \
      -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document {closeBox resizable}} \
      -closecommand [namespace code Close]
    wm title $w [mc "XML Console"]
    
    ::UI::SetWindowGeometry $w

    ttk::frame $w.frall
    pack  $w.frall  -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack  $wbox  -fill both -expand 1

    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::checkbutton $frbot.c -style Small.TCheckbutton \
      -text [mc "Pretty format"] -variable $token\(pretty)
    ttk::button $frbot.btok -text [mc Close] -default active \
      -command [list destroy $w]
    pack $frbot.btok -side right -padx 4
    pack $frbot.c -side left
    pack $frbot -side bottom -fill x

    set wframe $wbox.f
    set wtext  $wbox.f.t
    set wysc   $wbox.f.y
    
    if {$config(ui,aqua-text)} {
	frame $wframe
	set wcont [::UI::Text $wtext -height 16 -width 1 -state disabled -cursor {} -wrap word  \
	  -yscrollcommand [list ::UI::ScrollSet $wysc \
	  [list grid $wysc -column 1 -row 0 -sticky ns]]]
    } else {
	frame $wframe -bd 1 -relief sunken
	text $wtext -height 16 -width 1 -state disabled -cursor {} -wrap word  \
	  -yscrollcommand [list ::UI::ScrollSet $wysc \
	  [list grid $wysc -column 1 -row 0 -sticky ns]]
	set wcont $wtext
    }
    ttk::scrollbar $wysc -orient vertical -command [list $wtext yview]
    bindtags $wtext [linsert [bindtags $wtext] 0 ReadOnlyText]

    grid  $wcont  -column 0 -row 0 -sticky news
    grid  $wysc   -column 1 -row 0 -sticky ns
    grid columnconfigure $wframe 0 -weight 1
    grid rowconfigure    $wframe 0 -weight 1

    pack $wframe -side right -fill both -expand 1
    
    set tabsx  [option get $wtext tabsX {}]
    set recvfg [option get $wtext recvForeground {}]
    set sendfg [option get $wtext sendForeground {}]

    set font [$wtext cget -font]
    set tab [font measure $font [string repeat x $tabsx]]
    
    $wtext configure -tabs [list $tab left]
    
    $wtext tag configure trecv -foreground $recvfg
    $wtext tag configure tsend -foreground $sendfg
    
    set state(text)   $wtext
    set state(pretty) $opts(pretty)
    
    bind $w <Destroy> \
      +[subst { if {"%W" eq "$w"} { [namespace code [list Free %W]] } }]
    
    ::Jabber::JlibCmd tee_recv add [namespace code [list Recv $w]]
    ::Jabber::JlibCmd tee_send add [namespace code [list Send $w]]
    
    return $w
}

proc ::XMLConsole::Recv {w jlibname xmllist} {
    variable $w
    upvar 0 $w state    

    set wtext $state(text)
    if {$state(pretty)} {
	set xml [wrapper::formatxml $xmllist]
    } else {
	set xml [wrapper::createxml $xmllist]
    }
    $wtext configure -state normal
    $wtext insert end $xml trecv
    $wtext insert end "\n" trecv
    $wtext configure -state disabled
    $wtext see end
}

proc ::XMLConsole::Send {w jlibname xmllist} {
    variable $w
    upvar 0 $w state    
    
    set wtext $state(text)
    if {$state(pretty)} {
	set xml [wrapper::formatxml $xmllist]
    } else {
	set xml [wrapper::createxml $xmllist]
    }
    $wtext configure -state normal
    $wtext insert end $xml tsend
    $wtext insert end "\n" tsend
    $wtext configure -state disabled
    $wtext see end
}

proc ::XMLConsole::Close {w} {
    ::UI::SaveWinGeom $w
}

proc ::XMLConsole::Free {w} {
    variable opts
    variable $w
    upvar 0 $w state    

    set opts(pretty) $state(pretty)

    ::Jabber::JlibCmd tee_recv remove [namespace code [list Recv $w]]
    ::Jabber::JlibCmd tee_send remove [namespace code [list Send $w]]
    
    unset -nocomplain $w
}

