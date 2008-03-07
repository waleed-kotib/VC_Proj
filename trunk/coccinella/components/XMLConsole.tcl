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
# $Id: XMLConsole.tcl,v 1.8 2008-03-07 10:40:05 matben Exp $

namespace eval ::XMLConsole { 

    component::define XMLConsole "Simple XML console <$this(modkey)-Shift-D>"

    # TODO
    option add *XMLConsole*Text.tabsX                    4        widgetDefault
    option add *XMLConsole*Text.trecvBackground          gray90   widgetDefault
    option add *XMLConsole*Text.trecvForeground          blue     widgetDefault
    option add *XMLConsole*Text.tsendBackground          gray80   widgetDefault
    option add *XMLConsole*Text.tsendForeground          red      widgetDefault
}

proc ::XMLConsole::Init {} {
    global  this
    
    component::register XMLConsole 
    
    ::hooks::register prefsInitHook  [namespace code InitPrefsHook]
    ::hooks::register loginHook      [namespace code LoginHook]
    ::hooks::register logoutHook     [namespace code LogoutHook]
    
    bind all <$this(modkey)-Shift-Key-D> [namespace code OnCmd]
}

proc ::XMLConsole::OnCmd {} {
    Build   
}

proc ::XMLConsole::InitPrefsHook {} {
    variable opts
    
    set opts(pretty) 1
    
    ::PrefUtils::Add [list [list ::XMLConsole::opts(pretty) xmlconsole_pretty $opts(pretty)]]
}

proc ::XMLConsole::LoginHook {} {
    
    foreach w [ui::findalltoplevelwithclass XMLConsole] {
	variable $w
	upvar 0 $w state
	$state(send) configure -state normal
    }
}

proc ::XMLConsole::LogoutHook {} {

    foreach w [ui::findalltoplevelwithclass XMLConsole] {
	variable $w
	upvar 0 $w state
	$state(send) delete 1.0 end
	$state(send) configure -state disabled	
    }
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

    ttk::frame $w.frall
    pack  $w.frall  -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack  $wbox  -fill both -expand 1

    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::checkbutton $frbot.c -style Small.TCheckbutton \
      -text [mc "Pretty format"] -variable $token\(pretty)
    ttk::button $frbot.btok -text [mc OK] -default active \
      -command [list destroy $w]
    ttk::button $frbot.clear -text [mc Clear] \
      -command [namespace code [list Clear $w]]

    set padx [option get . buttonPadX {}]
    pack $frbot.btok -side right
    pack $frbot.clear -side right -padx $padx
    pack $frbot.c -side left
    pack $frbot -side bottom -fill x

    # Frame to serve as container for the pane geometry manager.
    frame $wbox.m
    pack  $wbox.m  -side top -fill both -expand 1

    set width 60

    # Pane geometry manager.
    set wpane $wbox.m.p
    ttk::paned $wpane -orient vertical
    pack $wpane -side top -fill both -expand 1    

    # Log pane.
    set wlog  $wpane.l
    set wtext $wlog.t
    set wysc  $wlog.y
    
    if {$config(ui,aqua-text)} {
	frame $wlog
	set wcont [::UI::Text $wtext -height 16 -width $width -cursor {} -wrap word \
	  -yscrollcommand [list ::UI::ScrollSet $wysc \
	  [list grid $wysc -column 1 -row 0 -sticky ns]]]
    } else {
	frame $wlog -bd 1 -relief sunken
	text $wtext -height 16 -width $width -bd 0 -state disabled -cursor {} -wrap word \
	  -yscrollcommand [list ::UI::ScrollSet $wysc \
	  [list grid $wysc -column 1 -row 0 -sticky ns]]
	set wcont $wtext
    }
    ttk::scrollbar $wysc -orient vertical -command [list $wtext yview]
    
    # @@@ This suddenly stopped working???
    bindtags $wtext [linsert [bindtags $wtext] 0 ReadOnlyText]

    grid  $wcont  -column 0 -row 0 -sticky news
    grid  $wysc   -column 1 -row 0 -sticky ns
    grid columnconfigure $wlog 0 -weight 1
    grid rowconfigure    $wlog 0 -weight 1
    
    set font [$wtext cget -font]
    set tabsx [option get $wtext tabsX {}]
    set tab [font measure $font [string repeat x $tabsx]]    
    $wtext configure -tabs [list $tab left]
    $wtext tag configure trecv
    $wtext tag configure tsend
    
    ::Text::ConfigureTags $wtext

    set state(text) $wtext

    # Send pane.
    set wsend $wpane.s
    set wtext $wsend.t
    set wysc  $wsend.y
    
    if {$config(ui,aqua-text)} {
	frame $wsend
	set wcont [::UI::Text  $wtext -height 1 -width $width -wrap word \
	  -yscrollcommand [list ::UI::ScrollSet $wysc \
	  [list grid $wysc -column 1 -row 0 -sticky ns]]]
    } else {
	frame $wsend -bd 1 -relief sunken
	text  $wtext -height 1 -width $width -bd 0 -wrap word \
	  -yscrollcommand [list ::UI::ScrollSet $wysc \
	  [list grid $wysc -column 1 -row 0 -sticky ns]]
	set wcont $wtext
    }
    ttk::scrollbar $wysc -orient vertical -command [list $wtext yview]
    
    grid  $wcont  -column 0 -row 0 -sticky news
    grid  $wysc   -column 1 -row 0 -sticky ns
    grid columnconfigure $wsend 0 -weight 1
    grid rowconfigure    $wsend 0 -weight 1
    
    if {![::Jabber::IsConnected]} {
	$wtext configure -state disabled
    }
    
    $wpane add $wlog  -weight 1
    $wpane add $wsend -weight 0
    
    set state(send)   $wtext
    set state(pretty) $opts(pretty)
    
    bind $wtext <Return> [namespace code [list DoSend $w]]
    bind $w <Destroy> \
      +[subst { if {"%W" eq "$w"} { [namespace code [list Free %W]] } }]

    ::UI::SetWindowGeometry $w
    
    ::Jabber::Jlib tee_recv add [namespace code [list Recv $w]]
    ::Jabber::Jlib tee_send add [namespace code [list Send $w]]
    
    return $w
}

proc ::XMLConsole::DoSend {w} {
    variable $w
    upvar 0 $w state
    
    set wstext $state(send)
    set xml [string trim [$wstext get 1.0 end]]
    
    ::Jabber::Jlib sendraw $xml
    $wstext delete 1.0 end
    
    set wtext $state(text)
    $wtext configure -state normal
    $wtext insert end $xml tsend
    $wtext insert end "\n" tsend
    $wtext configure -state disabled
    $wtext see end
    
    return -code break
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

proc ::XMLConsole::Clear {w} {
    variable $w
    upvar 0 $w state    

    set wtext $state(text)
    $wtext configure -state normal
    $wtext delete 1.0 end
    $wtext configure -state disabled
}

proc ::XMLConsole::Close {w} {
    ::UI::SaveWinGeom $w
}

proc ::XMLConsole::Free {w} {
    variable opts
    variable $w
    upvar 0 $w state    

    set opts(pretty) $state(pretty)

    ::Jabber::Jlib tee_recv remove [namespace code [list Recv $w]]
    ::Jabber::Jlib tee_send remove [namespace code [list Send $w]]
    
    unset -nocomplain $w
}

