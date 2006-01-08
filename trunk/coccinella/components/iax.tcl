# iaxClient.tcl --
# 
#       iaxClient phone UI
#       
# $Id: iax.tcl,v 1.3 2006-01-08 09:24:16 matben Exp $

namespace eval ::iaxClient:: { }

proc ::iaxClient::Init { } {
    global  this    
    variable wtab -
    variable w -

    variable phonenumber ""
    variable phoneNumberInput ""
    variable state -
    variable prefsPhone   
 
    if {[catch {package require iaxclient}]} {
	return
    }
    component::register iaxClient  \
      "Provides iaxClient for Asterisk PBX"

    ::hooks::register loginHook             ::iaxClient::LoginHook
    ::hooks::register logoutHook            ::iaxClient::LogoutHook
    ::hooks::register launchFinalHook       ::iaxClient::LoginHook

    ::hooks::register prefsInitHook                  ::iaxClient::InitPrefsHook
    ::hooks::register prefsBuildHook                 ::iaxClient::BuildPrefsHook
    ::hooks::register prefsSaveHook                  ::iaxClient::SavePrefsHook
    ::hooks::register prefsCancelHook                ::iaxClient::CancelPrefsHook
    ::hooks::register prefsUserDefaultsHook          ::iaxClient::UserDefaultsHook
    ::hooks::register prefsDestroyHook               ::iaxClient::DestroyPrefsHook
}

proc ::iaxClient::LoadPrefs { } {
variable prefsPhone
variable statePhone

#Values for miv/spkVolume from 0 to 99
array set prefsPhone {
    user		10107
    password		10107
    host	        localhost 
    cidnum		10107
    cidname		Pepe
    codec		a	
    micVolume		30
    spkVolume		30
    inputDevices	-
    outputDevices	-
}

#Values for onhold -> no, hold, mute
#Values for status -> returned by ::iaxclient:: library
array set statePhone {
    registerid          -
    activeLine          0 
    onholdLine0         no
    onholdLine1         no
    onholdLine2         no
    statusLine0         free
    statusLine1         free
    statusLine2         free
    numberLine0         ""
    numberLine1         ""
    numberLine2         ""
}

    #Format (Codec), volume, callerid and Register to Asterisk server
    iaxclient::register $prefsPhone(user) $prefsPhone(password) $prefsPhone(host)

    iaxclient::callerid $prefsPhone(cidname) $prefsPhone(cidnum)
    
    set $prefsPhone(inputDevices) [iaxclient::devices "input"]
    set $prefsPhone(outputDevices) [iaxclient::devices "output"]

    set volume [expr double($prefsPhone(micVolume))/double(100)]
    iaxclient::level input $volume

    set volume [expr double($prefsPhone(spkVolume))/double(100)]
    iaxclient::level output $volume

    iaxclient::formats $prefsPhone(codec)

    #Setting up Callbacks functions
    iaxclient::notify "<State>" "[namespace current]::NotifyState"
    iaxclient::notify "<Registration>" "[namespace current]::NotifyRegister"
   iaxclient::notify "<Levels>" "[namespace current]::NotifyLevels"
   iaxclient::notify "<NetStats>" "[namespace current]::NotifyNetStats"
   iaxclient::notify "<Text>" "[namespace current]::NotifyText"
}

proc ::iaxClient::LogoutHook { } {
    variable statePhone

    iaxclient::unregister $statePhone(registerid)
}

proc ::iaxClient::LoginHook { } {
    variable prefsPhone
    variable w

    set w [NewPage]
    LoadPrefs
}
proc ::iaxClient::NotifyLevels { args } {
#    puts "Levels: $args"
}

proc ::iaxClient::NotifyNetStats { args } {
    puts "NetStats: $args"
}

proc ::iaxClient::NotifyText { args } {
    puts "Text: $args"
}

proc ::iaxClient::NotifyRegister { args } {
    variable statePhone

    set statePhone(registerid) [lindex $args 0]
}

proc ::iaxClient::NotifyState { args } {
    variable statePhone
    variable w
    variable phoneNumberInput

    #set array arrArgs $args

    puts "Callback State arguments $args" 

    set statusLine "statusLine[lindex $args 0]"
    set statePhone($statusLine) "[lindex $args 1]"


    #----------------------------------------------------------------------
    #------------ Setting Outgoing/Incoming Calls actions -----------------
    #----------------------------------------------------------------------
    #----- Receiving an Outgoing Call
    #First step trying to connect
    if { $statePhone($statusLine) eq "active outgoing ringing" } {
#        setStateDialButtonOn $w.box
#        $w.box.dial state {disabled}
    }

    #Connect right
    if { $statePhone($statusLine) eq "active outgoing complete" } {
#        setStateDialButtonOff $w.box
    }

    #----- Receiving an Incoming Call
    #Notify to user, answer into a free line (if there is one) and makes this new line active (the others become on Hold)
    if { $statePhone($statusLine) eq "active ringing" } {
         #Notify
        #eval {::hooks::run IAXPhoneEvent "RING" "[lindex $args 4] ([lindex $args 3])"}

        #Get Free Line
        set freeLine -1
        for {set i 0} {$i < 3} {incr i} {
            set checkLine "statusLine$i"
            if { $statePhone($checkLine) eq "free" } {
		set freeLine [expr $i-1]
                break
            }
        }

        if { $freeLine >= 0 } {
            #Set Active Line
            set statePhone(activeLine) $freeLine
            iaxclient::changeline $freeLine

            #Stuff for make on hold every line

            #Set buttons
            set phoneNumberInput "[lindex $args 3]"
#            $w.box.e state {disabled}
#            setStateDialButtonOff $w.box
  
            #Answer Call
            #Has to change buttons actions and label: Dial -> Accept and Hangup -> Reject
            iaxclient::answer $freeLine 
            puts "Answer Incoming $phoneNumberInput in Line $freeLine"
        } else {
            puts "There is no free lines"
        }
    }

    #Connection free (incoming & outgoing)
    if { $statePhone($statusLine) eq "free" } {
#        eval {::hooks::run IAXPhoneEvent "HANGUP" "[lindex $args 4] ([lindex $args 3])"}

        set phoneNumberInput ""
#        $w.box.e state {active}

#        setStateDialButtonOn $w.box
    } 
}

proc ::iaxClient::NewPage { } {
    variable wtab
    variable prefsPhone

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
    global  prefs this

    variable prefsPhone
    variable wphone
    variable wtree
    variable wwave
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jprefs jprefs
    variable phonenumber
    variable phoneNumberInput
    variable activeLine
    variable wbox

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

    ttk::radiobutton $wbox.line1 -text "[mc line] 1" -variable [namespace current]::statePhone(activeLine) -value 0 \
      -command [list [namespace current]::changeLine $wbox "0"]

    ttk::radiobutton $wbox.line2 -text "[mc line] 2" -variable [namespace current]::statePhone(activeLine) -value 1 \
      -command [list [namespace current]::changeLine $wbox "1"]

    ttk::radiobutton $wbox.line3 -text "[mc line] 3" -variable [namespace current]::statePhone(activeLine) -value 2 \
      -command [list [namespace current]::changeLine $wbox "2"]

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

    ttk::button $wbox.transfer -text "Transfer"  \
      -command [list [namespace current]::transfer $wbox]

    ttk::button $wbox.hangup -text "Hangup"  \
      -command [list [namespace current]::hangup $wbox]

    ttk::button $wbox.hold -text "Hold"  \
      -command [list [namespace current]::hold $wbox]

    ttk::button $wbox.mute -text "Mute"  \
      -command [list [namespace current]::mute $wbox]

    set prefsPhone(micVolume) 99
    set prefsPhone(spkVolume) 99
#    ttk::scale $wbox.inputLevel -orient horizontal -from 0 -to 100 \
#       -variable [namespace current]::prefsPhone(micVolume) -value 99  \
#       -command [[namespace current]::setInputLevel]

#    ttk::scale $wbox.outputLevel -orient horizontal -length 100 -from 0 -to 100 \
#       -variable ::iaxClient::prefsPhone(spkVolume) -value 99 \
#       -command [[namespace current]::setOutputLevel]

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
    grid $wbox.hangup -row 6 -column 2 -sticky news
    grid $wbox.transfer -row 6 -column 3 -sticky news

    grid $wbox.hold -row 7 -column 1 -sticky news
    grid $wbox.mute -row 7 -column 3 -sticky news

#    grid $wbox.inputLevel -row 8 -column 1 -sticky news
#    grid $wbox.outputLevel -row 9 -column 1 -sticky news

    grid columnconfigure $wbox 0 -weight 1
    grid rowconfigure $wbox 0 -weight 1

    setStateDialButtonOn $wbox
    return $w
}

proc ::iaxClient::touch {w number} {
    variable phonenumber 
    variable phoneNumberInput
    variable statePhone

    set phonenumber $phonenumber$number
    set phoneNumberInput $phonenumber

    iaxclient::playtone $number 

    set line  $statePhone(activeLine)
    if { $statePhone(statusLine$line) ne "free" } {
        iaxclient::sendtone $number
    }

}

proc ::iaxClient::phonenumberchange { w } {
    variable phoneNumberInput
    variable phonenumber

    set phonenumber $phoneNumberInput
    return 1 
}

proc ::iaxClient::dial { w } {
    variable statePhone
    variable prefsPhone
    variable phonenumber


    puts "$prefsPhone(user):$prefsPhone(password)@$prefsPhone(host)/$phonenumber  ---> Dial using line  $statePhone(activeLine)"
    iaxclient::dial "$prefsPhone(user):$prefsPhone(password)@$prefsPhone(host)/$phonenumber" $statePhone(activeLine)

    set activeLine $statePhone(activeLine)
    set statePhone(numberLine$activeLine) $phonenumber
    set statePhone(onholdLine$activeLine) "no"
    set statePhone(statusLine$activeLine) "active outgoing"

    setStateDialButtonOff $w
}

proc ::iaxClient::hold { w } {
    variable statePhone

    set  onHoldLine "onholdLine$statePhone(activeLine)"

    puts "Holding Line $statePhone(activeLine) and being $statePhone($onHoldLine)"

    if {$statePhone($onHoldLine) eq "hold"} {
        puts "Pero esta entrando..."
        $w.mute state {!disabled}

        set statePhone($onHoldLine) "no"
        #iaxclient::unhold $statePhone(activeLine) 
    }


    if {$statePhone($onHoldLine) eq "no"} {
        $w.mute state {disabled}

        set statePhone($onHoldLine) "hold"
        #iaxclient::hold $statePhone(activeLine)
    }
}


proc ::iaxClient::mute { w } {
    variable statePhone

    set  onHoldLine "onholdLine$statePhone(activeLine)"

    if { $statePhone($onHoldLine) eq "mute"} {
        $w.hold state {!disabled}

        set statePhone($onHoldLine) "no"
        #iaxclient::unhold $statePhone(activeLine)
    } 

    if { $statePhone($onHoldLine) eq "no"} {
        $w.hold state {disabled}

        set statePhone($onHoldLine) "mute"
        #iaxclient::hold $statePhone(activeLine)
    }
}

proc ::iaxClient::hangup { w } {
variable statePhone

    puts "Hanging $statePhone(activeLine)"
	
    iaxclient::changeline $statePhone(activeLine)
    iaxclient::hangup
    setStateDialButtonOn $w
}

proc ::iaxClient::changeLine { w value} {
    variable statePhone
    variable phoneNumberInput
    variable phonenumber

    #internal logging
    set statePhone(activeLine) $value

    #changes line
    iaxclient::changeline $value

    #update UI
    set  phoneNumberInput $statePhone(numberLine$value)
    set  phonenumber $phoneNumberInput
puts "El estado es  $statePhone(statusLine$value)"
    if { $statePhone(statusLine$value) eq "free" || $statePhone(statusLine$value) eq "selected"} {
        setStateDialButtonOn $w
    } else {
        setStateDialButtonOff $w
    }
}

proc ::iaxClient::setInputLevel { } {
variable prefsPhone

    puts "Mirando input $prefsPhone(micVolume)"
#    iaxclient::level input [expr double($prefsPhone(micVolume))/double(100)]

}

proc ::iaxClient::setOutputLevel { } {

variable prefsPhone
puts "Mirando out $prefsPhone(ouputLevel)"
#    iaxclient::level input [expr double($prefsPhone(spkVolume))/double(100)]

}

proc ::iaxClient::setStateDialButtonOff { w } {
puts "That's  off $w"
    $w.dial state {disabled}
    $w.hangup state {!disabled}
    $w.transfer state {!disabled}
    $w.hold state {!disabled}
    $w.mute state {!disabled}
}

proc ::iaxClient::setStateDialButtonOn { w } {
puts "That's  on  $w"
    $w.dial state {!disabled}
    $w.hangup state {disabled}
    $w.transfer state {disabled}
    $w.hold state {disabled}
    $w.mute state {disabled}
}

################## Preferences Stuff ###################
proc ::iaxClient::InitPrefsHook { } {
    global  prefs

    set prefs(iaxPhone,user) ""
    set prefs(iaxPhone,password) 0
    set prefs(iaxPhone,host) 0
    set prefs(iaxPhone,cidnum) 0
    set prefs(iaxPhone,cidname) ""
    set prefs(iaxPhone,codec) ""
    set prefs(iaxPhone,inputDevices) ""
    set prefs(iaxPhone,outputDevices) ""

    ::PrefUtils::Add [list  \
      [list prefs(iaxPhone,user) prefs_iaxPhone_user $prefs(iaxPhone,user)] \
      [list prefs(iaxPhone,password) prefs_iaxPhone_password $prefs(iaxPhone,password)] \
      [list prefs(iaxPhone,host) prefs_iaxPhone_host $prefs(iaxPhone,host)] \
      [list prefs(iaxPhone,cidnum) prefs_iaxPhone_cidnum $prefs(iaxPhone,cidnum)] \
      [list prefs(iaxPhone,cidname) prefs_iaxPhone_cidname $prefs(iaxPhone,cidname)] \
      [list prefs(iaxPhone,codec) prefs_iaxPhone_codec $prefs(iaxPhone,codec)] \
      [list prefs(iaxPhone,inputDevices) prefs_iaxPhone_inputDevices $prefs(iaxPhone,inputDevices)] \
      [list prefs(iaxPhone,outputDevices))     prefs_iaxPhone_outputDevices     $prefs(iaxPhone,outputDevices)]]
}

proc ::iaxClient::BuildPrefsHook {wtree nbframe} {
    global  prefs
    variable tmpPrefs

    if {![::Preferences::HaveTableItem iaxPhone]} {
        ::Preferences::NewTableItem {iaxPhone} [mc iaxPhone]
    }
    set wpage [$nbframe page {iaxPhone}]
   
    set wc $wpage.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]

    set lfr $wc.fr
    ttk::labelframe $lfr -text [mc {iaxPhone}] \
      -padding [option get . groupSmallPadding {}]
    pack $lfr -side top -anchor w

    set tmpPrefs(iaxPhone,user) prefs(iaxPhone,user) 
    set tmpPrefs(iaxPhone,password)  prefs(iaxPhone,password)
    set tmpPrefs(iaxPhone,host) prefs(iaxPhone,host)
    set tmpPrefs(iaxPhone,cidnum) prefs(iaxPhone,cidnum)
    set tmpPrefs(iaxPhone,cidname) prefs(iaxPhone,cidname) 
    set tmpPrefs(iaxPhone,codec) prefs(iaxPhone,codec) 
    set tmpPrefs(iaxPhone,inputDevices) prefs(iaxPhone,inputDevices) 
    set tmpPrefs(iaxPhone,outputDevices) prefs(iaxPhone,outputDevices) 

    ttk::label $lfr.luser -text "[mc iaxPhoneUser]:"
    ttk::entry $lfr.user -textvariable [namespace current]::tmpPrefs(iaxPhone,user)

    ttk::label $lfr.lpassword -text "[mc iaxPhonePassword]:"
    ttk::entry $lfr.password -textvariable [namespace current]::tmpPrefs(iaxPhone,password)

    ttk::label $lfr.lhost -text "[mc iaxPhoneHost]:"
    ttk::entry $lfr.host -textvariable [namespace current]::tmpPrefs(iaxPhone,host)

    ttk::label $lfr.lcidnum -text "[mc iaxPhoneCidNum]:"
    ttk::entry $lfr.cidnum -textvariable [namespace current]::tmpPrefs(iaxPhone,cidnum)

    ttk::label $lfr.lcidname -text "[mc iaxPhoneCidName]:"
    ttk::entry $lfr.cidname -textvariable [namespace current]::tmpPrefs(iaxPhone,cidname)

    ttk::label $lfr.lcodec -text "[mc iaxPhoneCodec]:"
    ttk::entry $lfr.codec -textvariable [namespace current]::tmpPrefs(iaxPhone,codec)

    ttk::label $lfr.linputDev -text "[mc iaxPhoneInputDev]:"
    ttk::entry $lfr.input_dev -textvariable [namespace current]::tmpPrefs(iaxPhone,inpugDevices)

    ttk::label $lfr.loutputDev -text "[mc iaxPhoneOutputDev]:"
    ttk::entry $lfr.output_dev -textvariable [namespace current]::tmpPrefs(iaxPhone,outputDevices)

    grid  $lfr.luser $lfr.user    -sticky w
    grid  $lfr.lpassword  $lfr.password -sticky w
    grid  $lfr.lhost  $lfr.host    -sticky w
    grid  $lfr.lcidnum $lfr.cidnum    -sticky w
    grid  $lfr.lcidname $lfr.cidname  -sticky w
    grid  $lfr.lcodec $lfr.codec    -sticky w
    grid  $lfr.linputDev $lfr.input_dev   -sticky w
    grid  $lfr.loutputDev $lfr.output_dev    -sticky w
}

proc ::iaxClient::SavePrefsHook { } {
    global  prefs
    variable tmpPrefs

    set prefs(iaxPhone,user) $tmpPrefs(iaxPhone,user)
    set prefs(iaxPhone,password)  $tmpPrefs(iaxPhone,password)
    set prefs(iaxPhone,host) $tmpPprefs(iaxPhone,host)
    set prefs(iaxPhone,cidnum) $tmpPprefs(iaxPhone,cidnum)
    set prefs(iaxPhone,cidname) $tmpPprefs(iaxPhone,cidname)
    set prefs(iaxPhone,codec) $tmpPprefs(iaxPhone,codec)
    set prefs(iaxPhone,inputDevices) $tmpPprefs(iaxPhone,inputDevices)
    set prefs(iaxPhone,outputDevices) $tmpPprefs(iaxPhone,outputDevices)

}

proc ::iaxClient::CancelPrefsHook { } {
    global  prefs
    variable tmpPrefs

    set key iaxPhone,user
    if {![string equal $prefs($key) $tmpPrefs($key)]} {
        ::Preferences::HasChanged
    }


}

proc ::iaxClient::UserDefaultsHook { } {
    global  prefs
    variable tmpPrefs

    set tmpPrefs(iaxPhone,user) $prefs(iaxPhone,user)
    set tmpPrefs(iaxPhone,password)  $prefs(iaxPhone,password)
    set tmpPrefs(iaxPhone,host) $prefs(iaxPhone,host)
    set tmpPrefs(iaxPhone,cidnum) $prefs(iaxPhone,cidnum)
    set tmpPrefs(iaxPhone,cidname) $prefs(iaxPhone,cidname)
    set tmpPrefs(iaxPhone,codec) $prefs(iaxPhone,codec)
    set tmpPrefs(iaxPhone,inputDevices) $prefs(iaxPhone,inputDevices)
    set tmpPrefs(iaxPhone,outputDevices) $prefs(iaxPhone,outputDevices)
}

proc ::iaxClient::DestroyPrefsHook { } {
    variable tmpPrefs

    unset -nocomplain tmpPrefs
}


############## TO-DO ##################
# Basic features:
# 1. Disable PhoneNumber Input widget, and catch all key pressed like a shortcut of the number buttons.
# 2. Separate AddressBook from JivePhone and add last dialed numbers into the AddressBook
# 3. Show missed calls into a Chat Window
# 4. On incoming calls change the buttons Dial to Accept and Hangup to Reject
# 5. Complete Preferences code (loadPrefs, Devices combo, initial values)
#
# Advanced features:
# 6. Makes UI nicer, using custom widgets.
# 7. Use the Netstats callback for adjusting options
#
# Known bugs and errors:
# 1. From Callback functions there are problems setting state of widgets.
# 2. Hold/Unhold and Mute/Unmute, doesn't set the state of widgets and need tests of iaxclient::hold
# 3. Volume scale widget doesn't goes fine with -command option (more tests)
#
# ..... A lot of Debug work
