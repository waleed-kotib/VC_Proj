#  JForms.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements dynamic forms GUI. 
#      If an 'jabber:x:data' namespaced element is given, the methods
#      involved with this method are used. Else straight (simple) model.
#      
#  Copyright (c) 2002-2005  Mats Bengtsson
#
# $Id: JForms.tcl,v 1.19 2005-02-14 13:48:38 matben Exp $
# 
#      Updated to version 2.1 of JEP-0004
#  
#-------------------------------------------------------------------------------

package require wrapper

package provide JForms 1.0

# Just make sure that we have the parent namespace here.
namespace eval ::Jabber:: { }

namespace eval ::Jabber::Forms:: {

    # Unique id used as a token.
    variable uid 0

    # Storage for content in entries etc.
    variable cache
    
    # Mappings from $w to $id etc. locals($w,id), locals($w,type)
    variable locals
    
    # List of pairs 'varName label' for each search entry received.
    variable reported
    
    variable pady
    switch -- $::this(platform) {
	macintosh {
	    set pady 2
	}
	default {
	    set pady 0
	}
    }
}

# Jabber::Forms::Build --
#
#       Builds a megawidget form. Dispatches to the appropriate proc
#       depending on if we've got an 'jabber:x:data' namespace or not.

proc ::Jabber::Forms::Build {w xmllist args} {
    
    upvar ::Jabber::jprefs jprefs
    variable uid
    variable locals
    variable reported
    
    incr uid
    set argsArr(-template) ""
    array set argsArr $args
    set locals($w,id) $uid
    set locals($w,template) $argsArr(-template)
    set locals($w,xmllist) $xmllist
    set reported($uid) {}
    
    # We must figure out if the service supports the jabber:x:data stuff.
    set hasXDataForm 0
    set locals($w,type) "simple"

    if {$jprefs(useXDataSearch)} {
	set clist [wrapper::getnamespacefromchilds $xmllist x "jabber:x:data"]
	if {$clist != {}} {
	    set hasXDataForm 1
	    set xmlXDataElem [lindex $clist 0]
	}
    }
    if {$hasXDataForm} {
	set locals($w,type) "xdata"
	eval {::Jabber::Forms::BuildXData $w $xmlXDataElem} $args
    } else {
	::Jabber::Forms::BuildSimple $w $xmllist $argsArr(-template)
    }
    bind $w <Destroy> [list [namespace current]::Free $w]
    
    return $w
}

# Jabber::Forms::BuildScrollForm --
# 
#       Builds an empty scrollable frame.

proc ::Jabber::Forms::BuildScrollForm {w args} {

    namespace eval ::${w}:: { }
    upvar ::${w}::opts opts
    
    array set opts {
	-height     10
	-ipadx      4
	-ipady      4
	-width      10
    }
    array set opts $args
    set opts(wboxwidth) [expr $opts(-width) - 2 * $opts(-ipadx)]
    
    frame $w -bd 1 -relief sunken
    set wcan $w.can
    set wsc $w.ysc
    set wbox $w.can.f
    canvas $wcan -yscrollcommand  \
      [list ::UI::ScrollSet $wsc [list grid $wsc -row 0 -column 1 -sticky ns]] \
      -width $opts(-width) -height $opts(-height) -bd 0 -highlightthickness 0
    scrollbar $wsc -orient vertical -command [list $wcan yview]			
    
    grid $wcan -column 0 -row 0 -sticky news
    grid $wsc  -column 1 -row 0 -sticky ns
    grid columnconfigure $w 0 -weight 1
    grid rowconfigure    $w 0 -weight 1
    
    return $w
}

# Jabber::Forms::FillScrollForm --
# 
#       Fills the form defined in 'xmllist' into the scroll frame.

proc ::Jabber::Forms::FillScrollForm {w xmllist args} {
    upvar ::${w}::opts opts

    set wcan $w.can
    set wbox $w.can.f
    catch {destroy $wbox}
    eval {Build $wbox $xmllist -width $opts(wboxwidth)} $args
    
    $wcan create window $opts(-ipadx) $opts(-ipady) -anchor nw -window $wbox
    
    #
    tkwait visibility $wbox
    set width [winfo reqwidth $wbox]
    set height [winfo reqheight $wbox]
    set canscrollwidth [expr $width + 2 * $opts(-ipadx)]
    set canscrollheight [expr $height + 2 * $opts(-ipady)]
    $wcan config -scrollregion [list 0 0 $canscrollwidth $canscrollheight]
    $wcan config -width $opts(-width) -height $opts(-height)
    ::Jabber::Forms::ScrollConfig $w

    bind $wcan <Configure> [list [namespace current]::ScrollConfig $w]
}


proc ::Jabber::Forms::GetScrollForm {w} {
    upvar ::${w}::opts opts

    set wbox $w.can.f
    return [::Jabber::Forms::GetXML $wbox]
}

proc ::Jabber::Forms::ScrollConfig {w} {
    upvar ::${w}::opts opts

    set wcan $w.can
    set wbox $w.can.f
    set width [winfo width $wcan]
    set height [winfo height $wcan]
    set opts(wboxwidth) [expr $width - 2 * $opts(-ipadx)]
    
    #puts "ScrollConfig: winfo width/height=$width/$height, wboxwidth=$opts(wboxwidth)"
    
    $wbox.spacer configure -width $opts(wboxwidth)
    
    foreach c [winfo children $wbox] {
	if {([winfo class $c] == "Label") && ([$c cget -wraplength] > 0)} {
	    $c configure -wraplength [expr $opts(wboxwidth) - 12]
	}
    }
}

proc ::Jabber::Forms::GetReported {w} {

    variable locals
    variable reported
    
    if {![info exists locals($w,id)]} {
	return -code error "The widget \"$w\" is not a form"
    }
    set id $locals($w,id)
    return $reported($id)
}

# Jabber::Forms::GetXML --
#
#       Get xml from form.
#
# Arguments:
#       w           the form frame widget.
#       
# Results:
#       a list of elements if simple, else starting with the x-element.

proc ::Jabber::Forms::GetXML {w} {
    
    variable locals

    if {![info exists locals($w,id)]} {
	return -code error "The widget \"$w\" is not a form"
    }

    switch -- $locals($w,type) {
	simple {
	    set xmlForm [GetXMLSimple $w $locals($w,xmllist) $locals($w,template)]
	}
	xdata {
	    set xmlForm [GetXMLXData $w]
	}
	default {
	    return -code error "Type \"$locals($w,type)\" is not a valid form type"
	}
    }
    return $xmlForm
}

proc ::Jabber::Forms::Free {w} {
    
    variable locals
    variable reported
    variable cache
    variable wpaths

    set id $locals($w,id)
    array unset cache "$id,*"
    array unset wpaths "$id,*"
    array unset locals "$w,*"
    unset -nocomplain reported($id)
}

# Jabber::Forms::BuildSimple --
#
#       Utility to make a label-entry box automatically from a xml list.
#       Stored as cache($id,$key) where key is tag1, tag1_tag2, or
#       tag1#3.
#       
# Arguments:
#       w           The frame to be created.
#       xmllist     Hierarchical xml list.
#       template    (optional) Tells us the context for this call.
#                   "room", "register",...
#       
# Results:
#       w, the frame that must be packed.

proc ::Jabber::Forms::BuildSimple {w xmllist {template ""}} {
    variable cache
    variable reported
    variable locals

    if {![info exists locals($w,id)]} {
	return -code error "The widget \"$w\" is not a form"
    }
    array set argsArr {
	-width     200
    }
    array set argsArr {}
    set id $locals($w,id)
    set i 0
    set reported($id) {jid {Jid (user)}}
    frame $w
    
    # Handle tag by tag.
    foreach child $xmllist {
	set tag [wrapper::gettag $child]
	FillInBoxOneTag $w $child {} i $template
	incr i
    }
    
    # Spacer for <Configure> bind'ing.
    frame $w.spacer 
    grid $w.spacer -columnspan 2
    grid columnconfigure $w 1 -weight 1
    
    return $w
}

# Jabber::Forms::FillInBoxOneTag --
#
#       Just a helper proc to 'BuildSimple'.
#       Makes the right row or rows for this specific tag,
#       or calls itself rcursively.

proc ::Jabber::Forms::FillInBoxOneTag {w child parentTag iName {template ""}} {
    
    variable locals
    variable reported
    variable cache
    
    # Call by name for the row counter.
    upvar $iName i
    
    set id $locals($w,id)
    set tag [lindex $child 0]
    set cdata [lindex $child 3]
    set subchildren [lindex $child 4]
    set key ${parentTag}${tag}
    
    set fontSB [option get . fontSmallBold {}]
    set width 200
    
    if {$subchildren == ""} {
	set varName [namespace current]::cache($id,$key)

	# Collect 'reported' keys.
	if {($tag != "instructions") && ($tag != "key") && ($tag != "x")} {
	    lappend reported($id) $tag $tag
	}
	
	# Room template.
	if {$template == "room"} {
	    if {($tag == "nick") || ($tag == "nickname")} {
		foreach num {1 2 3} {
		    label $w.ln$num -text "${tag} ${num}:" -font $fontSB
		    entry $w.en$num    \
		      -textvariable [namespace current]::cache($id,$key#${num})
		    grid $w.ln$num -column 0 -row $i -sticky e
		    grid $w.en$num -column 1 -row $i -sticky ew
		    incr i
		}
	    } elseif {$tag == "privacy"} {
		label $w.l$i -text "Privacy if nickname" -font $fontSB
		grid $w.l$i -column 0 -row $i -columnspan 2 -sticky w
		incr i
	    } elseif {$tag == "ns"} {
		unset -nocomplain attr
		array set attr [lindex $child 1]
		if {[info exists attr(type)]} {
		    set str $attr(type)
		    set txt "[string replace $str 0 0   \
		      [string toupper [string index $str 0]]] namespace:"
		} else {
		    set txt "Namespace:"
		}
		label $w.l$i -text $txt -font $fontSB
		label $w.lns$i -text $cdata 
		grid $w.l$i -column 0 -row $i -sticky e
		grid $w.lns$i -column 1 -row $i -sticky w
		incr i
	    } else {
		label $w.l$i -text ${tag}: -font $fontSB
		entry $w.e$i -textvariable $varName
		grid $w.l$i -column 0 -row $i -sticky e
		grid $w.e$i -column 1 -row $i -sticky ew
		incr i
	    }
	    
	    # Registering & searching.
	} elseif {($template == "register") || ($template == "search")} {
	    if {$tag == "registered"} {
		label $w.l$i -wraplength $width -justify left \
		  -text {You are already registered with this service.\
		  These are your current settings of your login parameters.}
		grid $w.l$i -column 0 -row $i -sticky w -columnspan 2
		incr i
	    } elseif {$tag == "instructions"} {
		label $w.l$i -wraplength $width -justify left -text $cdata
		grid $w.l$i -column 0 -row $i -sticky w -columnspan 2
		incr i
	    } elseif {$tag == "key"} {

		# This is a trick to return the <key>. ???
		set $varName $cdata
	    } else {
		label $w.l$i -text ${tag}: -font $fontSB
		entry $w.e$i -textvariable $varName
		grid $w.l$i -column 0 -row $i -sticky e
		grid $w.e$i -column 1 -row $i -sticky ew
		incr i
	    }
	    
	    # Default.
	} else {
	    label $w.l$i -text ${tag}: -font $fontSB
	    entry $w.e$i -textvariable $varName
	    grid $w.l$i -column 0 -row $i -sticky e
	    grid $w.e$i -column 1 -row $i -sticky ew
	    incr i
	}
    } else {
	
	# Handle subtags by recursive calls.
	# We shouldn't do this if an <x> element (jabber:x:data etc.)
	if {![string equal $tag "x"]} {
	    foreach subchild $subchildren {
		FillInBoxOneTag $w $subchild "${key}_" $iName $template	    
	    }
	}
    }
}

# Jabber::Forms::GetXMLSimple --
#
#       Utility to use the UI box above and construct the xml data from that.
#       The array key of each element is constructed as:
#       rootTag_subTag_subSubTag.
#       
# Arguments:
#       w           The existing frame.
#       
# Results:
#       xml sub elements suitable for the -subtags option of wrapper::createtag.

proc ::Jabber::Forms::GetXMLSimple {w xmllist {template ""}} {
    
    set subelements {}
    foreach child $xmllist {
	set subelements [concat $subelements   \
	  [GetXMLForChild $w $child {} $template]]
    }
    return $subelements
}

# Jabber::Forms::GetXMLForChild --
#
#       Just a helper proc for the above one. If we get a leaf tag, it builds
#       and returns a xml list, if children, it calls itself recursively.
#       Important: it returns a list of one or more children. The extra list
#       structure must be stripped of by 'concat'.

proc ::Jabber::Forms::GetXMLForChild {w child parentTags template} {

    variable cache
    variable locals
    
    set tag [lindex $child 0]
    set subchildren [lindex $child 4]
    set subelements {}
    set id $locals($w,id)
    
    # Leaf tag.
    if {$subchildren == ""} {
	set keyTag [join "$parentTags $tag" _]
	if {$template == "room"} {
	    
	    # Treat certain tags with special rules.
	    if {($tag == "nick") || ($tag == "nickname")} {
		set sub {}
		foreach num {1 2 3} {
		    set val $cache($id,${keyTag}#${num})
		    if {$val != ""} {
			lappend sub [wrapper::createtag $tag -chdata $val]
		    }
		}	 
		if {$sub != ""} {
		    set subelements $sub
		}	    
	    } elseif {[info exists cache($id,$keyTag)]} {
		set val $cache($id,$keyTag)
		if {$val != ""} {
		    set subelements [list [wrapper::createtag $tag -chdata $val]]
		}	    
	    }
	} else {
	    if {[info exists cache($id,$keyTag)]} {
		set val $cache($id,$keyTag)
		if {$val != ""} {
		    set subelements [list [wrapper::createtag $tag -chdata $val]]
		}
	    }	    
	}
    } else {
	
	# Recursively.
	set subsub {}
	set ptaglist [concat $parentTags $tag]
	foreach subchild $subchildren {
	    set subsub [concat $subsub  \
	      [GetXMLForChild $w $subchild $ptaglist $template]]
	}
	set subelements [list [wrapper::createtag $tag -subtags $subsub]]
    }
    return $subelements
}

# Some code for handling the jabber:x:data things ------------------------------

# Jabber::Forms::BuildXData
#
#       Makes a frame from xml jabber:x:data namespaced xml.
#
# Arguments:
#       w           the form frame widget.
#       xml         an xml list starting with the <x> element, namespaced
#                   jabber:x:data
#       
# Results:
#       $w

proc ::Jabber::Forms::BuildXData {w xml args} {
    global  prefs

    variable cache
    variable reported
    variable type
    variable locals

    if {[wrapper::gettag $xml] != "x"} {
	return -code error "Not proper xml data here"
    }
    array set attrArr [wrapper::getattrlist $xml]
    if {![info exists attrArr(xmlns)]} {
	return -code error {Not proper xml data here}
    }
    if {![string equal $attrArr(xmlns) "jabber:x:data"]} {
	return -code error {Expected an "jabber:x:data" element here}
    }
    set width 240
    array set argsArr $args
    if {[info exists argsArr(-width)]} {
	set width $argsArr(-width)
    }
    frame $w
    set id $locals($w,id)   
    set i 0
    
    foreach elem [wrapper::getchildren $xml] {
	set tag [wrapper::gettag $elem]
	
	switch -exact -- $tag {
	    
	    title {
		label $w.m$i -text [wrapper::getcdata $elem] \
		  -anchor c -justify center -wraplength $width
		grid $w.m$i -row $i -column 0 -columnspan 2 -sticky ew
		$w.m$i configure -font [::Utils::FontBold [$w.m$i cget -font]]
		incr i
	    }
	    instructions {
		label $w.m$i -text [wrapper::getcdata $elem] \
		  -anchor w -justify left -wraplength $width
		grid $w.m$i -row $i -column 0 -columnspan 2 -sticky ew
		incr i
	    }
	    field {
		set attr(type) "text-single"
		array set attr [wrapper::getattrlist $elem]
				
		set c [wrapper::getfirstchildwithtag $elem "desc"]
		if {$c != {}} {
		    label $w.m$i -text [wrapper::getcdata $c] \
		      -wraplength $width -justify left
		    grid $w.m$i -row $i -column 0 -columnspan 2 -sticky ew
		    incr i
		}
		#puts "type=$attr(type)"
		
		switch -exact -- $attr(type) {
		    text-single - text-private {
			NewLabelEntry $w $elem $width i			
		    }
		    text-multi {
			NewTextMulti $w $elem $width i
		    }
		    list-single {
			NewListSingle $w $elem $width i
		    }
		    list-multi {
			NewListMulti $w $elem $width i
		    }
		    jid-multi {
			NewJidMulti $w $elem $width i
		    }
		    boolean {
			NewBoolean $w $elem $width i			
		    }
		    fixed {
			NewFixed $w $elem $width i
		    }
		    jid-single {
			NewJidSingle $w $elem $width
		    }
		    hidden {
			NewHidden $w $elem
		    }
		    default {
			NewLabelEntry $w $elem $width i
		    }
		}
	    }
	    reported {
		
		# Seems to be outdated. Reported instead in result element.
		set reported($id) {}
		foreach c [wrapper::getchildren $elem] {
		    unset -nocomplain cattrArr
		    array set cattrArr [wrapper::getattrlist $c]
		    lappend reported($id) $cattrArr(var) $cattrArr(label)
		}
	    }
	}
    }
    grid columnconfigure $w 1 -weight 1

    label $w.l$i -text "Entries labelled in red are required"
    grid  $w.l$i -row $i -column 0 -columnspan 2 -sticky w
    incr i

    # Spacer for <Configure> bind'ing.
    frame $w.spacer
    grid  $w.spacer -row $i -column 0 -columnspan 2
    
    if {0} {
	foreach c [winfo children $w] {
	    puts "[winfo name $c]: [grid info $c]"
	}
    }

    return $w
}

proc ::Jabber::Forms::GetDefaultValue {elem defValue} {
    
    set valueElem [wrapper::getfirstchildwithtag $elem "value"]
    if {$valueElem != {}} {
	set defValue [wrapper::getcdata $valueElem]
    }
    return $defValue
}

proc ::Jabber::Forms::GetDefaultValuesList {elem} {

    set defValueList {}
    foreach c [wrapper::getchildswithtag $elem "value"] {
	lappend defValueList [wrapper::getcdata $c]
    }
    return $defValueList
}

proc ::Jabber::Forms::NewLabelEntry {w elem width iVar} {
    upvar $iVar i
    variable locals
    variable cache
    variable type
    
    set attr(type) "text-single"
    array set attr [wrapper::getattrlist $elem]
    if {[info exists attr(label)]} {
	set label $attr(label)
    } else {
	set label ""
    }
    set defValue [GetDefaultValue $elem ""]
    set id $locals($w,id)   
    set var $attr(var)
    
    set cache($id,$var) $defValue
    set type($id,$var)  $attr(type)
    
    set lopts {}
    set requiredElem [wrapper::getfirstchildwithtag $elem "required"]
    if {$requiredElem != {}} {
	set lopts {-fg red}
    }
    set eopts {}
    if {[string equal $attr(type) "text-private"]} {
	set eopts {-show *}
    }
    
    # If label not too long make it into a single row.
    if {0 && [string length $label] < 24} {
	eval {label $w.l$i -text $label} $lopts
	grid $w.l$i -row $i -column 0 -sticky w
	eval {
	    entry $w.e$i -textvariable [namespace current]::cache($id,$var)
	} $eopts
	grid $w.e$i -row $i -column 1 -sticky ew
	incr i
    } else {
	eval {label $w.l$i -text $label -wraplength $width -justify left} $lopts
	grid $w.l$i -row $i -column 0 -columnspan 2 -sticky w
	incr i
	eval {
	    entry $w.e$i -textvariable [namespace current]::cache($id,$var)
	} $eopts
	grid $w.e$i -row $i -column 0 -columnspan 2 -sticky ew
	incr i
    }
}

proc ::Jabber::Forms::NewBoolean {w elem width iVar} {
    upvar $iVar i
    variable locals
    variable cache
    variable type
    variable pady
    
    array set attr [wrapper::getattrlist $elem]
    if {[info exists attr(label)]} {
	set label $attr(label)
    } else {
	set label ""
    }
    set defValue [GetDefaultValue $elem 0]
    if {![regexp {(0|1)} $defValue]} { 
	set defValue 0
    }
    set id $locals($w,id)   
    set var $attr(var)
    set cache($id,$var) $defValue
    set type($id,$var)  $attr(type)

    set opts {}
    set requiredElem [wrapper::getfirstchildwithtag $elem "required"]
    if {$requiredElem != {}} {
	set opts {-fg red}
    }
    eval {
	checkbutton $w.c$i -text " $label" \
	  -variable [namespace current]::cache($id,$var)  \
	  -wraplength $width -justify left
    } $opts
    grid $w.c$i -row $i -column 0 -columnspan 2 -sticky w -pady $pady
    incr i
}

proc ::Jabber::Forms::NewFixed {w elem width iVar} {
    upvar $iVar i
    
    set defValue [GetDefaultValue $elem ""]
    set lopts {}
    set requiredElem [wrapper::getfirstchildwithtag $elem "required"]
    if {$requiredElem != {}} {
	set lopts {-fg red}
    }
    eval {
	label $w.l$i -text $defValue -justify left -wraplength $width
    } $lopts
    grid $w.l$i -row $i -column 0 -columnspan 2 -sticky w
    incr i
}

proc ::Jabber::Forms::NewListSingle {w elem width iVar} {
    upvar $iVar i
    variable locals
    variable cache
    variable type
    variable optionLabel2Value
    variable optionValue2Label
    
    array set attr [wrapper::getattrlist $elem]
    if {[info exists attr(label)]} {
	set label $attr(label)
    } else {
	set label ""
    }
    
    # Represented by a popup menu button.
    set id $locals($w,id)   
    set var $attr(var)
    set type($id,$var) $attr(type)
    
    # Build menu list and mapping from label to value.
    foreach {defValue optionList} [ParseMultiOpts $id $elem $var] {break}

    set lopts {}
    set requiredElem [wrapper::getfirstchildwithtag $elem "required"]
    if {$requiredElem != {}} {
	set lopts {-fg red}
    }

    if {0 && [string length $label] < 24} {
	eval {label $w.l$i -text $label} $lopts
	grid $w.l$i -row $i -column 0 -sticky w
	
	set wmenu [eval {tk_optionMenu $w.pop$i   \
	  [namespace current]::cache($id,$var)} $optionList]
	$w.pop$i configure -highlightthickness 0 -foreground black
	grid $w.pop$i -row $i -column 1 -sticky w			
	incr i
     } else {
	 eval {label $w.l$i -text $label -wraplength $width -justify left} $lopts
	 grid $w.l$i -row $i -column 0 -columnspan 2 -sticky w
	 incr i
	 
	 set wmenu [eval {tk_optionMenu $w.pop$i   \
	   [namespace current]::cache($id,$var)} $optionList]
	 $w.pop$i configure -highlightthickness 0 -foreground black
	 grid $w.pop$i -row $i -column 0 -columnspan 2 -sticky w			
	 incr i
     }
     if {$defValue == ""} {
	 set cache($id,$var) ""
     } else {
	 set cache($id,$var) $optionValue2Label($id,$var,$defValue)
     }
}

proc ::Jabber::Forms::NewListMulti {w elem width iVar} {
    upvar $iVar i
    variable locals
    variable cache
    variable type
    variable wpaths
    variable optionLabel2Value
    variable optionValue2Label
    
    array set attr [wrapper::getattrlist $elem]
    if {[info exists attr(label)]} {
	set label $attr(label)
    } else {
	set label ""
    }

    # Build menu list and mapping from label to value.
    set id $locals($w,id)   
    set var $attr(var)
    set cache($id,$var) [GetDefaultValuesList $elem]
    set type($id,$var) $attr(type)
    foreach {defValue optionList} [ParseMultiOpts $id $elem $var] {break}
    set cache($id,$var) $optionList

    set lopts {}
    set requiredElem [wrapper::getfirstchildwithtag $elem "required"]
    if {$requiredElem != {}} {
	set lopts {-fg red}
    }

    # Represented by a listbox.
    eval {label $w.l$i -text $label -wraplength $width -justify left} $lopts
    grid $w.l$i -row $i -column 0 -columnspan 2 -sticky w
    incr i
    
    set wfr [frame $w.f$var]
    set wlb $w.f${var}.lb
    set wsc $w.f${var}.sc
    listbox $wlb -height 4 -selectmode multiple  \
      -yscrollcommand [list $wsc set]   \
      -listvar [namespace current]::cache($id,$var)
    scrollbar $wsc -orient vertical -command [list $wlb yview]
    grid $wlb -column 0 -row 0 -sticky news
    grid $wsc -column 1 -row 0 -sticky ns
    grid columnconfigure $wfr 0 -weight 1
    grid rowconfigure    $wfr 0 -weight 1
    
    grid $wfr -row $i -column 0 -columnspan 2 -sticky ew

    set wpaths($id,$var) $wlb

    set ind [lsearch $optionList $optionValue2Label($id,$var,$defValue)]
    if {$ind >= 0} {
	$wlb selection set $ind
    }
    incr i
}   

proc ::Jabber::Forms::NewJidSingle {w elem width iVar} {
    upvar $iVar i
    variable locals
    variable cache
    variable type
    
    array set attr [wrapper::getattrlist $elem]
    if {[info exists attr(label)]} {
	set label $attr(label)
    } else {
	set label ""
    }
    set defValue [GetDefaultValue $elem ""]
    set id $locals($w,id)   
    set var $attr(var)
    set cache($id,$var) $defValue
    set type($id,$var) $attr(type)
    label $w.l$i -text $label -wraplength $width -justify left
    grid $w.l$i -row $i -column 0 -columnspan 2 -sticky w
    incr i
    entry $w.e$i -textvariable [namespace current]::cache($id,$var)
    grid $w.e$i -row $i -column 0 -columnspan 2 -sticky ew
    incr i
}

proc ::Jabber::Forms::NewJidMulti {w elem width iVar} {
    upvar $iVar i
    variable locals
    variable cache
    variable type
    variable wpaths
    
    array set attr [wrapper::getattrlist $elem]
    if {[info exists attr(label)]} {
	set label $attr(label)
    } else {
	set label ""
    }
    set defValue ""
    foreach c [wrapper::getchildswithtag $elem "value"] {
	append defValue " " [wrapper::getcdata $c]
    }
    set id $locals($w,id)   
    set var $attr(var)
    set cache($id,$var) $defValue
    set type($id,$var)  $attr(type)

    set lopts {}
    set requiredElem [wrapper::getfirstchildwithtag $elem "required"]
    if {$requiredElem != {}} {
	set lopts {-fg red}
    }
    
    eval {label $w.l$i -text $label -wraplength $width -justify left} $lopts
    grid $w.l$i -row $i -column 0 -columnspan 2 -sticky w
    incr i

    set wfr [frame $w.f$var]
    set wtxt ${wfr}.txt
    set wsc ${wfr}.sc
    text $wtxt -height 3 -wrap word -yscrollcommand [list $wsc set] -width 20
    scrollbar $wsc -orient vertical -command [list $wtxt yview]
    $wtxt insert end $defValue
    set wpaths($id,$var) $wtxt

    grid $wtxt -column 0 -row 0 -sticky news
    grid $wsc  -column 1 -row 0 -sticky ns
    grid columnconfigure $wfr 0 -weight 1
    grid rowconfigure    $wfr 0 -weight 1
    
    grid $wfr -row $i -column 0 -columnspan 2 -sticky ew
    incr i
}

proc ::Jabber::Forms::NewTextMulti {w elem width iVar} {
    upvar $iVar i
    variable locals
    variable cache
    variable type
    variable wpaths

    array set attr [wrapper::getattrlist $elem]
    if {[info exists attr(label)]} {
	set label $attr(label)
    } else {
	set label ""
    }
    set defValueList {}
    foreach c [wrapper::getchildswithtag $elem "value"] {
	lappend defValueList [wrapper::getcdata $c]
    }
    set id $locals($w,id)   
    set var $attr(var)
    set cache($id,$var) $defValueList
    set type($id,$var)  $attr(type)

    set lopts {}
    set requiredElem [wrapper::getfirstchildwithtag $elem "required"]
    if {$requiredElem != {}} {
	set lopts {-fg red}
    }
    
    eval {label $w.l$i -text $label -wraplength $width -justify left} $lopts
    grid $w.l$i -row $i -column 0 -columnspan 2 -sticky w
    incr i

    set wfr [frame $w.f$var]
    set wtxt ${wfr}.txt
    set wsc ${wfr}.sc
    text $wtxt -height 3 -wrap word -yscrollcommand [list $wsc set] -width 20
    scrollbar $wsc -orient vertical -command [list $wtxt yview]
    foreach str $defValueList {
	$wtxt insert end $str
	$wtxt insert end "\n"
    }
    set wpaths($id,$var) $wtxt

    grid $wtxt -column 0 -row 0 -sticky news
    grid $wsc  -column 1 -row 0 -sticky ns
    grid columnconfigure $wfr 0 -weight 1
    grid rowconfigure    $wfr 0 -weight 1
    
    grid $wfr -row $i -column 0 -columnspan 2 -sticky ew
    incr i
}

proc ::Jabber::Forms::NewHidden {w elem} {
    variable locals
    variable cache
    variable type
    
    array set attr [wrapper::getattrlist $elem]
    set defValue [GetDefaultValue $elem ""]
    set id $locals($w,id)   
    set var $attr(var)
    set type($id,$var)  $attr(type)
    set cache($id,$var) $defValue
}

# Jabber::Forms::ParseMultiOpts --
# 
#       Returns a list {default optionList}

proc ::Jabber::Forms::ParseMultiOpts {id elem var} {
    
    variable optionLabel2Value
    variable optionValue2Label
    
    # Build menu list and mapping from label to value.
    set value ""
    set optionList {}
    foreach c [wrapper::getchildren $elem] {
	
	switch -- [wrapper::gettag $c] {
	    value {
		set value [wrapper::getcdata $c]				    
	    }
	    option {
		set labattr [wrapper::getattribute $c "label"]
		set valelem [lindex [wrapper::getchildswithtag $c "value"] 0]
		set val $labattr
		if {$valelem != {}} {
		    set val [wrapper::getcdata $valelem]
		}
		set optionLabel2Value($id,$var,$labattr) $val
		set optionValue2Label($id,$var,$val)     $labattr
		lappend optionList $labattr
	    }
	}
    }
    #puts "ParseMultiOpts: [list $value $optionList]"
    return [list $value $optionList]
}

# Jabber::Forms::GetXMLXData
#
#       Returns the xml list corresponding to the form with this id.
#
# Arguments:
#       w           the form frame widget.
#       
# Results:
#       the hierarchical xml list starting with the <x> element.

proc ::Jabber::Forms::GetXMLXData {w} {
    
    variable locals
    variable cache
    variable type
    variable wpaths
    variable optionLabel2Value
    
    if {![info exists locals($w,id)]} {
	return -code error "The widget \"$w\" is not a form"
    }
    set id $locals($w,id)
    set xmllist {}
    
    # Submit all nonempty entries.
    foreach key [array names type "$id,*"] {
	regexp "^${id},(.+)$" $key match var
	set subtags {}
	
	#puts "type=$type($key), var=$var"
	
	switch -- $type($key) {
	    text-single - text-private - boolean - jid-single {
		set value $cache($id,$var)
		set subtags [list [wrapper::createtag value -chdata $value]]
	    }
	    list-single {
		
		# Need to map from label to value!
		set label $cache($id,$var)
		set value $optionLabel2Value($id,$var,$label)
		set subtags [list [wrapper::createtag value -chdata $value]]
	    }
	    list-multi {
		set wlb $wpaths($id,$var)
		set selIndList [$wlb curselection]
		set valueList {}
		foreach ind $selIndList {
		    lappend valueList [$wlb get $ind]
		}
		if {[llength $valueList] == 0} {
		    continue
		}
		foreach value $valueList {
		    lappend subtags [wrapper::createtag value -chdata $value]
		}
	    }
	    jid-multi {
		set wtxt $wpaths($id,$var)
		set txt [$wtxt get 1.0 end]
		set txt [string trimright $txt]
		set valueList [split $txt "\n"]
		foreach value $valueList {
		    lappend subtags [wrapper::createtag value -chdata $value]
		}
	    }
	    text-multi {
		set wtxt $wpaths($id,$var)
		set txt [$wtxt get 1.0 end]
		set txt [string trimright $txt]
		set valueList [split $txt "\n"]
		foreach value $valueList {
		    lappend subtags [wrapper::createtag value -chdata $value]
		}
		set subtags [list [wrapper::createtag value -chdata $value]]
	    }
	    hidden {
		
		# We may have a: 
		# <field type='hidden' var='key'><value>1c9c...</value>
		# which must be returned.
		if {$var == "key"} {
		    set value $cache($id,$var)
		    set subtags [list [wrapper::createtag value  \
		      -chdata $cache($id,$var)]]
		} else {
		    set value ""
		}
	    }
	    default {
		set value ""
	    }
	}
	#puts "\t subtags=$subtags"
	if {$subtags != {}} {
	    lappend xmllist [wrapper::createtag field -attrlist [list var $var] \
	      -subtags $subtags]
	}
    }
    
    # Note the list structure.
    return [list [wrapper::createtag x  \
      -attrlist {xmlns jabber:x:data type submit} -subtags $xmllist]]
}

# Jabber::Forms::ResultList
#
#       Returns a list describing, for instance, a search result.
#
# Arguments:
#       w           the megawidget form.
#       
# Results:
#       a hierarchical list {{jid1 val1 val2 ...} {jid2 val1 val2 ...} ... }

proc ::Jabber::Forms::ResultList {w subiq} {

    variable locals
    variable reported
    
    if {![info exists locals($w,id)]} {
	return -code error "The widget \"$w\" is not a form"
    }
    set id $locals($w,id)
    set res {}
    
    if {$locals($w,type) == "xdata"} {		
	set res [ResultListXData $w $subiq]	
    } elseif {$locals($w,type) == "simple"} {
	
	# Loop through the items. Make sure we get them in the order specified 
	# in 'reported'.
	# We are not guaranteed to receive every field.
	foreach item [wrapper::getchildren $subiq] {
	    unset -nocomplain attrArr itemArr
	    array set attrArr [lindex $item 1]
	    set itemArr(jid) $attrArr(jid)
	    foreach thing [wrapper::getchildren $item] {
		set tag [lindex $thing 0]
		set val [lindex $thing 3]
		set itemArr($tag) $val
	    }
	    set row {}
	    foreach {var label} $reported($id) {
		if {[info exists itemArr($var)]} {
		    lappend row $itemArr($var)
		} else {
		    lappend row {}
		}
	    }
	    lappend res $row
	}
    } else {
	return -code error "The form \"$w\" is of invalid type \"$locals($w,type)\""
    }
    return $res
}

# Jabber::Forms::ResultListXData --
# 
#       See ::Jabber::Forms::ResultList
#       Complete xml: <query ...><iq ...><x xmlns='jabber:x:data' ...>
#       subiq: <iq ...><x ...
#       
#       or: <iq from='users.jabber.org' id='1014' to='..' type='result'>
#               <query xmlns='jabber:iq:search'><truncated/>
#                   <x type='result' xmlns='jabber:x:data'>

proc ::Jabber::Forms::ResultListXData {w subiq} {
    
    variable locals
    variable reported
    
    if {![info exists locals($w,id)]} {
	return -code error "The widget \"$w\" is not a form"
    }
    set id $locals($w,id)
    set res {}
    set xlist [wrapper::getchildwithtaginnamespace $subiq x "jabber:x:data"]
    if {[llength $xlist] == 0} {
	return -code error {Did not identify the <x> element in search result}
    }
    
    # We expect just a single x element.
    set xElem [lindex $xlist 0]    
    
    # Loop through the items. The first one must be a <reported> element.
    # We are not guaranteed to receive every field.
    
    foreach item [wrapper::getchildren $xElem] {
	
	switch -- [lindex $item 0] {
	    title {
		#
	    }
	    reported {
		set reported($id) {}
		foreach field [wrapper::getchildren $item] {
		    unset -nocomplain attrArr
		    array set attrArr [lindex $field 1]
		    lappend reported($id) $attrArr(var) $attrArr(label)
		}
	    }
	    item {
		foreach field [wrapper::getchildren $item] {
		    unset -nocomplain fieldAttrArr
		    array set fieldAttrArr [lindex $field 1]
		    set valueElem [lindex [wrapper::getchildren $field] 0]
		    if {![string equal [lindex $valueElem 0] "value"]} {
			continue
		    }		
		    set itemArr($fieldAttrArr(var)) [lindex $valueElem 3]		
		}
		
		# Sort in order of <reported>.
		set row {}
		foreach {var label} $reported($id) {
		    if {[info exists itemArr($var)]} {
			lappend row $itemArr($var)
		    } else {
			lappend row {}
		    }
		}
		lappend res $row
	    }
	}
    }
    return $res
}

#-------------------------------------------------------------------------------
