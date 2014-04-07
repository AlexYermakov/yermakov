# -*- mode: perl -*-

use warnings;
use strict;

# Test modules
use Test::More tests => 12;
use Test::Group;

# Search path for our modules
use FindBin;
use lib "$FindBin::Bin/../../lib";

# Our modules
use getxpath;
use qa;
use ElectricCommander;

# Log file
Test::Group->logfile("$0.log");

# Create the qa utilities object.
my $qa = new qa();

my $commander = new ElectricCommander();
#
use POSIX ();

#-----------------------------------------------------------------
test "Login", sub {
    my $rc = $qa->login();    # Returns 1 for successful login.
    ok( $rc, "Login" );
    BAIL_OUT("Login failed") unless $rc;
};
#----------------------------------------------------------------------
test "CreateConfiguration", sub {
	my $cmd;
    my $out;
    my $got;
	my $jobId;
	
	my $configName = "fullConf";
	my $configDesc = "full configuration";
	
	$cmd = $qa->ectool_command( 
		qq { getPlugin ECSCM-Git } 
	);
	$out = `$cmd`;
	my $project = get_xpath( $out, '//pluginName' );
	ok( $project, "git project returned" );
	
	$cmd = $commander->runProcedure(
		"$project",
        { 
			procedureName => "CreateConfiguration",
			  pollInterval  => '0.2',
			  timeout       => 600,
			  actualParameter => [
				{ actualParameterName => 'config', value => "$configName" },
				{ actualParameterName => 'desc', value => "$configDesc" },
				{ actualParameterName => 'credential', value => "test" }
			  ],
			  credential => [
				{
				  credentialName => 'test',
				  userName => "alex",
				  password => "4321"
				 }
			  ]
		}
	);
	print "$cmd";
	$out = `$cmd`;
	$got = get_xpath( $out, '//outcome' );
    is( $got, "success", "creation job successed" );
	
	# TODO
	# 1. check if config values equal parameters
};
#----------------------------------------------------------------
test "CreateMinimalConfiguration", sub {
	my $cmd;
    my $out;
    my $got;
	my $jobId;

	$cmd = $qa->ectool_command( 
		qq { getPlugin ECSCM-Git } 
	);
	$out = `$cmd`;
	my $project = get_xpath( $out, '//pluginName' );
	
	$cmd = $commander->runProcedure(
		"$project",
        { 
			procedureName => "CreateConfiguration",
			  pollInterval  => '0.2',
			  timeout       => 600,
			  actualParameter => [
				{ actualParameterName => 'config', value => "realMiniConf" },
				{ actualParameterName => 'desc', value => "" },
				{ actualParameterName => 'credential', value => "test" },
			  ],
			  credential => [
				{
				  credentialName => 'test',
				  userName => "",
				  password => "",
				 },
			  ],
		}
	);  
	print "$cmd";
    $out = `$cmd`;
	$got = get_xpath( $out, '//outcome' );
    is( $got, "success", "creation job successed" );
	
	# TODO
	# 1. check if config values equal parameters
};
#----------------------------------------------------------------
test "CreateMinimalConfiguration_UTF8chars", sub {
	my $cmd;
    my $out;
    my $got;
	my $jobId;
	
	$cmd = $qa->ectool_command( 
		qq { getPlugin ECSCM-Git } 
	);
	$out = `$cmd`;
	my $project = get_xpath( $out, '//pluginName' );
	
	$cmd = $commander->runProcedure(
		"$project",
        { 
			procedureName => "CreateConfiguration",
			  pollInterval  => '0.2',
			  timeout       => 600,
			  actualParameter => [
				{ actualParameterName => 'config', value => "Ваня plays Fußball" },
				{ actualParameterName => 'desc', value => "" },
				{ actualParameterName => 'credential', value => "test" },
			  ],
			  credential => [
				{
				  credentialName => 'test',
				  userName => "",
				  password => "",
				 },
			  ],
		}
	);
	print "$cmd";
    $out = `$cmd`;
	$got = get_xpath( $out, '//outcome' );
    is( $got, "success", "creation job successed" );
	
	# TODO
	# 1. check if config values equal parameters
};
#----------------------------------------------------------------
test "DeleteConfiguration", sub {
	my $cmd;
    my $out;
    my $got;
	my $jobId;

	$cmd = $qa->ectool_command( 
		qq { getPlugin ECSCM } 
	);
	$out = `$cmd`;
	my $project = get_xpath( $out, '//pluginName' );
	
	$cmd = $qa->ectool_command( qq{ runProcedure }
		. qq{ "$project"}
		. qq{ --procedureName "DeleteConfiguration"}
		. qq{ --actualParameter config=realMiniConf }
		. qq{ --pollInterval 1}
	);
    $out = `$cmd`;
	$got = get_xpath( $out, '//outcome' );
    is( $got, "success", "DeleteConfiguration" );
	
	# TODO
	# 1. check if config does not exist anymore
};
#----------------------------------------------------------------
sub createCIschedule {
	my $cmd;
    my $out;
    my $got;
	my $jobId;

    my $project = "TestCI";
	my $schedule = POSIX::strftime('%y%m%d%H%M%S', localtime);
	my $procedure = "PrintSome";
	my $propertyId;
	
	my $repo = $_[0];
	my $dest = $_[1];
	my $branch = $_[2];
	my $lsRemote = $_[3];

	# TODO: check if the schedule with the specified name does not exist in the project (before we try to create it)
	
	$cmd = $qa->ectool_command( qq{ createSchedule "$project" "$schedule" }
		. qq{ --procedureName "$procedure"}
	); 
	$out = `$cmd`;
	my $scheduleId = get_xpath( $out, '//scheduleId' );
	ok( $scheduleId, "Returned a schedule Id" );
	
	###### Set formType
	$cmd = $qa->ectool_command( qq{ setProperty /projects/$project/schedules/$schedule/ec_customEditorData/formType }
		. qq{ --value \\$[/plugins/ECSCM-Git/project/scm_form/sentry] }
	);
	$out = `$cmd`;
	$propertyId = get_xpath( $out, '//propertyId' );
	ok( $propertyId, "Returned a property Id" );
	
	###### Set scmConfig
	$cmd = $qa->ectool_command( qq{ setProperty /projects/$project/schedules/$schedule/ec_customEditorData/scmConfig }
		. qq{ --value gitconf }
	);
	$out = `$cmd`;
	$propertyId = get_xpath( $out, '//propertyId' );
	ok( $propertyId, "Returned a property Id" );
	
	###### Set GitRepo
     $cmd = $qa->ectool_command( qq{ setProperty ec_customEditorData/GitRepo }
          . qq{ --value $repo }
          . qq{ --projectName "$project" }
          . qq{ --scheduleName "$schedule"}
     );
     $out = `$cmd`;
     $propertyId = get_xpath( $out, '//propertyId' );
     ok( $propertyId, "Returned a property Id" );
     
     ###### Set dest
     $cmd = $qa->ectool_command( qq{ setProperty ec_customEditorData/dest }
          . qq{ --value $dest }
          . qq{ --projectName "$project" }
          . qq{ --scheduleName "$schedule"}
     );
     $out = `$cmd`;
     $propertyId = get_xpath( $out, '//propertyId' );
     ok( $propertyId, "Returned a property Id" );
     
     ###### Set GitBranch
     $cmd = $qa->ectool_command( qq{ setProperty ec_customEditorData/GitBranch }
          . qq{ --value $branch }
          . qq{ --projectName "$project" }
          . qq{ --scheduleName "$schedule"}
     );
     $out = `$cmd`;
     $propertyId = get_xpath( $out, '//propertyId' );
     ok( $propertyId, "Returned a property Id" );
     
     ###### Set lsRemote
     $cmd = $qa->ectool_command( qq{ setProperty ec_customEditorData/lsRemote }
          . qq{ --value $lsRemote }
          . qq{ --projectName "$project" }
          . qq{ --scheduleName "$schedule"}
     );
     $out = `$cmd`;
     $propertyId = get_xpath( $out, '//propertyId' );
     ok( $propertyId, "Returned a property Id" );
     
     ###### Set monitorTags
     $cmd = $qa->ectool_command( qq{ setProperty ec_customEditorData/monitorTags }
          . qq{ --value 1 }
          . qq{ --projectName "$project" }
          . qq{ --scheduleName "$schedule"}
     );
     $out = `$cmd`;
     $propertyId = get_xpath( $out, '//propertyId' );
     ok( $propertyId, "Returned a property Id" );
     
     ###### Set TriggerFlag
     $cmd = $qa->ectool_command( qq{ setProperty ec_customEditorData/TriggerFlag }
          . qq{ --value 2 }
          . qq{ --projectName "$project" }
          . qq{ --scheduleName "$schedule"}
     );
     $out = `$cmd`;
     $propertyId = get_xpath( $out, '//propertyId' );
     ok( $propertyId, "Returned a property Id" );
	 
	 ### Run the CI schedule
	 $cmd = $qa->ectool_command( qq{ runProcedure }
		. qq{ "$project"}
		. qq{ --procedureName $procedure }
		. qq{ --scheduleName $schedule }
		. qq{ --pollInterval 1 }
	); 
    $out = `$cmd`;
	$got = get_xpath( $out, '//outcome' );
    is( $got, "success", "Run CI schedule" );
	
	# TODO: 
	# 1. check if the properties are set correctly 
};
#----------------------------------------------------------------
test "CISchedule_BranchMaster", sub {
	&createCIschedule("https://github.com/AlexYermakov/yermakov.git", "/usr/gitrep", "master", 0 );
};
#----------------------------------------------------------------
test "CISchedule_lsRemote", sub {
	&createCIschedule("https://github.com/AlexYermakov/yermakov.git", "/usr/gitrep", "master", 1 );
};
#----------------------------------------------------------------
test "CISchedule_BranchDoesNotExist", sub {
	&createCIschedule("https://github.com/AlexYermakov/yermakov.git", "/usr/gitrep", "unknownBranch", 0 );
};
#----------------------------------------------------------------
test "CISchedule_RepoNotExist", sub {
	&createCIschedule("https://github.com/thisrepodoesnotexist/wow.git", "/usr/gitrep", "master", 0 );
};
#----------------------------------------------------------------
test "CISchedule_Bitbucket", sub {
	&createCIschedule("https://bitbucket.org/aiermakov/gitest.git", "/usr/bbrepo", "master", 0 );
};
#----------------------------------------------------------------
test "CISchedule_BitbucketNonExist", sub {
	&createCIschedule("https://bitbucket.org/aiermakov/unknownrepo.git", "/usr/bbrepo", "master", 0 );
};
#----------------------------------------------------------------
# Automation of http://jira.electric-cloud.com/browse/ECPSCMGIT-47
test "Checkout status equals to code returned", sub {
	my $cmd;
    my $out;
    my $got;
	
	my $project = "TestCI";
	my $procedure = "testGitClone";
	my $step = "clone3";
	
	my $gitConf = "gitconf";
	my $branch = "master";
	my $dest = "/usr/gitrep";
	my $repo = "https://github.com/AlexYermakov/yermakov.git";
	my $tag = "";
	my $clone = "1";
	
	# create a procedure with Git clone checkout step
	$cmd = $qa->ectool_command(
		qq { createProcedure $project $procedure }
	  . qq { --workspaceName default }
	);
	$out = `$cmd`;
	$got = get_xpath( $out, '//procedureId' );
	ok( $got, "create a procedure" );
	
	$cmd = $qa->ectool_command( 
		qq{ getPlugin ECSCM-Git } 
	);
	$out = `$cmd`;
	my $gitProject = get_xpath( $out, '//pluginName' );
	
	$cmd = $qa->ectool_command(
		qq { createStep $project $procedure $step }
	  . qq { --subproject $gitProject --subprocedure CheckoutCode }
	  . qq { --resourceName local --workspaceName default }
	  . qq { --actualParameter }
		. qq { config=$gitConf }
		. qq { tag=$tag }
		. qq { dest=$dest }
		. qq { commit="" }
		. qq { GitBranch=$branch }
		. qq { clone=$clone }
		. qq { GitRepo=$repo }
	);
	$out = `$cmd`;
	$got = get_xpath( $out, '//stepId' );
	ok( $got, "create a checkout clone step" );
	
	# run the procedure
	$cmd = $qa->ectool_command(
		qq { runProcedure $project }
	  . qq { --procedureName $procedure }
	  . qq { --pollInterval 1 }
	);
	my $jobId = `$cmd`;
	# check if the job succeed
	$cmd = $qa->ectool_command(
		qq { getJobStatus $jobId }
	);
	$out = `$cmd`;
	$got = get_xpath( $out, '//outcome' );
    is( $got, "success", "run checkout procedure" );
	
	# get the log file path 
	$cmd = $qa->ectool_command(
		qq { getJobDetails $jobId }
	);
	$out = `$cmd`;
	my $logDir = get_xpath( $out, '//unix' );
	print $logDir;
	ok( $logDir, "path returned" );
	# get the log file and open it
	# directory must contain the only one log file
	#my @files = glob "$logDir/*.log";
	#print $files[0];
	#my $file = $files[0];
	#open(LOG, $file) or die("Could not open a job log file.");
	
	# If the log contains fatal: or error: Then returned code must be 0, not 1
	#my $line;
	#foreach $line (<LOG>) {
	#	if (index($line, "fatal:") != -1) {
	#		print "$line contains fatal:\n";
	#	}
	#	if (index($line, "error:") != -1) {
	#		print "$line contains error:\n";
	#	}
	#}
	#close(LOG);
	
};
#----------------------------------------------------------------
# Automation of http://jira/browse/ECPSCMGIT-42 
test "plugin doesn't allow for username without password", sub {
	# ((http|https|ssh|git):\/\/)(\w+\:\w+)(\@)(\w)+
	
};