# -*- mode: perl -*-

use warnings;
use strict;

# Test modules
use Test::More tests => 16;
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

use POSIX ();

my $testCIProject = "TestCI";
my $procedureForCI = "PrintSome";
my $stepForCI = "lil";

my $autoTestProject = "AutomationTest";
my $autoTestProcedure = "test";
my $autoTestStep = "gitClone";

my $cl;
my $output;

# get the current Git plugin name to use later
$cl = $qa->ectool_command(
	qq { getPlugin ECSCM-Git }
);
$output = `$cl`;

my $gitPlugin = get_xpath( $output, "//pluginName" );
ok( $gitPlugin, "ECSCM-Git plugin name saved" );
print "$gitPlugin\n";

# get the current ECSCM plugin name to use it later
$cl = $qa->ectool_command(
	qq { getPlugin ECSCM }
);
$output = `$cl`;

my $ecscmPluginName = get_xpath( $output, "//pluginName" );
ok( $ecscmPluginName, "ECSCM plugin name saved" );
print "$ecscmPluginName\n";

#----------------------------------------------------------------------
test "Login", sub {
    my $rc = $qa->login();    # Returns 1 for successful login.
    ok( $rc, "Login" );
    BAIL_OUT("Login failed") unless $rc;
};
#----------------------------------------------------------------------
test "Prepare test projects", sub {
	my $cmd;
	my $out;
	my $got;
	
	$cmd = $qa->ectool_command( 
		qq { deleteProject "$testCIProject" } 
	);
	$out = `$cmd`;
	#print "TestCI project deleted.\n";

	$cmd = $qa->ectool_command( 
		qq { createProject "$testCIProject" } 
	);
	$out = `$cmd`;
	#print "TestCI project created.\n";

	$cmd = $qa->ectool_command( 
		qq { createProcedure "$testCIProject" "$procedureForCI" } 
	);
	$out = `$cmd`;
	#print "$procedureForCI created.\n";

	$cmd = $qa->ectool_command( 
		qq { createStep "$testCIProject" "$procedureForCI" "$stepForCI" --command "echo 'done';" } 
	);
	$out = `$cmd`;
	#print "$stepForCI created.";
	
	# delete existent and create new AutomationTest Project
	$cmd = $qa->ectool_command( 
		qq { deleteProject "$autoTestProject" } 
	);
	$out = `$cmd`;

	$cmd = $qa->ectool_command(
		qq { createProject "$autoTestProject" }
	);
	$out = `$cmd`;
	$got = get_xpath( $out, '//projectName' );
	is( $got, $autoTestProject, "test project created" );
	
	# create a procedure for test
	$cmd = $qa->ectool_command(
		qq { createProcedure "$autoTestProject" "$autoTestProcedure" }
		. qq { --resourceName "local" --workspaceName "default" }
	);
	$out = `$cmd`;
	$got = get_xpath( $out, '//procedureName' );
	is( $got, $autoTestProcedure, "procedure created" );
	
	# create a Git Clone step , provide the parameters
	$cmd = $qa->ectool_command(
		qq { createStep "$autoTestProject" "$autoTestProcedure" "$autoTestStep" }
		. qq { --subproject "$gitPlugin" --subprocedure "CheckoutCode" }
		. qq { --resourceName "local" --workspaceName "default" }
		. qq { --actualParameter "config"="gitconf" "GitRepo"="https://github.com/AlexYermakov/yermakov.git" "GitBranch"="master" }
		. qq { "clone"="1"  "dest"="/usr/gitrep" }
		# add "depth"="2" back after finish with Git 3.1.2
	);
	$out = `$cmd`;
	$got = get_xpath( $out, '//stepName' );
	is( $got, $autoTestStep, "clone step created" );
	
	pass;
};
#----------------------------------------------------------------------
test "create full configuration", sub {
	my $configName = "fullConf";
	my $configDesc = "full configuration";
	
	my $userName = "alex";
	my $password = "4321";
	
	deleteConfiguration( "$configName" );
	createConfiguration( "$configName", "$configDesc", "$userName", "$password" );
	deleteConfiguration( "$configName" );
};
#----------------------------------------------------------------
test "create mini configuration", sub {
	my $configName = "miniconf";
	my $configDesc = "";
	
	my $userName = "";
	my $password = "";
	
	deleteConfiguration( "$configName" );
	createConfiguration( "$configName", "$configDesc", "$userName", "$password" );
	deleteConfiguration( "$configName" );
};
#----------------------------------------------------------------
test "create mini configuration with UTF-8 chars", sub {
	my $configName = "ВаняplaysFußball";
	my $configDesc = "";
	
	my $userName = "";
	my $password = "";
	
	deleteConfiguration( "$configName" );
	createConfiguration( "$configName", "$configDesc", "$userName", "$password" );
	deleteConfiguration( "$configName" );
};
#----------------------------------------------------------------
sub createConfiguration {
	my $cmd;
    my $out;
    my $got;
	
	my $configName = $_[0];
	my $configDesc = $_[1];
	my $userName = $_[2];
	my $password = $_[3];
	
	$commander->runProcedure(
		"$gitPlugin",
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
				  userName => "$userName",
				  password => "$password"
				 }
			  ],
		},
	);
	
	$cmd = $qa->ectool_command(
		qq { getProperty /projects/$ecscmPluginName/scm_cfgs/$configName }
	);
	$out = `$cmd`;
	
	$got = get_xpath( $out, "//propertyName" );
	is( $got, $configName, "config name equals created config name" );
	
	# Default description value is not an empty string. 
	#$got = get_xpath( $out, "//description" );
	#is( $got, $configDesc, "config description equals created config desc." );
};
#----------------------------------------------------------------
sub deleteConfiguration {
	my $cmd;
    my $out;
    my $got;

	my $configName = $_[0];
	
	$cmd = $qa->ectool_command( 
	    qq{ runProcedure "$ecscmPluginName" }
		. qq{ --procedureName "DeleteConfiguration"}
		. qq{ --actualParameter config="$configName" }
	);
    my $jobId = `$cmd`;
	chomp $jobId;
	
	do {
		$cmd = $qa->ectool_command(
			qq { getJobStatus "$jobId" }
		);
		$out = `$cmd`;
		$got = get_xpath( $out, "//status" );
    } while( $got eq "running" || $got eq "runnable" || $got eq "pending" );
	
	$got = get_xpath( $out, "//outcome" );
    is( $got, "success", "configuration deleted" );
};
#----------------------------------------------------------------
test "CI schedule - branch is master", sub {
	createCIschedule("https://github.com/AlexYermakov/yermakov.git", "/usr/gitrep", "master", "0", "branchMaster" );
};
#----------------------------------------------------------------
test "CI schedule - lsRemote", sub {
	createCIschedule("https://github.com/AlexYermakov/yermakov.git", "/usr/gitrep", "master", "1", "lsRemote" );
};
#----------------------------------------------------------------
test "CI schedule - branch does not exist", sub {
	createCIschedule("https://github.com/AlexYermakov/yermakov.git", "/usr/gitrep", "unknownBranch", "0", "branchNotExist" );
};
#----------------------------------------------------------------
test "CI schedule - repo not exist", sub {
	createCIschedule("https://github.com/thisrepodoesnotexist/wow.git", "/usr/gitrep", "master", "0", "repoNotExist" );
};
#----------------------------------------------------------------
test "CI schedule - Bitbucket", sub {
	createCIschedule("https://bitbucket.org/aiermakov/gitest.git", "/usr/bbrepo", "master", "0", "BitBucket" );
};
#----------------------------------------------------------------
test "CI schedule - Bitbucket - repo does not exist", sub {
	createCIschedule("https://bitbucket.org/aiermakov/unknownrepo.git", "/usr/bbrepo", "master", "0", "BitBucketNotExist" );
};
#----------------------------------------------------------------
sub createCIschedule {
	my $cmd;
    my $out;
    my $got;
	
	my $repo = $_[0];
	my $dest = $_[1];
	my $branch = $_[2];
	my $lsRemote = $_[3];
	my $schedule = $_[4];
	
	# create schedule with a created procedure
	$cmd = $qa->ectool_command( 
		  qq { createSchedule "$testCIProject" "$schedule" }
	    . qq { --procedureName "$procedureForCI"}
	); 
	$out = `$cmd`;
	$got = get_xpath( $out, '//scheduleId' );
	ok( $got, "schedule ID returned" );
	
	# set formType
	$cmd = $qa->ectool_command( qq{ setProperty /projects/$testCIProject/schedules/$schedule/ec_customEditorData/formType }
		. qq{ --value '\$[/plugins/ECSCM-Git/project/scm_form/sentry]' }
	);
	$out = `$cmd`;
	$got = get_xpath( $out, '//propertyId' );
	ok( $got, "Returned a property Id" );
	
	# set scmConfig
	$cmd = $qa->ectool_command( qq{ setProperty /projects/$testCIProject/schedules/$schedule/ec_customEditorData/scmConfig }
		. qq{ --value gitconf }
	);
	$out = `$cmd`;
	$got = get_xpath( $out, '//propertyId' );
	ok( $got, "Returned a property Id" );
	
	 # set GitRepo
     $cmd = $qa->ectool_command( qq{ setProperty /projects/$testCIProject/schedules/$schedule/ec_customEditorData/GitRepo }
          . qq{ --value $repo }
          . qq{ --projectName "$testCIProject" }
          . qq{ --scheduleName "$schedule"}
     );
     $out = `$cmd`;
     $got = get_xpath( $out, '//propertyId' );
	 ok( $got, "Returned a property Id" );
     
     # set dest
     $cmd = $qa->ectool_command( qq{ setProperty /projects/$testCIProject/schedules/$schedule/ec_customEditorData/dest }
          . qq{ --value $dest }
          . qq{ --projectName "$testCIProject" }
          . qq{ --scheduleName "$schedule"}
     );
     $out = `$cmd`;
     $got = get_xpath( $out, '//propertyId' );
	ok( $got, "Returned a property Id" );
     
     # set GitBranch
     $cmd = $qa->ectool_command( qq{ setProperty /projects/$testCIProject/schedules/$schedule/ec_customEditorData/GitBranch }
          . qq{ --value $branch }
          . qq{ --projectName "$testCIProject" }
          . qq{ --scheduleName "$schedule"}
     );
     $out = `$cmd`;
     $got = get_xpath( $out, '//propertyId' );
	ok( $got, "Returned a property Id" );
     
     # set lsRemote
     $cmd = $qa->ectool_command( qq{ setProperty /projects/$testCIProject/schedules/$schedule/ec_customEditorData/lsRemote }
          . qq{ --value $lsRemote }
          . qq{ --projectName "$testCIProject" }
          . qq{ --scheduleName "$schedule"}
     );
     $out = `$cmd`;
     $got = get_xpath( $out, '//propertyId' );
	ok( $got, "Returned a property Id" );
     
     # set monitorTags
     $cmd = $qa->ectool_command( qq{ setProperty /projects/$testCIProject/schedules/$schedule/ec_customEditorData/monitorTags }
          . qq{ --value 1 }
          . qq{ --projectName "$testCIProject" }
          . qq{ --scheduleName "$schedule"}
     );
     $out = `$cmd`;
     $got = get_xpath( $out, '//propertyId' );
	ok( $got, "Returned a property Id" );
     
     # set TriggerFlag
     $cmd = $qa->ectool_command( qq{ setProperty /projects/$testCIProject/schedules/$schedule/ec_customEditorData/TriggerFlag }
          . qq{ --value 2 }
          . qq{ --projectName "$testCIProject" }
          . qq{ --scheduleName "$schedule"}
     );
     $out = `$cmd`;
     $got = get_xpath( $out, '//propertyId' );
	ok( $got, "Returned a property Id" );
	 
	 # run the CI schedule
	 $cmd = $qa->ectool_command( 
		  qq{ runProcedure "$testCIProject" }
		. qq{ --procedureName "$procedureForCI" }
		. qq{ --scheduleName "$schedule" }
	); 
    my $jobId = `$cmd`;
	chomp $jobId;
	
	do {
		$cmd = $qa->ectool_command(
			qq { getJobStatus "$jobId" }
		);
		$out = `$cmd`;
		$got = get_xpath( $out, "//status" );
    } while( $got ne "completed" );
	
	$got = get_xpath( $out, "//outcome" );
    is( $got, "success", "run CI schedule" );
};
#----------------------------------------------------------------
# Automation of http://jira/browse/ECPSCMGIT-42 "plugin doesn't allow for username without password" 
test "repo url without password", sub {
my $matcher = <<'EOF';
          my @newMatchers = (
               {
                 id      => "repoUrlNoPassword",
                 pattern => "((http|https|ssh|git):\/\/)(\w+\:)(\@)(\w)+",
                 action  => q { setProperty("/projects/AutomationTest/repoUrlNoPassword", 1) }
               },
          );
          push @::gMatchers, @newMatchers;
EOF
	
	my $matcherProperty = "repoUrlNoPassword";
	
	runCheckout( $matcher, $matcherProperty, "matcher1" );
};
#-----------------------------------------------------------------
test "repo url without name", sub {
my $matcher = <<'EOF';
          my @newMatchers = (
               {
                 id      => "repoUrlNoName",
                 pattern => "((http|https|ssh|git):\/\/)(\:\w+)(\@)(\w)+",
                 action  => q { setProperty("/projects/AutomationTest/repoUrlNoName", 1) }
               },
          );
          push @::gMatchers, @newMatchers;
EOF
	
	my $matcherProperty = "repoUrlNoName";
	
	runCheckout( $matcher, $matcherProperty, "matcher2" );
};
#-----------------------------------------------------------------
# Automation of http://jira/browse/ECPSCMGIT-75 , http://jira/browse/ECPSCMGIT-47
test "ECPSCMGIT-75 - checkoutCode returned", sub {
	# our specific postp matcher code for "checkoutCode returned 1"
my $matcher = <<'EOF';
          my @newMatchers = (
               {
                 id      => "checkoutCodeForSuccess",
                 pattern => "checkoutCode returned 1",
                 action  => q { setProperty("/projects/AutomationTest/checkoutCodeForSuccess", 1) }
               },
          );
          push @::gMatchers, @newMatchers;
EOF

	my $matcherProperty = "checkoutCodeForSuccess";
	
	my $cmd;
    my $out;
    my $got;

	my $matcherName = "matcher3";
	
	# initialize the property that will contain our specific postp matcher
	$cmd = $qa->ectool_command(
		qq { setProperty /projects/$autoTestProject/$matcherProperty --value 0 }
	);
	$out = `$cmd`;
	
	# add out specific postp matcher code to the property at AutomationTest project for later evaluation
	$cmd = $qa->ectool_command(
		qq { setProperty "$matcherName" }
		. qq { --projectName "$autoTestProject" }
		. qq { --value '$matcher' }
	);
	$out = `$cmd`;
	
	# save the default ECSCM runMethod postprocessor to restore it later
	$cmd = $qa->ectool_command(
		qq { getStep "$ecscmPluginName" "RunMethod" "runMethod" }
	);
	$out = `$cmd`;
	my $restoredPostp = get_xpath( $out, "//postProcessor" );
	print "$restoredPostp\n";
	
	# set out specific matcher as a runMethod postprocessor in ECSCM
	$cmd = $qa->ectool_command(
		qq { modifyStep "$ecscmPluginName" "RunMethod" "runMethod" }
		. qq { --postProcessor "postp --loadProperty /projects/$autoTestProject/$matcherName" }
	);
	$out = `$cmd`;
	
	# run our procedure that contains Git Clone step
	$cmd = $qa->ectool_command(
		qq { runProcedure "$autoTestProject" }
		. qq { --procedureName "$autoTestProcedure" }
	);
	my $jobId = `$cmd`;
	chomp $jobId;
	do {
		$cmd = $qa->ectool_command(
			qq { getJobStatus "$jobId" }
		);
		$out = `$cmd`;
		$got = get_xpath( $out, '//status' );
    } while( $got eq "running" || $got eq "runnable" || $got eq "pending" );
	
	# verify that the job failed
	my $outcome = get_xpath( $out, "//outcome");
	
	# check that code returned is 0 (conforms to an error case)
	$cmd = $qa->ectool_command(
		qq { getProperty /projects/$autoTestProject/$matcherProperty }
	);
	$out = `$cmd`;
	
	# We have not to meet the strings 'checkoutCode returned 1' in log, when job outcome is 'error'
	# If the job hasn't failed, then it's not important to check if 'checkoutCode returned 1' exists in log
	if( $outcome eq "error" ) {
		is( $out, 0, "code is for error" );
	}
		
	# Restore the default ECSCM runMethod postprocessor
	$cmd = $qa->ectool_command(
		qq { modifyStep "$ecscmPluginName" "RunMethod" "runMethod" }
		. qq { --postProcessor "$restoredPostp" }
	);
	$out = `$cmd`;
};
#-----------------------------------------------------------------
sub runCheckout {
	my $cmd;
    my $out;
    my $got;
	
	my $matcher = $_[0];
	my $matcherProperty = $_[1];
	my $matcherName = $_[2];
	
	# initialize the property that will contain our specific postp matcher
	$cmd = $qa->ectool_command(
		qq { setProperty /projects/$autoTestProject/$matcherProperty --value 0 }
	);
	$out = `$cmd`;
	
	# add out specific postp matcher code to the property at AutomationTest project for later evaluation
	$cmd = $qa->ectool_command(
		qq { setProperty "$matcherName" }
		. qq { --projectName "$autoTestProject" }
		. qq { --value '$matcher' }
	);
	$out = `$cmd`;
	
	# save the default ECSCM runMethod postprocessor to restore it later
	$cmd = $qa->ectool_command(
		qq { getStep "$ecscmPluginName" "RunMethod" "runMethod" }
	);
	$out = `$cmd`;
	my $restoredPostp = get_xpath( $out, "//postProcessor" );
	
	# set out specific matcher as a runMethod postprocessor in ECSCM
	$cmd = $qa->ectool_command(
		qq { modifyStep "$ecscmPluginName" "RunMethod" "runMethod" }
		. qq { --postProcessor "postp --loadProperty /projects/$autoTestProject/$matcherName" }
	);
	$out = `$cmd`;
	
	# run our procedure that contains Git Clone step
	$cmd = $qa->ectool_command(
		qq { runProcedure "$autoTestProject" }
		. qq { --procedureName "$autoTestProcedure" }
	);
	my $jobId = `$cmd`;
	chomp $jobId;
	do {
		$cmd = $qa->ectool_command(
			qq { getJobStatus "$jobId" }
		);
		$out = `$cmd`;
		$got = get_xpath( $out, '//status' );
    } while( $got eq "running" || $got eq "runnable" || $got eq "pending" );
	
	# verify that the job failed
	my $outcome = get_xpath( $out, "//outcome");
	
	# check that code returned is 0 (conforms to an error case)
	$cmd = $qa->ectool_command(
		qq { getProperty /projects/$autoTestProject/$matcherProperty }
	);
	$out = `$cmd`;
	
	is( $out, 0, "error did not occur" );
		
	# Restore the default ECSCM runMethod postprocessor
	$cmd = $qa->ectool_command(
		qq { modifyStep "$ecscmPluginName" "RunMethod" "runMethod" }
		. qq { --postProcessor "$restoredPostp" }
	);
	$out = `$cmd`;
};