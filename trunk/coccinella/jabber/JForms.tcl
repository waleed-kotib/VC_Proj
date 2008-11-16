#  JForms.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements dynamic forms GUI. 
#      If an 'jabber:x:data' namespaced element is given, the methods
#      involved with this method are used. Else straight (simple) model.
#      
#  Copyright (c) 2002-2007  Mats Bengtsson
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
# $Id: JForms.tcl,v 1.37 2008-06-09 09:50:59 matben Exp $
# 
#      Updated to version 2.5 of XEP-0004
#  
#-------------------------------------------------------------------------------

package require wrapper

package provide JForms 1.0

namespace eval ::JForms:: {
    
    # Public functions:
    # 
    #   ::JForms::Build w queryE ?-key value ...?
    #   ::JForms::XDataFrame w xdataE ?-tilestyle, -width?
    #   ::JForms::GetXML token
    #   ::JForms::GetStateValue token key
    
    # Internal state:
    # 
    #   state(reported)  : 
    #       list of pairs 'varName label' for each search entry received.
 
    
    # Unique id used as a token.
    variable uid 0

    # Spacer for some labels.
    variable topPadding {0 2 0 0}
    
}

# JForms::Build --
# 
#       Master function to build a form frame from a query-element.
#       
# Arguments:
#       w           the megawidget form.
#       queryE      query-element
#       args:       -tilestyle (|Small|Mixed)
#                   -xdata (0|1)
#                   -width
#       
# Results:
#       token

proc ::JForms::Build {w queryE args} {
    global jprefs
    variable uid

    # State variable to collect instance specific variables.
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state

    array set opts {
	-tilestyle ""
	-xdata     1
	-width     0
    }
    array set opts $args
    
    set xmllist [wrapper::getchildren $queryE]
    set queryXmlns [wrapper::getattribute $queryE xmlns]

    set state(w)       $w
    set state(xmllist) $xmllist
    set state(xmlns)   $queryXmlns
    foreach {key val} [array get opts] {
	set state(opt,$key) $val
    }
    
    set xdata 0
    if {$jprefs(useXData) && $opts(-xdata)} {
	set clist [wrapper::getnamespacefromchilds $xmllist x "jabber:x:data"]
	if {$clist != {}} {
	    set xdata 1
	    set xdataE [lindex $clist 0]
	    set state(xdataE) $xdataE
	}
    }
    set state(xdata) $xdata

    set state(textLabelStyle) TLabel
    if {$opts(-tilestyle) eq "Small"} {
	set wp [string trim $w .]	
	set state(textLabelStyle) Small.TLabel
	OptionAddSmall $w
    } elseif {$opts(-tilestyle) eq "Mixed"} {
	set state(textLabelStyle) Small.TLabel
    }
    if {$xdata} {
	BuildXDataFrame $token
    } else {
	BuildPlainFrame $token
    }
    bind $w <Destroy> [list [namespace current]::Free $token]    
    return $token
}

proc ::JForms::XDataFrame {w xdataE args} {
    variable uid
    
    # State variable to collect instance specific variables.
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state

    array set opts {
	-tilestyle ""
	-width     0
    }
    array set opts $args

    set state(w)      $w
    set state(xdata)  1
    set state(xdataE) $xdataE
    foreach {key val} [array get opts] {
	set state(opt,$key) $val
    }
    set state(textLabelStyle) TLabel
    if {$opts(-tilestyle) eq "Small"} {
	set wp [string trim $w .]	
	set state(textLabelStyle) Small.TLabel
	OptionAddSmall $w
    } elseif {$opts(-tilestyle) eq "Mixed"} {
	set state(textLabelStyle) Small.TLabel
    }

    BuildXDataFrame $token
    bind $w <Destroy> [list [namespace current]::Free $token]    
    return $token
}

proc ::JForms::OptionAddSmall {w} {
    
    set wp [string trim $w .]	

    option add *$wp*TLabel.style        Small.TLabel        widgetDefault
    option add *$wp*TLabelframe.style   Small.TLabelframe   widgetDefault
    option add *$wp*TButton.style       Small.TButton       widgetDefault
    option add *$wp*TMenubutton.style   Small.TMenubutton   widgetDefault
    option add *$wp*TRadiobutton.style  Small.TRadiobutton  widgetDefault
    option add *$wp*TCheckbutton.style  Small.TCheckbutton  widgetDefault
    option add *$wp*TEntry.style        Small.TEntry        widgetDefault
    option add *$wp*TEntry.font         CociSmallFont       60
}

proc ::JForms::BindEntry {w event cmd} {
    
    foreach win [winfo children $w] {
	set wclass [winfo class $win]
	if {($wclass eq "Entry") || ($wclass eq "TEntry")} {
	    bind $win $event $cmd
	} else {
	    BindEntry $win $event $cmd
	}
    }
}

# Support for the "plain" forms, typically:
# 
#   <query xmlns='jabber:iq:register'>
#       <instructions>
#           Choose a username and password for use with this service.
#       </instructions>
#       <username/>
#       <password/>
#       <email/>
#   </query>

proc ::JForms::BuildPlainFrame {token} {
    variable $token
    upvar 0 $token state

    set w $state(w)
    ttk::frame $w

    set xmllist $state(xmllist)
    set state(wraplengthList) {}
    set state(reported) {jid JID}


    # Any instructions or registered elements shall be first.
    foreach name {instructions registered} {
	set elemList [wrapper::getfromchilds $xmllist $name]
	if {$elemList != {}} {
	    PlainEntry $token [lindex $elemList 0]
	    set xmllist [wrapper::deletefromchilds $xmllist $name]
	}
    }
    
    # Handle tag by tag.
    foreach child $xmllist {
	PlainEntry $token $child
    }    
    grid columnconfigure $w 1 -weight 1
    
    # Need a spacer for wraplength if no exist.
    ttk::frame $w.spacer -width $state(opt,-width)
    grid  $w.spacer  -  -sticky ew
    
    after idle [list ::JForms::BindConfigure $token]
    #bind $w <Configure> \
    #  +[list [namespace current]::ConfigWraplengthList $token]

    # Trick to resize the labels wraplength.
    set script [format {
	::JForms::ConfigWraplengthList %s
    } $token]    
    #after idle $script

    return $w
}

proc ::JForms::PlainEntry {token child} {
    variable $token
    upvar 0 $token state
    
    set w $state(w)
    set tag   [wrapper::gettag $child]
    set cdata [wrapper::getcdata $child]

    # We may get multiple elements with the same tag!
    if {[info exists state(num,$tag)]} {
	incr state(num,$tag)
    } else {
	set state(num,$tag) 0
    }
    set num $state(num,$tag)
    set key [string tolower $tag]$num
    set wlab $w.l$key
    set went $w.e$key

    # Specials.
    if {$tag eq "instructions"} {
	ttk::label $wlab -style $state(textLabelStyle) \
	  -text $cdata -justify left
	grid  $wlab  -columnspan 2 -sticky w -pady 2
	if {$state(opt,-width)} {
	    $wlab configure -wraplength $state(opt,-width)
	}
	lappend state(wraplengthList) $wlab
    } elseif {$tag eq "registered"} {
	ttk::label $wlab -style $state(textLabelStyle) \
	  -text [mc "You are already registered with this service. These are your current registration settings."] -justify left
	grid  $wlab  -columnspan 2 -sticky w -pady 2
	if {$state(opt,-width)} {
	    $wlab configure -wraplength $state(opt,-width)
	}
	lappend state(wraplengthList) $wlab
    } elseif {$tag eq "key"} {
	
	# "This element is obsolete, but is documented here for historical 
	# completeness." Just return the original key.
	set state(tag,$num,$tag) $cdata
    } else {
	set str [string totitle $tag]
	set state(tag,$num,$tag) $cdata
	lappend state(reported) $tag $str
	
	# The -width 0 for the entry seems necessary.
	ttk::label $wlab -text "[mc $str]:"
	ttk::entry $went -textvariable $token\(tag,$num,$tag) -width 0
	
	grid  $wlab  $went  -sticky e -pady 2
	grid  $went  -sticky ew

	if {$tag eq "password"} {
	    $went configure -show {*}
	}

	set registration [dict create]
	dict set registration address [mc "Street portion of a physical or mailing address"]
	dict set registration city [mc "Locality portion of a physical or mailing address"]
	dict set registration date [mc "Some date (e.g., birth date, hire date, sign-up date)"]
	dict set registration email [mc "Email address"]
	dict set registration first [mc "First name or given name"]
	dict set registration is-registered [mc "You are already registered with this service. These are your current login settings."]
	dict set registration last [mc "Last name, surname, or family name"]
	dict set registration name [mc "Full name"]
	dict set registration nick [mc "Familiar name"]
	dict set registration password [mc "Password or secret"]
	dict set registration phone [mc "Telephone number"]
	dict set registration state [mc "An administrative region of the nation, such as a state or province"]
	dict set registration url [mc "URL to personal website"]
	dict set registration username [mc "Account name associated with the user"]
	dict set registration zip [mc "Postal code portion of a physical or mailing address"]
	
	set help [dict get $registration $tag]
	if {$help ne "registration-$tag"} {
	    ::balloonhelp::balloonforwindow $wlab $help
	    ::balloonhelp::balloonforwindow $went $help
	}
    }
}

proc ::JForms::GetXML {token} {
    variable $token
    upvar 0 $token state
    
    if {$state(xdata)} {
	set xmllist [GetXDataForm $token]
    } else {
	set xmllist [GetPlainForm $token]	
    }
    return $xmllist
}

proc ::JForms::GetPlainForm {token} {
    variable $token
    upvar 0 $token state
    
    set subElem {}
    foreach {key num} [array get state num,*] {
	set tag [string map {num, ""} $key]
	
	if {$tag eq "instructions"} {
	    continue
	}
	if {$tag eq "registered"} {
	    continue
	}
	
	# How to deal with multiple identical tags?
	# Include all for the moment.
	for {set i 0} {$i <= $num} {incr i} {
	    set value $state(tag,$i,$tag)
	    if {$value ne ""} {
		lappend subElem [wrapper::createtag $tag -chdata $value]
	    }
	}
    }
    return $subElem
}

# JForms::BuildXDataFrame --
# 
#       Support for xdata forms, typically:
# 
#   <x xmlns='jabber:x:data' type='{form-type}'>
#       <title/>
#       <instructions/>
#       <field var='field-name'
#              type='{field-type}'
#              label='description'>
#           <desc/>
#           <required/>
#           <value>field-value</value>
#           <option label='option-label'><value>option-value</value></option>
#           <option label='option-label'><value>option-value</value></option>
#       </field>
#   </x> 
#   
#       There is an alternative form with multiple items:
#       
#   <x xmlns="jabber:x:data" type="result">
#       <reported>
#           <field var="name" type="text-single" label="Name"/>
#           <field var="desc" type="text-multi" label="Description"/>
#           <field var="count" type="text-single" label="User Count"/>
#	</reported>
#	<item>
#           <field var="shared"><value>0</value></field>
#           <field var="desc"><value></value></field>
#           <field var="count"><value>0</value></field>
#       </item>
#   </x>


proc ::JForms::BuildXDataFrame {token} {
    variable $token
    upvar 0 $token state

    set w $state(w)
    ttk::frame $w

    set xdataE $state(xdataE)
    set xmllist [wrapper::getchildren $xdataE]

    set state(wraplengthList) {}
    set state(i) 0
    set state(anyrequired) 0
            
    # Handle tag by tag.
    foreach elem $xmllist {

	set tag [wrapper::gettag $elem]
		
	switch -exact -- $tag {	    
	    title {
		NewTitle $token $elem
	    }
	    instructions {
		NewInstructions $token $elem
	    }
	    field {
		set attr(type) "text-single"
		array set attr [wrapper::getattrlist $elem]
		
		switch -exact -- $attr(type) {
		    text-single - text-private {
			NewLabelEntry $token $elem
		    }
		    text-multi {
			NewTextMulti $token $elem
		    }
		    list-single {
			NewListSingle $token $elem
		    }
		    list-multi {
			NewListMulti $token $elem
		    }
		    jid-single {
			NewLabelEntry $token $elem
		    }
		    jid-multi {
			NewJidMulti $token $elem
		    }
		    boolean {
			NewBoolean $token $elem
		    }
		    fixed {
			NewFixed $token $elem
		    }
		    hidden {
			NewHidden $token $elem
		    }
		    default {
			NewLabelEntry $token $elem
		    }
		}
	    }
	    reported {
		ParseReported $token $elem
	    }
	    item {
		ParseItem $token $elem
	    }
	}
    } 
    if {$state(anyrequired)} {
	set wlab $w.l[incr state(i)]
	ttk::label $wlab -text [mc "Labels with (*) are required."]
	grid  $wlab  -sticky w
	lappend state(wraplengthList) $wlab
    }
    grid columnconfigure $w 0 -weight 1
    
    after idle [list ::JForms::BindConfigure $token]

    return $w
}

proc ::JForms::BindConfigure {token} {
    variable $token
    upvar 0 $token state
    
    bind $state(w) <Configure> \
      +[list [namespace current]::ConfigWraplengthList $token]
}

proc ::JForms::ConfigWraplengthList {token} {
    variable $token
    upvar 0 $token state

    set width [expr {[winfo width $state(w)] - 2}]
    foreach wlab $state(wraplengthList) {
	$wlab configure -wraplength $width
    }
}

# JForms::ParseReported --
# 
#       Parses a reported element which is used by form type='result' and
#       typically followed by a number of field elements.
#       XEP-0004: 3.4 Multiple Items in Form Results 

proc ::JForms::ParseReported {token elem} {
    variable $token
    upvar 0 $token state
    
    set i 0
    
    # XEP-0004: (if it is "fixed", it MAY possess a 'var' attribute) 
    foreach fieldE [wrapper::getchildren $elem] {
	if {[wrapper::gettag $fieldE] ne "field"} {
	    continue
	}
	unset -nocomplain attr
	set attr(type) "text-single"
	array set attr [wrapper::getattrlist $fieldE]
	if {[info exists attr(var)]} {
	    set var $attr(var)
	} else {
	    set var fixed-[incr i]
	}
	set label $var
	if {[info exists attr(label)]} {
	    set label $attr(label)
	}
	lappend state(reported,vars) $var
	set state(reported,$var,type) $attr(type)
	set state(reported,$var,label) $label
    }
    
    # Make a header.
    set i 0
    lassign [grid size $state(w)] ncol nrow
    foreach var $state(reported,vars) {
	set wlab $state(w).l[incr state(i)]
	ttk::label $wlab -text $state(reported,$var,label)
	grid  $wlab  -row $nrow -column $i -padx 4 -pady 2
	set state(reported,$var,column) $i
	incr i
    }
}

# JForms::ParseItem --
# 
#       XEP-0004: 3.4 Multiple Items in Form Results 

proc ::JForms::ParseItem {token elem} {
    variable $token
    upvar 0 $token state
    
    set i 0
    lassign [grid size $state(w)] ncol nrow
    foreach fieldE [wrapper::getchildren $elem] {
	if {[wrapper::gettag $fieldE] ne "field"} {
	    continue
	}
	unset -nocomplain attr
	set attr(type) "text-single"
	array set attr [wrapper::getattrlist $fieldE]
	if {[info exists attr(var)]} {
	    set var $attr(var)
	    if {[info exists state(reported,$var,column)]} {
		set value ""
		
		switch -- $state(reported,$var,type) {
		    text-single - boolean - jid-single - fixed {
			set value [GetDefaultValue $fieldE]
		    }
		    jid-multi - list-multi - text-multi {
			# @@@ TODO
		    }
		}
		set wlab $state(w).l[incr state(i)]
		set c $state(reported,$var,column)
		ttk::label $wlab -text $value
		grid  $wlab  -row $nrow -column $c -padx 4
	    }
	}	
    }
}

proc ::JForms::NewTitle {token elem} {
    variable $token
    upvar 0 $token state
    
    set wlab $state(w).l[incr state(i)]
    set cdata [wrapper::getcdata $elem]
    ttk::label $wlab -text $cdata -justify left
    grid  $wlab  -sticky w -pady 2

    if {$state(opt,-width)} {
	$wlab configure -wraplength $state(opt,-width)
    }
    lappend state(wraplengthList) $wlab
}

proc ::JForms::NewInstructions {token elem} {
    variable $token
    upvar 0 $token state
    
    set cdata [wrapper::getcdata $elem]
    if {[string length $cdata]} {
	set wlab $state(w).l[incr state(i)]
	ttk::label $wlab -style $state(textLabelStyle) -text $cdata -justify left
	grid  $wlab  -sticky w -pady 2
	
	if {$state(opt,-width)} {
	    $wlab configure -wraplength $state(opt,-width)
	}
	lappend state(wraplengthList) $wlab
    }
}

proc ::JForms::NewLabelEntry {token elem} {
    variable $token
    upvar 0 $token state
    variable topPadding
    
    set attr(type) "text-single"
    array set attr [wrapper::getattrlist $elem]
    set var $attr(var)
    if {[info exists attr(label)]} {
	set str $attr(label)
    } else {
	set str [GetLabelFromVar $var]
    }
    if {[AnyRequired $token $elem]} {
	append str " (*)"
    }    
    set defValue [GetDefaultValue $elem]
    
    set state(def,$var)  $defValue
    set state(var,$var)  $defValue
    set state(type,$var) $attr(type)

    set eopts {}
    if {$attr(type) eq "text-private"} {
	set eopts {-show *}
    }
    set w $state(w)
    set wlab $w.l[incr state(i)]
    set went $w.e$state(i)

    ttk::label $wlab -text $str -justify left -padding $topPadding
    eval {ttk::entry $went -textvariable $token\(var,$var)} $eopts

    grid  $wlab  -sticky w
    grid  $went  -sticky ew

    if {$state(opt,-width)} {
	$wlab configure -wraplength $state(opt,-width)
    }
    lappend state(wraplengthList) $wlab
    BalloonDesc $elem $wlab $went
}

# JForms::NewTextMulti --
#
#       Note: Data provided for fields of type "text-multi" SHOULD NOT contain 
#       any newlines (the \n and \r characters). Instead, the application 
#       SHOULD split the data into multiple strings (based on the newlines 
#       inserted by the platform), then specify each string as the XML 
#       character data of a distinct <value/> element. 
#       Similarly, an application that receives multiple <value/> elements 
#       for a field of type "text-multi" SHOULD merge the XML character data 
#       of the value elements into one text block for presentation to a user, 
#       with each string separated by a newline character as appropriate for 
#       that platform. 
#       
#       Mats: STUPID!

proc ::JForms::NewTextMulti {token elem} {
    variable $token
    upvar 0 $token state
    variable topPadding

    array set attr [wrapper::getattrlist $elem]
    set var $attr(var)
    if {[info exists attr(label)]} {
	set str $attr(label)
    } else {
	set str [GetLabelFromVar $var]
    }
    if {[AnyRequired $token $elem]} {
	append str " (*)"
    }
    set defValueList [GetDefaultList $elem]
    set state(var,$var)  $defValueList
    set state(type,$var) $attr(type)

    set w $state(w)
    set wlab $w.l[incr state(i)]
    set wfr  $w.f$state(i)

    ttk::label $wlab -text $str -justify left -padding $topPadding
    ttk::frame $wfr
    
    set wtxt $wfr.txt
    set wsc  $wfr.sc
    text $wtxt -height 3 -wrap word -yscrollcommand [list $wsc set] -width 20
    ttk::scrollbar $wsc -orient vertical -command [list $wtxt yview]
    foreach str $defValueList {
	$wtxt insert end $str
	$wtxt insert end "\n"
    }
    set state(widget,$var) $wtxt

    grid  $wtxt  -column 0 -row 0 -sticky news
    grid  $wsc   -column 1 -row 0 -sticky ns
    grid columnconfigure $wfr 0 -weight 1
    grid rowconfigure    $wfr 0 -weight 1
    
    grid  $wlab  -sticky w
    grid  $wfr   -sticky ew

    if {$state(opt,-width)} {
	$wlab configure -wraplength $state(opt,-width)
    }
    lappend state(wraplengthList) $wlab
    BalloonDesc $elem $wlab $wtxt
}

proc ::JForms::NewListSingle {token elem} {
    variable $token
    upvar 0 $token state
    variable topPadding
    
    array set attr [wrapper::getattrlist $elem]
    set var $attr(var)
    if {[info exists attr(label)]} {
	set str $attr(label)
    } else {
	set str [GetLabelFromVar $var]
    }
    if {[AnyRequired $token $elem]} {
	append str " (*)"
    }
    
    # Represented by a popup menu button.
    set state(type,$var) $attr(type)
    
    # Build menu list and mapping from label to value.
    lassign [ParseMultiOpts $token $elem $var] defValueList labelList
    set defValue [lindex $defValueList 0]
    
    # Handle exceptions:
    if {![llength $labelList]} {
	
	# 1) No <option/> elements. Weird!
	set labelList "None"
	set defValue  "None"
	set defLabel  "None"
	set state(label2value,$var,$defLabel) $defValue
    } elseif {![llength $defValueList]} {
	
	# 2) No <value/> element.
	set defLabel [lindex $labelList 0]
	set defValue $state(label2value,$var,$defLabel)
    } else {
	set defLabel $state(value2label,$var,$defValue)
    }
    set state(label,$var) $defLabel
    set state(def,$var)   $defValue
    set state(var,$var)   $defValue

    set w $state(w)
    set wlab $w.l[incr state(i)]
    set wpop $w.p$state(i)
    
    # Note that we have the labels and not the values in the menubutton.
    ttk::label $wlab -text $str -justify left -padding $topPadding
    ui::combobutton $wpop -variable $token\(label,$var) \
      -menulist [ui::optionmenu::menuList $labelList]
    
    grid  $wlab  -sticky w
    grid  $wpop  -sticky w			

    if {$state(opt,-width)} {
	$wlab configure -wraplength $state(opt,-width)
    }
    lappend state(wraplengthList) $wlab
    BalloonDesc $elem $wlab $wpop
}

proc ::JForms::NewListMulti {token elem} {
    variable $token
    upvar 0 $token state
    
    array set attr [wrapper::getattrlist $elem]
    set var $attr(var)
    if {[info exists attr(label)]} {
	set str $attr(label)
    } else {
	set str [GetLabelFromVar $var]
    }
    if {[AnyRequired $token $elem]} {
	append str " (*)"
    }
    
    # Build menu list and mapping from label to value.
    set state(type,$var) $attr(type)
    lassign [ParseMultiOpts $token $elem $var] defValueList labelList    
    set defValue [lindex $defValueList 0]

    # Handle exceptions:
    if {![llength $labelList]} {
	
	# 1) No <option/> elements. Weird!
	set labelList "None"
	set defValue  "None"
	set defLabel  "None"
	set state(label2value,$var,$defLabel) $defValue
    } elseif {![llength $defValueList]} {
	
	# 2) No <value/> element.
	set defLabel [lindex $labelList 0]
	set defValue $state(label2value,$var,$defLabel)
    } else {
	set defLabel $state(value2label,$var,$defValue)
    }
    set state(label,$var) $defLabel
    set state(def,$var)   $defValue
    set state(var,$var)   $defValue
    set state(labelList,$var) $labelList

    # Represented by a listbox.
    set w $state(w)
    set wlab $w.l[incr state(i)]
    set wfr  $w.f$state(i)

    ttk::label $wlab -text $str -justify left
    
    ttk::frame $wfr
    set wlb $wfr.lb
    set wsc $wfr.sc
    listbox $wlb -height 4 -selectmode multiple  \
      -yscrollcommand [list $wsc set] -listvar $token\(labelList,$var)
    ttk::scrollbar $wsc -orient vertical -command [list $wlb yview]

    grid  $wlb  -column 0 -row 0 -sticky news
    grid  $wsc  -column 1 -row 0 -sticky ns
    grid columnconfigure $wfr 0 -weight 1
    grid rowconfigure    $wfr 0 -weight 1
    
    grid  $wlab  -sticky w
    grid  $wfr   -sticky ew

    set state(widget,$var) $wlb

    foreach value $defValueList {
	set ind [lsearch $labelList $state(value2label,$var,$value)]
	$wlb selection set $ind
    }
    if {$state(opt,-width)} {
	$wlab configure -wraplength $state(opt,-width)
    }
    lappend state(wraplengthList) $wlab
    BalloonDesc $elem $wlab $wlb
}   

proc ::JForms::NewJidMulti {token elem} {
    variable $token
    upvar 0 $token state
    
    array set attr [wrapper::getattrlist $elem]
    set var $attr(var)
    if {[info exists attr(label)]} {
	set str $attr(label)
    } else {
	set str [GetLabelFromVar $var]
    }
    if {[AnyRequired $token $elem]} {
	append str " (*)"
    }
    set defValueList [GetDefaultList $elem]
    set state(var,$var)  $defValueList
    set state(type,$var) $attr(type)

    set w $state(w)
    set wlab $w.l[incr state(i)]
    set wfr  $w.f$state(i)
    
    ttk::label $wlab -text $str -justify left
    ttk::frame $wfr
    
    set wtxt $wfr.txt
    set wsc  $wfr.sc
    text $wtxt -height 3 -wrap word -yscrollcommand [list $wsc set] -width 20
    ttk::scrollbar $wsc -orient vertical -command [list $wtxt yview]

    grid  $wtxt  -column 0 -row 0 -sticky news
    grid  $wsc   -column 1 -row 0 -sticky ns
    grid columnconfigure $wfr 0 -weight 1
    grid rowconfigure    $wfr 0 -weight 1
    
    grid  $wlab  -sticky w
    grid  $wfr   -sticky ew

    foreach jid $defValueList {
	$wtxt insert end $jid
	$wtxt insert end "\n"
    }
    set state(widget,$var) $wtxt
    
    if {$state(opt,-width)} {
	$wlab configure -wraplength $state(opt,-width)
    }
    lappend state(wraplengthList) $wlab
    BalloonDesc $elem $wlab $wtxt
}

proc ::JForms::NewBoolean {token elem} {
    variable $token
    upvar 0 $token state
    
    array set attr [wrapper::getattrlist $elem]
    set var $attr(var)
    if {[info exists attr(label)]} {
	set str $attr(label)
    } else {
	set str [GetLabelFromVar $var]
    }
    if {[AnyRequired $token $elem]} {
	append str " (*)"
    }    
    set defValue [GetDefaultValue $elem 0]
    if {![regexp {(0|1)} $defValue]} { 
	set defValue 0
    }
    set state(def,$var)  $defValue
    set state(var,$var)  $defValue
    set state(type,$var) $attr(type)

    set w $state(w)
    set wch $w.c[incr state(i)]

    ttk::checkbutton $wch -text $str -variable $token\(var,$var)
    grid  $wch  -sticky w

    # Unused by ttk::checkbutton
    #lappend state(wraplengthList) $wch
    BalloonDesc $elem $wch
}

proc ::JForms::NewFixed {token elem} {
    variable $token
    upvar 0 $token state
    
    # XEP-0004: (if it is "fixed", it MAY possess a 'var' attribute) 
    set w $state(w)
    foreach value [GetDefaultList $elem] {
	set wlab $w.l[incr state(i)]    
	ttk::label $wlab -text $value -justify left
	grid  $wlab  -sticky w
	if {$state(opt,-width)} {
	    $wlab configure -wraplength $state(opt,-width)
	}
	lappend state(wraplengthList) $wlab
	BalloonDesc $elem $wlab
    }
}

proc ::JForms::NewHidden {token elem} {
    variable $token
    upvar 0 $token state
    
    array set attr [wrapper::getattrlist $elem]
    set defValue [GetDefaultValue $elem]
    set var $attr(var)
    
    set state(def,$var)  $defValue
    set state(var,$var)  $defValue
    set state(type,$var) $attr(type)
}

proc ::JForms::BalloonDesc {fieldE args} {
    
    set descE [wrapper::getfirstchildwithtag $fieldE desc]
    if {[llength $descE]} {
	foreach w $args {
	    ::balloonhelp::balloonforwindow $w [wrapper::getcdata $descE]
	}
    }
}

proc ::JForms::AnyRequired {token elem} {
    variable $token
    upvar 0 $token state
    
    set requiredElem [wrapper::getfirstchildwithtag $elem "required"]
    if {[llength $requiredElem]} {
	set state(anyrequired) 1
	return 1
    } else {
	return 0
    }
}

proc ::JForms::GetDefaultValue {elem {defValue ""}} {    
    set valueE [wrapper::getfirstchildwithtag $elem "value"]
    if {[llength $valueE]} {
	set defValue [wrapper::getcdata $valueE]
    }
    return $defValue
}

proc ::JForms::GetDefaultList {elem} {
    set defValueList [list]
    foreach c [wrapper::getchildswithtag $elem "value"] {
	lappend defValueList [wrapper::getcdata $c]
    }
    return $defValueList
}

proc ::JForms::GetLabelFromVar {var} {    
    return [string totitle [string map {_ " "} $var]]
}

# JForms::ParseMultiOpts --
# 
#       Returns a list {defaultList labelList}

proc ::JForms::ParseMultiOpts {token elem var} {
    variable $token
    upvar 0 $token state
    
    # Build menu list and mapping from label to value.
    set defaultL [list]
    set labelL   [list]
    foreach c [wrapper::getchildren $elem] {
	
	switch -- [wrapper::gettag $c] {
	    value {
		lappend defaultL [wrapper::getcdata $c]				    
	    }
	    option {
		set label [wrapper::getattribute $c "label"]
		set valueE [wrapper::getfirstchildwithtag $c "value"]
		set val $label
		if {[llength $valueE]} {
		    set val [wrapper::getcdata $valueE]
		}
		set state(label2value,$var,$label) $val
		set state(value2label,$var,$val)   $label
		lappend labelL $label
	    }
	}
    }
    return [list $defaultL $labelL]
}

proc ::JForms::GetXDataForm {token} {
    variable $token
    upvar 0 $token state
    
    set xmllist [list]

    foreach {key val} [array get state var,*] {
	set var [string map {var, ""} $key]
	set type $state(type,$var)
	set subtags [list]
	
	switch -- $type {
	    text-single - text-private - boolean {
		set str [string trim $state(var,$var)]
		if {$str ne ""} {
		    set subtags [list [wrapper::createtag value -chdata $str]]
		}
	    }
	    text-multi {
		set subtags [GetXDataTextMultiForm $token $var]
	    }
	    list-single {

		# Need to map from label to value!
		set label $state(label,$var)
		set value $state(label2value,$var,$label)
		set subtags [list [wrapper::createtag value -chdata $value]]
	    }
	    list-multi {
		set subtags [GetXDataListMultiForm $token $var]
	    }
	    jid-single {

		# Perhaps we should verify that this is a proper jid
		# before returning form.
		set subtags [list [wrapper::createtag value \
		  -chdata $state(var,$var)]]
	    }
	    jid-multi {

		# Perhaps we should verify that this is a proper jid
		# before returning form.
		set subtags [GetXDataTextMultiForm $token $var]
	    }
	    hidden {
		
		# The field is not shown to the entity providing information,
		# but instead is returned with the form. 
		set subtags [list [wrapper::createtag value \
		  -chdata $state(var,$var)]]
	    }
	    default {
		# empty
	    }
	}
	if {$subtags != {}} {
	    lappend xmllist [wrapper::createtag field -attrlist [list type $type var $var] \
	      -subtags $subtags]
	}
    }
    
    # Note the list structure.
    return [list [wrapper::createtag x  \
      -attrlist {xmlns jabber:x:data type submit} -subtags $xmllist]]
}

# JForms::GetXDataAsText --
# 
#       A method to translate a form into plain text suitable to save to file
#       or to print.

proc ::JForms::GetXDataAsText {token} {
    variable $token
    upvar 0 $token state
    
    set xdataE $state(xdataE)
    set xmllist [wrapper::getchildren $xdataE]
    set text ""
    
    # Handle tag by tag.
    foreach elem $xmllist {

	set tag [wrapper::gettag $elem]
		
	switch -exact -- $tag {	    
	    title - instructions {
		append text [wrapper::getcdata $elem]
		append text \n
	    }
	    field {
		set attr(type) "text-single"
		array set attr [wrapper::getattrlist $elem]
		set var $attr(var)
		if {[info exists attr(label)]} {
		    set str $attr(label)
		} else {
		    set str [GetLabelFromVar $var]
		}
		
		
		switch -exact -- $attr(type) {
		    text-single - text-private - boolean - jid-single {
			append text $str
			append text ": "
			append text $state(var,$var)
			append text \n
		    }
		    text-multi - jid-multi {
			set wtxt $state(widget,$var)
			append text $str
			append text ":"
			append text \n
			append text [$wtxt get 1.0 end]
			append text \n
		    }
		    list-single {
			append text $str
			append text ": "
			append text $state(label,$var)
			append text \n
		    }
		    list-multi {
			set wtxt $state(widget,$var)
			append text $str
			append text ":"
			append text \n
			set wlb $state(widget,$var)
			foreach ind [$wlb curselection] {
			    append text [$wlb get $ind]
			    append text \n
			}
			append text \n
		    }
		    default {
			# empty
		    }
		}
	    }
	}
    }
    return $text
}

proc ::JForms::GetXDataTextMultiForm {token var} {
    variable $token
    upvar 0 $token state
    
    # Each text line as a separate value-element.
    set subtags {}
    set wtxt $state(widget,$var)
    set txt [$wtxt get 1.0 end]
    set txt [string trim $txt]
    set valueList [split $txt "\n"]
    foreach value $valueList {
	lappend subtags [wrapper::createtag value -chdata $value]
    }
    return $subtags
}

proc ::JForms::GetXDataListMultiForm {token var} {
    variable $token
    upvar 0 $token state
    
    # Each selected list entry as a separate value-element.
    set subtags {}
    set wlb $state(widget,$var)
    set labelList {}
    foreach ind [$wlb curselection] {
	lappend labelList [$wlb get $ind]
    }

    # Need to map from label to value!
    foreach label $labelList {
	if {[info exists state(label2value,$var,$label)]} {
	    lappend subtags [wrapper::createtag value \
	      -chdata $state(label2value,$var,$label)]
	}
    }
    return $subtags
}

# JForms::ResultList
#
#       Returns a list describing, for instance, a search result.
#
# Arguments:
#       
# Results:
#       a hierarchical list: {{jid1 val1 val2 ...} {jid2 val1 val2 ...} ... }

proc ::JForms::ResultList {token queryE} {
    variable $token
    upvar 0 $token state
        
    if {$state(xdata)} {
	return [ResultXDataList $token $queryE]	
    } else {
	return [ResultPlainList $token $queryE]	
    }
}

proc ::JForms::ResultPlainList {token queryE} {
    variable $token
    upvar 0 $token state
        
    set res [list]
    
    # Loop through the items. Make sure we get them in the order specified 
    # in 'reported'.
    # We are not guaranteed to receive every field.
    foreach item [wrapper::getchildren $queryE] {
	unset -nocomplain attrArr itemArr
	array set attr [wrapper::getattrlist $item]
	set itemArr(jid) $attr(jid)
	foreach thing [wrapper::getchildren $item] {
	    set tag [wrapper::gettag $thing]
	    set val [wrapper::getcdata $thing]
	    set itemArr($tag) $val
	}
	
	# Sort in order of <reported>.
	if {[info exists state(reported)]} {
	    set row {}
	    foreach {var label} $state(reported) { 
		if {[info exists itemArr($var)]} {
		    lappend row $itemArr($var)
		} else {
		    lappend row {}
		}
	    } 
	    lappend res $row
	} else {
	    # @@@
	}
    }
    return $res
}

# JForms::ResultXDataList --
# 
#       See JForms::ResultList.
#       
#       Complete xml: 
#           <query ...>
#               <x xmlns='jabber:x:data' ...>
#       
#       or: 
#          <query xmlns='jabber:iq:search'><truncated/>
#               <x type='result' xmlns='jabber:x:data'>

proc ::JForms::ResultXDataList {token queryE} {
    variable $token
    upvar 0 $token state
    
    set res [list]
    set xElem [wrapper::getfirstchild $queryE x "jabber:x:data"]
    if {$xElem == {}} {
	return
    }
        
    # Loop through the items. The first one must be a <reported> element.
    # We are not guaranteed to receive every field.
    
    foreach item [wrapper::getchildren $xElem] {
	
	switch -- [wrapper::gettag $item] {
	    title {
		#
	    }
	    reported {
		set state(reported) {}
		foreach field [wrapper::getchildren $item] {
		    unset -nocomplain attr
		    array set attr [wrapper::getattrlist $field]
		    if {[info exists attr(label)]} {
			set str $attr(label)
		    } else {
			set str [GetLabelFromVar $attr(var)]
		    }
		    lappend state(reported) $attr(var) $str
		}
	    }
	    item {
		foreach field [wrapper::getchildren $item] {
		    unset -nocomplain attr
		    array set attr [wrapper::getattrlist $field]
		    set valueElem [lindex [wrapper::getchildren $field] 0]
		    if {[wrapper::gettag $valueElem] ne "value"} {
			continue
		    }		
		    set itemArr($attr(var)) [wrapper::getcdata $valueElem]		
		}
		
		# Sort in order of <reported>.
		if {[info exists state(reported)]} {
		    set row {}
		    foreach {var label} $state(reported) {
			if {[info exists itemArr($var)]} {
			    lappend row $itemArr($var)
			} else {
			    lappend row {}
			}
		    }
		    lappend res $row
		} else {
		    # @@@
		}
	    }
	}
    }
    return $res
}

# JForms::SetState --
# 
#       Used to put the form in a disabled state.

proc ::JForms::SetState {token _state} {
    variable $token
    upvar 0 $token state
    
    set w $state(w)
    SetStateRecursive $state(w) $_state
}

proc ::JForms::SetStateRecursive {win _state} {
    foreach w [winfo children $win] {
	SetStateRecursive $w $_state
    }
    if {[winfo class $win] eq "TEntry"} {
	$win state $_state
    }
}

proc ::JForms::GetReported {token} {
    variable $token
    upvar 0 $token state

    if {[info exists state(reported)]} {
	return $state(reported)
    } else {
	return
    }
}

proc ::JForms::GetStateValue {token key} {
    variable $token
    upvar 0 $token state

    return $state($key)
}

proc ::JForms::Free {token} {
    
    unset -nocomplain $token
}

#-------------------------------------------------------------------------------
