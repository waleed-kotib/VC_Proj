#!/usr/bin/wish
#
# Copyright (C) 1997,1998 D. Richard Hipp
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Library General Public$
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Library General Public License for more details.
# 
# You should have received a copy of the GNU Library General Public
# License along with this library; if not, write to the
# Free Software Foundation, Inc., 59 Temple Place - Suite 330,
# Boston, MA  02111-1307, USA.
#
# Author contact information:
#   drh@acm.org
#   http://www.hwaci.com/drh/
#
# Complete rewrite by Mats Bengtsson   (matben@privat.utfors.se)
# 
# Copyright (C) 2002-2003 Mats Bengtsson
# 
# $Id: tree.tcl,v 1.2 2003-01-30 17:33:40 matben Exp $
# 
# ########################### USAGE ############################################
#
#   NAME
#      tree - a tree widget.
#      
#   SYNOPSIS
#      tree pathName ?options?
#      
#   OPTIONS
#	-background, background, Background 
#	-buttonpresscommand, buttonPressCommand, ButtonPressCommand  tclProc?
#	-buttonpressmillisec, buttonPressMillisec, ButtonPressMillisec
#	-doubleclickcommand, doubleClickCommand, DoubleClickCommand  tclProc?
#	-font, font, Font
#	-fontdir, fontDir, FontDir
#	-highlightbackground, highlightBackground, HighlightBackground
#	-highlightcolor, highlightColor, HighlightColor
#	-highlightthickness, highlightThickness, HighlightThickness
#	-height, height, Height
#	-opencommand, openCommand, OpenCommand
#	-openicons, openIcons, OpenIcons                      (plusminus|triangles)
#	-pyjamascolor, pyjamasColor, PyjamasColor
#	-rightclickcommand, rightClickCommand, RightClickCommand  tclProc?
#	-scrollwidth, scrollWidth, ScrollWidth
#	-selectbackground, selectBackground, SelectBackground
#	-selectcommand, selectCommand, SelectCommand          tclSelectProc?
#	-selectforeground, selectForeground, SelectForeground
#	-selectmode, selectMode, SelectMode                   (0|1)
#	-silent, silent, Silent                               (0|1)
#	-sortorder, sortOrder, SortOrder                      (decreasing|increasing)?
#	-treecolor, treeColor, TreeColor                      color?
#	-width, width, Width
#	-xscrollcommand, xScrollCommand, ScrollCommand
#	-yscrollcommand, yScrollCommand, ScrollCommand
#	
#   WIDGET COMMANDS
#      pathName cget option
#      pathName children itemPath
#      pathName closetree itemPath
#      pathName configure ?option? ?value option value ...?
#      pathName delitem itemPath ?-childsonly (0|1)?
#      pathName find withtag aTag
#      pathName getselection
#      pathName getcanvas
#      pathName isitem itemPath
#      pathName itemconfigure itemPath ?option? ?value option value ...?
#      pathName labelat itemPath
#      pathName newitem itemPath
#      pathName opentree itemPath
#      pathName setselection itemPath
#      pathName xview args
#      pathName yview args
#      
#   ITEM OPTIONS
#      -background
#      -dir           0|1
#      -image         imageName
#      -open          0|1
#      -style         normal|bold|italic
#      -tags
#      -text
#
#   USER PROCS
#      proc tclSelectProc {w v}
#         w   widget
#         v   itemPath
#
# *) a question mark (?) means that an empty list {} is also an option.
#    -sortorder doesn't work when configure'ing.
# 
# ########################### CHANGES ##########################################
#
#       1.0         first release by Mats Bengtsson    

package provide tree 1.0

namespace eval tree {

    # The public interface.
    namespace export tree

    # Globals same for all instances of this widget.
    variable widgetGlobals
    
    set widgetGlobals(debug) 0
    
    # Define open/closed icons of Window type.
    set maskdata "#define solid_width 9\n#define solid_height 9"
    append maskdata {
	static unsigned char solid_bits[] = {
	    0xff, 0x01, 0xff, 0x01, 0xff, 0x01, 0xff, 0x01, 0xff, 0x01, 0xff, 0x01,
	    0xff, 0x01, 0xff, 0x01, 0xff, 0x01
	};
    }
    set data "#define open_width 9\n#define open_height 9"
    append data {
	static unsigned char open_bits[] = {
	    0xff, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x7d, 0x01, 0x01, 0x01,
	    0x01, 0x01, 0x01, 0x01, 0xff, 0x01
	};
    }
    set widgetGlobals(openbmplusmin)   \
      [image create bitmap -data $data -maskdata $maskdata \
      -foreground black -background white]
    set data "#define closed_width 9\n#define closed_height 9"
    append data {
	static unsigned char closed_bits[] = {
	    0xff, 0x01, 0x01, 0x01, 0x11, 0x01, 0x11, 0x01, 0x7d, 0x01, 0x11, 0x01,
	    0x11, 0x01, 0x01, 0x01, 0xff, 0x01
	};
    }
    set widgetGlobals(closedbmplusmin)   \
      [image create bitmap -data $data -maskdata $maskdata \
      -foreground black -background white]
    set widgetGlobals(idir) [image create photo -data {
	R0lGODdhEAAQAPIAAAAAAHh4eLi4uPj4APj4+P///wAAAAAAACwAAAAAEAAQAAADPVi63P4w
	LkKCtTTnUsXwQqBtAfh910UU4ugGAEucpgnLNY3Gop7folwNOBOeiEYQ0acDpp6pGAFArVqt
	hQQAO///
    }]
    set widgetGlobals(ifile) [image create photo -data {
	R0lGODdhEAAQAPIAAAAAAHh4eLi4uPj4+P///wAAAAAAAAAAACwAAAAAEAAQAAADPkixzPOD
	yADrWE8qC8WN0+BZAmBq1GMOqwigXFXCrGk/cxjjr27fLtout6n9eMIYMTXsFZsogXRKJf6u
	P0kCADv/
    }]
	
    # The mac look-alike triangles, folder, and generic file icons.
    set widgetGlobals(openbmmac) [image create photo -data {
	R0lGODdhCwAKAKIAAP///97e3s7O/729vZyc/4yMjGNjzgAAACwAAAAACwAKAAADHRi63P7t
	yElPOCJrcoo6REgY3bCAYxmRhemokKskADs=
    }]
    set widgetGlobals(closedbmmac) [image create photo -data {
	R0lGODdhCgALAKIAAP///97e3s7O/729vZyc/4yMjGNjzgAAACwAAAAACgALAAADHRh62n7M
	tSOipMROQfLlhKFhYjFs5Tll5nW0F6wkADs=
    }]
    set widgetGlobals(folderim) [image create photo -data {
	R0lGODdhEAAQANUAAP///+fn/97e/97e3s7O/87Ozs7G/8bG/73G/729/729zr29vbW9/7W1
	/7W1xrW1vbW1ta21/62t/62t96Wt96Wl96WlpZyc/5SU/5SU94yM74SEhHt753t73nNzc2tr
	xmtra2NjzmNjxmNjY1patVparVpapVpaWlpSpVJSpVJSnEpKnEpKlEpKjEJChDk5ezk5czEx
	azExYykxYykpWikpUiEhSiEhQgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACwAAAAAEAAQAAAG
	n8DBIJVyCI9IYQmmuYiKw5ciaSKQYBxnSqIRSY8oQuBCenEwaO7rmCIQDAKyGXPhwI4qwmGP
	iJc5H3dCKnsHCAmIDR0xJDFHLHyICQ2KMSuOQpCSk5SLKzKPkgyUDRKeM0ctHRejDRESE540
	CwUDDzEuq68TsZY0Hha1trgfGRQVnjUnHhBIty4fHZ42IxvCzrghljYeC0nOMjc3IN4DQQA7
    }]
    set widgetGlobals(fileim) [image create photo -data {
	R0lGODdhEAAQAKIAAP///+/v797e3s7OzgAAAAAAAAAAAAAAACwAAAAAEAAQAAADNCi03PKQ
	hEnngk9WSgbB2hY4mbh9pclF1igtFqvGaePSyoxrcL/rI9kMldMRQ6pjY8l4JAAAOw==
    }]
    set widgetGlobals(machead) [image create photo -data {
	R0lGODdhCgAMAKIAAP//////zv/OnN7e3s6cYwAAAAAAAAAAACwAAAAACgAMAAADIzi1vBow
	BrGmuJdUTIUu1lV4G0eC5hmKTDhSD8fEnDYojTMkADs=
    }]
    set widgetGlobals(macheadaway) [image create photo -data {
	R0lGODdhEAAOALMAAP//////zv/OnN7e3s7O/86cY2NjzjExYwAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAACwAAAAAEAAOAAAER3DIKZG9iFIUuheZNnBCWRahRpaIgE7YCrppHZhnFmMmLxAm
	IKgFGrkMroKhgBrqjkwlk/hqSZlL1KUCxU5VrkNU/FLtLKIIADs=
    }]
    set widgetGlobals(macheadtalk) [image create photo -data {
	R0lGODdhDgAOAKIAAP//////zv/OnN7e3s6cYwAAYwAAAAAAACwAAAAADgAOAAADOTi2vPPP
	hEmDMFBZwTnBkNRdwpeJnVGC0TaaRTt6YIyOS2y7zaPfLN+gcLs4hsMiB6OLNI7CjDSaAAA7
    }]
    set widgetGlobals(macheadunav) [image create photo -data {
	R0lGODdhDQANALMAAP//////zv/Ozv/OnP9jY/8xAN7e3t4AAM6cY70AAK0AAIwAAHMAAFJS
	UlIAAAAAACwAAAAADQANAAAETtCYI6uk17zNN5vCQyxBmQjK86WLogxHoTRP9bRK/KS1dLsu
	FaKnCRyAjMHQlpABFUsfwcUIbi6/5C6lmBBuycGAo/gwHg6x2lM5d9iGCAA7
    }]
    set widgetGlobals(macheadsleep) [image create photo -data {
	R0lGODdhDQAPAKIAAP//////zv/OnN7e3s6cYwAAAAAAAAAAACwAAAAADQAPAAADNDiq1bUQ
	PtnWjNfd4aKnWuYEZCAITxGoxekS6eqeLczJcx3Ps63yrx1Q4AsQjkjkJBQaJAAAOw==
    }]
    set widgetGlobals(macheadgray) [image create photo -data {
	R0lGODdhCgAMAKIAAP///97e3sbGxoSEhAAAAAAAAAAAAAAAACwAAAAACgAMAAADIxi0vAow
	ArGmuHdUjDWxFCF4YLdx44k15UU8KwNzWqA0TpAAADs=
    }]
    set widgetGlobals(dndim) [image create photo -data {
	R0lGODdhEAALALMAAP//////zv/Ozv/OnM6cnM6cY85jY5xjY5xjMZwxMQAAAAAAAAAAAAAA
	AAAAAAAAACwAAAAAEAALAAAERVDJSasMQoxBevmgJEhEoRiIYipIqoyDQkimGbvxPKv8LcUm
	HUnGGh6IO6FhmJoVUjmelJAqHGOKwaqQ6HZbLcNnZylLIgA7
    }]
    set widgetGlobals(naim) [image create photo -data {
	R0lGODdhEAALALMAAP///87//5z//5zO/2PO/2Oc/2OczjGczjFjzjFjnABjnAAAAAAAAAAA
	AAAAAAAAACwAAAAAEAALAAAESHDJSasEIAQxOiFFSFzBEozDgUhJK22SsAzJPMy1ec/4vNIx
	lAQ4IQ4KvF5qIVjNDMofVACdHZTXo6lKUHgVhFYLMTBULWhJBAA7
    }]
    set widgetGlobals(questmark) [image create photo -data {
	R0lGODdhCAANAKIAAP////9jY97e3q0AAFIAAAAAAAAAAAAAACwAAAAACAANAAADHCgSMaPL
	yfiEdNA6kgfxUMOFIDlCZXdmrNK0aQIAOw==
    }]    
    set widgetGlobals(macheadwb) [image create photo -data {
	R0lGODlhEAAOAPMAAP//////zv/OnN7e3s6cY29vbwAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAACH5BAEAAAMALAAAAAAQAA4AAARCcJhJ57hYhs2D
	MNlleEJZEmA4mp+AhhpruEZh3ytLAzxf5CxUzwcsUYaAH6n1QSaLR6RSJ5RK
	KhNnMlTQ+ri38C0CADs=
    }]
    set widgetGlobals(macheadtalkwb) [image create photo -data {
	R0lGODlhEAAOAPMAAP//////zv/OnN7e3s6cY29vbwAAYwAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAACH5BAEAAAMALAAAAAAQAA4AAARKcJxJ57hYhs2D
	ONl1eEJZEmA4mp+Ahhp7uEdh3ytLAwbgFzkWytcDAEmyQ694NFWIPGPw4Ksu
	pcjPBNpr6qhXo6Sytf5Ct5shHQEAOw==
    }]
    set widgetGlobals(macheadinv) [image create photo -data {
	R0lGODlhCgAMAPEAAP///wsb6QAAAAAAACH5BAEAAAEALAAAAAAKAAwAAAIY
	jI5nwc3qGpRPRGtwzLvu5GCWVo2dmEAFADs=
    }]
    
    # Some icons remade with transparency and 16 pixels width.
    # May be display problems with 8.3.
    set widgetGlobals(folderim) [image create photo -data {
	R0lGODlhEAARAPMAAP///+/v797e3s7OzgAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAACH5BAEAAAIALAAAAAAQABEAAAQ6UMhJqyQ4a0uC
	/x5WdeBHDARFlsF2sWX6wuZEdlh723Q9a7oQr9ca5o7CWU8mWNGYThiUWLxo
	rhlJBAA7
    }]
    set widgetGlobals(folderim) [image create photo -data {
	R0lGODlhEAAQAPcAAP///+fn/97e/97e3s7O/87Ozs7G/8bG/73G/729/729
	zr29vbW9/7W1/7W1xrW1vbW1ta21/62t/62t96Wt96Wl96WlpZyc/5SU/5SU
	94yM74SEhHt753t73nNzc2trxmtra2NjzmNjxmNjY1patVparVpapVpaWlpS
	pVJSpVJSnEpKnEpKlEpKjEJChDk5ezk5czExazExYykxYykpWikpUiEhSiEh
	QgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAACH5BAEAAAMALAAAAAAQABAAAAi8AAcMSJHCgcCD
	CAWWgKHhgoiCA18oSGiCAAkYHBymkKBBhMSDKAgEuEDiBQcMKDm+OJiCAAED
	AkiaxHCBA4yDKggc2IkgZkkOH24KVLHzAIIESBt0iEEixkEWPJEmaKA0xgqn
	AqFKnUp16QoZT6UyoNpAgtcZB1t0uDC2QQQJE7zSWFBgwIMYLta+nRDXKg0P
	FuraxfshA4UKXmuc8AAB4V0XHzp4tTFig2DHeENYteFhQULHMm7cAOF5QEAA
	Ow==
    }] 
    set widgetGlobals(machead) [image create photo -data {
	R0lGODlhEAAMAPMAAP//////zv/OnN7e3s6cYwAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAACH5BAEAAAMALAAAAAAQAAwAAAQxcJRJ57hYhs2D
	KNlVeEJZEmA4mp+AhhpbuGm2sjR8s69KmhTdb/aBxYAWIa6nqyRhEQA7
    }]
    set widgetGlobals(macheadaway) [image create photo -data {
	R0lGODlhEAAOAPMAAP//////zv/OnN7e3s7O/86cY2NjzjExYwAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAACH5BAEAAAMALAAAAAAQAA4AAARHcMgpkb2IUhS6
	F5k2cEJZFqFGloiATtgKumkdmGcWYyYvECYgqAUauQyugqGAGuqOTCWT+GpJ
	mUvUpQLFTlWuQ1T8Uu0soggAOw==
    }]
    set widgetGlobals(macheadgray) [image create photo -data {
	R0lGODlhEAAMAPMAAP///97e3sbGxoSEhAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAACH5BAEAAAEALAAAAAAQAAwAAAQxMJBJZ7hYgs2B
	INlFeEJZDmA4miYaauYkuCrJ0tnKzmlul5SXjtXzxYLCH+8lqliYEQA7
    }]
    set widgetGlobals(macheadinv) [image create photo -data {
	R0lGODlhEAAMAPEAAP///97e3gAAAAAAACH5BAEAAAEALAAAAAAQAAwAAAIl
	jI4XywYPn2hLxDipxZI6DmTNdoUeeYkMKikaqK6p+5bxmtBUAQA7
    }]
    set widgetGlobals(macheadsleep) [image create photo -data {
	R0lGODlhEAAPAPMAAP//////zv/OnN7e3s6cYwAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAACH5BAEAAAMALAAAAAAQAA8AAAQ+cEhZapk4U03r
	vNzWeZoVnoOlllbgBoIAUkFRxzgxpzcuCzqMreD7BT+wYuxIUy53NicQGiBY
	r9ddSsXFRAAAOw==
    }]
    set widgetGlobals(macheadtalk) [image create photo -data {
	R0lGODlhEAAOAPMAAP//////zv/OnN7e3s6cYwAAYwAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAACH5BAEAAAMALAAAAAAQAA4AAAQ/cJhJ57hYhs2D
	MNlleEJZEmA4mp+AhhpruGm2svRQ2CT76pibzLDbiXqVS/FoqimBsaYFaBQ2
	qbbK9AnrGi8RADs=
    }]
    set widgetGlobals(macheadunav) [image create photo -data {
	R0lGODlhEAANAPMAAP//////zv/Ozv/OnP9jY/8xAN7e3t4AAM6cY70AAK0A
	AIwAAHMAAFJSUlIAAAAAACH5BAEAAAYALAAAAAAQAA0AAARV0Jgjq6R2msc7
	Z9YhPMQSnImgPGC1LooyHIXSPNkGK/Sz4pnHLsZCAC2PwCGmYAyMuUeixlRA
	g4QYg8jJHITNgW+lCBGEzoGY07QwHg61/JN7e+iWCAA7
    }]
    set widgetGlobals(questmark) [image create photo -data {
	R0lGODlhEAANAPMAAP////9jY97e3q0AAFIAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAACH5BAEAAAIALAAAAAAQAA0AAAQmUIgQxpA4y2qt
	zpzUfeKFeeRAZCoptBvsxutM22eNv/ruxz+ZKwIAOw==
    }]
    
    # With whiteboard icon.
    set widgetGlobals(macheadwb) [image create photo -data {
	R0lGODlhEAAOAPMAAP//////zv/OnN7e3s6cY29vbwAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAACH5BAEAAAMALAAAAAAQAA4AAARCcJhJ57hYhs2D
	MNlleEJZEmA4mp+AhhpruEZh3ytLAzxf5CxUzwcsUYaAH6n1QSaLR6RSJ5RK
	KhNnMlTQ+ri38C0CADs=
    }]
    set widgetGlobals(macheadtalkwb) [image create photo -data {
	R0lGODlhEAAOAPMAAP//////zv/OnN7e3s6cY29vbwAAYwAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAACH5BAEAAAMALAAAAAAQAA4AAARKcJxJ57hYhs2D
	ONl1eEJZEmA4mp+Ahhp7uEdh3ytLAwbgFzkWytcDAEmyQ694NFWIPGPw4Ksu
	pcjPBNpr6qhXo6Sytf5Ct5shHQEAOw==
    }]
    set widgetGlobals(macheadawaywb) [image create photo -data {
	R0lGODlhEAAOAPMAAP//////zv/OnN7e3s7O/86cY29vb2NjzjExYwAAAAAA
	AAAAAAAAAAAAAAAAAAAAACH5BAEAAAMALAAAAAAQAA4AAARNcMgpk72J0hS6
	F5k2cEJZFqFGlomATtgKumkdmGcWYyYvECYgqAUytAoHF7KAGiaMrgNz2aRB
	qVQM4CpldhOA8PaImJZR4u1oZzG43xEAOw==
    }]
    set widgetGlobals(macheadinvwb) [image create photo -data {
	R0lGODlhEAAOAPMAAP////7+/vr6+vb29t7e3nV1dW9vbwAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAACH5BAEAAAQALAAAAAAQAA4AAAQ7kJxJJ7lYgs33
	ydfRdR8okh6oocBhvPA5tkNnyOMR2Lg3jQXcSTe65X7FnmdmkFQmAibIMOM0
	M7BsNgIAOw==
    }]
    set widgetGlobals(macheadunavwb) [image create photo -data {
	R0lGODlhEAAOAPcAAP//////zv/Ozv/OnP9jY/8xAN7e3t4AAM6cY70AAK0A
	AIwAAHMAAG9vb1JSUlIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAACH5BAEAAAYALAAAAAAQAA4AAAiJAA0YOCCwoECC
	BgcagMCwIUMGBg8IgEBgQYCLCQQogACx4MYFChQMOFBAgQMICReCVEASwkYI
	DWI2EAhhZUiOCCAA2DlzYYADIRUwGJBzJ4CeEBKUDKqgKE+aBEIyuMnQ6MwD
	NYUOcLlRgdUDBGoOHbCVodCnDCA8IMv2oVWBaR26fZtSpt2YAQEAOw==
    }]
    set widgetGlobals(macheadsleepwb) [image create photo -data {
	R0lGODlhEAAPAPMAAP//////zv/OnN7e3s6cY29vbwAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAACH5BAEAAAMALAAAAAAQAA8AAAREcEhpqpk4U03r
	vNzWeZoVnoOlFmwxGkEcCIIBAC6s0zxh46mAgUcb+m45IbEmOAJhy94vGaU5
	qdVrkMDtdqcvVaVViAAAOw==
    }]
    set widgetGlobals(questmarkwb) [image create photo -data {
	R0lGODlhEAAOAPMAAP////9jY97e3q0AAG9vb1IAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAACH5BAEAAAIALAAAAAAQAA4AAAQ9UIgQxpA4y2qt
	zpzUfeKFeeRQYIRKvPCrYlUB3DhAgGqe75ueDwcUuIbEU4GAvBUlzGaxEkUW
	j1JNbPuKAAA7
    }]
    set widgetGlobals(macheadgraywb) [image create photo -data {
	R0lGODlhEAAOAPMAAP///97e3sbGxoSEhG9vbwAAAAAAAAAAAAAAAAAAAAAA
	AAAAAAAAAAAAAAAAAAAAACH5BAEAAAEALAAAAAAQAA4AAAQ/MJRJZ7hYgs2B
	KNlVeEJZDmA4miYaauYkoERtr+w8dgTOoh1AjxSbBIe5T1DoqyyRvx1PUjE+
	Q4Qlh4C1eW0RADs=
    }]

    
    # Let them be accesible from the outside. 
    set ::tree::idir            $widgetGlobals(idir)
    set ::tree::ifile           $widgetGlobals(ifile)
    set ::tree::folderimmac     $widgetGlobals(folderim)
    set ::tree::fileimmac       $widgetGlobals(fileim)
    set ::tree::machead         $widgetGlobals(machead)
    set ::tree::macheadaway     $widgetGlobals(macheadaway)    
    set ::tree::macheadtalk     $widgetGlobals(macheadtalk)
    
    set ::tree::macheadunav     $widgetGlobals(macheadunav)
    set ::tree::macheadsleep    $widgetGlobals(macheadsleep)
    set ::tree::macheadgray     $widgetGlobals(macheadgray)
    set ::tree::dndim           $widgetGlobals(dndim)
    set ::tree::naim            $widgetGlobals(naim)
    set ::tree::questmark       $widgetGlobals(questmark)
    set ::tree::macheadinv      $widgetGlobals(macheadinv)
    
    set ::tree::macheadwb       $widgetGlobals(macheadwb)
    set ::tree::macheadtalkwb   $widgetGlobals(macheadtalkwb)    
    set ::tree::macheadawaywb   $widgetGlobals(macheadawaywb)    
    set ::tree::macheadinvwb    $widgetGlobals(macheadinvwb)    
    set ::tree::macheadunavwb   $widgetGlobals(macheadunavwb)     
    set ::tree::macheadsleepwb  $widgetGlobals(macheadsleepwb)    
    set ::tree::questmarkwb     $widgetGlobals(questmarkwb)    
    set ::tree::macheadgraywb   $widgetGlobals(macheadgraywb)    
}

# ::tree::Init --
#
#       Contains initializations needed for the tree widget. It is
#       only necessary to invoke it for the first instance of a widget since
#       all stuff defined here are common for all widgets of this type.
#       
# Arguments:
#       none.
# Results:
#       Defines option arrays and icons for the tree widget.

proc ::tree::Init { } {
    global  tcl_platform
    
    variable widgetGlobals
    variable widgetOptions
    variable widgetCommands
    variable canvasOptions
    variable frameOptions
    
    if {$widgetGlobals(debug) > 1}  {
	puts "tree::Init"
    }
    
    # List all allowed options with their database names and class names.
    
    array set widgetOptions {
	-background          {background           Background          }
	-buttonpresscommand  {buttonPressCommand   ButtonPressCommand  }
	-buttonpressmillisec {buttonPressMillisec  ButtonPressMillisec }
	-doubleclickcommand  {doubleClickCommand   DoubleClickCommand  }
	-font                {font                 Font                }
	-fontdir             {fontDir              FontDir             }
	-highlightbackground {highlightBackground  HighlightBackground }
	-highlightcolor      {highlightColor       HighlightColor      }
	-highlightthickness  {highlightThickness   HighlightThickness  }
	-height              {height               Height              }
	-opencommand         {openCommand          OpenCommand         }
	-openicons           {openIcons            OpenIcons           }
	-pyjamascolor        {pyjamasColor         PyjamasColor        }
	-rightclickcommand   {rightClickCommand    RightClickCommand   }
	-scrollwidth         {scrollWidth          ScrollWidth         }
	-selectbackground    {selectBackground     SelectBackground    }
	-selectcommand       {selectCommand        SelectCommand       }
	-selectforeground    {selectForeground     SelectForeground    }
	-selectmode          {selectMode           SelectMode          }
	-silent              {silent               Silent              }
	-sortorder           {sortOrder            SortOrder           }
	-treecolor           {treeColor            TreeColor           }
	-width               {width                Width               }
	-xscrollcommand      {xScrollCommand       ScrollCommand       }
	-yscrollcommand      {yScrollCommand       ScrollCommand       }
    }

    # Which of these apply directly to the canvas widget? 
    # '-scrollregion' treated separately.
    set canvasOptions {-background -height   \
      -scrollregion -width -xscrollcommand -yscrollcommand}
    
    set frameOptions {-highlightbackground -highlightcolor -highlightthickness}
  
    # The legal widget commands.
    set widgetCommands {cget children closetree configure delitem   \
      getselection getcanvas isitem itemconfigure labelat newitem opentree   \
      setselection xview yview}

    # Options for this widget
    option add *Tree.background            #dedede         widgetDefault
    option add *Tree.buttonPressCommand    {}              widgetDefault
    option add *Tree.buttonPressMillisec   1000            widgetDefault
    option add *Tree.highlightBackground   white           widgetDefault
    option add *Tree.highlightColor        black           widgetDefault
    option add *Tree.highlightThickness    3               widgetDefault
    option add *Tree.height                100             widgetDefault
    option add *Tree.openIcons             plusminus       widgetDefault
    option add *Tree.openCommand           {}              widgetDefault
    option add *Tree.pyjamasColor          white           widgetDefault
    option add *Tree.rightClickCommand     {}              widgetDefault
    option add *Tree.scrollWidth           200             widgetDefault
    option add *Tree.selectBackground      black           widgetDefault
    option add *Tree.selectForeground      white           widgetDefault
    option add *Tree.selectMode            1               widgetDefault
    option add *Tree.silent                0               widgetDefault
    option add *Tree.sortOrder             {}              widgetDefault
    option add *Tree.treeColor             gray50          widgetDefault
    option add *Tree.width                 100             widgetDefault
    option add *Tree.xScrollCommand        {}              widgetDefault
    option add *Tree.yScrollCommand        {}              widgetDefault
    
    # Platform specifics...
    switch $tcl_platform(platform) {
	unix {
	    set widgetGlobals(font)             {Helvetica 10 normal}
	    set widgetGlobals(fontbold)         {Helvetica 10 bold}
	    set widgetGlobals(fontitalic)       {Helvetica 10 italic}
	}
	windows {
	    set widgetGlobals(font)             {Arial 8 normal}
	    set widgetGlobals(fontbold)         {Arial 8 bold}
	    set widgetGlobals(fontitalic)       {Arial 8 italic}
	}
	macintosh {
	    set widgetGlobals(font)             {Geneva 9 normal}
	    set widgetGlobals(fontbold)         {Geneva 9 bold}
	    set widgetGlobals(fontitalic)       {Geneva 9 italic}
	}
    }
    option add *Tree.font               $widgetGlobals(font)
    option add *Tree.fontDir            $widgetGlobals(fontbold)
        
    # Some platform specific drawing issues.
    switch $tcl_platform(platform) {
	unix {
	    set widgetGlobals(yTreeOff) 1
	}
	windows {
	    set widgetGlobals(yTreeOff) 1
	}
	macintosh {
	    set widgetGlobals(yTreeOff) 0
	}
    }
    
    # Define the class bindings.
    # This allows us to clean up some things when we go away.
    bind Tree <Destroy> [list ::tree::DestroyHandler %W]
    if {$widgetGlobals(debug) > 1}  {
	puts "tree::Init on exit"
    }
}

# ::tree::tree --
#
#       The constructor of this class; it creates an instance named 'w' of the
#       tree widget. 
#       
# Arguments:
#       w       the widget path.
#       args    (optional) list of key value pairs for the widget options.
# Results:
#       The widget path or an error. Calls the necessary procedures to make a 
#       complete tree widget.

proc ::tree::tree {w args} {
    
    variable widgetOptions
    variable widgetGlobals
    variable canvasOptions
    variable frameOptions
    
    if {$widgetGlobals(debug) > 1} {
	puts "::tree::tree w=$w, args=$args"
    }
    
    # Perform a one time initialization.
    if {![info exists widgetOptions]} {
	Init
    }
    foreach {name value} $args {
	if {![info exists widgetOptions($name)]} {
	    return -code error "unknown option \"$name\" for the tree widget"
	}
    }

    # Instance specific namespace
    namespace eval ::tree::${w} {
	variable options
	variable widgets
	variable treestate
    }
    
    # Set simpler variable names.
    upvar ::tree::${w}::options options
    upvar ::tree::${w}::widgets widgets
    upvar ::tree::${w}::treestate treestate

    # We use a frame for this specific widget class.
    set widgets(this) [frame $w -class Tree]
    
    # Set only the name here.
    set widgets(canvas) $w.c
    set widgets(frame) ::tree::${w}::${w}
    
    # Necessary to remove the original frame procedure from the global
    # namespace into our own.
    rename ::$w $widgets(frame)
    
    # Parse options. First get widget defaults.
    foreach name [array names widgetOptions] {
	set optName [lindex $widgetOptions($name) 0]
	set optClass [lindex $widgetOptions($name) 1]
	set options($name) [option get $w $optName $optClass]
	if {$widgetGlobals(debug) > 3} {
	    puts "   name=$name, optName=$optName, optClass=$optClass"
	}
    }

    # Need to translate '-scrollwidth' to '-scrollregion'.
    set options(-scrollregion)   \
      [list 0 0 $options(-scrollwidth) $options(-height)]
    
    # Apply the options supplied in the widget command.
    # Overwrites defaults when option set in command.
    if {[llength $args] > 0}  {
	array set options $args
    }
    
    # Verify that '-scrollwidth' is at least '-width'.
    if {$options(-scrollwidth) < $options(-width)} {
	set options(-scrollwidth) $options(-width)
    }
    
    # Create the actual widget procedure.
    proc ::${w} {command args}   \
      "eval ::tree::WidgetProc {$w} \$command \$args"
    
    # Get the actual canvas options.
    set canOpts {}
    foreach name $canvasOptions {
	lappend canOpts $name $options($name)
    }
    
    # The frame takes care of the focus stuff since any focus ring in
    # the canvas is drawn inside it!
    eval canvas $widgets(canvas) $canOpts -highlightthickness 0
    pack $widgets(canvas) -fill both -expand 1
    
    # Find the frame options.
    set frameOpts {}
    foreach name $frameOptions {
	lappend frameOpts $name $options($name)
    }
    if {[llength $frameOpts] > 0} {
	eval $widgets(frame) configure $frameOpts
    }

    # Some more inits.
    ::tree::DfltConfig $w {}
    set treestate(selection) {}
    set treestate(oldselection) {}
    set treestate(selidx) {}
    
    # Provide some default bindings.
    bind $widgets(canvas) <Double-1>   \
      [list ::tree::ButtonDoubleClickCmd $w %x %y]
    bind $widgets(canvas) <Button-1>   \
      [list ::tree::ButtonClickCmd $w %x %y]
    bind $widgets(canvas) <Key-Up> [list ::tree::SelectNext $w -1]
    bind $widgets(canvas) <Key-Down> [list ::tree::SelectNext $w +1]
    bind $widgets(canvas) <ButtonRelease-1> [list ::tree::ButtonRelease $w]
    
    if {[llength $options(-rightclickcommand)]} {
	bind $widgets(canvas) <Button-3>   \
	  [list ::tree::Button3ClickCmd $w %x %y]
    }
    
    # And finally... build.
    BuildWhenIdle $w
    
    return $w
}

# ::tree::ButtonClickCmd --
#
#       Collection of calls to bind <Button-1>.
#       
# Arguments:
#       w       the widget path.
#       x
#       y
#       
# Results:
#

proc ::tree::ButtonClickCmd {w x y} {
    
    upvar ::tree::${w}::options options
    upvar ::tree::${w}::treestate treestate
    upvar ::tree::${w}::widgets widgets
    
    focus $widgets(canvas)
    
    set thetags [$widgets(canvas) itemcget current -tags]
    if {$options(-selectmode) && ([lsearch $thetags x] >= 0)} {
	SelectCmd $w $x $y	    
    } elseif {([lsearch $thetags topen] >= 0) ||    \
      ([lsearch $thetags tclose] >= 0)} {
	set can $widgets(canvas)
	set x [$can canvasx $x]
	set y [$can canvasy $y]
	set lbl {}
	foreach id [$can find overlapping 0 $y 200 $y] {
	    if {[info exists treestate(tag:$id)]} {
		set lbl $treestate(tag:$id)
		break
	    }
	}
	if {[string length $lbl]} {
	    if {[lsearch $thetags topen] >= 0} {
		set treestate($lbl:open) 0
	    } else {
		set treestate($lbl:open) 1
	
		# Evaluate any open command callback.
		if {[llength $options(-opencommand)]} {
		    uplevel #0 "$options(-opencommand) [list $w $lbl]"
		}
	    }
	    Build $w
	}
    } else {
	RemoveSelection $w
    }
    if {[llength $options(-buttonpresscommand)]} {
	
	# Set timer for this callback.
	if {[info exists treestate(afterid)]} {
	    catch {after cancel $treestate(afterid)}
	}
	set v [LabelAt $w $x $y]
	set treestate(afterid) [after $options(-buttonpressmillisec)  \
	  [list ::tree::ButtonPress $w $v $x $y]]
    }
}

proc ::tree::ButtonDoubleClickCmd {w x y} {
    
    upvar ::tree::${w}::options options
    upvar ::tree::${w}::widgets widgets

    set thetags [$widgets(canvas) itemcget current -tags]
    if {[lsearch $thetags x] >= 0} {
	OpenTreeCmd $w $x $y   
    }
    if {[llength $options(-doubleclickcommand)]} {
	set v [LabelAt $w $x $y]
	uplevel #0 "$options(-doubleclickcommand) [list $w $v]"
    }
}
    
proc ::tree::Button3ClickCmd {w x y} {
    
    upvar ::tree::${w}::options options

    set v [LabelAt $w $x $y]
    uplevel #0 "$options(-rightclickcommand) [list $w $v $x $y]"
}
    
proc ::tree::ButtonPress {w v x y} {
    
    upvar ::tree::${w}::options options

    uplevel #0 "$options(-buttonpresscommand) [list $w $v $x $y]"
}

proc ::tree::ButtonRelease {w} {
    
    upvar ::tree::${w}::treestate treestate

    if {[info exists treestate(afterid)]} {
	catch {after cancel $treestate(afterid)}
    }
}

# ::tree::WidgetProc --
#
#       This implements the methods, cget, configure etc.
#       
# Arguments:
#       w       the widget path.
#       command the actual command; cget, configure etc.
#       args    list of key value pairs for the widget options.
#       
# Results:
#

proc ::tree::WidgetProc {w command args} {
    
    variable widgetGlobals
    variable widgetOptions
    variable widgetCommands
    upvar ::tree::${w}::options options
    upvar ::tree::${w}::treestate treestate
    upvar ::tree::${w}::widgets widgets
    
    if {$widgetGlobals(debug) > 2} {
	puts "::tree::WidgetProc w=$w, command=$command, args=$args"
    }
    set result {}
    
    # Which command?
    switch -- $command {
	cget {
	    if {[llength $args] != 1} {
		return -code error "wrong # args: should be $w cget option"
	    }
	    set result $options($args)
	}
	children {
	    if {[llength $args] != 1} {
		return -code error "wrong # args: should be $w children itemPath"
	    }
	    set v [lindex $args 0]
	    if {[info exists treestate($v:children)]} {
		set result $treestate($v:children)
	    } else {
		#return -code error "parent \"$v\" does not exist"
		# Silent?
		set result {}
	    }
	}
	closetree {
	    set result [eval CloseTree $w $args]
	}
	configure {
	    set result [eval Configure $w $args]
	}
	delitem {
	    set result [eval DelItem $w $args]
	}
	find {
	    if {[string equal [lindex $args 0] "withtag"]} {
		
		# Search '$treestate($vxc:tags)' for matches.
		# Is there a smarter way?
		set ftag [lindex $args 1]
		set vlist {}
		foreach {key val} [array get treestate "*:tags"] {
		    if {[string equal $val $ftag]} {
			set ind [expr [string last ":tags" $key] - 1]
			lappend vlist [string range $key 0 $ind]
		    }
		}
		return $vlist
	    } else {
		return -code error "unrecognized subcommand. Must be \"find withtag\""
	    }
	}
	getselection {
	    set result [eval GetSelection $w]
	}
	getcanvas {
	    set result $widgets(canvas)
	}
	isitem {
	    set result [eval {IsItem $w} $args]
	}
	itemconfigure {
	    set result [eval {ConfigureItem $w} $args]
	}
	labelat {
	    set result [eval LabelAt $w $args]
	}
	newitem {
	    set result [eval NewItem $w $args]
	}
	opentree {
	    set result [eval OpenTree $w $args]
	}
	setselection {
	    set result [eval SetSelection $w $args]
	}
	xview {
	    if {[llength $args] == 0} {
		set result [$widgets(canvas) xview]
	    } else {
		eval {$widgets(canvas) xview} $args
	    }
	}
	yview {
	    if {[llength $args] == 0} {
		set result [$widgets(canvas) yview]
	    } else {
		eval {$widgets(canvas) yview} $args
	    }
	}
	default {
	    return -code error "unknown command \"$command\" of the tree widget.\
	      Must be one of $widgetCommands"
	}
    }
    return $result
}

# ::tree::Configure --
#
#       Implements the "configure" widget command (method). 
#       
# Arguments:
#       w       the widget path.
#       args    list of key value pairs for the widget options.
# Results:
#

proc ::tree::Configure {w args} {
    
    variable widgetGlobals
    variable widgetOptions
    variable canvasOptions
    variable frameOptions
    upvar ::tree::${w}::options options
    upvar ::tree::${w}::widgets widgets
    upvar ::tree::${w}::treestate treestate
    
    if {$widgetGlobals(debug) > 1} {
	puts "::tree::Configure w=$w, args='$args'"
    }
    
    # Error checking.
    foreach {name value} $args {
	if {![info exists widgetOptions($name)]}  {
	    return -code error "unknown option for the tree widget: $name"
	}
    }
    if {[llength $args] == 0} {
	
	# Return all options.
	foreach opt [lsort [array names widgetOptions]] {
	    set optName [lindex $widgetOptions($opt) 0]
	    set optClass [lindex $widgetOptions($opt) 1]
	    set def [option get $w $optName $optClass]
	    lappend results [list $opt $optName $optClass $def $options($opt)]
	}
	return $results
    } elseif {[llength $args] == 1} {
	
	# Return configuration value for this option.
	set opt $args
	set optName [lindex $widgetOptions($opt) 0]
	set optClass [lindex $widgetOptions($opt) 1]
	set def [option get $w $optName $optClass]
	return [list $opt $optName $optClass $def $options($opt)]
    }
    
    # Error checking.
    if {[expr {[llength $args]%2}] == 1} {
	return -code error "value for \"[lindex $args end]\" missing"
    }    

    # Process the new configuration options.
    array set argsarr $args
    
    # Process the configuration options given to us.
    foreach opt [array names argsarr] {
	set newValue $argsarr($opt)
	set oldValue $options($opt)
	switch -- $opt {
	    -rightclickcommand {
		if {[llength $newValue]} {
		    bind $widgets(canvas) <Button-3>   \
		      [list ::tree::Button3ClickCmd $w %x %y]
		} else {
		    bind $widgets(canvas) <Button-3> {}
		}
	    }
	    -selectmode {
		if {$newValue} {

		} else {
		    RemoveSelection $w
		}
	    }
	    -sortorder {
		
		if {[string compare $newValue $oldValue] != 0} {
		    
		    # Here we need to go through all 'children' and sort.
		    
		}
	    }
	}
    }
    
    # Apply the options supplied in the widget command.
    # Overwrites defaults when option set in command.
    if {[llength $args] > 0}  {
	array set options $args
    }
    
    # Verify that '-scrollwidth' is at least '-width'.
    if {$options(-scrollwidth) < $options(-width)} {
	set options(-scrollwidth) $options(-width)
    }

    # Need to translate '-scrollwidth' to '-scrollregion'.
    set options(-scrollregion)   \
      [list 0 0 $options(-scrollwidth) $options(-height)]
    
    # Find the canvas options.
    set canvasArgs {}
    foreach name $canvasOptions {
	if {[info exists argsarr($name)]} {
	    lappend canvasArgs $name $argsarr($name)
	}
    }
    if {[llength $canvasArgs] > 0} {
	eval $widgets(canvas) configure $canvasArgs
    }
    
    # Find the frame options.
    set frameArgs {}
    foreach name $frameOptions {
	if {[info exists argsarr($name)]} {
	    lappend frameArgs $name $argsarr($name)
	}
    }
    if {[llength $frameArgs] > 0} {
	eval $widgets(frame) configure $frameArgs
    }

    # And finally... build.
    if {[llength $canvasArgs] < [llength $args]} {
	BuildWhenIdle $w
    }

    return {}
}

# Initialize a element of the tree.
# Internal use only
#

proc ::tree::DfltConfig {w v} {

    upvar ::tree::${w}::treestate treestate
    
    set treestate($v:children) {}
    set treestate($v:open) 1
    set treestate($v:icon) {}
    set treestate($v:tags) {}
    set treestate($v:text) [FileTree tail $v]
    set treestate($v:bg) {}
}

# ::tree::ConfigureItem --
#
#       Configure an element $v in the tree $w.
#       
# Arguments:
#       w       the widget path.
#       v       the item as a list.
#       args    list of '-key value' pairs for the item.
#       
# Results:
#       new tree is built.

proc ::tree::ConfigureItem {w v args} {
    
    variable widgetGlobals
    upvar ::tree::${w}::treestate treestate
    
    if {$widgetGlobals(debug) > 1} {
	puts "::tree::ConfigureItem w=$w, v='$v', args='$args'"
    }
    set dir [FileTree dirname $v]
    set n [FileTree tail $v]
    
    set i [lsearch -exact $treestate($dir:children) $n]
    if {$i == -1} {
	return -code error "item \"$v\" doesn't exist"
    }
    
    if {[llength $args] == 0} {
	return -code error {Usage: "pathName itemconfigure treeItem ?-key? ?value?"}
    } elseif {[llength $args] == 1} {
	
	# If only one -key and no value, return present value.
	set op [lindex $args 0]
	switch -exact -- $op {
	    -background {
		if {[info exists treestate($v:bg)]} {
		    set result $treestate($v:bg)
		} else {
		    set result {}
		}
	    }
	    -dir {
		if {[info exists treestate($v:dir)]} {
		    set result $treestate($v:dir)
		} elseif {[string length $treestate($v:children)]} {
		    set result 1
		} else {
		    set result 0
		}
	    }
	    -image {
		set result $treestate($v:icon)
	    }
	    -open {
		set result $treestate($v:open)
	    }
	    -style {
		set result $treestate($v:style)
	    }
	    -tags {
		set result $treestate($v:tags)
	    }
	    -text {
		set result $treestate($v:text)
	    }
	    default {
		return -code error "unknown option \"$op\" to itemconfigure"
	    }
	    return $result
	} 
    } else {
	foreach {op arg} $args {
	    switch -exact -- $op {
		-background {
		    set treestate($v:bg) $arg
		}
		-dir {
		    set treestate($v:dir) $arg
		}
		-image {
		    set treestate($v:icon) $arg
		}
		-open {
		    set treestate($v:open) $arg
		}
		-style {
		    if {[regexp {(normal|bold|italic)} $arg]} {
			set treestate($v:style) $arg
		    } else {
			return -code error "Use -style normal|bold|italic"
		    }
		}
		-tags {
		    set treestate($v:tags) $arg
		}
		-text {
		    set treestate($v:text) $arg
		}
		default {
		    return -code error "unknown option \"$op\" to itemconfigure"
		}
	    } 
	}
	if {[string length $treestate($v:text)] == 0} {
	    set treestate($v:text) [FileTree tail $v]
	}
	BuildWhenIdle $w
	return {}
    }
}

proc ::tree::IsItem {w v} {
    
    upvar ::tree::${w}::treestate treestate

    if {[info exists treestate($v:children)]} {
	return 1
    } else {
	return 0
    }
}

# ::tree::NewItem --
#
#       Insert a new element $v into the tree $w.
#       
# Arguments:
#       w       the widget path.
#       v       the item as a list.
#       args    list of '-key value' pairs for the item.
#       
# Results:
#       new tree is built.

proc ::tree::NewItem {w v args} {

    upvar ::tree::${w}::options options
    upvar ::tree::${w}::treestate treestate
    
    set dir [FileTree dirname $v]
    set n [FileTree tail $v]
    if {![info exists treestate($dir:open)]} {
	return -code error "parent item \"$dir\" is missing"
    }
    set i [lsearch -exact $treestate($dir:children) $n]
    if {$i >= 0} {
	
	# Should we be silent about this?
	if {$options(-silent)} {
	    set treestate($dir:children)  \
	      [lreplace $treestate($dir:children) $i $i $n]
	} else {
	    return -code error "item \"$v\" already exists"
	}
    } else {
	lappend treestate($dir:children) $n
    }
    if {[llength $options(-sortorder)]} {
	set treestate($dir:children)   \
	  [lsort -$options(-sortorder) $treestate($dir:children)]
    }
    DfltConfig $w $v
    foreach {op arg} $args {
	switch -exact -- $op {
	    -dir {
		set treestate($v:dir) $arg
	    }
	    -image {
		set treestate($v:icon) $arg
	    }
	    -open {
		set treestate($v:open) $arg
	    }
	    -style {
		if {[regexp {(normal|bold|italic)} $arg]} {
		    set treestate($v:style) $arg
		} else {
		    return -code error "Use -style normal|bold|italic"
		}
	    }
	    -tags {
		set treestate($v:tags) $arg
	    }
	    -text {
		set treestate($v:text) $arg
	    }
	    -text2 {
		set treestate($v:text2) $arg
	    }
	}
    }
    if {[string length $treestate($v:text)] == 0} {
	set treestate($v:text) [FileTree tail $v]
    }
    BuildWhenIdle $w
}

# ::tree::DelItem --
#
#       Delete element $v from the tree $w.  If $v is "{}", then all content is
#       deleted.
#       
# Arguments:
#       w       the widget path.
#       v       the item as a list.
#       args    (optional) -childsonly 0/1 (D=0)
#       
# Results:
#       new tree is built.

proc ::tree::DelItem {w v args} {
    
    variable widgetGlobals
    upvar ::tree::${w}::treestate treestate
    
    if {$widgetGlobals(debug) > 1} {
	puts "::tree::DelItem w=$w, v='$v'"
    }
    
    if {![info exists treestate($v:open)]} {
	return
    }
    array set opts {-childsonly 0}
    array set opts $args
    if {[llength $v] == 0} {
	
	# Remove all content.
	catch {unset treestate}
	set treestate(selection) {}
	set treestate(oldselection) {}
	set treestate(selidx) {}
	::tree::DfltConfig $w {}
    } else {
	foreach c $treestate($v:children) {
	    catch {DelItem $w [eval "list $v \$c"]}
	}
	if {$opts(-childsonly) == 0} {
	    unset treestate($v:open)
	    unset treestate($v:children)
	    unset treestate($v:icon)
	    unset treestate($v:text)
	    set dir [FileTree dirname $v]
	    set n [FileTree tail $v]
	    set i [lsearch -exact $treestate($dir:children) $n]
	    if {$i >= 0} {
		set treestate($dir:children)   \
		  [lreplace $treestate($dir:children) $i $i]
	    }
	}
    }
    BuildWhenIdle $w
}

# These procedures are only used for handling the Button bind commands.

proc ::tree::SelectCmd {w x y} {
    set lbl [LabelAt $w $x $y]
    if {[string length $lbl]} {
	SetSelection $w $lbl
    }
}
    
proc ::tree::OpenTreeCmd {w x y} {
    set lbl [LabelAt $w $x $y]
    if {[string length $lbl]} {
	OpenTree $w $lbl
    }
}

proc ::tree::SelectNext {w direction} {
    set lbl [NextLabel $w $direction]
    if {[string length $lbl]} {
	SetSelection $w $lbl
    }
}
    
# ::tree::SetSelection --
#
#       Change the selection to the indicated item.
#       
# Arguments:
#       w       the widget path.
#       v       the item as a list.
#       
# Results:
#       selection highlight drawn.

proc ::tree::SetSelection {w v} {

    variable widgetGlobals
    upvar ::tree::${w}::options options
    upvar ::tree::${w}::treestate treestate
    upvar ::tree::${w}::widgets widgets
    
    if {$widgetGlobals(debug) > 1} {
	puts "::tree::SetSelection w=$w, v=$v"
    }    
    if {([string compare $v $treestate(selection)] != 0) && \
      ([llength $options(-selectcommand)] > 0)} {
	uplevel #0 "$options(-selectcommand) [list $w $v]"
    }
    set treestate(oldselection) $treestate(selection)
    set treestate(selection) $v
    DrawSelection $w
    
    # Modify our view so selection is visible.
    if {[string length $options(-yscrollcommand)] &&   \
      [winfo ismapped $w]} {
	set coords [$widgets(canvas) coords $treestate(selidx)]
	set midysel [expr ([lindex $coords 1] + [lindex $coords 3])/2]
	set scrollregion [$widgets(canvas) cget -scrollregion]
	set scrollheight [lindex $scrollregion 3]
	set yview [$widgets(canvas) yview]
	set ytop [expr [lindex $yview 0] * $scrollheight]
	set ybot [expr [lindex $yview 1] * $scrollheight]
	if {$midysel < [expr $ytop + 15]} {
	    
	    # Be sure to never scroll past the top.
	    if {$midysel < 40} {
		$widgets(canvas) yview moveto 0.0
	    } else {
		$widgets(canvas) yview scroll -1 pages
	    }
	} elseif {$midysel > [expr $ybot - 15]} {
	    $widgets(canvas) yview scroll 1 pages
	}
    }
    
    # Own selection; when lost deselect if same toplevel.
    selection own -command [list ::tree::LostSelection $w] $w
}

# tree::LostSelection --
#
#       Lost selection to other window. Deselect only if same toplevel.

proc ::tree::LostSelection {w} {
    
    if {[winfo toplevel $w] == [winfo toplevel [selection own]]} {
	RemoveSelection $w
    }    
}

# ::tree::GetSelection --
#
#       Retrieve the current selection.
#       
# Arguments:
#       w       the widget path.
#       
# Results:
#       item tree path.

proc ::tree::GetSelection {w} {

    upvar ::tree::${w}::treestate treestate
    
    return $treestate(selection)
}

proc ::tree::RemoveSelection {w} {

    variable widgetGlobals
    upvar ::tree::${w}::options options
    upvar ::tree::${w}::treestate treestate

    if {$widgetGlobals(debug) > 1} {
	puts "::tree::RemoveSelection w=$w"
    }
    if {[llength $options(-selectcommand)] > 0} {
	uplevel #0 "$options(-selectcommand) [list $w {}]"
    }
    set treestate(oldselection) $treestate(selection)
    set treestate(selection) {}
    DrawSelection $w
}
    
# ::tree::Build --
#
#       Draws a completely new tree given the internal state.
#       
# Arguments:
#       w       the widget path.
#       
# Results:
#       new tree is drawn.

proc ::tree::Build {w} {

    variable widgetGlobals
    upvar ::tree::${w}::widgets widgets
    upvar ::tree::${w}::options options
    upvar ::tree::${w}::treestate treestate

    if {$widgetGlobals(debug) > 1} {
	puts "::tree::Build w=$w"
    }    
    set can $widgets(canvas)
    if {[string compare $options(-openicons) {plusminus}] == 0} {
	set widgetGlobals(openbm) $widgetGlobals(openbmplusmin)
	set widgetGlobals(closedbm) $widgetGlobals(closedbmplusmin)	
    } elseif {[string compare $options(-openicons) {triangle}] == 0} {
	set widgetGlobals(openbm) $widgetGlobals(openbmmac)
	set widgetGlobals(closedbm) $widgetGlobals(closedbmmac)	
    } else {
	return -code error "unrecognized value \"$options(-openicons)\" for -openicons"
    }
    $can delete all
    catch {unset treestate(pending)}
    set treestate(y) 10
    BuildLayer $w {} 12
    set h [lindex [$can bbox all] 3]
    if {($h == "") || ($h < $options(-height))} {
	set h $options(-height)
    }
    $can configure -scrollregion [concat 0 0 $options(-scrollwidth) $h]
    DrawSelection $w
}

# ::tree::BuildLayer --
#
#       Build a single layer of the tree on the canvas.  Indent by $in pixels.
#       
# Arguments:
#       w       the widget path.
#       v       the item as a list.
#       in      indention in pixels.
#       
# Results:
#       new tree layer is drawn.

proc ::tree::BuildLayer {w v in} {

    variable widgetGlobals
    upvar ::tree::${w}::widgets widgets
    upvar ::tree::${w}::options options
    upvar ::tree::${w}::treestate treestate
    
    if {$widgetGlobals(debug) > 2} {
	puts "::tree::BuildLayer v=$v, in=$in"
    }
    set can $widgets(canvas)
    set treeCol $options(-treecolor)
    set hasTree 0
    set openbm $widgetGlobals(openbm) 
    set closedbm $widgetGlobals(closedbm) 
    set yTreeOff $widgetGlobals(yTreeOff)
    if {[string length $treeCol]} {
	set hasTree 1
    }
    if {[llength $v] == 0} {
	set vx {}
    } else {
	set vx $v
    }
    set start [expr $treestate(y) - 10]
    set y $treestate(y)
    
    foreach c $treestate($v:children) {
	
	set vxc [eval list $vx \$c]
	set isDir 0
	if {[info exists treestate($vxc:dir)] && ($treestate($vxc:dir) == 1)} {
	    set isDir 1
	}
	set hasChildren 0
	if {[string length $treestate($vxc:children)]} {
	    set hasChildren 1
	    set isDir 1
	}
	set y $treestate(y)
	if {[string length $treestate($vxc:bg)]} {
	    $can create rectangle 0 [expr $y - 7] $options(-scrollwidth)  \
	      [expr $y + 7] -outline {} -fill $treestate($vxc:bg) -tags bg
	}
	
	# This is the "row height".
	incr treestate(y) 17
	if {[llength $options(-pyjamascolor)] > 0} {
	    $can create line 0 [expr $y + 8] $options(-scrollwidth)   \
	      [expr $y + 8] -fill $options(-pyjamascolor) -tags pyj	    
	}
	if {$hasTree} {
	    $can create line $in $y [expr $in + 10] $y -fill $treeCol 
	}
	set icon $treestate($vxc:icon)
	set text $treestate($vxc:text)
	
	# The 'x' means selectable!
	set taglist [list x $treestate($vxc:tags)]
	set x [expr $in + 14]
	if {[string length $icon] > 0} {
	    set id [$can create image $x $y -image $icon -anchor w -tags $taglist]
	    set treestate(tag:$id) $vxc
	    incr x [expr [image width $icon] + 6]
	}
	if {[info exists treestate($vxc:style)]} {
	    set style $treestate($vxc:style)
	    set itemFont $widgetGlobals(font${style}) 
	} else {
	    if {$isDir} {
		set itemFont $options(-fontdir)
	    } else {
		set itemFont $options(-font)
	    }
	}
	set id [$can create text $x $y -text $text -font $itemFont \
	  -anchor w -tags $taglist]
	if {[info exists treestate($vxc:text2)]} {
	    $can create text 140 $y -text $treestate($vxc:text2)  \
	      -font $options(-font) -anchor w
	}
	set treestate(tag:$id) $vxc
	set treestate($vxc:tag) $id
	if {$isDir} {
	    if {$treestate($vxc:open)} {
		set id [$can create image $in $y -image $openbm -tags topen]
		if {$hasChildren} {
		
		    # Call this recursively. 
		    # The number here is the directory offset in x.
		    BuildLayer $w $vxc [expr $in + 14]
		}
	    } else {
		set id [$can create image $in $y -image $closedbm -tags tclose]
	    }
	}
    }
    if {$hasTree} {
	eval {set id [$can create line $in $start $in [expr $y + $yTreeOff]   \
	  -fill $treeCol]}
	$can lower $id
    }
    $can lower pyj
    $can lower bg
}

# ::tree::OpenTree --
#
#       Open a branch of a tree.
#       
# Arguments:
#       w       the widget path.
#       v       the tree to open.
#       
# Results:
#       new tree is drawn.

proc ::tree::OpenTree {w v} {

    variable widgetGlobals
    upvar ::tree::${w}::treestate treestate
    upvar ::tree::${w}::options options
    
    if {$widgetGlobals(debug) > 1} {
	puts "::tree::OpenTree w=$w, v=$v"
    }    
    if {[info exists treestate($v:open)] &&     \
      ($treestate($v:open) == 0) &&             \
      [info exists treestate($v:children)] &&   \
      ([string length $treestate($v:children)] > 0)} {
	set treestate($v:open) 1
	Build $w
	
	# Evaluate any open command callback.
	if {[llength $options(-opencommand)]} {
	    uplevel #0 "$options(-opencommand) [list $w $v]"
	}
    }
}

# ::tree::CloseTree --
#
#       Close a branch of a tree.
#       
# Arguments:
#       w       the widget path.
#       v       the tree to open.
#       
# Results:
#       the corresponding tree is closed.

proc ::tree::CloseTree {w v} {

    upvar ::tree::${w}::treestate treestate
    
    if {[info exists treestate($v:open)] && ($treestate($v:open) == 1)} {
	set treestate($v:open) 0
	Build $w
    }
}

# ::tree::DrawSelection --
#
#       Draw the selection highlight.
#       
# Arguments:
#       w       the widget path.
#       
# Results:
#       none.

proc ::tree::DrawSelection {w} {

    variable widgetGlobals
    upvar ::tree::${w}::widgets widgets
    upvar ::tree::${w}::options options
    upvar ::tree::${w}::treestate treestate
    
    if {$widgetGlobals(debug) > 1} {
	puts "::tree::DrawSelection w=$w"
    }    
    
    # Deselect.
    set can $widgets(canvas)
    if {[string length $treestate(selidx)] > 0} {
	$can delete $treestate(selidx)
	if {[string length $treestate(oldselection)] > 0} {
	    set vold $treestate(oldselection)
	    if {[info exists treestate($vold:tag)]} {
		$can itemconfigure $treestate($vold:tag) -fill black
	    }
	}
    }
    set v $treestate(selection)
    if {[string length $v] == 0} {
	return
    }
    if {![info exists treestate($v:tag)]} {
	return
    }
    
    # Select.
    set bbox [$can bbox $treestate($v:tag)]
    if {[llength $bbox] == 4} {
	set id [eval $can create rectangle $bbox -fill $options(-selectbackground) \
	  {-outline {}}]
	set treestate(selidx) $id
	$can lower $id
	if {[llength [$can find withtag bg]] > 0} {
	    $can raise $id bg
	}
	if {[string equal [$can type $treestate($v:tag)] "text"]} {
	    $can itemconfigure $treestate($v:tag) -fill $options(-selectforeground)
	}
    } else {
	set treestate(selidx) {}
    }
    return {}
}

# Internal use only
# Call ::tree::Build then next time we're idle

proc ::tree::BuildWhenIdle {w} {

    variable widgetGlobals
    upvar ::tree::${w}::treestate treestate
    
    if {$widgetGlobals(debug) > 2} {
	puts "::tree::BuildWhenIdle w=$w"
    }    
    if {![info exists treestate(pending)]} {
	set treestate(pending) 1
	after idle [list ::tree::Build $w]
    }
    return {}
}

# ::tree::LabelAt --
#
#       Return the full pathname of the label for widget $w that is located
#       at real coordinates $x, $y.
#       
# Arguments:
#       w       the widget path.
#       x
#       y
#       
# Results:
#       the label's full pathname, or empty list.

proc ::tree::LabelAt {w x y} {

    upvar ::tree::${w}::widgets widgets
    upvar ::tree::${w}::treestate treestate
    
    set can $widgets(canvas)
    set x [$can canvasx $x]
    set y [$can canvasy $y]
    foreach id [$can find overlapping $x $y $x $y] {
	if {[info exists treestate(tag:$id)]} {
	    return $treestate(tag:$id)
	}
    }
    return {}
}

# ::tree::NextLabel --
#
#       Return the full pathname of the label for widget $w that is located
#       in the line below or above the current selection.
#       
# Arguments:
#       w       the widget path.
#       direction  +1 for below, -1 for above.
#       
# Results:
#       the label's full pathname, or empty list.

proc ::tree::NextLabel {w direction} {
    
    variable widgetGlobals
    upvar ::tree::${w}::treestate treestate
    upvar ::tree::${w}::widgets widgets
    
    if {$widgetGlobals(debug) > 1} {
	puts "::tree::NextLabel w=$w, direction=$direction"
    }
    set selBbox [$widgets(canvas) bbox $treestate(selidx)]
    if {[llength $selBbox] > 0} {
	set yMid   \
	  [expr $direction * 17 + ([lindex $selBbox 1] + [lindex $selBbox 3])/2.0]
	foreach id [$widgets(canvas) find overlapping 10 $yMid 200 $yMid] {
	    if {[$widgets(canvas) type $id] == "text"} {
		if {[info exists treestate(tag:$id)]} {
		    return $treestate(tag:$id)
		}
	    }
	}
    }
    return {}
}

proc ::tree::FileTree {cmd arg} {
    
    if {[string compare $cmd {dirname}] == 0} {
	return [lrange $arg 0 [expr [llength $arg] - 2]]
    } elseif {[string compare $cmd {tail}] == 0} {
	return [lindex $arg end]
    }
}

# ::tree::DestroyHandler --
#
#       The exit handler of a tree.
#       
# Arguments:
#       w       the widget path.
#       
# Results:
#       the internal state is cleaned up, namespace deleted.

proc ::tree::DestroyHandler {w} {

    variable widgetGlobals
    upvar ::tree::${w}::widgets widgets
    
    if {$widgetGlobals(debug) > 1} {
	puts "::tree::DestroyHandler w=$w"
    }
    #set can $widgets(canvas)
    #catch {DelItem $w {}}
    
    # Remove the namespace with the widget.
    namespace delete ::tree::${w}
}
    
#-------------------------------------------------------------------------------

