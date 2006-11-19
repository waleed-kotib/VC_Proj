# xpath.tcl --
#
#	Provides an XPath parser for Tcl,
#	plus various support procedures
#
# Copyright (c) 2000 Zveno Pty Ltd
#
# $Id: xpath.tcl,v 1.2 2004-08-17 14:10:30 matben Exp $

package provide xpath 1.0

# We need the XML package for definition of Names
package require xml

namespace eval xpath {
    namespace export split join createnode

    variable axes {
	ancestor
	ancestor-or-self
	attribute
	child
	descendant
	descendant-or-self
	following
	following-sibling
	namespace
	parent
	preceding
	preceding-sibling
	self
    }

    variable nodeTypes {
	comment
	text
	processing-instruction
	node
    }

    # NB. QName has parens for prefix

    variable nodetestExpr ^(${::xml::QName})${::xml::allWsp}(\\(${::xml::allWsp}(("|')(.*?)\\5)?${::xml::allWsp}\\))?${::xml::allWsp}(.*)

    variable nodetestExpr2 ((($::xml::QName)${::xml::allWsp}(\\(${::xml::allWsp}(("|')(.*?)\\7)?${::xml::allWsp}\\))?)|${::xml::allWsp}(\\*))${::xml::allWsp}(.*)
}

# xpath::split --
#
#	Parse an XPath location path
#
# Arguments:
#	locpath	location path
#
# Results:
#	A Tcl list representing the location path.
#	The list has the form: {{axis node-test {predicate predicate ...}} ...}
#	Where each list item is a location step.

proc xpath::split locpath {
    set leftover {}

    set result [InnerSplit $locpath leftover]

    if {[string length [string trim $leftover]]} {
	return -code error "unexpected text \"$leftover\""
    }

    return $result
}

proc xpath::InnerSplit {locpath leftoverVar} {
    upvar $leftoverVar leftover

    variable axes
    variable nodetestExpr
    variable nodetestExpr2

    # First determine whether we have an absolute location path
    if {[regexp {^/(.*)} $locpath discard locpath]} {
	set path {{}}
    } else {
	set path {}
    }

    while {[string length [string trimleft $locpath]]} {
	if {[regexp {^\.\.(.*)} $locpath discard locpath]} {
	    # .. abbreviation
	    #puts stderr [list .. abbrev]
	    set axis parent
	    set nodetest *
	} elseif {[regexp {^/(.*)} $locpath discard locpath]} {
	    # // abbreviation
	    #puts stderr [list // abbrev]
	    set axis descendant-or-self
	    if {[regexp ^$nodetestExpr2 [string trimleft $locpath] discard discard discard nodetest discard typetest discard discard literal wildcard locpath]} {
		set nodetest [ResolveWildcard $nodetest $typetest $wildcard $literal]
	    } else {
		set leftover $locpath
		return $path
	    }
	} elseif {[regexp ^\\.${::xml::allWsp}(.*) $locpath discard locpath]} {
	    # . abbreviation
	    #puts stderr [list . abbrev]
	    set axis self
	    set nodetest *
	} elseif {[regexp ^@($::xml::QName)${::xml::allWsp}=${::xml::allWsp}"(\[^"\])"(.*) $locpath discard attrName discard attrValue locpath]} {
	    # @ abbreviation
	    #puts stderr [list @ abbrev 1]
	    set axis attribute
	    set nodetest $attrName
	} elseif {[regexp ^@($::xml::QName)${::xml::allWsp}=${::xml::allWsp}'(\[^'\])'(.*) $locpath discard attrName discard attrValue locpath]} {
	    # @ abbreviation
	    #puts stderr [list @ abbrev 2]
	    set axis attribute
	    set nodetest $attrName
	} elseif {[regexp ^@($::xml::QName)(.*) $locpath discard attrName discard locpath]} {
	    # @ abbreviation
	    #puts stderr [list @ abbrev 3 ]
	    set axis attribute
	    set nodetest $attrName
	} elseif {[regexp ^((${::xml::QName})${::xml::allWsp}::${::xml::allWsp})?\\*(.*) $locpath discard discard axis discard locpath]} {
	    # wildcard specified
	    #puts stderr [list got axis and/or wildcard]
	    set nodetest *
	    if {![string length $axis]} {
		set axis child
	    }
	} elseif {[regexp ^((${::xml::QName})${::xml::allWsp}::${::xml::allWsp})?$nodetestExpr2 $locpath discard discard axis discard discard discard nodetest discard typetest discard discard literal wildcard locpath]} {
	    # nodetest, with or without axis
	    #puts stderr [list no axis, got a nodetest]
	    if {![string length $axis]} {
		set axis child
	    }
	    set nodetest [ResolveWildcard $nodetest $typetest $wildcard $literal]
	} else {
	    #puts stderr [list else case]
	    set leftover $locpath
	    return $path
	}

	# ParsePredicates
	set predicates {}
	set locpath [string trimleft $locpath]
	while {[regexp {^\[(.*)} $locpath discard locpath]} {
	    if {[regexp {^([0-9]+)(\].*)} [string trim $locpath] discard posn locpath]} {
		set predicate [list = {function position {}} [list number $posn]]
	    } else {
		set leftover2 {}
		set predicate [ParseExpr $locpath leftover2]
		set locpath $leftover2
		unset leftover2
	    }

	    if {[regexp {^\](.*)} [string trimleft $locpath] discard locpath]} {
		lappend predicates $predicate
	    } else {
		return -code error "unexpected text in predicate \"$locpath\""
	    }
	}

	set axis [string trim $axis]
	set nodetest [string trim $nodetest]

	# This step completed
	if {[lsearch $axes $axis] < 0} {
	    return -code error "invalid axis \"$axis\""
	}
	lappend path [list $axis $nodetest $predicates]

	# Move to next step

	if {[string length $locpath] && ![regexp /(.*) $locpath discard locpath]} {
	    set leftover $locpath
	    return $path
	}

    }

    return $path
}

proc xpath::ParseExpr {locpath leftoverVar} {
    upvar $leftoverVar leftover
    variable nodeTypes

    set expr {}
    set mode expr
    set stack {}

    while {[string index [string trimleft $locpath] 0] != "\]"} {
	set locpath [string trimleft $locpath]
	switch $mode {
	    expr {
		# We're looking for a term
		#puts stderr [list looking for term in $locpath]
		if {[regexp ^-(.*) $locpath discard locpath]} {
		    # UnaryExpr
		    lappend stack "-"
		} elseif {[regexp ^\\\$({$::xml::QName})(.*) $locpath discard varname discard locpath]} {
		    # VariableReference
		    lappend stack [list varRef $varname]
		    set mode term
		} elseif {[regexp {^\((.*)} $locpath discard locpath]} {
		    # Start grouping
		    set leftover2 {}
		    lappend stack [list group [ParseExpr $locpath leftover2]]
		    set locpath $leftover2
		    unset leftover2

		    if {[regexp {^\)(.*)} [string trimleft $locpath] discard locpath]} {
			set mode term
		    } else {
			return -code error "unexpected text \"$locpath\", expected \")\""
		    }

		} elseif {[regexp {^"([^"]*)"(.*)} $locpath discard literal locpath]} {
		    # Literal (" delimited)
		    lappend stack [list literal $literal]
		    set mode term
		} elseif {[regexp {^'([^']*)'(.*)} $locpath discard literal locpath]} {
		    # Literal (' delimited)
		    lappend stack [list literal $literal]
		    set mode term
		} elseif {[regexp {^([0-9]+(\.[0-9]+)?)(.*)} $locpath discard number discard locpath]} {
		    # Number
		    lappend stack [list number $number]
		    set mode term
		} elseif {[regexp {^(\.[0-9]+)(.*)} $locpath discard number locpath]} {
		    # Number
		    lappend stack [list number $number]
		    set mode term
		} elseif {[regexp ^(${::xml::QName})\\(${::xml::allWsp}(.*) $locpath discard functionName discard locpath]} {
		    # Function call start

		    if {[lsearch $nodeTypes $functionName] >= 0} {
			return -code error "invalid function name \"$functionName\""
		    }

		    if {[regexp ^\\)${::xml::allWsp}(.*) $locpath discard locpath]} {
			set parameters {}
		    } else {
			set leftover2 {}
			set parameters [ParseExpr $locpath leftover2]
			set locpath $leftover2
			unset leftover2
			while {[regexp {^,(.*)} $locpath discard locpath]} {
			    set leftover2 {}
			    lappend parameters [ParseExpr $locpath leftover2]
			    set locpath $leftover2
			    unset leftover2
			}

			if {![regexp ^\\)${::xml::allWsp}(.*) [string trimleft $locpath] discard locpath]} {
			    return -code error "unexpected text \"locpath\" - expected \")\""
			}
		    }

		    lappend stack [list function $functionName $parameters]
		    set mode term

		} else {
		    # LocationPath
		    #puts stderr [list ParseExpr found location path]
		    set leftover2 {}
		    lappend stack [list path [InnerSplit $locpath leftover2]]
		    set locpath $leftover2
		    unset leftover2
		    set mode term
		}
	    }
	    term {
		# We're looking for an expression operator
		#puts stderr [list looking for operator in $locpath]
		if {[regexp ^-(.*) $locpath discard locpath]} {
		    # UnaryExpr
		    set stack [linsert $stack 0 expr "-"]
		    set mode expr
		} elseif {[regexp ^(and|or|\\=|!\\=|<|>|<\\=|>\\=|\\||\\+|\\-|\\*|div|mod)(.*) $locpath discard exprtype locpath]} {
		    # AndExpr, OrExpr, EqualityExpr, RelationalExpr or UnionExpr
		    set stack [linsert $stack 0 $exprtype]
		    set mode expr
		} else {
		    return -code error "unexpected text \"$locpath\", expecting operator"
		}
	    }
	    default {
		# Should never be here!
		return -code error "internal error"
	    }
	}
    }

    set leftover $locpath
    return $stack
}

# xpath::ResolveWildcard --

proc xpath::ResolveWildcard {nodetest typetest wildcard literal} {
    variable nodeTypes

    switch -glob -- [string length $nodetest],[string length $typetest],[string length $wildcard],[string length $literal] {
	0,0,0,* {
	    return -code error "bad location step (nothing parsed)"
	}
	0,0,* {
	    # Name wildcard specified
	    return *
	}
	*,0,0,* {
	    # Element type test - nothing to do
	    return $nodetest
	}
	*,0,*,* {
	    # Internal error?
	    return -code error "bad location step (found both nodetest and wildcard)"
	}
	*,*,0,0 {
	    # Node type test
	    if {[lsearch $nodeTypes $nodetest] < 0} {
		return -code error "unknown node type \"$typetest\""
	    }
	    return [list $nodetest $typetest]
	}
	*,*,0,* {
	    # Node type test
	    if {[lsearch $nodeTypes $nodetest] < 0} {
		return -code error "unknown node type \"$typetest\""
	    }
	    return [list $nodetest $literal]
	}
	default {
	    # Internal error?
	    return -code error "bad location step"
	}
    }
}

# xpath::join --
#
#	Reconstitute an XPath location path from a
#	Tcl list representation.
#
# Arguments:
#	spath	split path
#
# Results:
#	Returns an Xpath location path

proc xpath::join spath {
    return -code error "not yet implemented"
}
