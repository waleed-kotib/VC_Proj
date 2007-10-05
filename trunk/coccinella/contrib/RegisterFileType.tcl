# RegisterFileType::RegisterFileType --
#
#       Register a file type on Windows
#
# Author:
#       Kevin Kenny <kennykb@acm.org>.
#       Last revised: 27 Nov 2000, 22:35 UTC
#       Mats Bengtsson
#       $Id: RegisterFileType.tcl,v 1.1 2007-10-05 07:00:14 matben Exp $
#
# Parameters:
#       extension -- Extension (e.g., .tcl) of the new type
#                    being registered.
#       className -- Class name (e.g., "tclfile") of the new type
#       textName  -- Textual name (e.g. "Tcl Script") of the
#                    new type.
#       script    -- Name of the file containing a Tcl script
#                    to run when a file of the given type is
#                    opened.  The script will receive the name
#                    of the file in [lindex $argv 0].
#
# Options:
#       -icon FILENAME,NUMBER
#               Set the icon for files of the new type
#               to be the NUMBER'th icon in the given file.
#               The file must be a full path name.
#       -mimetype TYPE
#               Set the MIME type corresponding to the new
#               file type to the specified string.
#       -new BOOLEAN
#               If BOOLEAN is true, set things up so that
#               the new file type appears in the "New" menu
#               in the Explorer and the system tray.
#       -text BOOLEAN
#               If BOOLEAN is true, the new file type contains
#               plain ASCII text of some sort.  Set the
#               Edit and Print actions to open and print
#               ASCII files.
#
# Results:
#       None.
#
# Side effects:
#       Adds the following keys to the system registry:
#
#       HKEY_CLASSES_ROOT
#         (Extension)           (Default value)         ClassName
#                               "Content Type"          MimeType        [1]
#           ShellNew            "NullFile"              ""              [2]
#         (ClassName)           (Default value)         TextName
#           DefaultIcon         (Default value)         IconName,#      [3]
#           Shell
#             Open
#               command         (Default value)         -SEE BELOW-
#             Edit
#               command         (Default value)         -SEE BELOW-     [4]
#             Print
#               command         (Default value)         -SEE BELOW-     [4]
#         MIME
#           Database
#             Content Type
#               (MimeType)      (Default value)         Extension       [1]
#
#       [1] These values are added only if the -mimetype option is used.
#       [2] This value is added only if the -new option is true.
#       [3] This value is added only if the -icon option is used.
#       [4] These values are added only if the -text option is true.
#
#       The command to open the file consists of three arguments.
#       The first is the name of the current Tcl executable.  The
#       second is the script name, and the third is "%1", which causes
#       the target file to be passed as a command-line argument.
#       The edit command is the command that opens text files, and the
#       print command is the command that prints text files.
#
#----------------------------------------------------------------------
 
if {[tk windowingsystem] ne "win32"} {
    return
}
package require registry

package provide RegisterFileType 1.0

namespace eval RegisterFileType {}

proc RegisterFileType::RegisterFileType {
    extension className textName openCommand args
} {
    
    # extPath is the class path for the file's extension
    
    set extPath "HKEY_CLASSES_ROOT\\$extension"
    registry set $extPath {} $className sz
    
    # classPath is the class path for the file's class
    
    set classPath "HKEY_CLASSES_ROOT\\$className"
    registry set $classPath {} $textName sz
    
    # shellPath is the shell key within classPath
    
    set shellPath "$classPath\\Shell"
    
    # Set up the 'Open' action
    
    registry set "$shellPath\\open\\command" {} $openCommand sz
    
    # Process optional args
    
    foreach {key val} $args {
	switch -exact -- $key {
	    
	    -mimetype {
		
		# Set up the handler for the MIME content type,
		# and add the content type item to the database
		
		registry set $extPath "Content Type" $val sz
		set mimeDbPath "HKEY_CLASSES_ROOT\\MIME\\Database"
		append mimeDbPath "\\Content Type\\" $val
		registry set $mimeDbPath Extension $extension sz
	    }
	    
	    -icon {
		
		# Add the file icon to the shell database
		
		if {![regexp {^(.*),([^,]*)} $val junk file icon]} {
		    error "-icon option requires fileName,iconNumber"
		}
		registry set "$classPath\\DefaultIcon" {} [file nativename $file],$icon sz
	    }
	    
	    -text {
		if {$val} {
		    
		    # Copy the Print action for text files
		    # into the Print action for the new type
		    
		    set textPath "HKEY_CLASSES_ROOT\\txtfile\\Shell"
		    if {![catch {
			registry get "$textPath\\print\\command" {}
		    } pCmd]} {
			registry set "$shellPath\\print\\command" {} $pCmd sz
			registry set "$shellPath\\print" {} &Print sz
			
		    }
		    
		    # Copy the Open action for text files
		    # into the Edit action for the new type.
		    
		    if {![catch {
			registry get "$textPath\\open\\command" {}
		    } eCmd]} {
			registry set "$shellPath\\edit\\command" {} $eCmd sz
			registry set "$shellPath\\edit" {} &Edit sz
		    }
		}
	    }
	    
	    -new {
		if {$val} {
		    
		    # Add the 'NullFile' action to the
		    # shell's New menu
		    
		    registry set "$extPath\\ShellNew" NullFile {} sz
		}
	    }
	    
	    default {
		error "unknown option $key, must be -icon, -mimetype, -new or -text"
	    }
	}
    }
}