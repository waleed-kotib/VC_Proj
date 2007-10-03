# Totd.tcl
# 
#       Tip of today.

namespace eval ::Totd {
    
    option add *Totd.icon       coci-es-shadow-128      widgetDefault
    option add *Totd*Text.font  CociDefaultFont         50
}

proc ::Totd::Init {} {
    
    if {$::this(vers,full) eq "0.96.4"} {
	return
    }
    
    set mDef {
	command  mTotd...  ::Totd::Build  {} {}
    }
    ::JUI::RegisterMenuEntry info $mDef
        
    # All keys to message catalog must be listed here, 
    # see coccinella/msgs/components/Totd/
    variable all
    set all {
	first second third
    }
    ::hooks::register launchFinalHook ::Totd::LaunchHook
    ::hooks::register prefsInitHook   ::Totd::InitPrefsHook

    # Message catalog.
    set msgdir [file join $::this(msgcatCompPath) Totd]
    if {[file isdirectory $msgdir]} {
	uplevel #0 [list ::msgcat::mcload $msgdir]
    }

    component::register Totd "Useful tips"
}

proc ::Totd::InitPrefsHook {} {
    variable opts
    
    set opts(show) 1
    
    ::PrefUtils::Add [list [list ::Totd::opts(show) totd_show $opts(show)]]
}

proc ::Totd::LaunchHook {} {
    variable opts
    
    if {$opts(show)} {
	Build
    }
}

proc ::Totd::Build {} {
    variable all
    variable opts
    variable current
    variable wtext
    
    set w .cmpnt_totd
    if {[winfo exists $w]} {
	raise $w
	return
    }
    ::UI::Toplevel $w -class Totd \
      -usemacmainmenu 1 -macstyle documentProc -macclass {document closeBox} \
      -closecommand ::Totd::Close
    wm title $w [mc "Useful Tips"]
    
    ::UI::SetWindowPosition $w
    set icon [::Theme::GetImage [option get $w icon {}]]

    ttk::frame $w.frall
    pack  $w.frall  -fill x

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack  $wbox  -fill both -expand 1
            
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::checkbutton $frbot.c -style Small.TCheckbutton \
      -text [mc "Show tips on startup"] \
      -variable [namespace current]::opts(show)
    ttk::button $frbot.btok -text [mc OK] -default active \
      -command [list destroy $w]
    ttk::button $frbot.next -text [mc Next] \
      -command [namespace code [list Navigate 1]]
    ttk::button $frbot.prev -text [mc Previous] \
      -command [namespace code [list Navigate -1]]
    pack $frbot.btok $frbot.next $frbot.prev -side right -padx 4
    pack $frbot.c -side left
    pack $frbot -side bottom -fill x

    set wtext $wbox.t
    text $wbox.t -width 52 -height 12
    pack $wbox.t -side right -fill both -expand 1
    
    ttk::label $wbox.icon -compound image -image $icon -padding {0 0 6 0}
    pack $wbox.icon -side top

    # Pick random message.
    set len [llength $all]
    set idx [expr {int($len*rand())}]
    set key [lindex $all $idx]
    ::Text::Parse $wtext [mc totd-$key] ""
    
    set current $idx

    return $w
}

proc ::Totd::Navigate {dir} {
    variable all
    variable current
    variable wtext
    
    $wtext delete 1.0 end
    set len [llength $all]
    set idx [expr {$current + $dir}]
    if {$idx < 0} {
	incr idx $len
    } elseif {$idx >= $len} {
	incr idx -$len
    }
    set current $idx
    set key [lindex $all $idx]
    ::Text::Parse $wtext [mc totd-$key] ""
}

proc ::Totd::Close {w} {
    ::UI::SaveWinGeom $w
}

