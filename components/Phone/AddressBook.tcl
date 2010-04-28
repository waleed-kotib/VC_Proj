# AddressBook.tcl -- 
# 
#       AddressBook for phone system (Jive and Soft-Phone) 
#       
#  Copyright (c) 2006 Mats Bengtsson
#  Copyright (c) 2006 Antonio Cano damas
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
# $Id: AddressBook.tcl,v 1.15 2008-06-09 09:50:59 matben Exp $

namespace eval ::AddressBook { 

    component::define AddressBook "Address book for softphones"
}

proc ::AddressBook::Init {} {
    
    component::register AddressBook
        
    # Add event hooks.
    
    ############################# Direct from Phone User Interface #############################
    ::hooks::register phoneInit                       ::AddressBook::NewPage
    
    #--------------- Variables Uses For SpeedDial Addressbook Tab ----------------
    variable wtab -
    variable abline
    variable popMenuDef

    # Standard widgets and standard options.
    option add *AddressBook.borderWidth           0               50
    option add *AddressBook.relief                flat            50
    option add *AddressBook*box.borderWidth       1               50
    option add *AddressBook*box.relief            sunken          50
    option add *AddressBook.padding               2               50

    option add *AddressBook.addressBook16Image      view-history       widgetDefault
    option add *AddressBook.addressBook16DisImage   view-history-Dis   widgetDefault
}


#---------------------------------------------------------------------------
#------------------- Addressbook SpeedDial Tab User Interface --------------
#---------------------------------------------------------------------------
proc ::AddressBook::CloseAddressBook {} {
    variable wtab 

    if {[winfo exists $wtab]} {
        set wnb [::JUI::GetNotebook]
        $wnb forget $wtab
        destroy $wtab
    }
} 

proc ::AddressBook::NewPage {} {
    variable wtab
    variable popMenuDef

    set popMenuDef(addressbook,def) {
	mCall     phone  {[mc "&Call"]...}               {::AddressBook::DialExtension $phone}
        separator {}     {}                              {}
        mNewAB    phone  {[mc "New"]}                    {::AddressBook::NewAddressbookDlg}
        mModifyAB phone  {[mc "Modify"]}                 {::AddressBook::ModifyAddressbookDlg $phone}
        mRemoveAB phone  {[mc "Remove"]}                 {::AddressBook::RemoveAddressbookDlg $phone}
    }

    set popMenuDef(log,def) {
	mRedial   phone   {[mc "&Call"]...}               {::AddressBook::DialExtension $phone}
        separator {}      {}                              {}
        mToAB     phone   {[mc "Add to Address Book"]...} {::AddressBook::NewAddressbookDlg $phone}
    }

    set popMenuDef(call) {
	mCall     phone   {[mc "&Call"]...}               {::AddressBook::DialExtension $phone}
    }
    
    set popMenuDef(redial) {
	mRedial   phone   {[mc "Redial"]}                 {::AddressBook::DialExtension $phone}
    }
    
    set popMenuDef(forward) {
	mForward  phone   {[mc "Forward Call"]}           {::AddressBook::TransferExtension $phone}
    }
    
    set wnb [::JUI::GetNotebook]
    set wtab $wnb.ab
    if {![winfo exists $wtab]} {
        Build $wtab
	set im  [::Theme::Find16Icon $wtab addressBook16Image]
	set imd [::Theme::Find16Icon $wtab addressBook16DisImage]
	set imSpec [list $im disabled $imd background $imd]
        $wnb add $wtab -text [mc "Address Book"] -image $imSpec -compound image
    }
}

# AddressBook::Build --
#
#       This is supposed to create a frame which is pretty object like,
#       and handles most stuff internally without intervention.
#
# Arguments:
#       w           frame for everything
#       args
#
# Results:
#       w

proc ::AddressBook::Build {w args} {
    global  prefs this jprefs

    variable waddressbook
    variable wtree
    variable wwave
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    variable abline

    ::Debug 2 "::AddressBook::Build w=$w"
    set jstate(wpopup,addressbook)    .jpopupab
    set waddressbook $w
    set wbox    $w.box
    set wtree   $wbox.tree
    set wxsc    $wbox.xsc
    set wysc    $wbox.ysc

    # The frame.
    ttk::frame $w -class AddressBook 

    # D = -border 1 -relief sunken
    frame $wbox
    pack  $wbox -side top -fill both -expand 1

    ttk::scrollbar $wxsc -orient horizontal -command [list $wtree xview]
    ttk::scrollbar $wysc -orient vertical -command [list $wtree yview]

    ::ITree::New $wtree $wxsc $wysc   \
      -buttonpress ::AddressBook::Popup         \
      -buttonpopup ::AddressBook::Popup

    grid  $wtree  -row 0 -column 0 -sticky news
    grid  $wysc   -row 0 -column 1 -sticky ns
    grid  $wxsc   -row 1 -column 0 -sticky ew
    grid columnconfigure $wbox 0 -weight 1
    grid rowconfigure $wbox 0 -weight 1

    # below two lines create exception when called, because of missing second parameter in first line
    #set iconImage  [::Theme::Find16Icon icons/16x16/view-history]
    #set opts {-text AddressBook -button 1 -image $iconImage -open 1}
    set opts {-text AddressBook -button 1 -open 1}
    eval {::ITree::Item $wtree "AddressBook"} $opts

    #--------- Load Entries of AddressBook into NewPage Tab --------
    LoadEntries
    if { $abline ne "" } {
        foreach {name phone} $abline {
            if {$name ne ""} {
                set opts {-text "$name $phone" -button 0 -open 0}
                set v [list "AddressBook" $phone]
                if { [::ITree::IsItem $wtree $v] == 0 } {
                    eval {::ITree::Item $wtree $v} $opts
                }
            }
        }
    }

    #--------- Include Logs Categories ---------
    set iconImage  [::Theme::FindIconSize 16 phone-received]
    set opts {-text Received -button 1 -image $iconImage -open 1}
    eval {::ITree::Item $wtree "Received"} $opts

    set iconImage  [::Theme::FindIconSize 16 phone-called]
    set opts {-text Called -button 1 -image $iconImage -open 1}
    eval {::ITree::Item $wtree "Called"} $opts

    set iconImage  [::Theme::FindIconSize 16 phone-missed]
    set opts {-text Missed -button 1 -image $iconImage -open 1}
    eval {::ITree::Item $wtree "Missed"} $opts
    
    return $w
}

# AddressBook::Popup --
#
#       Handle popup menus in AddressBook, typically from right-clicking.
#
# Arguments:
#       w           widget that issued the command: tree or text
#       v           for the tree widget it is the item path,
#                   for text the phonehash.
#
# Results:
#       popup menu displayed

proc ::AddressBook::Popup {w v x y} {
    global  wDlgs this
    variable popMenuDef

    upvar ::Jabber::jstate jstate

    ::Debug 2 "::AddressBook::Popup w=$w, v='$v', x=$x, y=$y"

    # The last element of $v is either a phone, (a namespace,)
    # a header in roster, a group, or an agents xml tag.
    # The variables name 'phone' is a misnomer.
    # Find also type of thing clicked, 'typeClicked'.

    set typeClicked ""

    set phoneEntry $v
    set phone [lindex $phoneEntry 1]
    set section [lindex $phoneEntry 0]
    
    if {$phone ne ""} {
        set typeClicked phone
    }

    if {[string length $phone] == 0} {
        set typeClicked ""     
    }
    set X [expr {[winfo rootx $w] + $x}]
    set Y [expr {[winfo rooty $w] + $y}]
    
    ::Debug 2 "\t phone=$phone, typeClicked=$typeClicked"

    # Mads Linden's workaround for menu post problem on mac:
    # all in menubutton commands i add "after 40 the_command"
    # this way i can never have to posting error.
    # it is important after the tk_popup f.ex to
    #
    # destroy .mb
    # update
    #
    # this way the .mb is destroyd before the next window comes up, thats how I
    # got around this.

    # Make the appropriate menu.
    set m $jstate(wpopup,addressbook)
    set i 0
    catch {destroy $m}
    menu $m -tearoff 0
    
    #------- Check Where the user make Popup and Select the right MenuDef -------
    if { $section eq "AddressBook" } {
        set popMenu $popMenuDef(addressbook,def)
    } else {
        set popMenu $popMenuDef(log,def)
    }

    foreach {item type locname cmd} $popMenu {
        if {[string index $cmd 0] == "@"} {
            set mt [menu ${m}.sub${i} -tearoff 0]
            set locname [eval concat $locname]
            $m add cascade -label $locname -menu $mt -state disabled
            eval [string range $cmd 1 end] $mt
            incr i
        } elseif {[string equal $item "separator"]} {
            $m add separator
            continue
        } else {
            # Substitute the phone arguments. Preserve list structure!
            set cmd [eval list $cmd]
            set locname [eval concat $locname]
            $m add command -label $locname -command [list after 40 $cmd]  \
              -state disabled
        }

        # If a menu should be enabled even if not connected do it here.
#        if {![::Jabber::IsConnected]} {
#            continue
#        }

        # State of menu entry. We use the 'type' and 'typeClicked' to sort
        # out which capabilities to offer for the clicked item.
        set state disabled

        if {[string equal $item "mNewAB"]} {
            set state normal
        }

        if {[string equal $type $typeClicked]} {
            set state normal
        }
        if {[string equal $state "normal"]} {
            $m entryconfigure $locname -state normal
        }   
    }

    # This one is needed on the mac so the menu is built before it is posted.
    update idletasks

    # Post popup menu.
    tk_popup $m [expr {int($X) - 10}] [expr {int($Y) - 10}]

    # Mac bug... (else can't post menu while already posted if toplevel...)
    if {[string equal "macintosh" $this(platform)]} {
        catch {destroy $m}
        update
    }
}

proc ::AddressBook::RemoveAddressbookDlg {phone} {
    variable abline
    variable wtree

    set removePhone [lindex [lindex $phone end] end]

    set index [lsearch -exact $abline $removePhone]

    set tmp [lreplace $abline [expr {$index-1}] $index]
    set abline $tmp
    
    set v [list "AddressBook" $phone]
    if { [::ITree::IsItem $wtree $v] >= 0 } {
            eval {::ITree::DeleteItem $wtree $v}
    }
        
    SaveEntries
}


proc ::AddressBook::NewAddressbookDlg {{phonenumber ""}} {
    global  this wDlgs

    variable abName
    variable abPhoneNumber

    set abName ""
    set abPhoneNumber $phonenumber

    set w ".nadbdlg" 
    ::UI::Toplevel $w \
      -macstyle documentProc -macclass {document closeBox} -usemacmainmenu 1 \
      -closecommand [namespace current]::CloseCmd
    wm title $w [mc "New address book"]

    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jmucenter)]]
    if {$nwin == 1} {
        ::UI::SetWindowPosition $w ".nadbdlg" 
    }

    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1
   
    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 260 -justify left -text [mc "New address book"]
    pack $wbox.msg -side top -anchor w

    set frmid $wbox.frmid
    ttk::frame $frmid
    pack $frmid -side top -fill both -expand 1

    ttk::label $frmid.lname -text [mc "Name"]:
    ttk::entry $frmid.ename -textvariable [namespace current]::abName

    ttk::label $frmid.lphone -text [mc "Phone number"]:
    ttk::entry $frmid.ephone -textvariable [namespace current]::abPhoneNumber

    grid  $frmid.lname    $frmid.ename        -  -sticky e -pady 2
    grid  $frmid.lphone    $frmid.ephone   -  -sticky e -pady 2
    grid  $frmid.ephone  $frmid.ename  -sticky ew
    grid columnconfigure $frmid 1 -weight 1

    # Button part.
    set frbot $wbox.b
    set wenter  $frbot.btok
    ttk::frame $frbot
    ttk::button $wenter -text [mc "Enter"] \
      -default active -command [list [namespace current]::addItemAddressBook $w]
    ttk::button $frbot.btcancel -text [mc "Cancel"]  \
      -command [list [namespace current]::CancelEnter $w]

    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
        pack $frbot.btok -side right
        pack $frbot.btcancel -side right -padx $padx
    } else {
        pack $frbot.btcancel -side right
        pack $frbot.btok -side right -padx $padx
    }
    pack $frbot -side bottom -fill x

    wm resizable $w 0 0

    bind $w <Return> [list $wenter invoke]

    # Trick to resize the labels wraplength.
    set script [format {
        update idletasks
        %s configure -wraplength [expr {[winfo reqwidth %s] - 20}]
    } $wbox.msg $w]   
    after idle $script
}

proc ::AddressBook::ModifyAddressbookDlg {phone} {
    global  this wDlgs
    variable abName
    variable abPhoneNumber
    variable abline

    #Get Entry data from abline list
    set modifyPhone $phone
    set index [lsearch -exact $abline $modifyPhone]
    set abName [lindex $abline [expr {$index-1}]]
    set abPhoneNumber [lindex $abline [expr {$index}]]
    set oldPhoneNumber $abPhoneNumber


    set w ".madbdlg"
    ::UI::Toplevel $w \
      -macstyle documentProc -macclass {document closeBox} -usemacmainmenu 1 \
      -closecommand [namespace current]::CloseCmd
    wm title $w [mc "Modify address book"]

    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jmucenter)]]
    if {$nwin == 1} {
        ::UI::SetWindowPosition $w ".madbdlg"
    }

    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 260 -justify left -text [mc "Modify address book"]
    pack $wbox.msg -side top -anchor w

    set frmid $wbox.frmid
    ttk::frame $frmid
    pack $frmid -side top -fill both -expand 1

    ttk::label $frmid.lname -text [mc "Name"]:
    ttk::entry $frmid.ename -textvariable [namespace current]::abName

    ttk::label $frmid.lphone -text [mc "Phone number"]:
    ttk::entry $frmid.ephone -textvariable [namespace current]::abPhoneNumber

    grid  $frmid.lname    $frmid.ename        -  -sticky e -pady 2
    grid  $frmid.lphone    $frmid.ephone   -  -sticky e -pady 2
    grid  $frmid.ephone  $frmid.ename  -sticky ew
    grid columnconfigure $frmid 1 -weight 1

    # Button part.
    set frbot $wbox.b
    set wenter  $frbot.btok
    ttk::frame $frbot
    ttk::button $wenter -text [mc "Enter"] \
      -default active -command [list [namespace current]::modifyItemAddressBook $w $phone]
    ttk::button $frbot.btcancel -text [mc "Cancel"]  \
      -command [list [namespace current]::CancelEnter $w]

    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
        pack $frbot.btok -side right
        pack $frbot.btcancel -side right -padx $padx
    } else {
        pack $frbot.btcancel -side right
        pack $frbot.btok -side right -padx $padx
    }
    pack $frbot -side bottom -fill x

    wm resizable $w 0 0

    bind $w <Return> [list $wenter invoke]

    # Trick to resize the labels wraplength.
    set script [format {
        update idletasks
        %s configure -wraplength [expr {[winfo reqwidth %s] - 20}]
    } $wbox.msg $w]
    after idle $script
}

##################################################
# AddressBook Actions:
#    - addItemAddressBook
#    - modifyItemAddressBook
#    - CancelEnter
#    - CloseCmd
#    - SaveEntries
#    - LoadEntries
#    - DialExtension
#    - TransferExtension
#
################################################
    
proc ::AddressBook::addItemAddressBook {w} {
    variable abName
    variable abPhoneNumber
    variable abline
    variable wtree

    if { $abName ne "" && $abPhoneNumber ne ""} {
        lappend abline $abName
        lappend abline $abPhoneNumber
               
        set text "$abPhoneNumber"
        set v [list "AddressBook" $text]
        set textUpdate "$abName $abPhoneNumber"
        set opts {-text $textUpdate}
        eval {::ITree::Item $wtree $v} $opts

        SaveEntries 
 
        ::UI::SaveWinGeom $w
        destroy $w    
    }
}

proc ::AddressBook::modifyItemAddressBook {w phone} {
    variable abName
    variable abPhoneNumber
    variable abline
    variable wtree

    #Get Entry data from abline list

    if { $abName ne "" && $abPhoneNumber ne "" } {
        #---------- Updates Memory Addressbook -----------------
        set index [lsearch -exact $abline $phone]

        set tmp [lreplace $abline [expr {$index-1}] $index $abName $abPhoneNumber]
        set abline $tmp

        #----- Updates GUI ---------
        set v [list "AddressBook" $phone]
        if { [::ITree::IsItem $wtree $v] > 0 } {
            eval {::ITree::DeleteItem $wtree $v}
        }
        
        set text "$abName $abPhoneNumber"
        set opts {-text $text -button 0 -open 0}
        set v [list "AddressBook" $abPhoneNumber]
        eval {::ITree::Item $wtree $v} $opts
        #----- Updates Database -------
        SaveEntries

        ::UI::SaveWinGeom $w
        destroy $w
    }
}

proc ::AddressBook::CancelEnter {w} {

    ::UI::SaveWinGeom $w
    destroy $w
}

proc ::AddressBook::CloseCmd {w} {

    ::UI::SaveWinGeom $w
}

proc ::AddressBook::SaveEntries {} {
    variable abline
    global  prefs this

    # @@@ Mats
    set hFile [open [file join $this(prefsPath) addressbook.csv] "w"]

    foreach {name phonenumber} $abline {
       if {$name ne ""} {
           puts $hFile "$name:$phonenumber"
       }
    }

    close $hFile
}

proc ::AddressBook::LoadEntries {} {
    variable abline
    global  prefs this
    
    set fileName [file join $this(prefsPath) addressbook.csv]
    set abline ""
    if { [ file exists $fileName ] } {
        set hFile [open $fileName "r"]
        while {[eof $hFile] <= 0} {
           gets $hFile line
           set temp [split $line ":"]
           foreach i $temp {
               lappend abline $i
           }
        }

        close $hFile
    } else {
        set abline ""
    }
}

proc ::AddressBook::DialExtension {phonenumber} {    
    ::Phone::Dial $phonenumber
}

proc ::AddressBook::TransferExtension {phonenumber} {
    ::Phone::TransferTo [lindex $phonenumber 1]
}

##################################################
# AddressBook Event Hooks:
#    - Called
#    - UpdateLogs
#    - ReceivedCall
#    - FreeState
#    - TalkingState
#
################################################

proc ::AddressBook::TalkingState {args} {
    variable wtab
    variable popMenuDef

    if {[winfo exists $wtab]} {
#    $wtab entryconfigure $popMenuDef(call)  \
#      -label [mc mForward] -command {::AddressBook::TransferExtension $phone}

#    $wtab entryconfigure $popMenuDef(redial)  \
#      -label [mc mForward] -command {::AddressBook::TransferExtension $phone}
    }
}

proc ::AddressBook::NormalState {args} {
    variable wtab
    variable popMenuDef

    if {[winfo exists $wtab]} {
#    $wtab entryconfigure $popMenuDef(addressbook,def)  \
#      -label [mc mCall] -command {::AddressBook::DialExtension $phone}

#    $wtab entryconfigure $popMenuDef(call)  \
#      -label [mc mCall] -command {::AddressBook::DialExtension $phone}

#    $wtab entryconfigure $popMenuDef(redial)  \
#      -label [mc mRedial] -command {::AddressBook::DialExtension $phone}
    }
}

proc ::AddressBook::ReceivedCall {callNo remote remote_name} {
    variable wtree
    variable wtab

    if {[winfo exists $wtab]} {    
        set opts {-text "$remote_name $remote" -button 0 -open 0}
        set v [list "Received" $remote]
    
        if { [::ITree::IsItem $wtree $v] == 0 } {
            eval {::ITree::Item $wtree $v} $opts
        }
    }
}

proc ::AddressBook::Called {phonenumber args} {
    variable wtree
    variable wtab

    if {[winfo exists $wtab]} {    
        set opts {-text $phonenumber -button 0 -open 0}
        set v [list "Called" $phonenumber]
    
        if { [::ITree::IsItem $wtree $v] == 0 } {
            eval {::ITree::Item $wtree $v} $opts
        }
    }
}

proc ::AddressBook::UpdateLogs {type remote remote_name initDate callLength} {
    variable wtree
    variable wtab

    if {[winfo exists $wtab]} {
        if { [clock format [clock seconds] -format %D] eq  [clock format $initDate -format "%D"]} {
            set textDate [mc "Today"]
            append textDate " [clock format $initDate -format "%X"]"
        } else {
            set textDate [clock format $initDate -format "%D %X"]
        }
        set v [list $type  $remote]    
        if { $type eq "Missed" } {
            set textUpdate "$textDate $remote_name $remote"
            set opts {-text $textUpdate -button 0 -open 0}
            if { [::ITree::IsItem $wtree $v] == 0 } {
                eval {::ITree::Item $wtree $v} $opts
            }
        
            #Remove Missed Call from Received.
            set v [list "Received" $remote]
            if { [::ITree::IsItem $wtree $v] > 0 } {
                eval {::ITree::DeleteItem $wtree $v}
            }
        } else {
            if { [::ITree::IsItem $wtree $v] > 0 } {
                set textUpdate "$textDate ([clock format [expr {$callLength - 3600}] -format %X]) $remote_name $remote"
                set opts {-text $textUpdate}
                eval {::ITree::ItemConfigure $wtree $v} $opts
            }
        }
    }
}

proc ::AddressBook::Search {phonenumber} {
    #For searching into vCard Disco Service, take a look into Search.tcl (DoSearch, ResultCallback) and JForms.tcl (ResultPlainList)
    variable abline
    set name ""

    if {[info exists abline]} {    
        set index [lsearch $abline $phonenumber]
        if { $index >= 0 } {
            set name [lindex $abline [expr {$index-1}]]
        }
    }
    return $name
}

proc ::AddressBook::Debug {msg} {
    if {0} {
	puts "-------- $msg"
    }
}

#-------------------------------------------------------------------------------
#---------------- TO-DO ---------------------------
# 2. Review Dial/Transfer Popup Options
