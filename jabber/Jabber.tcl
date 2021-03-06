#  Jabber.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It is the main arganizer for all jabber application code.
#      
#  Copyright (c) 2001-2008  Mats Bengtsson
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
# $Id: Jabber.tcl,v 1.269 2008-08-04 13:05:28 matben Exp $

package require balloonhelp
package require chasearrows
package require http 2.3
package require sha1
package require tinyfileutils
package require uriencode

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
package require jlib::sipub
package require jlib::vcard

# All jlib scripts we may ever want.
package require jlibs::register
package require jlibs::unregister
package require jlibs::message

# Others depend upon this.
package require JUI

# We should have some component mechanism that lets packages load themselves.
package require Adhoc
package require AutoAway
package require AppStatusSlot
package require Avatar
package require AvatarMB
package require Chat
package require Create
package require Disco
package require Emoticons
package require FTrans
package require Gateway
package require GotMsg
package require GroupChat
package require JForms
package require JPrefs
package require JPubServers
package require JUser
package require Login
package require MailBox
package require MegaPresence
package require MicroBlog
package require MUC
package require NewMsg
package require Nickname
package require OOB
package require Privacy
package require Profiles
package require Register
package require Roster
package require Rosticons
package require Search
package require Servicons
package require Status
package require StatusSlot
package require Subscribe
package require UserInfo
package require VCard

package provide Jabber 1.0

namespace eval ::Jabber {
    global  this prefs
    
    # Add all event hooks.
    ::hooks::register quitAppHook        ::Jabber::EndSession
    ::hooks::register prefsInitHook      ::Jabber::InitPrefsHook

    # Jabber internal storage.
    variable jstate
    variable jserver
    variable jerror
    
    # Our own jid, and jid/resource respectively.
    set jstate(mejid)    ""
    set jstate(mejidres) ""
    set jstate(mejidmap) ""
    set jstate(meres)    ""
    set jstate(server)   ""
    
    set jstate(sock)  ""
    set jstate(ipNum) ""
    
    # Keep variables for our presence/show/status which are used in menus etc.
    set jstate(show) "unavailable"
    set jstate(status) ""
    set jstate(show+status) [list $jstate(show) $jstate(status)]
    
    # Server port actually used.
    set jstate(servPort) ""
            
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
    # NB: The caps XEP 1.4 introduces an incompatibility here and it is
    #     necessary to understand both versions!
    variable coccixmlns
    array set coccixmlns {
	caps            "http://coccinella.sourceforge.net/protocol/caps"
	caps14          "http://coccinella.sourceforge.net/"
	servers         "http://coccinella.sourceforge.net/protocol/servers"
	whiteboard      "http://coccinella.sourceforge.net/protocol/whiteboard"
    }
    
    # Standard jabber (xmpp + XEP) protocol namespaces.
    variable xmppxmlns
    array set xmppxmlns {
	amp             "http://jabber.org/protocol/amp"
	caps            "http://jabber.org/protocol/caps"
	chatstates      "http://jabber.org/protocol/chatstates"
	disco           "http://jabber.org/protocol/disco"
	disco,info      "http://jabber.org/protocol/disco#info"
	disco,items     "http://jabber.org/protocol/disco#items"
	file-transfer   "http://jabber.org/protocol/si/profile/file-transfer"
	ibb             "http://jabber.org/protocol/ibb"
	muc             "http://jabber.org/protocol/muc"
	muc,admin       "http://jabber.org/protocol/muc#admin"
	muc,owner       "http://jabber.org/protocol/muc#owner"
	muc,unique      "http://jabber.org/protocol/muc#unique"
	muc,user        "http://jabber.org/protocol/muc#user"
	oob             "jabber:iq:oob"
	si              "http://jabber.org/protocol/si"
    }
    
    # Standard xmlns supported. Components add their own.
    variable clientxmlns
    set clientxmlns {
	"jabber:client"
	"jabber:iq:last"
	"jabber:iq:time"
	"urn:xmpp:time"
	"jabber:iq:version"
	"jabber:x:event"
    }    
    lappend clientxmlns $coccixmlns(servers)
    
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
    
    # Dialogs with head label.
    set ::config(version,show-head) 1
    set ::config(logout,show-head)  1

    set ::config(subscribe,trpt-msgbox) 0
    
    # This is a method to show fake caps responses.
    set ::config(caps,fake) 0
    set ::config(caps,node) ""
    set ::config(caps,vers) ""
    
    # Method to fake jabber:iq.version response.
    set ::config(vers,full) ""
    
    # XEP-0092: Software Version; 
    # ...an application MUST provide a way for a human user or administrator to
    # disable sharing of information about the operating system. 
    set ::config(vers,show-os) 0
    
    if {0} {
	set ::config(caps,fake) 1
	set ::config(caps,node) "http://www.microsoft.com/msn"
	set ::config(caps,vers) "9.9"
	set ::config(vers,full) "9.9"
    }

    # the error messages stating connection problems will disappear after $errormessagetimeout
    variable errormessagetimeout 10000
}

# If the whiteboard/ complete dir is there we get whiteboard support.

namespace eval ::Jabber {
    variable haveWhiteboard 0    
}

proc ::Jabber::LoadWhiteboard {} {
    variable haveWhiteboard
    if {![catch {package require JWB}]} {
	set haveWhiteboard 1
    }
}

proc ::Jabber::HaveWhiteboard {} {
    variable haveWhiteboard
    return $haveWhiteboard
}

# Jabber::FactoryDefaults --
#
#       Makes reasonable default settings for a number of variables and
#       preferences.

proc ::Jabber::FactoryDefaults {} {
    global  this env prefs wDlgs sysFont jprefs
    
    variable jstate
    variable jserver
    
    # Network.
    set jprefs(port)    5222
    set jprefs(sslport) 5223
    set jprefs(usessl)  0
    
    # Protocol parts
    set jprefs(useSVGT) 0
    #set jprefs(useSVGT) 1
    
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
    
    set jstate(debugCmd) 0
    
    # Query these jabber servers for services. Login server is automatically
    # queried.
    set jprefs(browseServers) {}
    set jprefs(agentsServers) {}
        
    # New... Profiles. These are just leftovers that shall be removed later.
    set jserver(profile)  \
      {jabber.org {jabber.org myUsername myPassword home}}
    set jserver(profile,selected)  \
      [lindex $jserver(profile) 0]
    
    #
    set jprefs(urlServersList) "http://xmpp.org/services/services.xml"
        
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

proc ::Jabber::InitPrefsHook {} {
    global  jprefs
    variable jstate
    variable jserver
    
    # The profile stuff here is OUTDATED and replaced.

    ::PrefUtils::Add [list  \
      [list jprefs(port)             jprefs_port              $jprefs(port)]  \
      [list jprefs(sslport)          jprefs_sslport           $jprefs(sslport)]  \
      [list jprefs(agentsServers)    jprefs_agentsServers     $jprefs(agentsServers)]  \
      [list ::Jabber::jserver(profile)         jserver_profile          $jserver(profile)      userDefault] \
      [list ::Jabber::jserver(profile,selected) jserver_profile_selected $jserver(profile,selected) userDefault] \
      ]
}

# Jabber::GetjprefsArray, GetjserverArray, ... --
# 
#       Accesor functions for various preference arrays.

proc ::Jabber::GetjprefsArray {} {
    global jprefs
    return [array get jprefs]
}

proc ::Jabber::GetjserverArray {} {
    variable jserver
    return [array get jserver]
}

proc ::Jabber::SetjprefsArray {jprefsArrList} {
    global jprefs
    array set jprefs $jprefsArrList
}

proc ::Jabber::GetIQRegisterElements {} {
    global jprefs
    return $jprefs(iqRegisterElem)
}

proc ::Jabber::GetServerJid {} {
    variable jstate
    return $jstate(server)
}

proc ::Jabber::GetServerIpNum {} {
    variable jstate
    return $jstate(ipNum)
}

proc ::Jabber::GetMyJid {{roomjid {}}} {
    variable jstate

    set jid ""
    if {$roomjid eq ""} {
	set jid [::Jabber::Jlib myjid]
    } else {
	if {[$jstate(jlib) service isroom $roomjid]} {
	    set nick [$jstate(jlib) service mynick $roomjid]
	    set jid $roomjid/$nick
	}
    }
    return $jid
}

proc ::Jabber::GetMyStatus {} {
    variable jstate
    
    return $jstate(show)
    
    # Alternative: [$jstate(jlib) mypresence]
}

proc ::Jabber::IsConnected {} {
    variable jstate

    # @@@ Bad solution to fix p2p bugs.
    if {[info exists jstate(jlib)]} {
	return [$jstate(jlib) isinstream]
    } else {
	return 0
    }
}

proc ::Jabber::GetJlib {} {
    variable jstate
    return $jstate(jlib)
}

proc ::Jabber::Jlib {args} {
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

proc ::Jabber::Init {} {
    global  wDlgs prefs jprefs
    
    variable jstate
    variable coccixmlns
    variable xmppxmlns
    variable clientxmlns
    
    ::Debug 2 "::Jabber::Init"
        
    set opts [list]
    
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
    $jlibname iq_register get jabber:iq:version    [namespace code ParseGetVersion]
    $jlibname iq_register get $coccixmlns(servers) [namespace code ParseGetServers]
    
    # Register handlers for all four (un)subscribe(d) events.
    $jlibname presence_register subscribe    [namespace code SubscribeEvent]
    $jlibname presence_register subscribed   [namespace code SubscribedEvent]
    $jlibname presence_register unsubscribe  [namespace code UnsubscribeEvent]
    $jlibname presence_register unsubscribed [namespace code UnsubscribedEvent]
    
    foreach xmlns $clientxmlns {
	jlib::disco::registerfeature $xmlns
    }
    jlib::disco::registerfeature {jid\20escaping}
    $jlibname disco registeridentity client pc Coccinella
	
    ::JUI::Build $wDlgs(jmain)    
        
    # Stuff that need an instance of jabberlib register here.
    ::Debug 4 "--> jabberInitHook"
    ::hooks::run jabberInitHook $jlibname
    
    # Register extra presence elements.
    # NB: Must be after jabberInitHook since components may register their
    #     caps extensions there.
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
    if {$from eq ""} {
	# ??? return  check XMPP RFC
    }
    
    switch -- $type {
	error {
	    
	    # We must check if there is an error element sent along with the
	    # body element. In that case the body element shall not be processed.
	    set errspec [jlib::getstanzaerrorspec $xmldata]
	    if {[llength $errspec]} {
		set errcode [lindex $errspec 0]
		set errmsg  [lindex $errspec 1]		
		set str [mc "Cannot send message to %s." $from]
		append str "\n"
		append str [mc "Error code"]
		append str ": $errcode\n"
		append str [mc "Message"]
		append str ": $errmsg"	
		ui::dialog -title [mc "Error"] -message $str -icon error -type ok
		::Jabber::AddErrorLog $from $str
	    }
	}
	chat {
	    ::hooks::run newChatMessageHook $xmldata
	}
	groupchat {
	    ::hooks::run newGroupChatMessageHook $xmldata
	}
	headline {
	    ::hooks::run newHeadlineMessageHook $xmldata
	}
	default {
	    	    
	    # Add a unique identifier for each message which is handy for the mailbox.
	    set uuid [uuid::uuid generate]
	    
	    # Normal message. Handles whiteboard stuff as well.
	    ::hooks::run newMessageHook $xmldata $uuid
	}
    }
}

# Jabber::ExtractOptsFromXmldata --
# 
#       As an emergency to rescue the old style proc calls.

proc ::Jabber::ExtractOptsFromXmldata {xmldata} {
    
    set opts [list -xmldata $xmldata]
    
    foreach {name value} [wrapper::getattrlist $xmldata] {
	lappend opts -$name $value
    }
    set xElist [list]
    foreach E [wrapper::getchildren $xmldata] {
	set tag    [wrapper::gettag $E]
	set chdata [wrapper::getcdata $E]

	switch -- $tag {
	    subject - thread - body {
		lappend opts -$tag $chdata
	    }
	    x {
		lappend xElist $E
	    }
	    default {
		lappend opts -$tag $E
	    }
	}	
    }    
    if {[llength $xElist]} {
	lappend opts -x $xElist
    }
    return $opts
}

# Jabber::(Un)Subscribe(d)Event --
# 
#       Registered handlers for these presence event types.
#       Note that XMPP IM requires all 'from' attributes to be bare JIDs.

proc ::Jabber::SubscribeEvent {jlibname xmldata} {
    global  config jprefs
    variable jstate
    
    set jlib [::Jabber::GetJlib]
    
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
	if {$config(subscribe,trpt-msgbox)} {
	    set subtype [lindex [split $jidtype /] 1]
	    set typename [::Roster::GetNameFromTrpt $subtype]
	    ::ui::dialog -title [mc "Info"] -icon info -type ok \
	      -message [mc "Your registered account with the %s service will be put in your list of contacts to work as a transport with this service." $typename]
	}
    } else {
	
	# Another user request to subscribe to our presence.
	# Figure out what the user's prefs are.
	if {[$jlib roster isitem $jid2]} {
	    set key inrost
	} else {
	    set key notinrost
	}		
	
	# Accept, deny, or ask depending on preferences we've set.
	
	switch -- $jprefs(subsc,$key) {
	    accept {
		::SubscribeAuto::HandleAccept $from
	    }
	    reject {
		::SubscribeAuto::HandleReject $from
	    }
	    ask {
		::Subscribe::HandleAsk $from
	    }
	}
    }
    return 1
}

proc ::Jabber::SubscribedEvent {jlibname xmldata} {
    
    set from [wrapper::getattribute $xmldata from]    
    if {![::Roster::IsTransportHeuristics $from]} {
	::Subscribed::Handle $from
    }
    return 1
}

proc ::Jabber::UnsubscribeEvent {jlibname xmldata} {
    global jprefs
    variable jstate
    
    set jlib [::Jabber::GetJlib]

    set from [wrapper::getattribute $xmldata from]    
    set subscription [$jlib roster getsubscription $from]

    if {$jprefs(rost,rmIfUnsub)} {
	
	# Remove completely from our roster.
	$jlib roster send_remove $from
	::ui::dialog -title [mc "Presence Subscription"] \
	  -icon info -type ok -message [mc "Because %s does not allow you to see his/her presence anymore, he/she is removed." $from]
    } else {
	
	$jlib send_presence -to $from -type "unsubscribed"
	::ui::dialog -title [mc "Presence Subscription"] -icon info -type ok \
	  -message [mc "%s does not allow you to see his/her presence anymore." $from]	

	# If there is any subscription to this jid's presence.
	if {$subscription eq "both" || $subscription eq "to"} {
	    
	    set ans [::UI::MessageBox -title [mc "Presence Subscription"] \
	      -icon question -type yesno -default yes \
	      -message [mc "%s does not allow you to see his/her presence anymore. Do you want to remove %s?" $from $from]]
	    if {$ans eq "yes"} {
		$jlib roster send_remove $from
	    }
	}
    }
    return 1
}

# Jabber::UnsubscribedEvent --
# 
#       RFC 3921: "unsubscribed -- The subscription request has been denied or a
#                 previously-granted subscription has been cancelled."

proc ::Jabber::UnsubscribedEvent {jlibname xmldata} {
    global  jprefs
    variable jstate
    
    set jlib [::Jabber::GetJlib]

    set from [wrapper::getattribute $xmldata from]    
    set subscription [$jlib roster getsubscription $from]
    
    # If we fail to subscribe someone due to a technical reason we
    # have subscription='none'
    # NB: If the other user removes us from its roster we also get a presence
    #     'unsubscribed'. 

    if {$subscription eq "none"} {
	set ask [$jlib roster getask $from]
	
	# This is never the case. Don't know how to differentiate the two cases?
	if {$ask eq "subscribe"} {
	    set msg [mc "Cannot subscribe to %s's presence. The contact does not allow you to see his/her presence." $from]
	    set status [$jlib roster getstatus $from]
	    if {$status ne ""} {
		append msg " " $status
	    }
	    ::ui::dialog -title [mc "Subscription Failed"] \
	      -icon info -type ok -message $msg
	}
	if {$jprefs(rost,rmIfUnsub)} {
	    
	    # Remove completely from our roster.
	    $jlib roster send_remove $from
	}
    } else {		
	::ui::dialog -title [mc "Presence Subscription"] -icon info -type ok \
	  -message [mc "You cannot see %s's presence anymore." $from]
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
	    set msg [mc "Presence Error"].
	    append msg "\n"
	    append msg [mc "Error code"]
	    append msg ": $errcode\n"
	    append msg [mc "Message"]
	    append msg ": $errmsg"

	    if {$::config(talkative)} {
		::ui::dialog -icon error -type ok  \
		  -title [mc "Error"] -message $msg
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
    global  wDlgs jprefs
    
    variable jstate
    variable errormessagetimeout
    
    ::Debug 2 "::Jabber::ClientProc: jlibName=$jlibName, what=$what, args='$args'"
    
    # For each 'what', split the argument list into the proper arguments,
    # and make the necessary calls.
    array set argsA $args
    set ishandled 0
    
    switch -glob -- $what {
	disconnect {	    
	    
	    # This is as a response to a </stream> element.
	    # If we close the socket and don't wait for the close element
	    # we never end up here.
	    
	    # Disconnect. This should reset both wrapper and XML parser!
	    #::Jabber::DoCloseClientConnection
	    SetClosedState
	    # Added the arbitrary -timeout argument, necessary
	    # to allow the start of ::Login::AutoReLogin mechanism.
	    ui::dialog -icon error -title [mc "Error"] -type ok -timeout $errormessagetimeout \
	      -message [mc "The connection was unexpectedly broken."]
	}
	streamerror - xmpp-streams-error* {
	    DoCloseClientConnection
	    if {[info exists argsA(-errormsg)]} {
		set msg [mc "Received a fatal error: %s The connection is closed." "$argsA(-errormsg)\n"]
	    } else {
		set msg [mc "Received a fatal error: %s The connection is closed." ""]
	    }
	    ui::dialog -title [mc "Error"] -icon error -type ok -timeout $errormessagetimeout -message $msg
	}
	xmlerror {
	    
	    # XML parsing error.
	    # Disconnect. This should reset both wrapper and XML parser!
	    DoCloseClientConnection
	    if {[info exists argsA(-errormsg)]} {
		set msg [mc "Received a fatal error: %s The connection is closed." "$argsA(-errormsg)\n"]
	    } else {
		set msg [mc "Received a fatal error: %s The connection is closed." ""]
	    }
	    # Added the arbitrary -timeout argument, necessary
	    # to allow the start of ::Login::AutoReLogin mechanism.
	    ui::dialog -title [mc "Error"] -icon error -type ok -timeout $errormessagetimeout -message $msg
	}
	networkerror {
	    
	    # Disconnect. This should reset both wrapper and XML parser!
	    #::Jabber::DoCloseClientConnection
	    SetReconnectState
	    set msg [mc "The connection was unexpectedly broken."]
	    if {[info exists argsA(-errormsg)]} {
		append msg "\n"
		append msg $argsA(-errormsg)
	    }
	    # Added the arbitrary -timeout argument, necessary
	    # to allow the start of ::Login::AutoReLogin mechanism.
	    ui::dialog -icon error -title [mc "Error"] -type ok -timeout $errormessagetimeout -message $msg
	}
    }
    # start the automatic relogin procedure
    ::Login::AutoReLogin
    return $ishandled
}

# Jabber::DebugCmd --
#
#       Hides or shows console on mac and windows, sets debug for XML I/O.

proc ::Jabber::DebugCmd {} {
    global  this
    
    variable jstate
    
    switch -- $this(platform) windows - macosx {
	if {$jstate(debugCmd)} {
	    catch {
		console show
		console title "Coccinella Console"
	    }
	    jlib::setdebug 2
	} else {
	    catch {console hide}
	    jlib::setdebug 0
	}
    }
}

proc ::Jabber::AddErrorLog {jid msg} {    
    variable jerror
    
    set tm [clock format [clock seconds] -format "%H:%M:%S"]
    lappend jerror [list $tm $jid $msg]
}

# Jabber::ErrorLogDlg

proc ::Jabber::ErrorLogDlg {} {
    global  this wDlgs
    
    variable jerror

    set w $wDlgs(jerrdlg)
    if {[winfo exists $w]} {
	raise $w
	return
    }
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc
    wm title $w [mc "Error Log (noncriticals)"]
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1
    
    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc "Cancel"] -command [list destroy $w]
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
    global  prefs jprefs
        
    variable jstate
    
    ::Debug 2 "::Jabber::DoCloseClientConnection"
    
    array set argsA $args
    
    # Send unavailable information.
    if {[::Jabber::Jlib isinstream]} {
	set opts [list]
	if {[info exists argsA(-status)] && [string length $argsA(-status)]} {
	    lappend opts -status $argsA(-status)
	}
	eval {::Jabber::Jlib send_presence -type unavailable} $opts

	eval {::hooks::run setPresenceHook unavailable} $opts

	# Do the actual closing.
	#       There is a potential problem if called from within a xml parser 
	#       callback which makes the subsequent parsing to fail. (after idle?)
	after idle ::Jabber::Jlib closestream
    }
    SetClosedState
}

# Jabber::SetClosedState --
# 
#       Sets the application closed connection state.
#       Called either when doing a controlled close connection,
#       or as a result of any exception.
#       Doesn't do any network transactions.

proc ::Jabber::SetClosedState {} {
    variable jstate
    ::Debug 2 "::Jabber::SetClosedState"

    # Ourself.
    set jstate(mejid)    ""
    set jstate(meres)    ""
    set jstate(mejidres) ""
    set jstate(mejidmap) ""
    set jstate(server)   ""
    set jstate(show)     "unavailable"
    set jstate(status)   ""
    set jstate(show+status) [list $jstate(show) $jstate(status)]
    set jstate(ipNum)    ""
    
    # Run all logout hooks.
    ::hooks::run logoutHook
}

proc ::Jabber::SetReconnectState {} {
    SetClosedState
    ::JUI::SetConnectState "reconnecting"
}

# Jabber::EndSession --
#
#       This is supposed to be called only when doing Quit.
#       Things are not cleaned up properly, since we kill ourselves.

proc ::Jabber::EndSession {} {  
    global  jprefs
    
    # Send unavailable information. Silently in case we got a network error.
    if {[::Jabber::Jlib isinstream]} {
	catch {
	    ::Jabber::Jlib send_presence -type unavailable
	}
	
	# Do the actual closing.
	#       There is a potential problem if called from within a xml parser 
	#       callback which makes the subsequent parsing to fail. (after idle?)
	::Jabber::Jlib closestream
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

proc ::Jabber::ValidateUsernameStrEsc {str} {    
    if {[catch {jlib::nodeprep [jlib::escapestr $str]} err]} {
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
    
    set room [jlib::barejid $jid]
    set nick [::Jabber::Jlib service mynick $room]
    set myjid $room/$nick
    return [jlib::jidequal $myjid $jid]
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
    global  jprefs
    variable jstate
    
    ::Debug 4 "::Jabber::SetStatus type=$type, args=$args"
    
    # We protect against accidental calls. (logoutHook)
    if {![::Jabber::Jlib isinstream]} {
	return
    }
    array set argsA {
	-notype         0
    }
    
    # Any -status take precedence, even if empty.
    array set argsA $args
    
    set presA [list]
    foreach {key value} [array get argsA] {
	
	switch -- $key {
	    -to - -priority - -status - -xlist - -extras {
		lappend presA $key $value
	    }
	}
    }
    if {!$argsA(-notype)} {
	
	switch -- $type {
	    available {
		# empty
	    }
	    invisible - unavailable {
		lappend presA -type $type
	    }
	    away - dnd - xa - chat {
		# Seems Psi gets confused by this.
		#lappend presA -type "available" -show $type
		lappend presA -show $type
	    }
	}	
    }
    
    # General presence should not have a 'to' attribute.
    if {![info exists argsA(-to)]} {
	set status ""
	if {[info exists argsA(-status)] && [string length $argsA(-status)]} {
	    set status $argsA(-status)
	}
	
	# These can be traced for UI parts.
	set jstate(show) $type
	set jstate(status) $status
	set jstate(show+status) [list $type $status]
    }
    
    # It is somewhat unclear here if we should have a type attribute
    # when sending initial presence, see XMPP 5.1.
    eval {::Jabber::Jlib send_presence} $presA
	
    eval {::hooks::run setPresenceHook $type} $args
    
    # Do we target a room or the server itself?
    set toServer 0
    if {[info exists argsA(-to)]} {
	if {[jlib::jidequal $jstate(server) $argsA(-to)]} {
	    set toServer 1
	}
    } else {
	set toServer 1
    }
    if {$toServer && ($type eq "unavailable")} {
	after idle ::Jabber::Jlib closestream	    
	SetClosedState
    }
}

# Jabber::SyncStatus --
# 
#       Synchronize the presence we have. 
#       This is useful if we happen to change a custom presence x element,
#       for instance, our phone status.

proc ::Jabber::SyncStatus {} {
    variable jstate
    
    # We need to add -status to preserve it.
    SetStatus [::Jabber::Jlib mypresence] -status [::Jabber::Jlib mypresencestatus]
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

proc ::Jabber::CreateCoccinellaPresElement {} {
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

# Jabber::CreateCoccinellaDiscoExt --
# 
#       Better is to supply an extension to disoc info accoring to:
#       XEP-0128: Service Discovery Extensions
#       
#       <x xmlns='jabber:x:data' type='result'>
#           <field var='FORM_TYPE' type='hidden'>
#               <value>http://coccinella.sourceforge.net/protocol/servers</value>
#           </field>
#           <field var='putget_port'>
#               <value>8235</value>
#           </field>
#           <field var='http_port'>
#               <value>8077</value>
#           </field>
#           <field var='ip'>
#               <value>192.168.0.5</value>
#           </field>
#       </x>

proc ::Jabber::CreateCoccinellaDiscoExt {} {
    global  prefs this
    variable coccixmlns
    
    set ip [::Network::GetThisPublicIP]
    set fieldEs [list]
    
    set valueE [wrapper::createtag "value" -chdata $coccixmlns(servers)]
    lappend fieldEs [wrapper::createtag "field" \
      -attrlist [list var FORM_TYPE type hidden] -subtags [list $valueE]]
    
    # Wrap up ip and ports:
    set spec [list  \
      putget_port  $prefs(thisServPort) \
      http_port    $prefs(httpdPort)    \
      ip           $ip]
    
    foreach {var value} $spec {
	set valueE [wrapper::createtag "value" -chdata $value]
	lappend fieldEs [wrapper::createtag "field" \
	  -attrlist [list var $var] -subtags [list $valueE]]
    }
    
    set xmllist [wrapper::createtag x -subtags $fieldEs \
      -attrlist [list xmlns "jabber:x:data" type "result"]]

    return $xmllist
}

# Jabber::CreateCapsPresElement --
# 
#       Used when sending inital presence. This way clients get various info.
#       See [XEP 0115]
#       Note that this doesn't replace the 'coccinella' element since caps
#       are not instance specific (can't send ip addresses).

proc ::Jabber::CreateCapsPresElement {} {
    global  this config
    variable coccixmlns
    variable xmppxmlns

    if {$config(caps,fake)} {
	set node $config(caps,node)
	set vers $config(caps,vers)
    } else {
	set node $coccixmlns(caps)
	set vers $this(vers,full)
    }
    set exts [Jlib caps getexts]
    set ver  [Jlib caps generate_ver]
    # Mandatory element in XEP-0115 version 1.5
    set hash "sha-1"
    # Need to switch to "$node#$vers" some time
    set xmllist [wrapper::createtag c -attrlist \
      [list xmlns $xmppxmlns(caps) hash $hash node $node ver $ver ext $exts]]

    return $xmllist
}
    
# Jabber::GetAnyDelayElem --
#
#       Takes a list of x-elements, finds any 'jabber:x:delay' x-element.
#       If no such element it returns empty.
#       
# Arguments:
#       xlist       Must be an xml list of <x> elements.  
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
    ::Jabber::Jlib get_last $to [list ::Jabber::GetLastResult $to $opts(-silent)]
}

# Jabber::GetLastResult --
#
#       Callback for '::Jabber::GetLast'.

proc ::Jabber::GetLastResult {from silent jlibname type subiq} {    

    set ujid [jlib::unescapejid $from]
    if {[string equal $type "error"]} {
	set msg [mc "Cannot query %s's last activity." $ujid]
	append msg "\n"
	append msg [mc "Error"]
	append msg ": [lindex $subiq 1]"
	::Jabber::AddErrorLog $from $msg	    
	if {!$silent} {
	    ::ui::dialog -title [mc "Error"] -icon error -type ok \
	      -message $msg
	}
    } else {
	array set attrArr [wrapper::getattrlist $subiq]
	if {![info exists attrArr(seconds)]} {
	    ::ui::dialog -title [mc "Last Activity"] -icon info  \
	      -type ok -message [mc "Cannot query %s's local time information." $ujid]
	} else {
	    ::ui::dialog -title [mc "Last Activity"] -icon info  \
	      -type ok -message [GetLastString $from $subiq]
	}
    }
}

proc ::Jabber::GetLastString {jid subiq} {
    
    set ujid [jlib::unescapejid $jid]
    array set attrArr [wrapper::getattrlist $subiq]
    if {![info exists attrArr(seconds)]} {
	set str [mc "Cannot query %s's local time information." $ujid]
    } elseif {![string is integer -strict $attrArr(seconds)]} {
	set str [mc "Cannot query %s's local time information." $ujid]
    } else {
	set secs [expr {[clock seconds] - $attrArr(seconds)}]
	set uptime [clock format $secs -format "%a %b %d %H:%M:%S %Y"]
	if {[wrapper::getcdata $subiq] ne ""} {
	    set msg [mc "Message"]
	    append msg ": [wrapper::getcdata $subiq]"
	} else {
	    set msg ""
	}
	
	# Time interpreted differently for different jid types.
	if {$jid ne ""} {
	    if {[regexp {^[^@]+@[^/]+/.*$} $jid match]} {
		set msg1 [mc "Time since client %s was last active" $ujid]
	    } elseif {[regexp {^.+@[^/]+$} $jid match]} {
		set msg1 [mc "Time since %s was last connected" $ujid]
	    } else {
		set msg1 [mc "Time since server %s was started" $ujid]
	    }
	} else {
	    set msg1 [mc "The uptime/last activity is"]:
	}
	set str " ${msg1}: $uptime. $msg"
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
    ::Jabber::Jlib get_time $to [list ::Jabber::GetTimeResult $to $opts(-silent)]
}

proc ::Jabber::GetTimeResult {from silent jlibname type subiq} {

    set ujid [jlib::unescapejid $from]
    if {[string equal $type "error"]} {
	::Jabber::AddErrorLog $from  \
	  "We received an error when quering its time info.\
	  The error was: [lindex $subiq 1]"	    
	if {!$silent} {
	    set str [mc "Cannot query %s's local time." $ujid]
	    append str "\n"
	    append str [mc "Error"]
	    append str ": [lindex $subiq 1]"
	    ::ui::dialog -title [mc "Error"] -icon error -type ok -message $str
	}
    } else {
	set msg [GetTimeString $subiq]
	::ui::dialog -title [mc "Local Time"] -icon info -type ok \
	  -message [mc "%s's local time is: %s" $ujid $msg]
    }
}

proc ::Jabber::GetTimeString {subiq} {
    
    # Display the cdata of <display>, or <utc>.
    foreach child [wrapper::getchildren $subiq] {
	set tag  [wrapper::gettag $child]
	set $tag [wrapper::getcdata $child]
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

proc ::Jabber::GetEntityTimeString {timeE} {
    
    foreach child [wrapper::getchildren $timeE] {
	set tag  [wrapper::gettag $child]
	set $tag [wrapper::getcdata $child]
    }
    if {![info exists tzo] || ![info exists utc]} {
	return ""
    }
    set msg ""
    
    # NB: 'clock scan' can't be applied directly due to the time zone suffix!
    # Typical values:  01:00  -06:00 etc.
    if {[regexp {(^.+[0-9])([^0-9]*)$} $utc - utc1 utc2]} {
	
	# NB; I get 5 hours diff here compared to original value
	# if using 'clock scan' directly on utc1! Skip the "T".
	regsub {T} $utc1 { } utc1
	if {[catch {clock scan $utc1 -timezone :UTC} secs]} {
	    return ""
	}

	# Remove leading zeros since they will be interpreted as octals.
	regsub -all {0?([0-9])} $tzo {\1} tzo
	lassign [split $tzo :] hours minutes
	set sign [expr {$hours/abs($hours)}]
	set hours [expr {abs($hours)}]
	set offset [expr {$sign*60*($minutes + 60*$hours)}]
	incr secs $offset
	set msg [clock format $secs -format "%c" -timezone :UTC]
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
    ::Jabber::Jlib get_version $to  \
      [list ::Jabber::GetVersionResult $to $opts(-silent)]
}

proc ::Jabber::GetVersionResult {from silent jlibname type subiq} {
    global  prefs this config
    
    variable uidvers
    
    set ujid [jlib::unescapejid $from]
    if {[string equal $type "error"]} {
	set str [mc "Cannot query %s's version." $ujid]
	append str "\n"
	append str [mc "Error"]
	append str ": [lindex $subiq 1]"
	::Jabber::AddErrorLog $from $str
	if {!$silent} {
	    ::ui::dialog -title [mc "Error"] -icon error -type ok -message $str
	}
	return
    }
    
    set w .jvers[incr uidvers]
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox}
    wm title $w [mc "Version"]

    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1
    
    if {$config(version,show-head)} {
	set im  [::Theme::FindIconSize 32 dialog-information]
	set imd [::Theme::FindIconSize 32 dialog-information-Dis]

	ttk::label $w.frall.head -style Headlabel \
	  -text [mc "Version"] -compound left \
	  -image [list $im background $imd]
	pack $w.frall.head -side top -anchor w
	
	ttk::separator $w.frall.s -orient horizontal
	pack $w.frall.s -side top -fill x
    }
    
    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1
    
    ttk::label $wbox.msg  \
      -padding {0 0 0 6} -wraplength 300 -justify left \
      -text [mc "Version information for %s." $from]
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
    ttk::button $frbot.btok -text [mc "OK"] -command [list destroy $w]
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
    global  prefs tcl_platform this config
    variable jstate
    
    ::Debug 2 "Jabber::ParseGetVersion args='$args'"
    
    array set argsA $args
    
    # Return any id!
    set opts [list]
    if {[info exists argsA(-id)]} {
	set opts [list -id $argsA(-id)]
    }
    lappend opts -to $from
   
    if {$config(vers,full) eq ""} {
	set version $this(vers,full)
    } else {
	set version $config(vers,full)
    }
    set subtags [list  \
      [wrapper::createtag name    -chdata $prefs(appName)]  \
      [wrapper::createtag version -chdata $version]]
    if {$config(vers,show-os)} {
	set os $tcl_platform(os)
	if {[info exists tcl_platform(osVersion)]} {
	    append os " $tcl_platform(osVersion)"
	}
	lappend subtags [wrapper::createtag os -chdata $os]
    }
    set xmllist [wrapper::createtag query -subtags $subtags  \
      -attrlist {xmlns jabber:iq:version}]
    eval {::Jabber::Jlib send_iq "result" [list $xmllist]} $opts

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
    
    array set argsA $args
    
    # Return any id!
    set opts {}
    if {[info exists argsA(-id)]} {
	set opts [list -id $argsA(-id)]
    }
    lappend opts -to $from
    
    set attrputget [list protocol putget port $prefs(thisServPort)]
    set attrhttpd  [list protocol http port $prefs(httpdPort)]
    set subtags [list  \
      [wrapper::createtag ip -chdata $ip -attrlist $attrputget]  \
      [wrapper::createtag ip -chdata $ip -attrlist $attrhttpd]]
    set xmllist [wrapper::createtag query -subtags $subtags  \
      -attrlist [list xmlns $coccixmlns(servers)]]
    eval {::Jabber::Jlib send_iq "result" [list $xmllist]} $opts
    
     # Tell jlib's iq-handler that we handled the event.
    return 1
}

# The ::Jabber::Passwd:: namespace -------------------------------------------

namespace eval ::Jabber::Passwd:: {

    variable password
}

proc ::Jabber::Passwd::OnMenu {} {
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
#       none

proc ::Jabber::Passwd::Build {} {
    global  this wDlgs
    
    variable finished -1
    variable password
    variable validate
    upvar ::Jabber::jstate jstate
    
    set password ""
    set validate ""

    set w $wDlgs(jpasswd)

    # Singleton.
    if {[winfo exists $w]} {
	raise $w
	return
    }
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox} \
      -closecommand [namespace current]::Close
    wm title $w [mc "New Password"]
    
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

    set myjid2 [::Jabber::Jlib myjid2]

    ttk::label $frmid.ll -text [mc "Set a new password for"]
    ttk::label $frmid.le -text $myjid2
    ttk::label $frmid.lserv -text [mc "New password"]: -anchor e
    ttk::entry $frmid.eserv -width 18 -show *  \
      -textvariable [namespace current]::password -validate key  \
      -validatecommand {::Jabber::ValidatePasswordStr %S}
    ttk::label $frmid.lvalid -text [mc "Retype password"]: -anchor e
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
    ttk::button $frbot.btok -text [mc "Save"] -default active \
      -command [list [namespace current]::Doit $w]
    ttk::button $frbot.btcancel -text [mc "Cancel"]   \
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
}

proc ::Jabber::Passwd::Close {w} {
    
    ::UI::SaveWinPrefixGeom $w
    return
}

proc ::Jabber::Passwd::Cancel {w} {
    
    ::UI::SaveWinPrefixGeom $w
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
    
    ::Debug 2 "::Jabber::Passwd::Doit"

    if {![string equal $validate $password]} {
	::ui::dialog -type ok -icon error -title [mc "Error"] \
	  -message [mc "Passwords do not match. Please try again."]
	return
    }
    set finished 1
    
    set myjid2 [::Jabber::Jlib myjid2]
    set server [::Jabber::Jlib getserver]
    jlib::splitjidex $myjid2 username - -
    
    ::Jabber::Jlib register_set $username $password \
      [list [namespace current]::ResponseProc] -to $server
    destroy $w

    # Just wait for a callback to the procedure.
}

proc ::Jabber::Passwd::ResponseProc {jlibName type theQuery} {    
    variable password
    upvar ::Jabber::jstate jstate

    if {[string equal $type "error"]} {
	set errcode [lindex $theQuery 0]
	set errmsg [lindex $theQuery 1]
	
	set str [mc "Cannot set new password."]
	append str "\n"
	append str [mc "Error code"]
	append str ": $errcode\n"
	append str [mc "Message"]
	append str ": $errmsg\n"
	::ui::dialog -title [mc "Error"] -icon error -type ok -message $str
    } else {
		
	# Make sure the new password is stored in our profiles.
	set myjid2 [::Jabber::Jlib myjid2]
	set name [::Profiles::FindProfileNameFromJID $myjid2]
	if {$name ne ""} {
	    ::Profiles::SetWithKey $name password $password
	}
	::ui::dialog -title [mc "New Password"] -icon info -type ok \
	  -message [mc "Setting new password was successful."]
    }
}

# Jabber::OnMenuLogInOut --
# 
#       Toggle login/logout. Menu and button bindings.

proc ::Jabber::OnMenuLogInOut {} {

    if {[llength [grab current]]} { return }

    switch -- [::JUI::GetConnectState] {
	connect - connectfin {
	    DoCloseClientConnection
	}
	connectinit - reconnecting {
	    ::Login::Reset
	}
	disconnect {
	    if {![llength [ui::findallwithclass JProfiles]]} {
		::Login::Dlg
	    }
	}
    }  
}

# The ::Jabber::Logout:: namespace ---------------------------------------------

namespace eval ::Jabber::Logout:: { 

    option add *JLogout.connectImage      network-disconnect      widgetDefault
    option add *JLogout.connectDisImage   network-disconnect-Dis  widgetDefault
}

proc ::Jabber::Logout::OnMenuStatus {} {
    if {[llength [grab current]]} { return }
    if {[::JUI::GetConnectState] eq "connectfin"} {
	WithStatus
    }
}

proc ::Jabber::Logout::WithStatus {} {
    global  prefs this wDlgs config jprefs

    variable finished -1
    variable wtextstatus
    upvar ::Jabber::jstate jstate

    ::Debug 2 "::Jabber::Logout::WithStatus"

    # Singleton.
    set w $wDlgs(joutst)
    if {[winfo exists $w]} {
	raise $w
	return
    }
    
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox} -class JLogout \
      -closecommand [namespace current]::DoCancel
    wm title $w [mc "Logout With Message"]
    ::UI::SetWindowPosition $w

    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1
    
    if {$config(logout,show-head)} {
	set im   [::Theme::Find32Icon $w connectImage]
	set imd  [::Theme::Find32Icon $w connectDisImage]

	ttk::label $w.frall.head -style Headlabel \
	  -text [mc "Logout With Message"] -compound left \
	  -image [list $im background $imd]
	pack $w.frall.head -side top -fill both -expand 1
	
	ttk::separator $w.frall.s -orient horizontal
	pack $w.frall.s -side top -fill x
    }
    
    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    # Entries etc.
    set frmid $wbox.mid
    ttk::frame $frmid
    pack $frmid -side top -fill both -expand 1
    
    ttk::label $frmid.lstat -text [mc "Message"]: -anchor e
    text $frmid.estat -font TkDefaultFont \
      -width 36 -height 2 -wrap word
    
    grid  $frmid.lstat  $frmid.estat  -sticky ne -padx 2 -pady 4
    
    set wtextstatus $frmid.estat

    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc "Logout"]  \
      -default active -command [list [namespace current]::DoLogout $w]
    ttk::button $frbot.btcancel -text [mc "Cancel"]  \
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
    focus $frmid.estat

    return $w
}

proc ::Jabber::Logout::DoCancel {w} {
    ::UI::SaveWinGeom $w
    destroy $w
}

proc ::Jabber::Logout::DoLogout {w} {
    variable finished
    variable wtextstatus
    
    ::UI::SaveWinGeom $w
    set msg [string trimright [$wtextstatus get 1.0 end]]
    ::Jabber::DoCloseClientConnection -status $msg
    destroy $w
}

#-------------------------------------------------------------------------------
