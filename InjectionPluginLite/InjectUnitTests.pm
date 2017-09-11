use strict;

package InjectUnitTests;

use common;
use List::MoreUtils qw(uniq);


sub execute_command {
    my $command = $_[0];

    foreach my $out (`$command 2>&1`) {
        print "!!$out";
        print rtfEscape( $out );
    }
    error("Unit tests compile failed") if $?;
}
##
## Findls all entries defined in *.swiftdeps for a given group
## Sample group (arg): "provides-nominal" or "provides-member"...
##
sub get_swiftdeps {
    local $/ = "\n";
    my @groupValues = ();
    my $filename = $_[0];
    my $groupName = $_[1];
    open (my $fh," <:raw",  $filename);
    my $section = "";
    while (my $line = <$fh>) {
        if ( (my($newSection) = $line =~ /(.*)\:/) ) {
            last if $section eq $groupName;
            $section = $newSection;
        } elsif ($section eq $groupName) {
           push (@groupValues, $line =~ /-\s*(.*)$/); 
        }
    }
    close $fh;
  return @groupValues;
}

##
## Findls all unit tests files that reference to @referencesToFind
## entries. 
## Returns hash with appended ->{update_unit_files} array of filenames 
## (not filepath).
##
sub get_swiftdeps_references {
    local $/ = "\n";
    my $referencesToFindRef = $_[0];
    my $swift_matchRef = $_[1];
    my @referencesToFind = @{$referencesToFindRef};
    my %swift_match = %{$swift_matchRef};
    return () if (scalar @referencesToFind == 0);
    
    my $referencesUpdatedRegex = join ("|", @referencesToFind);
    while (my ($moduleName, $moduleHash) = each(%swift_match)) {
        if ($moduleHash->{isUnitTestModule}){
            my @testCounterpartFiles = ();
            my $moduleDepsPath = $moduleHash->{outputPath};
            my $findDepsCmd = "grep -rle \"\Q$referencesUpdatedRegex\E\" --include=\"*.swiftdeps\" $moduleDepsPath\n";
            my @outputFind = `$findDepsCmd`;    
            chomp @outputFind;

            foreach my $lineFind (@outputFind) {
                if ( my ($testFileName) = $lineFind =~ /([^\/]*)\.swiftdeps/ ){
                    my @allFiles = @{$moduleHash->{files}};
                    my @file = grep(/\/$testFileName\.swift$/i, @allFiles);
                    push (@testCounterpartFiles, @file);
                }
            }
            if (scalar @testCounterpartFiles > 0){
                $moduleHash->{update_unit_files} = \@testCounterpartFiles;
            }
        }
    }
    return %swift_match;
}

##
## Parses Both swiftc and clang commands into comprehensive hash
##
sub match_swift_clang_commands{
    my $swiftCCommandsRef = $_[0];
    my $clangCommandsRef = $_[1];
    my @swiftCCommands = @{$swiftCCommandsRef};
    my @clangCommands = @{$clangCommandsRef};
    my %modules;

    foreach my $swiftCCommand (@swiftCCommands){
        my ($moduleName) = ($swiftCCommand =~ m/-module-name\s(\S*)\s/);
        my @allFiles = ($swiftCCommand =~ /(\S*\.swift)\s/g);
        $modules{$moduleName} = {} if !exists $modules{$moduleName};
        
        $modules{$moduleName}{files} = \@allFiles;
        $modules{$moduleName}{swiftc} = $swiftCCommand;
    }

    foreach my $clangCommand (@clangCommands){
        my ($moduleName) = ($clangCommand =~ m/([^\/\s]*)\.swiftmodule\s/);
        my ($swiftOutputPath) = ($clangCommand =~ m/\s(\S*)\/([^\/\s]*)\.swiftmodule\s/);
        my $isUnitTestModule = $clangCommand =~ /-framework\sXCTest\s/;
        $modules{$moduleName} = {} if !exists $modules{$moduleName};

        $modules{$moduleName}{isUnitTestModule} = $isUnitTestModule;
        $modules{$moduleName}{outputPath} = $swiftOutputPath;
        $modules{$moduleName}{clang} = $clangCommand;
    }

    return %modules;
}



###
### Custom swiftc response parser. Replacement of generic decode_json to speed up 
### parsing proces, which could be signifficant for bigger projects.
###
sub swiftc_command{
    local $/ = "\n";
    my $swiftcLine = $_[0];
    
    open SWIFTC, "$swiftcLine 2>&1 | ";
    
    my $status = "";
    my @reports = ();
    my $report = {};
    while ( my $line = <SWIFTC> ) {
        if ($line =~ /\"(kind|name|command)\"\:/){
            my ($myKey) = ($line =~ /\s*\"(\S*)\"\:/);
            my ($myValue) = ($line =~ /\:\s*\"([^\"]*)\"/);
            $myValue =~ s/\\\//\//g;
            $report->{$myKey} = $myValue;
            $status = "";
            next;
        }
        if ($line =~ /\"inputs\"\:/){
            $status = "inputs";
            next;
        }
        if ($line =~ /\"\S*\"\:/){
            $status = "";
            next;
        }
        if ($status eq "inputs" && $line =~ /\"(\S*)\"/){
            my ($inputValue) = $1;
            $inputValue =~ s/\\\//\//g;
            my @empty = ();
            $report->{inputs} = \@empty if !exists $report->{inputs};
            push ($report->{inputs}, $inputValue);
            next;
        }
        # Line with single digits begin new section (new JSON)
        next if !($line =~ /^\s*\d+\s*$/);
        
        push (@reports, $report);
        $report = {};
        $status = "";
    }
    ## Insert last section
    push (@reports, $report);
    close SWIFTC;
    return \@reports;
}

##
## Scans all modules to find which swiftc command contained selectedFilePath.
## For found module, it rebuilts it (copies swiftmodule file) and finds all symbols
## that given file introduces. This list of symbols is used to search all files in 
## XCTest modules, that reference at least one symbol. These unit test files are 
## rebuilt. 
## 
## // Sidenote: rebuilding unit test module is required to retrieve full swift build
## command.
##

sub rebuild_project_and_find_unit_tests_commands{
    my $selectedFilePath = $_[0];
    my $swiftcCommandsRef = $_[1];
    my $unitTestsClangCommandsRef = $_[2];
    my $copySwiftModuleCommandsRef = $_[3];
    my @swiftcCommands = @{$swiftcCommandsRef};
    my @unitTestsClangCommands = @{$unitTestsClangCommandsRef};
    my %copySwiftModuleCommands = %{$copySwiftModuleCommandsRef};

    my @unitTestLearnt = ();

    my %hash = match_swift_clang_commands(\@swiftcCommands, \@unitTestsClangCommands);
    my @swiftDepsPaths2 = ();
    my @unitTestFiles = ();
    my @referencesUpdated = ();
    my $implementationCommand = "";
    print "!!Compiling for unit tests...\n";
    while (my ($key, $value) = each(%hash)) {
        my $files = $value->{files};
        my $swiftcLine = $value->{swiftc};
        my $isUnitTestModule = $value->{isUnitTestModule};

        ## Rebuild swift module that includes selectedFilePath
        if (index ($swiftcLine, $selectedFilePath) != -1){
            my $outputs = swiftc_command($swiftcLine);
            execute_command("$copySwiftModuleCommands{$key}");

            foreach my $report (@$outputs){
                my $inputs = $report->{inputs};

                # parse swiftc section output related to selectedFilePath
                if ( grep( /^\Q$selectedFilePath\E$/, @$inputs) ){
                    my $injectionCommand = $report->{command};
                    my ($swiftDepsFile) = ($injectionCommand =~ /(\S*\.swiftdeps)\s/);
                    my $learntInjection = $injectionCommand;
                    $learntInjection =~ s/-filelist\s\S*\s/ @{[join(" ", @{$value->{files}})]} /;
                    $implementationCommand = $learntInjection;

                    @referencesUpdated = (get_swiftdeps($swiftDepsFile, "provides-nominal"), get_swiftdeps($swiftDepsFile, "provides-member"));
                    @referencesUpdated = uniq @referencesUpdated;
                    
                }
            }
        }
    }

    my %unitTestFiles = get_swiftdeps_references(\@referencesUpdated, \%hash);
    while (my ($key, $value) = each(%unitTestFiles)) {
        next if !$value->{update_unit_files};

        my $affected_unit_filesRef = $value->{update_unit_files};
        my @affected_unit_files = @$affected_unit_filesRef;
        @affected_unit_files = grep !/\Q$selectedFilePath\E/, @affected_unit_files;
        next if scalar @affected_unit_files == 0;

        my $filesRef = $value->{files};
        my @files = @$filesRef;
        my $filesToCommand = join(" ", @files);

        my $swiftcLine = $value->{swiftc};
        my $swiftcOutput = swiftc_command($swiftcLine);
        for my $report ( @$swiftcOutput ) {
            ## TODO: depend on intersection between @affected_unit_files and $report->{inputs} 
            my $input = $report->{inputs}[0];
            if ( grep( /^\Q$input\E$/, @affected_unit_files) ){
                @affected_unit_files = grep !/\Q$input\E/, @affected_unit_files;
                my $injectionCommand = $report->{command};
                my $nonFileCommand = $injectionCommand;
                $nonFileCommand =~ s/-filelist\s\S*\s/ $filesToCommand /;
                push (@unitTestLearnt, $nonFileCommand);
            }
        }
    }
    return {"unitTestLearnt" => \@unitTestLearnt, "implementationCommand" => $implementationCommand};
}


##
## Recompiles all unit test files and copy .o files into Bundle package with $outputFilePrefix name patter
## To speed up, $originalFilePath is an existing directory with up-to-date binaries, that can be moved to a bundle
## already executed command (in @unitTestLearnt) does not require any modification (like code coverage stripping).  
##

sub recompile_unit_tests{
    my $unitTestLearntRef = $_[0];
    my $outputFilePrefix = $_[1];
    my $originalFilePath = $_[2];
    my @unitTestLearnt = @{$unitTestLearntRef};
    
    my $obj = ""; 

    # Compile corresponding unit tests
    for my $i (0..$#unitTestLearnt){
        my $line = $unitTestLearnt[$i];
        my $objTest = "$outputFilePrefix$i.o";
        $obj .= " $objTest ";
        my ($oldFile) = $line =~ / -o (\S*)/; 
        $line =~ s@( -o )(.*)$@$1$originalFilePath/$objTest@ or die "Could not locate object file in: $line";
        
        # Disable Code coverage for unit test file
        my $generateStripped = $line =~ s/-profile-generate//g;
        my $converageStripped =$line =~ s/-profile-coverage-mapping//g;

        if ($generateStripped || $converageStripped){
            $line =~ s/([()])/\\$1/g;

            execute_command("time $line");
        }else{
            # Manual rebuild of test file not required (swiftc ensures up-to-date) .o binary
            # Just move .o into expected path

            execute_command("cp $oldFile $originalFilePath$objTest");
        }
    }
    return $obj;
}

1;