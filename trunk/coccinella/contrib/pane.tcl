## Paned Window Procs inspired by code by Stephen Uhler @ Sun.
## Thanks to John Ellson (ellson@lucent.com) for bug reports & code ideas.
##
## Copyright 1996-1997 Jeffrey Hobbs, jeff.hobbs@acm.org
##
## Large rewrite by Mats Bengtsson 2001-2002
##
# $Id: pane.tcl,v 1.2 2003-12-15 08:20:53 matben Exp $

package provide Pane 1.0

##------------------------------------------------------------------
## PROCEDURE
##	pane
##
## DESCRIPTION
##	paned window management function
##
## METHODS
##
##  pane configure <widget> ?<widget> ...? ?<option> <value>?
##  pane <widget> ?<widget> ...? ?<option> <value>?
##	Sets up the management of the named widgets as paned windows.
##
##	OPTIONS
##	-dynamic	Whether to dynamically resize or to resize only
##			when the user lets go of the handle
##      -limit          How large fraction of a frame that is its
##                      min value. Defaults to 0.1.
##	-orient		Orientation of window to determing tiling.
##			Can be either horizontal (default) or vertical.
##	-parent		A master widget to use for the slaves.
##			Defaults to the parent of the first widget.
##      -relative       List of relative widths.
##	-handlelook	Options to pass to the handle during 'frame' creation.
##	-handleplace	Options to pass to the handle during 'place'ment.
##			Make sure you know what you're doing.
##
##  pane forget <master> ?<slave> ...?
##	If called without a slave name, it forgets all slaves and removes
##	all handles, otherwise just removes the named slave(s) and redraws.
##
##  pane info <slave>
##	Returns the value of [place info <slave>].
##
##  pane slaves <master>
##	Returns the slaves currently managed by <master>.
##
##  pane master <slave>
##	Returns the master currently managing <slave>.
##
## BEHAVIORAL NOTES
##	pane is a limited interface to paned window management.  Error
##  catching is minimal.  When you add more widgets to an already managed
##  parent, all the fractions are recalculated.  Handles have the name
##  $parent.__h#, and will be created/destroyed automagically.  You must
##  use 'pane forget $parent' to clean up what 'pane' creates, otherwise
##  critical state info about the parent pane will not be deleted.  This
##  could support -before/after without too much effort if the desire
##  was there.  Because this uses 'place', you have to take the same care
##  to size the parent yourself.
##
## VERSION 1.0
##
## EXAMPLES AT END OF FILE
##

namespace eval ::pane:: {
    namespace export pane
    
    option add *Pane.background          white             widgetDefault
    option add *Pane.imageHorizontal     pane::imh         widgetDefault
    option add *Pane.imageVertical       pane::imv         widgetDefault

    variable PANE    

    set dataPaneH {
R0lGODdhsAQIAKIAAP///8fJ0aetvkpuvDJEawAAAAAAAAAAACwAAAAAsAQI
AAAD/xi63P4wykmrvTjrzbv/YCiOZGmeaKqubOu+cCzPdG3fuFkUz+77uaBw
SCwaj8ikcslsOp/QqHRKKQyuj6t2AFh0Fd9AeOwtg81iNPnMTrfX7jh8rq6/
7XI8/c7P9/d+gYCDeoV/hoKIhIeMiY2LjpGQk4qVj5aSmJSXnJmdm56hoKOa
pZ+moqikp6yprauusbCzqrWvtgtWW1laYQoEC8C/wcTDxgHCyMXKx8nOy8/N
0NPS1czX0djU2tbZ3tvf3eDj4uXc5+Ho5Orm6e7r7+3w8/L17Pfx+PT69vn+
+//6ARwosCC/gwERElRoMKHDhQ8bQpwosSLDixEx5tqihYeXL1y0bomUBbLk
yJAkT5pMyRKly5UvVcpsCbPmzJg0b9rMyROnz50/dQrtCbToUAYAkipN+uAj
g4xQKWq0GJWq1KpTs2LderWr1a9avYYFy5Ws2LJj06Jde7at2bdq3caFy5au
XCp48+rdy7ev37+AAwseTLiw4cOIEytezLix48eQI0tenAAAOw==}

    set dataPaneV {
R0lGODdhCAAgA6IAAP///8fJ0aetvkpuvDJEawAAAAAAAAAAACwAAAAACAAg
AwAD/xi63P7FlQHYpOtipesaoPdtDMmIT6pG0tC6FghzsnihExoUuuo/PQUh
FQwMF8WjI3lKKRtMpJM4lT6ezWvWgbVyt42uIjquLs0BMhStBjOebW/YvRCn
2Wi6UG+kauVvfl+AdYJzhHtAeH9njHeOfHB5iH2UdmpxZY6Zj4Oanmubk5+H
pIGKopCWkYanpoWooJyYo52ltq6hsrW0qq+Jv5WNu764sMGXi6Csq7G3s8q3
zMitx8bAus+80bnT18LZudCpy83UzuLb5NLm38nr3e3jxOXn9uHW89rFvfXu
3t70pePHzVpAdfTY3ROYD+E+f/0U/mt3kCA8g/IcDoRYEP9bRY4XPWa0mDDe
Qo0NST6UGNHkxHsfWXYEF9NlS4wnVW6UGZLmSJAlcb4cWlPoTZE5ga60OfNd
UKRDGWKTCo6qJJ0ple5k2tPpUqNNq01FORZrWa1ZeT71mVTtV6hH2UYlW5Xu
VbRn3W4F21VsXbN/8QbWm5brWq974YZFV5jvYb93Cec1/FZuXMSNFfdlPNlx
ZcydNT/mPJhyYsuLh32GDPCn5NKeT4OGLXo16cimM6PerFo2a4quc4fePbq3
7tm4Yx//DTO48uHIW7cVTpu4bePQmRN1Xtv3belzASfvvvw78OnPq0c/H17w
eOvesavXbhX8Zfp27afGl938vQQAOw==}
	
    set PANE(impaneh) [image create photo pane::imh -data $dataPaneH]
    set PANE(impanev) [image create photo pane::imv -data $dataPaneV]
}

proc ::pane::pane {opt args} {
    variable PANE    
    
    switch -glob -- $opt {
	c* { eval pane_config $args }
	f* {
	    set p [lindex $args 0]
	    if {[info exists PANE($p,w)]} {
		if {[llength $args]==1} {
		    foreach w $PANE($p,w) { catch {place forget $w} }
		    foreach w [array names PANE $p,*] { unset PANE($w) }
		    if {![catch {winfo children $p} kids]} {
			foreach w $kids {
			    if {[string match *.__h* $w]} { destroy $w }
			}
		    }
		} else {
		    foreach w [lrange $args 1 end] {
			place forget $w
			set i [lsearch -exact $PANE($p,w) $w]
			set PANE($p,w) [lreplace $PANE($p,w) $i $i]
		    }
		    if [llength $PANE($p,w)] {
			eval pane_config $PANE($p,w)
		    } else {
			pane forget $p
		    }
		}
	    } else {
		
	    }
	}
	i* { return [place info $args] }
	s* {
	    if {[info exists PANE($args,w)]} {
		return $PANE($args,w)
	    } {
		return {}
	    }
	}
	m* {
	    foreach w [array names PANE *,w] {
		if {[lsearch $PANE($w) $args] != -1} {
		    regexp {([^,]*),w} $w . res
		    return $res
		}
	    }
	    return -code error \
		    "no master found. perhaps $args is not a pane slave?"
	}
	default { eval pane_config [list $opt] $args }
    }
}

##
## PRIVATE FUNCTIONS
##
## I don't advise playing with these because they are slapped together
## and delicate.  I don't recommend calling them directly either.
##

;proc ::pane::pane_config args {
    variable PANE    

    array set opt {orn none par {} dyn 0 hpl {} hlk {} rel none lim none}
    set wids {}
    for {set i 0;set num [llength $args];set cargs {}} {$i<$num} {incr i} {
	set arg [lindex $args $i]
	if [winfo exists $arg] { lappend wids $arg; continue }
	set val [lindex $args [incr i]]
	switch -glob -- $arg {
	    -d*	{ set key dyn; set val [regexp -nocase {^(1|yes|true|on)$} $val] }
	    -o*	{ set key orn }
	    -p*	{ set key par }
	    -handlep*	{ set key hpl }
	    -handlel*	{ set key hlk }
	    -relative   { set key rel }
	    -limit      { set key lim }
	    default	{ return -code error "unknown option \"$arg\"" }
	}
	if {$num==$i} {
	    return -code error "Missing option for $args"
	}
	set opt($key) $val
    }
    if {[string match {} $wids]} {
	return -code error "no widgets specified to configure"
    }
    if {[string compare {} $opt(par)]} {
	set p $opt(par)
    } else {
	set p [winfo parent [lindex $wids 0]]
    }
    if {[string match none $opt(orn)]} {
	if {![info exists PANE($p,o)]} { set PANE($p,o) h }
    } else {
	set PANE($p,o) $opt(orn)
    }
    if {[string match h* $PANE($p,o)]} {
	set owh height; set wh width; set xy x; set hv h; set ohv v
    } else {
	set owh width; set wh height; set xy y; set hv v; set ohv h
    }
    if ![info exists PANE($p,w)] { set PANE($p,w) {} }
    foreach w [winfo children $p] {
	if {[string match *.__h* $w]} { destroy $w }
    }
    foreach w $wids {
	set i [lsearch -exact $PANE($p,w) $w]
	if {$i<0} { lappend PANE($p,w) $w }
    }
    set ll [llength $PANE($p,w)]
    if {[string match none $opt(rel)] && ![info exists PANE($p,rel)]} { 
	for {set i 0} {$i < $ll} {incr i} {
	    lappend fracl [expr {1.0/$ll}]
	}
    } else {
	set PANE($p,rel) $opt(rel)
	set fracl $opt(rel)
    }
    if {[string match none $opt(lim)] && ![info exists PANE($p,lim)]} { 
	set PANE($p,lim) 0.1
    } else {
	set PANE($p,lim) $opt(lim)
    }
    array set hndconf $opt(hlk)
    if {![info exists hndconf(-$wh)]} {
	set hndconf(-$wh) [image $wh $PANE(impane$ohv)]	
    }
    set off [expr $hndconf(-$wh) + 2]
    set pos 0.0
    set i 0
    foreach w $PANE($p,w) {
	set frac [lindex $fracl $i]
	place forget $w
	place $w -in $p -rel$owh 1 -rel$xy $pos -$wh -$off \
	  -rel$wh $frac -anchor nw
	raise $w
	set pos [expr $pos+$frac]
	incr i 
    }
    place $w -$wh 0
    set frac 1.0
    
    while {[incr ll -1]} {
	set frac [expr $frac - [lindex $fracl $ll]]
	set h [eval label [list $p.__h$ll] -bd 1 -relief raised \
	  -cursor sb_${hv}_double_arrow -image $PANE(impane$ohv)  \
	  -anchor nw [array get hndconf]]
	eval place [list $h] -rel$owh 1 -rel$xy $frac \
	  -$xy -$off -anchor nw $opt(hpl)
	raise $h
	bind $h <ButtonPress-1> "::pane::pane_constrain $p $h \
	  [lindex $PANE($p,w) [expr $ll-1]] [lindex $PANE($p,w) $ll] \
	  $wh $xy $opt(dyn) $hndconf(-$wh)"
    }
}

;proc ::pane::pane_constrain {p h w0 w1 wh xy d hwh} {
    variable PANE    
    regexp -- "\-rel$xy (\[^ \]+)" [place info $w0] junk t0
    regexp -- "\-rel$xy (\[^ \]+).*\-rel$wh (\[^ \]+)" \
	    [place info $w1] junk t1 t2
    set offset [expr ($t1+$t2-$t0) * $PANE($p,lim)]
    array set PANE [list XY [winfo root$xy $p] WH [winfo $wh $p].0 \
      W0 $w0 W1 $w1 XY0 $t0 XY1 [expr $t1+$t2] \
      C0 [expr $t0+$offset] C1 [expr $t1+$t2-$offset]]
    set PANE(C0) [expr $PANE(C0) + $hwh/$PANE(WH)]
    bind $h <B1-Motion> "::pane::pane_motion %[string toup $xy] $p $h $wh $xy $d"
    $h config -relief sunken
    if !$d {
	bind $h <ButtonRelease-1> \
		"::pane::pane_motion %[string toup $xy] $p $h $wh $xy 1;\
		$h config -relief raised"
    } else {
	bind $h <ButtonRelease-1> "$h config -relief raised"
    }
}

;proc ::pane::pane_motion {X p h wh xy d} {
    variable PANE
    set f [expr ($X-$PANE(XY))/$PANE(WH)]
    if {$f<$PANE(C0)} { set f $PANE(C0) }
    if {$f>$PANE(C1)} { set f $PANE(C1) }
    if $d {
	place $PANE(W0) -rel$wh [expr $f-$PANE(XY0)]
	place $h -rel$xy $f
	place $PANE(W1) -rel$wh [expr $PANE(XY1)-$f] -rel$xy $f
    } else {
	place $h -rel$xy $f
    }
}

##
## EXAMPLES
##
## These auto-generate for the plugin.  Remove these for regular use.
##
if {0 && [info exists embed_args]} {
    ## Hey, super-pane the one toplevel we get!
    namespace import ::pane::*
    pane [frame .0] [frame .1]
    ## Use the line below for a good non-plugin example
    #toplevel .0; toplevel .1
    pane [listbox .0.0] [listbox .0.1] -dynamic 1
    pane [frame .1.0] [frame .1.1] -dyn 1
    pane [listbox .1.0.0] [listbox .1.0.1] [listbox .1.0.2] -orient vertical
    pack [label .1.1.0 -text "Text widget:"] -fill x
    pack [text .1.1.1] -fill both -expand 1
    set i [info procs]
    foreach w {.0.0 .0.1 .1.0.0 .1.0.1 .1.0.2 .1.1.1} { eval $w insert end $i }
}
##
## END EXAMPLES
##
## EOF
