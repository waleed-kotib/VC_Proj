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

    ttk::frame $w.frall
    pack  $w.frall  -fill x

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack  $wbox  -fill both -expand 1

    set wtext $wbox.t
    text $wbox.t -width 60 -height 8
    pack $wbox.t -fill both -expand 1
    
    set wnav $wbox.nav
    ttk::frame $wbox.nav
    pack $wbox.nav -side top -anchor e
    
    ttk::button $wnav.prev -style Small.TButton -text [mc Previous] \
      -command [namespace code [list Navigate -1]]
    ttk::button $wnav.next -style Small.TButton -text [mc Next] \
      -command [namespace code [list Navigate 1]]
    grid  $wnav.prev  $wnav.next  -padx 4 -pady 4
    
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::checkbutton $frbot.c -style Small.TCheckbutton \
      -text [mc "Show tips on startup"] \
      -variable [namespace current]::opts(show)
    ttk::button $frbot.btok -text [mc OK] -default active \
      -command [list destroy $w]
    pack $frbot.btok -side right
    pack $frbot.c -side left
    pack $frbot -side bottom -fill x
    
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

