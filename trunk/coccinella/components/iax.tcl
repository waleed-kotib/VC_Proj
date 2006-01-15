# iaxClient.tcl --
# 
#       iaxClient phone UI
#       
# $Id: iax.tcl,v 1.5 2006-01-15 07:55:02 matben Exp $

namespace eval ::iaxClient:: { }

proc ::iaxClient::Init { } {
    global  this    
    variable b

    return
    
    if {[catch {package require iaxclient}]} {
	return
    }
    component::register iaxClient  \
      "Provides iaxClient for Asterisk PBX"

    ::hooks::register launchFinalHook       ::iaxClient::LaunchHook
    ::hooks::register loginHook			::iaxClient::LoginHook 

    ::hooks::register iaxClientRinging      ::iaxClient::DialPadRinging
    ::hooks::register iaxClientHangup       ::iaxClient::DialPadHangup

    iaxclient::register "10107"  "10107"  "localhost" 

    #Setting up Callbacks functions
    iaxclient::notify "<State>" "[namespace current]::NotifyState"
}

proc ::iaxClient::LoginHook { } {
variable b
    puts "Login $b -State [$b cget -state] -Text [$b cget -text]"

#    $b configure -state normal
    $b configure -text "login"
    
    puts "After Login $b -State [$b cget -state] -Text [$b cget -text]"

}

proc ::iaxClient::DialPadRinging { } {
    variable b

    puts "Incoming Call $b -State [$b cget -state] -Text [$b cget -text]"

#    $b configure -state normal
    $b configure -text "incoming"

    puts "After Incoming Call $b -State [$b cget -state] -Text [$b cget -text]"

}

proc ::iaxClient::DialPadHangup { } {
    variable b

    puts "Hangup Call $b -State [$b cget -state] -Text [$b cget -text]"

#    $b configure -state normal     
    $b configure -text "free"

    puts "After Hangup Call $b -State [$b cget -state] -Text [$b cget -text]"
}

proc ::iaxClient::LaunchHook { } {
    variable w

    set w [NewPage]
}

proc ::iaxClient::NotifyState { args } {
    set statusLine "[lindex $args 1]"

    if { $statusLine eq "active ringing" } {
        eval {::hooks::run iaxClientRinging}
    }

    #Connection free (incoming & outgoing)
    if { [lsearch $statusLine "free"] >= 0 } {
        eval {::hooks::run iaxClientHangup}
    } 
}

proc ::iaxClient::NewPage { } {
    variable wtab

    set wnb [::Jabber::UI::GetNotebook]
    set wtab $wnb.iax
    if {![winfo exists $wtab]} {
        set im [::Theme::GetImage \
          [option get [winfo toplevel $wnb] browser16Image {}]]
        set imd [::Theme::GetImage \
          [option get [winfo toplevel $wnb] browser16DisImage {}]]
        set imSpec [list $im disabled $imd background $imd]
        set w [Build $wtab]
        $wnb add $wtab -text [mc Phone] -image $imSpec -compound left
        return $w
    }
}

proc ::iaxClient::Build {w args} {
    variable wphone
    variable wtree
    variable wwave
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jprefs jprefs
    variable wbox

    variable b

    set jstate(wpopup,phone)    .jpopupph
    set wphone $w
    set wwave   $w.fs
    set wbox    $w.box

    # The frame.
    ttk::frame $w -class Phone 

    frame $wbox
    pack $wbox -side top

    set bgimage [::Theme::GetImage [option get $w backgroundImage {}]]

    set b [ttk::button $wbox.b1 -text "1"  -state normal \
      -command [list [namespace current]::touch $wbox]]

    grid $wbox.b1 -row 2 -column 1 -sticky news
    grid columnconfigure $wbox 0 -weight 1
    grid rowconfigure $wbox 0 -weight 1

    return $w
}

proc ::iaxClient::touch {w} {
variable b

    set estado [$b cget -state]
    puts "$w ($b - $estado)"
#    $b configure -state disabled 
    $b configure -text "touch"
}

