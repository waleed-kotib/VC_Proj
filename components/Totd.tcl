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
    dict set tips 5 [mc "To override the automatic creation of the XMPP resource you can add\
                     /resourcename to your Contact ID."]
    dict set tips 6 [mc "Nicknames in chatrooms can be automatically completed using the TAB key.\
		     Enter the first letter(s) of the nickname and then use the TAB key to complete."]
    dict set tips 7 [mc "You can carry %s with you on an USB stick and use the same configuration\
                     on different computers. You can create such a cross-platform portable %s USB\
                     stick this way:\n\n\
		     1. Create a folder on the USB stick.\n\
		     2. Put in this folder the Coccinella binaries (for Windows, Linux and Mac OS X).\
                        Of course you do not necessarily need all binaries, for instance in case\
                        you do not want to use the USB stick on Windows computers.\n\
		     3. Then open on each platform (Windows, Linux and Mac OS X) the binary for that platform.\n\
		     4. Go each time to Preferences and enable the checkbox option\
                        'Store preferences in same folder as program' (on the General page).\n\
		     5. Preferences will now be saved on the USB stick in the same folder as the binary." $prefs(appName) $prefs(appName)]
    dict set tips 8 [mc "%s is free software. This means you have the freedom to improve %s for\
		     internal use without breaking copyright laws. Feel free to contribute\
		     improvements back to the project so that others can build upon your contribution.\
                     Check out http://coccinella.im/development to learn how you can help." $prefs(appName) $prefs(appName)]
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

    set wpage $wbox.f
    ttk::frame $wpage -padding [option get . notebookPagePadding {}]
    pack $wpage -side right -fill x -anchor [option get . dialogAnchor {}]
    set wtext $wpage.t
    set wysc  $wpage.s
    ttk::scrollbar $wysc -orient vertical -command [list $wtext yview]
    text $wpage.t -width 52 -height 12 -wrap word \
	-yscrollcommand [list ::UI::ScrollSet $wysc [list pack $wysc -side right -fill y]]
    pack $wpage.t -side left -fill both -expand 1
    pack $wysc -side right -fill y
    
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

