#  Jabber.tcl ---
#  
#      This file is part of the whiteboard application. 
#      It implements the "glue" between the whiteboard and jabberlib.
#      
#  Copyright (c) 2001-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#
# $Id: Jabber.tcl,v 1.8 2003-03-01 14:19:02 matben Exp $
#
#  The $address is an ip name or number.
#
#  jserver(all)               list of all profiles in array
#  jserver(profile,selected)  profile picked in user info
#  jserver(this)              present connected $address
#  jserver(profile):          {$profile1 {$server1 $username $password $resource} \
#                              $profile2 {$server2 $username2 $password2 $resource2} ... }

package provide Jabber 1.0

package require tree
package require jlib
package require roster
package require browse
package require chasearrows
package require http 2.3
package require balloonhelp
package require tablelist
package require mactabnotebook
package require combobox
package require tinyfileutils
package require uriencode
package require JForms
package require MailBox
package require NewMsg
package require GotMsg
package require OOB
package require Chat

namespace eval ::Jabber:: {
    global  this
    
    # Jabber internal storage.
    variable jstate
    variable jprefs
    variable jserver
    variable jerror
        
    # The trees 'directories' which should always be there.
    set jprefs(treedirs) {Online Offline {Subscription Pending}}
    set jprefs(closedtreedirs) {}
    
    # Our own jid, and jid/resource respectively.
    set jstate(mejid) {}
    set jstate(mejidres) {}
    
    #set jstate(alljid) {}   not implemented yet...
    set jstate(sock) {}
    set jstate(ipNum) {}
    set jstate(inroster) 0
    set jstate(status) "unavailable"
    
    # Server port actually used.
    set jstate(servPort) {}
    set jstate(debug) 0

    # Login server.
    set jserver(this) {}

    # Regexp pattern for username etc. Ascii no. 0-32 (deci) not allowed.
    set jprefs(invalsExp) {.*([\x00-\x20]|[\r\n\t@:' <>&"/])+.*}
    set jprefs(valids) {[^\x00-\x20]|[^\r\n\t@:' <>&"]}
    
    # Other hardcoded jabber prefs.
    set jprefs(useXMLNamespace) 1
    
    # List all iq:register personal info elements.
    set jprefs(iqRegisterElem)   \
      {first last nick email address city state phone url}
    
    # Popup menus.
    set jstate(wpopup,roster) .jpopupro
    set jstate(wpopup,browse) .jpopupbr
    set jstate(wpopup,groupchat) .jpopupgc
    set jstate(wpopup,agents) .jpopupag
    
    # Keep noncritical error text here.
    set jerror {}
    
    # Get/put ip numbers.
    variable getid 1001
    # Records any callback procs, index from 'getid'.
    variable getcmd
    
    # Array that maps 'jid' to its ip number.
    variable jidToIP
    
    # Array that acts as a data base for the public storage on the server.
    # Typically: jidPublic(matben@athlon.se,home,serverport).
    # Not used for the moment.
    variable jidPublic
    set jidPublic(haveit) 0
    
    # Mappings from <show> element to displayable text and vice versa.
    # chat away xa dnd
    variable mapShowElemToText
    variable mapShowTextToElem
    
    array set mapShowElemToText  \
      [list [::msgcat::mc mAvailable] available  \
      [::msgcat::mc mAway]            away       \
      [::msgcat::mc mDoNotDisturb]    dnd        \
      [::msgcat::mc mExtendedAway]    xa         \
      [::msgcat::mc mInvisible]       invisible  \
      [::msgcat::mc mNotAvailable]    unavailable]
    array set mapShowTextToElem  \
      [list available [::msgcat::mc mAvailable]     \
      away            [::msgcat::mc mAway]          \
      dnd             [::msgcat::mc mDoNotDisturb]  \
      xa              [::msgcat::mc mExtendedAway]  \
      invisible       [::msgcat::mc mInvisible]     \
      unavailable     [::msgcat::mc mNotAvailable]]

    # Mapping from presence/show to icon. Specials for whiteboard clients.
    variable gShowIcon
    array set gShowIcon [list                   \
      {available}       $::tree::machead        \
      {unavailable}     $::tree::macheadgray    \
      {chat}            $::tree::macheadtalk    \
      {away}            $::tree::macheadaway    \
      {xa}              $::tree::macheadunav    \
      {dnd}             $::tree::macheadsleep   \
      {invisible}       $::tree::macheadinv     \
      {subnone}         $::tree::questmark      \
      {available,wb}    $::tree::macheadwb      \
      {unavailable,wb}  $::tree::macheadgraywb  \
      {chat,wb}         $::tree::macheadtalkwb  \
      {away,wb}         $::tree::macheadawaywb  \
      {xa,wb}           $::tree::macheadunavwb  \
      {dnd,wb}          $::tree::macheadsleepwb \
      {invisible,wb}    $::tree::macheadinvwb   \
      {subnone,wb}      $::tree::questmarkwb    \
      ]
        
    # Arry that maps namespace (ns) to a descriptive name.
    variable nsToText
    array set nsToText {
      jabber:iq:agent              {Server component properties}
      jabber:iq:agents             {Server component properties}
      jabber:iq:auth               {Client authentization}      
      jabber:iq:autoupdate         {Release information}
      jabber:iq:browse             {Browsing services}
      jabber:iq:conference         {Conferencing service}
      jabber:iq:gateway            {Gateway}
      jabber:iq:last               {Last time}
      jabber:iq:oob                {Out of band data}
      jabber:iq:private            {Store private data}
      jabber:iq:register           {Interactive registration}
      jabber:iq:roster             {Roster management}
      jabber:iq:search             {Searching user database}
      jabber:iq:time               {Client time}
      jabber:iq:version            {Client version}
      jabber:x:autoupdate          {Client update notification}
      jabber:x:conference          {Conference invitation}
      jabber:x:delay               {Object delayed}
      jabber:x:encrypted           {Encrypted message}
      jabber:x:envelope            {Message envelope}
      jabber:x:event               {Message events}
      jabber:x:expire              {Message expiration}
      jabber:x:oob                 {Out of band attachment}
      jabber:x:roster              {Roster item in message}
      jabber:x:signed              {Signed presence}
      vcard-temp                   {Business card exchange}
      http://jabber.org/protocol/muc   {Multi user chat}
      http://jabber.org/protocol/disco {Feature discovery}
    }    
  
    # Short error names.
    variable errorCodeToShort
    array set errorCodeToShort {
      301 {Moved Permanently}
      307 {Moved Temporarily}
      400 {Bad Request}
      401 {Unauthorized}
      404 {Not Found}
      405 {Not Allowed}
      406 {Not Acceptable}
      407 {Registration Required}
      408 {Request Timeout}
    }
    
    # Jabber specific mappings from three digit error code to text.
    variable errorCodeToText
    array set errorCodeToText {\
      conf_pres,301           {The room has changed names}     \
      conf_pres,307           {This room has changed location temporarily}  \
      conf_pres,401           {An authentization step is needed at the service\
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
      conf_message_dir,406    {A reuired extension is stopping this message}  \
      conf_message_dir,407    {The client is required to be in the room in\
      order to send a message to its participants}   \
      conf_message_dir,408    {The message timed out while being sent,\
      the user may resend}  \
    }
      
    # Templates for popup menus for the roster, browse, and groupchat windows.
    # The roster:
    set jstate(popup,roster,def) {
      mMessage       users     {::Jabber::NewMsg::Build $wDlgs(jsendmsg) -to &jid}
      mChat          user      {::Jabber::Chat::StartThread &jid}
      mWhiteboard    wb        {::Jabber::WB::NewWhiteboard &jid}
      separator      {}        {}
      mLastLogin/Activity user {::Jabber::GetLast &jid}
      mvCard         user      {::VCard::Fetch .jvcard other &jid}
      mAddNewUser    any       {::Jabber::Roster::NewOrEditItem $wDlgs(jrostnewedit) new}
      mEditUser      user      {::Jabber::Roster::NewOrEditItem $wDlgs(jrostnewedit) \
	edit -jid &jid}
      mRemoveUser    user      {::Jabber::Roster::SendRemove &jid}
      separator      {}        {}
      mStatus        any       @::Jabber::BuildPresenceMenu
      mRefreshRoster any       {::Jabber::Roster::Refresh}
    }  
  
    # Can't run our http server on macs :-(
    if {![string equal $this(platform) "macintosh"]} {
	set jstate(popup,roster,def) [linsert $jstate(popup,roster,def) 9  \
	  mSendFile     user      {::Jabber::OOB::BuildSet .joobs &jid}]
    }
    
    # The browse:
    set jstate(popup,browse,def) {
      mMessage       user      {::Jabber::NewMsg::Build $wDlgs(jsendmsg) -to &jid}
      mChat          user      {::Jabber::Chat::StartThread &jid}
      mWhiteboard    wb        {::Jabber::WB::NewWhiteboard &jid}
      mEnterRoom     room      {::Jabber::GroupChat::EnterRoom  \
	$wDlgs(jenterroom) -roomjid &jid -autoget 1}
      separator      {}        {}
      mLastLogin/Activity jid  {::Jabber::GetLast &jid}
      mLocalTime     jid       {::Jabber::GetTime &jid}
      mvCard         jid       {::VCard::Fetch .jvcard other &jid}
      mVersion       jid       {::Jabber::GetVersion &jid}
      separator      {}        {}
      mSearch        search    {::Jabber::Search::Build  \
	.jsearch -server &jid -autoget 1}
      mRegister      register  {::Jabber::GenRegister::BuildRegister .jreg  \
	-server &jid -autoget 1}
      mUnregister    register  {::Jabber::Register::Remove &jid}
      separator      {}        {}
      mRefresh       jid       {::Jabber::Browse::Refresh &jid}
      mAddServer     any       {::Jabber::Browse::AddServer}
    }
    
    # The groupchat:
    set jstate(popup,groupchat,def) {
      mMessage       user      {::Jabber::NewMsg::Build $wDlgs(jsendmsg) -to &jid}
      mChat          user      {::Jabber::Chat::StartThread &jid}
      mWhiteboard    wb        {::Jabber::WB::NewWhiteboard &jid}
    }    
    
    # The agents stuff:
    set jstate(popup,agents,def) {
      mSearch        search    {::Jabber::Search::Build .jsearch -server &jid -autoget 1}
      mRegister      register  {::Jabber::GenRegister::BuildRegister  \
	.jreg -server &jid -autoget 1}
      mUnregister    register  {::Jabber::Register::Remove &jid}
      separator      {}        {}
      mEnterRoom     groupchat {::Jabber::GroupChat::EnterRoom $wDlgs(jenterroom)}
      mLastLogin/Activity jid  {::Jabber::GetLast &jid}
      mLocalTime     jid       {::Jabber::GetTime &jid}
      mVersion       jid       {::Jabber::GetVersion &jid}
   }    
  
    variable killerId 
}

proc ::Jabber::Debug {num str} {
    variable jstate
    if {$num <= $jstate(debug)} {
	puts $str
    }
}

# Jabber::FactoryDefaults --
#
#       Makes reasonable default settings for a number of variables and
#       preferences.

proc ::Jabber::FactoryDefaults { } {
    global  sysFont this env prefs wDlgs

    variable jstate
    variable jprefs
    variable jserver
    
    # Network.
    set jprefs(port) 5222
    set jprefs(sslport) 5223
    set jprefs(usessl) 0
    
    # Other
    set jprefs(defSubscribe) 1
    set jprefs(rost,rmIfUnsub) 1
    set jprefs(rost,allowSubNone) 1
    set jprefs(rost,clrLogout) 1
    set jprefs(rost,dblClk) normal
    set jprefs(subsc,inrost) ask
    set jprefs(subsc,notinrost) ask
    set jprefs(subsc,auto) 0
    set jprefs(subsc,group) {}
    set jprefs(chat,showtime) 1
    set jprefs(block,notinrost) 0
    set jprefs(block,list) {}
    set jprefs(speakMsg) 0
    set jprefs(speakChat) 0
    
    # Automatically browse users with resource?
    set jprefs(autoBrowseUsers) 1
    
    # Dialog pane positions.
    set prefs(paneGeom,$wDlgs(jchat)) {0.75 0.25}
    set prefs(paneGeom,$wDlgs(jinbox)) {0.5 0.5}
    set prefs(paneGeom,groupchatDlgVert) {0.8 0.2}
    set prefs(paneGeom,groupchatDlgHori) {0.8 0.2}
    
    # Autoupdate; be sure to use version key since a new version must not inherit.
    # Abondened!!!!!!!
    set jprefs(autoupdateCheck) 0
    set jprefs(autoupdateShow,$prefs(fullVers)) 1
    
    # Our registered serial number at update.jabber.org
    set jprefs(serialno) 123456789
    
    # Sounds.
    set jprefs(snd,online) 1
    set jprefs(snd,offline) 1
    set jprefs(snd,newmsg) 1
    set jprefs(snd,statchange) 1
    set jprefs(snd,connected) 1

    set jprefs(showMsgNewWin) 1
    set jprefs(inbox2click) "newwin"
    
    # Save inbox when quit?
    set jprefs(inboxSave) 0
    
    set jprefs(autoaway) 0
    set jprefs(xautoaway) 0
    set jprefs(awaymin) 0
    set jprefs(xawaymin) 0
    set jprefs(awaymsg) {}
    set jprefs(xawaymsg) {User has been inactive for a while}
    
    set jprefs(logoutStatus) ""
    
    set jprefs(chatFont) $sysFont(s)
    set jprefs(useXDataSearch) 1
    
    # Service discovery method: "agents" or "browse"
    set jprefs(agentsOrBrowse) "browse"
    
    set jstate(rosterVis) 1
    set jstate(browseVis) 0
    set jstate(rostBrowseVis) 1
    set jstate(debugCmd) 0
    
    # Personal info corresponding to the iq:register namespace.
    foreach key $jprefs(iqRegisterElem) {
	set jprefs(iq:register,$key) {}
    }
    
    # Query these jabber servers for services. Login server is automatically
    # queried.
    set jprefs(browseServers) {}
    set jprefs(agentsServers) {}
    
    # The User Info of servers.    
    set jserver(this) {}
    
    # New... Profiles
    set jserver(profile)  \
      {jabber.org {jabber.org myUsername myPassword home}}
    set jserver(profile,selected)  \
      [lindex $jserver(profile) 0]
    set jserver(all) {}
    foreach {name spec} $jserver(profile) {
	lappend jserver(all) $name
    }
    
    switch $this(platform) {
	macintosh - macosx {
	    set jprefs(inboxPath) [file join $prefs(prefsDir) Inbox.tcl]
	}
	windows {
	    set jprefs(inboxPath) [file join $prefs(prefsDir) Inbox.tcl]
	}
	unix {
	    set jprefs(inboxPath) [file join $prefs(prefsDir) inbox.tcl]
	}
    }
}

# Generic ::Jabber:: stuff -----------------------------------------------------

# Jabber::InitWhiteboard --
#
#       Initialize jabber things for this specific whiteboard instance.

proc ::Jabber::InitWhiteboard {wtop} {
    variable jstate
    
    set jstate($wtop,doSend) 0
    # The current receiver of our messages. 'textvariable' in UI entry.
    set jstate($wtop,tojid) ""
    # Identical to 'tojid' for standard chats, but a list of jid's
    # with /nick for groupchat's.
}

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
    
    # Make the roster object.
    set jstate(roster) [::roster::roster rost0 ::Jabber::Roster::PushProc]
    
    # Make the browse object.
    set jstate(browse) [::browse::browse browse0 ::Jabber::Browse::Callback]
    
    # Check if we need to set any auto away options.
    set opts {}
    if {$jprefs(autoaway) || $jprefs(xautoaway)} {
	foreach name {autoaway xautoaway awaymin xawaymin awaymsg xawaymsg} {
	    lappend opts -$name $jprefs($name)
	}
    }
    
    # Add the three element callbacks.
    lappend opts -iqcommand ::Jabber::IqCallback  \
      -messagecommand ::Jabber::MessageCallback  \
      -presencecommand ::Jabber::PresenceCallback

    # Make an instance of jabberlib and fill in our roster object.
    set jstate(jlib) [eval {::jlib::new jlib0 $jstate(roster) $jstate(browse) \
      ::Jabber::ClientProc} $opts]
    
    if {[string equal $prefs(protocol) "jabber"]} {
	
	# Make the combined window.
	if {$jstate(rostBrowseVis)} {
	    ::Jabber::RostServ::Show $wDlgs(jrostbro)
	} else {
	    ::Jabber::RostServ::Build $wDlgs(jrostbro)
	    wm withdraw $wDlgs(jrostbro)
	}
    }
}

# ::Jabber::IqCallback --
#
#       Registered callback proc for <iq> elements. Most handled elsewhere,
#       in roster, browser and registered callbacks.
#       
# Results:
#       boolean (0/1) telling if this was handled or not. Only for 'get'.

proc ::Jabber::IqCallback {jlibName type args} {
    
    variable jstate
    variable jprefs
    
    ::Jabber::Debug 2 "::Jabber::IqCallback type=$type, args='$args'"
    
    array set attrArr $args
    set xmlns [wrapper::getattr [lindex $attrArr(-query) 1] xmlns]
    set stat 1
    
    switch -- $type {
	result {
	    # Unhandled result callback?
	}
	get {
	    
	    # jabber:iq:time and jabber:iq:last handled in jabberlib.
	    switch -- $xmlns {
		jabber:iq:version {
		    set stat [eval {::Jabber::ParseGetVersion} $args]
		}
		jabber:iq:browse {
		    set stat [eval {::Jabber::ParseGetBrowse} $args]
		}
		default {
		    set stat 0
		}
	    }	    
	}
	set {
	    switch -- $xmlns {
		jabber:iq:oob {
		    eval {::Jabber::OOB::ParseSet $attrArr(-from)  \
		      $attrArr(-query)} $args
		}
		default {

		}
	    }	    
	}
	error {
	    # Unhandled error callback?
	}
    }
    return $stat
}

# ::Jabber::MessageCallback --
#
#       Registered callback proc for <message> elements.
#       
# Arguments:
#       type        normal|chat|groupchat
#       args        ?-key value ...?
#       
# Results:
#       none.

proc ::Jabber::MessageCallback {jlibName type args} {
    
    variable jstate
    variable jprefs
    
    ::Jabber::Debug 2 "::Jabber::MessageCallback type=$type, args='$args'"
    
    array set attrArr {-body ""}
    array set attrArr $args
    
    set from $attrArr(-from)
    
    # Check if any blockers.
    if {$jprefs(block,notinrost) && ($type == "normal")} {
	
	# Reject if not in roster.
	set allUsers [$jstate(roster) getusers]
	if {[lsearch -exact $allUsers $from] < 0} {
	    puts "Rejected message from: $from"
	    return
	}
    }
    if {[llength $jprefs(block,list)] > 0} {
	foreach blkjid $jprefs(block,list) {
	    if {[string match $blkjid $from]} {
		puts "Rejected message from: $from"
		return
	    }
	}
    }
    
    # We must check if there is an error element sent along with the
    # body element. In that case the body element shall not be processed.
    if {[string equal $type "error"] && [info exists attrArr(-error)]} {
	set errcode [lindex $attrArr(-error) 0]
	set errmsg [lindex $attrArr(-error) 1]
	
	tk_messageBox -title [::msgcat::mc Error] -message [FormatTextForMessageBox \
	  [::msgcat::mc jamesserrsend $attrArr(-from) $errcode $errmsg]]  \
	  -icon error -type ok		
    } else {
	
	# Check if we've got an <x xmlns='coccinella:wb'><raw> element...
	set haveCoccinellaNS 0
	set rawElemList {}
	if {[info exists attrArr(-x)]} {
	    foreach xlist $attrArr(-x) {
		
		# Take each <x> element in turn.
		foreach {xtag xattrlist xempty xchdata xsub} $xlist { break }
		array set xattrArr $xattrlist
		if {![info exists xattrArr(xmlns)]} {
		    continue
		}
		switch -- $xattrArr(xmlns) {
		    "jabber:x:coccinella" - "coccinella:wb" {
			set haveCoccinellaNS 1
			foreach xsubtag $xsub {
			    if {[string equal [lindex $xsubtag 0] "raw"]} {
				lappend rawElemList [lindex $xsubtag 3]
			    }
			}
		    }
		    "jabber:x:autoupdate" {
			
			# CHDATA shall contain the jid
			$jstate(jlib) send_autoupdate $xchdata  \
			  [namespace current]::GetAutoupdate
		    }
		}
	    }
	}
		
	# If a room message sent from us we don't want to duplicate it.
	# Whiteboard only.
	set doShow 1
	if {$haveCoccinellaNS} {
	    if {[string equal $type "groupchat"]} {
		if {[regexp {^(.+@[^/]+)(/(.+))?} $attrArr(-from) match roomJid x]} {
		    foreach {meHash nick}  \
		      [$jstate(jlib) service hashandnick $roomJid] { break }
		    if {[string equal $meHash $attrArr(-from)]} {
			set doShow 0
		    }
		}
	    }
	}
	
	# Send message to dispatcher for 'type' and whiteboard.
	set msgArgs $args
	if {$doShow && $haveCoccinellaNS} {
	    lappend msgArgs -whiteboard $rawElemList
	}
	
	# Interpret this as an ordinary jabber message element.
	eval {::Jabber::MessageDispatcher $type $attrArr(-body)} $msgArgs    
    }
}

# ::Jabber::MessageDispatcher --
#
#       Dispatch a jabber message to either the "normal" dialog, chat window,
#       or groupchat window.
#       
# Arguments:
#       type        message type attribute
#       body        the <body> element. Empty if have -whiteboard.
#       args        -type, -from, -whiteboard, -x, -thread
#       
# Results:
#       dispatch procedure called.

proc ::Jabber::MessageDispatcher {type body args} {
    
    set iswb 0
    if {[lsearch -exact $args "-whiteboard"] >= 0} {
	set iswb 1
    }
    
    switch -- $type {
	chat {
	    if {$iswb} {
		eval {::Jabber::WB::ChatMsg} $args
	    } elseif {[string length $body]} {
		eval {::Jabber::Chat::GotMsg $body} $args
	    }	    
	}
	groupchat {
	    if {$iswb} {
		eval {::Jabber::WB::GroupChatMsg} $args
	    } elseif {[string length $body]} {
		eval {::Jabber::GroupChat::GotMsg $body} $args
	    }	    
	}
	default {
	
	    # Normal message. Handles whiteboard stuff as well.
	    eval {::Jabber::DispatchNormalMessage $body $iswb} $args
	}
    }
}

# ::Jabber::DispatchNormalMessage --
# 
#       Take care of commands that must be responded to, and forward rest
#       to inbox.

proc ::Jabber::DispatchNormalMessage {body iswb args} {
    variable  jstate
    
    # We need to split up whiteboard commands (messages) that must be
    # handled immediately and those destined for drawing etc. 
    # BAD DESIGN HERE!!!!!!!!!
    if {$iswb} {
	array set argsArr $args
	set restCmds {}
	foreach raw $argsArr(-whiteboard) {
	    switch -glob -- $raw {
		"GET IP:*" - "PUT IP:*" {
		    eval {ExecuteClientRequest . $jstate(sock) ip port $raw} \
		      $args
		}
		"IDENTITY:*" - "IPS CONNECTED:*" - "CLIENT:*" -  \
		  "DISCONNECTED:*" - "RESIZE:*" {
		    
		    # Junk.
		}
		default {
		    lappend restCmds $raw
		}
	    }
	}
	if {[llength $restCmds] > 0} {
		set argsArr(-whiteboard) $restCmds
		eval {::Jabber::MailBox::GotMsg $body} [array get argsArr]
	}
    } else {
	eval {::Jabber::MailBox::GotMsg $body} $args
    }
}

# ::Jabber::PresenceCallback --
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

proc ::Jabber::PresenceCallback {jlibName type args} {
    global  wDlgs prefs
    
    variable jstate
    variable jprefs
    variable jerror
    
    ::Jabber::Debug 2 "::Jabber::PresenceCallback type=$type, args='$args'"
    
    array set attrArr $args
    set from $attrArr(-from)
    
    switch -- $type {
	subscribe {
	    
	    # Another user request to subscribe to our presence.
	    # Figure out what the user's prefs are.
	    set allUsers [$jstate(roster) getusers]
	    if {[lsearch -exact $allUsers $from] >= 0} {
		set key inrost
	    } else {
		set key notinrost
	    }		
	    
	    # No resource here!
	    set subState [$jstate(roster) getsubscription $from]
	    set isSubscriberToMe 0
	    if {[string equal $subState "from"] ||  \
	      [string equal $subState "both"]} {
		set isSubscriberToMe 1
	    }
		
	    # Accept, deny, or ask depending on preferences we've set.
	    set msg ""
	    set autoaccepted 0
	    switch -- $jprefs(subsc,$key) {
		accept {
		    $jstate(jlib) send_presence -to $from -type "subscribed"
		    set autoaccepted 1
		    set msg [::msgcat::mc jamessautoaccepted $from]
		}
		reject {
		    $jstate(jlib) send_presence -to $from -type "unsubscribed"
		    set msg [::msgcat::mc jamessautoreject $from]
		}
		ask {
		    eval {::Jabber::Subscribe::Subscribe $wDlgs(jsubsc) $from} $args
		}
	    }
	    if {$msg != ""} {
		tk_messageBox -title [::msgcat::mc Info] -icon info -type ok \
		  -message [FormatTextForMessageBox $msg]			      
	    }
	    
	    # Auto subscribe to subscribers to me.
	    if {$autoaccepted && $jprefs(subsc,auto)} {
		
		# Explicitly set the users group.
		if {[string length $jprefs(subsc,group)]} {
		    $jstate(jlib) roster_set $from ::Jabber::Subscribe::ResProc \
		      -groups [list $jprefs(subsc,group)]
		}
		$jstate(jlib) send_presence -to $from -type "subscribe"
		set msg [::msgcat::mc jamessautosubs $from]
		tk_messageBox -title [::msgcat::mc Info] -icon info -type ok \
		  -message [FormatTextForMessageBox $msg]			  
	    }
	}
	subscribed {
	    tk_messageBox -title [::msgcat::mc Subscribed] -icon info -type ok  \
	      -message [FormatTextForMessageBox [::msgcat::mc jamessallowsub $from]]
	}
	unsubscribe {	    
	    if {$jprefs(rost,rmIfUnsub)} {
		
		# Remove completely from our roster.
		$jstate(jlib) roster_remove $from ::Jabber::Roster::PushProc
		tk_messageBox -title [::msgcat::mc Unsubscribe] \
		  -icon info -type ok  \
		  -message [FormatTextForMessageBox [::msgcat::mc jamessunsub $from]]
	    } else {
		
		$jstate(jlib) send_presence -to $from -type "unsubscribed"
		tk_messageBox -title [::msgcat::mc Unsubscribe] -icon info -type ok  \
		  -message [FormatTextForMessageBox [::msgcat::mc jamessunsubpres $from]]
		
		# If there is any subscription to this jid's presence.
		set sub [$jstate(roster) getsubscription $from]
		if {[string equal $sub "both"] ||  \
		  [string equal $sub "to"]} {
		    
		    set ans [tk_messageBox -title [::msgcat::mc Unsubscribed]  \
		      -icon question -type yesno -default yes \
		      -message [FormatTextForMessageBox  \
		      [::msgcat::mc jamessunsubask $from $from]]]
		    if {$ans == "yes"} {
			$jstate(jlib) roster_remove $from \
			  ::Jabber::Roster::PushProc
		    }
		}
	    }
	}
	unsubscribed {
	    
	    # If we fail to subscribe someone due to a technical reason we
	    # have sunscription='none'
	    set sub [$jstate(roster) getsubscription $from]
	    if {$sub == "none"} {
		set msg "Failed making a subscription to $from."
		if {[info exists attrArr(-status)]} {
		    append msg " Status message: $attrArr(-status)"
		}
		tk_messageBox -title "Subscription Failed"  \
		  -icon info -type ok  \
		  -message [FormatTextForMessageBox $msg]
	    } else {		
		tk_messageBox -title [::msgcat::mc Unsubscribed]  \
		  -icon info -type ok  \
		  -message [FormatTextForMessageBox  \
		  [::msgcat::mc jamessunsubscribed $from]]
	    }
	}
	error {
	    foreach {errcode errmsg} $attrArr(-error) { break }		
	    set msg [::msgcat::mc jamesserrpres $errcode $errmsg]
	    if {$prefs(talkative)} {
		tk_messageBox -icon error -type ok  \
		  -title [::msgcat::mc {Presence Error}] \
		  -message [FormatTextForMessageBox $msg]	
	    } else {
		lappend jerror [list [clock format [clock seconds] -format "%H:%M:%S"]  \
		  $from $msg]
	    }
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
#                   "away", or "xaway"
#       args        Is a list of '-key value' pairs.
#       
# Results:
#       none.

proc ::Jabber::ClientProc {jlibName what args} {
    global  wDlgs
    
    variable jstate
    variable jprefs
    
    ::Jabber::Debug 2 "::Jabber::ClientProc: jlibName=$jlibName, what=$what, args='$args'"
    
    # For each 'what', split the argument list into the proper arguments,
    # and make the necessary calls.
    array set attrArr $args
    
    switch -- $what {
	connect {
	    
	    # We just got the <stream> element from the server.
	    # Handled via direct callback from 'jlibName connect' instead.
	}
	disconnect {	    
	    
	    # This is as a response to a </stream> element.
	    # If we close the socket and don't wait for the close element
	    # we never end up here.
	    
	    # Disconnect. This should reset both wrapper and XML parser!
	    ::Jabber::DoCloseClientConnection $jstate(ipNum)
	    
	    tk_messageBox -icon error -type ok  \
	      -message [::msgcat::mc jamessconnbroken]
	}
	away - xaway {
	    
	    set tm [clock format [clock seconds] -format "%H:%M:%S"]
	    set ans [tk_messageBox -icon info -type yesno -default yes \
	      -message [FormatTextForMessageBox \
	      [::msgcat::mc jamessautoawayset $tm]]
	    if {$ans == "yes"} {
		::Jabber::SetStatus available
	    }
	}
	xmlerror {
	    
	    # XML parsing error.
	    # Disconnect. This should reset both wrapper and XML parser!
	    ::Jabber::DoCloseClientConnection $jstate(ipNum)
	    if {[info exists attrArr(-errormsg)]} {
		set msg "Receieved a fatal XML parsing error:\
		  $attrArr(-errormsg). The connection is closed down."
	    } else {
		set msg {Receieved a fatal XML parsing error.\
		  The connection is closed down.}
	    }
	    tk_messageBox -title [::msgcat::mc {Fatal Error}] -icon error -type ok \
	      -message [FormatTextForMessageBox $msg]
	}
	networkerror {
	    
	    # Disconnect. This should reset both wrapper and XML parser!
	    ::Jabber::DoCloseClientConnection $jstate(ipNum)
	    tk_messageBox -title [::msgcat::mc {Network Error}] \
	      -message [FormatTextForMessageBox $attrArr(-body)] \
	      -icon error -type ok	    
	}
    }
}

proc ::Jabber::IsConnected { } {
    variable jserver
    return [expr [string length $jserver(this)] == 0 ? 0 : 1]
}

# Jabber::DebugCmd --
#
#       Hides or shows console on mac and windows, sets debug for XML I/O.

proc ::Jabber::DebugCmd { } {
    global  this
    
    variable jstate
    
    if {$jstate(debugCmd)} {
	if {$this(platform) == "windows" || [string match "mac*" $this(platform)]} {
	    console show
	}
	jlib::setdebug 2
    } else {
	if {$this(platform) == "windows" || [string match "mac*" $this(platform)]} {
	    if {$jstate(debug) == 0} {
		console hide
	    }
	}
	jlib::setdebug 0
    }
}

# Jabber::ErrorLogDlg

proc ::Jabber::ErrorLogDlg {w} {
    global  this sysFont
    
    variable jerror

    if {[winfo exists $w]} {
	raise $w
	return
    }
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {
	wm transient $w .
    }
    wm title $w {Error Log (noncriticals)}
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised] -fill both -expand 1
    
    # Text.
    set wtxt $w.frall.frtxt
    pack [frame $wtxt] -side top -fill both -expand 1 -padx 4 -pady 4
    set wtext $wtxt.text
    set wysc $wtxt.ysc
    text $wtext -height 12 -width 48 -font $sysFont(s) -wrap word \
      -borderwidth 1 -relief sunken -yscrollcommand [list $wysc set]
    scrollbar $wysc -orient vertical -command [list $wtext yview]
    grid $wtext -column 0 -row 0 -sticky news
    grid $wysc -column 1 -row 0 -sticky ns
    grid columnconfigure $wtxt 0 -weight 1
    grid rowconfigure $wtxt 0 -weight 1
    
    set space 2
    $wtext tag configure timetag -spacing1 $space -foreground blue
    $wtext tag configure jidtag -spacing1 $space -foreground red
    $wtext tag configure msgtag -spacing1 $space -spacing3 $space   \
      -lmargin1 20 -lmargin2 30
        
    $wtext configure -state normal
    foreach line $jerror {
	foreach {tm jid msg} $line { break }
	$wtext insert end "<$tm>:  " timetag
	$wtext insert end "$jid   " jidtag
	$wtext insert end $msg msgtag
	$wtext insert end "\n"
    }
    $wtext configure -state disabled
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btset -text [::msgcat::mc Close] -width 8 \
      -command "destroy $w"] -side right -padx 5 -pady 5
    pack $frbot -side top -fill x -padx 8 -pady 6
}

# Jabber::IqSetGetCallback --
#
#       Generic callback procedure when sending set/get iq element.
#       
# Arguments:
#       method      description of the original call.
#       jlibName:   the instance of this jlib.
#       type:       "error" or "ok".
#       thequery:   if type="error", this is a list {errcode errmsg},
#                   else it is the query element as a xml list structure.
#       
# Results:
#       none.

proc ::Jabber::IqSetGetCallback {method jlibName type theQuery} {
    
    variable jstate
    
    ::Jabber::Debug 2 "::Jabber::IqSetGetCallback, method=$method, type=$type,\
	  theQuery='$theQuery'"
	
    if {[string equal $type "error"]} {
	foreach {errcode errmsg} $theQuery { break }
	switch -- $method {
	    default {
		set msg "Found an error for $method with code $errcode,\
		  and with message: $errmsg"
	    }
	}
	tk_messageBox -icon error -type ok -title [::msgcat::mc Error] -message \
	  [FormatTextForMessageBox $msg]
    }
}

# Jabber::SendWhiteboardMessage --
#
#       This is just a shortcut for sending a message. Practical in the
#       whiteboard since it hides the internal jabber vars.
#       
# Arguments:
#       wtop
#       msg
#       args        ?-key value ...?
#                   -force 0|1   (D=0) override doSend checkbutton?
#       
# Results:
#       none.

proc ::Jabber::SendWhiteboardMessage {wtop msg args} {
    variable jstate
    
    array set opts {-force 0}
    array set opts $args
    set tojid $jstate($wtop,tojid)
    
    # Here we shall decide the 'type' of message sent (normal, chat, groupchat)
    # depending on the type of whiteboard (via wtop).
    set argsList [::Jabber::SendWhiteboardArgs $wtop]
    if {$jstate($wtop,doSend) || $opts(-force)} {
	if {[::Jabber::VerifyJIDWhiteboard $wtop]} {
	    eval {::Jabber::SendMessage $tojid $msg} $argsList
	} else {
	    
	    # Perhaps we should give some aid here; set focus?
	}
    }
}

# Jabber::SendWhiteboardMessageList --
#
#       As above but for a list of commands.

proc ::Jabber::SendWhiteboardMessageList {wtop msgList args} {
    variable jstate
    
    array set opts {-force 0}
    array set opts $args
    set tojid $jstate($wtop,tojid)

    set argsList [::Jabber::SendWhiteboardArgs $wtop]
    if {$jstate($wtop,doSend) || $opts(-force)} {
	if {[::Jabber::VerifyJIDWhiteboard $wtop]} {
	    eval {::Jabber::SendMessageList $tojid $msgList} $argsList
	} else {
	    
	    # Perhaps we should give some aid here; set focus?
	}
    }
}

proc ::Jabber::SendWhiteboardArgs {wtop} {

    set argsList {}
    set type [::UI::GetJabberType $wtop]
    if {[llength $type] > 0} {
	lappend argsList -type $type
	if {[string equal $type "chat"]} {
		lappend argsList -thread [::UI::GetJabberChatThread $wtop]
	}
    }
    return $argsList
}

# Jabber::SendMessage --
#
#       Sends a message, typically in an <x xmlns='coccinella:wb'><raw> element.
#       
# Arguments:
#       jid
#       msg
#       args    ?-key value? list to use for 'send_message'.
#       
# Results:
#       none.

proc ::Jabber::SendMessage {jid msg args} {    
    variable jstate
    variable jprefs
    
    if {$jprefs(useXMLNamespace)} {
	
	# Form an <x xmlns='coccinella:wb'><raw> element in message.
	set subx [list [wrapper::createtag "raw" -chdata $msg]]
	set xlist [list [wrapper::createtag x -attrlist  \
	  {xmlns coccinella:wb} -subtags $subx]]
	if {[catch {
	    eval {$jstate(jlib) send_message $jid -xlist $xlist} $args
	} err]} {
	    DoCloseClientConnection $jstate(ipNum)
	    tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	      -message [FormatTextForMessageBox $err]
	}
    } else {
	if {[catch {
	    eval {$jstate(jlib) send_message $jid -body $msg} $args
	} err]} {
	    DoCloseClientConnection $jstate(ipNum)
	    tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	      -message [FormatTextForMessageBox $err]
	}
    }
}

# Jabber::SendMessageList --
#
#       As above but for a list of commands.

proc ::Jabber::SendMessageList {jid msgList args} {
    variable jstate
    variable jprefs
    
    if {$jprefs(useXMLNamespace)} {
	
	# Form <x xmlns='coccinella:wb'> element with any number of <raw>
	# elements as childs.
	set subx {}
	foreach msg $msgList {
	    lappend subx [wrapper::createtag "raw" -chdata $msg]
	}
	set xlist [list [wrapper::createtag x -attrlist  \
	  {xmlns coccinella:wb} -subtags $subx]]
	if {[catch {
	    eval {$jstate(jlib) send_message $jid -xlist $xlist} $args
	} err]} {
	    DoCloseClientConnection $jstate(ipNum)
	    tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	      -message [FormatTextForMessageBox $err]
	}
    } else {
	error {::Jabber::SendMessageList needs jprefs(useXMLNamespace)}
    }
}

proc ::Jabber::DoSendCanvas {wtop} {
    global  prefs
    variable jstate
    upvar ::${wtop}::wapp wapp

    set wtopReal $wapp(toplevel)

    set jid $jstate($wtop,tojid)
    if {[::Jabber::IsWellFormedJID $jid]} {
	
	# The Classic mac can't run the http server!
	if {!$prefs(haveHttpd)} {
	    set ans [tk_messageBox -icon warning -type yesno  \
	      -parent $wapp(toplevel)  \
	      -message [FormatTextForMessageBox "The Classic Mac can't run\
	      the internal http server which is needed for transporting any\
	      images etc. in this message.\
	      Do you want to send it anyway?"]]
	    if {$ans == "no"} {
		return
	    }
	}
	
	# If user not online no files may be sent off.
	if {![$jstate(roster) isavailable $jid]} {
	    set ans [tk_messageBox -icon warning -type yesno  \
	      -parent $wapp(toplevel)  \
	      -message [FormatTextForMessageBox "The user you are sending to,\
	      \"$jid\", is not online, and if this message contains any images\
	      or other similar entities, this user will not get them unless\
	      you happen to be online while this message is being read.\
	      Do you want to send it anyway?"]]
	    if {$ans == "no"} {
		return
	    }
	}
	::UserActions::DoSendCanvas $wtop
    
	    # Should we clear the window, or perhaps destroy it?
	    if {$wtop == "."} {
		::UserActions::EraseAll $wtop
		set msg "Whiteboard message sent to $jid"
		::UI::SetStatusMessage $wtop $msg
	    } else {
		destroy $wtopReal
	    }
    } else {
	tk_messageBox -icon warning -type ok -parent $wapp(toplevel) -message \
	  [FormatTextForMessageBox [::msgcat::mc jamessinvalidjid]]
    }
}

# Jabber::UpdateAutoAwaySettings --
#
#       If changed present auto away settings, may need to configure
#       our jabber object.

proc ::Jabber::UpdateAutoAwaySettings { } {
    
    variable jstate
    variable jprefs
    
    array set oldopts [$jstate(jlib) config]
    set reconfig 0
    foreach name {autoaway xautoaway awaymin xawaymin} {
	if {$oldopts(-$name) != $jprefs($name)} {
	    set reconfig 1
	    break
	}
    }
    if {$reconfig} {
	set opts {}
	if {$jprefs(autoaway) || $jprefs(xautoaway)} {
	    foreach name {autoaway xautoaway awaymin xawaymin awaymsg xawaymsg} {
		lappend opts -$name $jprefs($name)
	    }
	}
	eval {$jstate(jlib) config} $opts
    }
}

# Jabber::DoCloseClientConnection --
#
#       Handle closing down the client side connection (the 'to' part).
#       Try to be silent if called as a response to a server shutdown.
#       
# Arguments:
#       ipNum     the ip number.
#       args      -status, 
#       
# Results:
#       none

proc ::Jabber::DoCloseClientConnection {ipNum args} {
    global  prefs
        
    variable jstate
    variable jserver
    variable jprefs
    
    ::Jabber::Debug 2 "::Jabber::DoCloseClientConnection ipNum=$ipNum"
    array set argsArr [list -status $jprefs(logoutStatus)]    
    array set argsArr $args

    # Send unavailable information. Silently in case we got network error.
    set opts {}
    if {[string length $argsArr(-status)] > 0} {
	lappend opts -status $argsArr(-status)
    }
    catch {
	eval {$jstate(jlib) send_presence -type unavailable} $opts
    }
    
    # Disable all buttons in groupchat windows.
    ::Jabber::GroupChat::Logout
    
    # Do the actual closing.
    #       There is a potential problem if called from within a xml parser 
    #       callback which makes the subsequent parsing to fail. (after idle?)
    after idle $jstate(jlib) disconnect
    
    # Update the communication frame; remove connection 'to'.
    if {$prefs(jabberCommFrame)} {
	::UI::ConfigureAllJabberEntries $ipNum -netstate "disconnect"
    } else {
	::UI::SetCommEntry . $ipNum 0 -1
    }
    
    # Ourself.
    set jstate(mejid) ""
    set jstate(meres) ""
    set jstate(mejidres) ""
    set jstate(status) "unavailable"
    set jserver(this) {}

    # Multiinstance whiteboard UI stuff.
    foreach w [::UI::GetAllWhiteboards] {
	set wtop [::UI::GetToplevelNS $w]
	::UI::SetStatusMessage $wtop [::msgcat::mc jaservclosed]

	# If no more connections left, make menus consistent.
	::UI::FixMenusWhen $wtop "disconnect"
    }
    ::Jabber::Roster::SetUIWhen "disconnect"
    if {[lsearch [::Jabber::RostServ::Pages] "Browser"] >= 0} {
	::Jabber::Browse::SetUIWhen "disconnect"
    }
    
    # Be sure to kill the wave; could end up here when failing to connect.
    ::UI::StartStopAnimatedWaveOnMain 0
    
    # Clear roster and browse windows.
    $jstate(roster) reset
    if {$jprefs(rost,clrLogout)} {
	::Jabber::Roster::Clear
    }
    if {[lsearch [::Jabber::RostServ::Pages] "Browser"] >= 0} {
	::Jabber::Browse::Clear
    }
    ::Jabber::RostServ::LogoutClear
}

# Jabber::EndSession --
#
#       This is supposed to be called only when doing Quit.
#       Things are not cleaned up properly, since we kill ourselves.

proc ::Jabber::EndSession { } {
    
    variable jstate
    variable jserver
    variable jprefs

    # Send unavailable information. Silently in case we got network error.
    if {[::Jabber::IsConnected]} {
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
	$jstate(jlib) disconnect
    }
    
    if {$jprefs(inboxSave)} {
	::Jabber::MailBox::SaveMailbox
    }
}

# Jabber::BuildJabberEntry --
#
#       A utility procedure to build a persistant jabber entry.
#       Used to hide jabber stuff away from ::UI

proc ::Jabber::BuildJabberEntry {wtop args} {
    
    eval {::UI::BuildJabberEntry $wtop  \
      -servervariable ::Jabber::jserver(this)  \
      -jidvariable ::Jabber::jstate($wtop,tojid) \
      -dosendvariable ::Jabber::jstate($wtop,doSend)} $args
      
    eval {::Jabber::ConfigureJabberEntry $wtop} $args
}

# Jabber::ConfigureJabberEntry --
#
#       A utility procedure to configure the jabber entry.
#       Used to hide jabber stuff away from ::UI

proc ::Jabber::ConfigureJabberEntry {wtop args} {

    variable jstate

    Debug 2 "::Jabber::ConfigureJabberEntry wtop=$wtop args='$args'"
    foreach {key value} $args {
    	switch -- $key {
    	    -jid {
    	    	set jstate($wtop,tojid) $value
	    }

	}
    }
}

# Jabber::IsWellFormedJID --
#
#       Is this a well formed Jabber ID?. What abot the resource (/home) part?
#       
# Arguments:
#       jid     Jabber ID, such as 'matben@athlon.se', if well formed.
#       
# Results:
#       boolean

proc ::Jabber::IsWellFormedJID {jid} {
    
    variable jprefs
    
    if {[regexp {(.+)@([^/]+)(/(.+))?} $jid match name host junk res]} {
	if {[regexp $jprefs(invalsExp) $name match junk]} {
	    return 0
	} elseif {[regexp $jprefs(invalsExp) $host match junk]} {
	    return 0
	}
	return 1
    } else {
	return 0
    }
}

# Jabber::ValidateJIDChars --
#
#       Validate entry for username etc.
#       
# Arguments:
#       str     username etc.
#       
# Results:
#       boolean: 0 if reject, 1 if accept

proc ::Jabber::ValidateJIDChars {str} {
    
    variable jprefs

    if {[regexp $jprefs(invalsExp) $str match junk]} {
	bell
	return 0
    } else {
	return 1
    }
}

# Jabber::ValidatePasswdChars --
#
#       Validate entry for password. Not so sure about this. Docs?
#       
# Arguments:
#       str     password
#       
# Results:
#       boolean: 0 if reject, 1 if accept

proc ::Jabber::ValidatePasswdChars {str} {
    
    if {[regexp {[ ]} $str match junk]} {
	bell
	return 0
    } else {
	return 1
    }
}

# Jabber::SetStatus --
#
#       Sends presence status information.

proc ::Jabber::SetStatus {type {to {}}} {
    
    variable jprefs
    variable jstate
    
    if {$to != ""} {
	set toArgs "-to $to"
    } else {
	set toArgs {}
    }
    
    # Trap network errors.
    if {[catch {
	switch -- $type {
	    available - unavailable - invisible {
		eval {$jstate(jlib) send_presence -type $type} $toArgs
	    }
	    away - dnd - xa {
		eval {$jstate(jlib) send_presence -type "available"}  \
		  -show $type $toArgs
	    }
	}	
    } err]} {
	
	# Close down?
	
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	  -message [FormatTextForMessageBox $err]
    }
}

# Jabber::SetStatusWithMessage --
#
#       Dialog for setting user's status with message.
#       
# Arguments:
#       w
#       
# Results:
#       "cancel" or "set".

proc ::Jabber::SetStatusWithMessage {w} {
    global  this sysFont
    
    variable finishedStat
    variable show
    variable wtext
    variable jprefs
    variable jstate

    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {
	wm transient $w .
    }
    wm title $w [::msgcat::mc {Set Status}]
    set finishedStat -1
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised] -fill both -expand 1
    
    # Top frame.
    set frtop $w.frall.frtop
    set fr [LabeledFrame2 $frtop [::msgcat::mc {My Status}]]
    pack $frtop -side top -fill x -padx 4 -pady 4
    foreach val {available chat away xa dnd invisible} {
	radiobutton ${fr}.${val} -text [::msgcat::mc jastat${val}]  \
	  -variable "[namespace current]::show" -value $val
	grid ${fr}.${val} -sticky w -padx 12 -pady 3
    }
    
    # Set present status.
    set show $jstate(status)
    
    pack [label $w.frall.lbl -text "[::msgcat::mc {Status message}]:" \
      -font $sysFont(sb)]  \
      -side top -anchor w -padx 6 -pady 0
    set wtext $w.frall.txt
    text $wtext -height 4 -width 36 -font $sysFont(s) -wrap word \
      -borderwidth 1 -relief sunken
    pack $wtext -expand 1 -fill both -padx 6 -pady 4    
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btset -text [::msgcat::mc Set] -default active -width 8 \
      -command [list [namespace current]::BtSetStatus $w]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8  \
      -command [list [namespace current]::SetStatusCancel $w]] \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
    
    wm resizable $w 0 0
    bind $w <Return> {}
    
    # Grab and focus.
    set oldFocus [focus]
    focus $w
    catch {grab $w}
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w
    
    catch {grab release $w}
    focus $oldFocus
    return [expr {($finishedStat <= 0) ? "cancel" : "set"}]
}

proc ::Jabber::SetStatusCancel {w} {    
    variable finishedStat

    set finishedStat 0
    destroy $w
}

proc ::Jabber::BtSetStatus {w} {
    
    variable finishedStat
    variable show
    variable wtext
    variable jstate
    
    set statusOpt {}
    set allText [string trim [$wtext get 1.0 end] " \n"]
    if {[string length $allText]} {
	set statusOpt [list -status $allText]
    }  
    
    # Set present status.
    set jstate(status) $show
    switch -- $show {
	invisible {
	    eval {$jstate(jlib) send_presence -type "invisible" -show $show} \
	      $statusOpt
	}
	default {
	    eval {$jstate(jlib) send_presence -type "available" -show $show} \
	      $statusOpt
	}
    }
    
    set finishedStat 1
    destroy $w
}

# Jabber::GetIPnumber / PutIPnumber --
#
#       Utilites to put/get ip numbers from clients.
#
# Arguments:
#       jid:        fully qualified "username@host/resource".
#       cmd:        (optional) callback command when gets ip number.
#       
# Results:
#       none.

proc ::Jabber::GetIPnumber {jid {cmd {}}} {
    
    variable jstate
    variable getcmd
    variable getid
    variable jidToIP

    ::Jabber::Debug 2 "::Jabber::GetIPnumber:: jid=$jid, cmd='$cmd'"
    
    if {[string length $cmd]} {
	set getcmd($getid) $cmd
	
	# What shall we do when we already have the IP number?
	if {[info exists jidToIP($jid)]} {
	    GetIPCallback $jid $getid $jidToIP($jid)
	} else {
	    #$jstate(jlib) send_message $jid -body "GET IP: $getid"
	    ::Jabber::SendMessage $jid "GET IP: $getid"
	}
    }
    incr getid
}

proc ::Jabber::PutIPnumber {jid id} {
    variable jstate
    
    ::Jabber::Debug 2 "::Jabber::PutIPnumber:: jid=$jid, id=$id"
    
    set ip [::Network::GetThisOutsideIPAddress]
    ::Jabber::SendMessage $jid "PUT IP: $id $ip"
}

# Jabber::GetIPCallback --
#
#       This proc gets called when a requested ip number is received
#       by our server.
#
# Arguments:
#       fromjid     fully qualified  "username@host/resource"
#       id
#       clientIP
#       
# Results:
#       Any registered callback proc is eval'ed.

proc ::Jabber::GetIPCallback {fromjid id clientIP} {
    
    variable jstate
    variable getcmd
    variable jidToIP

    ::Jabber::Debug 2 "::Jabber::GetIPCallback: fromjid=$fromjid, id=$id, clientIP=$clientIP"
    if {[info exists getcmd($id)]} {
	::Jabber::Debug 2 "   getcmd($id)='$getcmd($id)'"
	set jidToIP($fromjid) $clientIP
	eval $getcmd($id) $fromjid
	unset getcmd($id)
    }
}

# Jabber::PutFileAndSchedule --
# 
#       Handles everything needed to put a file to the jid's corresponding
#       to the 'wtop'. Users that we haven't got ip number from are scheduled
#       for delivery as a callback.
#       
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       fileName    the path to the file to be put.
#       'optList'   a list of 'key: value' pairs, resembling the html 
#                   protocol for getting files, but where most keys correspond
#                   to a valid "canvas create" option.
#       
# Results:
#       none.

proc ::Jabber::PutFileAndSchedule {wtop fileName optList} {
    
    variable jidToIP
    variable jstate
    
    ::Jabber::Debug 2 "::Jabber::PutFileAndSchedule: \
      wtop=$wtop, fileName=$fileName, optList='$optList'"
    
    # Before doing anything check that the Send checkbutton is on. ???
    if {!$jstate($wtop,doSend)} {
    	::Jabber::Debug 2 "    doSend=0 => return"
	return
    }
    
    # Verify that jid is well formed.
    if {![::Jabber::VerifyJIDWhiteboard $wtop]} {
	return
    }
    
    # This must never fail (application/octet-stream as fallback).
    set mime [GetMimeTypeFromFileName $fileName]
    
    # Need to add jabber specific info to the 'optList', such as
    # to:, from:, type:, thread: etc.
    # 
    # -type and 'tojid' shall never be in conflict???
    foreach {key value} [::UI::ConfigureMain $wtop] {
	switch -- $key {
	    -type - -thread {
		lappend optList [string trimleft $key -]: $value
	    }
	}
    }
    
    set tojid $jstate($wtop,tojid)
    set isRoom 0
    
    if {[regexp {^(.+)@([^/]+)/([^/]+)} $tojid match name host res]} {
	
	# The 'tojid' is already complete with resource.
	set allJid3 $tojid
    	lappend optList from: $jstate(mejidres)
    } else {
	
	# If 'tojid' is without a resource, it can be a room.
	if {[$jstate(jlib) service isroom $tojid]} {
	    set isRoom 1
	    set allJid3 [$jstate(jlib) service roomparticipants $tojid]
	    
	    # Exclude ourselves.
	    foreach {meRoomJid nick} [$jstate(jlib) service hashandnick $tojid] \
	      { break }
	    set ind [lsearch $allJid3 $meRoomJid]
	    if {$ind >= 0} {
		set allJid3 [lreplace $allJid3 $ind $ind]
	    }
	    
	    # Be sure to have our room jid and not the real one.
     	    lappend optList from: $meRoomJid
	} else {
	    
	    # Else put to resource with highest priority.
	    set res [$jstate(roster) gethighestresource $tojid]
	    if {$res == ""} {
		
		# This is someone we haven't got presence from.
		set allJid3 $tojid
	    } else {
		set allJid3 $tojid/$res
	    }
	    lappend optList from: $jstate(mejidres)
	}
    }
    
    ::Jabber::Debug 2 "   allJid3=$allJid3"
    
    # We shall put to all resources. Treat each in turn.
    foreach jid3 $allJid3 {
	
	# If we are in a room all must be available, else check.
	if {$isRoom} {
	    set avail 1
	} else {
	    set avail [$jstate(roster) isavailable $jid3]
	}
	
	# Each jid must get its own to: attribute.
	set optjidList [concat $optList to: $jid3]
	
	::Jabber::Debug 2 "   jid3=$jid3, avail=$avail"
	
	if {$avail} {
	    if {[info exists jidToIP($jid3)]} {
		
		# This one had already told us its ip number, good!
		::Jabber::PutFile $wtop $fileName $mime $optjidList $jid3
	    } else {
		
		# This jid is online but has not told us its ip number.
		# We need to get this jid's ip number and register the
		# PutFile as a callback when receiving this ip.
		::Jabber::GetIPnumber $jid3 \
		  [list ::Jabber::PutFile $wtop $fileName $mime $optjidList]
	    }
	} else {
	    
	    # We need to tell this jid to get this file from a server,
	    # possibly as an OOB http transfer.
	    array set optArr $optList
	    if {[info exists optArr(Get-Url:)]} {
		$jstate(jlib) oob_set $jid3 ::Jabber::OOB::SetCallback  \
		  $optArr(Get-Url:)  \
		  -desc {This file is part of a whiteboard conversation.\
		  You were not online when I opened this file}
	    } else {
		puts "   missing optArr(Get-Url:)"
	    }
	}
    }
        
    # This is an activity that may not be registered with jabberlib's auto away
    # functions, and must therefore schedule it here. ???????
    $jstate(jlib) schedule_auto_away
}

# Jabber::PutFile --
#
#       Puts the file to the given jid provided the client has
#       told us its ip number.
#       Calls '::PutFileIface::PutFile' to do the real work for us.
#
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       fileName    the path to the file to be put.
#       'optList'   a list of 'key: value' pairs, resembling the html 
#                   protocol for getting files, but where most keys correspond
#                   to a valid "canvas create" option.
#       jid         fully qualified  "username@host/resource"
#       
# Results:

proc ::Jabber::PutFile {wtop fileName mime optList jid} {
    global  prefs
    variable jidToIP
    variable jstate
    
    ::Jabber::Debug 2 "::Jabber::PutFile: fileName=$fileName, optList='$optList', jid=$jid"
 
    if {![info exists jidToIP($jid)]} {
	puts "::Jabber::PutFile: Houston, we have a problem. \
	  jidToIP($jid) not there"
	return
    }
    
    # Check first that the user has not closed the window.
    if {![winfo exists [string trimright $wtop "."]]} {
	return
    }
    
    # Get the remote (network) file name (no path, no uri encoding).
    set dstFile [NativeToNetworkFileName $fileName]

    if {[catch {
	::putfile::put $fileName $jidToIP($jid) $prefs(remotePort)   \
	  -mimetype $mime -timeout [expr 1000 * $prefs(timeout)]     \
	  -optlist $optList -filetail $dstFile                       \
	  -progress ::PutFileIface::PutProgress                      \
	  -command [list ::PutFileIface::PutCommand $wtop]
    } tok]} {
	tk_messageBox -title [::msgcat::mc {File Transfer Error}]  \
	  -type ok -message $tok
    } else {
	::PutFileIface::RegisterPutSession $tok $wtop
    }
}

# Jabber::SetPrivateData --
#
#       Set ip & port of our two servers at out public space at the server
#       for others to fetch.
#       
# Arguments:
#       
# Results:
#       none.

proc ::Jabber::SetPrivateData { } {
    global  prefs
    
    variable jstate
    
    # Build tag and attributes lists to 'private_set'.
    set ip [::Network::GetThisOutsideIPAddress]
    $jstate(jlib) private_set "coccinella:public"     \
      [list ::Jabber::SetPrivateDataCallback private_set]   \
      -server [list $ip [list resource $jstate(meres)  \
      port $prefs(thisServPort)]]       \
      -httpd [list $ip [list resource $jstate(meres)   \
      port $prefs(httpdPort)]]
}

# Jabber::SetPrivateDataCallback --
#
#       Records if this was succesful or not. Be silent.

proc ::Jabber::SetPrivateDataCallback {jid jlibName what theQuery} {
    
    variable jidPublic

    if {[string equal $what "error"]} {
	set jidPublic(haveit) 0
    } else {
	set jidPublic(haveit) 1
    }
}

# Jabber::GetPrivateData --
#
#       Gets ip & port of the two servers for the specified jid.
#       
# Arguments:
#       jid         get data from this jid.
#       
# Results:
#       shows window.

proc ::Jabber::GetPrivateData {jid} {
    variable jstate
    
    # Build tag and attributes lists to 'private_set'.
    $jstate(jlib) private_get {coccinella:public} {server httpd}  \
      [list ::Jabber::GetPrivateDataCallback $jid]
}

# Jabber::GetPrivateDataCallback --
#
#       Parses the callback when receiving the iq result (or error).

proc ::Jabber::GetPrivateDataCallback {jid jlibName what theQuery} {
    
    variable jidPublic
    
    if {[string equal $what "error"]} {
	foreach {errcode errmsg} $theQuery {}
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamesserrgetpublic $jid $errcode $errmsg]]
	return
    }
    
    # Parse the query element:
    # theQuery='{query {xmlns coccinella:public} 0 {} {
    #     {server {resource home port 8235} 0 192.168.0.4 {}} 
    #     {httpd {resource home port 8077} 0 192.168.0.4 {}}}}'
    set childList [lindex $theQuery 4]
    foreach {tag attrlist empty chdata c} $childList {
	foreach {name val} $attrlist {
	    set $name $val
	}
	set jidPublic($jid,$resource,$tag) $chdata
	foreach {name val} $attrlist {
	    if {[string equal $name "resource"]} {
		continue
	    }
	    
	    # Typically: jidPublic(matben@athlon.se,home,serverport).
	    set jidPublic($jid,$resource,$tag$name) $val
	}
    }
}

# Jabber::SetUserProfile --
#
#       Sets or replaces a user profile. Format:
#  jserver(profile,selected)  profile picked in user info
#  jserver(profile):          {$profile1 {$server1 $username $password $resource} \
#                              $profile2 {$server2 $username2 $password2 $resource2} ... }
#       
# Arguments:
#       profile     if empty, make a new unique profile, else, create this,
#                   possibly replace if exists already.
#       server      Jabber server name.
#       username
#       password
#       
# Results:
#       none.

proc ::Jabber::SetUserProfile {profile server username password {res {coccinella}}} {
    
    variable jserver
    
    ::Jabber::Debug 2 "profile=$profile, s=$server, u=$username, p=$password, r=$res"

    # Be sure to sync jserver(all) first.
    set jserver(all) {}
    array set jserverArr $jserver(profile)
    foreach prof [array names jserverArr] {
	lappend jserver(all) $prof
    }
    
    # Create a new unique profile name.
    if {[string length $profile] == 0} {
	set profile $server

	# Make sure that 'profile' is unique.
	if {[lsearch -exact $jserver(all) $profile] >= 0} {
	    set i 2
	    set tmpprof $profile
	    set profile ${tmpprof}-${i}
	    while {[lsearch -exact $jserver(all) $profile] >= 0} {
		incr i
		set profile ${tmpprof}-${i}
	    }
	}
    }
    set jserverArr($profile) [list $server $username $password $res]
    set jserver(profile) [array get jserverArr]
    set jserver(profile,selected) $profile
    lappend jserver(all) $profile
    set jserver(all) [lsort -unique $jserver(all)]
    return ""
}

proc ::Jabber::GetAllWinGeom { } {
    
    set geomList {}
    set geomList [concat $geomList [::Jabber::GroupChat::GetWinGeom]]
    return $geomList
}

proc ::Jabber::GetAllPanePos { } {
    global  prefs wDlgs
        
    
    # Each proc below return any stored pane position, but returns empty if
    # dialog was never built.
    set paneList {}
    
    # Chat:
    set pos [::Jabber::Chat::GetPanePos]
    if {$pos == ""} {
	set pos [list $wDlgs(jchat) $prefs(paneGeom,$wDlgs(jchat))]
    }
    set paneList [concat $paneList $pos]
    
    # Mailbox:
    set pos [::Jabber::MailBox::GetPanePos]
    if {$pos == ""} {
	set pos [list $wDlgs(jinbox) $prefs(paneGeom,$wDlgs(jinbox))]
    }
    set paneList [concat $paneList $pos]
    
    # Groupchat:
    set pos [::Jabber::GroupChat::GetPanePos]
    if {$pos == ""} {
	set pos [list groupchatDlgVert $prefs(paneGeom,groupchatDlgVert) \
	  groupchatDlgHori $prefs(paneGeom,groupchatDlgHori)]
    }
    set paneList [concat $paneList $pos]
    
    return $paneList
}

# Jabber::FormatAnyDelayElem --
#
#       Takes a list of x-elements, finds any 'jabber:x:delay' x-element,
#       and formats a human readable text string. If no such element,
#       returns empty.
#       
# Arguments:
#       xlist       Must be an hierarchical xml list of <x> elements.  
#       
# Results:
#       Pretty formatted date string or empty.

proc ::Jabber::FormatAnyDelayElem {xlist} {
    
    set ans ""
    foreach xelem $xlist {
	foreach {tag attrlist empty chdata sub} $xelem { break }
	catch {unset attrArr}
	array set attrArr $attrlist
	if {[info exists attrArr(xmlns)] &&  \
	  [string equal $attrArr(xmlns) "jabber:x:delay"]} {
	    
	    # This is ISO 8601 and 'clock scan' shall work here!
	    if {[info exists attrArr(stamp)]} {
		set secs [clock scan $attrArr(stamp)]
		set ans [SmartClockFormat $secs]
	    }
	}
    }
    return $ans
}

#-------------------------------------------------------------------------------

# Jabber::GetPresenceIcon --
#
#       Returns the image appropriate for 'presence', and any 'show'
#       attribute.
#       If presence is to make sense, the jid shall be a 3-tier jid.

proc ::Jabber::GetPresenceIcon {jid presence args} {
    
    variable gShowIcon
    variable jstate
    array set argsArr $args
    
    # Any show attribute?
    set keyStatus $presence
    if {[info exists argsArr(-show)] && [string length $argsArr(-show)]} {
	set keyStatus $argsArr(-show)
    } elseif {[info exists argsArr(-subscription)] &&   \
      [string equal $argsArr(-subscription) "none"]} {
	set keyStatus "subnone"
    }
    
    # If whiteboard:
    if {[$jstate(browse) isbrowsed $jid]} {
	set namespaces [$jstate(browse) getnamespaces $jid]
	if {[lsearch $namespaces "coccinella:wb"] >= 0} {
	    append keyStatus ",wb"
	}
    }
    return $gShowIcon($keyStatus)
}
    

# Jabber::PresenceSounds --
#
#       Makes an alert sound corresponding to the jid's presence status.
#
# Arguments:
#       jid  
#       presence    "available", "unavailable", or "unsubscribed"
#       args        list of '-key value' pairs of presence attributes.
#       
# Results:
#       roster tree updated.

proc ::Jabber::PresenceSounds {jid presence args} {
    
    array set argsArr $args
    
    # Alert sounds.
    if {[info exists argsArr(-show)] && [string equal $argsArr(-show) "chat"]} {
	::Sounds::Play statchange
    } elseif {[string equal $presence "available"]} {
	::Sounds::Play online
    } elseif {[string equal $presence "unavailable"]} {
	::Sounds::Play offline
    }    
}

# Jabber::Popup --
#
#       Handle popup menus in jabber dialogs, typically from right-clicking
#       a thing in the roster, browser, etc.
#       
# Arguments:
#       what        any of "roster", "browse", or "groupchat", or "agents"
#       w           widget that issued the command
#       v           for the tree widget it is the item path, 
#                   for text the jidhash.
#       
# Results:
#       popup menu displayed

proc ::Jabber::Popup {what w v x y} {
    global  wDlgs this
    
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Popup what=$what, w=$w, v='$v', x=$x, y=$y"
    
    # The last element of $v is either a jid, (a namespace,) 
    # a header in roster, a group, or an agents xml tag.
    # The variables name 'jid' is a misnomer.
    # Find also type of thing clicked, 'typeClicked'.
    
    set typeClicked ""
    switch -- $what {
	roster {
	    
	    # The last element of atree item if user is a 3-tier jid for
	    # online users and a 2-tier jid else.
	    set jid [lindex $v end]
	    set status [string tolower [lindex $v 0]]
	    switch -- [llength $v] {
		1 {
		    set typeClicked head
		}
		default {
		    
		    # Must let 'jid' refer to 2-tier jid for commands to work!
		    if {[regexp {^(.+@[^/]+)(/.+)?$} $jid match jid2 res]} {
			
			set jid3 $jid
			set jid $jid2
			set namespaces [$jstate(browse) getnamespaces $jid3]
			if {[lsearch $namespaces "coccinella:wb"] >= 0} {
			    set typeClicked wb
			} else {
			    set typeClicked user
			}			
		    } elseif {[llength $v] == 2} {
			
			# Get a list of all jid's in this group. type=user.
			# Must strip off all resources.
			set typeClicked group
			set jid {}
			foreach jid3 [$w children $v] {
			    set jid2 $jid3
			    regexp {^(.+@[^/]+)(/.+)?$} $jid3 match jid2
			    lappend jid $jid2
			}
			set jid [list $jid]
		    }
		}
	    }
	}
	browse {
	    set jid [lindex $v end]
	    set namespaces [$jstate(browse) getnamespaces $jid]
	    if {[regexp {^.+@[^/]+(/.+)?$} $jid match res]} {
		set typeClicked user
		if {[$jstate(jlib) service isroom $jid]} {
		    set typeClicked room
		}
	    } elseif {$jid != ""} {
		set typeClicked jid
	    }
	}
	groupchat {	    
	    set jid $v
	    if {[regexp {^.+@[^/]+(/.+)?$} $jid match res]} {
		set typeClicked user
	    }
	}
	agents {
	    set jid [lindex $v end]
	    set childs [$w children $v]
	    if {[regexp {(register|search|groupchat)} $jid match service]} {
		set typeClicked $service
		set jid [lindex $v end-1]
	    } elseif {$jid != ""} {
		set typeClicked jid
	    }
	    set services {}
	    foreach c $childs {
		if {[regexp {(register|search|groupchat)} $c match service]} {
		    lappend services $service
		}
	    }
	}
    }
    if {[string length $jid] == 0} {
	set typeClicked ""	
    }
    set X [expr [winfo rootx $w] + $x]
    set Y [expr [winfo rooty $w] + $y]
    
    ::Jabber::Debug 2 "    jid=$jid, typeClicked=$typeClicked"
    
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
    set m $jstate(wpopup,$what)
    set i 0
    catch {destroy $m}
    menu $m -tearoff 0
    
    foreach {item type cmd} $jstate(popup,$what,def) {
	if {[string index $cmd 0] == "@"} {
	    set mt [menu ${m}.sub${i} -tearoff 0]
	    set locname [::msgcat::mc $item]
	    $m add cascade -label $locname -menu $mt -state disabled
	    eval [string range $cmd 1 end] $mt
	    incr i
	} elseif {[string equal $item "separator"]} {
	    $m add separator
	    continue
	} else {
	    regsub -all &jid $cmd [list $jid] cmd
	    set cmd [subst -nocommands $cmd]
	    set locname [::msgcat::mc $item]
	    $m add command -label $locname -command "after 40 $cmd" -state disabled
	}
	if {![::Jabber::IsConnected]} {
	    continue
	}
	if {[string equal $type "any"]} {
	    $m entryconfigure $locname -state normal
	    continue
	}
	
	# State of menu entry. We use the 'type' and 'typeClicked' to sort
	# out which capabilities to offer for the clicked item.
	set state disabled
	switch -- $what {
	    roster {
		switch -- $type {
		    user {
			if {[string equal $typeClicked "user"] || \
			  [string equal $typeClicked "wb"]} {
			    set state normal
			}
			if {($status == "offline") &&  \
			  ([string match -nocase "*chat*" $item])} {
			    set state disabled
			}
		    }
		    users {
			if {($typeClicked == "user") ||  \
			  ($typeClicked == "group") ||  \
			  ($typeClicked == "wb")} {
			    set state normal
			}
		    }
		    wb {
			if {[string equal $typeClicked "wb"]} {
			    set state normal
			}
		    }
		}
	    }
	    browse {
		switch -- $type {
		    user {
			if {[string equal $typeClicked "user"]} {
			    set state normal
			}
		    }
		    room {
			if {[string equal $typeClicked "room"]} {
			    set state normal
			}
		    }
		    jid {
			switch -- $typeClicked {
			    jid - user {
				set state normal
			    }
			}
		    } 
		    search - register {
			if {[lsearch $namespaces "jabber:iq:${type}"] >= 0} {
			    set state normal
			}
		    }
		    wb {
			switch -- $typeClicked {
			    room - user {
				set state normal
			    }
			}
		    }
		}
	    }
	    groupchat {	    
		if {($type == "user") && ($typeClicked == "user")} {
		    set state normal
		}
		if {($type == "wb") && ($typeClicked == "user")} {
		    set state normal
		}
	    }
	    agents {
		if {[string equal $type $typeClicked]} {
		    set state normal
		} elseif {[lsearch $services $type] >= 0} {
		    set state normal
		}
	    }
	}
	if {[string equal $state "normal"]} {
	    $m entryconfigure $locname -state normal
	}
    }   
    
    # This one is needed on the mac so the menu is built before it is posted.
    update idletasks
    
    # Post popup menu.
    tk_popup $m [expr int($X) - 10] [expr int($Y) - 10]   
    
    # Mac bug... (else can't post menu while already posted if toplevel...)
    if {[string match "mac*" $this(platform)]} {
	catch {destroy $m}
	update
    }
}

# Jabber::BuildPresenceMenu --
# 
#       Sets presence status. Used in popup only so far.
#       
# Arguments:
#       mt          menu widget
#       
# Results:
#       none.

proc ::Jabber::BuildPresenceMenu {mt} {
    global  prefs
    variable gShowIcon
    variable mapShowTextToElem

    if {$prefs(haveMenuImage)} {
	foreach name {available away dnd invisible unavailable} {
	    $mt add radio -label $mapShowTextToElem($name)  \
	      -variable ::Jabber::jstate(status) -value $name   \
	      -command [list ::Jabber::SetStatus $name]  \
	      -compound left -image $gShowIcon($name)
	}
    } else {
	foreach name {available away dnd invisible unavailable} {
	    $mt add radio -label $mapShowTextToElem($name)  \
	      -variable ::Jabber::jstate(status) -value $name   \
	      -command [list ::Jabber::SetStatus $name]
	}
    }
}
    
# Jabber::BuildStatusMenuDef --
# 
#       Builds a menuDef list for the status menu.
#       
# Arguments:
#       
# Results:
#       menuDef list.

proc ::Jabber::BuildStatusMenuDef { } {
    global  prefs
    variable gShowIcon

    set statMenuDef {}
    if {$prefs(haveMenuImage)} {
	foreach mName {mAvailable mAway mDoNotDisturb  \
	  mExtendedAway mInvisible mNotAvailable}      \
	  name {available away dnd xa invisible unavailable} {
	    lappend statMenuDef [list radio $mName  \
	      [list ::Jabber::SetStatus $name] normal {}  \
	      [list -variable ::Jabber::jstate(status) -value $name  \
	      -compound left -image $gShowIcon($name)]]
	}
	lappend statMenuDef {separator}   \
	  {command mAttachMessage         \
	  {::Jabber::SetStatusWithMessage $wDlgs(jpresmsg)}  normal {}}
    } else {
	foreach mName {mAvailable mAway mDoNotDisturb  \
	  mExtendedAway mInvisible mNotAvailable}      \
	  name {available away dnd xa invisible unavailable} {
	    lappend statMenuDef [list radio $mName  \
	      [list ::Jabber::SetStatus $name] normal {} \
	      [list -variable ::Jabber::jstate(status) -value $name]]
	}
	lappend statMenuDef {separator}   \
	  {command mAttachMessage         \
	  {::Jabber::SetStatusWithMessage $wDlgs(jpresmsg)}  normal {}}
    }
    return $statMenuDef
}
    
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
    
    variable jerror

    if {[string equal $type "error"]} {
	set msg [::msgcat::mc jamesserrlastactive $from [lindex $subiq 1]]
	if {$silent} {
	    lappend jerror [list [clock format [clock seconds] -format "%H:%M:%S"]  \
	      $from $msg]	    
	} else {
	    tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	      -message [FormatTextForMessageBox $msg]
	}
    } else {
	array set attrArr [lindex $subiq 1]
	if {![info exists attrArr(seconds)]} {
	    tk_messageBox -title [::msgcat::mc {Last Activity}] -icon info  \
	      -type ok -message [FormatTextForMessageBox \
	      [::msgcat::mc jamesserrnotimeinfo $from]]
	} else {
	    set secs [expr [clock seconds] - $attrArr(seconds)]
	    set uptime [clock format $secs -format "%a %b %d %H:%M:%S"]
	    if {[lindex $subiq 3] != ""} {
		set msg "The message: [lindex $subiq 3]"
	    } else {
		set msg {}
	    }
	    
	    # Time interpreted differently for different jid types.
	    if {$from != ""} {
		if {[regexp {^.+@[^/]+/.+$} $from match]} {
		    set msg1 [::msgcat::mc jamesstimeused $from]
		} elseif {[regexp {^.+@[^/]+$} $from match]} {
		    set msg1 [::msgcat::mc jamesstimeconn $from]
		} else {
		    set msg1 [::msgcat::mc jamesstimeservstart $from]
		}
	    } else {
		set msg1 [::msgcat::mc jamessuptime]
	    }
	    tk_messageBox -title [::msgcat::mc {Last Activity}] -icon info  \
	      -type ok -message \
	      [FormatTextForMessageBox "$msg1 $uptime. $msg"]
	}
    }
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

    variable jerror

    if {[string equal $type "error"]} {
	if {$silent} {
	    lappend jerror [list [clock format [clock seconds] -format "%H:%M:%S"]  \
	      $from "We received an error when quering its time info.\
	      The error was: [lindex $subiq 1]"]	    
	} else {
	    tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	      -message [FormatTextForMessageBox \
	      [::msgcat::mc jamesserrtime $from [lindex $subiq 1]]]
	}
    } else {
	
	# Display the cdata of <display>, or <utc>.
	foreach child [lindex $subiq 4] {
	    set tag [lindex $child 0]
	    set $tag [lindex $child 3]
	}
	if {[info exists display]} {
	    set msg $display
	} elseif {[info exists utc]} {
	    set msg $utc
	} elseif {[info exists tz]} {
	    set msg $tz
	} else {
	    set msg {unknown}
	}
	tk_messageBox -title [::msgcat::mc {Local Time}] -icon info -type ok -message \
	  [FormatTextForMessageBox [::msgcat::mc jamesslocaltime $from $msg]]
    }
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
    $jstate(jlib) get_version $to [list ::Jabber::GetVersionResult $to $opts(-silent)]
}

proc ::Jabber::GetVersionResult {from silent jlibname type subiq} {
    global  sysFont prefs this
    
    variable jerror
    
    if {[string equal $type "error"]} {
	if {$silent} {
	    lappend jerror [list [clock format [clock seconds] -format "%H:%M:%S"]  \
	      $from [::msgcat::mc jamesserrvers $from [lindex $subiq 1]]]
	} else {
	    tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	      -message [FormatTextForMessageBox \
	      [::msgcat::mc jamesserrvers $from [lindex $subiq 1]]]
	}
    } else {
	set w .jvers
	catch {delete $w}
	toplevel $w -background $prefs(bgColGeneral)
	if {[string match "mac*" $this(platform)]} {
	    eval $::macWindowStyle $w movableDBoxProc
	} else {
	    wm transient $w .
	}
	wm title $w [::msgcat::mc {Version Info}]
	pack [label $w.icon -bitmap info] -side left -anchor n -padx 10 -pady 10
	pack [label $w.msg -text [::msgcat::mc javersinfo $from] -font $sysFont(sb)] \
	  -side top -padx 8 -pady 4
	pack [frame $w.fr] -padx 10 -pady 4 -side top 
	set i 0
	foreach child [lindex $subiq 4] {
	    label $w.fr.l$i -text "[lindex $child 0]:"
	    label $w.fr.lr$i -text "[lindex $child 3]:"
	    grid $w.fr.l$i -column 0 -row $i -sticky e
	    grid $w.fr.lr$i -column 1 -row $i -sticky w
	    incr i
	}
	pack [button $w.ok -text [::msgcat::mc OK] -width 8 \
	  -command "destroy $w"] -side right -padx 10 -pady 8
	wm resizable $w 0 0
	bind $w <Return> "$w.ok invoke"
	tkwait window $w
    }
}

# Jabber::::GetAutoupdate --
#
#       Respond to an incoming 'jabber:iq:autoupdate' result.

proc ::Jabber::GetAutoupdate {from jlibname type subiq} {
    global  sysFont prefs this
    
    variable jprefs
    
    if {[string equal $type "error"]} {
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamesserrautoupdate $from [lindex $subiq 1]]]
	return
    } 
    set w .jautoud
    catch {delete $w}
    toplevel $w -background $prefs(bgColGeneral)
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {
	wm transient $w .
    }
    wm title $w [::msgcat::mc {Software Update}]
    
    # Global frame.
    set wfr $w.frall
    pack [frame $wfr -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 12 -ipady 4
    message $wfr.msg -width 260 -font $sysFont(sb) -text  \
      [::msgcat::mc jaupdatemsg]
    pack $wfr.msg -side top -fill both -expand 1
    label $wfr.ver -text \
      [::msgcat::mc jaupdatevers $prefs(fullVers)]
    pack $wfr.ver -side top -anchor w -padx 16
    
    # Map tag to descriptive name.
    array set tagDesc {
	release {New release}
	beta {Beta version}
	dev {Developers only}
    }
    
    # Loop through all children of <query> element.
    set frmid [frame $w.frall.frmid -borderwidth 0]
    pack $frmid -fill both -expand 1 -side top
    set i 0
    foreach child [wrapper::getchildren $subiq] {	
	foreach {tag attrlist empty chdata sub} $child { break }
	catch {unset attrArr}
	array set attrArr $attrlist
	if {[info exists tagDesc($tag)]} {
	    set txt $tagDesc($tag)
	} else {
	    set txt $tag
	}
	set fr [LabeledFrame2 $frmid.f$i $txt]
	pack $frmid.f$i -side top -fill x -padx 0 -pady 0
	if {[info exists attrArr(priority)]} {
	    label $fr.pri -text [::msgcat::mc jaupdatepri $attrArr(priority)]
	    pack $fr.pri -side top -padx 12 -pady 4 -anchor w
	}
	foreach item [wrapper::getchildren $child] {
	    foreach {stag sattrlist sempty schdata ssub} $item { break }
	    switch -- $stag {
		desc {
		    message $fr.desc -width 220 -font $sysFont(s) -text $schdata
		    pack $fr.desc -side top -padx 12 -anchor w
		}
		version {
		    label $fr.version -text [::msgcat::mc jaupdatenewver $schdata]
		    pack $fr.version -side top -padx 12 -anchor w
		}
		url {
		    ::Text::URLLabel $fr.url $schdata -font $sysFont(s)   \
		      -bg $prefs(bgColGeneral) 
		    pack $fr.url -side top -padx 12 -anchor w
		}
	    }
	}
	incr i
    }
    
    pack [checkbutton $wfr.show -onvalue 0 -offvalue 1 \
      -variable jprefs(autoupdateShow,$prefs(fullVers)) \
      -text "  [::msgcat::mc jaupdateremind]"]   \
      -side top -anchor w -padx 12
    pack [frame $wfr.bot] -side bottom -fill both -expand 1
    pack [button $wfr.bot.ok -text [::msgcat::mc OK] -default active -width 8 \
      -command "destroy $w"] -side right -padx 10 -pady 8
    wm resizable $w 0 0
    bind $w <Return> "$wfr.bot.ok invoke"
    tkwait window $w
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
    
    # The MUC, Multi User Chat component (not implemented here):
    # <query xmlns='jabber:iq:version'><name>MU-Conference</name><version>0.4cvs</version>
    #	<os>Linux 2.4.17</os></query>
    
    set name ""
    set version ""
    foreach child [lindex $subiq 4] {
	set tag [lindex $child 0]
	set $tag [lindex $child 3]
    }
		
    # This is a VERY rude ad hoc method of figuring out if the
    # server has a conference component.
    if {($name == "conference") && ($version != "1.0") && ($version != "1.1")} {
	set jstate(conference,$confjid) 1
	set jstate(groupchattype,$confjid) "conference"
    } elseif {[string match -nocase "*mu*"]} {
	set jstate(groupchattype,$confjid) "muc"
    }
}
    
# Jabber::ParseGetVersion --
#
#       Respond to an incoming 'jabber:iq:version' get query.

proc ::Jabber::ParseGetVersion {args} {
    global  prefs
    variable jstate
    
    ::Jabber::Debug 2 "Jabber::ParseGetVersion args='$args'"
    
    array set argsArr $args
    
    # Return any id!
    set opts {}
    if {[info exists argsArr(-id)]} {
	set opts [list -id $argsArr(-id)]
    }
    
    set subtags [list  \
      [wrapper::createtag name -chdata {Coccinella}]  \
      [wrapper::createtag version  \
      -chdata $prefs(majorVers).$prefs(minorVers).$prefs(releaseVers)]  \
      [wrapper::createtag os -chdata $::tcl_platform(os)] ]
    set xmllist [wrapper::createtag query -subtags $subtags  \
      -attrlist {xmlns jabber:iq:version}]
    if {[info exists argsArr(-from)]} {
	lappend opts -to $argsArr(-from)
    }
    eval {$jstate(jlib) send_iq "result" $xmllist} $opts

    # Tell jlib's iq-handler that we handled the event.
    return 1
}
    
# Jabber::ParseGetTime --
#
#       Respond to an incoming 'jabber:iq:time' get query.

proc ::Jabber::ParseGetTime {args} {
    global  prefs
    variable jstate
    
    ::Jabber::Debug 2 "::Jabber::ParseGetTime args='$args'"
    
    array set argsArr $args
    
    # Return any id!
    set opts {}
    if {[info exists argsArr(-id)]} {
	set opts [list -id $argsArr(-id)]
    }
    set secs [clock seconds]
    set gmt [clock format $secs -format "%Y%m%dT%H:%M:%S" -gmt 1]
    set display [clock format $secs -gmt 1]
    set subtags [list  \
      [wrapper::createtag utc -chdata $gmt]  \
      [wrapper::createtag display -chdata $display]  \
      [wrapper::createtag tz -chdata GMT]]
    set xmllist [wrapper::createtag query -subtags $subtags  \
      -attrlist {xmlns jabber:iq:time}]
    if {[info exists argsArr(-from)]} {
	lappend opts -to $argsArr(-from)
    }
    eval {$jstate(jlib) send_iq "result" $xmllist} $opts

    # Tell jlib's iq-handler that we handled the event.
    return 1
}
        
# Jabber::ParseGetBrowse --
#
#       Respond to an incoming 'jabber:iq:browse' get query.
#       
# Results:
#       boolean (0/1) telling if this was handled or not.

proc ::Jabber::ParseGetBrowse {args} {
    global  prefs    
    variable jstate

    ::Jabber::Debug 2 "::Jabber::ParseGetBrowse: args='$args'"
    
    array set argsArr $args
    if {![info exists argsArr(-from)]} {
	return 0
    }
    
    # Return any id!
    set opts {}
    if {[info exists argsArr(-id)]} {
	set opts [list -id $argsArr(-id)]
    }

    # List everything this client supports.
    set subtags [list  \
      [wrapper::createtag "ns" -chdata "jabber:client"]         \
      [wrapper::createtag "ns" -chdata "jabber:iq:autoupdate"]  \
      [wrapper::createtag "ns" -chdata "jabber:iq:browse"]      \
      [wrapper::createtag "ns" -chdata "jabber:iq:conference"]  \
      [wrapper::createtag "ns" -chdata "jabber:iq:last"]        \
      [wrapper::createtag "ns" -chdata "jabber:iq:oob"]         \
      [wrapper::createtag "ns" -chdata "jabber:iq:roster"]      \
      [wrapper::createtag "ns" -chdata "jabber:iq:time"]        \
      [wrapper::createtag "ns" -chdata "jabber:iq:version"]     \
      [wrapper::createtag "ns" -chdata "jabber:x:autoupdate"]   \
      [wrapper::createtag "ns" -chdata "jabber:x:data"]         \
      [wrapper::createtag "ns" -chdata "coccinella:public"]     \
      [wrapper::createtag "ns" -chdata "coccinella:wb"]]
    
    set attr [list xmlns jabber:iq:browse jid $jstate(mejidres)  \
      type client category user]
    set xmllist [wrapper::createtag "user" -subtags $subtags -attrlist $attr]
    eval {$jstate(jlib) send_iq "result" $xmllist -to $argsArr(-from)} $opts
    
    # Tell jlib's iq-handler that we handled the event.
    return 1
}

# Jabber::SetSendState --
#
#       Set from the checkbutton.

proc ::Jabber::SetSendState {wtop state} {    
    variable jstate

    set jstate($wtop,doSend) $state
}

proc ::Jabber::GetSendState {wtop} {    
    variable jstate

    return $jstate($wtop,doSend)
}

# The ::Jabber::WB:: namespace -------------------------------------------------

namespace eval ::Jabber::WB:: {
   
}

# Jabber::WB::NewWhiteboard --
#
#       Starts a new whiteboard session.
#       
# Arguments:
#       jid         2-tier jid with no /resource (room participants???)
#       args        -thread
#       
# Results:
#       $wtop; may create new toplevel whiteboard

proc ::Jabber::WB::NewWhiteboard {jid args} {
    global  wDlgs    
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::WB::NewWhiteboard jid=$jid, args='$args'"
    
    set haveMultiinstance 1
    array set argsArr $args
    
    if {$haveMultiinstance} {
	
	# Make a fresh whiteboard window:
	#    jid is room: groupchat live
	#    jid is ordinary available user: chat
	#    jid is ordinary but unavailable user: normal message	
	set isRoom [$jstate(jlib) service isroom $jid]
	set isAvailable [$jstate(roster) isavailable $jid]
	
    	::Jabber::Debug 2 "    isRoom=$isRoom, isAvailable=$isAvailable"
	
	if {$isRoom} {
	    
	    # Must enter room in the usual way if not there already.
	    set allRooms [$jstate(jlib) service allroomsin]
	    if {[lsearch $allRooms $jid] < 0} {
		set ans [::Jabber::GroupChat::EnterRoom $wDlgs(jenterroom) \
		  -roomjid $jid -autoget 1]
		if {$ans == "cancel"} {
		    return
		}
	    }
	    set roomName [$jstate(browse) getname $jid]    
	    if {[llength $roomName]} {
		set title "Groupchat room $roomName"
	    } else {
		set title "Groupchat room $jid"
	    }
	    set wbOpts [list -type groupchat -title $title -jid $jid \
	      -toentrystate disabled -sendbuttonstate disabled \
	      -serverentrystate disabled]
	    set sendLive 1
	} elseif {$isAvailable} {
	    if {[info exists argsArr(-thread)]} {
	        set threadID $argsArr(-thread)
	    } else {
	    
	    	# Make unique thread id.
	    	set threadID [::sha1pure::sha1 "$jstate(mejid)[clock seconds]"]
	    }
	    set name [$jstate(roster) getname $jid]
	    if {[string length $name]} {
	    	set title "Chat with $name"
	    } else {
	    	set title "Chat with $jid"
	    }
	    set wbOpts [list -type chat -thread $threadID -title $title  \
	      -toentrystate disabled -jid $jid -sendbuttonstate disabled  \
	      -serverentrystate disabled]
	    set sendLive 1
	} else {
	    set name [$jstate(roster) getname $jid]
	    if {[string length $name]} {
	    	set title "Send Message to $name"
	    } else {
	    	set title "Send Message to $jid"
	    }
	    set wbOpts [list -type normal -title $title -jid $jid  \
	      -toentrystate disabled -serverentrystate disabled]
	    set sendLive 0
	}
	
	set wtop [eval {::UI::NewMain} $wbOpts]
	set jstate($wtop,doSend) $sendLive
    } else {
	set wtop .
	set ans [tk_messageBox -type yesno -default yes -icon warning  \
	  -message [FormatTextForMessageBox [::msgcat::mc jamesswarberasewb]]]
	if {$ans == "yes"} {
	    
	    # Probably should not send this???
	    set jstate(.,doSend) 0
	    DoEraseAll .
	    set jstate(.,doSend) 1
	}
	set jstate(.,tojid) $jid
	raise .
    }
    return $wtop
}

# ::Jabber::WB::ChatMsg, GroupChatMsg --
# 
#       Handles incoming chat/groupchat message aimed for a whiteboard.
#       It may not exist, for instance, if we receive a new chat thread.
#       Then create a specific whiteboard for this chat/groupchat.
#       
# Arguments:
#       args        -from, -thread,...

proc ::Jabber::WB::ChatMsg {args} {
    
    upvar ::Jabber::jstate jstate

    array set argsArr $args
    ::Jabber::Debug 2 "::Jabber::WB::ChatMsg args='$args'"
    
    set jid2 $argsArr(-from)
    regexp {^(.+@[^/]+)(/.+)?$} $argsArr(-from) match jid2 res

    # This one returns empty if not exists.
    set wtop [::UI::GetWtopFromJabberType "chat" $argsArr(-from)  \
      $argsArr(-thread)]
    if {$wtop == ""} {
	set wtop [eval {::Jabber::WB::NewWhiteboard $jid2} $args]
    }
    foreach line $argsArr(-whiteboard) {
	eval {ExecuteClientRequest $wtop $jstate(sock) ip port $line} $args
    }     
}

proc ::Jabber::WB::GroupChatMsg {args} {
    
    upvar ::Jabber::jstate jstate

    array set argsArr $args
    
    # The -from argument is either the room itself, or usually a user in
    # the room.
    if {![regexp {(^[^@]+@[^/]+)(/.+)?} $argsArr(-from) match roomjid]} {
	return -code error "The jid we got \"$argsArr(-from)\" was not well-formed!"
    }
    set wtop [::UI::GetWtopFromJabberType "groupchat" $roomjid]
    if {$wtop == ""} {
	set wtop [eval {::Jabber::WB::NewWhiteboard $roomjid} $args]
    }
    foreach line $argsArr(-whiteboard) {
	eval {ExecuteClientRequest $wtop $jstate(sock) ip port $line} $args
    } 
}

# ::Jabber::WB::DispatchToImporter --
# 
#       Is called as a response to a GET file event. 
#       We've received a file that should be imported somewhere.
#       
# Arguments:
#       mime
#       optList
#       args        -file, -where; for importer proc.

proc ::Jabber::WB::DispatchToImporter {mime optList args} {
    global  plugin
        
    set display 1
    array set optArr $optList
    switch -- $optArr(type:) {
	chat {
	    set wtop [::UI::GetWtopFromJabberType chat $optArr(from:) \
	      $optArr(thread:)]
	    if {$wtop == ""} {
		set wtop [::Jabber::WB::NewWhiteboard $optArr(from:)  \
		  -thread $optArr(thread:)]
	    }
	}
	groupchat {
	    if {![regexp {(^[^@]+@[^/]+)(/.+)?} $optArr(from:) match roomjid]} {
		return -code error  \
		  "The jid we got \"$optArr(from:)\" was not well-formed!"
	    }
	    set wtop [::UI::GetWtopFromJabberType groupchat $optArr(from:)]
	    if {$wtop == ""} {
		set wtop [::Jabber::WB::NewWhiteboard $roomjid]
	    }
	}
	default {
	    
	    # Normal message. Shall go in inbox ???????????
	    # We have no solution for this at the moment:
	    # 1) Offline users can never be sent to since no offline storage.
	    # 2) Online users may get these entities, but it is the importers
	    #    responsibility to import it which is not designed for
	    #    delayed display.
	    
	    set wtop [::UI::GetWtopFromJabberType normal $optArr(from:)]
	    set display 0
	}
    }
    
    set importPackage [GetPreferredPackage $mime]
    if {$display && [llength $importPackage]} {
	upvar ::${wtop}::wapp wapp
	
	eval {$plugin($importPackage,importProc) $wapp(can) $optList} $args
    }
}

# The ::Jabber::RostServ:: namespace -------------------------------------------

namespace eval ::Jabber::RostServ:: {
    
    # The notebook widget.
    variable nbframe
    variable wtoplevel
}

proc ::Jabber::RostServ::Show {w args} {
    
    upvar ::Jabber::jstate jstate

    array set argsArr $args
    if {[info exists argsArr(-visible)]} {
	set jstate(rostBrowseVis) $argsArr(-visible)
    }
    if {$jstate(rostBrowseVis)} {
	if {[winfo exists $w]} {
	    wm deiconify $w
	} else {
	    ::Jabber::RostServ::Build $w
	}
    } else {
	catch {wm withdraw $w}
    }
}

# Jabber::RostServ::Build --
#
#       A combination tabbed window with roster/agents/browser...
#       Must be persistant since roster/browser etc. are built once.

proc ::Jabber::RostServ::Build {w} {
    global  this sysFont prefs
    
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    variable nbframe
    variable wtoplevel

    if {[winfo exists $w]} {
	return
    }
    toplevel $w -class RostServ
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {
	wm transient $w .
    }
    set wtoplevel $w
    wm title $w [::msgcat::mc {Roster & Services}]
    wm protocol $w WM_DELETE_WINDOW [list ::Jabber::RostServ::Close $w]
    
    # Global frame.
    pack [frame $w.frall -borderwidth 0 -relief raised] -fill both -expand 1
    set frall $w.frall
    
    set nbframe [::mactabnotebook::mactabnotebook $frall.tn]
    pack $nbframe -fill both -expand 1
    
    # Make the notebook pages.
    # Start with the Roster page -----------------------------------------------
    set ro [$nbframe newpage {Roster} -text [::msgcat::mc Roster]]    
    pack [::Jabber::Roster::Build $ro.ro] -fill both -expand 1

    # Build only Browser and/or Agents page when needed.
    if {[info exists prefs(winGeom,$w)]} {
	wm geometry $w $prefs(winGeom,$w)
    }
    wm minsize $w 180 260
    wm maxsize $w 420 2000
}

# Jabber::RostServ::NewPage --
#
#       Makes sure that there exists a page in the notebook with the
#       given name. Build it if missing. On return the page always exists.

proc ::Jabber::RostServ::NewPage {name} {
    
    variable nbframe

    set pages [$nbframe pages]
    ::Jabber::Debug 2 "------::Jabber::RostServ::NewPage name=$name, pages=$pages"
    
    switch -exact $name {
	Agents {

	    # Agents page
	    if {[lsearch $pages Agents] < 0} {
		set ag [$nbframe newpage {Agents}]    
		pack [::Jabber::Agents::Build $ag.ag] -fill both -expand 1
	    }
	}
	Browser {
    
	    # Browser page
	    if {[lsearch $pages Browser] < 0} {
		set br [$nbframe newpage {Browser}]    
		pack [::Jabber::Browse::Build $br.br] -fill both -expand 1
	    }
	}
	default {
	    # Nothing
	    return -code error "Not recognized page name $name"
	}
    }    
}

proc ::Jabber::RostServ::Close {w} {
    
    upvar ::Jabber::jstate jstate

    set jstate(rostBrowseVis) 0
    if {[winfo exists $w]} {
	catch {wm withdraw $w}
	::UI::SaveWinGeom $w
    }
}

proc ::Jabber::RostServ::Pages { } {
    variable nbframe
    
    return [$nbframe pages]
}

proc ::Jabber::RostServ::LogoutClear { } {
    variable nbframe
    
    foreach page [$nbframe pages] {
	if {![string equal $page "Roster"]} {
	    $nbframe deletepage $page
	}
    }
}

# The ::Jabber::Roster:: namespace ---------------------------------------------

namespace eval ::Jabber::Roster:: {
    
    variable wtree    
    variable servtxt
}

# Jabber::Roster::Show --
#
#       Show the roster window.
#
# Arguments:
#       w      the toplevel window.
#       
# Results:
#       shows window.

proc ::Jabber::Roster::Show {w} {

    upvar ::Jabber::jstate jstate

    if {$jstate(rosterVis)} {
	if {[winfo exists $w]} {
	    catch {wm deiconify $w}
	} else {
	    ::Jabber::Roster::BuildToplevel $w
	}
    } else {
	catch {wm withdraw $w}
    }
}

# Jabber::Roster::BuildToplevel --
#
#       Build the toplevel roster window.
#
# Arguments:
#       w      the toplevel window.
#       
# Results:
#       shows window.

proc ::Jabber::Roster::BuildToplevel {w} {
    global  this sysFont prefs

    variable wtop
    variable servtxt

    if {[winfo exists $w]} {
	return
    }
    set wtop $w
    
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {
	wm transient $w .
    }
    wm title $w {Roster (Contact list)}
    wm protocol $w WM_DELETE_WINDOW [list ::Jabber::Roster::CloseDlg $w]
    wm group $w .
    
    # Toplevel menu for mac only. Only when multiinstance.
    if {0 && [string match "mac*" $this(platform)]} {
	set wmenu ${w}.menu
	menu $wmenu -tearoff 0
	::UI::MakeMenu $w ${wmenu}.apple   {}       $::UI::menuDefs(main,apple)
	::UI::MakeMenu $w ${wmenu}.file    mFile    $::UI::menuDefs(min,file)
	::UI::MakeMenu $w ${wmenu}.edit    mEdit    $::UI::menuDefs(min,edit)	
	::UI::MakeMenu $w ${wmenu}.jabber  mJabber  $::UI::menuDefs(main,jabber)
	$w configure -menu ${wmenu}
    }
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised] -fill both -expand 1
    
    # Top frame for info.
    set frtop $w.frall.frtop
    pack [frame $frtop] -fill x -side top -anchor w -padx 10 -pady 4
    label $frtop.la -text {Connected to:} -font $sysFont(sb)
    label $frtop.laserv -textvariable "[namespace current]::servtxt"
    pack $frtop.la $frtop.laserv -side left -pady 4
    set servtxt {not connected}

    # And the real stuff.
    pack [::Jabber::Roster::Build $w.frall.br] -side top -fill both -expand 1
    
    wm maxsize $w 320 800
    wm minsize $w 180 240
}

# Jabber::Roster::Build --
#
#       Makes mega widget to show the roster.
#
# Arguments:
#       w           frame window with everything.
#       
# Results:
#       w

proc ::Jabber::Roster::Build {w} {
    global  sysFont this wDlgs prefs
        
    variable wtree    
    variable wtreecanvas
    variable servtxt
    variable btedit
    variable btremove
    variable btrefresh
    variable selItem
    upvar ::Jabber::jprefs jprefs
        
    # The frame.
    frame $w -borderwidth 0 -relief flat

    # Tree frame with scrollbars.
    set wbox $w.box
    pack [frame $wbox -border 1 -relief sunken]   \
      -side top -fill both -expand 1 -padx 6 -pady 6
    set wtree $wbox.tree
    set wxsc $wbox.xsc
    set wysc $wbox.ysc
    set wtree [::tree::tree $wtree -width 220 -height 300 -silent 1  \
      -openicons triangle -treecolor {} -scrollwidth 400  \
      -xscrollcommand [list $wxsc set]       \
      -yscrollcommand [list $wysc set]       \
      -selectcommand ::Jabber::Roster::SelectCmd   \
      -doubleclickcommand ::Jabber::Roster::DoubleClickCmd   \
      -highlightcolor #6363CE -highlightbackground gray87]
    set wtreecanvas [$wtree getcanvas]
    if {[string match "mac*" $this(platform)]} {
	$wtree configure -buttonpresscommand  \
	  [list ::Jabber::Popup roster]
    } else {
	$wtree configure -rightclickcommand  \
	  [list ::Jabber::Popup roster]
    }
    scrollbar $wxsc -orient horizontal -command [list $wtree xview]
    scrollbar $wysc -orient vertical -command [list $wtree yview]
    grid $wtree -row 0 -column 0 -sticky news
    grid $wysc -row 0 -column 1 -sticky ns
    grid $wxsc -row 1 -column 0 -sticky ew
    grid columnconfigure $wbox 0 -weight 1
    grid rowconfigure $wbox 0 -weight 1    
    
    # Add main tree dirs.
    foreach gpres $jprefs(treedirs) {
	$wtree newitem [list $gpres] -dir 1 -text [::msgcat::mc $gpres]
    }
    foreach gpres $jprefs(closedtreedirs) {
	$wtree itemconfigure [list $gpres] -open 0
    }
    return $w
}

proc ::Jabber::Roster::CloseDlg {w} {
    
    upvar ::Jabber::jstate jstate

    catch {wm withdraw $w}
    set jstate(rosterVis) 0
}

proc ::Jabber::Roster::Refresh { } {
    
    upvar ::Jabber::jstate jstate

    # Get my roster.
    $jstate(jlib) roster_get ::Jabber::Roster::PushProc
}

# Jabber::Roster::SendRemove --
#
#       Method to remove another user from my roster.
#
#

proc ::Jabber::Roster::SendRemove { {jidArg {}} } {
    
    variable selItem
    upvar ::Jabber::jstate jstate

    ::Jabber::Debug 2 "::Jabber::Roster::SendRemove jidArg=$jidArg"

    if {[string length $jidArg]} {
	set jid $jidArg
    } else {
	set jid [lindex $selItem end]
    }
    set ans [tk_messageBox -title [::msgcat::mc {Remove Item}] -message  \
      [FormatTextForMessageBox [::msgcat::mc jamesswarnremove]]  \
      -icon warning -type yesno]
    if {[string equal $ans "yes"]} {
	$jstate(jlib) roster_remove $jid ::Jabber::Roster::PushProc
    }
}

# Jabber::Roster::SelectCmd --
#
#       Callback when selecting roster item in tree.
#
# Arguments:
#       w           tree widget
#       v           tree item path
#       
# Results:
#       button states set set.

proc ::Jabber::Roster::SelectCmd {w v} {
    
    variable btedit
    variable btremove
    variable selItem
    
    # Not used
    return
    
    set selItem $v
    if {[llength $v] && ([$w itemconfigure $v -dir] == 0)} {
	$btedit configure -state normal
	$btremove configure -state normal
    } else {
	$btedit configure -state disabled
	$btremove configure -state disabled
    }
}

# Jabber::Roster::DoubleClickCmd --
#
#       Callback when double clicking roster item in tree.
#
# Arguments:
#       w           tree widget
#       v           tree item path
#       
# Results:
#       button states set set.

proc ::Jabber::Roster::DoubleClickCmd {w v} {
    global  wDlgs
    
    upvar ::Jabber::jprefs jprefs

    if {[llength $v] && ([$w itemconfigure $v -dir] == 0)} {
	set jid [lindex $v end]
	if {[string equal $jprefs(rost,dblClk) "normal"]} {
	    ::Jabber::NewMsg::Build $wDlgs(jsendmsg) -to $jid
	} else {
	    ::Jabber::Chat::StartThread $jid
	}
    }    
}

# Jabber::Roster::PushProc --
#
#       Our callback procedure for roster pushes.
#       Populate our roster tree.
#
# Arguments:
#       rostName
#       what        any of "presence", "remove", "set", "enterroster",
#                   "exitroster"
#       jid         'user@server' without any /resource.
#       args        list of '-key value' pairs where '-key' can be
#                   -resource, -from, -type...
#       
# Results:
#       updates the roster UI.

proc ::Jabber::Roster::PushProc {rostName what {jid {}} args} {
    
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jstate jstate

    ::Jabber::Debug 2 "--roster-> rostName=$rostName, what=$what, jid=$jid, \
      args='$args'"

    # Extract the args list as an array.
    array set attrArr $args
        
    switch -- $what {
	presence {
	    if {![info exists attrArr(-type)]} {
		puts "   Error: no type attribute"
		return
	    }
	    set jid3 $jid
	    if {[info exists attrArr(-resource)]} {
		set jid3 ${jid}/$attrArr(-resource)
	    }
	    
	    # Ordinary members should go into our roster, but presence
	    # from groupchat users shall go into the specific groupchat dialog.
	    if {[$jstate(jlib) service isroom $jid]} {
		eval {::Jabber::GroupChat::Presence $jid $attrArr(-type)} $args
		
		# What if agent(s) instead???
		# Dont do this unless we've got browsing for this server.		
		if {[::Jabber::Browse::HaveBrowseTree $jid]} {
		    eval {::Jabber::Browse::Presence $jid $attrArr(-type)} $args
		}
	    } else {
		eval {::Jabber::Roster::Presence $jid3 $attrArr(-type)} $args
	    
	    	# If users shall be automatically browsed to.
	    	if {$jprefs(autoBrowseUsers) &&  \
		  ![$jstate(browse) isbrowsed $jid3]} {
		    eval {::Jabber::Roster::AutoBrowse $jid3 $attrArr(-type)} \
		      $args
	    	}
	    }
	    
	    # Any noise?
	    eval {::Jabber::PresenceSounds $jid $attrArr(-type)} $args	    
	}
	remove {
	    
	    # Must remove all resources, and jid2 if no resources.
    	    set resList [$jstate(roster) getresources $jid]
	    foreach res $resList {
	        ::Jabber::Roster::Remove ${jid}/${res}
	    }
	    if {$resList == ""} {
	        ::Jabber::Roster::Remove $jid
	    }
	}
	set {
	    eval {::Jabber::Roster::SetItem $jid} $args
	}
	enterroster {
	    set jstate(inroster) 1
	    ::Jabber::Roster::Clear
	}
	exitroster {
	    set jstate(inroster) 0
	    ::Jabber::ExitRoster
	}
    }
}

# Jabber::Roster::Clear --
#
#       Clears the complete tree from all jid's and all groups.
#
# Arguments:
#       
# Results:
#       clears tree.

proc ::Jabber::Roster::Clear { } {
    
    variable wtree    
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate

    ::Jabber::Debug 2 "::Jabber::Roster::Clear"

    foreach gpres $jprefs(treedirs) {
	$wtree delitem $gpres -childsonly 1
    }
}

proc ::Jabber::ExitRoster { } {
    
    ::UI::SetStatusMessage . [::msgcat::mc jarostupdate]
    
    # Should perhaps fix the directories of the tree widget, such as
    # appending (#items) for each headline.
}

# Jabber::Roster::SetItem --
#
#       Adds a jid item to the tree.
#
# Arguments:
#       jid         2-tier jid with no /resource part.
#       args        list of '-key value' pairs where '-key' can be
#                   -name
#                   -groups   Note, PLURAL!
#                   -ask
#       
# Results:
#       updates tree.

proc ::Jabber::Roster::SetItem {jid args} {
    
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jstate jstate

    ::Jabber::Debug 2 "::Jabber::Roster::SetItem jid=$jid, args='$args'"
    
    # Remove any old items first:
    # 1) If we 'get' the roster, the roster is cleared, so we can be
    #    sure that we don't have any "old" item???
    # 2) Must remove all resources for this jid first, and then add back.
    #    Remove also jid2.
    if {!$jstate(inroster)} {
    	set resList [$jstate(roster) getresources $jid]
	foreach res $resList {
	    ::Jabber::Roster::Remove ${jid}/${res}
	}
	if {$resList == ""} {
	    ::Jabber::Roster::Remove $jid
	}
    }
    
    set doAdd 1
    if {!$jprefs(rost,allowSubNone)} {
	
	# Do not add items with subscription='none'.
	set ind [lsearch $args "-subscription"]
	if {($ind >= 0) && [string equal [lindex $args [expr $ind+1]] "none"]} {
	    set doAdd 0
	}
    }
    
    if {$doAdd} {
    
	# We get a sublist for each resource. IMPORTANT!
	# Add all resources for this jid?
	set presenceList [$jstate(roster) getpresence $jid]
	::Jabber::Debug 2 "      presenceList=$presenceList"
	foreach pres $presenceList {
	    catch {unset presArr}
	    array set presArr $pres
	    
	    # Put in our roster tree.
	    eval {::Jabber::Roster::PutItemInTree $jid $presArr(-type)} \
	      $args $pres
	}
    }
}

# Jabber::Roster::Presence --
#
#       Sets the presence of the jid in our UI.
#
# Arguments:
#       jid         3-tier jid
#       presence    "available", "unavailable", or "unsubscribed"
#       args        list of '-key value' pairs of presence attributes.
#       
# Results:
#       roster tree updated.

proc ::Jabber::Roster::Presence {jid presence args} {
    
    upvar ::Jabber::jidToIP jidToIP
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate

    ::Jabber::Debug 2 "::Jabber::Roster::Presence jid=$jid, presence=$presence, args='$args'"

    # All presence have a 3-tier jid as 'from' attribute:
    # presence = 'available'   => remove jid2 + jid3,  add jid3
    # presence = 'unavailable' => remove jid2 + jid3,  add jid2
    
    array set argsArr $args
    set jid2 $jid
    regexp {^(.+@[^/]+)(/.+)?$} $jid match jid2 res
        
    # This gets a list '-name ... -groups ...' etc. from our roster.
    set itemAttr [$jstate(roster) getrosteritem $jid2]
    
    # First remove if there, then add in the right tree dir.
    ::Jabber::Roster::Remove $jid
    
    # Put in our roster tree.
    if {[string equal $presence "unsubscribed"]} {
	set treePres "unavailable"
	if {$jprefs(rost,rmIfUnsub)} {
	    
	    # Must send a subscription remove here to get rid if it completely??
	    # Think this is already been made from our presence callback proc.
	    #$jstate(jlib) roster_remove $jid ::Jabber::Roster::PushProc
	} else {
	    eval {::Jabber::Roster::PutItemInTree $jid2 $treePres} \
	      $itemAttr $args
	}
    } else {
	set treePres $presence
	eval {::Jabber::Roster::PutItemInTree $jid2 $treePres} $itemAttr $args
    }
    if {[string equal $treePres "unavailable"]} {
	
	# Need to remove our cached ip number for this jid.
	catch {unset jidToIP($jid)}
    }
}

# Jabber::Roster::Remove --
#
#       Removes a jid item from all groups in the tree.
#
# Arguments:
#       jid         can be 2-tier or 3-tier jid!
#       
# Results:
#       updates tree.

proc ::Jabber::Roster::Remove {jid} {
    
    variable wtree    
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Roster::Remove, jid=$jid"
    
    # All presence have a 3-tier jid as 'from' attribute.
    # If have 3-tier jid:
    #    presence = 'available'   => remove jid2 + jid3
    #    presence = 'unavailable' => remove jid2 + jid3
    # Else if 2-tier jid:  => remove jid2
    
    if {[regexp {^([^@]+@[^/]+)/.+$} $jid match jid2]} {
	
	# Must be 3-tier jid.
	set jid3 $jid
    } else {
	set jid2 $jid
    }

    # New tree widget command 'find withtag'. 
    foreach v [$wtree find withtag $jid2] {
	$wtree delitem $v
	
	# Remove dirs if empty?
	if {[llength $v] == 3} {
	    if {[llength [$wtree children [lrange $v 0 1]]] == 0} {
		$wtree delitem [lrange $v 0 1]
	    }
	}
    }
    if {[info exists jid3]} {
	foreach v [$wtree find withtag $jid3] {
	    $wtree delitem $v
	    if {[llength $v] == 3} {
		if {[llength [$wtree children [lrange $v 0 1]]] == 0} {
		    $wtree delitem [lrange $v 0 1]
		}
	    }
	}
    }
}

# Jabber::Roster::AutoBrowse --
# 
#       If presence from user browse that user including its resource.
#       
# Arguments:
#       jid:        3-tier jid
#       presence    "available" or "unavailable"

proc ::Jabber::Roster::AutoBrowse {jid presence args} {
    
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate

    ::Jabber::Debug 2 "::Jabber::Roster::AutoBrowse jid=$jid, presence=$presence, args='$args'"

    array set argsArr $args
    if {[string equal $presence "available"]} {    
	$jstate(jlib) browse_get $jid  \
	  -errorcommand [list ::Jabber::Browse::ErrorProc 1]  \
	  -command [list ::Jabber::Roster::AutoBrowseCallback]
    } elseif {[string equal $presence "unavailable"]} {    
	$jstate(browse) clear $jid
    }
}

# Jabber::Roster::AutoBrowseCallback --
# 
#       The intention here is to signal which services a particular client
#       supports to the UI. If coccinella, for instance.
#       
# Arguments:
#       jid:        3-tier jid

proc ::Jabber::Roster::AutoBrowseCallback {browseName type jid subiq} {
    
    variable wtree    
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::gShowIcon gShowIcon
    
    ::Jabber::Debug 2 "::Jabber::Roster::AutoBrowseCallback, jid=$jid,\
      [string range "subiq='$subiq'" 0 40]..."
    
    set clientnsList [$jstate(browse) getnamespaces $jid]
    if {[lsearch $clientnsList "coccinella:wb"] >= 0} {
	if {[regexp {^(.+@[^/]+)/(.+)$} $jid match jid2 res]} {
	    set presArr(-show) "normal"
	    array set presArr [$jstate(roster) getpresence $jid2 $res]
	    
	    # If available and show = ( normal | empty | chat ) display icon.
	    if {![string equal $presArr(-type) "available"]} {
		return
	    }
	    switch -- $presArr(-show) {
		normal {
		    set icon $gShowIcon(available,wb)
		}
		chat {
		    set icon $gShowIcon(chat,wb)
		}
		default {
		    return
		}
	    }
	    
	    array set rostArr [$jstate(roster) getrosteritem $jid2]
	    
	    if {[info exists rostArr(-groups)] &&  \
	      [string length $rostArr(-groups)]} {
		set groups $rostArr(-groups)
		foreach grp $groups {
		    $wtree itemconfigure [list Online $grp $jid] -image $icon
		}
	    } else {
		
		# No groups associated with this item.
		$wtree itemconfigure [list Online $jid] -image $icon
	    }
	    
	}
    }
}

# Jabber::Roster::PutItemInTree --
#
#       Sets the jid in the correct place in our roster tree.
#       Online users shall be put with full 3-tier jid.
#       Offline and other are stored with 2-tier jid with no resource.
#
# Arguments:
#       jid         2-tier jid
#       presence    "available" or "unavailable"
#       args        list of '-key value' pairs of presence and roster
#                   attributes.
#       
# Results:
#       roster tree updated.

proc ::Jabber::Roster::PutItemInTree {jid presence args} {
    
    variable wtree    
    variable wtreecanvas
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::mapShowElemToText mapShowElemToText
    
    ::Jabber::Debug 3 "::Jabber::Roster::PutItemInTree jid=$jid, presence=$presence, args='$args'"

    array set argsArr $args
    array set gpresarr {available Online unavailable Offline}
    
    # Format item:
    #  - If 'name' attribute, use this, else
    #  - if user belongs to login server, use only prefix, else
    #  - show complete 2-tier jid
    # If resource add it within parenthesis '(presence)' but only if Online.
    # 
    # For Online users, the tree item must be a 3-tier jid with resource 
    # since a user may be logged in from more than one resource.
    
    set jidx $jid
    if {[info exists argsArr(-name)] && ($argsArr(-name) != "")} {
	set itemTxt $argsArr(-name)
    } elseif {[regexp "^(\[^@\]+)@$jserver(this)" $jid match user]} {
	set itemTxt $user
    } else {
	set itemTxt $jid
    }
    if {[string equal $presence "available"]} {
	if {[info exists argsArr(-resource)] && ($argsArr(-resource) != "")} {
	    append itemTxt " ($argsArr(-resource))"
	    set jidx ${jid}/$argsArr(-resource)
	}
    }
    
    set itemOpts [list -text $itemTxt]    
    set icon [eval {::Jabber::GetPresenceIcon $jidx $presence} $args]
	
    # If we have an ask attribute, put in Pending tree dir.
    if {[info exists argsArr(-ask)] &&  \
      [string equal $argsArr(-ask) "subscribe"]} {
	eval {$wtree newitem [list {Subscription Pending} $jid] -tags $jidx} \
	  $itemOpts
    } elseif {[info exists argsArr(-groups)] && ($argsArr(-groups) != "")} {
	set groups $argsArr(-groups)
	
	# Add jid for each group.
	foreach grp $groups {
	    
	    # Make group if not exists already.
	    set childs [$wtree children [list $gpresarr($presence)]]
	    if {[lsearch -exact $childs $grp] < 0} {
		$wtree newitem [list $gpresarr($presence) $grp] -dir 1
	    }
	    eval {$wtree newitem [list $gpresarr($presence) $grp $jidx] \
	      -image $icon -tags $jidx} $itemOpts
	}
    } else {
	
	# No groups associated with this item.
	eval {$wtree newitem [list $gpresarr($presence) $jidx] \
	  -image $icon -tags $jidx} $itemOpts
    }
    
    # Design the balloon help window message.
    if {[info exists argsArr(-name)] && [string length $argsArr(-name)]} {
	set msg "$argsArr(-name): $gpresarr($presence)"
    } else {
	set msg "${jid}: $gpresarr($presence)"
    }
    if {[string equal $presence "available"]} {
	set delay [$jstate(roster) getx $jidx "jabber:x:delay"]
	if {$delay != ""} {
	    
	    # An ISO 8601 point-in-time specification. clock works!
	    set stamp [wrapper::getattr [lindex $delay 1] stamp]
	    set tstr [SmartClockFormat [clock scan $stamp]]
	    append msg "\nOnline since: $tstr"
	}
	if {[info exists argsArr(-show)]} {
	    set show $argsArr(-show)
	    if {[info exists mapShowElemToText($show)]} {
		append msg "\n$mapShowElemToText($show)"
	    } else {
		append msg "\n$show"
	    }
	}
    }
    if {[info exists argsArr(-status)]} {
	append msg "\n$argsArr(-status)"
    }
    
    ::balloonhelp::balloonforcanvas $wtreecanvas $jidx $msg
}

# Jabber::Roster::NewOrEditItem --
#
#       Build and shows the roster new or edit item window.
#
# Arguments:
#       w           toplevel window
#       which       "new" or "edit"
#       args      -jid theJid
#       
# Results:
#       "cancel" or "add".

proc ::Jabber::Roster::NewOrEditItem {w which args} {
    global  sysFont this prefs wDlgs

    variable selItem
    variable menuVar
    variable finishedNew -1
    variable jid
    variable name
    variable oldName
    variable usersGroup
    variable oldUsersGroup
    variable subscribe
    variable unsubscribe
    variable subscription
    variable oldSubscription
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    
    if {[winfo exists $w]} {
	return
    }    
    array set argsArr $args
        
    # Find all our groups for any jid.
    set allGroups [$jstate(roster) getgroups]    
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {
	wm transient $w .
    }

    # Clear any old variable values.
    set name ""
    set usersGroup ""
    if {[string equal $which "new"]} {
	wm title $w [::msgcat::mc {Add New User}]
	set jid "@$jserver(this)"
	set subscribe 1
    } else {
	wm title $w [::msgcat::mc {Edit User}]
	if {[info exists argsArr(-jid)]} {
	    set jid $argsArr(-jid)
	} else {
	    set jid [lindex $selItem end]
	}
	set subscribe 0
	set unsubscribe 0
	set subscription "none"
	
	# We should query our roster object for the present values.
	# Note PLURAL!
	set groups [$jstate(roster) getgroups $jid]
	set theItemOpts [$jstate(roster) getrosteritem $jid]
	foreach {key value} $theItemOpts {
	    set keym [string trimleft $key "-"]
	    set $keym $value
	}
	if {[llength $groups] > 0} {
		set usersGroup [lindex $groups 0]
	}
	
	# Collect the old subscription so we know if to send a new presence.
	set oldSubscription $subscription
    }
    if {$usersGroup == ""} {
    	set usersGroup "None"
    }
    set oldName $name
    set oldUsersGroup $usersGroup
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 12 -ipady 4
    
    if {[string equal $which "new"]} {
	set msg [::msgcat::mc jarostadd]
    } elseif {[string equal $which "edit"]} {
	set msg [::msgcat::mc jarostset $jid]
    }
    message $w.frall.msg -width 260 -font $sysFont(s) -text $msg
    pack $w.frall.msg -side top -fill both -expand 1

    # Entries etc.
    set frmid [frame $w.frall.frmid -borderwidth 0]
    label $frmid.ljid -text "[::msgcat::mc {Jabber user id}]:"  \
      -font $sysFont(sb) -anchor e
    entry $frmid.ejid -width 24    \
      -textvariable [namespace current]::jid
    label $frmid.lnick -text "[::msgcat::mc {Nick name}]:" -font $sysFont(sb) \
      -anchor e
    entry $frmid.enick -width 24   \
      -textvariable "[namespace current]::name"
    label $frmid.lgroups -text "[::msgcat::mc Group]:" -font $sysFont(sb) -anchor e
    
    ::combobox::combobox $frmid.egroups -font $sysFont(s) -width 18  \
      -textvariable [namespace current]::usersGroup
    eval {$frmid.egroups list insert end} "None $allGroups"
        
    if {[string equal $which "new"]} {
	checkbutton $frmid.csubs -text "  [::msgcat::mc jarostsub]"  \
	  -variable [namespace current]::subscribe
    } else {
	
	# Give user an opportunity to subscribe/unsubscribe other jid.
	switch -- $subscription {
	    from - none {
		checkbutton $frmid.csubs -text "  [::msgcat::mc jarostsub]"  \
		  -variable "[namespace current]::subscribe"
	    }
	    both - to {
		checkbutton $frmid.csubs -text "  [::msgcat::mc jarostunsub]" \
		  -variable "[namespace current]::unsubscribe"
	    }
	}
	
	# Present subscription.
	set frsub $frmid.frsub
	label $frmid.lsub -text "[::msgcat::mc Subscription]:"  \
	  -font $sysFont(sb) -anchor e
	frame $frsub
	foreach val {none to from both} txt {None To From Both} {
	    radiobutton ${frsub}.${val} -text [::msgcat::mc $txt]  \
	      -state disabled  \
	      -variable "[namespace current]::subscription" -value $val	      
	    pack $frsub.$val -side left -padx 4
	}
	
	# vCard button.
	set frvcard $frmid.vcard
	frame $frvcard
	pack [label $frvcard.lbl -text "[::msgcat::mc jasubgetvcard]:"  \
	  -font $sysFont(sb)] -side left -padx 2
	pack [button $frvcard.bt -text " [::msgcat::mc {Get vCard}]..."  \
	  -font $sysFont(s) -command [list ::VCard::Fetch .kass {other} $jid]] \
	  -side right -padx 2
    }
    grid $frmid.ljid -column 0 -row 0 -sticky e
    grid $frmid.ejid -column 1 -row 0 -sticky ew 
    grid $frmid.lnick -column 0 -row 1 -sticky e
    grid $frmid.enick -column 1 -row 1 -sticky ew
    grid $frmid.lgroups -column 0 -row 2 -sticky e
    grid $frmid.egroups -column 1 -row 2 -sticky ew
    
    if {[string equal $which "new"]} {
	grid $frmid.csubs -column 1 -row 3 -sticky w -columnspan 2
    } else {
	grid $frmid.csubs -column 1 -row 3 -sticky w -columnspan 2 -pady 2
	grid $frmid.lsub -column 0 -row 4 -sticky e -pady 2
	grid $frsub -column 1 -row 4 -sticky w -columnspan 2 -pady 2
	grid $frvcard -column 0 -row 5 -sticky w -columnspan 2 -pady 2
    }
    pack $frmid -side top -fill both -expand 1
    if {[string equal $which "edit"]} {
	$frmid.ejid configure -state disabled -bg $prefs(bgColGeneral)
    }
    if {[string equal $which "new"]} {
	focus $frmid.ejid
	$frmid.ejid icursor 0
    }
    
    # Button part.
    if {[string equal $which "edit"]} {
	set bttxt [::msgcat::mc Apply]
    } else {
	set bttxt [::msgcat::mc Add]
    }
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btconn -text $bttxt -default active -width 8 \
      -command [list [namespace current]::EditSet $w $which]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8   \
      -command [list [namespace current]::Cancel $w]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
    
    wm resizable $w 0 0
    bind $w <Return> [list ::Jabber::Roster::EditSet $w $which]
    
    # Grab and focus.
    set oldFocus [focus]
    focus $w
    catch {grab $w}
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w

    catch {grab release $w}
    focus $oldFocus
    return [expr {($finishedNew <= 0) ? "cancel" : "add"}]
}

# Jabber::Roster::Cancel --
#

proc ::Jabber::Roster::Cancel {w} {
    variable finishedNew

    set finishedNew 0
    destroy $w
}

# Jabber::Roster::EditSet --
#
#       The button press command when setting roster name or groups of jid.
#
# Arguments:
#       which       "new" or "edit"
#       
# Results:
#       sends roster set.

proc ::Jabber::Roster::EditSet {w which} {
    
    variable selItem
    variable finishedNew
    variable jid
    variable name
    variable oldName
    variable usersGroup
    variable oldUsersGroup
    variable subscribe
    variable unsubscribe
    variable subscription
    variable oldSubscription
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    # General checks.
    foreach key {jid name usersGroup} {
	set what $key
	if {[regexp $jprefs(invalsExp) $what match junk]} {
	    tk_messageBox -message [FormatTextForMessageBox  \
	      [::msgcat::mc jamessillegalchar $key $what]] \
	      -icon error -type ok
	    return
	}
    }
    
    # In any case the jid should be well formed.
    if {![::Jabber::IsWellFormedJID $jid]} {
	set ans [tk_messageBox -message [FormatTextForMessageBox  \
	  [::msgcat::mc jamessbadjid $jid]] \
	  -icon error -type yesno]
	if {[string equal $ans "no"]} {
	    return
	}
    }
    
    if {[string equal $which "new"]} {
	
	# Warn if already in our roster.
	set allUsers [$jstate(roster) getusers]
	set ind [lsearch -exact $allUsers $jid]
	if {$ind >= 0} {
	    set ans [tk_messageBox -message [FormatTextForMessageBox  \
	      [::msgcat::mc jamessalreadyinrost $jid]] \
	      -icon error -type yesno]
	    if {[string equal $ans "no"]} {
		return
	    }
	}
    }
    set finishedNew 1
    
    # This is the only (?) situation when a client "sets" a roster item.
    # The actual roster item is pushed back to us, and not set from here.
    set opts {}
    if {[string length $name]} {
	lappend opts -name $name
    }
    if {$usersGroup != $oldUsersGroup} {
    	if {$usersGroup == "None"} {
    		set usersGroup ""
    	}
	lappend opts -groups [list $usersGroup]
    }
    if {[string equal $which "new"]} {
	eval {$jstate(jlib) roster_set $jid   \
	  [list ::Jabber::Roster::EditSetCommand $jid]} $opts
    } else {
	eval {$jstate(jlib) roster_set $jid   \
	  [list ::Jabber::Roster::EditSetCommand $jid]} $opts
    }
    if {[string equal $which "new"]} {
	
	# Send subscribe request.
	if {$subscribe} {
	    $jstate(jlib) send_presence -type "subscribe" -to $jid
	}
    } else {
	
	# Send (un)subscribe request.
	if {$subscribe} {
	    $jstate(jlib) send_presence -type "subscribe" -to $jid
	} elseif {$unsubscribe} {
	    $jstate(jlib) send_presence -type "unsubscribe" -to $jid
	}
    }
    
    destroy $w
}

# Jabber::Roster::EditSetCommand --
#
#       This is our callback procedure to the roster set command.
#
# Arguments:
#       jid
#       type        "ok" or "error"
#       args

proc ::Jabber::Roster::EditSetCommand {jid type args} {
    
    if {[string equal $type "error"]} {
	set err [lindex $args 0]
	set errcode [lindex $err 0]
	set errmsg [lindex $err 1]
	tk_messageBox -icon error -type ok -message [FormatTextForMessageBox \
	  [::msgcat::mc jamessfailsetnick $jid $errcode $errmsg]]
    }	
}

# Jabber::Roster::SetUIWhen --
#
#       Update the roster buttons etc to reflect the current state.
#
# Arguments:
#       what        any of "connect", "disconnect"
#

proc ::Jabber::Roster::SetUIWhen {what} {
    
    variable btedit
    variable btremove
    variable btrefresh
    variable servtxt

    # outdated
    return
    
    switch -- $what {
	connect {
	    $btrefresh configure -state normal
	}
	disconnect {
	    set servtxt {not connected}
	    $btedit configure -state disabled
	    $btremove configure -state disabled
	    $btrefresh configure -state disabled
	}
    }
}

# The ::Jabber::Register:: namespace -------------------------------------------

namespace eval ::Jabber::Register:: {

    variable server
    variable username
    variable password
}

# Jabber::Register::Register --
#
#       Registers new user with a server.
#
# Arguments:
#       w      the toplevel window.
#       args   -server, -username, -password
#       
# Results:
#       "cancel" or "new".

proc ::Jabber::Register::Register {w args} {
    global  this sysFont
    
    variable finished -1
    variable server
    variable username
    variable password
    variable topw $w
    
    if {[winfo exists $w]} {
	return
    }
    set finished -1
    array set argsArr $args
    foreach name {server username password} {
	if {[info exists argsArr(-$name)]} {
	    set $name $argsArr(-$name)
	}
    }
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {
	wm transient $w .
    }
    wm title $w [::msgcat::mc {Register New Account}]
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 12 -ipady 4
    
    label $w.frall.head -text [::msgcat::mc {New Account}] -font $sysFont(l)  \
      -anchor w -padx 10 -pady 4
    pack $w.frall.head -side top -fill both -expand 1
    message $w.frall.msg -width 260 -font $sysFont(s) -text [::msgcat::mc janewaccount]
    pack $w.frall.msg -side top -fill both -expand 1
    
    # Entries etc.
    set frmid [frame $w.frall.frmid -borderwidth 0]
    label $frmid.lserv -text "[::msgcat::mc {Jabber server}]:"  \
      -font $sysFont(sb) -anchor e
    entry $frmid.eserv -width 26    \
      -textvariable "[namespace current]::server" -validate key  \
      -validatecommand {::Jabber::ValidateJIDChars %S}
    label $frmid.luser -text "[::msgcat::mc Username]:" -font $sysFont(sb)  \
      -anchor e
    entry $frmid.euser -width 26   \
      -textvariable "[namespace current]::username" -validate key  \
      -validatecommand {::Jabber::ValidateJIDChars %S}
    label $frmid.lpass -text "[::msgcat::mc Password]:" -font $sysFont(sb)  \
      -anchor e
    entry $frmid.epass -width 26   \
      -textvariable "[namespace current]::password" -validate key  \
      -validatecommand {::Jabber::ValidatePasswdChars %S}
    grid $frmid.lserv -column 0 -row 0 -sticky e
    grid $frmid.eserv -column 1 -row 0 -sticky w
    grid $frmid.luser -column 0 -row 1 -sticky e
    grid $frmid.euser -column 1 -row 1 -sticky w
    grid $frmid.lpass -column 0 -row 2 -sticky e
    grid $frmid.epass -column 1 -row 2 -sticky w
    pack $frmid -side top -fill both -expand 1

    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btconn -text [::msgcat::mc New] -width 8 -default active \
      -command [list [namespace current]::Doit]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8   \
      -command [list [namespace current]::Cancel $w]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
    
    wm resizable $w 0 0
    bind $w <Return> "$frbot.btconn invoke"
    
    # Grab and focus.
    set oldFocus [focus]
    focus $w
    catch {grab $w}
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w
    
    catch {grab release $w}
    focus $oldFocus
    return [expr {($finished <= 0) ? "cancel" : "new"}]
}

proc ::Jabber::Register::Cancel {w} {
    variable finished

    set finished 0
    destroy $w
}

# Jabber::Register::Doit --
#
#       Initiates a register operation.
# Arguments:
#       w
#       
# Results:
#       .

proc ::Jabber::Register::Doit { } {
    global  errorCode prefs

    variable finished
    variable server
    variable username
    variable password
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Register::Doit"
    
    # Kill any pending open states.
    ::Network::OpenConnectionKillAll
    ::UI::SetStatusMessage . ""
    ::UI::StartStopAnimatedWaveOnMain 0
    
    # Check 'server', 'username' if acceptable.
    foreach name {server username} {
	set what $name
	if {[string length $what] <= 1} {
	    tk_messageBox -icon error -type ok -message [FormatTextForMessageBox \
	      [::msgcat::mc jamessnamemissing $name]]
	    return
	}
	if {[regexp $jprefs(invalsExp) $what match junk]} {
	    tk_messageBox -icon error -type ok -message [FormatTextForMessageBox  \
	      [::msgcat::mc jamessillegalchar $name $what]]
	    return
	}
    }    
    
    ::UI::SetStatusMessage . [::msgcat::mc jawaitresp $server]
    ::UI::StartStopAnimatedWaveOnMain 1
    update idletasks

    # Set callback procedure for the async socket open.
    set jstate(servPort) $jprefs(port)
    set cmd [namespace current]::SocketIsOpen
    ::Network::OpenConnection $server $jprefs(port) $cmd -timeout $prefs(timeout)
    
    # Not sure about this...
    if {0} {
	if {$ssl} {
	    set port $jprefs(sslport)
	} else {
	    set port $jprefs(port)
	}
	::Network::OpenConnection $server $port $cmd -timeout $prefs(timeout) \
	  -tls $ssl
    }
}

# Jabber::Register::SocketIsOpen --
#
#       Callback when socket has been opened. Registers.
#       
# Arguments:
#       
#       status      "error", "timeout", or "ok".
# Results:
#       .

proc ::Jabber::Register::SocketIsOpen {sock ip port status {msg {}}} {
    
    variable server
    variable username
    variable password
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Register::SocketIsOpen"

    ::UI::SetStatusMessage . {}
    ::UI::StartStopAnimatedWaveOnMain 0
    update idletasks
    
    if {[string equal $status "error"]} {
	tk_messageBox -icon error -type ok -message [FormatTextForMessageBox \
	  [::msgcat::mc jamessnosocket $ip $msg]]
	return {}
    } elseif {[string equal $status "timeout"]} {
	tk_messageBox -icon error -type ok -message [FormatTextForMessageBox \
	  [::msgcat::mc jamesstimeoutserver $server]]
	return {}
    }    
    
    # Initiate a new stream. Perhaps we should wait for the server <stream>?
    if {[catch {$jstate(jlib) connect $server -socket $sock} err]} {
	tk_messageBox -icon error -title [::msgcat::mc {Open Failed}] -type ok \
	  -message [FormatTextForMessageBox $err]
	return
    }

    # Make a new account. Perhaps necessary to get additional variables
    # from some user preferences.
    $jstate(jlib) register_set $username $password   \
      [namespace current]::ResponseProc

    # Just wait for a callback to the procedure.
}

# Jabber::Register::ResponseProc --
#
#       Callback for register iq element.
#       
# Arguments:
#       
# Results:
#       .

proc ::Jabber::Register::ResponseProc {jlibName type theQuery} {
    
    variable topw
    variable finished
    variable server
    variable username
    variable password
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Register::ResponseProc jlibName=$jlibName,\
      type=$type, theQuery=$theQuery"
    
    if {[string equal $type "error"]} {
	set errcode [lindex $theQuery 0]
	set errmsg [lindex $theQuery 1]
	if {$errcode == 409} {
	    set msg "The registration failed with the error code $errcode\
	      message: \"$errmsg\",\
	      because this username is already in use by another user.\
	      If this user is you, try to login instead."
	} else {
	    set msg "The registration failed with the error code $errcode and\
	      message: \"$errmsg\""
	}
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	  -message [FormatTextForMessageBox $msg] \	  
    } else {
	tk_messageBox -icon info -type ok -message [FormatTextForMessageBox \
	  [::msgcat::mc jamessregisterok $server]]
    
	# Save to our jserver variable. Create a new profile.
	::Jabber::SetUserProfile {} $server $username $password
    }
    
    # Disconnect. This should reset both wrapper and XML parser!
    # Beware: we are in the middle of a callback from the xml parser,
    # and need to be sure to exit from it before resetting!
    after idle $jlibName disconnect
    set finished 1
    destroy $topw
}

# Jabber::Register::Remove --
#
#       Removes an existing user account from your login server.
#
# Arguments:
#       jid:        Optional, defaults to login server
#       
# Results:
#       Remote callback from server scheduled.

proc ::Jabber::Register::Remove {{jid {}}} {
    
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver

    set ans "yes"
    if {$jid == ""} {
	set jid $jserver(this)
	set ans [tk_messageBox -icon warning -title [::msgcat::mc Unregister] \
	  -type yesno -default no -message [FormatTextForMessageBox \
	  [::msgcat::mc jamessremoveaccount]]]
    }
    if {$ans == "yes"} {
	
	# Do we need to obtain a key for this???
	$jstate(jlib) register_remove $jid  \
	  [list ::Jabber::Register::RemoveCallback $jid]
    }
}

proc ::Jabber::Register::RemoveCallback {jid jlibName type theQuery} {
    
    if {[string equal $type "error"]} {
	foreach {errcode errmsg} $theQuery { break }
	tk_messageBox -icon error -title [::msgcat::mc Unregister] -type ok  \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamesserrunreg $jid $errcode $errmsg]]
    } elseif {[string equal $type "ok"]} {
	tk_messageBox -icon info -title [::msgcat::mc Unregister] -type ok  \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamessokunreg $jid]]
    }
}

# The ::Jabber::Passwd:: namespace -------------------------------------------
#  jserver(profile): {$profile1 {$server1 $username $password $resource} \
#                     $profile2 {$server2 $username2 $password2 $resource2} ... }

namespace eval ::Jabber::Passwd:: {

    variable password
}

# Jabber::Passwd::Build --
#
#       Sets new password.
#
# Arguments:
#       w      the toplevel window.
#       
# Results:
#       "cancel" or "set".

proc ::Jabber::Passwd::Build {w} {
    global  this sysFont
    
    variable finished -1
    variable password
    variable validate
    upvar ::Jabber::jstate jstate
    
    if {[winfo exists $w]} {
	return
    }
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {
	wm transient $w .
    }
    wm title $w [::msgcat::mc {New Password}]
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised] \
      -fill both -expand 1 -ipadx 12 -ipady 4
    set password ""
    set validate ""
    
    # Entries etc.
    set frmid [frame $w.frall.frmid -borderwidth 0]
    label $frmid.ll -font $sysFont(sb) -text [::msgcat::mc janewpass]
    label $frmid.le -font $sysFont(sb) -text $jstate(mejid)
    label $frmid.lserv -text "[::msgcat::mc {New password}]:" -anchor e
    entry $frmid.eserv -width 18 -show *  \
      -textvariable [namespace current]::password -validate key  \
      -validatecommand {::Jabber::ValidatePasswdChars %S}
    label $frmid.lvalid -text "[::msgcat::mc {Retype password}]:" -anchor e
    entry $frmid.evalid -width 18 -show * \
      -textvariable [namespace current]::validate -validate key  \
      -validatecommand {::Jabber::ValidatePasswdChars %S}
    grid $frmid.ll -column 0 -row 0 -sticky e
    grid $frmid.le -column 1 -row 0 -sticky w
    grid $frmid.lserv -column 0 -row 1 -sticky e
    grid $frmid.eserv -column 1 -row 1 -sticky w
    grid $frmid.lvalid -column 0 -row 2 -sticky e
    grid $frmid.evalid -column 1 -row 2 -sticky w
    pack $frmid -side top -fill both -expand 1

    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btset -text [::msgcat::mc Set] -width 8 -default active \
      -command [list [namespace current]::Doit $w]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8   \
      -command [list [namespace current]::Cancel $w]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
    
    wm resizable $w 0 0
    bind $w <Return> "$frbot.btset invoke"
    
    # Grab and focus.
    set oldFocus [focus]
    focus $w
    catch {grab $w}
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w
    
    catch {grab release $w}
    focus $oldFocus
    return [expr {($finished <= 0) ? "cancel" : "set"}]
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
    
    ::Jabber::Debug 2 "::Jabber::Passwd::Doit"

    if {![string equal $validate $password]} {
	tk_messageBox -type ok -icon error  \
	  -message [FormatTextForMessageBox [::msgcat::mc jamesspasswddiff]]
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
    upvar ::Jabber::jserver jserver

    if {[string equal $type "error"]} {
	set errcode [lindex $theQuery 0]
	set errmsg [lindex $theQuery 1]
	set msg 
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	  -message [FormatTextForMessageBox  \
	  [::msgcat::mc jamesspasswderr $errcode $errmsg]] \
    } else {
	
	# Make sure the new password is stored in our internal state array.
	set ind [lsearch $jserver(profile) $jserver(profile,selected)]
	if {$ind >= 0} {
	    set userSpec [lindex $jserver(profile) [expr $ind + 1]]
	    #set userSpec [lreplace $userSpec 2 2 $password]
	    lset userSpec 2 $password
	   
	    # Save to our jserver variable. Create a new profile.
	    eval {::Jabber::SetUserProfile {}} $userSpec
	}
	
	tk_messageBox -title [::msgcat::mc {New Password}] -icon info -type ok \
	  -message [FormatTextForMessageBox [::msgcat::mc jamesspasswdok]]
    }
}

# The ::Jabber::GenRegister:: namespace -----------------------------------------

namespace eval ::Jabber::GenRegister:: {


}

# Jabber::GenRegister::BuildRegister --
#
#       Initiates the process of registering with a service. 
#       Uses iq get-set method.
#       
# Arguments:
#       w           toplevel widget
#       args   -server, -autoget 0/1
#       
# Results:
#       "cancel" or "register".
     
proc ::Jabber::GenRegister::BuildRegister {w args} {
    global  this sysFont

    variable wtop
    variable wbox
    variable wbtregister
    variable wbtget
    variable wcomboserver
    variable server
    variable wsearrows
    variable stattxt
    variable finished -1
    upvar ::Jabber::jstate jstate
    
    if {[winfo exists $w]} {
	return
    }
    array set argsArr $args
    
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {
	wm transient $w .
    }
    wm title $w [::msgcat::mc {Register Service}]
    set wtop $w
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 12 -ipady 4
    message $w.frall.msg -width 240 -font $sysFont(s) -text  \
      [::msgcat::mc jaregmsg]
    pack $w.frall.msg -side top -fill x -anchor w -padx 4 -pady 4
    set frtop $w.frall.top
    pack [frame $frtop] -side top -fill x
    label $frtop.lserv -text "[::msgcat::mc {Service server}]:" -font $sysFont(sb)
    
    # Get all (browsed) services that support registration.
    set regServers [$jstate(jlib) service getjidsfor "register"]
    set wcomboserver $frtop.eserv
    ::combobox::combobox $wcomboserver -width 20 -font $sysFont(s)   \
      -textvariable "[namespace current]::server" -editable 0
    eval {$frtop.eserv list insert end} $regServers
    
    # Find the default registration server.
    if {[llength $regServers]} {
	set server [lindex $regServers 0]
    }
    if {[info exists argsArr(-server)]} {
	set server $argsArr(-server)
	$wcomboserver configure -state disabled
    }

    grid $frtop.lserv -column 0 -row 0 -sticky e
    grid $wcomboserver -column 1 -row 0 -sticky w

    # This part must be built dynamically from the 'get' xml data.
    # May be different for each conference server.
    set wfr $w.frall.frlab
    set wcont [LabeledFrame2 $wfr [::msgcat::mc Specifications]]
    pack $wfr -side top -fill both -padx 2 -pady 2

    set wbox $wcont.box
    frame $wbox
    pack $wbox -side top -fill x -padx 4 -pady 10
    pack [label $wbox.la -textvariable "[namespace current]::stattxt"]  \
      -padx 0 -pady 10
    set stattxt "-- [::msgcat::mc jasearchwait] --"
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    set wsearrows $frbot.arr
    set wbtregister $frbot.btenter
    set wbtget $frbot.btget
    pack [button $wbtget -text [::msgcat::mc Get] -width 8 -default active \
      -command [namespace current]::Get]  \
      -side right -padx 5 -pady 5
    pack [button $wbtregister -text [::msgcat::mc Register] -width 8 -state disabled \
      -command [namespace current]::DoRegister]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8  \
      -command [list [namespace current]::Cancel $w]]  \
      -side right -padx 5 -pady 5
    pack [::chasearrows::chasearrows $wsearrows -background gray87 -size 16] \
      -side left -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
        
    wm resizable $w 0 0
        
    # Grab and focus.
    set oldFocus [focus]
    catch {grab $w}
    
    if {[info exists argsArr(-autoget)] && $argsArr(-autoget)} {
	::Jabber::GenRegister::Get
    }
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w
    
    catch {grab release $w}
    focus $oldFocus
    return [expr {($finished <= 0) ? "cancel" : "register"}]
}

# Jabber::GenRegister::Simple --
#
#       Initiates the process of registering with a service. 
#       Uses straight iq set method with fixed fields (username and password).
#       
# Arguments:
#       w           toplevel widget
#       args   -server
#       
# Results:
#       "cancel" or "register".
     
proc ::Jabber::GenRegister::Simple {w args} {
    global  this sysFont

    variable wtop
    variable wbtregister
    variable server
    variable finished -1
    upvar ::Jabber::jstate jstate
    
    if {[winfo exists $w]} {
	return
    }
    array set argsArr $args
    
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {
	wm transient $w .
    }
    wm title $w [::msgcat::mc {Register Service}]
    set wtop $w
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 12 -ipady 4
    message $w.frall.msg -width 240 -font $sysFont(s) -text  \
      [::msgcat::mc jaregmsg]
    pack $w.frall.msg -side top -fill x -anchor w -padx 4 -pady 4
    set frtop $w.frall.top
    pack [frame $frtop] -side top -fill x
    label $frtop.lserv -text "[::msgcat::mc {Service server}]:" -font $sysFont(sb)
    
    # Get all (browsed) services that support registration.
    set regServers [$jstate(jlib) service getjidsfor "register"]
    set wcomboserver $frtop.eserv
    ::combobox::combobox $wcomboserver -width 20 -font $sysFont(s)   \
      -textvariable [namespace current]::server -editable 0
    eval {$frtop.eserv list insert end} $regServers
    
    # Find the default conferencing server.
    if {[llength $regServers]} {
	set server [lindex $regServers 0]
    }
    if {[info exists argsArr(-server)]} {
	set server $argsArr(-server)
	$wcomboserver configure -state disabled
    }
    grid $frtop.lserv -column 0 -row 0 -sticky e
    grid $wcomboserver -column 1 -row 0 -sticky ew
    
    label $frtop.luser -text "[::msgcat::mc Username]:" -font $sysFont(sb) \
      -anchor e
    entry $frtop.euser -width 26   \
      -textvariable [namespace current]::username -validate key  \
      -validatecommand {::Jabber::ValidateJIDChars %S}
    label $frtop.lpass -text "[::msgcat::mc Password]:" -font $sysFont(sb) \
      -anchor e
    entry $frtop.epass -width 26   \
      -textvariable [namespace current]::password -validate key \
      -validatecommand {::Jabber::ValidatePasswdChars %S}
    
    grid $frtop.luser -column 0 -row 1 -sticky e
    grid $frtop.euser -column 1 -row 1 -sticky ew
    grid $frtop.lpass -column 0 -row 2 -sticky e
    grid $frtop.epass -column 1 -row 2 -sticky ew
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    set wbtregister $frbot.btenter
    pack [button $wbtregister -text [::msgcat::mc Register] \
      -default active -command [namespace current]::DoSimple]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8  \
      -command [list [namespace current]::Cancel $w]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
        
    wm resizable $w 0 0
        
    # Grab and focus.
    set oldFocus [focus]
    catch {grab $w}
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w

    catch {grab release $w}
    focus $oldFocus
    return [expr {($finished <= 0) ? "cancel" : "register"}]
}

proc ::Jabber::GenRegister::Cancel {w} {
    variable finished
    
    set finished 0
    destroy $w
}

proc ::Jabber::GenRegister::Get { } {
    
    variable server
    variable wsearrows
    variable wcomboserver
    variable wbtget
    variable stattxt
    upvar ::Jabber::jstate jstate
    
    # Verify.
    if {[string length $server] == 0} {
	tk_messageBox -type ok -icon error  \
	  -message [::msgcat::mc jamessregnoserver]
	return
    }	
    $wcomboserver configure -state disabled
    $wbtget configure -state disabled
    set stattxt "-- [::msgcat::mc jawaitserver] --"
    
    # Send get register.
    $jstate(jlib) register_get ::Jabber::GenRegister::GetCB -to $server    
    $wsearrows start
}

proc ::Jabber::GenRegister::GetCB {jlibName type subiq} {
    
    variable wtop
    variable wbox
    variable wsearrows
    variable wbtregister
    variable wbtget
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::GenRegister::GetCB type=$type, subiq='$subiq'"

    if {![winfo exists $wtop]} {
	return
    }
    $wsearrows stop
    
    if {[string equal $type "error"]} {
	tk_messageBox -type ok -icon error  \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamesserrregget [lindex $subiq 0] [lindex $subiq 1]]]
	return
    }
    catch {destroy $wbox}
    set subiqChildList [wrapper::getchildren $subiq]
    ::Jabber::Forms::Build $wbox $subiqChildList -template "register"
    pack $wbox -side top -fill x -padx 2 -pady 10
    $wbtregister configure -state normal -default active
    $wbtget configure -state normal -default disabled
    
}

proc ::Jabber::GenRegister::DoRegister { } {
    
    variable server
    variable wsearrows
    variable wtop
    variable wbox
    variable finished
    upvar ::Jabber::jstate jstate
    
    if {[winfo exists $wsearrows]} {
	$wsearrows start
    }
    set subelements [::Jabber::Forms::GetXML $wbox]
    
    # We need to do it the crude way.
    $jstate(jlib) send_iq "set"  \
      [wrapper::createtag "query" -attrlist {xmlns jabber:iq:register}   \
      -subtags $subelements] -to $server   \
      -command [list [namespace current]::ResultCallback $server]
    set finished 1
    destroy $wtop
}

proc ::Jabber::GenRegister::DoSimple { } {
    
    variable wtop
    variable server
    variable username
    variable password
    variable finished
    upvar ::Jabber::jstate jstate
    
    $jstate(jlib) register_set $username $password  \
      [list [namespace current]::SimpleCallback $server] -to $server
    set finished 1
    destroy $wtop
}

# Jabber::GenRegister::ResultCallback --
#
#       This is our callback procedure from 'jabber:iq:register' stuffs.

proc ::Jabber::GenRegister::ResultCallback {server type subiq} {

    ::Jabber::Debug 2 "::Jabber::GenRegister::ResultCallback server=$server, type=$type, subiq='$subiq'"

    if {[string equal $type "error"]} {
	tk_messageBox -type ok -icon error  \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamesserrregset $server [lindex $subiq 0] [lindex $subiq 1]]]
    } else {
	tk_messageBox -type ok -icon info -message [FormatTextForMessageBox \
	  [::msgcat::mc jamessokreg $server]]
    }
}

proc ::Jabber::GenRegister::SimpleCallback {server jlibName type subiq} {

    ::Jabber::Debug 2 "::Jabber::GenRegister::ResultCallback server=$server, type=$type, subiq='$subiq'"

    if {[string equal $type "error"]} {
	tk_messageBox -type ok -icon error  \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamesserrregset $server [lindex $subiq 0] [lindex $subiq 1]]]
    } else {
	tk_messageBox -type ok -icon info -message [FormatTextForMessageBox \
	  [::msgcat::mc jamessokreg $server]]
    }
}

# The ::Jabber::Login:: namespace ----------------------------------------------

namespace eval ::Jabber::Login:: {
    
    variable server
    variable username
    variable password
}

# Jabber::Login::Login --
#
#       Log in to a server with an existing user account.
#
# Arguments:
#       w      the toplevel window.
#       
# Results:
#       name of button pressed; "cancel" or "login".

proc ::Jabber::Login::Login {w} {
    global  this sysFont prefs
    
    variable wtoplevel $w
    variable finished -1
    variable menuVar
    variable profile
    variable server
    variable username
    variable password
    variable resource
    variable digest
    variable ssl 0
    variable invisible 0
    variable tmpJServArr
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jprefs jprefs
    
    if {[winfo exists $w]} {
	return
    }
    
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {
	wm transient $w .
    }
    wm title $w [::msgcat::mc Login]
    set digest 1
    set ssl $jprefs(usessl)
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 12 -ipady 4
    
    label $w.frall.head -text [::msgcat::mc Login] -font $sysFont(l)  \
      -anchor w -padx 10 -pady 4
    pack $w.frall.head -side top -fill both -expand 1
    message $w.frall.msg -width 260 -font $sysFont(s) -text [::msgcat::mc jalogin]
    pack $w.frall.msg -side top -fill both -expand 1
    
    # Entries etc.
    set frmid [frame $w.frall.frmid -borderwidth 0]
    pack $frmid -side top -fill both -expand 1
    
    # Sync $jserver(all)
    set jserver(all) {}
    foreach {name spec} $jserver(profile) {
	lappend jserver(all) $name
    }
    
    # Option menu for selecting user profile.
    label $frmid.lpop -text "[::msgcat::mc Profile]:" -font $sysFont(sb) -anchor e
    set wpopup $frmid.popup
    eval {tk_optionMenu $wpopup [namespace current]::menuVar} $jserver(all)
    $wpopup configure -highlightthickness 0  \
      -background $prefs(bgColGeneral) -foreground black
    grid $frmid.lpop -column 0 -row 0 -sticky e
    grid $wpopup -column 1 -row 0 -sticky e

    # Verify that the selected also in array.
    if {[lsearch -exact $jserver(profile) $jserver(profile,selected)] < 0} {
	set jserver(profile,selected) [lindex $jserver(profile) 0]
    }
    set profile $jserver(profile,selected)
    set menuVar $jserver(profile,selected)
    
    # Make temp array for servers. Handy fo filling in the entries.
    foreach {name spec} $jserver(profile) {
	foreach [list  \
	  tmpJServArr($name,server)     \
	  tmpJServArr($name,username)   \
	  tmpJServArr($name,password)   \
	  tmpJServArr($name,resource)] $spec { break }
    }
    set server $tmpJServArr($menuVar,server)
    set username $tmpJServArr($menuVar,username)
    set password $tmpJServArr($menuVar,password)
    set resource $tmpJServArr($menuVar,resource)
    
    label $frmid.lserv -text "[::msgcat::mc {Jabber server}]:" -font $sysFont(sb) -anchor e
    entry $frmid.eserv -width 26    \
      -textvariable [namespace current]::server -validate key  \
      -validatecommand {::Jabber::ValidateJIDChars %S}
    label $frmid.luser -text "[::msgcat::mc Username]:" -font $sysFont(sb) -anchor e
    entry $frmid.euser -width 26   \
      -textvariable [namespace current]::username -validate key  \
      -validatecommand {::Jabber::ValidateJIDChars %S}
    label $frmid.lpass -text "[::msgcat::mc Password]:" -font $sysFont(sb) -anchor e
    entry $frmid.epass -width 26   \
      -textvariable [namespace current]::password -show {*} -validate key \
      -validatecommand {::Jabber::ValidatePasswdChars %S}
    label $frmid.lres -text "[::msgcat::mc Resource]:" -font $sysFont(sb) -anchor e
    entry $frmid.eres -width 26   \
      -textvariable [namespace current]::resource -validate key  \
      -validatecommand {::Jabber::ValidateJIDChars %S}
    checkbutton $frmid.cdig -text "  [::msgcat::mc {Scramble password}]"  \
      -variable [namespace current]::digest
    checkbutton $frmid.cssl -text "  [::msgcat::mc {Use SSL for security}]"  \
      -variable [namespace current]::ssl
    checkbutton $frmid.cinv  \
      -text "  [::msgcat::mc {Login as invisible}]"  \
      -variable [namespace current]::invisible

    grid $frmid.lserv -column 0 -row 1 -sticky e
    grid $frmid.eserv -column 1 -row 1 -sticky w
    grid $frmid.luser -column 0 -row 2 -sticky e
    grid $frmid.euser -column 1 -row 2 -sticky w
    grid $frmid.lpass -column 0 -row 3 -sticky e
    grid $frmid.epass -column 1 -row 3 -sticky w
    grid $frmid.lres -column 0 -row 4 -sticky e
    grid $frmid.eres -column 1 -row 4 -sticky w
    grid $frmid.cdig -column 1 -row 5 -sticky w -pady 2
    grid $frmid.cssl -column 1 -row 6 -sticky w -pady 2
    grid $frmid.cinv -column 1 -row 7 -sticky w -pady 2

    if {!$prefs(tls)} {
	set ssl 0
	$frmid.cssl configure -state disabled
    }
	
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btconn -text [::msgcat::mc Login] -width 8 \
      -default active -command [namespace current]::Doit]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8  \
      -command [list [namespace current]::DoCancel $w]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
    
    # Necessary to trace the popup menu variable.
    trace variable [namespace current]::menuVar w  \
      [namespace current]::TraceMenuVar
        
    if {[info exists prefs(winGeom,$w)]} {
	regexp {^[^+-]+((\+|-).+$)} $prefs(winGeom,$w) match pos
	wm geometry $w $pos
    }
    wm resizable $w 0 0
    bind $w <Return> ::Jabber::Login::Doit
    
    # Grab and focus.
    set oldFocus [focus]
    focus $w
    catch {grab $w}
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w
    
    # Clean up.
    catch {grab release $w}
    ::Jabber::Login::Close $w
    focus $oldFocus
    return [expr {($finished <= 0) ? "cancel" : "login"}]
}

proc ::Jabber::Login::DoCancel {w} {
    variable finished
    
    ::UI::SaveWinGeom $w
    set finished 0
    catch {destroy $w}
}

proc ::Jabber::Login::Close {w} {

    variable menuVar
    upvar ::Jabber::jserver jserver
    
    # Clean up.
    set jserver(profile,selected) $menuVar
    trace vdelete [namespace current]::menuVar w  \
      [namespace current]::TraceMenuVar
    catch {grab release $w}
    catch {destroy $w}    
}

proc ::Jabber::Login::TraceMenuVar {name key op} {
    
    # Call by name.
    upvar #0 $name locName

    variable profile
    variable server
    variable username
    variable password
    variable resource
    variable menuVar
    variable tmpJServArr
    
    set profile $locName
    set server $tmpJServArr($locName,server)
    set username $tmpJServArr($locName,username)
    set password $tmpJServArr($locName,password)
    set resource $tmpJServArr($locName,resource)
}

# Jabber::Login::Doit --
#
#       Initiates a login to a server with an existing user account.
#
# Arguments:
#       
# Results:
#       .

proc ::Jabber::Login::Doit { } {
    global  errorCode prefs

    variable wtoplevel
    variable finished
    variable server
    variable username
    variable password
    variable resource
    variable ssl
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Login::Doit"
    
    # Kill any pending open states.
    ::Network::OpenConnectionKillAll
    ::UI::SetStatusMessage . ""
    ::UI::StartStopAnimatedWaveOnMain 0
    
    # Check 'server', 'username' and 'password' if acceptable.
    foreach name {server username password} {
	upvar 0 $name var
	if {[string length $var] <= 1} {
	    tk_messageBox -icon error -type ok -message  \
	      [FormatTextForMessageBox [::msgcat::mc jamessnamemissing $name]]	      
	    return
	}
	if {$name == "password"} {
	    continue
	}
	if {[regexp $jprefs(invalsExp) $var match junk]} {
	    tk_messageBox -icon error -type ok -message  \
	      [FormatTextForMessageBox [::msgcat::mc jamessillegalchar $name $var]]
	    return
	}
    }    
    set finished 1
    ::UI::SaveWinGeom $wtoplevel
    catch {destroy $wtoplevel}
    
    ::UI::SetStatusMessage . [::msgcat::mc jawaitresp $server]
    ::UI::StartStopAnimatedWaveOnMain 1
    update idletasks

    # Set callback procedure for the async socket open.
    set cmd ::Jabber::Login::SocketIsOpen    
    if {$ssl} {
	set port $jprefs(sslport)
    } else {
	set port $jprefs(port)
    }
    ::Network::OpenConnection $server $port $cmd -timeout $prefs(timeout) \
      -tls $ssl
}

# Jabber::Login::SocketIsOpen --
#
#       Callback when socket has been opened. Logins.
#       
# Arguments:
#       
#       status      "error", "timeout", or "ok".
# Results:
#       .

proc ::Jabber::Login::SocketIsOpen {sock ip port status {msg {}}} {
    
    variable server
    variable username
    variable password
    variable resource
    variable digest
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Login::SocketIsOpen"
    
    if {[string equal $status "error"]} {
	::UI::SetStatusMessage . ""
	::UI::StartStopAnimatedWaveOnMain 0
	tk_messageBox -icon error -type ok -message [FormatTextForMessageBox \
	  [::msgcat::mc jamessnosocket $ip $msg]]
	return ""
    } elseif {[string equal $status "timeout"]} {
	::UI::SetStatusMessage . ""
	::UI::StartStopAnimatedWaveOnMain 0
	tk_messageBox -icon error -type ok -message [FormatTextForMessageBox \
	  [::msgcat::mc jamesstimeoutserver $server]]
	return ""
    }    
    set jstate(sock) $sock
    ::UI::SetStatusMessage . [::msgcat::mc jawaitxml $server]
    
    # Initiate a new stream. Perhaps we should wait for the server <stream>?
    if {[catch {$jstate(jlib) connect $server -socket $sock  \
      -cmd ::Jabber::Login::ConnectProc} err]} {
	::UI::SetStatusMessage . ""
	::UI::StartStopAnimatedWaveOnMain 0
	tk_messageBox -icon error -title [::msgcat::mc {Open Failed}] -type ok \
	  -message [FormatTextForMessageBox $err]
	return
    }

    # Just wait for a callback to the procedure.
}

# Jabber::Login::ConnectProc --
#
#       .
#       
# Arguments:
#       jlibName    name of jabber lib instance
#       args        attribute list
#       
# Results:
#       .

proc ::Jabber::Login::ConnectProc {jlibName args} {
    
    variable server
    variable username
    variable password
    variable resource
    variable digest
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Login::ConnectProc jlibName=$jlibName, args='$args'"

    array set argsArray $args
    ::UI::SetStatusMessage . [::msgcat::mc jasendauth $server]
    
    # Send authorization info for an existing account.
    # Perhaps necessary to get additional variables
    # from some user preferences.
    if {$resource == ""} {
    	set resource coccinella
    }
    if {$digest} {
	if {![info exists argsArray(id)]} {
	    error "no id for digest in receiving <stream>"
	}
	
	::Jabber::Debug 3 "argsArray(id)=$argsArray(id), password=$password"
	
	set digestedPw [::sha1pure::sha1 $argsArray(id)$password]
	$jstate(jlib) send_auth $username $resource   \
	  ::Jabber::Login::ResponseProc -digest $digestedPw
    } else {
	$jstate(jlib) send_auth $username $resource   \
	  ::Jabber::Login::ResponseProc -password $password
    }
    
    # Just wait for a callback to the procedure.
}

# Jabber::Login::ResponseProc --
#
#       Callback for Login iq element.
#       
# Arguments:
#       
# Results:
#       .

proc ::Jabber::Login::ResponseProc {jlibName type theQuery} {
    global  ipName2Num prefs
    
    variable profile
    variable server
    variable username
    variable password
    variable resource
    variable invisible
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    
    ::Jabber::Debug 2 "::Jabber::Login::ResponseProc  theQuery=$theQuery"

    ::UI::StartStopAnimatedWaveOnMain 0
    
    if {[string equal $type "error"]} {	
	set errcode [lindex $theQuery 0]
	set errmsg [lindex $theQuery 1]
	::UI::SetStatusMessage . [::msgcat::mc jaerrlogin $server $errmsg]
	if {$errcode == 409} {
	    set msg [::msgcat::mc jamesslogin409 $errcode]
	} else {
	    set msg [::msgcat::mc jamessloginerr $errcode $errmsg]
	}
	tk_messageBox -icon error -type ok -title [::msgcat::mc Error]  \
	  -message [FormatTextForMessageBox $msg]

	#       There is a potential problem if called from within a xml parser 
	#       callback which makes the subsequent parsing to fail. (after idle?)
	after idle $jstate(jlib) disconnect
	return
    } 
    
    # Collect ip num name etc. in arrays.
    if {![::OpenConnection::SetIpArrays $server $jstate(sock)  \
      $jstate(servPort)]} {
	::UI::SetStatusMessage . ""
	return
    }
    if {[IsIPNumber $server]} {
	set ipNum $server
    } else {
	set ipNum $ipName2Num($server)
    }
    set jstate(ipNum) $ipNum
    
    # Ourself.
    set jstate(mejid) "${username}@${server}"
    set jstate(meres) $resource
    set jstate(mejidres) "${username}@${server}/${resource}"
    set jserver(profile,selected) $profile
    set jserver(this) $server
    
    # Set communication entry in UI.
    if {$prefs(jabberCommFrame)} {
	::UI::ConfigureAllJabberEntries $ipNum -netstate "connect"	
    } else {
	::UI::SetCommEntry . $ipNum 1 -1 -jidvariable ::Jabber::jstate(.,tojid)  \
	  -dosendvariable ::Jabber::jstate(.,doSend)
	# We skip this.
	#  -validatecommand ::Jabber::VerifyJID
    }
    set ::Jabber::Roster::servtxt $server
    ::Jabber::Roster::SetUIWhen "connect"
    ::Jabber::Browse::SetUIWhen "connect"

    # Multiinstance whiteboard UI stuff.
    foreach w [::UI::GetAllWhiteboards] {
	set wtop [::UI::GetToplevelNS $w]
	set ::Jabber::jstate($wtop,tojid) "@${server}"
	::UI::SetStatusMessage $wtop [::msgcat::mc jaauthok $server]

	# Make menus consistent.
	::UI::FixMenusWhen $wtop "connect"
    }
    
    # Login was succesful. Get my roster, and set presence.
    $jlibName roster_get ::Jabber::Roster::PushProc
    if {$invisible} {
	$jlibName send_presence -type invisible
	set jstate(status) "invisible"
    } else {
	$jlibName send_presence -type available
	set jstate(status) "available"
    }
    
    # Store our own ip number in a public storage at the server.
    ::Jabber::SetPrivateData
    
    # Get the services for all our servers on the list. Depends on our settings:
    # If browsing fails must use "agents" as a fallback.
    if {[string equal $jprefs(agentsOrBrowse) "browse"]} {
	::Jabber::Browse::GetAll
    } elseif {[string equal $jprefs(agentsOrBrowse) "agents"]} {
	::Jabber::Agents::GetAll
    }
    
    # Check for autoupdates? ABONDENED!!!!
    if {$jprefs(autoupdateCheck) && $jprefs(autoupdateShow,$prefs(fullVers))} {
	$jlibName send_presence -to  \
	  $jprefs(serialno)@update.jabber.org/$prefs(fullVers)
    }
    
    # Any noise.
    ::Sounds::Play "connected"
}

# Jabber::VerifyJIDWhiteboard --
#
#       Validate entry for jid.
#       
# Arguments:
#       #jid     username@server
#       
# Results:
#       boolean: 0 if reject, 1 if accept

proc ::Jabber::VerifyJIDWhiteboard {wtop} {

    upvar ::Jabber::jstate jstate
    
    if {[string equal $wtop "."]} {
	set w .
    } else {
	set w [string trimright $wtop .]
    }
    set jid $jstate($wtop,tojid)
    if {$jstate($wtop,doSend)} {
	if {![::Jabber::IsWellFormedJID $jid]} {
	    tk_messageBox -icon warning -type ok -parent $w -message  \
	      [FormatTextForMessageBox [::msgcat::mc jamessinvalidjid]]
	    return 0
	}
    }
    return 1
}

# The ::Jabber::Logout:: namespace ---------------------------------------------

namespace eval ::Jabber::Logout:: {}

proc ::Jabber::Logout::WithStatus {w} {
    global  prefs this sysFont

    variable finished -1
    variable status ""
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate

    ::Jabber::Debug 2 "::Jabber::Logout::WithStatus"

    if {[winfo exists $w]} {
	return
    }
    
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {
	wm transient $w .
    }
    wm title $w {Logout With Message}
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]  \
      -fill both -expand 1 -ipadx 12 -ipady 4
    
    label $w.frall.head -text {Logout} -font $sysFont(l)  \
      -anchor w -padx 10 -pady 4
    pack $w.frall.head -side top -fill both -expand 1
    
    # Entries etc.
    set frmid [frame $w.frall.frmid -borderwidth 0]
    pack $frmid -side top -fill both -expand 1
    
    label $frmid.lstat -text "Status:" -font $sysFont(sb) -anchor e
    entry $frmid.estat -width 36  \
      -textvariable [namespace current]::status
    grid $frmid.lstat -column 0 -row 1 -sticky e
    grid $frmid.estat -column 1 -row 1 -sticky w
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btout -text [::msgcat::mc Logout] -width 8 \
      -default active -command [list [namespace current]::DoLogout $w]] \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8  \
      -command [list [namespace current]::DoCancel $w]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
    
    if {[info exists prefs(winGeom,$w)]} {
	regexp {^[^+-]+((\+|-).+$)} $prefs(winGeom,$w) match pos
	wm geometry $w $pos
    }
    wm resizable $w 0 0
    bind $w <Return> "$frbot.btout invoke"
    
    # Grab and focus.
    set oldFocus [focus]
    focus $frmid.estat
    catch {grab $w}
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w
    
    # Clean up.
    catch {grab release $w}
    focus $oldFocus
    return [expr {($finished <= 0) ? "cancel" : "logout"}]
}

proc ::Jabber::Logout::DoCancel {w} {
    variable finished
    
    set finished 0
    destroy $w
}

proc ::Jabber::Logout::DoLogout {w} {
    variable finished
    variable status
    upvar ::Jabber::jstate jstate
    
    set finished 1
    destroy $w
    ::Jabber::DoCloseClientConnection $jstate(ipNum) -status $status
}

# The ::Jabber::Subscribe:: namespace ------------------------------------------

namespace eval ::Jabber::Subscribe:: {

    # Store everything in 'locals($uid, ... )'.
    variable locals   
    variable uid 0
}

# Jabber::Subscribe::Subscribe --
#
#       Ask for user response on a subscribe presence element.
#
# Arguments:
#       wbase  the toplevel window's base path.
#       jid    the jid we receive a 'subscribe' presence element from.
#       args   ?-key value ...? look for any '-status' only.
#       
# Results:
#       "deny" or "accept".

proc ::Jabber::Subscribe::Subscribe {wbase jid args} {
    global  this sysFont prefs wDlgs
    
    variable locals   
    variable uid
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Jabber::Debug 2 "::Jabber::Subscribe::Subscribe jid=$jid"

    incr uid
    set w ${wbase}${uid}
    set locals($uid,finished) -1
    set locals($uid,wtop) $w
    set locals($uid,jid) $jid
    array set argsArr $args
    
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {
	wm transient $w .
    }
    wm title $w [::msgcat::mc Subscribe]
    
    # Find our present groups.
    set allGroups [$jstate(roster) getgroups]
        
    # This gets a list '-name ... -groups ...' etc. from our roster.
    # Note! -groups PLURAL!
    array set itemAttrArr {-name {} -groups {} -subscription none}
    array set itemAttrArr [$jstate(roster) getrosteritem $jid]
    
    # Textvariables for entry and combobox.
    set locals($uid,name) $itemAttrArr(-name)
    if {[llength $itemAttrArr(-groups)] > 0} {
	set locals($uid,group) [lindex $itemAttrArr(-groups) 0]
    }
    
    # Figure out if we shall send a 'subscribe' presence to this user.
    set maySendSubscribe 1
    if {$itemAttrArr(-subscription) == "to" ||  \
      $itemAttrArr(-subscription) == "both"} {
	set maySendSubscribe 0
    }

    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]  \
      -fill both -expand 1 -ipadx 4
    
    label $w.frall.head -text [::msgcat::mc Subscribe] -font $sysFont(l)  \
      -anchor w -padx 10 -pady 4
    pack $w.frall.head -side top -fill both -expand 1
    message $w.frall.msg -width 260 -font $sysFont(s)  \
      -text [::msgcat::mc jasubwant $jid]
    pack $w.frall.msg -side top -fill both -expand 1
    
    # Any -status attribute?
    if {[info exists argsArr(-status)] && [string length $argsArr(-status)]} {
    	set txt "Message: \"$argsArr(-status)\""
    	label $w.frall.status -wraplength 260 -text $txt
    	pack $w.frall.status -side top -anchor w -padx 10
    }
        
    # Some action buttons.
    set frmid [frame $w.frall.frmid -borderwidth 0]
    label $frmid.lvcard -text "[::msgcat::mc jasubgetvcard]:" -font $sysFont(sb) \
      -anchor e
    button $frmid.bvcard -text "[::msgcat::mc {Get vCard}]..."   \
      -command [list ::VCard::Fetch .kass other $jid]
    label $frmid.lmsg -text [::msgcat::mc jasubsndmsg]   \
      -font $sysFont(sb) -anchor e
    button $frmid.bmsg -text "[::msgcat::mc Send]..."    \
      -command [list ::Jabber::Subscribe::SendMsg $uid]
    grid $frmid.lvcard -column 0 -row 0 -sticky e -padx 6 -pady 2
    grid $frmid.bvcard -column 1 -row 0 -sticky ew -padx 6 -pady 2
    grid $frmid.lmsg -column 0 -row 1 -sticky e -padx 6 -pady 2
    grid $frmid.bmsg -column 1 -row 1 -sticky ew -padx 6 -pady 2
    pack $frmid -side top -fill both -expand 1

    # The option part.
    set locals($uid,allow) 1
    set locals($uid,add) $jprefs(defSubscribe)
    set fropt $w.frall.fropt
    set frcont [LabeledFrame2 $fropt {Options}]
    pack $fropt -side top -fill both -ipadx 10 -ipady 6
    checkbutton $frcont.pres -text "  [::msgcat::mc jasuballow $jid]" \
      -variable [namespace current]::locals($uid,allow)
    
    checkbutton $frcont.add -text "  [::msgcat::mc jasubadd $jid]" \
      -variable [namespace current]::locals($uid,add)
    pack $frcont.pres $frcont.add -side top -anchor w -padx 10 -pady 4
    set frsub [frame $frcont.frsub]
    pack $frsub -expand 1 -fill x -side top
    label $frsub.lnick -text "[::msgcat::mc {Nick name}]:" -font $sysFont(sb) \
      -anchor e
    entry $frsub.enick -width 26  \
      -textvariable [namespace current]::locals($uid,name)
    label $frsub.lgroup -text "[::msgcat::mc Group]:" -font $sysFont(sb) -anchor e
    
    ::combobox::combobox $frsub.egroup -font $sysFont(s) -width 18  \
      -textvariable [namespace current]::locals($uid,group)
    eval {$frsub.egroup list insert end} "None $allGroups"
    
    grid $frsub.lnick -column 0 -row 0 -sticky e
    grid $frsub.enick -column 1 -row 0 -sticky ew
    grid $frsub.lgroup -column 0 -row 1 -sticky e
    grid $frsub.egroup -column 1 -row 1 -sticky w
    
    # If we may NOT send a 'subscribe' presence to this user.
    if {!$maySendSubscribe} {
	set locals($uid,add) 0
	$frcont.add configure -state disabled
	$frsub.enick configure -state disabled
	$frsub.egroup configure -state disabled
    }
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btconn -text [::msgcat::mc Accept] -width 8 -default active \
      -command [list [namespace current]::Doit $uid]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Deny] -width 8   \
      -command [list [namespace current]::Cancel $uid]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
    
    wm resizable $w 0 0
    bind $w <Return> "$frbot.btconn invoke"
    focus $w
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w
    
    # Cleanup.
    set finito $locals($uid,finished)
    foreach key [array names locals "$uid,*"] {
	unset locals($key)
    }
    return [expr {($finito <= 0) ? "deny" : "accept"}]
}

proc ::Jabber::Subscribe::SendMsg {uid} {
    global  wDlgs
    variable locals   
        
    ::Jabber::NewMsg::Build $wDlgs(jsendmsg) -to $locals($uid,jid)
}

# Jabber::Subscribe::Doit --
#
#	Execute the subscription.

proc ::Jabber::Subscribe::Doit {uid} {
    
    variable locals   
    upvar ::Jabber::jstate jstate
    
    set jid $locals($uid,jid)
    ::Jabber::Debug 2 "::Jabber::Subscribe::Doit jid=$jid, locals($uid,add)=$locals($uid,add), locals($uid,allow)=$locals($uid,allow)"
    
    # Accept (allow) or deny subscription.
    if {$locals($uid,allow)} {
	$jstate(jlib) send_presence -to $jid -type "subscribed"
    } else {
	$jstate(jlib) send_presence -to $jid -type "unsubscribed"
    }
	
    # Add user to my roster. Send subscription request.	
    if {$locals($uid,add)} {
	set arglist {}
	if {[string length $locals($uid,name)]} {
	    lappend arglist -name $locals($uid,name)
	}
	if {($locals($uid,group) != "") && ($locals($uid,group) != "None")} {
	    lappend arglist -groups [list $locals($uid,group)]
	}
	eval {$jstate(jlib) roster_set $jid ::Jabber::Subscribe::ResProc} \
	  $arglist
	$jstate(jlib) send_presence -to $jid -type "subscribe"
    }
    set locals($uid,finished) 1
    destroy $locals($uid,wtop)
}

proc ::Jabber::Subscribe::Cancel {uid} {
    
    variable locals   
    upvar ::Jabber::jstate jstate
    
    set jid $locals($uid,jid)

    ::Jabber::Debug 2 "::Jabber::Subscribe::Cancel jid=$jid"
    
    # Deny presence to this user.
    $jstate(jlib) send_presence -to $jid -type {unsubscribed}

    set locals($uid,finished) 0
    destroy $locals($uid,wtop)
}

# Jabber::Subscribe::ResProc --
#
#       This is our callback proc when setting the roster item from the
#       subscription dialog. Catch any errors here.

proc ::Jabber::Subscribe::ResProc {jlibName what} {
    
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Subscribe::ResProc: jlibName=$jlibName, what=$what"

    if {[string equal $what "error"]} {
	tk_messageBox -type ok -message "We got an error from the\
	  Jabber::Subscribe::ResProc callback"
    }
    
}

# The ::Jabber::GroupChat:: namespace ------------------------------------------

# Provides dialog for old-style gc-1.0 groupchat but the rest should work for 
# both groupchat and conference protocols.

namespace eval ::Jabber::GroupChat:: {
      
    # Local stuff
    variable locals
}

# Jabber::GroupChat::AllConference --
#
#       Returns 1 only if all services that provided groupchat also support
#       the 'jabber:iq:conference' protocol. This is implicitly obtained
#       by obtaining version number for the conference component. UGLY!!!

proc ::Jabber::GroupChat::AllConference { } {

    upvar ::Jabber::jstate jstate

    set anyNonConf 0
    foreach confjid [$jstate(jlib) service getjidsfor "groupchat"] {
	if {[info exists jstate(conference,$confjid)] &&  \
	  ($jstate(conference,$confjid) == 0)} {
	    set anyNonConf 1
	    break
	}
    }
    if {$anyNonConf} {
	return 0
    } else {
	return 1
    }
}

# Jabber::GroupChat::UseOriginalConference --
#
#       Ad hoc method for finding out if possible to use the original
#       jabber:iq:conference method (not MUC).

proc ::Jabber::GroupChat::UseOriginalConference {{roomjid {}}} {
    
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver

    set ans 0
    if {[string length $roomjid] == 0} {
	if {[::Jabber::Browse::HaveBrowseTree $jserver(this)] &&  \
	  [::Jabber::GroupChat::AllConference]} {
	    set ans 1
	}
    } else {
	
	# Require that conference service browsed and that we have the
	# original jabber:iq:conference
	set confserver [$jstate(browse) getparentjid $roomjid]
	if {[$jstate(browse) isbrowsed $confserver]} {
	    if {$jstate(conference,$confserver)} {
		set ans 1
	    }
	}
    }
    return $ans
}

# Jabber::GroupChat::EnterRoom --
#
#       Dispatch entering a room to either 'groupchat' or 'conference' methods.
#       The 'conference' method requires jabber:iq:browse and jabber:iq:conference
#       
# Arguments:
#       w           toplevel widget
#       args        -server, -roomjid, -autoget
#       
# Results:
#       "cancel" or "enter".

proc ::Jabber::GroupChat::EnterRoom {w args} {

    upvar ::Jabber::jserver jserver
    
    array set argsArr $args
    if {[info exists argsArr(-roomjid)]} {
	set roomjid $argsArr(-roomjid)
    } else {
	set roomjid ""
    }
    if {[::Jabber::GroupChat::UseOriginalConference $roomjid]} {
	set ans [eval {::Jabber::Conference::BuildEnterRoom $w} $args]
    } else {
	set ans [eval {::Jabber::GroupChat::BuildEnter $w} $args]
    }
    return $ans
}

proc ::Jabber::GroupChat::CreateRoom {w args} {

    upvar ::Jabber::jserver jserver

    array set argsArr $args
    if {[info exists argsArr(-roomjid)]} {
	set roomjid $argsArr(-roomjid)
    } else {
	set roomjid ""
    }
    if {[::Jabber::GroupChat::UseOriginalConference $roomjid]} {
	set ans [eval {::Jabber::Conference::BuildCreateRoom $w} $args]
    } else {
	set ans [eval {::Jabber::GroupChat::BuildEnter $w} $args]
    }
    return $ans
}

# Jabber::GroupChat::BuildEnter --
#
#       This is to provide support for the old-style 'groupchat 1.0' protocol
#       which shall be used when not server is being browsed.
#       
# Arguments:
#       w           toplevel widget
#       args        -server, -roomjid, -autoget
#       
# Results:
#       "cancel" or "enter".
     
proc ::Jabber::GroupChat::BuildEnter {w args} {
    global  this sysFont

    variable finishedEnter -1
    variable gchatserver
    variable gchatroom
    variable gchatnick
    upvar ::Jabber::jstate jstate

    set chatservers [$jstate(jlib) service getjidsfor "groupchat"]
    ::Jabber::Debug 2 "::Jabber::GroupChat::BuildEnter args='$args'"
    ::Jabber::Debug 2 "    service getjidsfor groupchat: '$chatservers'"
    
    if {[llength $chatservers] == 0} {
	tk_messageBox -icon error -message [::msgcat::mc jamessnogchat]
	return
    }
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {
	wm transient $w .
    }
    wm title $w [::msgcat::mc {Enter/Create Room}]
    set gchatroom ""
    set gchatnick ""
    array set argsArr $args

    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 4
        
    set gchatserver [lindex $chatservers 0]
    set frmid $w.frall.mid
    pack [frame $frmid] -side top -fill both -expand 1
    set msg [::msgcat::mc jagchatmsg]
    message $frmid.msg -width 260 -font $sysFont(s) -text $msg
    label $frmid.lserv -text "[::msgcat::mc Servers]:" -font $sysFont(sb) -anchor e
    set wcomboserver $frmid.eserv
    ::combobox::combobox $wcomboserver -font $sysFont(s) -width 18  \
      -textvariable [namespace current]::gchatserver
    eval {$frmid.eserv list insert end} $chatservers
    label $frmid.lroom -text "[::msgcat::mc Room]:" -font $sysFont(sb) -anchor e
    entry $frmid.eroom -width 24    \
      -textvariable "[namespace current]::gchatroom" -validate key  \
      -validatecommand {::Jabber::ValidateJIDChars %S}
    label $frmid.lnick -text "[::msgcat::mc {Nick name}]:" -font $sysFont(sb) \
      -anchor e
    entry $frmid.enick -width 24    \
      -textvariable "[namespace current]::gchatnick" -validate key  \
      -validatecommand {::Jabber::ValidateJIDChars %S}
    grid $frmid.msg -column 0 -columnspan 2 -row 0 -sticky ew
    grid $frmid.lserv -column 0 -row 1 -sticky e
    grid $frmid.eserv -column 1 -row 1 -sticky ew 
    grid $frmid.lroom -column 0 -row 2 -sticky e
    grid $frmid.eroom -column 1 -row 2 -sticky ew
    grid $frmid.lnick -column 0 -row 3 -sticky e
    grid $frmid.enick -column 1 -row 3 -sticky ew
    
    if {[info exists argsArr(-roomjid)]} {
	regexp {^([^@]+)@([^/]+)} $argsArr(-roomjid) match gchatroom server
	$wcomboserver configure -state disabled
	$frmid.eroom configure -state disabled
    }
    if {[info exists argsArr(-server)]} {
	set server $argsArr(-server)
	$wcomboserver configure -state disabled
    }
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btconn -text [::msgcat::mc Enter] -width 8 -default active \
      -command [list [namespace current]::DoEnter $w]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btexit -text [::msgcat::mc Cancel] -width 8   \
      -command [list [namespace current]::Cancel $w]]  \
      -side right -padx 5 -pady 5  
    pack $frbot -side bottom -fill x
    
    # Grab and focus.
    set oldFocus [focus]
    focus $w
    catch {grab $w}
    bind $w <Return> "$frbot.btconn invoke"
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w
    
    catch {grab release $w}
    focus $oldFocus
    return [expr {($finishedEnter <= 0) ? "cancel" : "enter"}]
}

proc ::Jabber::GroupChat::Cancel {w} {
    variable finishedEnter
    
    set finishedEnter 0
    destroy $w
}

proc ::Jabber::GroupChat::DoEnter {w} {

    variable finishedEnter
    variable gchatserver
    variable gchatroom
    variable gchatnick
    upvar ::Jabber::jstate jstate
    
    # Verify the fields first.
    if {([string length $gchatserver] == 0) ||  \
      ([string length $gchatroom] == 0) ||  \
      ([string length $gchatnick] == 0)} {
	tk_messageBox -title [::msgcat::mc Warning] -type ok -message \
	  [::msgcat::mc jamessgchatfields]
	return
    }
    set finishedEnter 1
    destroy $w

    $jstate(jlib) groupchat enter ${gchatroom}@${gchatserver} $gchatnick \
      -command [namespace current]::EnterCallback
}

proc ::Jabber::GroupChat::EnterCallback {jlibName type args} {
    
    if {[string equal $type "error"]} {
	array set argsArr $args
	set msg "We got an error when entering room \"$argsArr(-from)\"."
	if {[info exists argsArr(-error)]} {
	    foreach {errcode errmsg} $argsArr(-error) { break }
	    append msg " The error code is $errcode: $errmsg"
	}
	tk_messageBox -title "Error Enter Room" -message $msg
    }
}

# Jabber::GroupChat::GotMsg --
#
#       Just got a group chat message. Fill in message in existing dialog.
#       If no dialog, make a freash one.
#       
# Arguments:
#       body        the text message.
#       args        ?-key value? pairs
#       
# Results:
#       updates UI.

proc ::Jabber::GroupChat::GotMsg {body args} {
    global  prefs

    variable locals
    upvar ::Jabber::mapShowElemToText mapShowElemToText
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate

    ::Jabber::Debug 2 "::Jabber::GroupChat::GotMsg args='$args'"

    array set argsArr $args
    
    # We must follow the roomJid...
    if {[info exists argsArr(-from)]} {
	set fromJid $argsArr(-from)
    } else {
	return -code error {Missing -from attribute in group message!}
    }
    
    # Figure out if from the room or from user.
    if {[regexp {(.+)@([^/]+)(/(.+))?} $fromJid match name host junk res]} {
	set roomJid ${name}@${host}
	if {$res == ""} {
	    # From the room itself.
	}
    } else {
	return -code error "The jid we got \"$fromJid\"was not well-formed!"
    }

    # If we haven't a window for this thread, make one!
    if {[info exists locals($roomJid,wtop)] &&  \
      [winfo exists $locals($roomJid,wtop)]} {
    } else {
	eval {::Jabber::GroupChat::Build $roomJid} $args
    }       
    
    # This can be room name or nick name.
    foreach {meRoomJid mynick} [$jstate(jlib) service hashandnick $roomJid] { break }

    # Old-style groupchat and browser compatibility layer.
    set nick [$jstate(jlib) service nick $fromJid]
    
    set wtext $locals($roomJid,wtext)
    if {$jprefs(chat,showtime)} {
	set theTime [clock format [clock seconds] -format "%H:%M"]
	set txt "$theTime <$nick>"
    } else {
	set txt <$nick>
    }
    $wtext configure -state normal
    if {[string equal $meRoomJid $fromJid]} {
	set meyou me
    } else {
	set meyou you
    }
    $wtext insert end $txt ${meyou}tag
    set textCmds [::Text::ParseAllForTextWidget "  $body" ${meyou}txttag linktag]
    foreach cmd $textCmds {
	eval $wtext $cmd
    }
    $wtext insert end "\n"
    
    $wtext configure -state disabled
    $wtext see end
    if {$locals($roomJid,got1stMsg) == 0} {
	set locals($roomJid,got1stMsg) 1
    }
    
    if {$jprefs(speakChat)} {
	if {$meyou == "me"} {
	    ::UserActions::Speak $body $prefs(voiceUs)
	} else {
	    ::UserActions::Speak $body $prefs(voiceOther)
	}
    }
}

# Jabber::GroupChat::Build --
#
#       Builds the group chat dialog. Independently on protocol 'groupchat'
#       and 'conference'.
#
# Arguments:
#       roomJid     The roomname@server
#       args        ??
#       
# Results:
#       shows window.

proc ::Jabber::GroupChat::Build {roomJid args} {
    global  this sysFont prefs
    
    variable locals
    upvar ::Jabber::mapShowElemToText mapShowElemToText
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Jabber::Debug 2 "::Jabber::GroupChat::Build roomJid=$roomJid, args='$args'"
    
    # Make unique toplevel name from rooms jid.
    regsub -all {\.} $roomJid {_} wunique
    regsub -all {@} $wunique {_} wunique
    set w ".[string tolower $wunique]"
    
    set locals($roomJid,wtop) $w
    set locals($w,room) $roomJid
    if {[winfo exists $w]} {
	return
    }
    array set argsArr $args
    if {[info exists argsArr(-from)]} {
	set locals($roomJid,jid) $argsArr(-from)
    }
    set locals($roomJid,got1stMsg) 0
    toplevel $w -class GroupChat
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {
	#wm transient $w .
    }
    
    # Not sure how old-style groupchat works here???
    set roomName [$jstate(browse) getname $roomJid]
    
    if {[llength $roomName]} {
	set tittxt $roomName
    } else {
	set tittxt $roomJid
    }
    wm title $w $tittxt
    wm protocol $w WM_DELETE_WINDOW  \
      [list ::Jabber::GroupChat::Exit $roomJid]
    wm group $w .

    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 4
        
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btsnd -text [::msgcat::mc Send] -width 8  \
      -default active -command [list [namespace current]::Send $roomJid]] \
      -side right -padx 5 -pady 5
    pack [button $frbot.btexit -text [::msgcat::mc Exit] -width 8   \
      -command [list [namespace current]::Exit $roomJid]]  \
      -side right -padx 5 -pady 5  
    
    # CCP
    pack [frame $w.frall.fccp] -side top -fill x
    set wccp $w.frall.fccp.ccp
    pack [::UI::NewCutCopyPaste $wccp] -padx 10 -pady 2 -side left
    ::UI::CutCopyPasteConfigure $wccp cut -state disabled
    ::UI::CutCopyPasteConfigure $wccp copy -state disabled
    ::UI::CutCopyPasteConfigure $wccp paste -state disabled
    pack [frame $w.frall.fccp.div -bd 2 -relief raised -width 2] -fill y -side left
    pack [::UI::NewPrint $w.frall.fccp.pr [list [namespace current]::Print $roomJid]] \
      -side left -padx 10
    pack [frame $w.frall.div2 -bd 2 -relief sunken -height 2] -fill x -side top

    # Popup for setting status to this room.
    set allStatus [array names mapShowElemToText]
    set locals($roomJid,status) [::msgcat::mc Available]
    set locals($roomJid,oldStatus) [::msgcat::mc Available]
    set wpopup $frbot.popup
    set wMenu [eval {tk_optionMenu $wpopup  \
      [namespace current]::locals($roomJid,status)} $allStatus]
    $wpopup configure -highlightthickness 0 -width 14 \
      -background $prefs(bgColGeneral) -foreground black
    pack $wpopup -side left -padx 5 -pady 5
    
    pack $frbot -side bottom -fill x -padx 10 -pady 8
    
    # Keep track of all buttons that need to be disabled on logout.
    set locals($roomJid,allBts) [list $frbot.btsnd $frbot.btexit $wpopup]
        
    # Header fields.
    set frtop [frame $w.frall.frtop -borderwidth 0]
    pack $frtop -side top -fill x   
    label $frtop.la -text {Group chat in room:} -font $sysFont(sb) -anchor e
    entry $frtop.en -bg $prefs(bgColGeneral)
    grid $frtop.la -column 0 -row 0 -sticky e -padx 8 -pady 2
    grid $frtop.en -column 1 -row 0 -sticky ew -padx 4 -pady 2
    grid columnconfigure $frtop 1 -weight 1
    $frtop.en insert end $roomJid
    $frtop.en configure -state disabled
    
    # Text chat and user list.
    set frmid $w.frall.frmid
    pack [frame $frmid -height 250 -width 300 -relief sunken -bd 1]  \
      -side top -fill both -expand 1 -padx 4 -pady 4
    set wtxt $frmid.frtxt
    frame $wtxt -height 200
    frame $wtxt.0 -bg $prefs(bgColGeneral)
    set wtext $wtxt.0.text
    set wysc $wtxt.0.ysc
    set wusers $wtxt.users
    text $wtext -height 12 -width 1 -font $sysFont(s) -state disabled  \
      -borderwidth 1 -relief sunken -yscrollcommand [list $wysc set] -wrap word \
      -cursor {}
    text $wusers -height 12 -width 12 -font $sysFont(s) -state disabled  \
      -borderwidth 1 -relief sunken -background $prefs(bgColGeneral)  \
      -spacing1 1 -spacing3 1 -wrap none -cursor {}
    scrollbar $wysc -orient vertical -command [list $wtext yview]
    pack $wtext -side left -fill both -expand 1
    pack $wysc -side right -fill y -padx 2

    if {[info exists prefs(paneGeom,groupchatDlgHori)]} {
	set relpos $prefs(paneGeom,groupchatDlgHori)
    } else {
	set relpos {0.8 0.2}
    }
    ::pane::pane $wtxt.0 $wusers -limit 0.0 -relative $relpos -orient horizontal
    
    # The tags.
    set space 2
    $wtext tag configure metag -foreground red -background #cecece  \
      -spacing1 $space -font $sysFont(sb)
    $wtext tag configure metxttag -foreground black -background #cecece  \
      -spacing1 $space -spacing3 $space -lmargin1 20 -lmargin2 20
    $wtext tag configure youtag -foreground blue -spacing1 $space  \
       -font $sysFont(sb)
    $wtext tag configure youtxttag -foreground black -spacing1 $space  \
      -spacing3 $space -lmargin1 20 -lmargin2 20

    # Text send.
    set wtxtsnd $frmid.frtxtsnd
    frame $wtxtsnd -height 100 -width 300
    set wtextsnd $wtxtsnd.text
    set wyscsnd $wtxtsnd.ysc
    text $wtextsnd -height 4 -width 1 -font $sysFont(s) -wrap word \
      -borderwidth 1 -relief sunken -yscrollcommand [list $wyscsnd set]
    scrollbar $wyscsnd -orient vertical -command [list $wtextsnd yview]
    grid $wtextsnd -column 0 -row 0 -sticky news
    grid $wyscsnd -column 1 -row 0 -sticky ns
    grid columnconfigure $wtxtsnd 0 -weight 1
    grid rowconfigure $wtxtsnd 0 -weight 1

    if {[info exists prefs(paneGeom,groupchatDlgVert)]} {
	set relpos $prefs(paneGeom,groupchatDlgVert)
    } else {
	set relpos {0.8 0.2}
    }
    ::pane::pane $wtxt $wtxtsnd -limit 0.0 -relative $relpos -orient vertical
    
    set locals($roomJid,wtext) $wtext
    set locals($roomJid,wtextsnd) $wtextsnd
    set locals($roomJid,wusers) $wusers
    set locals($roomJid,wtxt.0) $wtxt.0
    set locals($roomJid,wtxt) $wtxt
	
    # Add to exit menu.
    $locals(exitmenu) add command -label $roomJid  \
      -command [list ::Jabber::GroupChat::Exit $roomJid]
    
    # Necessary to trace the popup menu variable.
    trace variable [namespace current]::locals($roomJid,status) w  \
      [list [namespace current]::TraceStatus $roomJid]

    if {[info exists prefs(winGeom,groupchatDlg)]} {
	wm geometry $w $prefs(winGeom,groupchatDlg)
    }
    wm minsize $w 240 320
    wm maxsize $w 800 2000
    
    focus $w
}

proc ::Jabber::GroupChat::Send {roomJid} {
    global  prefs
    
    variable locals
    upvar ::Jabber::jstate jstate
    
    # Check that still connected to server.
    if {![::Jabber::IsConnected]} {
	tk_messageBox -type ok -icon error -title [::msgcat::mc {Not Connected}] \
	  -message [::msgcat::mc jamessnotconnected]
	return
    }
    set wtextsnd $locals($roomJid,wtextsnd)

    # Get text to send.
    set allText [$wtextsnd get 1.0 "end - 1 char"]
    if {$allText != ""} {	
	if {[catch {
	    $jstate(jlib) send_message $roomJid -type groupchat \
	      -body $allText
	} err]} {
	    tk_messageBox -type ok -icon error -title "Network Error" \
	      -message "Network error ocurred: $err"
	    return
	}
    }
    
    # Clear send.
    $wtextsnd delete 1.0 end
    if {$locals($roomJid,got1stMsg) == 0} {
	set locals($roomJid,got1stMsg) 1
    }
}

# Jabber::GroupChat::TraceStatus --
# 
#       Callback via trace when the status is changed via the menubutton.
#

proc ::Jabber::GroupChat::TraceStatus {roomJid name key op} {

    variable locals
    upvar ::Jabber::mapShowElemToText mapShowElemToText
    upvar ::Jabber::jstate jstate
	
    # Call by name. Must be array.
    #upvar #0 ${name}(${key}) locName    
    upvar ${name}(${key}) locName

    ::Jabber::Debug 3 "::Jabber::GroupChat::TraceStatus roomJid=$roomJid, name=$name, \
      key=$key"
    ::Jabber::Debug 3 "    locName=$locName"

    set status $mapShowElemToText($locName)
    if {$status == "unavailable"} {
	set ans [::Jabber::GroupChat::Exit $roomJid]
	if {$ans == "no"} {
	    set locals($roomJid,status) $locals($roomJid,oldStatus)
	}
    } else {
    
	# Send our status.
	::Jabber::SetStatus $status $roomJid
	set locals($roomJid,oldStatus) $locName
    }
}

# Jabber::GroupChat::Presence --
#
#       Sets the presence of the jid in our UI.
#
# Arguments:
#       jid         'user@server' without resource
#       presence    "available", "unavailable", or "unsubscribed"
#       args        list of '-key value' pairs where '-key' can be
#                   -resource, -from, -type, -show...
#       
# Results:
#       groupchat member list updated.

proc ::Jabber::GroupChat::Presence {jid presence args} {

    variable locals
    
    ::Jabber::Debug 2 "::Jabber::GroupChat::Presence jid=$jid, presence=$presence, args='$args'"

    array set attrArr $args
    
    # Since there should not be any /resource.
    set roomJid $jid
    set jidhash ${jid}/$attrArr(-resource)
    if {[string equal $presence "available"]} {
	eval {::Jabber::GroupChat::SetUser $roomJid $jidhash $presence} $args
    } elseif {[string equal $presence "unavailable"]} {
	::Jabber::GroupChat::RemoveUser $roomJid $jidhash
    }
}

# Jabber::GroupChat::BrowseUser --
#
#       This is a <user> element. Gets called for each <user> element
#       in the jabber:iq:browse set or result iq element.
#       Only called if have conference/browse stuff for this service.

proc ::Jabber::GroupChat::BrowseUser {userXmlList} {
    
    variable locals
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::GroupChat::BrowseUser userXmlList='$userXmlList'"

    array set attrArr [lindex $userXmlList 1]
    
    # Direct it to the correct room. 
    set jid $attrArr(jid)
    set parentList [$jstate(browse) getparents $jid]
    set parent [lindex $parentList end]
    
    # Do something only if joined that room.
    if {[$jstate(browse) isroom $parent] &&  \
      ([lsearch [$jstate(jlib) conference allroomsin] $parent] >= 0)} {
	if {[info exists attrArr(type)] && [string equal $attrArr(type) "remove"]} {
	    ::Jabber::GroupChat::RemoveUser $parent $jid
	} else {
	    ::Jabber::GroupChat::SetUser $parent $jid {}
	}
    }
}

# Jabber::GroupChat::SetUser --
#
#       Adds or updates a user item in the group chat dialog.
#       
# Arguments:
#       roomJid     the room's jid
#       jidhash     $roomjid/hashornick
#       presence    "available", "unavailable", or "unsubscribed"
#       args        list of '-key value' pairs where '-key' can be
#                   -resource, -from, -type, -show...
#       
# Results:
#       updated UI.

proc ::Jabber::GroupChat::SetUser {roomJid jidhash presence args} {
    global  this

    variable locals
    upvar ::Jabber::jstate jstate

    ::Jabber::Debug 2 "::Jabber::GroupChat::SetUser roomJid=$roomJid,\
      jidhash=$jidhash presence=$presence"

    array set attrArr $args

    # If we haven't a window for this thread, make one!
    if {[info exists locals($roomJid,wtop)] &&  \
      [winfo exists $locals($roomJid,wtop)]} {
    } else {
	eval {::Jabber::GroupChat::Build $roomJid} $args
    }       
    
    # Get the hex string to use as tag. 
    # In old-style groupchat this is the nick name which should be unique
    # within this room aswell.
    if {![regexp {[^@]+@[^/]+/(.+)} $jidhash match hexstr]} {
	error {Failed finding hex string}
    }    
    
    # If we got a browse push with a <user>, asume is available.
    if {[string length $presence] == 0} {
	set presence available
    }
    
    # Any show attribute?
    set showStatus $presence
    if {[info exists attrArr(-show)] && [string length $attrArr(-show)]} {
	set showStatus $attrArr(-show)
    } elseif {[info exists attrArr(-subscription)] &&   \
      [string equal $attrArr(-subscription) "none"]} {
	set showStatus {subnone}
    }
    
    # Remove any "old" line first. Image takes one character's space.
    set wusers $locals($roomJid,wusers)
    
    # Old-style groupchat and browser compatibility layer.
    set nick [$jstate(jlib) service nick $jidhash]
    set icon [eval {::Jabber::GetPresenceIcon $jidhash $presence} $args]
    $wusers configure -state normal
    set insertInd end
    set begin end
    set range [$wusers tag ranges $hexstr]
    if {[llength $range]} {
	
	# Remove complete line including image.
	set insertInd [lindex $range 0]
	set begin "$insertInd linestart"
	$wusers delete "$insertInd linestart" "$insertInd lineend +1 char"
    }    
    
    # Icon that is popup sensitive.
    $wusers image create $begin -image $icon -align bottom
    $wusers tag add $hexstr "$begin linestart" "$begin lineend"

    # Use hex string (resource) as tag.
    $wusers insert "$begin +1 char" " $nick\n" $hexstr
    $wusers configure -state disabled
    
    # For popping up menu.
    if {[string match "mac*" $this(platform)]} {
	$wusers tag bind $hexstr <Button-1>  \
	  [list ::Jabber::GroupChat::PopupTimer $wusers $jidhash %x %y]
	$wusers tag bind $hexstr <ButtonRelease-1>   \
	  ::Jabber::GroupChat::PopupTimerCancel
    } else {
	$wusers tag bind $hexstr <Button-3>  \
	  [list ::Jabber::Popup groupchat $wusers $jidhash %x %y]
    }
    
    # Noise.
    ::Sounds::Play online
}
    
proc ::Jabber::GroupChat::PopupTimer {w jidhash x y} {
    
    variable locals
    upvar ::Jabber::jstate jstate

    ::Jabber::Debug 2 "::Jabber::GroupChat::PopupTimer w=$w, jidhash=$jidhash"

    # Set timer for this callback.
    if {[info exists locals(afterid)]} {
	catch {after cancel $locals(afterid)}
    }
    set locals(afterid) [after 1000  \
      [list ::Jabber::Popup groupchat $w $jidhash $x $y]]
}

proc ::Jabber::GroupChat::PopupTimerCancel { } {
    variable locals
    catch {after cancel $locals(afterid)}
}

proc ::Jabber::GroupChat::RemoveUser {roomJid jidhash} {

    variable locals    
    if {![winfo exists $locals($roomJid,wusers)]} {
	return
    }
    
    # Get the hex string to use as tag.
    if {![regexp {[^@]+@[^/]+/(.+)} $jidhash match hexstr]} {
	error {Failed finding hex string}
    }    
    set wusers $locals($roomJid,wusers)
    $wusers configure -state normal
    set range [$wusers tag ranges $hexstr]
    if {[llength $range]} {
	set insertInd [lindex $range 0]
	$wusers delete "$insertInd linestart" "$insertInd lineend +1 char"
    }
    $wusers configure -state disabled
    
    # Noise.
    ::Sounds::Play offline
}

proc ::Jabber::GroupChat::SetAllRoomsMenu {theMenu} {   
    variable locals
    set locals(exitmenu) $theMenu
}

# Jabber::GroupChat::ConfigWBStatusMenu --
# 
#       Sets the Jabber/Status menu for groupchat:
#       -variable ... -command {}

proc ::Jabber::GroupChat::ConfigWBStatusMenu {wtop} {   
    variable locals

    array set wbOpts [::UI::ConfigureMain $wtop]
    set roomJid $wbOpts(-jid)

    # Orig: {-variable ::Jabber::jstate(status) -value available}
    # Not same values due to the design of the tk_optionMenu.
    foreach mName {mAvailable mAway mDoNotDisturb mNotAvailable} {
	::UI::MenuMethod ${wtop}menu.jabber.mstatus entryconfigure $mName \
	  -command {} -variable [namespace current]::locals($roomJid,status) \
	  -value [::msgcat::mc $mName]
    }
    ::UI::MenuMethod ${wtop}menu.jabber.mstatus entryconfigure mAttachMessage \
      -command {} -state disabled
    
    # Just skip this menu entry.
    ::UI::MenuMethod ${wtop}menu.jabber entryconfigure mExitRoom \
      -state disabled
}

proc ::Jabber::GroupChat::Print {roomJid} {
    variable locals
    set wtext $locals($roomJid,wtext) 
    ::UserActions::DoPrintText $wtext
}

# Jabber::GroupChat::Exit --
#
#       Ask if wants to exit room. If then calls GroupChat::Close to do it.
#       
# Arguments:
#       roomJid
#       
# Results:
#       yes/no if actually exited or not.

proc ::Jabber::GroupChat::Exit {roomJid} {
    
    variable locals
    upvar ::Jabber::jstate jstate
    
    set w $locals($roomJid,wtop)

    if {[::Jabber::IsConnected]} {
	set ans [tk_messageBox -icon warning -parent $w -type yesno  \
	  -message [::msgcat::mc jamesswarnexitroom $roomJid]]
	if {$ans == "yes"} {
	    ::Jabber::GroupChat::Close $roomJid
	    $jstate(jlib) service exitroom $roomJid
	    catch {$locals(exitmenu) delete $roomJid}
	}
    } else {
	set ans "yes"
	::Jabber::GroupChat::Close $roomJid
    }
    return $ans
}

proc ::Jabber::GroupChat::CloseToplevel {w} {
    variable locals
    
    set roomJid $locals($w,room)     
    ::Jabber::GroupChat::Close $roomJid
}

# Jabber::GroupChat::Close --
#
#       Handles the closing of a groupchat. Both text and whiteboard dialogs.

proc ::Jabber::GroupChat::Close {roomJid} {
    variable locals
    upvar ::Jabber::jstate jstate
    
    set locals(winGeom) [list groupchatDlg [wm geometry $locals($roomJid,wtop)]]
    ::UI::SavePanePos groupchatDlgVert $locals($roomJid,wtxt) vertical
    ::UI::SavePanePos groupchatDlgHori $locals($roomJid,wtxt.0)
    ::Jabber::GroupChat::GetPanePos $roomJid
    
    # after idle seems to be needed to avoid crashing the mac :-(
    after idle destroy $locals($roomJid,wtop)
    trace vdelete [namespace current]::locals($roomJid,status) w  \
      [list [namespace current]::TraceStatus $roomJid]
	
    # Make sure any associated whiteboard is closed as well.
    set wbwtop [::UI::GetWtopFromJabberType "groupchat" $roomJid]
    if {[string length $wbwtop]} {
	::UI::DestroyMain $wbwtop
    }
}

# Jabber::GroupChat::Logout --
#
#       Sets logged out status on all groupchats, that is, disable all buttons.

proc ::Jabber::GroupChat::Logout { } {
    
    variable locals
    upvar ::Jabber::jstate jstate

    set allRooms [$jstate(jlib) service allroomsin]
    foreach room $allRooms {
	set w $locals($room,wtop)
	catch {$locals(exitmenu) delete $room}
	if {[winfo exists $w]} {
	    foreach wbt $locals($room,allBts) {
		$wbt configure -state disabled
	    }
	}
    }
}

proc ::Jabber::GroupChat::GetWinGeom { } {
    
    variable locals

    set ans {}
    set found 0
    foreach key [array names locals "*,wtop"] {
	if {[winfo exists $locals($key)]} {
	    set wtop $locals($key)
	    set found 1
	    break
	}
    }
    if {$found} {
	set ans [list groupchatDlg [wm geometry $wtop]]
    } elseif {[info exists locals(winGeom)]} {
	set ans $locals(winGeom)
    }
    return $ans
}

# Jabber::GroupChat::GetPanePos --
#
#       Return typical pane position list. If $roomJid is given, pick this
#       particular dialog, else first found.

proc ::Jabber::GroupChat::GetPanePos {{roomJid {}}} {

    variable locals

    set ans {}
    if {$roomJid == ""} {
	set found 0
	foreach key [array names locals "*,wtxt"] {
	    set wtxt $locals($key)
	    set wtxt0 ${wtxt}.0
	    if {[winfo exists $wtxt]} {
		set found 1
		break
	    }
	}
    } else {
	set found 1
	set wtxt $locals($roomJid,wtxt)    
	set wtxt0 $locals($roomJid,wtxt.0)    
    }
    if {$found} {
	array set infoArr [::pane::pane info $wtxt]
	lappend ans groupchatDlgVert   \
	  [list $infoArr(-relheight) [expr 1.0 - $infoArr(-relheight)]]
	array set infoArr0 [::pane::pane info $wtxt0]
	lappend ans groupchatDlgHori   \
	  [list $infoArr0(-relwidth) [expr 1.0 - $infoArr0(-relwidth)]]
	set locals(panePosList) $ans
    } elseif {[info exists locals(panePosList)]} {
	set ans $locals(panePosList)
    } else {
	set ans {}
    }
    return $ans
}

# The ::Jabber::Browse:: namespace -------------------------------------------

namespace eval ::Jabber::Browse:: {

    variable wtop {}

    # We keep an reference count that gets increased by one for each request
    # sent, and decremented by one for each response.
    variable arrowRefCount 0
    
    # Options only for internal use. EXPERIMENTAL! See browse.tcl
    #     -setbrowsedjid:   default=1, store the browsed jid even if cached already
    variable options
    array set options {
	-setbrowsedjid 1
    }
    
    # Just a dummy widget name for the running arrows until it's built.
    variable wsearrows .xx
}

# Jabber::Browse::GetAll --
#
#       Queries (browses) the services available for all the servers
#       that are in 'jprefs(browseServers)' plus the login server.
#
# Arguments:
#       
# Results:
#       none.

proc ::Jabber::Browse::GetAll { } {

    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jserver jserver
    
    set allServers [lsort -unique [concat $jserver(this) $jprefs(browseServers)]]
    foreach server $allServers {
	::Jabber::Browse::Get $server
    }
}

# Jabber::Browse::Get --
#
#       Queries (browses) the services available for the $jid.
#
# Arguments:
#       jid         The jid to browse.
#       args    ?-silent 0/1? (D=0)
#       
# Results:
#       callback scheduled.

proc ::Jabber::Browse::Get {jid args} {
    
    upvar ::Jabber::jstate jstate
    
    array set opts {
	-silent 0
    }
    array set opts $args
    
    # Browse services available.
    $jstate(jlib) browse_get $jid -errorcommand  \
      [list ::Jabber::Browse::ErrorProc $opts(-silent)]
}

# Jabber::Browse::HaveBrowseTree --
#
#       Does the jid belong to a browse tree? This only if we actually
#       have browsed the server the jid belongs to.

proc ::Jabber::Browse::HaveBrowseTree {jid} {
    
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jstate jstate
    
    set allServers [lsort -unique [concat $jserver(this) $jprefs(browseServers)]]
	
    # This is not foolproof!!!
    foreach server $allServers {
	 if {[string match "*$server" $jid]} {
	     if {[$jstate(browse) isbrowsed $server]} {
		 return 1
	     }
	 }
    }    
    return 0
}

# Jabber::Browse::Callback --
#
#       The callback proc from the 'browse' object.
#       It receives reports from iq set and result elements with the
#       jabber:iq:browse namespace.
#
# Arguments:
#       type:       can be 'set', or 'error'.
#       jid:        the jid of the first element in 'subiq'.
#       subiq:      xml list starting after the <iq> tag;
#                   if 'error' then {errorCode errorMsg}
#       
# Results:
#       none. UI maybe updated, jids may be auto browsed.

proc ::Jabber::Browse::Callback {browseName type jid subiq} {
    
    variable wtop
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    
    ::Jabber::Debug 2 "::Jabber::Browse::Callback browseName=$browseName, type=$type,\
      jid=$jid, subiq='[string range $subiq 0 30] ...'"

    ::Jabber::Browse::ControlArrows -1

    switch -- $type {
	error {
	    
	    # Shall we be silent? 
	    if {[winfo exists $wtop]} {
		tk_messageBox -type ok -icon error \
		  -message [FormatTextForMessageBox  \
		  [::msgcat::mc jamesserrbrowse $jid [lindex $subiq 1]]]
	    }
	}
	set {
    
	    # It is at this stage we are confident that a Browser page is needed.
	    if {[string equal $jid $jserver(this)]} {
		::Jabber::RostServ::NewPage "Browser"
	    }
	    
	    # We shall fill in the browse tree.
	    set parents [$jstate(browse) getparents $jid]
	    ::Jabber::Browse::AddToTree $parents $jid $subiq 1
	    
	    # If we have a conference (groupchat) window.
	    ::Jabber::Browse::DispatchUsers $jid $subiq
	    
	    # Browse all services for any public (jabber) conference servers.
	    # Two things: 
	    #     1) we need to query its version number to know which 
	    #        protocol to use. 
	    #        The old groupchat protocol is used as a fallback.
	    #     2) if belongs to our login server, then browse it
	       
	    foreach child [wrapper::getchildren $subiq] {
		
		# We need to take into account the changed browse syntax:
		# 1)  <conference ...
		# 2)  <item category='conference' ...
		set isConference 0
		set tag [lindex $child 0]
		if {[string equal $tag "conference"]} {
		    set isConference 1
		} elseif {[string equal $tag "item"]} {
		    set category [wrapper::getattr [lindex $child 1] category]
		    if {[string equal $category "conference"]} {
			set isConference 1
		    }
		}
		if {$isConference} {
		    catch {unset cattrArr}
		    array set cattrArr [lindex $child 1]
		    set confjid $cattrArr(jid)
		    
		    # Exclude the rooms.
		    if {![string match "*@*" $confjid]} {
			
			# Keep a record of which components that support the
			# jabber:iq:conference namespace
			if {![info exists jstate(conference,$confjid)]} {
			    set jstate(conference,$confjid) 0
			}
			
			# General: (groupchat | conference | muc)
			if {![info exists jstate(groupchattype,$confjid)]} {
			    set jstate(groupchattype,$confjid) "groupchat"
			}
			
			# Version query only for jabber conferences 
			#        (type='private' or 'public')
			if {[info exists cattrArr(type)] &&  \
			  ($cattrArr(type) == "public" ||  \
			  $cattrArr(type) == "private")} {
			    $jstate(jlib) get_version $confjid   \
			      [list ::Jabber::CacheGroupchatType $confjid]
			}

			# Auto browse only 'public' jabber conferences.
			if {[info exists cattrArr(type)] &&   \
			  $cattrArr(type) == "public"} {
			    ::Jabber::Browse::Get $confjid -silent 1
			}
		    }
		}
	    }
	}
    }
}

# Jabber::Browse::DispatchUsers --
#
#       Find any <user> element and send to groupchat.

proc ::Jabber::Browse::DispatchUsers {jid subiq} {

    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Browse::DispatchUsers jid=$jid,\
      subiq='[string range $subiq 0 30] ...'"
    
    # Find any <user> elements.
    if {[string equal [lindex $subiq 0] "user"]} {
	::Jabber::GroupChat::BrowseUser $subiq
    }
    foreach child [wrapper::getchildren $subiq] {
	if {[string equal [lindex $child 0] "user"]} {
	    ::Jabber::GroupChat::BrowseUser $child	    
	}
    }
}

# Jabber::Browse::ErrorProc --
# 
#       Error callback for jabber:iq:browse method. Non errors handled by the
#       browse object.
#
#

proc ::Jabber::Browse::ErrorProc {silent browseName type jid errlist} {

    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jerror jerror
    
    ::Jabber::Debug 2 "::Jabber::Browse::ErrorProc type=$type, jid=$jid, errlist='$errlist'"

    ::Jabber::Browse::ControlArrows 0
    
    # If we got an error browsing an actual server, then remove from list.
    set ind [lsearch -exact $jprefs(browseServers) $jid]
    if {$ind >= 0} {
	set jprefs(browseServers) [lreplace $jprefs(browseServers) $ind $ind]
    }
    
    # Silent...
    if {$silent} {
	lappend jerror [list [clock format [clock seconds] -format "%H:%M:%S"] \
	  $jid  \
	  "Failed browsing: Error code [lindex $errlist 0] and message:\
	  [lindex $errlist 1]"]
    } else {
	tk_messageBox -icon error -type ok -title [::msgcat::mc Error] \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamesserrbrowse $jid [lindex $errlist 1]]]
    }
    
    # As a fallback we use the agents method instead if browsing the login
    # server fails.
    if {[string equal $jid $jserver(this)]} {
	::Jabber::Agents::GetAll
    }
}


proc ::Jabber::Browse::Show {w} {
    
    upvar ::Jabber::jstate jstate

    if {$jstate(browseVis)} {
	if {[winfo exists $w]} {
	    wm deiconify $w
	} else {
	    ::Jabber::Browse::BuildToplevel $w
	}
    } else {
	wm withdraw $w
    }
}

proc ::Jabber::Browse::BuildToplevel {w} {
    global  this sysFont prefs

    variable wtop

    if {[winfo exists $w]} {
	return
    }
    set wtop $w
    
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {
	wm transient $w .
    }
    wm title $w {Jabber Browser}
    wm protocol $w WM_DELETE_WINDOW [list ::Jabber::Browse::CloseDlg $w]
    
    # Toplevel menu for mac only. Only when multiinstance.
    if {0 && [string match "mac*" $this(platform)]} {
	set wmenu ${w}.menu
	menu $wmenu -tearoff 0
	::UI::MakeMenu $w ${wmenu}.apple   {}       $::UI::menuDefs(main,apple)
	::UI::MakeMenu $w ${wmenu}.file    mFile    $::UI::menuDefs(min,file)
	::UI::MakeMenu $w ${wmenu}.edit    mEdit    $::UI::menuDefs(min,edit)	
	::UI::MakeMenu $w ${wmenu}.jabber  mJabber  $::UI::menuDefs(main,jabber)
	$w configure -menu ${wmenu}
    }
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 12 -ipady 4
    
    message $w.frall.msg -width 220 -font $sysFont(sb) -anchor w -text \
      {Services that are available on each Jabber server listed.}
    message $w.frall.msg2 -width 220 -font $sysFont(s) -anchor w -text  \
      {Open to display its properties}
    pack $w.frall.msg $w.frall.msg2 -side top -fill x -padx 4 -pady 2

    # And the real stuff.
    pack [::Jabber::Browse::Build $w.frall.br] -side top -fill both -expand 1
    
    wm minsize $w 180 260
    wm maxsize $w 420 2000
}
    
# Jabber::Browse::Build --
#
#       Makes mega widget to show the services available for the $server.
#
# Arguments:
#       w           frame window with everything.
#       
# Results:
#       w

proc ::Jabber::Browse::Build {w} {
    global  this sysFont prefs
    
    variable wtree
    variable wtreecanvas
    variable wsearrows
    variable wtop
    variable btaddserv
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jprefs jprefs
    
    ::Jabber::Debug 2 "::Jabber::Browse::Build"
    
    # The frame.
    frame $w -borderwidth 0 -relief flat
    set wbrowser $w
    
    set frbot [frame $w.frbot -borderwidth 0]
    set wsearrows $frbot.arr        
    pack [::chasearrows::chasearrows $wsearrows -background gray87 -size 16] \
      -side left -padx 5 -pady 5
    pack $frbot -side bottom -fill x -padx 8 -pady 6
    
    set wbox $w.box
    pack [frame $wbox -border 1 -relief sunken]   \
      -side top -fill both -expand 1 -padx 6 -pady 6
    set wtree $wbox.tree
    set wxsc $wbox.xsc
    set wysc $wbox.ysc
    scrollbar $wxsc -orient horizontal -command [list $wtree xview]
    scrollbar $wysc -orient vertical -command [list $wtree yview]
    ::tree::tree $wtree -width 180 -height 200 -silent 1  \
      -openicons triangle -treecolor {} -scrollwidth 400 \
      -xscrollcommand [list $wxsc set]       \
      -yscrollcommand [list $wysc set]       \
      -selectcommand ::Jabber::Browse::SelectCmd   \
      -opencommand ::Jabber::Browse::OpenTreeCmd   \
      -highlightcolor #6363CE -highlightbackground $prefs(bgColGeneral)
    set wtreecanvas [$wtree getcanvas]
    if {[string match "mac*" $this(platform)]} {
	$wtree configure -buttonpresscommand  \
	  [list ::Jabber::Popup browse]
    } else {
	$wtree configure -rightclickcommand  \
	  [list ::Jabber::Popup browse]
    }
    grid $wtree -row 0 -column 0 -sticky news
    grid $wysc -row 0 -column 1 -sticky ns
    grid $wxsc -row 1 -column 0 -sticky ew
    grid columnconfigure $wbox 0 -weight 1
    grid rowconfigure $wbox 0 -weight 1
        
    # All tree content is set from browse callback from the browse object.
    
    return $w
}

# Jabber::Browse::AddToTree --
#
#       Fills tree with content. Calls itself recursively.
#
# Arguments:
#       parentsJidList: 
#       jid:        the jid of the first element in xmllist.
#                   if empty then get it from the attributes instead.
#       xmllist:    xml list starting after the <iq> tag.

proc ::Jabber::Browse::AddToTree {parentsJidList jid xmllist {browsedjid 0}} {
    
    variable wtree
    variable wtreecanvas
    variable options
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::nsToText nsToText
    
    ::Jabber::Debug 2 "::Jabber::Browse::AddToTree parentsJidList='$parentsJidList', jid=$jid"

    set tag [lindex $xmllist 0]
    array set attrArr [lindex $xmllist 1]

    if {$options(-setbrowsedjid)} {}
    
    switch -exact -- $tag {
	ns {
	    
	    # outdated !!!!!!!!!
	    if {0} {
		set ns [lindex $xmllist 3]
		set txt $ns
		if {[info exists nsToText($ns)]} {
		    set txt $nsToText($ns)
		}
		
		# Namespaces indicate supported feature.
		$wtree newitem [concat $parentsJidList [lindex $xmllist 3]]  \
		  -text $txt -dir 0
	    }
	}
	default {
    
	    # If the 'jid' is empty we get it from our attributes!
	    if {[string length $jid] == 0} {
		set jid $attrArr(jid)
	    }
	    set jidList [concat $parentsJidList $jid]
	    set allChildren [wrapper::getchildren $xmllist]
	    
	    ::Jabber::Debug 3 "   jidList='$jidList'"
	    
	    if {[info exists attrArr(type)] && [string equal $attrArr(type) "remove"]} {
		
		# Remove this jid from tree widget.
		foreach v [$wtree find withtag $jid] {
		    $wtree delitem $v
		}
	    } elseif {$options(-setbrowsedjid) || !$browsedjid} {
		
		# Set this jid in tree widget.
		set txt $jid
		if {[info exists attrArr(name)]} {
		    set txt $attrArr(name)
		}
		
		# If three-tier jid, then dead-end.
		# Note: it is very unclear how to determine if dead-end without
		# an additional browse of that jid.
		# This is very ad hoc!!!
		if {[regexp {.+@[^/]+/.+} $jid match]} {
		    if {[string equal $tag "user"]} {
			$wtree newitem $jidList -dir 0  \
			  -text $txt -image $::tree::machead -tags $jid
		    } else {
			$wtree newitem $jidList -text $txt -tags $jid
		    }
		} elseif {[string equal $tag "service"]} {
		    $wtree newitem $jidList -text $txt -tags $jid -style bold
		} else {
		    
		    # This is a service, transport, room, etc.
		    set isOpen [expr [llength $allChildren] ? 1 : 0]
		    $wtree newitem $jidList -dir 1 -open $isOpen -text $txt \
		      -tags $jid
		}
		set typesubtype [$jstate(browse) gettype $jid]
		set jidtxt $jid
		if {[string length $jid] > 30} {
		    set jidtxt "[string range $jid 0 28]..."
		}
		set msg "jid: $jidtxt\ntype: $typesubtype"
		::balloonhelp::balloonforcanvas $wtreecanvas $jid $msg
	    }
	    
	    # If any child elements, call ourself recursively.
	    foreach child $allChildren {
		::Jabber::Browse::AddToTree $jidList {} $child
	    }
	}
    }
}

# Jabber::Browse::Presence --
#
#       Sets the presence of the (<user>) jid in our browse tree.
#
# Arguments:
#       jid  
#       presence    "available", "unavailable", or "unsubscribed"
#       args        list of '-key value' pairs of presence attributes.
#       
# Results:
#       browse tree icon updated.

proc ::Jabber::Browse::Presence {jid presence args} {
    
    variable wtree
    upvar ::Jabber::jstate jstate

    ::Jabber::Debug 2 "::Jabber::Browse::Presence jid=$jid, presence=$presence, args='$args'"

    array set argsArr $args
            
    if {![winfo exists $wtree]} {
	return
    }
    set jidhash ${jid}/$argsArr(-resource)
    set parentList [$jstate(browse) getparents $jidhash]
    set jidList [concat $parentList $jidhash]
    if {![$wtree isitem $jidList]} {
	return
    }
    if {$presence == "available"} {
    
	# Add first if not there?    
	set icon [eval {::Jabber::GetPresenceIcon $jidhash $presence} $args]
	$wtree itemconfigure $jidList -image $icon
    } elseif {$presence == "unavailable"} {

    }
}

# Jabber::Browse::SelectCmd --
#
#
# Arguments:
#       w           tree widget
#       v           tree item path
#       
# Results:
#       .

proc ::Jabber::Browse::SelectCmd {w v} {
    
}

# Jabber::Browse::OpenTreeCmd --
#
#       Callback when open service item in tree.
#       It browses a subelement of the server jid, typically
#       jud.jabber.org, aim.jabber.org etc.
#
# Arguments:
#       w           tree widget
#       v           tree item path (jidList: {jabber.org jud.jabber.org} etc.)
#       
# Results:
#       .

proc ::Jabber::Browse::OpenTreeCmd {w v} {
    
    variable wsearrows
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Browse::OpenTreeCmd v=$v"

    if {[llength $v]} {
	set jid [lindex $v end]
	
	# If we have not yet browsed this jid, do it now!
	if {![$jstate(browse) isbrowsed $jid]} {
	    ::Jabber::Browse::ControlArrows 1
	    
	    # Browse services available.
	    ::Jabber::Browse::Get $jid
	}
    }    
}

proc ::Jabber::Browse::Refresh {jid} {
    
    variable wtree    
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Browse::Refresh jid=$jid"
        
    # Clear internal state of the browse object for this jid.
    $jstate(browse) clear $jid
    
    # Remove all children of this jid from browse tree.
    foreach v [$wtree find withtag $jid] {
	$wtree delitem $v -childsonly 1
    }
    
    # Browse once more, let callback manage rest.
    ::Jabber::Browse::ControlArrows 1
    ::Jabber::Browse::Get $jid
}

proc ::Jabber::Browse::ControlArrows {step} {
    
    variable wsearrows
    variable arrowRefCount
    
    if {![winfo exists $wsearrows]} {
	return
    }
    if {$step == 1} {
	incr arrowRefCount
	if {$arrowRefCount == 1} {
	    $wsearrows start
	}
    } elseif {$step == -1} {
	incr arrowRefCount -1
	if {$arrowRefCount <= 0} {
	    set arrowRefCount 0
	    $wsearrows stop
	}
    } elseif {$step == 0} {
	set arrowRefCount 0
	$wsearrows stop
    }
}

# Jabber::Browse::ClearRoom --
#
#       Removes all users from room, typically on exit. Not sure of this one...

proc ::Jabber::Browse::ClearRoom {roomJid} {
    
    variable wtree    
    upvar ::Jabber::jstate jstate

    set parentList [$jstate(browse) getparents $roomJid]
    set jidList "$parentList $roomJid"
    #$wtree delitem $jidList -childsonly 1
    foreach v [$wtree find withtag $roomJid] {
	$wtree delitem $v -childsonly 1
    }
}

proc ::Jabber::Browse::Clear { } {
    
    variable wtree    
    upvar ::Jabber::jstate jstate

    ::Jabber::Debug 2 "::Jabber::Browse::Clear"
    
    # Remove the complete tree. We could relogin, and then we need a fresh start.
    $wtree delitem {}
    
    # Clears out all cached info in browse object.
    $jstate(browse) clear
}

proc ::Jabber::Browse::CloseDlg {w} {
    
    upvar ::Jabber::jstate jstate

    wm withdraw $w
    set jstate(browseVis) 0
}

proc ::Jabber::Browse::AddServer { } {
    global  this sysFont prefs
    
    variable finishedAdd -1

    set w .jaddsrv
    if {[winfo exists $w]} {
	return
    }
    set finishedAdd 0
    
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {
	wm transient $w .
    }
    wm title $w [::msgcat::mc {Add Server}]
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 12 -ipady 4
    message $w.frall.msg -width 220 -font $sysFont(s) -text \
      [::msgcat::mc jabrowseaddserver]
    entry $w.frall.ent -width 24   \
      -textvariable "[namespace current]::addserver"
    pack $w.frall.msg $w.frall.ent -side top -fill x -anchor w -padx 10  \
      -pady 4

    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btadd -text [::msgcat::mc Add] -width 8 -default active \
      -command [list [namespace current]::DoAddServer $w]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8  \
      -command [list [namespace current]::CancelAdd $w]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
        
    wm resizable $w 0 0
        
    # Grab and focus.
    set oldFocus [focus]
    focus $w.frall.ent
    catch {grab $w}
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w

    catch {grab release $w}
    focus $oldFocus
    return [expr {($finishedAdd <= 0) ? "cancel" : "add"}]
}

proc ::Jabber::Browse::DoAddServer {w} {
    variable finishedAdd

    set finishedAdd 0
    destroy $w
}

proc ::Jabber::Browse::DoAddServer {w} {
    
    variable addserver
    variable finishedAdd
    upvar ::Jabber::jprefs jprefs
    
    set finishedAdd 1
    destroy $w
    if {[llength $addserver] == 0} {
	return
    }
    
    # Verify that we doesn't have it already.
    if {[lsearch $jprefs(browseServers) $addserver] >= 0} {
	tk_messageBox -type ok -icon info  \
	  -message {We have this server already on our list}
	return
    }
    lappend jprefs(browseServers) $addserver
    
    # Browse services for this server, schedules update tree.
    ::Jabber::Browse::Get $addserver
    
}

# Jabber::Browse::SetUIWhen --
#
#       Update the browse buttons etc to reflect the current state.
#
# Arguments:
#       what        any of "connect", "disconnect"
#

proc ::Jabber::Browse::SetUIWhen {what} {
    
    variable btaddserv

    # unused!
    return
    
    switch -- $what {
	connect {
	    $btaddserv configure -state normal
	}
	disconnect {
	    $btaddserv configure -state disabled
	}
    }
}

# The ::Jabber::Conference:: namespace -----------------------------------------

# This uses the 'jabber:iq:conference' namespace and therefore requires
# that we use the 'jabber:iq:browse' for this to work.
# We only handle the enter/create dialogs here since the rest is handled
# in ::GroupChat::
# The 'jabber:iq:conference' is in a transition to be replaced by MUC.

namespace eval ::Jabber::Conference:: {

    # Keep track of me for each room.
    # locals($roomJid,own) {room@server/hash nickname}
    variable locals
}

# Jabber::Conference::BuildEnterRoom --
#
#       Initiates the process of entering a room.
#       
# Arguments:
#       w           toplevel widget
#       args    -server, -roomjid, -roomname, -autoget 0/1
#       
# Results:
#       "cancel" or "enter".
     
proc ::Jabber::Conference::BuildEnterRoom {w args} {
    global  this sysFont

    variable wtop
    variable wbox
    variable wbtenter
    variable wbtget
    variable wcomboserver
    variable wcomboroom
    variable server
    variable roomname
    variable wsearrows
    variable stattxt
    variable finishedEnter -1
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Conference::BuildEnterRoom"
    if {[winfo exists $w]} {
	return
    }
    array set argsArr $args
    set server ""
    set roomname ""
    
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {
	wm transient $w .
    }
    wm title $w [::msgcat::mc {Enter Room}]
    set wtop $w
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 12 -ipady 4
    message $w.frall.msg -width 260 -font $sysFont(s)  \
    	-text [::msgcat::mc jamessconfmsg]
    pack $w.frall.msg -side top -fill x -anchor w -padx 2 -pady 4
    set frtop $w.frall.top
    pack [frame $frtop] -side top -fill x
    label $frtop.lserv -text "[::msgcat::mc {Conference server}]:" \
      -font $sysFont(sb) 
    
    set confServers [$jstate(browse) getconferenceservers]
    
    ::Jabber::Debug 2 "BuildEnterRoom: confServers='$confServers'"

    set wcomboserver $frtop.eserv
    ::combobox::combobox $wcomboserver -width 20 -font $sysFont(s)  \
      -textvariable [namespace current]::server  \
      -command [namespace current]::ConfigRoomList -editable 0
    eval {$frtop.eserv list insert end} $confServers
    label $frtop.lroom -text "[::msgcat::mc {Room name}]:" -font $sysFont(sb)
    
    # Find the default conferencing server.
    if {[info exists argsArr(-server)]} {
	set server $argsArr(-server)
    } elseif {[llength $confServers]} {
	set server [lindex $confServers 0]
    }
    set roomList {}
    if {[string length $server] > 0} {
	set allRooms [$jstate(browse) getchilds $server]
	
	::Jabber::Debug 2 "BuildEnterRoom: allRooms='$allRooms'"
	
	foreach roomJid $allRooms {
	    regexp {([^@]+)@.+} $roomJid match room
	    lappend roomList $room
	}
    }
    set wcomboroom $frtop.eroom
    ::combobox::combobox $wcomboroom -width 20 -font $sysFont(s)   \
      -textvariable "[namespace current]::roomname" -editable 0
    eval {$frtop.eroom list insert end} $roomList
    if {[info exists argsArr(-roomjid)]} {
	regexp {^([^@]+)@([^/]+)} $argsArr(-roomjid) match roomname server	
	$wcomboserver configure -state disabled
	$wcomboroom configure -state disabled
    }
    if {[info exists argsArr(-server)]} {
	set server $argsArr(-server)
	$wcomboserver configure -state disabled
    }
    if {[info exists argsArr(-roomname)]} {
	set roomname $argsArr(-roomname)
	$wcomboroom configure -state disabled
    }

    grid $frtop.lserv -column 0 -row 0 -sticky e
    grid $frtop.eserv -column 1 -row 0 -sticky w
    grid $frtop.lroom -column 0 -row 1 -sticky e
    grid $frtop.eroom -column 1 -row 1 -sticky w

    # This part must be built dynamically from the 'get' xml data.
    # May be different for each conference server.
    set wfr $w.frall.frlab
    set wcont [LabeledFrame2 $wfr [::msgcat::mc Specifications]]
    pack $wfr -side top -fill both -padx 2 -pady 2

    set wbox $wcont.box
    frame $wbox
    pack $wbox -side top -fill x -padx 4 -pady 10
    pack [label $wbox.la -textvariable [namespace current]::stattxt]  \
      -padx 0 -pady 10
    set stattxt "-- [::msgcat::mc jasearchwait] --"
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    set wsearrows $frbot.arr
    set wbtenter $frbot.btenter
    set wbtget $frbot.btget
    pack [button $wbtget -text [::msgcat::mc Get] -width 8 -default active \
      -command [namespace current]::EnterGet]  \
      -side right -padx 5 -pady 5
    pack [button $wbtenter -text [::msgcat::mc Enter] -width 8 -state disabled \
      -command [list [namespace current]::DoEnter $w]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8  \
      -command [list [namespace current]::CancelEnter $w]]  \
      -side right -padx 5 -pady 5
    pack [::chasearrows::chasearrows $wsearrows -background gray87 -size 16] \
      -side left -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
        
    wm resizable $w 0 0
        
    # Grab and focus.
    set oldFocus [focus]
    catch {grab $w}
    
    if {[info exists argsArr(-autoget)] && $argsArr(-autoget)} {
	::Jabber::Conference::EnterGet
    }
    bind $w <Return> "$wbtget invoke"
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w

    catch {grab release $w}
    focus $oldFocus
    return [expr {($finishedEnter <= 0) ? "cancel" : "enter"}]
}

proc ::Jabber::Conference::CancelEnter {w} {
    variable finishedEnter

    set finishedEnter 0
    destroy $w
}

proc ::Jabber::Conference::ConfigRoomList {wcombo pickedServ} {
    
    variable wcomboroom
    upvar ::Jabber::jstate jstate

    set allRooms [$jstate(browse) getchilds $pickedServ]
    foreach roomJid $allRooms {
	regexp {([^@]+)@.+} $roomJid match room
	lappend roomList $room
    }
    $wcomboroom list delete 0 end
    eval {$wcomboroom list insert end} $roomList
}

proc ::Jabber::Conference::EnterGet { } {
    
    variable server
    variable roomname
    variable wsearrows
    variable wcomboserver
    variable wcomboroom
    variable wbtget
    variable stattxt
    upvar ::Jabber::jstate jstate
    
    # Verify.
    if {($server == "") || ($roomname == "")} {
	tk_messageBox -type ok -icon error  \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamessenterroomempty]]
	return
    }	
    $wcomboserver configure -state disabled
    $wcomboroom configure -state disabled
    $wbtget configure -state disabled
    set stattxt "-- [::msgcat::mc jawaitserver] --"
    
    # Send get enter room.
    set theRoomJid ${roomname}@${server}
    $jstate(jlib) conference get_enter $theRoomJid [namespace current]::EnterGetCB
    
    $wsearrows start
}

proc ::Jabber::Conference::EnterGetCB {jlibName type subiq} {
    
    variable wtop
    variable wbox
    variable wsearrows
    variable wbtenter
    variable wbtget
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Conference::EnterGetCB type=$type, subiq='$subiq'"
    
    if {![winfo exists $wtop]} {
	return
    }
    $wsearrows stop
    
    if {$type == "error"} {
	tk_messageBox -type ok -icon error  \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamesserrconfget [lindex $subiq 0] [lindex $subiq 1]]]
	return
    }
    catch {destroy $wbox}
    
    set subiqChildList [wrapper::getchildren $subiq]
    ::Jabber::Forms::Build $wbox $subiqChildList -template "room"    
    pack $wbox -side top -fill x -padx 2 -pady 10
    $wbtenter configure -state normal -default active
    $wbtget configure -state normal -default disabled
    bind $wtop <Return> [list $wbtenter invoke]
}

proc ::Jabber::Conference::DoEnter {w} {
    
    variable server
    variable roomname
    variable wsearrows
    variable wbox
    variable finishedEnter
    upvar ::Jabber::jstate jstate
    
    $wsearrows start
    
    set theRoomJid ${roomname}@${server}
    set subelements [::Jabber::Forms::GetXML $wbox]
    $jstate(jlib) conference set_enter $theRoomJid $subelements  \
      [list [namespace current]::ResultCallback $theRoomJid]
    
    # This triggers the tkwait, and destroys the enter dialog.
    set finishedEnter 1
    destroy $w
}

# Jabber::Conference::ResultCallback --
#
#       This is our callback procedure from 'jabber:iq:conference' stuffs.

proc ::Jabber::Conference::ResultCallback {roomJid jlibName type subiq} {

    variable locals
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Conference::ResultCallback roomJid=$roomJid, type=$type, subiq='$subiq'"
    
    if {$type == "error"} {
	tk_messageBox -type ok -icon error  \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamessconffailed $roomJid [lindex $subiq 0] [lindex $subiq 1]]]
    } else {
	
	# Handle the wb UI. Could be the room's name.
	#set jstate(.,tojid) $roomJid
    
	# This should be something like:
	# <query><id>myroom@server/7y3jy7f03</id><nick/>snuffie<nick><query/>
	# Use it to cache own room jid.
	
	#  OUTDATED!!!!!!!!!!!!!
	
	foreach child [wrapper::getchildren $subiq] {
	    set tagName [lindex $child 0]
	    set value [lindex $child 3]
	    set $tagName $value
	}
	if {[info exists id] && [info exists nick]} {
	    set locals($roomJid,own) [list $id $nick]
	}
	if {[info exists name]} {
	    set locals($roomJid,roomname) $name
	}
    }
}

#... Create Room ...............................................................

# Jabber::Conference::BuildCreateRoom --
#
#       Initiates the process of creating a room.
#       
# Arguments:
#       w           toplevel widget
#       args    -server, -roomname
#       
# Results:
#       "cancel" or "create".
     
proc ::Jabber::Conference::BuildCreateRoom {w args} {
    global  this sysFont

    variable wtop
    variable wbox
    variable wbtenter
    variable wbtget
    variable wcomboserver
    variable server
    variable roomname
    variable stattxt
    variable wsearrows
    variable finishedCreate -1
    upvar ::Jabber::jstate jstate
    
    if {[winfo exists $w]} {
	return
    }
    array set argsArr $args
    
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {
	wm transient $w .
    }
    wm title $w [::msgcat::mc {Create Room}]
    set wtop $w
    set roomname {}
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 12 -ipady 4
    message $w.frall.msg -width 220 -font $sysFont(s) -text  \
      [::msgcat::mc jacreateroom]
    pack $w.frall.msg -side top -fill x -anchor w -padx 10 -pady 4
    set frtop $w.frall.top
    pack [frame $frtop] -side top -fill x
    label $frtop.lserv -text "[::msgcat::mc {Conference server}]:"  \
      -font $sysFont(sb)
    
    set confServers [$jstate(browse) getconferenceservers]
    set wcomboserver $frtop.eserv
    ::combobox::combobox $wcomboserver -width 20 -font $sysFont(s)   \
      -textvariable "[namespace current]::server" -editable 0
    eval {$frtop.eserv list insert end} $confServers
    
    # Find the default conferencing server.
    if {[llength $confServers]} {
	set server [lindex $confServers 0]
    }
    if {[info exists argsArr(-server)]} {
	set server $argsArr(-server)
	$frtop.eserv configure -state disabled
    }
    
    label $frtop.lroom -text "[::msgcat::mc {Room name (optional)}]:" \
      -font $sysFont(sb)    
    entry $frtop.eroom -width 24   \
      -textvariable "[namespace current]::roomname"  \
      -validate key -validatecommand {::Jabber::ValidateJIDChars %S}
    
    grid $frtop.lserv -column 0 -row 0 -sticky e
    grid $frtop.eserv -column 1 -row 0 -sticky w
    grid $frtop.lroom -column 0 -row 1 -sticky e
    grid $frtop.eroom -column 1 -row 1 -sticky w

    # This part must be built dynamically from the 'get' xml data.
    # May be different for each conference server.
    set wfr $w.frall.frlab
    set wcont [LabeledFrame2 $wfr [::msgcat::mc Specifications]]
    pack $wfr -side top -fill both -padx 2 -pady 2

    set wbox $wcont.box
    frame $wbox
    pack $wbox -side top -fill x -padx 4 -pady 10
    pack [label $wbox.la -textvariable "[namespace current]::stattxt"]  \
      -padx 0 -pady 10
    set stattxt "-- [::msgcat::mc jasearchwait] --"
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    set wsearrows $frbot.arr
    set wbtenter $frbot.btenter
    set wbtget $frbot.btget
    pack [button $wbtget -text [::msgcat::mc Get] -width 8 -default active \
      -command [namespace current]::CreateGet]  \
      -side right -padx 5 -pady 5
    pack [button $wbtenter -text [::msgcat::mc Enter] -width 8 -state disabled \
      -command [list [namespace current]::DoCreate $w]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8  \
      -command [list [namespace current]::CancelCreate $w]]  \
      -side right -padx 5 -pady 5
    pack [::chasearrows::chasearrows $wsearrows -background gray87 -size 16] \
      -side left -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
        
    wm resizable $w 0 0
    bind $w <Return> [list $wbtget invoke]
        
    # Grab and focus.
    set oldFocus [focus]
    catch {grab $w}
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w

    catch {grab release $w}
    focus $oldFocus
    return [expr {($finished <= 0) ? "cancel" : "create"}]
}

proc ::Jabber::Conference::CancelCreate {w} {
    variable finishedCreate

    set finishedCreate 0
    destroy $w
}

proc ::Jabber::Conference::CreateGet { } {
    
    variable wbtget
    variable wcomboserver
    variable server
    variable roomname
    variable wsearrows
    variable stattxt
    upvar ::Jabber::jstate jstate
    
    # Verify.
    if {$server == ""} {
	tk_messageBox -type ok -icon error  \
	  -message [::msgcat::mc jamessconfservempty]
	return
    }	
    $wcomboserver configure -state disabled
    $wbtget configure -state disabled
    set stattxt "-- [::msgcat::mc jawaitserver] --"
    
    # Send get create room. NOT the server!
    set theRoomJid ${roomname}@${server}
    $jstate(jlib) conference get_create $theRoomJid  \
      [namespace current]::CreateGetGetCB
    
    $wsearrows start
}

proc ::Jabber::Conference::CreateGetGetCB {jlibName type subiq} {
    
    variable wtop
    variable wbox
    variable wsearrows
    variable wbtenter
    variable wbtget
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Conference::CreateGetGetCB type=$type, subiq='$subiq'"
    
    if {![winfo exists $wtop]} {
	return
    }
    $wsearrows stop
    
    if {$type == "error"} {
	tk_messageBox -type ok -icon error  \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamesserrconfgetcre [lindex $subiq 0] [lindex $subiq 1]]]
	return
    }
    catch {destroy $wbox}
    set childList [wrapper::getchildren $subiq]
    ::Jabber::Forms::Build $wbox $childList -template "room"
    pack $wbox -side top -fill x -padx 2 -pady 10
    $wbtenter configure -state normal -default active
    $wbtget configure -state normal -default disabled
    bind $wtop <Return> [list $wbtenter invoke]    
}

proc ::Jabber::Conference::DoCreate {w} {
    
    variable server
    variable roomname
    variable wsearrows
    variable wtop
    variable wbox
    variable locals
    variable finishedCreate
    upvar ::Jabber::jstate jstate
    
    $wsearrows start
    
    set theRoomJid ${roomname}@${server}
    set subelements [::Jabber::Forms::GetXML $wbox]
    
    # Ask jabberlib to create the room for us.
    $jstate(jlib) conference set_create $theRoomJid $subelements  \
      [list [namespace current]::ResultCallback $theRoomJid]
    
    # This triggers the tkwait, and destroys the create dialog.
    set finishedCreate 1
    destroy $w
}

# The ::Jabber::Agents:: namespace ----------------------------------------------

namespace eval ::Jabber::Agents:: {

    # We keep an reference count that gets increased by one for each request
    # sent, and decremented by one for each response.
    variable arrowRefCount 0
    variable arrMsg ""
}

# Jabber::Agents::GetAll --
#
#       Queries the services available for all the servers
#       that are in 'jprefs(agentsServers)' plus the login server.
#
# Arguments:
#       
# Results:
#       none.

proc ::Jabber::Agents::GetAll { } {

    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jserver jserver
    
    set allServers [lsort -unique [concat $jserver(this) $jprefs(agentsServers)]]
    foreach server $allServers {
	::Jabber::Agents::Get $server
	::Jabber::Agents::GetAgent {} $server -silent 1
    }
}

# Jabber::Agents::Get --
#
#       Calls get jabber:iq:agents to investigate the services of server jid.
#
# Arguments:
#       jid         The jid server to investigate.
#       
# Results:
#       callback scheduled.

proc ::Jabber::Agents::Get {jid} {
    
    upvar ::Jabber::jstate jstate
    
    $jstate(jlib) agents_get $jid [list ::Jabber::Agents::AgentsCallback $jid]
}

# Jabber::Agents::GetAgent --
#
#       args    ?-silent 0/1? (D=0)
#       
# Results:
#       callback scheduled.

proc ::Jabber::Agents::GetAgent {parentJid jid args} {
    
    upvar ::Jabber::jstate jstate
    
    array set opts {
	-silent 0
    }
    array set opts $args        
    $jstate(jlib) agent_get $jid  \
      [list ::Jabber::Agents::GetAgentCallback $parentJid $jid $opts(-silent)]
}

# Jabber::Agents::AgentsCallback --
#
#       Fills in agent tree with the info from this response via calls
#       to 'AddAgentToTree'.
#       Makes a get jabber:iq:agent to all <agent> elements from agents get.
#       
# Arguments:
#       jid         The jid we query, the parent of all <agent> elements
#       what        "ok" or "error"
#       
# Results:
#       none.

proc ::Jabber::Agents::AgentsCallback {jid jlibName what subiq} {

    variable wagents
    variable wtree
    variable wtreecanvas
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    
    ::Jabber::Debug 2 "::Jabber::Agents::AgentsCallback jid=$jid, \
      what=$what\n\tsubiq=$subiq"
    
    if {[string equal $what "error"]} {
	    
	# Shall we be silent? 
	if {[winfo exists $wagents]} {
	    tk_messageBox -type ok -icon error \
	      -message [FormatTextForMessageBox  \
	      [::msgcat::mc jamesserragentget [lindex $subiq 1]]]
	}
    } elseif {[string equal $what "ok"]} {
    
	# It is at this stage we are confident that an Agents page is needed.
	::Jabber::RostServ::NewPage "Agents"

	$wtree newitem $jid -dir 1 -open 1 -tags $jid
	set bmsg "jid: $jid"
	::balloonhelp::balloonforcanvas $wtreecanvas $jid $bmsg	    

	# Loop through all <agent> elements and:
	# 1) fill in what we've got so far.
	# 2) send get jabber:iq:agent.
	foreach agent [wrapper::getchildren $subiq] {
	    if {![string equal [lindex $agent 0] "agent"]} {
		continue
	    }
	    set subAgent [wrapper::getchildren $agent]
	    set jidAgent [wrapper::getattr [lindex $agent 1] jid]
	    
	    # If any groupchat/conference service we need to query its
	    # version number to know which protocol to use.
	    foreach elem $subAgent {
		if {[string equal [lindex $elem 0] "groupchat"]} {
		    $jstate(jlib) get_version $jidAgent   \
		      [list ::Jabber::CacheGroupchatType $jidAgent]
		    
		    # The old groupchat protocol is used as a fallback.
		    set jstate(conference,$jidAgent) 0
		    break
		}
	    }
		
	    # Fill in tree items.
	    ::Jabber::Agents::AddAgentToTree $jid $jidAgent $subAgent
	    ::Jabber::Agents::GetAgent $jid $jidAgent -silent 1
	}
    }
}
    
# Jabber::Agents::GetAgentCallback --
#
#       It receives reports from iq result elements with the
#       jabber:iq:agent namespace.
#
# Arguments:
#       jid:        the jid that we sent get jabber:iq:agent to (from attribute).
#       what:       can be 'ok', or 'error'.
#       
# Results:
#       none. UI maybe updated

proc ::Jabber::Agents::GetAgentCallback {parentJid jid silent jlibName what subiq} {
    
    variable wagents
    variable warrows
    variable wtree
    variable wtreecanvas
    variable arrMsg
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jerror jerror
    
    ::Jabber::Debug 2 "::Jabber::Agents::GetAgentCallback parentJid=$parentJid,\
      jid=$jid, what=$what"
    
    if {[winfo exists $wagents]} {
	::Jabber::Agents::ControlArrows -1
    }
    if {[string equal $what "error"]} {
	if {$silent} {
	    lappend jerror [list [clock format [clock seconds] -format "%H:%M:%S"]  \
	      $jid "Failed getting agent info. The error was: [lindex $subiq 1]"]	    
	} else {
	}
    } elseif {[string equal $what "ok"]} {
	
	# Fill in tree.
	::Jabber::Agents::AddAgentToTree $parentJid $jid  \
	  [wrapper::getchildren $subiq]
    }
}

# Jabber::Agents::AddAgentToTree --
#
#

proc ::Jabber::Agents::AddAgentToTree {parentJid jid subAgent} {
    
    variable wtree
    variable wtreecanvas
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 4 "::Jabber::Agents::AddAgentToTree parentJid=$parentJid,\
      jid=$jid, subAgent='$subAgent'"
    	
    # Loop through the subelement to see what we've got.
    foreach elem $subAgent {
	set tag [lindex $elem 0]
	set agentSubArr($tag) [lindex $elem 3]
    }
    if {[lsearch [concat $jserver(this) $jprefs(agentsServers)] $jid] < 0} {
	set isServer 0
    } else {
	set isServer 1
    }
    if {$isServer} {	
	if {[info exists agentSubArr(name)]} {
	    $wtree itemconfigure $jid -text $agentSubArr(name)
	}
    } else {
	if {[string length $parentJid] > 0} {
	    set v [list $parentJid $jid]
	} else {
	    set v $jid
	}
	set txt $jid
	if {[info exists agentSubArr(name)]} {
	    set txt $agentSubArr(name)
	}
	$wtree newitem $v -dir 1 -open 1 -text $txt -tags $jid
	set bmsg "jid: $jid"
	
	foreach tag [array names agentSubArr] {
	    switch -- $tag {
		register - search - groupchat {
		    $wtree newitem [concat $v $tag]
		}
		service {
		    $wtree newitem [concat $v $tag]  \
		      -text "service: $agentSubArr($tag)"
		}
		transport {
		    $wtree newitem [concat $v $tag]  \
		      -text $agentSubArr($tag)
		} 
		description {
		    append bmsg "\n$agentSubArr(description)"
		} 
		name {
		    # nothing
		} 
		default {
		    $wtree newitem [concat $v $tag]
		}
	    }
	}
	::balloonhelp::balloonforcanvas $wtreecanvas $jid $bmsg	    
    }
}

# Jabber::Agents::Build --
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

proc ::Jabber::Agents::Build {w args} {
    global  sysFont prefs this

    variable wagents
    variable warrows
    variable wtree
    variable wtreecanvas
    variable arrMsg
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jprefs jprefs
    
    ::Jabber::Debug 2 "::Jabber::Agents::Build w=$w"
        
    # The frame.
    frame $w -borderwidth 0 -relief flat
    set wagents $w

    # Start with running arrows and message.
    pack [frame $w.bot] -side bottom -fill x -anchor w -padx 8 -pady 6
    set warrows $w.bot.arr
    pack [::chasearrows::chasearrows $warrows -background gray87 -size 16] \
      -side left -padx 5 -pady 5
    pack [label $w.bot.la   \
      -textvariable [namespace current]::arrMsg] -side left -padx 8 -pady 6
    
    # Tree part
    set wbox $w.box
    pack [frame $wbox -border 1 -relief sunken]   \
      -side top -fill both -expand 1 -padx 6 -pady 6
    set wtree $wbox.tree
    set wxsc $wbox.xsc
    set wysc $wbox.ysc
    scrollbar $wxsc -orient horizontal -command [list $wtree xview]
    scrollbar $wysc -orient vertical -command [list $wtree yview]
    ::tree::tree $wtree -width 180 -height 200 -silent 1  \
      -openicons triangle -treecolor {} -scrollwidth 400 \
      -xscrollcommand [list $wxsc set]       \
      -yscrollcommand [list $wysc set]       \
      -selectcommand ::Jabber::Agents::SelectCmd   \
      -opencommand ::Jabber::Agents::OpenTreeCmd   \
      -highlightcolor #6363CE -highlightbackground $prefs(bgColGeneral)
    set wtreecanvas [$wtree getcanvas]
    if {[string match "mac*" $this(platform)]} {
	$wtree configure -buttonpresscommand  \
	  [list ::Jabber::Popup agents]
    } else {
	$wtree configure -rightclickcommand  \
	  [list ::Jabber::Popup agents]
    }
    grid $wtree -row 0 -column 0 -sticky news
    grid $wysc -row 0 -column 1 -sticky ns
    grid $wxsc -row 1 -column 0 -sticky ew
    grid columnconfigure $wbox 0 -weight 1
    grid rowconfigure $wbox 0 -weight 1
    
    return $w
}

# Jabber::Agents::SelectCmd --
#
#
# Arguments:
#       w           tree widget
#       v           tree item path
#       
# Results:
#       .

proc ::Jabber::Agents::SelectCmd {w v} {
    
    
}

# Jabber::Agents::OpenTreeCmd --
#
#       Callback when open service item in tree.
#       It calls jabber:iq:agent of the server jid, typically
#       jud.jabber.org, aim.jabber.org etc.
#
# Arguments:
#       w           tree widget
#       v           tree item path (jidList: {jabber.org jud.jabber.org} etc.)
#       
# Results:
#       .

proc ::Jabber::Agents::OpenTreeCmd {w v} {
    
    
    
}

proc ::Jabber::Agents::ControlArrows {step} {
    
    variable warrows
    variable arrowRefCount
    
    if {$step == 1} {
	incr arrowRefCount
	if {$arrowRefCount == 1} {
	    $warrows start
	}
    } elseif {$step == -1} {
	incr arrowRefCount -1
	if {$arrowRefCount <= 0} {
	    set arrowRefCount 0
	    $warrows stop
	}
    } elseif {$step == 0} {
	set arrowRefCount 0
	$warrows stop
    }
}

# The ::Jabber::Search:: namespace ---------------------------------------------

namespace eval ::Jabber::Search:: {

    # Wait for this variable to be set.
    variable finished  
}

# Jabber::Search::Build --
#
#       Initiates the process of searching a service.
#       
# Arguments:
#       w           toplevel widget
#       args   -server, -autoget 0/1
#       
# Results:
#       .
     
proc ::Jabber::Search::Build {w args} {
    global  this sysFont prefs

    variable wtop
    variable wbox
    variable wbtsearch
    variable wbtget
    variable wcomboserver
    variable wtb
    variable wxsc
    variable wysc
    variable woob
    variable server
    variable wsearrows
    variable stattxt
    upvar ::Jabber::jstate jstate
    
    if {[winfo exists $w]} {
	return
    }
    array set argsArr $args
    set finished -1
    
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {
	wm transient $w .
    }
    wm title $w [::msgcat::mc {Search Service}]
    set wtop $w
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 6 -ipady 4
    
    # Left half.
    set wleft $w.frall.fl
    pack [frame $wleft] -side left -fill y
    
    # Right half.
    set wright $w.frall.fr
    pack [frame $wright] -side right -expand 1 -fill both
    
    message $wleft.msg -width 200 -font $sysFont(s)  \
      -text [::msgcat::mc jasearch] -anchor w
    pack $wleft.msg -side top -fill x -anchor w -padx 4 -pady 2
    set frtop $wleft.top
    pack [frame $frtop] -side top -fill x -anchor w -padx 4 -pady 2
    label $frtop.lserv -text "[::msgcat::mc {Search Service}]:" -font $sysFont(sb)
    
    # Button part.
    set frbot [frame $wleft.frbot -borderwidth 0]
    set wsearrows $frbot.arr
    set wbtsearch $frbot.btenter
    pack [button $wbtsearch -text [::msgcat::mc Search] -width 8 -state disabled \
      -command [namespace current]::DoSearch]  \
      -side right -padx 5 -pady 2
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8  \
      -command "destroy $w"]  \
      -side right -padx 5 -pady 2
    pack [::chasearrows::chasearrows $wsearrows -background gray87 -size 16] \
      -side left -padx 5 -pady 2
    pack $frbot -side bottom -fill x -padx 8 -pady 6
    
    # OOB alternative.
    set woob [frame $wleft.foob]
    pack $woob -side bottom -fill x -padx 8 -pady 0
    
    # Get all (browsed) services that support search.
    set searchServ [$jstate(jlib) service getjidsfor "search"]
    set wcomboserver $frtop.eserv
    ::combobox::combobox $wcomboserver -width 20 -font $sysFont(s)   \
      -textvariable [namespace current]::server -editable 0
    eval {$frtop.eserv list insert end} $searchServ
    
    # Find the default search server.
    if {[llength $searchServ]} {
	set server [lindex $searchServ 0]
    }
    if {[info exists argsArr(-server)]} {
	set server $argsArr(-server)
	$wcomboserver configure -state disabled
    }
    
    # Get button.
    set wbtget $frtop.btget
    button $wbtget -text [::msgcat::mc Get] -width 6 -default active \
      -command [list ::Jabber::Search::Get]

    grid $frtop.lserv -sticky w
    grid $wcomboserver -row 1 -column 0 -sticky ew
    grid $wbtget -row 1 -column 1 -sticky e -padx 2

    # This part must be built dynamically from the 'get' xml data.
    # May be different for each conference server.
    set wfr $wleft.frlab
    set wcont [LabeledFrame2 $wfr [::msgcat::mc {Search Specifications}]]
    pack $wfr -side top -fill both -padx 2 -pady 2

    set wbox [frame $wcont.box]
    pack $wbox -side left -fill both -padx 4 -pady 4 -expand 1
    pack [label $wbox.la -textvariable "[namespace current]::stattxt"]  \
      -padx 0 -pady 10 -side left
    set stattxt "-- [::msgcat::mc jasearchwait] --"
    
    # The Search result tablelist widget.
    set frsearch $wright.se
    pack [frame $frsearch -borderwidth 1 -relief sunken] -side top -fill both \
      -expand 1 -padx 4 -pady 4
    set wtb $frsearch.tb
    set wxsc $frsearch.xsc
    set wysc $frsearch.ysc
    tablelist::tablelist $wtb \
      -columns [list 60 [::msgcat::mc {Search results}]]  \
      -font $sysFont(s) -labelfont $sysFont(s) -background white  \
      -xscrollcommand [list $wxsc set] -yscrollcommand [list $wysc set]  \
      -labelbackground #cecece -stripebackground #dedeff -width 60 -height 20
    #-labelcommand "[namespace current]::LabelCommand"  \
    
    scrollbar $wysc -orient vertical -command [list $wtb yview]
    scrollbar $wxsc -orient horizontal -command [list $wtb xview]
    grid $wtb $wysc -sticky news
    grid $wxsc -sticky ew -column 0 -row 1
    grid rowconfigure $frsearch 0 -weight 1
    grid columnconfigure $frsearch 0 -weight 1
    
    wm minsize $w 400 320
            
    # If only a single search service, or if specified as argument.
    if {([llength $searchServ] == 1) ||  \
      [info exists argsArr(-autoget)] && $argsArr(-autoget)} {
	::Jabber::Search::Get
    }
}

proc ::Jabber::Search::Get { } {
    
    variable server
    variable wsearrows
    variable wcomboserver
    variable wbtget
    variable wtb
    variable stattxt
    upvar ::Jabber::jstate jstate
    
    # Verify.
    if {[string length $server] == 0} {
	tk_messageBox -type ok -icon error  \
	  -message [::msgcat::mc jamessregnoserver]
	return
    }	
    $wcomboserver configure -state disabled
    $wbtget configure -state disabled
    set stattxt "-- [::msgcat::mc jawaitserver] --"
    
    # Send get register.
    $jstate(jlib) search_get $server ::Jabber::Search::GetCB    
    $wsearrows start
    
    $wtb configure -columns [list 60 [::msgcat::mc {Search results}]]
    $wtb delete 0 end
}

# Jabber::Search::GetCB --
#
#       This is the 'get' iq callback.
#       It should be possible to receive multiple callbacks for a single
#       search, but this is untested.

proc ::Jabber::Search::GetCB {jlibName type subiq} {
    global  sysFont
    
    variable wtop
    variable wbox
    variable wtb
    variable wxsc
    variable wysc
    variable woob
    variable wsearrows
    variable wbtsearch
    variable wbtget
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Jabber::Debug 2 "::Jabber::Search::GetCB type=$type, subiq='$subiq'"
    
    if {![winfo exists $wtop]} {
	return
    }
    $wsearrows stop
    
    if {$type == "error"} {
	tk_messageBox -type ok -icon error  \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamesserrsearch [lindex $subiq 0] [lindex $subiq 1]]]
	return
    }
    catch {destroy $wbox}
    catch {destroy $woob.oob}
    set subiqChildList [wrapper::getchildren $subiq]
    
    # We must figure out if we have an oob thing.
    set hasOOBForm 0
    foreach c $subiqChildList {
	if {[string equal [lindex $c 0] "x"]} {
	    array set cattrArr [lindex $c 1]
	    if {[info exists cattrArr(xmlns)] &&  \
	      [string equal $cattrArr(xmlns) "jabber:x:oob"]} {
		set hasOOBForm 1
		set xmlOOBElem $c
	    }
	}
    }
	
    # Build form dynamically from XML.
    ::Jabber::Forms::Build $wbox $subiqChildList -template "search" -width 160
    pack $wbox -side left -padx 2 -pady 10
    if {$hasOOBForm} {
	set woobtxt [::Jabber::OOB::BuildText ${woob}.oob $xmlOOBElem]
	pack $woobtxt -side top -fill x
    }
    $wbtsearch configure -state normal -default active
    $wbtget configure -state normal -default disabled   
}

proc ::Jabber::Search::DoSearch { } {
    
    variable server
    variable wsearrows
    variable wbox
    variable wtb
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    $wsearrows start
    $wtb delete 0 end

    # Returns the hierarchical xml list starting with the <x> element.
    set subelements [::Jabber::Forms::GetXML $wbox]    
    $jstate(jlib) search_set $server  \
      [list [namespace current]::ResultCallback $server] -subtags $subelements
}

# Jabber::Search::ResultCallback --
#
#       This is the 'result' and 'set' iq callback We may get a number of server
#       pushing 'set' elements, finilized by the 'result' element.
#       
#       Update: the situation with jabber:x:data seems unclear here.
#       
# Arguments:
#       server:
#       type:       "ok", "error", or "set"
#       subiq:

proc ::Jabber::Search::ResultCallback {server type subiq} {
    
    variable wtop
    variable wtb
    variable wbox
    variable wsearrows
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Jabber::Debug 2 "::Jabber::Search::ResultCallback server=$server, type=$type, \
      subiq='$subiq'"
    
    if {![winfo exists $wtop]} {
	return
    }
    $wsearrows stop
    if {[string equal $type "error"]} {
	foreach {ecode emsg} [lrange $subiq 0 1] { break }
	if {$ecode == "406"} {
	    set msg "There was an invalid field. Please correct it: $emsg"
	} else {
	    set msg "Failed searching service. Error code $ecode with message: $emsg"
	}
	tk_messageBox -type ok -icon error -message [FormatTextForMessageBox $msg]
	return
    } elseif {[string equal $type "ok"]} {
	
	# This returns the search result and sets the reported stuff.
	set columnSpec {}
	set resultList [::Jabber::Forms::ResultList $wbox $subiq]
	foreach {var label} [::Jabber::Forms::GetReported $wbox] {
	    lappend columnSpec 0 $label	    
	}
	$wtb configure -columns $columnSpec
	if {[llength $resultList] == 0} {
	    $wtb insert end {{No matches found}}
	} else {
	    foreach row $resultList {
		$wtb insert end $row
	    }
	}
    }
}

#-------------------------------------------------------------------------------
