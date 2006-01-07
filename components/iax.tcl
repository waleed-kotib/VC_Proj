# iax.tcl --
# 
# Copyright (c) 2006 Antonio Cano damas     
#  
# $Id: iax.tcl,v 1.2 2006-01-07 14:54:37 matben Exp $

namespace eval ::iaxClient:: { }

proc ::iaxClient::Init { } {
    global  this    
    variable wtab -

    variable phonenumber ""
    variable state -
    variable prefsPhone   
 
    if {[catch {package require iaxclient}]} {
	return
    }
    component::register iaxClient  \
      "Provides iaxClient for Asterisk PBX"

    ::hooks::register loginHook             ::iaxClient::LoginHook
    ::hooks::register logoutHook            ::iaxClient::LogoutHook
}

proc ::iaxClient::LoadPrefs { } {
    variable prefsPhone
    
    array set prefsPhone {
	user		10107
	password	10107
	host		192.168.1.70
	cidnum		10107
	cidname		Pepe
	codec		a	
	inputLevel	0.2
	outputLevel	0.2
	inputDevices	-
	outputDevices	-
	registerid	-
	activeLine      1
	statusLine1     free 
	statusLine2     free
        statusLine3     free
    }
    
    set prefsPhone(registerid) [iaxclient::register $prefsPhone(user) $prefsPhone(password) $prefsPhone(host)]
    puts "Registrado como $prefsPhone(registerid)"
    
    iaxclient::callerid $prefsPhone(cidname) $prefsPhone(cidnum)
    
    set $prefsPhone(inputDevices) [iaxclient::devices "input"]
    set $prefsPhone(outputDevices) [iaxclient::devices "output"]
    
    iaxclient::level input $prefsPhone(inputLevel)
    iaxclient::level output $prefsPhone(outputLevel)
    
    iaxclient::formats $prefsPhone(codec)
    
}

proc ::iaxClient::LogoutHook { } {
    variable prefsPhone
    variable wtab
    
    iaxclient::unregister $prefsPhone(registerid)
    if {[winfo exists $wtab]} {
	set wnb [::Jabber::UI::GetNotebook]
	$wnb forget $wtab
	destroy $wtab
    }
}

proc ::iaxClient::LoginHook { } {
    # puts "Colgar la llamada"
    # iaxclient::hangup
    NewPage
    LoadPrefs
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
        Build $wtab
        $wnb add $wtab -text [mc Phone] -image $imSpec -compound left
    }
}

proc ::iaxClient::Build {w args} {
    global  prefs this

    variable wphone
    variable wtree
    variable wwave
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jprefs jprefs
    variable phonenumber
    variable phoneNumberInput
    variable prefsPhone
    variable activeLine

    ::Debug 2 "::iaxClient::Build w=$w"
    set jstate(wpopup,phone)    .jpopupph
    set wphone $w
    set wwave   $w.fs
    set wbox    $w.box

    # The frame.
    ttk::frame $w -class Phone 

    frame $wbox
    pack $wbox -side top
    set bgimage [::Theme::GetImage [option get $w backgroundImage {}]]

    ttk::entry $wbox.e -textvariable [namespace current]::phoneNumberInput  \
      -width 10 -validate all -validatecommand [list [namespace current]::phonenumberchange $wbox]
    set phoneNumberInput ""

    ttk::radiobutton $wbox.line1 -text "[mc line] 1" -variable [namespace current]::prefsPhone(activeLine) -value 1
    ttk::radiobutton $wbox.line2 -text "[mc line] 2" -variable [namespace current]::prefsPhone(activeLine) -value 2
    ttk::radiobutton $wbox.line3 -text "[mc line] 3" -variable [namespace current]::prefsPhone(activeLine) -value 3 

    ttk::button $wbox.b1 -text "1"  \
      -command [list [namespace current]::touch $wbox "1"]

    ttk::button $wbox.b2 -text "2"  \
      -command [list [namespace current]::touch $wbox "2"]

    ttk::button $wbox.b3 -text "3"  \
      -command [list [namespace current]::touch $wbox "3"]

    ttk::button $wbox.b4 -text "4"  \
      -command [list [namespace current]::touch $wbox "4"]

    ttk::button $wbox.b5 -text "5"  \
      -command [list [namespace current]::touch $wbox "5"]

    ttk::button $wbox.b6 -text "6"  \
      -command [list [namespace current]::touch $wbox "6"]

    ttk::button $wbox.b7 -text "7"  \
      -command [list [namespace current]::touch $wbox "7"]

    ttk::button $wbox.b8 -text "8"  \
      -command [list [namespace current]::touch $wbox "8"]

    ttk::button $wbox.b9 -text "9"  \
      -command [list [namespace current]::touch $wbox "9"]

    ttk::button $wbox.basterisk -text "*"  \
      -command [list [namespace current]::touch $wbox "*"]

    ttk::button $wbox.b0 -text "0"  \
      -command [list [namespace current]::touch $wbox "0"]

    ttk::button $wbox.bcom -text "#"  \
      -command [list [namespace current]::touch $wbox "#"]

    ttk::button $wbox.dial -text "Dial"  \
      -command [list [namespace current]::dial $wbox]

    ttk::button $wbox.hold -text "Hold"  \
      -command [list [namespace current]::hold $wbox]

    ttk::button $wbox.hangup -text "Hangup"  \
      -command [list [namespace current]::hangup $wbox]

    ttk::scale $wbox.inputLevel -orient horizontal -length 100 -from 0 -to 100 \
      -command [list ::iaxClient::setInputLevel $wbox]

    ttk::scale $wbox.outputLevel -orient horizontal -length 100 -from 0 -to 100 \
      -command [list ::iaxClient::setOutputLevel $wbox]

    grid $wbox.e -row 0 -column 2 -sticky news
    grid $wbox.line1 -row 1 -column 1 -sticky news
    grid $wbox.line2 -row 1 -column 2 -sticky news
    grid $wbox.line3 -row 1 -column 3 -sticky news
 
    grid $wbox.b1 -row 2 -column 1 -sticky news
    grid $wbox.b2 -row 2 -column 2 -sticky news
    grid $wbox.b3 -row 2 -column 3 -sticky news
    grid $wbox.b4 -row 3 -column 1 -sticky news
    grid $wbox.b5 -row 3 -column 2 -sticky news
    grid $wbox.b6 -row 3 -column 3 -sticky news
    grid $wbox.b7 -row 4 -column 1 -sticky news
    grid $wbox.b8 -row 4 -column 2 -sticky news
    grid $wbox.b9 -row 4 -column 3 -sticky news
    grid $wbox.basterisk -row 5 -column 1 -sticky news
    grid $wbox.b0 -row 5 -column 2 -sticky news
    grid $wbox.bcom -row 5 -column 3 -sticky news

    grid $wbox.dial -row 6 -column 1 -sticky news
    grid $wbox.hold -row 6 -column 2 -sticky news
    grid $wbox.hangup -row 6 -column 3 -sticky news

    grid $wbox.inputLevel -row 7 -column 1 -sticky news
    grid $wbox.outputLevel -row 8 -column 1 -sticky news

    grid columnconfigure $wbox 0 -weight 1
    grid rowconfigure $wbox 0 -weight 1

    return $w
}

proc ::iaxClient::touch {w number} {
    variable phonenumber 
    variable phoneNumberInput

    set phonenumber $phonenumber$number
    set phoneNumberInput $phonenumber

    iaxclient::playtone $number 
}

proc ::iaxClient::phonenumberchange { w } {
    variable phoneNumberInput
    variable phonenumber
    
    set phonenumber $phoneNumberInput
    return 1 
}

proc ::iaxClient::dial { w } {
    variable prefsPhone
    variable phonenumber
    
    puts "$prefsPhone(user):$prefsPhone(password)@$prefsPhone(host)/$phonenumber  ---> Llamando por $prefsPhone(activeLine)"
    iaxclient::dial "$prefsPhone(user):$prefsPhone(password)@$prefsPhone(host)/$phonenumber" $prefsPhone(activeLine)

}

proc ::iaxClient::hold { w } {
    variable prefsPhone
    
    set state [iaxclient::state]
    puts "Estado es $state"
    
    #    if { $prefsPhone(onhold) eq "yes"} {
    #        iaxclient::unhold 0 
    #        set prefsPhone(onhold) "no"
    #    } else {
    #        iaxclient::hold 0
    #        set prefsPhone(onhold) "yes"
    #    }
}

proc ::iaxClient::hangup { w } {
    iaxclient::changeline 0
    iaxclient::hangup
}

proc ::iaxClient::changeLine { w value} {
    variable prefsPhone
    
    set prefsPhone(activeLine) $value
    puts "Hemos dicho $value"

}
proc ::iaxClient::setInputLevel { w } {

    #variable prefsPhone
    #set $prefsPhone(inputLevel) [expr $prefsPhone(inputLevel) + 1]
    #puts "Mirando input $prefsPhone(inputLevel)"

}

proc ::iaxClient::setOutputLevel { w } {

    #variable prefsPhone
    #puts "Mirando out $prefsPhone(ouputLevel)"

}
