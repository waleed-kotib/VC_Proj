# Totd.tcl
# 
#       Tip of today.

namespace eval ::Totd {}

proc ::Totd::Init {} {
    
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

    component::register Totd "Message of the day"
}

proc ::Totd::InitPrefsHook {} {
    variable opts
    
    set opts(dont) 0
    
    ::PrefUtils::Add [list [list ::Totd::opts(dont) totd_dont $opts(dont)]]
}

proc ::Totd::LaunchHook {} {
    variable opts
    
    if {!$opts(dont)} {
	Build
    }
}

proc ::Totd::Build {} {
    variable all
    variable opts
    
    set w .cmpnt_totd
    if {[winfo exists $w]} {
	raise $w
	return
    }
    ::UI::Toplevel $w -class Totd \
      -usemacmainmenu 1 -macstyle documentProc -macclass {document closeBox} \
      -closecommand ::Totd::Close
    wm title $w [mc "Tip of the day"]
    
    ::UI::SetWindowPosition $w

    ttk::frame $w.frall
    pack  $w.frall  -fill x

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack  $wbox  -fill both -expand 1

    text $wbox.t -width 60 -height 8
    pack $wbox.t -fill both -expand 1

    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::checkbutton $frbot.c -style Small.TCheckbutton \
      -text [mc "Do not show this any more"] \
      -variable [namespace current]::opts(dont)
    ttk::button $frbot.btok -text [mc Close] -default active \
      -command [list destroy $w]
    pack $frbot.btok -side right
    pack $frbot.c -side left
    pack $frbot -side bottom -fill x
    
    # Pick random message.
    set len [llength $all]
    set idx [expr {int($len*rand())}]
    set key [lindex $all $idx]
    $wbox.t insert 1.0 [mc totd-$key]

    return $w
}

proc ::Totd::Close {w} {
    ::UI::SaveWinGeom $w
}

