#  TheServer.tcl ---
#  
#       This file is part of the whiteboard application. It implements the
#       server part and contains procedures for creating new server side sockets,
#       handling canvas operations and file transfer.
#      
#  Copyright (c) 1999-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: TheServer.tcl,v 1.5 2003-04-28 13:32:34 matben Exp $
    
# DoStartServer ---
#
#       This belongs to the server part, but is necessary for autoStartServer.
#       Some operations can be critical since the app is not yet completely 
#       launched.
#       Therefore 'after idle'.(?)

proc DoStartServer {thisServPort} {
    global  prefs state listenServSocket this thisIPnum
    
    set res "ok"
    
    # If it's a centralized net config, ask first.
    if {[string equal $prefs(protocol) "central"]} {
	after 1000 {set res [tk_messageBox -message [FormatTextForMessageBox \
	  {Are you sure that this is the central server?}] \
	  -icon warning -type okcancel -default ok]}
    }
    if {[string equal $res "ok"]} {
	if {[catch {socket -server SetupChannel $thisServPort} sock]} {
	    after 500 {tk_messageBox -message [FormatTextForMessageBox \
	      [::msgcat::mc messfailserver]]  \
	      -icon error -type ok}
	} else {
	    set listenServSocket $sock
	    set state(isServerUp) 1
	    
	    # Sometimes this gives 0.0.0.0, why I don't know.
	    set sockname [fconfigure $sock -sockname]
	    if {[lindex $sockname 0] != "0.0.0.0"} {
		set thisIPnum [lindex $sockname 0]
		set this(ipnum) [lindex $sockname 0]
	    }
	}
    }
}

# DoStopServer --
#   
#       Closes the server socket, prevents new connections, but existing ones
#       are kept alive.
#       
# Arguments:
#       
# Results:
#       none

proc DoStopServer { } {
    global  listenServSocket state
    
    catch {close $listenServSocket}
    set state(isServerUp) 0
}

# SetupChannel --
#   
#       Handles remote connections to the server port. 
#       Sets up the callback routine.
#       
# Arguments:
#       channel     the socket
#       ip          ip number
#       port        port number
#       
# Results:
#       socket event handler set up.

proc SetupChannel {channel ip port} {
    global  ipNumTo ipName2Num this thisIPnum prefs
    
    # This is the important code that sets up the server event handler.
    fileevent $channel readable [list HandleClientRequest $channel $ip $port]

    # Everything should be done with 'fileevent'.
    fconfigure $channel -blocking 0

    # Everything is lineoriented except binary transfer operations.
    fconfigure $channel -buffering line
    
    # For nonlatin characters to work be sure to use Unicode/UTF-8.
    if {[info tclversion] >= 8.1} {
        catch {fconfigure $channel -encoding utf-8}
    }

    Debug 2 "---> Connection made to $ip:${port} on channel $channel."
    
    # Save ip nums and names etc in arrays.
    # Depending on which happens first, this info is either collected here, or via
    # '::OpenConnection::SetIpArrays' when a client socket is opened.
    # Need to be economical here since '-peername' takes 5 secs on my intranet.
    if {![info exists ipNumTo(name,$ip)]} {

	# problem on my mac since ipName is '<unknown>'
	set peername [fconfigure $channel -peername]
	set ipNum [lindex $peername 0]
	set ipName [lindex $peername 1]
	set ipNumTo(name,$ipNum) $ipName
	set ipName2Num($ipName) $ipNum
	Debug 4 "   [clock clicks -milliseconds]: peername=$peername"
    }
	
    # If we are a server in a client/server set up store socket if this is first time.
    if {($prefs(protocol) == "server") && ![info exists ipNumTo(socket,$ip)]} {
	set ipNumTo(socket,$ip) $channel
    }
    set sockname [fconfigure $channel -sockname] 

    # Sometimes the DoStartServer just gives this(ipnum)=0.0.0.0 ; fix this here.
    if {[string equal $this(ipnum) "0.0.0.0"]} {
	set thisIPnum [lindex $sockname 0]
	set this(ipnum) [lindex $sockname 0]
    }
    
    # Don't think this is correct!!!
    if {![info exists ipNumTo(servPort,$this(ipnum))]} {
	set ipNumTo(servPort,$this(ipnum)) [lindex $sockname 2]
    }
}

# HandleClientRequest --
#
#       This is the actual server that reads client requests. 
#       The most important is the CANVAS command which is a complete
#       canvas command that is prefixed only by the widget path.
#
# Arguments:
#       channel
#       ip
#       port
#       
# Results:
#       one line read from socket.

proc HandleClientRequest {channel ip port} {
    global  tempChannel prefs debugServerLevel
        
    # If client closes socket to this server.
    
    if {[eof $channel]} {
	if {$debugServerLevel >= 2} {
	    puts "HandleClientRequest:: eof channel=$channel"
	}
	fileevent $channel readable {}
	
	# Update entry only for nontemporary channels.
	if {[info exists tempChannel($channel)]} {
	    unset tempChannel($channel)
	} else {
	    if {[string equal $prefs(protocol) "jabber"]} {
		
		# Am not sure we ever end up here...
		::Jabber::DoCloseClientConnection $ip
	    } elseif {[string equal $prefs(protocol) "symmetric"]} {
	    
		# Close the 'from' part.
		::OpenConnection::DoCloseServerConnection $ip
	    } elseif {[string equal $prefs(protocol) "server"]} {
		::OpenConnection::DoCloseServerConnection $ip
	    } elseif {[string equal $prefs(protocol) "central"] ||  \
	      [string equal $prefs(protocol) "client"]} {
		
		# If connected to a reflector server that closes down,
		# close the 'to' part.
		::OpenConnection::DoCloseClientConnection $ip
	    }
	}
		
    } elseif {[gets $channel line] != -1} {

	# Read one line at the time and find out what to do from the
	# leading word.
	if {$debugServerLevel >= 2} {
	    puts "--->$ip:${port}:: $line"
	}
	
	# Check that line does not contain any embedded command.
	if {$prefs(checkSafety)} {

	    # If any "[" that is not backslashed or embraced, then skip it.
	    # Security is not treated well, must do better!!!!!!!!!!!
	    
	    set ans [IsServerCommandSafe $line]
	    if {[string equal $ans "0"]} {
		puts "Warning: the following command to the server was considered\
		  potentially harmful:\n\t$line"
		return
	    } else {
		set line $ans
	    }
	}
	
	# Interpret the command we just read. 
	# Non Jabber only supports a single whiteboard instance.
	ExecuteClientRequest . $channel $ip $port $line
    }
}

# ExecuteClientRequest --
#
#       Interpret the command we just read.
#     
# Arguments:
#       wtop        toplevel window. ("." or ".main2." with extra dot!)
#       channel
#       ip
#       port
#       line       Typically a canvas command.
#       args       a list of '-key value' pairs which is typically XML
#                  attributes of our XML message element (jabber only).
#
# Returns:
#       none.

proc ExecuteClientRequest {wtop channel ip port line args} {
    global  tempChannel ipNumTo chunkSize debugServerLevel   \
      clientRecord prefs allIPnumsTo this  \
      canvasSafeInterp
    
    upvar ::${wtop}::wapp wapp
    
    set wServCan $wapp(servCan)

    # regexp patterns. Defined globally to speedup???
    set wrd_ {[^ ]+}
    set optwrd_ {[^ ]*}
    set optlist_ {.*}
    set any_ {.+}
    set nothing_ {}
    
    # Matches list with braces.  
    # ($llist_|$wrd_)  :should match single item list or multi item list.
    set llist_ {\{[^\}]+\}}
    set pre_ {[^/ ]+}
    set portwrd_ {[0-9]+}
    set ipnum_ {[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+}
    set int_ {[0-9]+}
    set signint_ {[-0-9]+}
    set punct {[.,;?!]}
    
    # Special chars.
    set nl_ {\\n}
    set bs_ {\\}
    set lb_ {\{}
    set rb_ {\}}
    
    if {$debugServerLevel >= 2} {
	puts "ExecuteClientRequest:: wtop=$wtop, line='$line', args='$args'"
    }
    array set attrarr $args
    if {![regexp {^([A-Z]+ *[A-Z]+):} $line x prefixCmd]} {
	return
    }
    
    # Branch into the right command prefix.
    switch -exact -- $prefixCmd {
	CANVAS {
	    if {[regexp "^CANVAS: +(.*)$" $line junk instr]} {
		
		# Regular drawing commands in the canvas.
		
		# If html sizes in text items, be sure to translate them into
		# platform specific point sizes.
		
		if {$prefs(useHtmlSizes) && ([lsearch -exact $instr "-font"] >= 0)} {
		    set instr [::CanvasUtils::FontHtmlToPointSize $instr]
		}
		
		# Careful, make newline (backslash) substitutions only for the command
		# being eval'd, else the tcl interpretation may be screwed up.
		# Fix special chars such as braces since they are parsed 
		# when doing 'subst' below. Pad extra backslash for each '\{' and
		# '\}' to protect them.
		# Seems like an identity operation but is not!
		
		regsub -all "$bs_$lb_" $instr "$bs_$lb_" padinstr
		regsub -all "$bs_$rb_" $padinstr "$bs_$rb_" padinstr
		set bsinstr [subst -nocommands -novariables $padinstr]
		
		# Intercept the canvas command if delete to remove any markers
		# *before* it is deleted! See below for other commands.
		
		set cmd [lindex $instr 0]
		if {[string equal $cmd "delete"]} {
		    set utag [lindex $instr 1]
		    set id [$wServCan find withtag $utag]
		    $wServCan delete id$id
		}
		
		# Find and register the undo command (and redo), and push
		# on our undo/redo stack. Security ???
		if {$prefs(privacy) == 0} {
		    set undocmd [::CanvasUtils::GetUndoCommand $wtop $instr]
		    set redo [list ::CanvasUtils::Command $wtop $instr]
		    set undo [list ::CanvasUtils::Command $wtop $undocmd]
		    undo::add [::UI::GetUndoToken $wtop] $undo $redo
		}
		
		# The 'import' command is an exception case (for the future). 
		if {[string equal $cmd "import"]} {
		    ::ImageAndMovie::HandleImportCmd $wServCan $bsinstr
		} else {
		    		
		    # Make the actual canvas command, either straight or in the 
		    # safe interpreter.
		    if {$prefs(makeSafeServ)} {
			if {[catch {$canvasSafeInterp eval SafeCanvasDraw  \
			  $wServCan $bsinstr} idnew]} {
			    puts stderr "--->error: did not understand: $idnew"
			    return
			}
		    } else {
			if {[catch {eval $wServCan $bsinstr} idnew]} {
			    puts stderr "--->error: did not understand: $idnew"
			    return
			}
		    }
		}
		
		# Intercept the canvas command in certain cases:
		# If moving a selected item, be sure to move the markers with it.
		# The item can either be selected by remote client or here.
		
		if {[string equal $cmd "move"] ||  \
		  [string equal $cmd "coords"] || \
		  [string equal $cmd "scale"] ||  \
		  [string equal $cmd "itemconfigure"]} {
		    set utag [lindex $instr 1]
		    set id [$wServCan find withtag $utag]
		    set idsMarker [$wServCan find withtag id$id]
		    
		    # If we have selected the item in question.
		    if {[string length $idsMarker] > 0} {
			$wServCan delete id$id
			$wServCan dtag $id "selected"
			::CanvasDraw::MarkBbox $wServCan 1 $id
		    }
		} 
		
		# If text then speak up to last punct.
		
		if {$prefs(SpeechOn)} {
		    if {[string equal $cmd "create"] ||  \
		      [string equal $cmd "insert"]} {
			if {[string equal $cmd "create"]} {
			    set utag $idnew
			} else {
			    set utag [lindex $instr 1]
			}
			set type [$wServCan type $utag]
			if {[string equal $type "text"]} {
			    
			    # Extract the actual text. TclSpeech not foolproof!
			    set theText [$wServCan itemcget $utag -text]
			    if {[string match *${punct}* $theText]} {
				catch {::UserActions::Speak $theText $prefs(voiceOther)}
			    }
			}
		    }
		}
	    }		
	}
	IDENTITY {
	    if {[regexp "^IDENTITY: +($portwrd_) +($pre_) +($llist_|$wrd_)$" \
	      $line junk remPort id user]} {
		
		# A client tells which server port number it has, its item prefix
		# and its user name.
		
		if {$debugServerLevel >= 2 } {
		    puts "HandleClientRequest:: IDENTITY: remPort=$remPort, \
		      id=$id, user=$user"
		}
		
		# Save port and socket for the server side in array.
		# This is done here so we are sure that it is not a temporary socket
		# for file transfer etc.
		
		set ipNumTo(servSocket,$ip) $channel
		set ipNumTo(servPort,$ip) $remPort
		
		# If user is a list remove braces.
		set ipNumTo(user,$ip) [lindex $user 0]
		set ipNumTo(connectTime,$ip) [clock seconds]
		
		# Add entry in the communication frame.
		::UI::SetCommEntry . $ip -1 1
		::UI::MenuMethod .menu.info entryconfigure mOnClients  \
		  -state normal
		
		# Check that not own ip and user.
		if {$ip == $this(ipnum) &&   \
		  [string equal [string tolower $user]  \
		  [string tolower $this(username)]]} {
		    tk_messageBox -message [FormatTextForMessageBox  \
		      "A connecting client has chosen an ip number  \
		      and user name identical to your own."] \
		      -icon warning -type ok
		}
		
		# If auto connect, then make a connection to the client as well.
		if {[string equal $prefs(protocol) "symmetric"] &&  \
		  $prefs(autoConnect) && [lsearch $allIPnumsTo $ip] == -1} {
		    if {$debugServerLevel >= 2} {
			puts "HandleClientRequest:: autoConnect:  \
			  ip=$ip, name=$ipNumTo(name,$ip), remPort=$remPort"
		    }
		    
		    # Handle the complete connection process.
		    # Let propagateSizeToClients = false.
		    ::OpenConnection::DoConnect $ip $ipNumTo(servPort,$ip) 0
		} elseif {[string equal $prefs(protocol) "server"]} {
		    ::UI::FixMenusWhen . "connect"
		}
	    }		
	}
	"IPS CONNECTED" {
	    if {[regexp "^IPS CONNECTED: +($any_|$nothing_)$" \
	      $line junk remListIPandPort]} {
		
		# A client tells which other ips it is connected to.
		# 'remListIPandPort' contains: ip1 port1 ip2 port2 ...
		
		if {$debugServerLevel >= 2 } {
		    puts "HandleClientRequest:: IPS CONNECTED:  \
		      remListIPandPort=$remListIPandPort"
		}
		
		# If multi connect then connect to all other 'remAllIPnumsTo'.
		if {[string equal $prefs(protocol) "symmetric"] &&  \
		  $prefs(multiConnect)} {
		    
		    # Make temporary array that maps ip to port.
		    array set arrayIP2Port $remListIPandPort
		    foreach ipNum [array names arrayIP2Port] {
			if {![IsConnectedToQ $ipNum]} {		
			    
			    # Handle the complete connection process.
			    # Let propagateSizeToClients = false.
			    ::OpenConnection::DoConnect $ipNum $arrayIP2Port($ipNum) 0
			}
		    }
		}
	    }		
	}
	CLIENT {
	    if {[regexp "^CLIENT: *($optlist_)$" $line match clientList]} {
		
		# Primarily for the reflector server, when one client connects,
		# the reflector srver has cached information of all other clients
		# that is transfered this way. Also used when a new client connects
		# to the reflector server.
		# Each client identifies itself with a list of 'key: value' pairs.
		
		array set arrClient $clientList
		set clientRecord($arrClient(ip:)) $clientList
	    }		
	}
	DISCONNECTED {
	    if {[regexp "^DISCONNECTED: *($ipnum_)$" $line match theIP]} {
		
		# Primarily for the reflector server, when one client disconnects.
		
		if {[info exists clientRecord($theIP)]} {
		    unset clientRecord($theIP)
		}
	    }		
	}
	RESIZE {
	    if {[regexp "^RESIZE: +($int_) +($int_)$" $line match w h]} {
		
		# Received resize request.
		
		if {$debugServerLevel >= 2 } {
		    puts "HandleClientRequest:: RESIZE: w=$w, h=$h"
		}
		
		# Change total size of application so that w and h is the canvas size.
		# Be sure to not propagate this size change to other clients.
		# A full blown update seems to be necessary on Windows!
		if {0} {
		    bind $wServCan <Configure> [list ::UI::CanvasConfigureCallback 0]
		    ::UI::SetCanvasSize $w $h
		    update
		    bind $wServCan <Configure> [list ::UI::CanvasConfigureCallback "all"]
		}		
	    }
	}
	PUT - GET {
	    if {[regexp "^(PUT|GET): +($llist_|$wrd_) *($optlist_)$" \
	      $line what cmd fileName optList]} {
		
		# Put file to receive file; handles via temporary socket.
		# The 'optList' is a list of 'key: value' pairs, resembling
		# the html protocol for getting files, but where most keys 
		# correspond to a valid "canvas create" option, and everything 
		# is on a single line.
		
		# For some reason the outer {} must be stripped off.
		set fileName [lindex $fileName 0]
		set tempChannel($channel) 1
		
		if {$cmd == "PUT"} {
		    
		    # Some file is put on this server, take action.
		    if {$debugServerLevel >= 2 } {
			puts "=HandleClientRequest:: PUT: cmd=$cmd, channel=$channel"
			puts "    fileName=$fileName, optList=$optList"
		    }
		    
		    # Be sure to strip off any path. (this(path))??? Mac bug for /file?
		    set fileName [file tail $fileName]
		    ::GetFile::GetFileFromClient $wtop $ip $channel $fileName \
		      ::GetFile::DefaultCallbackProc $optList
		} elseif {$cmd == "GET"} {
		    
		    # A file is requested from this server. 'fileName' may be
		    # a relative path so beware. This should be taken care for in
		    # 'PutFileToClient'.
		    
		    if {$debugServerLevel >= 2 } {
			puts "=HandleClientRequest:: GET: cmd=$cmd, channel=$channel"
			puts "    fileName=$fileName, optList=$optList"
		    }
		    ::PutFileIface::PutFileToClient $wtop $channel $ip \
		      $fileName $optList
		}
	    }		
	}
	"PUT NEW" {
	    if {[regexp "^PUT NEW: +($llist_|$wrd_) *($optlist_)$" \
	      $line what relFilePath optList]} {
		
		# We should open a new socket and request a GET operation on that
		# socket with the options given.
		
		# For some reason the outer {} must be stripped off.
		set relFilePath [lindex $relFilePath 0]
		
		if {$debugServerLevel >= 2} {
		    puts "--->PUT NEW: relFilePath='$relFilePath', optList='$optList'"
		}
		::GetFile::GetFileFromServer $wtop $ip $ipNumTo(servPort,$ip) $relFilePath  \
		  ::GetFile::DefaultCallbackProc $optList
	    }		
	}
	"GET CANVAS" {
	    if {[regexp "^GET CANVAS:" $line]} {
		
		# The present client requests to put this canvas.	
		if {$debugServerLevel >= 2} {
		    puts "--->GET CANVAS:"
		}
		DoPutCanvas $wServCan $ip
	    }		
	}
	"RESIZE IMAGE" {
	    if {[regexp "^RESIZE IMAGE: +($wrd_) +($wrd_) +($signint_)$"   \
	      $line match itOrig itNew zoomFactor]} {
		
		# Image (photo) resizing.	
		if {$debugServerLevel >= 2} {
		    puts "--->RESIZE IMAGE: itOrig=$itOrig, itNew=$itNew, \
		      zoomFactor=$zoomFactor"
		}
		::ImageAndMovie::ResizeImage $wtop $zoomFactor $itOrig $itNew "local"
	    }		
	}
	"GET IP" {
	    if {[regexp "^GET IP: +($wrd_)$" $line match getid]} {
		
		# Extract the unique request id number, and forward it.
		if {[string equal $prefs(protocol) "jabber"]} {
		    ::Jabber::PutIPnumber $attrarr(-from) $getid
		}
	    }		
	}
	"PUT IP" {
	    if {[regexp "^PUT IP: +($wrd_) +($wrd_)$"   \
	      $line match getid clientIP]} {
		
		# We have got the requested ip number from the client.
		if {[string equal $prefs(protocol) "jabber"]} {
		    ::Jabber::GetIPCallback $attrarr(-from) $getid $clientIP
		}
	    }		
	}
	default {
	    
	    # We couldn't recognize this command as our own.
	    
	}
    }
}

# IsServerCommandSafe --
#
#       Look for any "[" that are not backslashed "\[" and not embraced {...[...}
#     
# Arguments:
#       cmd        Typically a canvas command, but can be any string.
#
# Returns:
#       0          If not safe
#       cmd        If safe; see comments above.

proc IsServerCommandSafe { cmd } {
    
    # Patterns:
    # Verbatim [ that is not backslashed.
    set lbr_ {[^\\]\[}
    set lbr2_ {\[}
    set nolbr_ {[^\{]*}
    set norbr_ {[^\}]*}
    set noanybr_ {[^\}\{]*}
    set any_ {.*}

    if {[regexp "^(${any_})${lbr_}(${any_})$" $cmd match leftStr rightStr]} {
	
	# We have got one "[" that is not backslashed. Check if it's embraced.
	# Works only for one level of braces.
	
	if {[regexp "\{${noanybr_}${lbr2_}${noanybr_}\}" $cmd]} {
	    return $cmd
	} else {
	    return 0
	}
    } else {
	return $cmd
    }
}

#-------------------------------------------------------------------------------
