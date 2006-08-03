# Mood.tcl --
# 
#       User Mood using PEP recommendations over PubSub library code.
#
#  Copyright (c) 2006 Mats Bengtsson
#  Copyright (c) 2006 Antonio Cano Damas

namespace eval ::Mood:: { }

proc ::Mood::Init { } {

    component::register Mood \
      "This is User Mood (JEP-0107)."

    ::Debug 2 "::Mood::Init"

    # Add event hooks.
    ::hooks::register newMessageHook        ::Mood::MessageHook
    ::hooks::register presenceHook          ::Mood::PresenceHook
    ::hooks::register loginHook             ::Mood::LoginHook
    ::hooks::register rosterBalloonhelp     ::Mood::BalloonHook

    variable server
    variable myjid
    variable moodjlib

    variable node
    set node "http://jabber.org/protocol/mood"

    variable xmlnsMood
    set xmlnsMood "http://jabber.org/protocol/mood"

    variable state

    variable menuMood

    set menuMood [list cascade [mc mMood] {} normal {} {} {}]
    set subEntries {}
        lappend subEntries [list radio [mc mAngry] {::Mood::Cmd "angry"}  normal {} {}]
        lappend subEntries [list radio [mc mAnxious] {::Mood::Cmd "anxious"}  normal {} {}]
        lappend subEntries [list radio [mc mAshamed] {::Mood::Cmd "ashamed"} normal {} {}]
        lappend subEntries [list radio [mc mBored] {::Mood::Cmd "bored"} normal {} {}]
        lappend subEntries [list radio [mc mCurious] {::Mood::Cmd "curious"}  normal {} {}]
        lappend subEntries [list radio [mc mDepressed] {::Mood::Cmd "depressed"} normal {} {}]
        lappend subEntries [list radio [mc mExcited] {::Mood::Cmd "excited"} normal {} {}]
        lappend subEntries [list radio [mc mHappy] {::Mood::Cmd "happy"}  normal {} {}]
        lappend subEntries [list radio [mc mInLove] {::Mood::Cmd "in_love"} normal {} {}]
        lappend subEntries [list radio [mc mInvincible] {::Mood::Cmd "invincible"}  normal {} {}]
        lappend subEntries [list radio [mc mJealous] {::Mood::Cmd "jealous"} normal {} {}]
        lappend subEntries [list radio [mc mNervous] {::Mood::Cmd "nervous"}  normal {} {}]
        lappend subEntries [list radio [mc mSad] {::Mood::Cmd "sad"} normal {} {}]
        lappend subEntries [list radio [mc mSleepy] {::Mood::Cmd "sleepy"} normal {} {}]
        lappend subEntries [list radio [mc mStressed] {::Mood::Cmd "stressed"}  normal {} {}]
        lappend subEntries [list radio [mc mWorried] {::Mood::Cmd "worried"} normal {} {}]
        lappend subEntries [list radio [mc mCustom] {::Mood::CustomMoodWindow} normal {} {}]
        lset menuMood 6 $subEntries

    variable mapMoodTextToElem
    array set mapMoodTextToElem [list \
      [mc mAngry]       angry      \
      [mc mAnxious]     anxious    \
      [mc mAshamed]     ashamed    \
      [mc mBored]       bored      \
      [mc mCurious]     curious    \
      [mc mDepressed]   depressed  \
      [mc mExcited]     excited    \
      [mc mHappy]       happy      \
      [mc mInLove]      in_love    \
      [mc mInvincible]  invincible \
      [mc mJealous]     jealous    \
      [mc mNervous]     nervous    \
      [mc mSad]         sad        \
      [mc mSleepy]      sleepy     \
      [mc mStressed]    stressed   \
      [mc mWorried]     worried]

    variable moodStateDlg
    variable moodMessageDlg
}

proc ::Mood::LoginHook { } {
    variable server
    variable myjid
    variable moodjlib

    #----- Initialize variables ------
    set moodjlib jlib::jlib1
    set myjid [$moodjlib myjid2]
    set server [$moodjlib getserver]

    #----- Disco server for pubsub support -----
    ::Jabber::JlibCmd disco get_async info $server ::Mood::OnDiscoServer
}

proc ::Mood::OnDiscoServer {jlibname type from subiq args} {
    variable myjid
    variable moodjlib
    variable node
    variable xmlnsMood
    variable menuMood
 
    ::Debug 2 "::Mood::OnDiscoServer"

    if {$type eq "result"} {
        set node [wrapper::getattribute $subiq node]
        #---- Check if disco returns <indetity category=pubsub type=pep>
        if {[::Jabber::JlibCmd disco iscategorytype pubsub/pep $from $node]} {
                ::Jabber::UI::RegisterMenuEntry jabber $menuMood
                #----- Create Node for Mood -------------
                ::Jabber::JlibCmd disco get_async items $myjid [list ::Mood::CreateNode]
        }
    }
}
proc ::Mood::Cmd {{moodState ""} {text ""}} {    
    variable server
    variable myjid
    variable moodjlib
    variable node
    variable xmlnsMood

    set moodValues [list afraid amazed angry annoyed anxious aroused ashamed bored brave calm cold confused contented cranky \
                         curious depressed disappointed disgusted distracted embarrassed excited flirtatious frustated grumpy \
                         guilty happy hot humbled humiliated hungry hurt impressed in_awe in_love indignant interested intoxicated \
                         invincible jealous lonely mean moody nervous neutral offended playful proud relieved remorseful restless \
                         sad sarcastic serious shocked shy sick sleepy stressed surprised thirsty worried]

    if {[lsearch $moodValues $moodState] >= 0} {
	set moodTextTag [wrapper::createtag text -chdata $text] 

        set moodStateTag [wrapper::createtag $moodState]
        set moodTag [wrapper::createtag mood -attrlist [list xmlns $xmlnsMood] -subtags [list  $moodStateTag $moodTextTag] ]

        set itemElem [wrapper::createtag item -subtags [list $moodTag]]

        $moodjlib pubsub publish $node  -items [list $itemElem] -command ::Mood::PubSubPublishCB
    }
}

proc ::Mood::PubSubPublishCB {args} {
     puts "(Publish Results)----> $args"
}

#--------------------------------------------------------------------
#-------             Checks and create if node exists ---------------
#-----------            before the publish tasks     ----------------
#--------------------------------------------------------------------
proc ::Mood::CreateNode {jlibname type from subiq args} {
variable server
variable myjid
variable moodjlib
variable node

    #------- Before create a node checks if it is created ---------
    set findMood false
    if {$type eq "result"} {
        set nodes [::Jabber::JlibCmd disco nodes $from]
        foreach nodeItem $nodes {
            if { [string first "moodee" $nodeItem] != -1 } {
                set findMood true
                break
            }
        }
    }

    #---------- Create the node for mood information -------------
    if { !$findMood } {
        #Configure setup for PEP node
        set valueFormElem  [wrapper::createtag value -chdata "http://jabber.org/protocol/pubsub#node_config"]
        set fieldFormElem [wrapper::createtag field -attrlist [list var "FORM_TYPE" type hidden] -subtags [list $valueFormElem]]

        #PEP Values for access_model: roster / presence / open or authorize / whitelist
        set valueAccessModel [wrapper::createtag value -chdata roster]
        set fieldAccessModelElem [wrapper::createtag field -attrlist [list var "pubsub#access_model"] -subtags [list $valueAccessModel]]

        set xElem [wrapper::createtag x -attrlist [list xmlns "jabber:x:data" type submit] -subtags [list $fieldFormElem $fieldAccessModelElem]]

        $moodjlib pubsub create -node $node -command ::Mood::PubSubCreateCB -configure $xElem
    }
}

proc ::Mood::PubSubCreateCB {type args} {

    if { $type ne "result" } {
        puts "(CreateNode error)----> $args"
    }
}

#-------------------------------------------------------------------------
#---------------------- (Extended Presence) ------------------------------
#-------------------------------------------------------------------------

proc ::Mood::PresenceHook {jid type args} {
    variable state
    variable moodjlib

    # Beware! jid without resource!
    ::Debug 2 "::Mood::PresenceHook jid=$jid, type=$type"

    if {$type ne "available"} {
        return
    }

    if {![::Jabber::RosterCmd isitem $jid]} {
        return
    }

    # Some transports propagate the complete prsence stanza.
    if {[::Roster::IsTransportHeuristics $jid]} {
        return
    }

    array set aargs $args
    set from $aargs(-from)
    jlib::splitjidex $from node jidserver res
    set jid2 $node@$jidserver

    if { ![info exists state($jid2,pubsubsupport)] } {
        #------------- Check(disco#items) If the User supports PEP before subscribe
        ::Jabber::JlibCmd disco get_async items $jid2 [list ::Mood::OnDiscoContact]
    } 
}

proc ::Mood::OnDiscoContact {jlibname type from subiq args} {
    variable state
    variable moodjlib
    variable myjid
    variable node

    ::Debug 2 "::Mood::OnDiscoContactServer"

    # --- Check if contact supports Mood node ----
    if {$type eq "result"} {
        set nodes [::Jabber::JlibCmd disco nodes $from]
        foreach nodeItem $nodes {
            if { [string first "mood" $nodeItem] != -1 } {

puts "Parece que si que $from soporta mood"

                set state($from,pubsubsupport) true
           
                $moodjlib pubsub subscribe $from $myjid -node $node -command ::Mood::PubSubscribeCB
                break
            }
        }
    }
}

proc ::Mood::PubSubscribeCB {args} {
        puts "(Subscribe CB) ---> $args"
}

#-------------------------------------------------------------------------
#---------------------- (Incoming Mood Handling) -------------------------
#-------------------------------------------------------------------------
proc ::Mood::MessageHook {body args} {
    array set aargs $args
    variable state

    set event $aargs(-xmldata)

    set from [wrapper::getattribute $event from]

    set eventElem [wrapper::getfirstchildwithtag $event event]

    set itemsElem [wrapper::getfirstchildwithtag $eventElem items]
    set node [wrapper::getattribute $itemsElem node]

    set itemElem [wrapper::getfirstchildwithtag $itemsElem item]
    set moodElem [wrapper::getfirstchildwithtag $itemElem mood]

    set moodElemTemp [wrapper::getchildren $moodElem] 
    set elem1 [lindex $moodElemTemp 0]
    set elem2 [lindex $moodElemTemp 1]

    if { [wrapper::gettag $elem1] eq "text" } {
        set textElem $elem1
        set mood [wrapper::gettag $elem2]
    } else {
        set textElem $elem2
        set mood [wrapper::gettag $elem1]
    }
 
    set text ""
    if {$textElem ne {}} {
        set text [wrapper::getcdata $textElem]
    }

    #Cache Mood info for BallonHook
    set state($from,text) $text
    set state($from,mood) $mood
    
    #@@@ Refresh Roster, the BalloonHook is called only when a Presence is coming and a Refresh of the roster
    ::Roster::Refresh

    eval {::hooks::run moodEvent $from $mood $text} $args

}

proc ::Mood::BalloonHook {T item jid} {
   variable state

    jlib::splitjidex $jid node jidserver res
    set jid2 $node@$jidserver

    set text ""
    if { [info exists state($jid2,text)] } {
        if {$state($jid2,text) ne ""} {
            set text ($state($jid2,text))
        }
    }

    if { [info exists state($jid2,mood)] } {
        ::balloonhelp::treectrl_set $T $item mood "\n[mc mMood]: [mc $state($jid2,mood)] $text"
    }
}

#--------------------------------------------------------------
#----------------- UI for Custom Mood Dialog ------------------
#--------------------------------------------------------------
proc ::Mood::CustomMoodWindow {} {
    global  this wDlgs
    variable moodMessage
    variable moodState

    set w ".mumdlg"
    ::UI::Toplevel $w \
      -macstyle documentProc -macclass {document closeBox} -usemacmainmenu 1 \
      -closecommand [namespace current]::CloseCmd
    wm title $w [mc {moodDlg}]

    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jmucenter)]]
    if {$nwin == 1} {
        ::UI::SetWindowPosition $w ".mumdlg"
    }

    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 260 -justify left -text [mc selectCustomMood]
    pack $wbox.msg -side top -anchor w

    set frmid $wbox.frmid
    ttk::frame $frmid
    pack $frmid -side top -fill both -expand 1

    set moodList [list [mc mAngry] [mc mAnxious] [mc mAshamed] [mc mBored] [mc mCurious] [mc mDepressed] [mc mExcited] [mc mHappy] [mc mInLove] [mc mInvincible] [mc mJealous] [mc mNervous] [mc mSad] [mc mSleepy] [mc mStressed] [mc mWorried]]

    ttk::label $frmid.lmood -text "[mc {mMood}]:" 
    ttk::combobox $frmid.cmood -state readonly -values $moodList -textvariable [namespace current]::moodStateDlg

    ttk::label $frmid.ltext -text "[mc {moodMessage}]:"
    ttk::entry $frmid.etext -textvariable [namespace current]::moodMessageDlg

    grid  $frmid.lmood    $frmid.cmood        -  -sticky e -pady 2
    grid  $frmid.ltext    $frmid.etext        -  -sticky e -pady 2
    grid columnconfigure $frmid 1 -weight 1

    # Button part.
    set frbot $wbox.b
    set wenter  $frbot.btok
    ttk::frame $frbot
    ttk::button $wenter -text [mc Enter] \
      -default active -command [list [namespace current]::sendMoodEnter $w]
    ttk::button $frbot.btcancel -text [mc Cancel]  \
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
        %s configure -wraplength [expr [winfo reqwidth %s] - 20]
    } $wbox.msg $w]
    after idle $script
}

proc ::Mood::sendMoodEnter {w} {
    variable moodStateDlg
    variable moodMessageDlg
    variable mapMoodTextToElem

    ::Mood::Cmd $mapMoodTextToElem($moodStateDlg) $moodMessageDlg

    ::UI::SaveWinGeom $w
    destroy $w
}

proc ::Mood::CancelEnter {w} {

    ::UI::SaveWinGeom $w
    destroy $w
}

proc ::Mood::CloseCmd {w} {
    ::UI::SaveWinGeom $w
}
