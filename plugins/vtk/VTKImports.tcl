#  VTKImports.tcl --
#
#       Glue code for the VTK 3D rendering package.
#
# $Id: VTKImports.tcl,v 1.1 2004-04-25 10:10:15 matben Exp $
#
# The following entries in the arrays need to be filled in.

# Add more supported filetypes as additional extensions and Mac types.
# Hook for adding other packages or plugins
#
#  plugin(packageName,full)        Exact name.
#  plugin(packageName,type)        "Tcl plugin" or "Helper application".
#  plugin(packageName,desc)        A longer description of the package.
#  plugin(packageName,platform)    m: macintosh, u: unix, w: windows.
#  plugin(packageName,trpt,MIME)   (optional) the transport method used,
#                                  which defaults to the built in PUT/GET,
#                                  but can be "url" for certain Mime types
#                                  for the QuickTime package. In that case
#                                  the 'importProc' procedure gets it internally.
#  plugin(packageName,importProc)  which tcl procedure to call when importing... 
#  supportedMimeTypes(packageName) List of all MIME types supported.

# OUTDATED !!!!!!!!!!!!!!!!!!!!!!!!!

if {[string compare $::tcl_platform(platform) "macintosh"] == 0}  {
    return
} elseif {[string compare $::tcl_platform(platform) "windows"] == 0}  {
    if {[catch {load vtktcl}]} {
	return
    }
} elseif {[string compare $::tcl_platform(platform) "unix"] == 0}  {
    if {[catch {load vtktcl}]} {
	return
    }

}

# My home crafted package with some utility files for VTK.
if {[catch {package require TkInteractor} msg]} {
    
    # Should we issue a warning?
}

# This defines the VTK package.
set plugin(vtk,full) vtk
set plugin(vtk,type) {Tcl plugin}
set plugin(vtk,desc) {3D renderer using OpenGL or other 3D library}
set plugin(vtk,platform) uw

# These procs hooks into the whiteboard.
set plugin(vtk,importProc) ::vtkImport::ImportProc
set plugin(vtk,bindProc) ::vtkImport::VTKClickToolButton
set supportedMimeTypes(vtk) {application/vtk}

namespace eval ::vtkImport::  {
    
    variable id
}

# ::vtkImport::ImportProc --
#
#       Imports a VTK file into the whiteboard.
#       
# Arguments:
#       w         the canvas widget path.
#       fileNameOrUrl  the complete path name to the file containing the image or
#                 movie, or it can be a complete URL. If URL then where="own".
#       optList   a list of 'key: value' pairs, resembling the html protocol 
#                 for getting files, but where most keys correspond to a valid
#                 "canvas create" option, and everything is on a single line.
#       where     (optional), "all": write to this canvas and all others,
#                 "other": write only to remote client canvases,
#                 ip number: write only to this remote client canvas and not 
#                 to own,
#                 "own": write only to this canvas and not to any other.
#       
# Results:
#       Shows the image or movie in canvas and initiates transfer to other
#       clients if requested.

proc ::vtkImport::ImportProc  { w fileNameOrUrl optList {where all} }  {
    global  myItpref itno debugLevel
    
    if {$debugLevel > 2} {
	puts "::vtkImport::ImportProc  w=$w, fileNameOrUrl=$fileNameOrUrl"
    }
    set dot_ {\.}

    # Define a standard set of put/import options that may be overwritten by
    # the options in the procedure argument 'optList'.
    # An ordinary file on our disk.
    set fileName $fileNameOrUrl
    set fileTail [file tail $fileName]
    
    array set optArray [list   \
      -mine     [GetMimeTypeFromFileName $fileName]      \
      -size             [file size $fileName]                    \
      -coords           {0 0}                                    \
      -tags             $myItpref/$itno                          ]
    
    # Now apply the 'optList' and possibly overwrite some of the default options.
    if {[llength $optList] > 0}  {
	array set optArray $optList
    }
    
    # Make it as a list for PutFile below.
    set putOpts [array get optArray]
    
    # Extract coordinates and tags which must be there. error checking?
    set x [lindex $optArray(-coords) 0]
    set y [lindex $optArray(-coords) 1]
    set useTag $optArray(-tags)
    
    # VTK render windows are put in frame with class 'VTKFrame'
    # in order to catch mouse events.
    # Strip dots in fileName, " " to _; small chars in pathname.
    
    set fileRoot [string tolower [file rootname [file tail $fileName]]]
    regsub -all $dot_ $fileRoot "" tmp
    regsub -all " " $tmp "_" newName
    
    # We use a frame to put the render window in; used for dragging etc.
    
    set fr ${w}.fr_${newName}${itno}
    if {$where == "all" || $where == "own"}  {
	
	# Make a frame for the VTK widget; need special class to catch mouse events.
	frame $fr -height 1 -width 1 -bg gray40 -class VTKFrame
	
	set width 300
	set height 300
	$fr configure -width [expr $width + 6] -height [expr $height + 6]

	# Added the 'movie' tag just for the tool bindings. Bad???
	$w create window $x $y -anchor nw -window $fr -tags "vtk movie $useTag"
	
	# Instances of VTK objects.
	vtkPolyData PolyData
	vtkCellTypes CellTypes
	vtkDecimatePro deci
	vtkSmoothPolyDataFilter smooth
	vtkCleanPolyData cleaner
	vtkPolyDataConnectivityFilter connect
	vtkTriangleFilter tri
	vtkPolyDataNormals normals

	# Make special widget for VTK to draw in; the rendering widget.
	set frvtk $fr.vtk
	vtkTkRenderWidget $frvtk -width $width -height $height
	BindTkRenderWidget $frvtk
	pack $frvtk -in $fr -padx 3 -pady 3

	# VTK graphics objects.
	vtkCamera camera
	vtkLight light
	vtkRenderer Renderer
	    Renderer SetActiveCamera camera
	    Renderer AddLight light
	set renWin [$frvtk GetRenderWindow]
	$renWin AddRenderer Renderer

	# Create pipeline.
	vtkPolyDataMapper mapper
	    mapper SetInput PolyData
	vtkProperty property
	    property SetColor 0.89 0.81 0.34
	    property SetSpecularColor 1 1 1
	    property SetSpecular 0.3
            property SetSpecularPower 20
	    property SetAmbient 0.2
	    property SetDiffuse 0.8
	vtkActor actor
	    actor SetMapper mapper
	    actor SetProperty property
	vtkTextMapper banner
	    banner SetInput "Mats Bengtsson"
	    banner SetFontFamilyToArial
            banner SetFontSize 18
            banner SetJustificationToCentered       
	vtkActor2D bannerActor
	    bannerActor SetMapper banner
	    [bannerActor GetProperty] SetColor 0 1 0
	    [bannerActor GetPositionCoordinate]   \
		    SetCoordinateSystemToNormalizedDisplay
	    [bannerActor GetPositionCoordinate] SetValue 0.5 0.5
	Renderer AddProp bannerActor

	# Edges.
	vtkFeatureEdges FeatureEdges
	    FeatureEdges SetInput PolyData
	vtkPolyDataMapper FEdgesMapper
	    FEdgesMapper SetInput [FeatureEdges GetOutput]
	    FEdgesMapper SetScalarModeToUseCellData
	vtkActor FEdgesActor
	    FEdgesActor SetMapper FEdgesMapper
	
	# This file should contain VTK code (data).
	if {[info commands reader] != ""} {
	    reader Delete
	}

	# Pick the right reader for this format.
	if {[string match *.g $fileName]} {
	    vtkBYUReader reader
	    reader SetGeometryFileName $fileName
	} elseif {[string match *.stl $fileName]} {
	    vtkSTLReader reader
	    reader SetFileName $fileName
	} elseif {[string match *.vtk $fileName]} {
	    vtkPolyDataReader reader
	    reader SetFileName $fileName
	} elseif {[string match *.cyb $fileName]} {
	    vtkCyberReader reader
	    reader SetFileName $fileName
	} elseif {[string match *.tri $fileName]} {
	    vtkMCubesReader reader
	    reader SetFileName $fileName
	} elseif {[string match *.obj $fileName]} {
	    vtkOBJReader reader
	    reader SetFileName $fileName
	} else {
	    
	    # Unknown format (file extension).
	    puts "Unknown format (file extension) $fileName"
	}

	UpdateUndo "reader"
	UpdateGUI
	
	Renderer ResetCamera
	$renWin Render
    }    

    # Transfer movie file to all other servers.
	
    if {($where != "own") && ([llength [::Network::GetIP to]] > 0)}  {
	
	# The client must detemine how it wants this stuff to be receieved,
	# and respond to 'PutFile' how it wants it (http, RTP...).
	::PutFile::PutFile $fileName $where $putOpts
    }    
    
    # Update 'itno' only when also writing to own canvas!
    if {$where == "all" || $where == "own"}  {
	incr itno
    }
}

# Stealed from the 'Decimate.tcl' file in the VTK distro.

proc ::vtkImport::UpdateUndo {filter} {
    variable CurrentFilter

    set CurrentFilter $filter
    $filter Update
    
    PolyData CopyStructure [$filter GetOutput]
    [PolyData GetPointData] PassData [[$filter GetOutput] GetPointData]
    PolyData Modified

    ReleaseData
}

# Stealed from the 'Decimate.tcl' file in the VTK distro.

proc ::vtkImport::UpdateGUI { } {

    # Update GUI.
    set numNodes [PolyData GetNumberOfPoints]
    set numElements [PolyData GetNumberOfCells]
    PolyData GetCellTypes CellTypes

    Renderer RemoveActor bannerActor
    
    # Check to see whether to add surface model.
    if {[PolyData GetNumberOfCells] <= 0} {
	Renderer AddActor bannerActor
    } else {
	Renderer AddActor actor
	if {0} {

	    # The 'FEdgesActor' makes red and green edges.
	    Renderer AddActor FEdgesActor
	    FeatureEdges SetBoundaryEdges 1
	    FeatureEdges SetFeatureEdges 1
	    FeatureEdges SetNonManifoldEdges 1
	}
    }
    
}

# Stealed from the 'Decimate.tcl' file in the VTK distro.

proc ::vtkImport::ReleaseData { } {
    
    [deci GetOutput] Initialize
    [smooth GetOutput] Initialize
    [cleaner GetOutput] Initialize
    [connect GetOutput] Initialize
    [tri GetOutput] Initialize
}

proc ::vtkImport::VTKClickToolButton {btName} {
    global  wCan debugLevel

    if {$debugLevel > 2} {
	puts "::vtkImport::VTKClickToolButton btName=$btName"
    }

    # Clear old bindings first.
    bind VTKFrame <Button-1> {}
    bind VTKFrame <B1-Motion> {}
    bind VTKFrame <ButtonRelease-1> {}

    switch -- $btName {

	point {

	    # We use the search tag 'vtk' which only works if single VTK
	    # widget in canvas. The tag 'current' seems not to apply
	    # to embedded widgets.

	    bind VTKFrame <Button-1> {
		MarkBbox $wCan 0 vtk
	    }
	    bind VTKFrame <Double-Button-1> {
		::ItemInspector::ItemInspector $wCan vtk
	    }
	}
	move {
	    
	    # Bindings for moving the frame with class 'VTKFrame'.
	    # The frame with the movie the mouse events, not the canvas.
	    # We could have used our own functions instead.

	    bind VTKFrame <Button-1> {
		::CanvasDraw::InitMove $wCan  \
		  [$wCan canvasx [expr [winfo x %W] + %x]]  \
		  [$wCan canvasy [expr [winfo y %W] + %y]] movie
	    }
	    bind VTKFrame <B1-Motion> {
		DoMove $wCan  \
		  [$wCan canvasx [expr [winfo x %W] + %x]]  \
		  [$wCan canvasy [expr [winfo y %W] + %y]] movie
	    }
	    bind VTKFrame <ButtonRelease-1> {
		FinalizeMove $wCan  \
		  [$wCan canvasx [expr [winfo x %W] + %x]]  \
		  [$wCan canvasy [expr [winfo y %W] + %y]] movie
	    }
	}
    }
}
