#  JForms.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements dynamic forms GUI. 
#      If an 'jabber:x:data' namespaced element is given, the methods
#      involved with this method are used. Else straight (simple) model.
#      
#  Copyright (c) 2002-2005  Mats Bengtsson
#
# $Id: JForms.tcl,v 1.24 2006-05-17 06:35:02 matben Exp $
# 
#      Updated to version 2.5 of JEP-0004
#  
#-------------------------------------------------------------------------------

package require wrapper

package provide JForms 1.0

namespace eval ::JForms:: {
    
    # Public functions:
    # 
    #   ::JForms::Build w queryElem ?-key value ...?
    #   ::JForms::GetXML token
    #   ::JForms::GetState token key
    
    # Internal state:
    # 
    #   state(reported)  : 
    #       list of pairs 'varName label' for each search entry received.
 
    
    # Unique id used as a token.
    variable uid 0

    # Spacer for some labels.
    variable topPadding {0 2 0 0}
    
    variable help
    array set help {
	username        "Account name associated with the user"
	nick            "Familiar name of the user"
	password        "Password or secret for the user"
	name            "Full name of the user"
	first           "First name or given name of the user"
	last            "Last name, surname, or family name of the user"
	email           "Email address of the user"
	address         "Street portion of a physical or mailing address"
	city            "Locality portion of a physical or mailing address"
	state           "Region portion of a physical or mailing address"
	zip             "Postal code portion of a physical or mailing address"
	phone           "Telephone number of the user"
	url             "URL to web page describing the user"
	date            "Some date (e.g., birth date, hire date, sign-up date)"
    }
}

# JForms::Build --
# 
#       Master function to build a form frame from a query-element.
#       
# Arguments:
#       w           the megawidget form.
#       queryElem   query-element
#       args:       -tilestyle (|Small|Mixed)
#                   -xdata (0|1)
#                   -width
#       
# Results:
#       token

proc ::JForms::Build {w queryElem args} {
    variable uid
    upvar ::Jabber::jprefs jprefs

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
    
    set xmllist [wrapper::getchildren $queryElem]
    set queryXmlns [wrapper::getattribute $queryElem xmlns]

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
	    set xdataElem [lindex $clist 0]
	    set state(xdataElem) $xdataElem
	}
    }
    set state(xdata) $xdata

    set state(textLabelStyle) TLabel
    if {$opts(-tilestyle) eq "Small"} {
	set wp [string trim $w .]	
	set state(textLabelStyle) Small.TLabel
	option add *$wp*TLabel.style        Small.TLabel        widgetDefault
	option add *$wp*TLabelframe.style   Small.TLabelframe   widgetDefault
	option add *$wp*TButton.style       Small.TButton       widgetDefault
	option add *$wp*TMenubutton.style   Small.TMenubutton   widgetDefault
	option add *$wp*TRadiobutton.style  Small.TRadiobutton  widgetDefault
	option add *$wp*TCheckbutton.style  Small.TCheckbutton  widgetDefault
	option add *$wp*TEntry.style        Small.TEntry        widgetDefault
	option add *$wp*TEntry.font         CociSmallFont       60
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
    variable help
    
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
	  -text [mc jaregalready] -justify left
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
	if {[info exists help($tag)]} {
	    ::balloonhelp::balloonforwindow $wlab $help($tag)
	    ::balloonhelp::balloonforwindow $went $help($tag)
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

proc ::JForms::BuildXDataFrame {token} {
    variable $token
    upvar 0 $token state

    set w $state(w)
    ttk::frame $w

    set xdataElem $state(xdataElem)
    set xmllist [wrapper::getchildren $xdataElem]

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
	}
    } 
    if {$state(anyrequired)} {
	set wlab $w.l[incr state(i)]
	ttk::label $wlab -text [mc jaxformreq]
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
    
    set wlab $state(w).l[incr state(i)]
    set cdata [wrapper::getcdata $elem]
    ttk::label $wlab -style $state(textLabelStyle) -text $cdata -justify left
    grid  $wlab  -sticky w -pady 2

    if {$state(opt,-width)} {
	$wlab configure -wraplength $state(opt,-width)
    }
    lappend state(wraplengthList) $wlab
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
    if {$labelList == {}} {
	
	# 1) No <option/> elements. Weird!
	set labelList "None"
	set defValue  "None"
	set defLabel  "None"
	set state(label2value,$var,$defLabel) $defValue
    } elseif {[llength $defValueList] == 0} {
	
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
    eval {ttk::optionmenu $wpop $token\(label,$var)} $labelList

    grid  $wlab  -sticky w
    grid  $wpop  -sticky w			

    if {$state(opt,-width)} {
	$wlab configure -wraplength $state(opt,-width)
    }
    lappend state(wraplengthList) $wlab
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
    set defLabel $state(value2label,$var,$defValue)
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
}

proc ::JForms::NewFixed {token elem} {
    variable $token
    upvar 0 $token state
    
    set w $state(w)
    foreach value [GetDefaultList $elem] {
	set wlab $w.l[incr state(i)]    
	ttk::label $wlab -text $value -justify left
	grid  $wlab  -sticky w
	if {$state(opt,-width)} {
	    $wlab configure -wraplength $state(opt,-width)
	}
	lappend state(wraplengthList) $wlab
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

proc ::JForms::AnyRequired {token elem} {
    variable $token
    upvar 0 $token state
    
    set requiredElem [wrapper::getfirstchildwithtag $elem "required"]
    if {$requiredElem != {}} {
	set state(anyrequired) 1
	return 1
    } else {
	return 0
    }
}

proc ::JForms::GetDefaultValue {elem {defValue ""}} {
    
    set valueElem [wrapper::getfirstchildwithtag $elem "value"]
    if {$valueElem != {}} {
	set defValue [wrapper::getcdata $valueElem]
    }
    return $defValue
}

proc ::JForms::GetDefaultList {elem} {
    
    set defValueList {}
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
    set defaultList {}
    set labelList  {}
    foreach c [wrapper::getchildren $elem] {
	
	switch -- [wrapper::gettag $c] {
	    value {
		lappend defaultList [wrapper::getcdata $c]				    
	    }
	    option {
		set label [wrapper::getattribute $c "label"]
		set valelem [wrapper::getfirstchildwithtag $c "value"]
		set val $label
		if {$valelem != {}} {
		    set val [wrapper::getcdata $valelem]
		}
		set state(label2value,$var,$label) $val
		set state(value2label,$var,$val)   $label
		lappend labelList $label
	    }
	}
    }
    return [list $defaultList $labelList]
}

proc ::JForms::GetXDataForm {token} {
    variable $token
    upvar 0 $token state
    
    set xmllist {}

    foreach {key val} [array get state var,*] {
	set var [string map {var, ""} $key]
	set type $state(type,$var)
	set subtags {}
	
	switch -- $type {
	    text-single - text-private - boolean {
		set subtags [list [wrapper::createtag value \
		  -chdata $state(var,$var)]]
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

proc ::JForms::ResultList {token queryElem} {
    variable $token
    upvar 0 $token state
        
    if {$state(xdata)} {
	return [ResultXDataList $token $queryElem]	
    } else {
	return [ResultPlainList $token $queryElem]	
    }
}

proc ::JForms::ResultPlainList {token queryElem} {
    variable $token
    upvar 0 $token state
        
    set res {}
    
    # Loop through the items. Make sure we get them in the order specified 
    # in 'reported'.
    # We are not guaranteed to receive every field.
    foreach item [wrapper::getchildren $queryElem] {
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

proc ::JForms::ResultXDataList {token queryElem} {
    variable $token
    upvar 0 $token state
    
    set res {}
    set xElem [wrapper::getfirstchild $queryElem x "jabber:x:data"]
    if {$xElem == {}} {
	return -code error "Did not identify the <x> element in search result"
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

proc ::JForms::GetReported {token} {
    variable $token
    upvar 0 $token state

    return $state(reported)
}

proc ::JForms::GetState {token key} {
    variable $token
    upvar 0 $token state

    return $state($key)
}

proc ::JForms::Free {token} {
    
    unset -nocomplain $token
}


# Test code:
if {0} {
    
    # Plain:
    set xmllist {query {xmlns jabber:iq:register} 0 {} {
	{password {} 1 {} {}} 
	{password {} 1 {} {}} 
	{instructions {} 0 {Choose a username and password to register with this server. This is some extra text just to test the width option.} {}} 
	{name {} 1 {} {}} 
	{email {} 1 {} {}} {username {} 1 {} {}}}
    }
    set w .t1
    toplevel $w
    ::JForms::Build $w.f $xmllist -tilestyle Mixed -width 180
    pack $w.f -fill both -expand 1 

    set w .t6
    set width 200
    toplevel $w
    ::UI::ScrollFrame $w.f -padding {8 12} -propagate 0 -width $width
    set fr [::UI::ScrollFrameInterior $w.f]
    ::JForms::Build $fr.f $xmllist -tilestyle Small -width [expr $width-2*12-16]
    pack $w.f -fill both -expand 1
    pack $fr.f -fill both -expand 1
    
    set xmllist {query {xmlns jabber:iq:conference} 0 {} {
	{name {} 0 Girls {}} {nick {} 1 {} {}}}
    }
    set w .t7
    set width 200
    toplevel $w
    ::UI::ScrollFrame $w.f -padding {8 12} -propagate 0 -width $width
    set fr [::UI::ScrollFrameInterior $w.f]
    ::JForms::Build $fr.f $xmllist -tilestyle Small -width [expr $width-2*12-16]
    pack $w.f -fill both -expand 1
    pack $fr.f -fill both -expand 1

    # xdata:                                                                                                                                        
    set xmllist {
	query {xmlns http://jabber.org/protocol/muc#owner} 0 {} {
	    {instructions {} 0 {You need an x:data capable client to configure room} {}} 
	    {x {xmlns jabber:x:data} 0 {} {
		{title {} 0 {Configuratie voor junk@conference.l4l.be} {}}
		{field {label Kamernaam var title type text-single} 0 {} {{value {} 0 {} {}}}} 
		{field {label {Gebruikers toestaan het onderwerp te wijzigen} var allow_change_subj type boolean} 0 {} {{value {} 0 1 {}}}} 
		{field {label {Gebruikers toestaan om andere gebruikers te query-en} var allow_query_users type boolean} 0 {} {{value {} 0 1 {}}}} 
		{field {label {Gebruikers toestaan om privéberichten te versturen} var allow_private_messages type boolean} 0 {} {{value {} 0 1 {}}}} 
		{field {label {Kamer doorzoekbaar maken} var public type boolean} 0 {} {{value {} 0 1 {}}}} 
		{field {label {Deelnemerslijst publiek maken} var public_list type boolean} 0 {} {{value {} 0 1 {}}}} 
		{field {label {Kamer blijvend maken} var persistent type boolean} 0 {} {{value {} 0 0 {}}}} 
		{field {label {Kamer moderated maken} var moderated type boolean} 0 {} {{value {} 0 0 {}}}} 
		{field {label {Gebruikers standaard als leden instellen} var members_by_default type boolean} 0 {} {{value {} 0 1 {}}}} 
		{field {label {Kamer enkel toegankelijk maken voor leden} var members_only type boolean} 0 {} {{value {} 0 0 {}}}} 
		{field {label {Gebruikers toestaan om uitnodigingen te sturen} var allow_user_invites type boolean} 0 {} {{value {} 0 0 {}}}} 
		{field {label {Kamer beveiligen met een wachtwoord} var password_protected type boolean} 0 {} {{value {} 0 0 {}}}} 
		{field {label Wachtwoord var password type text-private} 0 {} {{value {} 0 {} {}}}} 
		{field {label {Kamer anoniem maken} var anonymous type boolean} 0 {} {{value {} 0 1 {}}}} 
		{field {label {Logs inschakelen} var logging type boolean} 0 {} {{value {} 0 0 {}}}}}
	    }
	}
    }
    set w .t2
    toplevel $w
    ::JForms::Build $w.f $xmllist -tilestyle Mixed
    pack $w.f -fill both -expand 1 
    
    set xmllist {
	query {xmlns jabber:iq:search} 0 {} {
	    {instructions {} 0 {U hebt een x:data compatibele client nodig om te kunnen zoeken} {}} 
	    {x {type form xmlns jabber:x:data} 0 {} {
		{title {} 0 {Gebruikers zoeken in vjud.l4l.be} {}}
		{instructions {} 0 {Vul de velden in om te zoeken naar Jabbergebruikers op deze server} {}} 
		{field {label Gebruiker var user type text-single} 1 {} {}}
		{field {label {Volledige naam} var fn type text-single} 1 {} {}} 
		{field {label Naam var given type text-single} 1 {} {}} 
		{field {label Tussennaam var middle type text-single} 1 {} {}} 
		{field {label Achternaam var family type text-single} 1 {} {}} 
		{field {label Bijnaam var nickname type text-single} 1 {} {}} 
		{field {label Geboortedatum var bday type text-single} 1 {} {}} 
		{field {label Land var ctry type text-single} 1 {} {}} 
		{field {label Plaats var locality type text-single} 1 {} {}} 
		{field {label E-mail var email type text-single} 1 {} {}} 
		{field {label Organisatie var orgname type text-single} 1 {} {}} 
		{field {label Afdeling var orgunit type text-single} 1 {} {}}
		{field {label JIDs var jmulti type jid-multi} 1 {} {}}
	    }
	    }
	}
    }
    set w .t3
    toplevel $w
    ::JForms::Build $w.f $xmllist -tilestyle Mixed -width 180
    pack $w.f -fill both -expand 1

    set w .t4
    toplevel $w
    ::UI::ScrollFrame $w.f -padding {8 12}
    set fr [::UI::ScrollFrameInterior $w.f]
    ::JForms::Build $fr.f $xmllist -tilestyle Small -width 160
    pack $w.f -fill both -expand 1
    pack $fr.f -fill both -expand 1

    set w .t5
    toplevel $w
    ::UI::ScrollFrame $w.f -padding {8 12} -propagate 0
    set fr [::UI::ScrollFrameInterior $w.f]
    ::JForms::Build $fr.f $xmllist -tilestyle Small -width 180
    pack $w.f -fill both -expand 1
    pack $fr.f -fill both -expand 1

    set result {
	query {xmlns jabber:iq:search} 0 {} {
	    {x {type result xmlns jabber:x:data} 0 {} {
		{title {} 0 {Zoekresultaten van vjud.l4l.be} {}} 
		{reported {} 0 {} {
		    {field {label JID var jid} 1 {} {}} 
		    {field {label {Volledige naam} var fn} 1 {} {}} 
		    {field {label Naam var given} 1 {} {}} 
		    {field {label Tussennaam var middle} 1 {} {}} 
		    {field {label Achternaam var family} 1 {} {}} 
		    {field {label Bijnaam var nickname} 1 {} {}} 
		    {field {label Geboortedatum var bday} 1 {} {}} 
		    {field {label Land var ctry} 1 {} {}} 
		    {field {label Plaats var locality} 1 {} {}} 
		    {field {label E-mail var email} 1 {} {}} 
		    {field {label Organisatie var orgname} 1 {} {}} 
		    {field {label Afdeling var orgunit} 1 {} {}}}
		} 
		{item {} 0 {} {
		    {field {var jid} 0 {} {{value {} 0 marilu@l4l.be {}}}} 
		    {field {var fn} 0 {} {{value {} 0 {Mats Bengtsson} {}}}} 
		    {field {var family} 0 {} {{value {} 0 Bengtsson {}}}} 
		    {field {var given} 0 {} {{value {} 0 Mats {}}}} 
		    {field {var middle} 0 {} {{value {} 0 G {}}}} 
		    {field {var nickname} 0 {} {{value {} 0 {} {}}}} 
		    {field {var bday} 0 {} {{value {} 0 {} {}}}} 
		    {field {var ctry} 0 {} {{value {} 0 {} {}}}} 
		    {field {var locality} 0 {} {{value {} 0 {} {}}}} 
		    {field {var email} 0 {} {{value {} 0 matben@users.sf.net {}}}} 
		    {field {var orgname} 0 {} {{value {} 0 {} {}}}} 
		    {field {var orgunit} 0 {} {{value {} 0 {} {}}}}}}
		}
	    }
	}
    }

}

#-------------------------------------------------------------------------------
