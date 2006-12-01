#  Jabber.tcl ---
#  
#      This file is part of The Coccinella application. 
#      
#  Copyright (c) 2001-2006  Mats Bengtsson
#
# $Id: Jabber.tcl,v 1.189 2006-12-01 08:55:13 matben Exp $

package require balloonhelp
package require chasearrows
package require http 2.3
package require sha1
package require tinyfileutils
package require tree
package require uriencode
package require wavelabel


# jlib components shall be declared here, or later.
package require jlib
package require jlib::roster
package require jlib::bytestreams
package require jlib::caps
package require jlib::connect
package require jlib::disco
package require jlib::dns
package require jlib::ftrans
package require jlib::http
package require jlib::ibb
package require jlib::pubsub
package require jlib::si
package require jlib::vcard

# We should have some component mechanism that lets packages load themselves.
package require Avatar
package require Chat
package require Create
package require Disco
package require Emoticons
package require FTrans
package require GotMsg
package require GroupChat
package require JForms
package require JPrefs
package require JPubServers
package require JUI
package require JUser
package require JWB
package require Login
package require MailBox
package require MUC
package require NewMsg
package require OOB
package require Privacy
package require Profiles
package require Register
package require Roster
package require Rosticons
package require Search
package require Servicons
package require Status
package require Subscribe
package require UserInfo
package require VCard

package provide Jabber 1.0

namespace eval ::Jabber:: {
    global  this prefs
    
    # Add all event hooks.
    ::hooks::register quitAppHook        ::Jabber::EndSession
    ::hooks::register prefsInitHook      ::Jabber::InitPrefsHook

    # Jabber internal storage.
    variable jstate
    variable jprefs
    variable jserver
    variable jerror
    
    # Our own jid, and jid/resource respectively.
    set jstate(mejid)    ""
    set jstate(mejidres) ""
    set jstate(mejidmap) ""
    set jstate(meres)    ""
    
    set jstate(sock) {}
    set jstate(ipNum) {}
    
    # This is our own status (presence/show).
    set jstate(status) "unavailable"
    
    # Server port actually used.
    set jstate(servPort) {}
    
    set jstate(haveJabberUI) 0

    # Login server.
    set jserver(this) ""
    
    # Popup menus.
    set jstate(wpopup,disco)     .jpopupdi
    set jstate(wpopup,roster)    .jpopupro
    set jstate(wpopup,browse)    .jpopupbr
    set jstate(wpopup,groupchat) .jpopupgc
    
    # Keep noncritical error text here.
    set jerror {}
    
    # Array that acts as a data base for the public storage on the server.
    # Typically: jidPublic(matben@athlon.se,home,serverport).
    # Not used for the moment.
    variable jidPublic
    set jidPublic(haveit) 0
    
    # Array that maps namespace (ns) to a descriptive name.
    variable nsToText
    array set nsToText {
	iq                           "Info/query"
	message                      "Message handling"
	presence                     "Presence notification"
	presence-invisible           "Allows invisible users"
	jabber:client                "Client entity"
	jabber:iq:agent              "Server component properties"
	jabber:iq:agents             "Server component properties"
	jabber:iq:auth               "Client authentication"      
	jabber:iq:autoupdate         "Release information"
	jabber:iq:browse             "Browsing services"
	jabber:iq:conference         "Conferencing service"
	jabber:iq:gateway            "Gateway"
	jabber:iq:last               "Last time"
	jabber:iq:oob                "Out of band data"
	jabber:iq:privacy            "Blocking communication"
	jabber:iq:private            "Store private data"
	jabber:iq:register           "Interactive registration"
	jabber:iq:roster             "Roster management"
	jabber:iq:search             "Searching user database"
	jabber:iq:time               "Client time"
	jabber:iq:version            "Client version"
	jabber:x:autoupdate          "Client update notification"
	jabber:x:conference          "Conference invitation"
	jabber:x:delay               "Object delayed"
	jabber:x:encrypted           "Encrypted message"
	jabber:x:envelope            "Message envelope"
	jabber:x:event               "Message events"
	jabber:x:expire              "Message expiration"
	jabber:x:oob                 "Out of band attachment"
	jabber:x:roster              "Roster item in message"
	jabber:x:signed              "Signed presence"
	vcard-temp                   "Business card exchange"
	http://jabber.org/protocol/muc   "Multi user chat"
	http://jabber.org/protocol/disco "Feature discovery"
	http://jabber.org/protocol/caps  "Entity capabilities"
    }    
    
    # XML namespaces defined here.
    variable coccixmlns
    array set coccixmlns {
	coccinella      "http://coccinella.sourceforge.net/protocol/coccinella"
	servers         "http://coccinella.sourceforge.net/protocol/servers"
	whiteboard      "http://coccinella.sourceforge.net/protocol/whiteboard"
	public          "http://coccinella.sourceforge.net/protocol/private"
	caps            "http://coccinella.sourceforge.net/protocol/caps"
    }
    
    # Standard jabber (xmpp + XEP) protocol namespaces.
    variable xmppxmlns
    array set xmppxmlns {
	amp         "http://jabber.org/protocol/amp"
	caps        "http://jabber.org/protocol/caps"
	disco       "http://jabber.org/protocol/disco"
	disco,info  "http://jabber.org/protocol/disco#info"
	disco,items "http://jabber.org/protocol/disco#items"
	ibb         "http://jabber.org/protocol/ibb"
	muc         "http://jabber.org/protocol/muc"
	muc,admin   "http://jabber.org/protocol/muc#admin"
	muc,owner   "http://jabber.org/protocol/muc#owner"
	muc,user    "http://jabber.org/protocol/muc#user"
    }
    
    # Standard xmlns supported. Components add their own.
    variable clientxmlns
    set clientxmlns {
	"jabber:client"
	"jabber:iq:last"
	"jabber:iq:oob"
	"jabber:iq:time"
	"jabber:iq:version"
	"jabber:x:event"
    }    
    foreach {key xmlns} [array get coccixmlns] {
	lappend clientxmlns $xmlns
    }
    
    # Short error names.
    variable errorCodeToShort
    array set errorCodeToShort {
      301 "Moved Permanently"
      307 "Moved Temporarily"
      400 "Bad Request"
      401 "Unauthorized"
      404 "Not Found"
      405 "Not Allowed"
      406 "Not Acceptable"
      407 "Registration Required"
      408 "Request Timeout"
    }
    
    # Jabber specific mappings from three digit error code to text.
    variable errorCodeToText
    array set errorCodeToText {\
      conf_pres,301           {The room has changed names}     \
      conf_pres,307           {This room has changed location temporarily}  \
      conf_pres,401           {An authentication step is needed at the service\
      level before you can communicate with this room}      \
      conf_pres,403           {You are being denied access to rooms at the\
      service level}     \
      conf_pres,404           {The server only allows predefined rooms, and\
      the room specified does not exist}    \
      conf_pres,405           {You are being denied access to this specific\
      room, due to being on a ban list}\
      conf_pres,407           {A registration step is needed at the service\
      level before you can communicate with this room}     \
      conf_create,301         {The server has changed addresses}   \
      conf_create,307         {This server has changed location temporarily} \
      conf_create,401         {An authorization step is needed with this\
      service before interactions can occur with it}    \
      conf_create,403         {You are not allowed to interact with this\
      service}    \
      conf_create,407         {Registration with the service is required for\
      all interactions}   \
      conf_message,400        {The message was malformed in some manner,\
      such as sending a message that was of not of type "groupchat" to a room} \
      conf_message,401        {The user is not authorized to speak in this\
      room. This may be because the user does not have voice within the room}
      conf_message,404        {The client is sending a message to a room\
	which does not exist}    \
      conf_message,406        {Additional data was forwarded through the room\
      which the room is not configured to handle}    \
      conf_message,407        {The user is not a participant within the room,\
      and the room does not allow non-participant to speak within the room}  \
      conf_message,408        {The message timed out while being sent,\
      the user may resend}   \
      conf_message_dir,400    {The message was malformed, for instance,\
      it may have had type "groupchat"}   \
      conf_message_dir,401    {The user is not authorized to send directed\
      messages in this room}   \
      conf_message_dir,404    {The user could not be found within the room,\
      or the room does not exist}  \
      conf_message_dir,405    {The conferencing service does not support\
      directed messages}   \
      conf_message_dir,406    {A required extension is stopping this message}  \
      conf_message_dir,407    {The client is required to be in the room in\
      order to send a message to its participants}   \
      conf_message_dir,408    {The message timed out while being sent,\
      the user may resend}  \
    }
  
    variable killerId 
}

# Jabber::FactoryDefaults --
#
#       Makes reasonable default settings for a number of variables and
#       preferences.

proc ::Jabber::FactoryDefaults { } {
    global  this env prefs wDlgs sysFont
    
    variable jstate
    variable jprefs
    variable jserver
    
    # Network.
    set jprefs(port)    5222
    set jprefs(sslport) 5223
    set jprefs(usessl)  0
    
    # Protocol parts
    set jprefs(useSVGT) 0
    
    # Other
    set jprefs(defSubscribe)        1
    
    # Shall we query ip number directly when verified Coccinella?
    set jprefs(preGetIP) 1
    
    # Get ip addresses through <iq> element.
    # Switch off the raw stuff in later version.
    set jprefs(getIPraw) 0
            
    # Dialog pane positions.
    set prefs(paneGeom,$wDlgs(jchat))    {0.75 0.25}
    set prefs(paneGeom,$wDlgs(jinbox))   {0.5 0.5}
    set prefs(paneGeom,groupchatDlgVert) {0.8 0.2}
    set prefs(paneGeom,groupchatDlgHori) {0.8 0.2}
    
    set jprefs(useXData) 1
    
    set jstate(rosterVis) 1
    set jstate(browseVis) 0
    set jstate(rostBrowseVis) 1
    set jstate(debugCmd) 0
    
    # Query these jabber servers for services. Login server is automatically
    # queried.
    set jprefs(browseServers) {}
    set jprefs(agentsServers) {}
    
    # The User Info of servers.    
    set jserver(this) ""
    
    # New... Profiles. These are just leftovers that shall be removed later.
    set jserver(profile)  \
      {jabber.org {jabber.org myUsername myPassword home}}
    set jserver(profile,selected)  \
      [lindex $jserver(profile) 0]
    
    #
    set jprefs(urlServersList) "http://www.jabber.org/servers.xml"
        
    # Menu definitions for the Roster/services window. Collects minimal Jabber
    # stuff.
    variable menuDefs
    
    set menuDefs(min,edit) {    
	{command   mCut              {::UI::CutEvent}           X}
	{command   mCopy             {::UI::CopyEvent}          C}
	{command   mPaste            {::UI::PasteEvent}         V}
    }    
}

# Jabber::InitPrefsHook --
# 
#       Set defaults in the option database for widget classes.
#       First, on all platforms...
#       Set the user preferences from the preferences file if they are there,
#       else take the hardcoded defaults.
#       'thePrefs': a list of lists where each sublist defines an item in the
#       following way:  {theVarName itsResourceName itsHardCodedDefaultValue
#                 {thePriority 20}}.

proc ::Jabber::InitPrefsHook { } {
    
    variable jstate
    variable jprefs
    variable jserver
    
    # The profile stuff here is OUTDATED and replaced.

    ::PrefUtils::Add [list  \
      [list ::Jabber::jprefs(port)             jprefs_port              $jprefs(port)]  \
      [list ::Jabber::jprefs(sslport)          jprefs_sslport           $jprefs(sslport)]  \
      [list ::Jabber::jprefs(agentsServers)    jprefs_agentsServers     $jprefs(agentsServers)]  \
      [list ::Jabber::jserver(profile)         jserver_profile          $jserver(profile)      userDefault] \
      [list ::Jabber::jserver(profile,selected) jserver_profile_selected $jserver(profile,selected) userDefault] \
      ]
}

# Jabber::GetjprefsArray, GetjserverArray, ... --
# 
#       Accesor functions for various preference arrays.

proc ::Jabber::GetjprefsArray { } {
    variable jprefs
    
    return [array get jprefs]
}

proc ::Jabber::GetjserverArray { } {
    variable jserver
    
    return [array get jserver]
}

proc ::Jabber::SetjprefsArray {jprefsArrList} {
    variable jprefs
    
    array set jprefs $jprefsArrList
}

proc ::Jabber::GetIQRegisterElements { } {
    variable jprefs

    return $jprefs(iqRegisterElem)
}

proc ::Jabber::GetServerJid { } {
    variable jserver

    return $jserver(this)
}

proc ::Jabber::GetServerIpNum { } {
    variable jstate
    
    return $jstate(ipNum)
}

proc ::Jabber::GetMyJid {{roomjid {}}} {
    variable jstate

    set jid ""
    if {$roomjid eq ""} {
	set jid $jstate(mejidres)
    } else {
	if {[$jstate(jlib) service isroom $roomjid]} {
	    set hashandnick [$jstate(jlib) service hashandnick $roomjid]
	    set jid [lindex $hashandnick 0]   
	}
    }
    return $jid
}

proc ::Jabber::GetMyStatus { } {
    variable jstate
    
    return $jstate(status)
    
    # Alternative: [$jstate(jlib) mypresence]
}

proc ::Jabber::IsConnected { } {
    variable jstate

    # @@@ Bad solution to fix p2p bugs.
    if {[info exists jstate(jlib)]} {
	return [$jstate(jlib) isinstream]
    } else {
	return 0
    }
}

proc ::Jabber::JlibCmd {args} {
    variable jstate
    
    eval {$jstate(jlib)} $args
}

proc ::Jabber::RosterCmd {args}  {
    variable jstate
    
    eval {$jstate(jlib) roster} $args
}

proc ::Jabber::DiscoCmd {args}  {
    variable jstate
    
    eval {$jstate(jlib) disco} $args
}

# Generic ::Jabber:: stuff -----------------------------------------------------

# Jabber::Init --
#
#       Make all the necessary initializations, create roster object,
#       jlib object etc.
#       
# Arguments:
#       
# Results:
#       none.

proc ::Jabber::Init { } {
    global  wDlgs prefs
    
    variable jstate
    variable jprefs
    variable coccixmlns
    variable xmppxmlns
    
    ::Debug 2 "::Jabber::Init"
        
    # Check if we need to set any auto away options.
    set opts {}
    if {$jprefs(autoaway) && ($jprefs(awaymin) > 0)} {
	lappend opts -autoawaymins $jprefs(awaymin) -awaymsg $jprefs(awaymsg)
    }
    if {$jprefs(xautoaway) && ($jprefs(xawaymin) > 0)} {
	lappend opts -xautoawaymins $jprefs(xawaymin) -xawaymsg $jprefs(xawaymsg)
    }
    
    # Add the three element callbacks.
    lappend opts  \
      -iqcommand       ::Jabber::IqHandler        \
      -messagecommand  ::Jabber::MessageHandler   \
      -presencecommand ::Jabber::PresenceHandler

    # Make an instance of jabberlib and fill in our roster object.
    set jlibname [eval {::jlib::new ::Jabber::ClientProc} $opts]
    set jstate(jlib) $jlibname
    
    $jlibname roster register_cmd ::Roster::PushProc

    # Register handlers for various iq elements.
    $jlibname iq_register get jabber:iq:version    ::Jabber::ParseGetVersion
    $jlibname iq_register get $coccixmlns(servers) ::Jabber::ParseGetServers
    
    # Register handlers for all four (un)subscribe(d) events.
    $jlibname presence_register subscribe    [namespace code SubscribeEvent]
    $jlibname presence_register subscribed   [namespace code SubscribedEvent]
    $jlibname presence_register unsubscribe  [namespace code UnsubscribeEvent]
    $jlibname presence_register unsubscribed [namespace code UnsubscribedEvent]
        
    if {[string equal $prefs(protocol) "jabber"]} {
	::JUI::Show $wDlgs(jmain)
	set jstate(haveJabberUI) 1
    }
    
    # Register file transport mechanism used when responding to a disco info
    # request to the specified node.
    # In a component based system this should be done by the transport component.
    set subtags [list [wrapper::createtag "identity"  \
      -attrlist [list category hierarchy type leaf name "File transfer"]]]
    lappend subtags [wrapper::createtag "feature" \
      -attrlist [list var $xmppxmlns(disco,info)]]
    lappend subtags [wrapper::createtag "feature" \
      -attrlist [list var $coccixmlns(servers)]]
    lappend subtags [wrapper::createtag "feature" \
      -attrlist [list var jabber:iq:oob]]

    RegisterCapsExtKey ftrans $subtags
    
    # Stuff that need an instance of jabberlib register here.
    ::Debug 4 "--> jabberInitHook"
    ::hooks::run jabberInitHook $jlibname
    
    # Register extra presence elements.
    $jlibname register_presence_stanza [CreateCapsPresElement] -type available
    $jlibname register_presence_stanza [CreateCoccinellaPresElement] -type available
}

# ::Jabber::IqHandler --
#
#       Registered callback proc for <iq> elements. Most handled elsewhere,
#       in roster, browser and registered callbacks.
#       
# Results:
#       boolean (0/1) telling if this was handled or not. Only for 'get'.

proc ::Jabber::IqHandler {jlibname xmldata} {

    # empty
    return 0
}

# ::Jabber::MessageHandler --
#
#       Registered callback proc for <message> elements.
#       Not all messages may be delivered here; some may be intersected by
#       the 'register_message hook', some whiteboard messages for instance.
#       
# Arguments:
#       xmldata     intact xml list as received
#       
# Results:
#       none.

proc ::Jabber::MessageHandler {jlibname xmldata} {    
        
    set from [wrapper::getattribute $xmldata from]
    set type [wrapper::getattribute $xmldata type]
    set body ""

    # The hooks are expecting a -key value list of preprocessed xml.
    # @@@ In the future we may deliver the full xmldata instead.
    set opts [list -xmldata $xmldata]
    
    foreach {name value} [wrapper::getattrlist $xmldata] {
	lappend opts -$name $value
    }
    foreach E [wrapper::getchildren $xmldata] {
	set tag    [wrapper::gettag $E]
	set chdata [wrapper::getcdata $E]

	switch -- $tag {
	    body {
		set body $chdata
		lappend opts -$tag $chdata
	    }
	    subject - thread {
		lappend opts -$tag $chdata
	    }
	    default {
		lappend opts -$tag $E
	    }
	}	
    }    
    
    switch -- $type {
	error {
	    
	    # We must check if there is an error element sent along with the
	    # body element. In that case the body element shall not be processed.
	    set errspec [jlib::getstanzaerrorspec $xmldata]
	    if {[llength $errspec]} {
		set errcode [lindex $errspec 0]
		set errmsg  [lindex $errspec 1]		
		ui::dialog -title [mc Error] \
		  -message [mc jamesserrsend $from $errcode $errmsg] \
		  -icon error -type ok		
	    }
	    eval {::hooks::run newErrorMessageHook} $opts
	}
	chat {
	    eval {::hooks::run newChatMessageHook $body} $opts
	}
	groupchat {
	    eval {::hooks::run newGroupChatMessageHook $body} $opts
	}
	headline {
	    eval {::hooks::run newHeadlineMessageHook $body} $opts
	}
	default {
	    	    
	    # Add a unique identifier for each message which is handy for the mailbox.
	    lappend opts -uuid [uuid::uuid generate]
	    
	    # Normal message. Handles whiteboard stuff as well.
	    eval {::hooks::run newMessageHook $body} $opts
	}
    }
}

# Jabber::(Un)Subscribe(d)Event --
# 
#       Registered handlers for these presence event types.
#       Note that XMPP IM requires all from attributes to be bare JIDs.

proc ::Jabber::SubscribeEvent {jlibname xmldata} {
    variable jstate
    variable jprefs
    
    set jlib $jstate(jlib)
    
    set from [wrapper::getattribute $xmldata from]    
    set jid2 [jlib::barejid $from]
    set subscription [$jlib roster getsubscription $from]

    # Treat the case where the sender is a transport component.
    # We must be indenpendent of method; agent, browse, disco
    # The icq transports gives us subscribe from icq.host/registered
    
    set jidtype [lindex [$jlib disco types $jid2] 0]
    
    ::Debug 4 "\t jidtype=$jidtype"
    
    if {[::Roster::IsTransportHeuristics $from]} {
	
	# Add roster item before sending 'subscribed'. Didn't help :-(
	if {![$jlib roster isitem $from]} {
	    $jlib roster send_set $from -command ::Subscribe::ResProc
	}
	$jlib send_presence -to $from -type "subscribed"

	# It doesn't hurt to be subscribed to the transports presence.
	if {$subscription eq "none" || $subscription eq "from"} {
	    $jlib send_presence -to $from -type "subscribe"
	}
	
	set subtype [lindex [split $jidtype /] 1]
	set typename [::Roster::GetNameFromTrpt $subtype]
	::ui::dialog -title [mc {Transport Subscription}] \
	  -icon info -type ok -message [mc jamesstrptsubsc $typename]
    } else {
	
	# Another user request to subscribe to our presence.
	# Figure out what the user's prefs are.
	if {[$jlib roster isitem $jid2]} {
	    set key inrost
	} else {
	    set key notinrost
	}		
	
	# No resource here!
	if {$subscription eq "from" || $subscription eq "both"} {
	    set isSubscriberToMe 1
	} else {
	    set isSubscriberToMe 0
	}
	
	# Accept, deny, or ask depending on preferences we've set.
	set msg ""
	set autoaccepted 0
	
	switch -- $jprefs(subsc,$key) {
	    accept {
		$jlib send_presence -to $from -type "subscribed"
		set autoaccepted 1
		set msg [mc jamessautoaccepted $from]
	    }
	    reject {
		$jlib send_presence -to $from -type "unsubscribed"
		set msg [mc jamessautoreject $from]
	    }
	    ask {
		::Subscribe::NewDlg $from
	    }
	}
	if {$msg ne ""} {
	    ::ui::dialog -title [mc Info] -icon info -type ok \
	      -message $msg
	}
	
	# Auto subscribe to subscribers to me.
	if {$autoaccepted && $jprefs(subsc,auto)} {
	    
	    # Explicitly set the users group.
	    if {[string length $jprefs(subsc,group)]} {
		$jlib roster send_set $from  \
		  -groups [list $jprefs(subsc,group)]
	    }
	    $jlib send_presence -to $from -type "subscribe"
	    set msg [mc jamessautosubs $from]
	    ::ui::dialog -title [mc Info] -icon info -type ok \
	      -message $msg
	}
    }
    return 1
}

proc ::Jabber::SubscribedEvent {jlibname xmldata} {
    variable jstate
    
    set jlib $jstate(jlib)
    
    set from [wrapper::getattribute $xmldata from]    

    if {[::Roster::IsTransportHeuristics $from]} {
	# silent.
    } else {
	::ui::dialog -title [mc Subscribed] -icon info -type ok  \
	  -message [mc jamessallowsub $from]
    }
    return 1
}

proc ::Jabber::UnsubscribeEvent {jlibname xmldata} {
    variable jstate
    variable jprefs
    
    set jlib $jstate(jlib)

    set from [wrapper::getattribute $xmldata from]    
    set subscription [$jlib roster getsubscription $from]

    if {$jprefs(rost,rmIfUnsub)} {
	
	# Remove completely from our roster.
	$jlib roster send_remove $from
	::ui::dialog -title [mc Unsubscribe] \
	  -icon info -type ok -message [mc jamessunsub $from]
    } else {
	
	$jlib send_presence -to $from -type "unsubscribed"
	::UI::MessageBox -title [mc Unsubscribe] -icon info -type ok  \
	  -message [mc jamessunsubpres $from]
	
	# If there is any subscription to this jid's presence.
	if {$subscription eq "both" || $subscription eq "to"} {
	    
	    set ans [::UI::MessageBox -title [mc Unsubscribed]  \
	      -icon question -type yesno -default yes \
	      -message [mc jamessunsubask $from $from]]
	    if {$ans eq "yes"} {
		$jlib roster send_remove $from
	    }
	}
    }
    return 1
}

proc ::Jabber::UnsubscribedEvent {jlibname xmldata} {
    variable jstate
    variable jprefs
    
    set jlib $jstate(jlib)

    set from [wrapper::getattribute $xmldata from]    
    set subscription [$jlib roster getsubscription $from]
    
    # If we fail to subscribe someone due to a technical reason we
    # have subscription='none'
    if {$subscription eq "none"} {
	set msg [mc jamessfailedsubsc $from]
	set status [$jlib roster getstatus $from]
	if {$status ne ""} {
	    append msg " " $status
	}
	::ui::dialog -title [mc {Subscription Failed}]  \
	  -icon info -type ok -message $msg
	if {$jprefs(rost,rmIfUnsub)} {
	    
	    # Remove completely from our roster.
	    $jlib roster send_remove $from
	}
    } else {		
	::ui::dialog -title [mc Unsubscribed] -icon info -type ok \
	  -message [mc jamessunsubscribed $from]
    }
    return 1
}

# ::Jabber::PresenceHandler --
#
#       Registered callback proc for <presence> elements.
#       
# Arguments:
#       jlibName    Name of jabberlib instance.
#       type        the type attribute of the presence element
#       args        Is a list of '-key value' pairs.
#       
# Results:
#       none.

proc ::Jabber::PresenceHandler {jlibname xmldata} {
    
    set from [wrapper::getattribute $xmldata from]
    set type [wrapper::getattribute $xmldata type]
    if {$type eq ""} {
	set type "available"
    }
    
    switch -- $type {
	error {
	    set errspec [jlib::getstanzaerrorspec $xmldata]
	    foreach {errcode errmsg} $errspec break		
	    set msg [mc jamesserrpres $errcode $errmsg]
	    if {$::config(talkative)} {
		::UI::MessageBox -icon error -type ok  \
		  -title [mc {Presence Error}] -message $msg
	    }
	    ::Jabber::AddErrorLog $from $msg
	}
    }
}

# Jabber::ClientProc --
#
#       This is our standard client procedure for callbacks from jabberlib.
#       It is supposed to handle every event that is not the arrival of any of
#       the <iq>, <message>, or <presence> elements.
#       
# Arguments:
#       jlibName    Name of jabberlib instance.
#       what        Any of "connect", "disconnect", "xmlerror", "networkerror",
#                   "away", or "xa"
#       args        Is a list of '-key value' pairs.
#       
# Results:
#       none.

proc ::Jabber::ClientProc {jlibName what args} {
    global  wDlgs
    
    variable jstate
    variable jprefs
    
    ::Debug 2 "::Jabber::ClientProc: jlibName=$jlibName, what=$what, args='$args'"
    
    # For each 'what', split the argument list into the proper arguments,
    # and make the necessary calls.
    array set argsArr $args
    set ishandled 0
    
    switch -glob -- $what {
	disconnect {	    
	    
	    # This is as a response to a </stream> element.
	    # If we close the socket and don't wait for the close element
	    # we never end up here.
	    
	    # Disconnect. This should reset both wrapper and XML parser!
	    #::Jabber::DoCloseClientConnection
	    SetClosedState
	    ::UI::MessageBox -icon error -type ok -message [mc jamessconnbroken]
	}
	away - xa {
	    set jstate(status) $what
	    ::hooks::run setPresenceHook $what
	    #after idle ::Jabber::AutoAway
	}
	streamerror - xmpp-streams-error* {
	    DoCloseClientConnection
	    if {[info exists argsArr(-errormsg)]} {
		set msg "Receieved a fatal error: "
		append msg $argsArr(-errormsg)
		append msg "\n"
		append msg "The connection is closed."
	    } else {
		set msg "Receieved a fatal error. The connection is closed."
	    }
	    ::UI::MessageBox -title [mc {Fatal Error}] -icon error -type ok \
	      -message $msg
	}
	xmlerror {
	    
	    # XML parsing error.
	    # Disconnect. This should reset both wrapper and XML parser!
	    DoCloseClientConnection
	    if {[info exists argsArr(-errormsg)]} {
		set msg "Receieved a fatal XML parsing error: "
		append msg $argsArr(-errormsg)
		append msg "\n"
		append msg "The connection is closed down."
	    } else {
		set msg "Receieved a fatal XML parsing error.\
		  The connection is closed down."
	    }
	    ::UI::MessageBox -title [mc {Fatal Error}] -icon error -type ok \
	      -message $msg
	}
	networkerror {
	    
	    # Disconnect. This should reset both wrapper and XML parser!
	    #::Jabber::DoCloseClientConnection
	    SetClosedState
	    set msg [mc jamessconnbroken]
	    if {[info exists argsArr(-errormsg)]} {
		append msg "\n"
		append msg $argsArr(-errormsg)
	    }
	    ::UI::MessageBox -icon error -type ok -message $msg
	}
    }
    return $ishandled
}

proc ::Jabber::AutoAway {} {
    
    # This is a naive try to avoid that the modal dialog blocks. BAD!!!
    set tm [clock format [clock seconds] -format "%H:%M:%S"]
    set ans [::UI::MessageBox -icon info -type yesno -default yes \
      -message [mc jamessautoawayset $tm]]
    if {$ans eq "yes"} {
	SetStatus available
    }
}

# Jabber::DebugCmd --
#
#       Hides or shows console on mac and windows, sets debug for XML I/O.

proc ::Jabber::DebugCmd { } {
    global  this
    
    variable jstate
    
    if {$jstate(debugCmd)} {
	if {$this(platform) eq "windows" || [string match "mac*" $this(platform)]} {
	    console show
	}
	jlib::setdebug 2
    } else {
	if {$this(platform) eq "windows" || [string match "mac*" $this(platform)]} {
	    console hide
	}
	jlib::setdebug 0
    }
}

proc ::Jabber::AddErrorLog {jid msg} {    
    variable jerror
    
    set tm [clock format [clock seconds] -format "%H:%M:%S"]
    lappend jerror [list $tm $jid $msg]
}

# Jabber::ErrorLogDlg

proc ::Jabber::ErrorLogDlg { } {
    global  this wDlgs
    
    variable jerror

    set w $wDlgs(jerrdlg)
    if {[winfo exists $w]} {
	raise $w
	return
    }
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc
    wm title $w [mc {Error Log (noncriticals)}]
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1
    
    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc Close] -command [list destroy $w]
    pack  $frbot.btok  -side right
    pack  $frbot       -side bottom -fill x

    # Text.
    set wtxt  $wbox.frtxt
    set wtext $wtxt.text
    set wysc  $wtxt.ysc
    frame $wtxt -bd 1 -relief sunken
    pack $wtxt -side top -fill both -expand 1

    text $wtext -height 12 -width 48 -wrap word -bd 0 \
      -highlightthickness 0 -yscrollcommand [list $wysc set]
    ttk::scrollbar $wysc -orient vertical -command [list $wtext yview]
    
    grid  $wtext  -column 0 -row 0 -sticky news
    grid  $wysc   -column 1 -row 0 -sticky ns
    grid columnconfigure $wtxt 0 -weight 1
    grid rowconfigure $wtxt 0 -weight 1
    
    set space 2
    $wtext tag configure timetag -spacing1 $space -foreground blue
    $wtext tag configure jidtag -spacing1 $space -foreground red
    $wtext tag configure msgtag -spacing1 $space -spacing3 $space   \
      -lmargin1 20 -lmargin2 30
        
    $wtext configure -state normal
    foreach line $jerror {
	foreach {tm jid msg} $line break
	$wtext insert end "<$tm>:  " timetag
	$wtext insert end "$jid   " jidtag
	$wtext insert end $msg msgtag
	$wtext insert end "\n"
    }
    $wtext configure -state disabled
}

# Jabber::IqSetGetCallback --
#
#       Generic callback procedure when sending set/get iq element.
#       
# Arguments:
#       method      description of the original call.
#       jlibName:   the instance of this jlib.
#       type:       "error" or "result".
#       thequery:   if type="error", this is a list {errcode errmsg},
#                   else it is the query element as a xml list structure.
#       
# Results:
#       none.

proc ::Jabber::IqSetGetCallback {method jlibName type theQuery} {    
    variable jstate
    
    ::Debug 2 "::Jabber::IqSetGetCallback, method=$method, type=$type,\
	  theQuery='$theQuery'"
	
    if {[string equal $type "error"]} {
	foreach {errcode errmsg} $theQuery break
	
	switch -- $method {
	    default {
		set msg "Found an error for $method with code $errcode,\
		  and with message: $errmsg"
	    }
	}
	::UI::MessageBox -icon error -type ok -title [mc Error] -message $msg
    }
}

# Jabber::DoCloseClientConnection --
#
#       Handle closing down the client side connection (the 'to' part).
#       Try to be silent if called as a response to a server shutdown.
#       
# Arguments:
#       args      -status, 
#       
# Results:
#       none

proc ::Jabber::DoCloseClientConnection {args} {
    global  prefs
        
    variable jstate
    variable jserver
    variable jprefs
    
    ::Debug 2 "::Jabber::DoCloseClientConnection"
    
    array set argsArr [list -status $jprefs(logoutStatus)]    
    array set argsArr $args
    
    # Send unavailable information.
    if {[$jstate(jlib) isinstream]} {
	set opts {}
	if {[string length $argsArr(-status)] > 0} {
	    lappend opts -status $argsArr(-status)
	}
	eval {$jstate(jlib) send_presence -type unavailable} $opts
	
	# Do the actual closing.
	#       There is a potential problem if called from within a xml parser 
	#       callback which makes the subsequent parsing to fail. (after idle?)
	after idle $jstate(jlib) closestream
    }
    SetClosedState
}

# Jabber::SetClosedState --
# 
#       Sets the application closed connection state.
#       Called either when doing a controlled close connection,
#       or as a result of any exception.
#       Doesn't do any network transactions.

proc ::Jabber::SetClosedState { } {
    variable jstate
    variable jserver
    
    ::Debug 2 "::Jabber::SetClosedState"

    # Ourself.
    set jstate(mejid)    ""
    set jstate(meres)    ""
    set jstate(mejidres) ""
    set jstate(mejidmap) ""
    set jstate(status)   "unavailable"
    set jserver(this)    ""
    set jstate(ipNum)    ""
    
    # Run all logout hooks.
    ::hooks::run logoutHook
}

# Jabber::EndSession --
#
#       This is supposed to be called only when doing Quit.
#       Things are not cleaned up properly, since we kill ourselves.

proc ::Jabber::EndSession { } {    
    variable jstate
    variable jserver
    variable jprefs
    
    # This protects against previous p2p setup. BAD!
    if {![::Jabber::IsConnected]} {
	return
    }

    # Send unavailable information. Silently in case we got a network error.
    if {[$jstate(jlib) isinstream]} {
	set opts {}
	if {[string length $jprefs(logoutStatus)] > 0} {
	    lappend opts -status $jprefs(logoutStatus)
	}
	catch {
	    eval {$jstate(jlib) send_presence -type unavailable} $opts
	}
	
	# Do the actual closing.
	#       There is a potential problem if called from within a xml parser 
	#       callback which makes the subsequent parsing to fail. (after idle?)
	$jstate(jlib) closestream
    }
}

# Jabber::Validate... --
#
#       Validate entry for username etc.
#       
# Arguments:
#       str     username etc.
#       
# Results:
#       boolean: 0 if reject, 1 if accept

proc ::Jabber::ValidateDomainStr {str} {
    
    if {[catch {jlib::nameprep $str} err]} {
	bell
	return 0
    } else {
	return 1
    }
}

proc ::Jabber::ValidateUsernameStr {str} {
    
    if {[catch {jlib::nodeprep $str} err]} {
	bell
	return 0
    } else {
	return 1
    }
}

proc ::Jabber::ValidateResourceStr {str} {
    
    if {[catch {jlib::resourceprep $str} err]} {
	bell
	return 0
    } else {
	return 1
    }
}

# Jabber::ValidatePasswordStr --
#
#       Validate entry for password. Not so sure about this. Docs?
#       
# Arguments:
#       str     password
#       
# Results:
#       boolean: 0 if reject, 1 if accept

proc ::Jabber::ValidatePasswordStr {str} {
    
    # @@@ I don't know if there are any limitations at all.
    return 1
}

# Jabber::IsMyGroupchatJid --
# 
#       Is the jid our own used in groupchat?

proc ::Jabber::IsMyGroupchatJid {jid} {
    variable jstate
    
    jlib::splitjid $jid room resource
    foreach {meHash nick} [$jstate(jlib) service hashandnick $room] break
    set isme 0
    if {[string equal $meHash $jid]} {
	set isme 1
    }
    return $isme
}

# Jabber::SetStatus --
#
#       Sends presence status information. 
#       It should take care of everything (almost) when setting status.
#       
# Arguments:
#       type        any of 'available', 'unavailable', 'invisible',
#                   'away', 'dnd', 'xa', 'chat'.
#       args
#                -to      sets any to='jid' attribute.
#                -notype  0|1 see XMPP 5.1
#                -priority
#                -status  text message
#                -xlist
#                -extras
#       
# Results:
#       None.

proc ::Jabber::SetStatus {type args} {    
    variable jstate
    variable jserver
    variable jprefs
    
    ::Debug 4 "::Jabber::SetStatus type=$type, args=$args"
    
    # We protect against accidental calls. (logoutHook)
    if {![$jstate(jlib) isinstream]} {
	return
    }
    array set argsArr {
	-notype         0
    }
    
    # Any -status take precedence, even if empty.
    array set argsArr $args

    # Any default status?
    if {![info exists argsArr(-status)]} {
	if {$jprefs(statusMsg,bool,$type) \
	  && ($jprefs(statusMsg,msg,$type) ne "")} {
	    set argsArr(-status) $jprefs(statusMsg,msg,$type)
	}
    }
    
    set presArgs {}
    foreach {key value} [array get argsArr] {
	
	switch -- $key {
	    -to - -priority - -status - -xlist - -extras {
		lappend presArgs $key $value
	    }
	}
    }
    if {!$argsArr(-notype)} {
	
	switch -- $type {
	    available {
		# empty
	    }
	    invisible - unavailable {
		lappend presArgs -type $type
	    }
	    away - dnd - xa - chat {
		# Seems Psi gets confused by this.
		#lappend presArgs -type "available" -show $type
		lappend presArgs -show $type
	    }
	}	
    }
    
    # General presence should not have a 'to' attribute.
    if {![info exists argsArr(-to)]} {
	set jstate(status) $type
    }
    
    # It is somewhat unclear here if we should have a type attribute
    # when sending initial presence, see XMPP 5.1.
    eval {$jstate(jlib) send_presence} $presArgs
	
    eval {::hooks::run setPresenceHook $type} $args
    
    # Do we target a room or the server itself?
    set toServer 0
    if {[info exists argsArr(-to)]} {
	if {[jlib::jidequal $jserver(this) $argsArr(-to)]} {
	    set toServer 1
	}
    } else {
	set toServer 1
    }
    if {$toServer && ($type eq "unavailable")} {
	after idle $jstate(jlib) closestream	    
	SetClosedState
    }
}

# Jabber::SyncStatus --
# 
#       Synchronize the presence we have. 
#       This is useful if we happen to change a custom presence x element,
#       for instance, our phone status.

proc ::Jabber::SyncStatus { } {
    variable jstate
    
    # We need to add -status to preserve it.
    SetStatus [$jstate(jlib) mypresence] -status [$jstate(jlib) mypresencestatus]
}

# Jabber::CreateCoccinellaPresElement --
# 
#       Used when sending inital presence. This way clients get the info
#       necessary for file transports.
#       
#  <coccinella 
#      xmlns='http://coccinella.sourceforge.net/protocol/servers'>
#                <ip protocol='putget' port='8235'>212.214.113.57</ip>
#                <ip protocol='http' port='8077'>212.214.113.57</ip>
#  </coccinella>
#  
#  Now <x .../> instead.

proc ::Jabber::CreateCoccinellaPresElement { } {
    global  prefs this
    
    variable jstate
    variable coccixmlns
	
    set ip [::Network::GetThisPublicIP]

    set attrputget [list protocol putget port $prefs(thisServPort)]
    set attrhttpd  [list protocol http   port $prefs(httpdPort)]
    set subelem [list  \
      [wrapper::createtag ip -chdata $ip -attrlist $attrputget]  \
      [wrapper::createtag ip -chdata $ip -attrlist $attrhttpd]]

    # Switch to x-element.
    set xmllist [wrapper::createtag x -subtags $subelem \
      -attrlist [list xmlns $coccixmlns(servers) ver $this(vers,full)]]

    return $xmllist
}

# Jabber::CreateCapsPresElement --
# 
#       Used when sending inital presence. This way clients get various info.
#       See [XEP 0115]
#       Note that this doesn't replace the 'coccinella' element since caps
#       are not instance specific (can't send ip addresses).

proc ::Jabber::CreateCapsPresElement { } {
    global  this
    variable coccixmlns
    variable capsExtArr
    variable xmppxmlns

    set node $coccixmlns(caps)
    set exts [lsort [array names capsExtArr]]
    set xmllist [wrapper::createtag c -attrlist \
      [list xmlns $xmppxmlns(caps) node $node ver $this(vers,full) ext $exts]]

    return $xmllist
}

proc ::Jabber::RegisterCapsExtKey {name subtags} {    
    variable capsExtArr
    
    set capsExtArr($name) $subtags
}

proc ::Jabber::GetCapsExtKeyList { } {
    variable capsExtArr
    
    return [lsort [array names capsExtArr]]
}

proc ::Jabber::GetCapsExtSubtags {name} {
    variable capsExtArr
    
    if {[info exists capsExtArr($name)]} {
	return $capsExtArr($name)
    } else {
	return {}
    }
}
    
# Jabber::GetAnyDelayElem --
#
#       Takes a list of x-elements, finds any 'jabber:x:delay' x-element.
#       If no such element it returns empty.
#       
# Arguments:
#       xlist       Must be an hierarchical xml list of <x> elements.  
#       
# Results:
#       jabber:x:delay stamp attribute or empty. This is ISO 8601.

proc ::Jabber::GetAnyDelayElem {xlist} {
    
    set ans ""    
    set delayList [wrapper::getnamespacefromchilds $xlist x "jabber:x:delay"]
    if {[llength $delayList]} {
	array set attrArr [wrapper::getattrlist [lindex $delayList 0]]
	if {[info exists attrArr(stamp)]} {
	    set ans $attrArr(stamp)
	}
    }
    return $ans
}

proc ::Jabber::GetDelayStamp {xmldata} {
    
    set xE [wrapper::getfirstchildwithxmlns $xmldata "jabber:x:delay"]
    if {[llength $xE]} {
	return [wrapper::getattribute $xE stamp]
    } else {
	return ""
    }
}

#-------------------------------------------------------------------------------
    
# Jabber::GetLast --
#
#       Makes a jabber:iq:last query.
#
#       args    ?-silent 0/1? (D=0)
#       
# Results:
#       callback scheduled.

proc ::Jabber::GetLast {to args} {
    variable jstate
    
    array set opts {
	-silent 0
    }
    array set opts $args    
    $jstate(jlib) get_last $to [list ::Jabber::GetLastResult $to $opts(-silent)]
}

# Jabber::GetLastResult --
#
#       Callback for '::Jabber::GetLast'.

proc ::Jabber::GetLastResult {from silent jlibname type subiq} {    

    if {[string equal $type "error"]} {
	set msg [mc jamesserrlastactive $from [lindex $subiq 1]]
	::Jabber::AddErrorLog $from $msg	    
	if {!$silent} {
	    ::UI::MessageBox -title [mc Error] -icon error -type ok \
	      -message $msg
	}
    } else {
	array set attrArr [wrapper::getattrlist $subiq]
	if {![info exists attrArr(seconds)]} {
	    ::UI::MessageBox -title [mc {Last Activity}] -icon info  \
	      -type ok -message [mc jamesserrnotimeinfo $from]
	} else {
	    ::UI::MessageBox -title [mc {Last Activity}] -icon info  \
	      -type ok -message [GetLastString $from $subiq]
	}
    }
}

proc ::Jabber::GetLastString {jid subiq} {
    
    array set attrArr [wrapper::getattrlist $subiq]
    if {![info exists attrArr(seconds)]} {
	set str [mc jamesserrnotimeinfo $jid]
    } elseif {![string is integer -strict $attrArr(seconds)]} {
	set str [mc jamesserrnotimeinfo $jid]
    } else {
	set secs [expr [clock seconds] - $attrArr(seconds)]
	set uptime [clock format $secs -format "%a %b %d %H:%M:%S %Y"]
	if {[wrapper::getcdata $subiq] ne ""} {
	    set msg "The message: [wrapper::getcdata $subiq]"
	} else {
	    set msg ""
	}
	
	# Time interpreted differently for different jid types.
	if {$jid ne ""} {
	    if {[regexp {^[^@]+@[^/]+/.*$} $jid match]} {
		set msg1 [mc jamesstimeused $jid]
	    } elseif {[regexp {^.+@[^/]+$} $jid match]} {
		set msg1 [mc jamesstimeconn $jid]
	    } else {
		set msg1 [mc jamesstimeservstart $jid]
	    }
	} else {
	    set msg1 [mc jamessuptime]
	}
	set str "$msg1 $uptime. $msg"
    }
    return $str
}

# Jabber::GetTime --
#
#       Makes a jabber:iq:time query.
#
#       args    ?-silent 0/1? (D=0)
#       
# Results:
#       callback scheduled.

proc ::Jabber::GetTime {to args} {
    variable jstate
    
    array set opts {
	-silent 0
    }
    array set opts $args    
    $jstate(jlib) get_time $to [list ::Jabber::GetTimeResult $to $opts(-silent)]
}

proc ::Jabber::GetTimeResult {from silent jlibname type subiq} {

    if {[string equal $type "error"]} {
	::Jabber::AddErrorLog $from  \
	  "We received an error when quering its time info.\
	  The error was: [lindex $subiq 1]"	    
	if {!$silent} {
	    ::UI::MessageBox -title [mc Error] -icon error -type ok \
	      -message [mc jamesserrtime $from [lindex $subiq 1]]
	}
    } else {
	set msg [GetTimeString $subiq]
	::UI::MessageBox -title [mc {Local Time}] -icon info -type ok \
	  -message [mc jamesslocaltime $from $msg]
    }
}

proc ::Jabber::GetTimeString {subiq} {
    
    # Display the cdata of <display>, or <utc>.
    foreach child [wrapper::getchildren $subiq] {
	set tag [lindex $child 0]
	set $tag [lindex $child 3]
    }
    if {[info exists display]} {
	set msg $display
    } elseif {[info exists utc]} {
	set msg [clock format [clock scan $utc]]
    } elseif {[info exists tz]} {
	# ???
    } else {
	set msg "unknown"
    }
    return $msg
}

namespace eval ::Jabber:: {
    
    # Running uid for dialog window path.
    variable uidvers 0
}

# Jabber::GetVersion --
#
#       args    ?-silent 0/1? (D=0)
#       
# Results:
#       callback scheduled.

proc ::Jabber::GetVersion {to args} {
    variable jstate

    array set opts {
	-silent 0
    }
    array set opts $args    
    $jstate(jlib) get_version $to  \
      [list ::Jabber::GetVersionResult $to $opts(-silent)]
}

proc ::Jabber::GetVersionResult {from silent jlibname type subiq} {
    global  prefs this
    
    variable uidvers
    
    if {[string equal $type "error"]} {
	::Jabber::AddErrorLog $from  \
	  [mc jamesserrvers $from [lindex $subiq 1]]
	if {!$silent} {
	    ::UI::MessageBox -title [mc Error] -icon error -type ok \
	      -message [mc jamesserrvers $from [lindex $subiq 1]]
	}
	return
    }
    
    set w .jvers[incr uidvers]
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox}
    wm title $w [mc {Version Info}]

    set im  [::Theme::GetImage info]
    set imd [::Theme::GetImage infoDis]

    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1
    
    ttk::label $w.frall.head -style Headlabel \
      -text [mc {Version Info}] -compound left \
      -image [list $im background $imd]
    pack $w.frall.head -side top -anchor w

    ttk::separator $w.frall.s -orient horizontal
    pack $w.frall.s -side top -fill x

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1
    
    ttk::label $wbox.msg  \
      -padding {0 0 0 6} -wraplength 300 -justify left \
      -text [mc javersinfo $from]
    pack $wbox.msg -side top -anchor w

    set frmid $wbox.frmid
    ttk::frame $frmid
    pack $frmid -side top -fill both -expand 1

    set i 0
    foreach child [wrapper::getchildren $subiq] {
	ttk::label $frmid.l$i -style Small.TLabel \
	  -text "[lindex $child 0]:"
	ttk::label $frmid.lr$i -style Small.TLabel \
	  -text [lindex $child 3]

	grid  $frmid.l$i   $frmid.lr$i  -sticky ne
	grid  $frmid.lr$i  -sticky w
	incr i
    }
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc OK] -command [list destroy $w]
    pack $frbot.btok -side right
    pack $frbot -side top -fill x

    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btok invoke]
}

# Jabber::CacheGroupchatType --
#
#       Callback from a 'jabber:iq:version' query called from either the agent,
#       or the browse callback procs to see which protocols may be used:
#       'conference' and 'groupchat' or only 'groupchat'.
#

proc ::Jabber::CacheGroupchatType {confjid jlibname type subiq} {    
    variable jstate
    
    if {[string equal $type "error"]} {
	
	# Perhaps we should log it in our error log?
	return
    }
    
    # The conference component:
    # <query xmlns='jabber:iq:version'><name>conference</name><version>0.4</version>
    #   <os>Linux 2.4.2-2</os></query>
    
    # The MUC, Multi User Chat (MUC) component:
    # <query xmlns='jabber:iq:version'><name>MU-Conference</name><version>0.4cvs</version>
    #	<os>Linux 2.4.17</os></query>
    
    set name ""
    set version ""
    foreach child [wrapper::getchildren $subiq] {
	set tag  [wrapper::gettag $child]
	set $tag [wrapper::getcdata $child]
    }
		
    # This is a VERY rude ad hoc method of figuring out if the
    # server has a conference component.
    if {($name eq "conference") && ($version ne "1.0") && ($version ne "1.1")} {
	set jstate(conference,$confjid) 1
	set jstate(groupchatprotocol,$confjid) "conference"
    } elseif {[string match -nocase "*mu*" $name]} {
	set jstate(groupchatprotocol,$confjid) "muc"
    }
}
    
# Jabber::ParseGetVersion --
#
#       Respond to an incoming 'jabber:iq:version' get query.

proc ::Jabber::ParseGetVersion {jlibname from subiq args} {
    global  prefs tcl_platform this
    variable jstate
    
    ::Debug 2 "Jabber::ParseGetVersion args='$args'"
    
    array set argsArr $args
    
    # Return any id!
    set opts {}
    if {[info exists argsArr(-id)]} {
	set opts [list -id $argsArr(-id)]
    }
    lappend opts -to $from
   
    set os $tcl_platform(os)
    if {[info exists tcl_platform(osVersion)]} {
	append os " $tcl_platform(osVersion)"
    }
    set version $this(vers,full)
    set subtags [list  \
      [wrapper::createtag name    -chdata "Coccinella"]  \
      [wrapper::createtag version -chdata $version]      \
      [wrapper::createtag os      -chdata $os]]
    set xmllist [wrapper::createtag query -subtags $subtags  \
      -attrlist {xmlns jabber:iq:version}]
    eval {$jstate(jlib) send_iq "result" [list $xmllist]} $opts

    # Tell jlib's iq-handler that we handled the event.
    return 1
}

# Jabber::ParseGetServers --
# 
#       Sends something like:
#       <iq type='result' id='1012' to='matben@jabber.dk/coccinella'>
#           <query xmlns='http://coccinella.sourceforge.net/protocol/servers'>
#                <ip protocol='putget' port='8235'>212.214.113.57</ip>
#                <ip protocol='http' port='8077'>212.214.113.57</ip>
#            </query>
#       </iq>
#       

proc ::Jabber::ParseGetServers  {jlibname from subiq args} {
    global  prefs
    
    variable jstate
    variable coccixmlns
    
    # Build tag and attributes lists.
    set ip [::Network::GetThisPublicIP]
    
    array set argsArr $args
    
    # Return any id!
    set opts {}
    if {[info exists argsArr(-id)]} {
	set opts [list -id $argsArr(-id)]
    }
    lappend opts -to $from
    
    set attrputget [list protocol putget port $prefs(thisServPort)]
    set attrhttpd  [list protocol http port $prefs(httpdPort)]
    set subtags [list  \
      [wrapper::createtag ip -chdata $ip -attrlist $attrputget]  \
      [wrapper::createtag ip -chdata $ip -attrlist $attrhttpd]]
    set xmllist [wrapper::createtag query -subtags $subtags  \
      -attrlist [list xmlns $coccixmlns(servers)]]
    eval {$jstate(jlib) send_iq "result" [list $xmllist]} $opts
    
     # Tell jlib's iq-handler that we handled the event.
    return 1
}

# ::Jabber::AddClientXmlns --
# 
#       Reserved for specific client xmlns, not library ones.

proc ::Jabber::AddClientXmlns {xmlnsList} {
    variable clientxmlns
    
    set clientxmlns [concat $clientxmlns $xmlnsList]
}

proc ::Jabber::GetClientXmlnsList { } {
    variable clientxmlns
    
    return $clientxmlns
}

# The ::Jabber::Passwd:: namespace -------------------------------------------

namespace eval ::Jabber::Passwd:: {

    variable password
}

proc ::Jabber::Passwd::OnMenu { } {
    if {[llength [grab current]]} { return }
    if {[::JUI::GetConnectState] eq "connectfin"} {
	Build
    }    
}

# Jabber::Passwd::Build --
#
#       Sets new password.
#
# Arguments:
#       
# Results:
#       "cancel" or "set".

proc ::Jabber::Passwd::Build { } {
    global  this wDlgs
    
    variable finished -1
    variable password
    variable validate
    upvar ::Jabber::jstate jstate
    
    set password ""
    set validate ""

    set w $wDlgs(jpasswd)
    if {[winfo exists $w]} {
	return
    }
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox} \
      -closecommand [namespace current]::Close
    wm title $w [mc {New Password}]
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1
    
    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    # Entries etc.
    set frmid $wbox.frmid
    ttk::frame $frmid
    pack $frmid -side top -fill both -expand 1

    ttk::label $frmid.ll -text [mc janewpass]
    ttk::label $frmid.le -text $jstate(mejid)
    ttk::label $frmid.lserv -text "[mc {New Password}]:" -anchor e
    ttk::entry $frmid.eserv -width 18 -show *  \
      -textvariable [namespace current]::password -validate key  \
      -validatecommand {::Jabber::ValidatePasswordStr %S}
    ttk::label $frmid.lvalid -text "[mc {Retype Password}]:" -anchor e
    ttk::entry $frmid.evalid -width 18 -show * \
      -textvariable [namespace current]::validate -validate key  \
      -validatecommand {::Jabber::ValidatePasswordStr %S}

    grid  $frmid.ll      $frmid.le      -sticky e -pady 2
    grid  $frmid.lserv   $frmid.eserv   -sticky e -pady 2
    grid  $frmid.lvalid  $frmid.evalid  -sticky e -pady 2
    
    grid  $frmid.le  -sticky w

    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc Set] -default active \
      -command [list [namespace current]::Doit $w]
    ttk::button $frbot.btcancel -text [mc Cancel]   \
      -command [list [namespace current]::Cancel $w]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
    }
    pack $frbot -side top -fill x
    
    wm resizable $w 0 0
    ::UI::SetWindowPosition $w
    bind $w <Return> [list $frbot.btok invoke]
    
    # Grab and focus.
    set oldFocus [focus]
    focus $w
    catch {grab $w}
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w
    
    catch {grab release $w}
    catch {focus $oldFocus}
    return [expr {($finished <= 0) ? "cancel" : "set"}]
}

proc ::Jabber::Passwd::Close {w} {
    
    ::UI::SaveWinPrefixGeom $w
    return
}

proc ::Jabber::Passwd::Cancel {w} {
    variable finished
    
    set finished 0
    destroy $w
}

# Jabber::Passwd::Doit --
#
#       Initiates a register operation. Must be connected already!
#
# Arguments:
#       
# Results:
#       .

proc ::Jabber::Passwd::Doit {w} {
    global  errorCode prefs

    variable validate
    variable password
    variable finished
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    
    ::Debug 2 "::Jabber::Passwd::Doit"

    if {![string equal $validate $password]} {
	::UI::MessageBox -type ok -icon error -message [mc jamesspasswddiff]
	return
    }
    set finished 1
    regexp -- {^([^@]+)@.+$} $jstate(mejid) match username
    $jstate(jlib) register_set $username $password \
      [list [namespace current]::ResponseProc] -to $jserver(this)
    destroy $w

    # Just wait for a callback to the procedure.
}

proc ::Jabber::Passwd::ResponseProc {jlibName type theQuery} {    
    variable password
    upvar ::Jabber::jstate jstate

    if {[string equal $type "error"]} {
	set errcode [lindex $theQuery 0]
	set errmsg [lindex $theQuery 1]
	set msg 
	::UI::MessageBox -title [mc Error] -icon error -type ok \
	  -message [mc jamesspasswderr $errcode $errmsg]
    } else {
		
	# Make sure the new password is stored in our profiles.
	set name [::Profiles::FindProfileNameFromJID $jstate(mejid)]
	if {$name ne ""} {
	    ::Profiles::SetWithKey $name password $password
	}
	::UI::MessageBox -title [mc {New Password}] -icon info -type ok \
	  -message [mc jamesspasswdok]
    }
}

# Jabber::OnMenuLogInOut --
# 
#       Toggle login/logout. Menu and button bindings.

proc ::Jabber::OnMenuLogInOut { } {

    if {[llength [grab current]]} { return }

    switch -- [::JUI::GetConnectState] {
	connect - connectfin {
	    DoCloseClientConnection
	}
	connectinit {
	    ::Login::Reset
	}
	disconnect {
	    ::Login::Dlg
	}
    }    
}

# The ::Jabber::Logout:: namespace ---------------------------------------------

namespace eval ::Jabber::Logout:: { 

    option add *JLogout.connectImage             connect         widgetDefault
    option add *JLogout.connectDisImage          connectDis      widgetDefault
}

proc ::Jabber::Logout::OnMenuStatus { } {
    if {[llength [grab current]]} { return }
    if {[::JUI::GetConnectState] eq "connectfin"} {
	WithStatus
    }
}

proc ::Jabber::Logout::WithStatus { } {
    global  prefs this wDlgs

    variable finished -1
    variable wtextstatus
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate

    ::Debug 2 "::Jabber::Logout::WithStatus"

    set w $wDlgs(joutst)
    if {[winfo exists $w]} {
	raise $w
	return
    }
    
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox} -class JLogout \
      -closecommand [namespace current]::DoCancel
    wm title $w [mc {Logout With Message}]
    ::UI::SetWindowPosition $w

    set im   [::Theme::GetImage [option get $w connectImage {}]]
    set imd  [::Theme::GetImage [option get $w connectDisImage {}]]

    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1
    
    ttk::label $w.frall.head -style Headlabel \
      -text [mc Logout] -compound left \
      -image [list $im background $imd]
    pack $w.frall.head -side top -fill both -expand 1

    ttk::separator $w.frall.s -orient horizontal
    pack $w.frall.s -side top -fill x
    
    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    # Entries etc.
    set frmid $wbox.mid
    ttk::frame $frmid
    pack $frmid -side top -fill both -expand 1
    
    ttk::label $frmid.lstat -text "[mc Message]:" -anchor e
    text $frmid.estat -font TkDefaultFont \
      -width 36 -height 2 -wrap word
    
    grid  $frmid.lstat  $frmid.estat  -sticky ne -padx 2 -pady 4
    
    set wtextstatus $frmid.estat

    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc Logout]  \
      -default active -command [list [namespace current]::DoLogout $w]
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::DoCancel $w]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
    }
    pack $frbot -side top -fill x
    
    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btok invoke]
    
    # Grab and focus.
    set oldFocus [focus]
    focus $frmid.estat
    catch {grab $w}
    
    # Wait here for a button press and window to be destroyed.
    tkwait variable [namespace current]::finished
    
    # Clean up.
    catch {grab release $w}
    catch {focus $oldFocus}
    ::UI::SaveWinGeom $w
    destroy $w
    return [expr {($finished <= 0) ? "cancel" : "logout"}]
}

proc ::Jabber::Logout::DoCancel {w} {
    variable finished
    
    ::UI::SaveWinGeom $w
    set finished 0
}

proc ::Jabber::Logout::DoLogout {w} {
    variable finished
    variable wtextstatus
    
    set msg [string trimright [$wtextstatus get 1.0 end]]
    ::Jabber::DoCloseClientConnection -status $msg
    set finished 1
}

#-------------------------------------------------------------------------------
