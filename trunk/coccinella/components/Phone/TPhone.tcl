#  TPhone.tcl ---
#  
#      This file implements a megawidget phone key pad.
#      
#  Copyright (c) 2006  Mats Bengtsson
#  
# $Id: TPhone.tcl,v 1.2 2006-04-27 07:48:49 matben Exp $

#-------------------------------------------------------------------------------
# USAGE:
# 
#   ::TPhone::New widgetPath tclProc ?-key value ...?
#
#   ::TPhone::Volume widgetPath microphone|speaker ?level?
#
#   ::TPhone::Number widgetPath ?number?
#   
#   ::TPhone::State widgetPath name ?state?
#   
#   ::TPhone::DialState widgetPath state
#
#-------------------------------------------------------------------------------

package require tile
package require tkpng

package provide TPhone 0.1

namespace eval ::TPhone {
    
    variable inited 0
    variable imagePath [file join [file dirname [info script]] timages]
}

proc ::TPhone::Init {} {
    variable inited
    variable imagePath
    variable images
    variable buttons {1 2 3 4 5 6 7 8 9 star 0 square}

    # Use the content of the 'timages' folder to define all the images we need.
    if {![info exists images(0)]} {
	set subPath [file join components Phone timages]
	foreach f [glob -nocomplain -directory $imagePath *.png] {
	    set name [file rootname [file tail $f]]
	    set images($name) [::Theme::GetImage $name $subPath]
	}
    }
    
    foreach name [tile::availableThemes] {
	style theme settings $name {
	    
	    style layout Phone.TButton {
		Phone.border -children {
		    Phone.padding -children {
			Phone.label -side left
		    }
		}
	    }
	    style configure Phone.TButton  \
	      -padding {0} -borderwidth 0 -relief flat

	    style layout Phone.Toolbutton {
		Phone.label
	    }
	}
    }
    
    # Map from name to widget subpath.
    variable name2w
    array set name2w {
	display  display
	0        bts.0
	1        bts.1
	2        bts.2
	3        bts.3
	4        bts.4
	5        bts.5
	6        bts.6
	7        bts.7
	8        bts.8
	9        bts.9
	star     bts.star
	square   bts.square
	call     bts.call
	hangup   bts.hangup
	transfer bts.transfer
	backspace bts.backspace
    }
    set inited 1
}

# TPhone::New --
#
#       Creates new megawidget phone pad.
#       
# Arguments:
#       w
#       command     tclProc
#       args        options to the main ttk::frame
#       
# Results:
#       $w

proc ::TPhone::New {w command args} {
    variable inited
    variable images
    variable buttons
        
    variable $w
    upvar #0 $w state
          
    if {!$inited} {
	Init
    }
    set state(command) $command
    set state(microphone) 0
    set state(speaker) 0
    set state(old:microphone) 0
    set state(old:speaker) 0
    set state(cmicrophone) 1
    set state(cspeaker) 1
    set state(line) 1
    set state(subject) ""

    eval {ttk::frame $w} $args
    
    # The display:
    set width  [expr {[image width $images(display)] + 0}]
    set height [expr {[image height $images(display)] + 0}]
    set display $w.display
    canvas $w.display -width $width -height $height  \
      -highlightthickness 3 -bd 0 -highlightbackground gray87  \
      -insertwidth 0 -bg gray87
    $w.display create image 3 3 -anchor nw -image $images(display)
    $w.display create text  18 26 -anchor nw -tag number  \
      -font {Helvetica -16} -fill black
    $w.display create text  18 46 -anchor nw -tag time  \
      -font {Helvetica -11} -fill black
    $w.display create text  [expr {$width - 18}] 16 -anchor nw -tag mwi  \
      -font {Helvetica -11} -fill black
    $w.display bind mwi <Button-1> [list ::TPhone::Invoke $w mwi]
    
    grid  $w.display  -pady 4
    
    $w.display itemconfigure time -text 00:00:00
    $w.display itemconfigure mwi -text 0

    bind $display <ButtonPress> {
	focus %W
	%W focus number
    }
    
    bind $display <KeyPress>  [list ::TPhone::KeyPress $w %A %K]
    bind $display <Delete>    [list ::TPhone::KeyDeleteBind $w]
    bind $display <BackSpace> [list ::TPhone::KeyDeleteBind $w]

    # Call Subject
    set subject $w.esb
    ttk::frame $w.esb
    grid  $w.esb  -sticky ew -pady 2
    
    ttk::label $subject.lsubject -text "[mc Subject]:"
    ttk::entry $subject.esubject -textvariable $w\(subject)  \
      -width 18
    grid $subject.lsubject $subject.esubject -padx 2 -pady 2    
    
    # Buttons:
    set bts $w.bts
    ttk::frame $w.bts
    grid  $w.bts  -sticky ew -pady 2
    
    option add *$bts.TButton.takeFocus  0
    
#    set wr $bts.radio
#    ttk::frame $bts.radio
#    ttk::radiobutton $wr.1 -style Phone.Toolbutton  \
#      -image [list $images(radio1) selected $images(radio1Pressed)]  \
#      -variable $w\(line) -value 1 -command [list ::TPhone::Line $w]
#    ttk::radiobutton $wr.2 -style Phone.Toolbutton  \
#      -image [list $images(radio2) selected $images(radio2Pressed)]  \
#      -variable $w\(line) -value 2 -command [list ::TPhone::Line $w]
#    ttk::radiobutton $wr.3 -style Phone.Toolbutton  \
#      -image [list $images(radio3) selected $images(radio3Pressed)]  \
#      -variable $w\(line) -value 3 -command [list ::TPhone::Line $w]
    
#    grid  $wr.1  $wr.2  $wr.3
    
    ttk::button $bts.call -style Phone.TButton  \
      -image [list $images(call) pressed $images(callPressed)]  \
      -command [list ::TPhone::Invoke $w call]
    
    ttk::button $bts.transfer -style Phone.TButton  \
      -image [list $images(transfer) pressed $images(transferPressed)]  \
      -command [list ::TPhone::Invoke $w transfer]
    
    ttk::button $bts.hangup -style Phone.TButton  \
      -image [list $images(hangup) pressed $images(hangupPressed)]  \
      -command [list ::TPhone::Invoke $w hangup]
    
    grid  $bts.call  $bts.transfer  $bts.hangup  -padx 2 -pady 2
    
    bind $bts.call <KeyPress>  [list ::TPhone::KeyPress $w %A %K]
    bind $bts.call <Delete>    [list ::TPhone::KeyDeleteBind $w]
    bind $bts.call <BackSpace> [list ::TPhone::KeyDeleteBind $w]

    bind $bts.transfer <KeyPress>  [list ::TPhone::KeyPress $w %A %K]
    bind $bts.transfer <Delete>    [list ::TPhone::KeyDeleteBind $w]
    bind $bts.transfer <BackSpace> [list ::TPhone::KeyDeleteBind $w]

    bind $bts.hangup <KeyPress>  [list ::TPhone::KeyPress $w %A %K]
    bind $bts.hangup <Delete>    [list ::TPhone::KeyDeleteBind $w]
    bind $bts.hangup <BackSpace> [list ::TPhone::KeyDeleteBind $w]
	
    foreach {c0 c1 c2} $buttons {
	ttk::button $bts.$c0 -style Phone.TButton  \
	  -image [list $images(b$c0) pressed $images(b${c0}Pressed)]  \
	  -command [list ::TPhone::Invoke $w $c0]
	ttk::button $bts.$c1 -style Phone.TButton  \
	  -image [list $images(b$c1) pressed $images(b${c1}Pressed)]  \
	  -command [list ::TPhone::Invoke $w $c1]
	ttk::button $bts.$c2 -style Phone.TButton  \
	  -image [list $images(b$c2) pressed $images(b${c2}Pressed)]  \
	  -command [list ::TPhone::Invoke $w $c2]
	
	grid  $bts.$c0  $bts.$c1  $bts.$c2  -padx 2 -pady 2
	
	bind $bts.$c0 <KeyPress>  [list ::TPhone::KeyPress $w %A %K]
	bind $bts.$c0 <Delete>    [list ::TPhone::KeyDeleteBind $w]
	bind $bts.$c0 <BackSpace> [list ::TPhone::KeyDeleteBind $w]
	bind $bts.$c1 <KeyPress>  [list ::TPhone::KeyPress $w %A %K]
	bind $bts.$c1 <Delete>    [list ::TPhone::KeyDeleteBind $w]
	bind $bts.$c1 <BackSpace> [list ::TPhone::KeyDeleteBind $w]
        bind $bts.$c2 <KeyPress>  [list ::TPhone::KeyPress $w %A %K]
	bind $bts.$c2 <Delete>    [list ::TPhone::KeyDeleteBind $w]
	bind $bts.$c2 <BackSpace> [list ::TPhone::KeyDeleteBind $w]
    }

    ttk::button $bts.backspace -style Phone.TButton  \
      -image [list $images(backspace) pressed $images(backspacePressed)]  \
      -command [list ::TPhone::Invoke $w backspace]    
    grid  $bts.backspace -column 1

    bind $bts.backspace <KeyPress>  [list ::TPhone::KeyPress $w %A %K]
    bind $bts.backspace <Delete>    [list ::TPhone::KeyDeleteBind $w]
    bind $bts.backspace <BackSpace> [list ::TPhone::KeyDeleteBind $w]
    
    set bot $w.bot
    ttk::frame $w.bot
    grid  $w.bot  -sticky ew -pady 2

    bind $bot  <KeyPress>  [list ::TPhone::KeyPress $w %A %K]
    bind $bot  <Delete>    [list ::TPhone::KeyDeleteBind $w]
    bind $bot  <BackSpace> [list ::TPhone::KeyDeleteBind $w]
    
    ttk::frame $bot.mic
    ttk::scale $bot.mic.s -orient vertical -from 0 -to 100 \
      -variable $w\(microphone) -command [list ::TPhone::MicCmd $w] -length 60
    ttk::checkbutton $bot.mic.l -style Toolbutton  \
      -variable $w\(cmicrophone) -image $images(microphone)  \
      -onvalue 0 -offvalue 1 -padding {1}  \
      -command [list ::TPhone::Mute $w microphone]
    pack  $bot.mic.s  $bot.mic.l  -side top
    pack $bot.mic.l -pady 4

    
    ttk::frame $bot.spk
    ttk::scale $bot.spk.s -orient vertical -from 0 -to 100 \
      -variable $w\(speaker) -command [list ::TPhone::SpkCmd $w] -length 60
    ttk::checkbutton $bot.spk.l -style Toolbutton  \
      -variable $w\(cspeaker) -image $images(speaker)  \
      -onvalue 0 -offvalue 1 -padding {1}  \
      -command [list ::TPhone::Mute $w speaker]
    pack  $bot.spk.s  $bot.spk.l  -side top
    pack $bot.spk.l -pady 4

    grid  $bot.mic $bot.spk -padx 4
    grid $bot.mic -sticky w
    grid $bot.spk -sticky e
    grid columnconfigure $bot 1 -weight 1

    bind $bot.mic.l <KeyPress>  [list ::TPhone::KeyPress $w %A %K]
    bind $bot.mic.l <Delete>    [list ::TPhone::KeyDeleteBind $w]
    bind $bot.mic.l <BackSpace> [list ::TPhone::KeyDeleteBind $w]
    bind $bot.spk.l <KeyPress>  [list ::TPhone::KeyPress $w %A %K]
    bind $bot.spk.l <Delete>    [list ::TPhone::KeyDeleteBind $w]
    bind $bot.spk.l <BackSpace> [list ::TPhone::KeyDeleteBind $w]    
    
    bind $w <Destroy>  { ::TPhone::Free %W }
    return $w
}

proc ::TPhone::KeyPress {w key alt} {
    variable $w
    upvar #0 $w state  
    set meta {period colon minus underscore slash Shift_L Alt_L Control_L Meta_L}
    #We can call an URI with text characters
    set metaValue 0
    if { ([lsearch $meta $alt]>=0) || [string is wordchar -strict $alt]} {
	set metaValue 1
    }
    if { $metaValue && $key ne ""} {
        if {[string is integer -strict $key]} {
    	    $w.bts.$key invoke
        } else {
            set btn [string map {"*" star "#" square} $key]
            if { $key eq "*" || $key eq "#"} {
		$w.bts.$btn invoke
            } else {
                $w.display insert number end $key  
	    	uplevel #0 $state(command) $key
            }
        }
    }
}

proc ::TPhone::KeyDeleteBind {w} {
    $w.bts.backspace invoke
}

proc ::TPhone::KeyDelete {w} {
    set len [string length [$w.display itemcget number -text]]
    $w.display dchars number [expr {$len - 1}]  
}

proc ::TPhone::TimeUpdate {w time} {
    $w.display itemconfigure time -text $time
}

proc ::TPhone::GetSubject {w args} {
    variable $w
    upvar #0 $w state
    
    if {$args eq {}} {
	return $state(subject)
    } 
}

proc ::TPhone::SetSubject {w subject} {
    variable $w
    upvar #0 $w state
    
    set state(subject) $subject
}

proc ::TPhone::MWIUpdate {w msgCount} {
    $w.display itemconfigure mwi -text $msgCount
}

proc ::TPhone::MicCmd {w level} {
    variable $w
    upvar #0 $w state
    
    if {$level != $state(old:microphone)} {
	uplevel #0 $state(command) microphone [expr {100 - $level}]
    }
    set state(old:microphone) $level
}

proc ::TPhone::SpkCmd {w level} {
    variable $w
    upvar #0 $w state
    
    if {$level != $state(old:speaker)} {
	uplevel #0 $state(command) speaker [expr {100 - $level}]        
    }
    set state(old:speaker) $level
}

proc ::TPhone::Volume {w type args} {
    variable $w
    upvar #0 $w state
        
    if {[lsearch {microphone speaker} $type] < 0} {
	return -code error "unrecognized volume type \"$type\""
    }
    if {$args == {}} {
	return [expr {100 - $state($type)}]
    } else {
	set state($type) [expr {100 - [lindex $args 0]}]
    }
}

proc ::TPhone::Number {w args} {
    variable $w
    upvar #0 $w state
    
    if {$args eq {}} {
	return [$w.display itemcget number -text]
    } else {
	set number [lindex $args 0]
	$w.display itemconfigure number -text $number
    }
}

proc ::TPhone::State {w name {_state ""}} {
    variable name2w
    
    # Map from name to widget subpath!
    set win $w.$name2w($name)
    set wclass [winfo class $win]
    if {$_state eq ""} {
	if {$wclass eq "Canvas"} {
	    return [$win cget -state]
	} else {
	    return [$win state]
	}
    } else {
	if {$wclass eq "Canvas"} {
	    $win configure -state $_state
	} else {
	    $win state $_state
	}
    }
}

proc ::TPhone::DialState {w _state} {
    variable name2w
    variable buttons
    
    if {$_state eq "disabled"} {
	foreach name $buttons {
	    $w.$name2w($name) state {disabled}
	}
	$w.$name2w(display) configure -state disabled
    } else {
	foreach name $buttons {
	    $w.$name2w($name) state {!disabled}
	}
	$w.$name2w(display) configure -state normal
    }
}

proc ::TPhone::Invoke {w b} {
    variable $w
    upvar #0 $w state
    
    set tone [string map {star "*" square "#"} $b]
    if {[string is integer -strict $b]} {
	$w.display insert number end $b
    }
    if { $b eq "star" || $b eq "square"} {
	$w.display insert number end $tone
    }
 
    uplevel #0 $state(command) $tone
}

proc ::TPhone::Line {w} {
    variable $w
    upvar #0 $w state
       
    uplevel #0 $state(command) line $state(line)
}

proc ::TPhone::Mute {w type} {
    variable $w
    upvar #0 $w state
       
    uplevel #0 $state(command) mute $type $state(c$type)
}

# TPhone::Button --
# 
#       Make standalone button.

proc ::TPhone::Button {w type args} {
    variable inited
    variable images
    
    if {!$inited} {
	Init
    }
    return [eval {ttk::button $w -style Phone.TButton  \
      -image [list $images($type) pressed $images(${type}Pressed)]} $args]
}

proc ::TPhone::Free {w} {
    variable $w
    upvar #0 $w state
    
    unset -nocomplain state
}
