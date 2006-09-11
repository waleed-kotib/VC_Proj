# Mood.tcl --
# 
#       User Mood using PEP recommendations over PubSub library code.
#
#  Copyright (c) 2006 Mats Bengtsson
#  Copyright (c) 2006 Antonio Cano Damas
#  
#  $Id: Mood.tcl,v 1.10 2006-09-11 09:39:24 matben Exp $

package require ui::optionmenu

namespace eval ::Mood:: { }

proc ::Mood::Init { } {

    component::register Mood "This is User Mood (JEP-0107)."

    ::Debug 2 "::Mood::Init"

    # Add event hooks.
    ::hooks::register newMessageHook        ::Mood::MessageHook
    #::hooks::register presenceHook          ::Mood::PresenceHook
    ::hooks::register loginHook             ::Mood::LoginHook
    ::hooks::register logoutHook            ::Mood::LogoutHook
    ::hooks::register rosterBalloonhelp     ::Mood::BalloonHook

    variable moodNode
    set moodNode "http://jabber.org/protocol/mood"

    variable xmlns
    set xmlns(mood)        "http://jabber.org/protocol/mood"
    set xmlns(node_config) "http://jabber.org/protocol/pubsub#node_config"

    variable state

    variable myMoods
    set myMoods {
	angry       anxious     ashamed     bored
	curious     depressed   excited     happy
	in_love     invincible  jealous     nervous
	sad         sleepy      stressed    worried
    }
    
    variable allMoods
    set allMoods {
	afraid 	    amazed      angry       annoyed 
	anxious     aroused     ashamed     bored 
	brave       calm        cold        confused 
	contented   cranky      curious     depressed 
	disappointed disgusted  distracted  embarrassed 
	excited     flirtatious frustrated  grumpy 
	guilty      happy       hot         humbled 
	humiliated  hungry      hurt        impressed 
	in_awe      in_love     indignant   interested 
	intoxicated invincible  jealous     lonely 
	mean        moody       nervous     neutral 
	offended    playful     proud       relieved 
	remorseful  restless    sad         sarcastic 
	serious     shocked     shy         sick 
	sleepy      stressed    surprised   thirsty 
	worried 
    }
    
    variable mood2mLabel
    array set mood2mLabel {
	angry       mAngry
	anxious     mAnxious
	ashamed     mAshamed
	bored       mBored
	curious     mCurious
	depressed   mDepressed
	excited     mExcited
	happy       mHappy
	in_love     mInLove
	invincible  mInvincible
	jealous     mJealous
	nervous     mNervous
	sad         mSad
	sleepy      mSleepy
	stressed    mStressed
	worried     mWorried
    }
  
    variable menuDef
    set menuDef [list cascade mMood {} {} {} {}]
    set subMenu {}
    set opts [list -variable ::Mood::menuMoodVar -value "-"]
    lappend subMenu [list radio None ::Mood::MenuCmd {} $opts]
    foreach mood $myMoods {
	set opts [list -variable ::Mood::menuMoodVar -value $mood]
	lappend subMenu [list radio $mood2mLabel($mood) ::Mood::MenuCmd {} $opts]
    }
    lappend subMenu {separator}
    lappend subMenu [list command mCustomMood ::Mood::CustomMoodDlg {} {}]
    lset menuDef 5 $subMenu
    
    variable menuMoodVar
    set menuMoodVar "-"
    

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

}

proc ::Mood::LoginHook {} {
   
    #----- Disco server for pubsub support -----
    set server [::Jabber::JlibCmd getserver]
    ::Jabber::JlibCmd disco get_async info $server ::Mood::OnDiscoServer
}

proc ::Mood::OnDiscoServer {jlibname type from subiq args} {
    variable node
    variable xmlns
    variable menuDef
    variable menuMoodVar
    variable moodNode
 
    ::Debug 2 "::Mood::OnDiscoServer"

    if {$type eq "result"} {
        set node [wrapper::getattribute $subiq node]
        
	# Check if disco returns <identity category='pubsub' type='pep'/>
        if {[::Jabber::JlibCmd disco iscategorytype pubsub/pep $from $node]} {
	    ::JUI::RegisterMenuEntry jabber $menuDef
	    ::Jabber::JlibCmd pubsub register_event ::Mood::Event -node $moodNode
                
	    # Create Node for mood.
	    # This seems not necessary with latest PEP.
	    if {1} {
		set myjid2 [::Jabber::JlibCmd myjid2]
		::Jabber::JlibCmd disco get_async items $myjid2 ::Mood::OnDiscoUser
	    } else {
		
		# Publish node directly since PEP service automatically creates
		# a pubsub node with default configuration.
		if {$menuMoodVar ne "-"} {
		    Publish $menuMoodVar
		}
	    }
	}
    }
}

proc ::Mood::LogoutHook {} {
    
    ::JUI::DeRegisterMenuEntry jabber mMood
}

proc ::Mood::MenuCmd {} {
    variable menuMoodVar
    
    Publish $menuMoodVar
}

proc ::Mood::Publish {mood {text ""}} {
    variable moodNode
    variable xmlns
    
    set moodChildEs [list [wrapper::createtag $mood]]
    if {$text ne ""} {
	lappend moodChildEs [wrapper::createtag text -chdata $text] 
    }
    set moodE [wrapper::createtag mood  \
      -attrlist [list xmlns $xmlns(mood)] -subtags $moodChildEs]
    set itemE [wrapper::createtag item -subtags [list $moodE]]
    
    ::Jabber::JlibCmd pubsub publish $moodNode -items [list $itemE]  \
      -command ::Mood::PublishCB
}

proc ::Mood::PublishCB {args} {
    # empty
}

#--------------------------------------------------------------------
#-------             Checks and create if node exists ---------------
#-----------            before the publish tasks     ----------------
#--------------------------------------------------------------------
#
# Not used for PEP?
proc ::Mood::OnDiscoUser {jlibname type from subiq args} {
    
    puts "\t ::Mood::OnDiscoUser"
    
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
    puts "\t findMood=$findMood"
    
    #---------- Create the node for mood information -------------
    # This is not necessary if we not wants default configuration.
    if { !$findMood } {
	CreateNode
    }
}

proc ::Mood::CreateNode {} {
    variable moodNode
    variable xmlns
    
    puts "\t ::Mood::CreateNode"
    
    # Configure setup for PEP node
    set valueFormE [wrapper::createtag value -chdata $xmlns(node_config)]
    set fieldFormE [wrapper::createtag field  \
      -attrlist [list var "FORM_TYPE" type hidden] -subtags [list $valueFormE]]
    
    # PEP Values for access_model: roster / presence / open or authorize / whitelist
    set valueModelE [wrapper::createtag value -chdata roster]
    set fieldModelE [wrapper::createtag field  \
      -attrlist [list var "pubsub#access_model"] -subtags [list $valueModelE]]
    
    set xattr [list xmlns "jabber:x:data" type submit]
    set xsubE [list $fieldFormE $fieldModelE]
    set xE [wrapper::createtag x -attrlist $xattr -subtags $xsubE]
    
    ::Jabber::JlibCmd pubsub create -node $moodNode  \
      -command ::Mood::CreateNodeCB -configure $xE
}

proc ::Mood::CreateNodeCB {type args} {
    # empty
}

#-------------------------------------------------------------------------
#---------------------- (Extended Presence) ------------------------------
#-------------------------------------------------------------------------

# Not necessary for PEP.
proc ::Mood::PresenceHook {jid type args} {
    variable state

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

    array set argsA $args
    set from $argsA(-from)
    jlib::splitjidex $from node jidserver res
    set jid2 $node@$jidserver

    if { ![info exists state($jid2,pubsubsupport)] } {
        #------------- Check(disco#items) If the User supports PEP before subscribe
        ::Jabber::JlibCmd disco get_async items $jid2 [list ::Mood::OnDiscoContact]
    } 
}

proc ::Mood::OnDiscoContact {jlibname type from subiq args} {
    variable state
    variable node

    ::Debug 2 "::Mood::OnDiscoContactServer"

    # --- Check if contact supports Mood node ----
    if {$type eq "result"} {
        set nodes [::Jabber::JlibCmd disco nodes $from]
        foreach nodeItem $nodes {
            if { [string first "mood" $nodeItem] != -1 } {


                set state($from,pubsubsupport) true
		set myjid2 [::Jabber::JlibCmd myjid2]

                ::Jabber::JlibCmd pubsub subscribe $from $myjid2 -node $node -command ::Mood::PubSubscribeCB
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

if {0} {
    <message from='juliet@capulet.com'
	     to='benvolio@montague.net'
	     type='headline'
	     id='foo'>
      <event xmlns='http://jabber.org/protocol/pubsub#event'>
	<items node='http://jabber.org/protocol/tune'>
	  <item>
	    <tune xmlns='http://jabber.org/protocol/tune'>
	      <artist>Gerald Finzi</artist>
	      <title>Introduction (Allegro vigoroso)</title>
	      <source>Music for "Love's Labors Lost" (Suite for small orchestra)</source>
	      <track>1</track>
	      <length>255</length>
	    </tune>
	  </item>
	</items>
      </event>
    </message> 
}

proc ::Mood::Event {jlibname xmldata} {
    
    puts "::Mood::Event----->"
 
    set from [wrapper::getattribute $xmldata from]
    set eventE [wrapper::getfirstchildwithtag $xmldata event]
    if {[llength $eventE]} {
	set itemsE [wrapper::getfirstchildwithtag $eventE items]
	if {[llength $itemsE]} {
	    set node [wrapper::getattribute $itemsE node]
    
	    set itemE [wrapper::getfirstchildwithtag $itemsE item]
	    set moodE [wrapper::getfirstchildwithtag $itemE mood]
	
	
	
	}
    }
}

proc ::Mood::MessageHook {body args} {
    array set argsA $args
    variable state

    set xmlE $argsA(-xmldata)

    set from [wrapper::getattribute $xmlE from]

    set eventElem [wrapper::getfirstchildwithtag $xmlE event]

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
    # Mats ???
    #::Roster::Refresh

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

proc ::Mood::CustomMoodDlg {} {
    global  this wDlgs
    variable moodMessage
    variable moodState
    variable menuMoodVar
    variable myMoods
    variable mood2mLabel
    variable moodStateDlg

    set w ".mumdlg"
    if {[winfo exists $w]} {
	raise $w
	return
    }
    ::UI::Toplevel $w \
      -macstyle documentProc -macclass {document closeBox} -usemacmainmenu 1 \
      -closecommand [namespace current]::CloseCmd
    wm title $w [mc {moodDlg}]

    ::UI::SetWindowPosition $w ".mumdlg"
    
    set moodStateDlg $menuMoodVar

    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    ttk::label $wbox.msg  \
      -padding {0 0 0 6} -wraplength 260 -justify left -text [mc selectCustomMood]
    pack $wbox.msg -side top -anchor w

    set frmid $wbox.frmid
    ttk::frame $frmid
    pack $frmid -side top -fill both -expand 1

    #set moodList [list [mc mAngry] [mc mAnxious] [mc mAshamed] [mc mBored] [mc mCurious] [mc mDepressed] [mc mExcited] [mc mHappy] [mc mInLove] [mc mInvincible] [mc mJealous] [mc mNervous] [mc mSad] [mc mSleepy] [mc mStressed] [mc mWorried]]

    ttk::label $frmid.lmood -text "[mc {mMood}]:" 
    
    set mDef {}
    foreach mood $myMoods {
	lappend mDef [list [mc $mood2mLabel($mood)] -value $mood] 
    }
    ui::optionmenu $frmid.cmood -menulist $mDef -direction flush \
      -variable [namespace current]::moodStateDlg

    #ttk::combobox $frmid.cmood -state readonly -values $moodList \
    #  -textvariable [namespace current]::moodStateDlg

    ttk::label $frmid.ltext -text "[mc {moodMessage}]:"
    ttk::entry $frmid.etext -textvariable [namespace current]::moodMessageDlg

    grid  $frmid.lmood    $frmid.cmood  -sticky e -pady 2
    grid  $frmid.ltext    $frmid.etext  -sticky e -pady 2
    grid $frmid.cmood $frmid.etext -sticky ew
    grid columnconfigure $frmid 1 -weight 1

    # Button part.
    set frbot $wbox.b
    set wenter  $frbot.btok
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $wenter -text [mc OK] \
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

    Publish $mapMoodTextToElem($moodStateDlg) $moodMessageDlg

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
