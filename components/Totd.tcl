# Totd.tcl
# 
#       Tip of the day.

namespace eval ::Totd {
    
    component::define Totd "Tip of the Day"

    option add *Totd.icon       coccinella       widgetDefault
    option add *Totd*Text.font  CociDefaultFont         50
}

proc ::Totd::Init {} {
    variable tips
    global prefs

    # Register menu entry.
    set menuDef [list command mTotd... {[mc "Tip of the Day"]...} {::Totd::Build}  {} {}]
    ::JUI::RegisterMenuEntry info $menuDef

    # Set system key for commands
    if {$::this(platform) eq "macosx"} {
    set ctrl "Cmd"
    } else {
    set ctrl "Ctrl"
    }

    # All tips should be listed below. 
    set tips [dict create]
    dict set tips 0 [mc "If the desired chat system is not available when you\
                     want to add a contact, this indicates no server support had\
                     been detected. Luckily, for most chat systems you can use\
                     another server without the need to register a new account.\
                     \n\n\
                     Instructions:\n\
                     1. Login to your account in %s.\n\
                     2. Select the Discover Server option in the Actions menu.\n\
                     3. Find a server with support for the desired chat system\
                        at http://coccinella.im/servers/servers.html (you can\
                        sort the columns).\n\
                     4. Enter the name of the desired server and proceed.\n\
                     5. The chat system will become available in the list!" $prefs(appName)]
    dict set tips 1 [mc "Typing the /clean command during a chat conversation\
                     will empty your chat window, whilst the /retain command will\
                     restore its content. Your contacts do not see these commands."]
    dict set tips 2 [mc "You might be interested in the hidden XML console if\
                     you are a developer. You can open it with the command\
                     %s+Shift+D" $ctrl]
    dict set tips 3 [mc "You can initiate a whiteboard session with multiple\
                     participants by clicking the whiteboard icon in a\
                     chatroom. All participants using %s will be invited." $prefs(appName)]
    dict set tips 4 [mc "Documentation is available at http://coccinella.im/documentation"]
    ::hooks::register launchFinalHook ::Totd::LaunchHook
    ::hooks::register prefsInitHook   ::Totd::InitPrefsHook

    component::register Totd
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
    variable tips
    variable opts
    variable current
    variable wtext
    global prefs
    
    set w .cmpnt_totd
    if {[winfo exists $w]} {
	raise $w
	return
    }
    ::UI::Toplevel $w -class Totd \
      -usemacmainmenu 1 -macstyle documentProc -macclass {document closeBox} \
      -closecommand ::Totd::Close
    wm title $w [mc "Tip of the Day"]
    
    ::UI::SetWindowPosition $w
    set icon [::Theme::Find128Icon $w icon]

    ttk::frame $w.frtips
    pack  $w.frtips  -fill x

    set wbox $w.frtips.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack  $wbox  -fill both -expand 1
            
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::checkbutton $frbot.c -style Small.TCheckbutton \
      -text [mc "Show tips on %s startup" $prefs(appName)] \
      -variable [namespace current]::opts(show)
    ttk::button $frbot.btok -text [mc "OK"] -default active \
      -command [list destroy $w]
    ttk::button $frbot.next -text [mc "Next"] \
      -command [namespace code [list Navigate 1]]
    ttk::button $frbot.prev -text [mc "Previous"] \
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
    set len [dict size $tips]
    set idx [expr {int($len*rand())}]
    ::Text::Parse $wtext [dict get $tips $idx] ""
    
    set current $idx

    return $w
}

proc ::Totd::Navigate {dir} {
    variable tips
    variable current
    variable wtext
    
    $wtext delete 1.0 end
    set len [dict size $tips]
    set idx [expr {$current + $dir}]
    if {$idx < 0} {
	incr idx $len
    } elseif {$idx >= $len} {
	incr idx -$len
    }
    set current $idx
    ::Text::Parse $wtext [dict get $tips $idx] ""
}

proc ::Totd::Close {w} {
    ::UI::SaveWinGeom $w
}

