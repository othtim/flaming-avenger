#example: perl main.pl -u userlist.txt -t logfile.txt
#
# need to add a routine to the parent thread that checks if threads exited abnormally, and regain their un/pw
# 
# started on the work parts. will eventually have to write a way to parse an external file.
#


use strict;
use warnings;
use threads;
use threads::shared;
use Thread::Semaphore;
use Time::HiRes qw(gettimeofday);
#use Data::Dumper qw(Dumper);
use HTTP::Request::Common qw(GET);
use HTTP::Cookies;
use WWW::Mechanize;

my $DEBUG = 1;
$SIG{'INT'} = \&exit_clean;
$SIG{'QUIT'} = \&exit_clean;
$SIG{'CHLD'} = \&child_handler;

#for locking use_credentials
my $use_credentials_semaphore = Thread::Semaphore->new();

# where to point the script -change later
my $target = 'http://localhost/SchoolLogic/login.aspx?ReturnUrl=%2fschoollogic%2fDefault.aspx';

my $userlist_index_counter = 1; #counter for incrementing the index when populating %userlist hash
my $userlist_inuse_LOCK; #variable to store a lock value for the "inuse" check.
my $log_file;
my $log_filehandle;
my $userlist_file;

##parse arguments
for (my $argv_ident_counter = 0 ; $argv_ident_counter < $#ARGV + 1 ; $argv_ident_counter++){  
	#skip the last argument, it wont be a switch
	next if($argv_ident_counter == $#ARGV + 1);
	if ($ARGV[$argv_ident_counter] eq "-u"){
		$userlist_file = $ARGV[$argv_ident_counter + 1];
	}elsif($ARGV[$argv_ident_counter] eq "-t"){
		$log_file = $ARGV[$argv_ident_counter + 1];
	}	
}
	
##open logfile if exists, otherwise no logging.
if(defined $log_file){
	#$log_file = $curdir;
	open($log_filehandle , ">>" , $log_file) || die("could not find user list $log_file, quitting...\n");
	#and we just keep this open to write to. via log_message(). close at end of program run.
}


##parse userlist
# $users{someGeneratedInt}{username} = 'joe';	#un for this user
# $users{someGeneratedInt}{password} = 'joe';	#pw for this user
#  $users{someGeneratedInt}{inuse} = 1;			#is this un/pw combo in use? if so no other threads will attempt to use it
my %userlist;


#open user list file for reading
open(my $userlist_filehandle , "<", $userlist_file) || die("could not find user list $userlist_file, quitting...\n");

while(<$userlist_filehandle>){
	#if the format of the record is okay, load into data structure
	if( m/^([A-Za-z.0-9- ]+),([A-Za-z.0-9- ]*)$/ ){
		share($userlist{$userlist_index_counter}{'username'});
		share($userlist{$userlist_index_counter}{'password'});
		share($userlist{$userlist_index_counter}{'inuse'});
		$userlist{$userlist_index_counter}{'username'} = $1;
		$userlist{$userlist_index_counter}{'password'} = $2;
		$userlist{$userlist_index_counter}{'inuse'} = 0;
		$userlist_index_counter++;
		#print $1, $2;
	}
}
close($userlist_filehandle) || warn("could not close user list $userlist_file \n");

###########
# work lists are a hash of hashes. 
# each key is a work item. 
# each value contains keys for the type of work, the url to get, and a string to 'verify' that its the expected page.
# $work{'1'}{'1'}{'type'} = 'GET' 
# $work{'1'}{'1'}{'url'} = 'www.google.ca' 
# $work{'1'}{'1'}{'verify'} = '<title>Google</title>' 
#ideally work will be grabbed based on a system of what "likely user actions" are. ie % chance of a user doing such and such.
my %work;

#some hardcoded test values
$work{'1'}{'1'}{'type'} = 'GET';
$work{'1'}{'1'}{'url'} = 'http://localhost/schoollogic/NavPage.aspx?MenuItem=Demographics';
$work{'1'}{'1'}{'verify'} = 'SchoolLogic - Demographics';

$work{'1'}{'2'}{'type'} = 'GET';
$work{'1'}{'2'}{'url'} = 'http://localhost/schoollogic/NavPage.aspx?MenuItem=IndividualGradesEntry';
$work{'1'}{'2'}{'verify'} = 'SchoolLogic - Grades';



###########

my $maxThreads = 10;
my $threadInterval = 0.15;	#seconds
my $activityInterval = 10;


while(1){

	#between thread creation we are going to sleep a certain amount of time.
	sleep($threadInterval);

	#make threads until we are at $maxThreads
	if( threads->list(threads::running) < $maxThreads){

	
		#child process time
		threads->create(sub {

			#data structure for threads
			# $thread_data{'browser'}		where browser is a www::mechanize object that contains the webpage we are working with
			# $thread_data{'cookie_jar'}	where cookie jar is a cookie store for the www:mechanize object
			# $thread_data{'username'}
			# $thread_data{'password'}
			my %thread_data;

			#initial timer for timing the thread
			$thread_data{'time'} = Time::HiRes::gettimeofday();
		
			log_message(threads->tid(). ", create, " . $thread_data{'time'});
		
			#create a new session. $data{$id}{browser} is the main object
			#store cookie jar in memory in this threads hash
			$thread_data{'browser'} = WWW::Mechanize->new( cookie_jar => {} );
			
			#create a user-agent based on the thread id 
			$thread_data{'browser'}->agent('Mozilla 5.0' . threads->tid());
			
			#we need to search through %userlist. this could create a race condition, so lock this function.
			#need better way to trap return values of 0 (ie, no un/pw found). for now, create one login per thread.
			my $unpwindex = 0;
			my $i;
			while($unpwindex == 0){
				$unpwindex = use_credentials();
			}

				
	
			##LOGIN
			#we make an initial request. login stage
			#make request
			$thread_data{'browser'}->get( $target ); 
			
			#check that things worked
			if (! $thread_data{'browser'}->success()) {
				print $thread_data{'browser'}->status() . "\n"; 
			}
			
			print threads->tid() . " un " . $userlist{$unpwindex}{'username'} . "\n";
			print threads->tid() . " pw " . $userlist{$unpwindex}{'password'} . "\n";
			
			#now we login. the field() function sets the value of a field (www::mechanize magic). 
			#populate username and password, hidden fields, then submit
			my $time = Time::HiRes::gettimeofday();
			my $result = $thread_data{'browser'}->submit_form(	form_name => 'Form1',
														fields => {
															txtUserName => $userlist{$unpwindex}{'username'},
															txtPassword => $userlist{$unpwindex}{'password'},
															__EVENTVALIDATION => $thread_data{'browser'}->value('__EVENTVALIDATION'),
															#__VIEWSTATE => $thread_data{'browser'}->value('_VIEWSTATE'),
															Submit => 'Login',
															},
														button => 'Submit'
														) || "fail";
			
			# check that we are on the right page. if not, quit thread.
			if($result->decoded_content() =~ m/ctl00_Head1/){
					log_message(threads->tid() . ", login, , " . (Time::HiRes::gettimeofday() - $time));
			}else{
					#log and quit if we cant login
					#print $result->decoded_content();
					log_message(threads->tid() . ", login error, , " . (Time::HiRes::gettimeofday() - $time));
					free_credentials($unpwindex);
					threads->exit();	
			}
			
			
			
			
			
			
			#NEED TO TURN THIS SECTION IN FETCHING JOBS FROM THE WORK LIST
			
			#have to insert some way to select which hash index to use (or what parts of it? not sure yet).
			#figure out what you want to do in here

			#loop through the various steps of the task
			foreach my $inner_index ( sort keys %{ $work{'1'}} ){
													
				#pause between actions
				sleep($activityInterval);
													
				#do actions depending on what type of request this is
				##############################################################GET
				if( $work{'1'}{$inner_index}{'type'} eq 'GET'){
					#if task is get, get the page
					

					#record the start time
					my $thread_task_time = Time::HiRes::gettimeofday();
					my $task_value = $work{'1'}{$inner_index}{'url'};
					
					#make the request
					$thread_data{'browser'}->get( $task_value  );
					
					#did the request work
					if (! $thread_data{'browser'}->success()) {
						#request failed, log
						log_message(threads->tid() . ", fail, GET " . $task_value . ", " . (Time::HiRes::gettimeofday() - $thread_task_time));
					}else{
					
						#verify we are on the expected page
						my $regex = $work{'1'}{$inner_index}{'verify'};
						if($thread_data{'browser'}->content() =~ m/$regex/){
					
							#request success, log the elapsed time
							log_message(threads->tid() . ", success, GET " . $task_value . ", " . (Time::HiRes::gettimeofday() - $thread_task_time));
						}else{
							
							#request failed, log the elapsed time
							log_message(threads->tid() . ", unexpected page, GET " . $task_value .  ", " . (Time::HiRes::gettimeofday() - $thread_task_time));
						}
					
					}
				
				##############################################################POST
				} elsif( $work{'1'}{$inner_index}{'type'} eq 'POST'){
				
				} else{
					#there shouldn't be any options other than GET and POST
					print "problem \n";
				}
			
			#do the next action in the list.
			}
			
			
						
						
						
			
			
			########################################
			#IMPLEMENT LOGOUT HERE
			########################################
				
			

		



			
			#check exit state of this thread
			if($DEBUG){
				#print threads->list(threads::running) . ", $maxThreads \n";
				#print threads->tid() . " un: " . $userlist{$unpwindex}{'username'} . "\n";
				#print threads->tid() . " pw: " . $userlist{$unpwindex}{'password'} . "\n";
				#print threads->tid() . " unpwindex: " . $unpwindex . "\n";
			}				
		
			
			#get time elapsed since thread started
			$thread_data{'time'} = Time::HiRes::gettimeofday() - $thread_data{'time'};
			#log and exit
			log_message(threads->tid() . ", exit, ," . $thread_data{'time'});

			
			
			########################################THREAD CLEANUP
			#release the username/password
			free_credentials($unpwindex);
			
			#exit thread	
			threads->exit();
		});		
		
		

	}

}

############################################################
############################################################
############################################################
############################################################
#PROGRAM CLEANUP GOES HERE






################################################################
################################################################
################################################################
################################################################
################################################################
################################################################
#SUBS GO HERE


sub exit_clean(){
	#put some thread cleanup in here
	#close logfile if it exists
	if(defined $log_file){
		if($log_file != 0){ 
			close($log_filehandle) || warn("could not close log file $log_file \n"); 
		}
	}
	$SIG{'INT'}  = 'IGNORE';
	$SIG{'QUIT'} = 'IGNORE';
	die("Quitting on signal " . @_ . "\n");
}


sub child_handler(){
	wait;
}


#sub that holds open the logfile so that we don't have overhead of opening and closing logfile for each message
# format: (thread id, action (login,exit,succses,failure,etc), target (google.ca or similar), elapsed time)
#
sub log_message(){
	#if logging to file is enabled do so, otherwise log to stdout
	if(defined $log_file){
		#if this isnt true then the logfile has closed unexpectedly
		if( tell($log_filehandle) != -1 ){
			#while anything remains in the argument list, remove it from the list and print it to LOGFILE.
			while(@_){ 
				print $log_filehandle shift(@_) . "\n"; 
			}				
		}
		else{
			die("log file closed unexpectedly");
		}
	}
	else{
		while(@_){ 
			print shift(@_) . "\n"; 
		}
	}
}

#returns a free un/pw, and sets it in-use in the hash
sub use_credentials() {
	my $returnVal = 0;
	foreach my $userlist_sort_indexes (sort keys %userlist) {
		next if $returnVal != 0;
		#semaphore to lock this code block
		$use_credentials_semaphore->down();
		if($userlist{$userlist_sort_indexes}{'inuse'} == 0){
		#then we are going to take this un/pw and mark it in-use
			$userlist{$userlist_sort_indexes}{'inuse'} = 1;
			#and return the index of this un/pw
			$returnVal = $userlist_sort_indexes;
		}
		#semaphore to unlock this code block
		$use_credentials_semaphore->up();
	}
	return $returnVal;
}


#frees a un/pw in use
sub free_credentials() {
	my $index = shift(@_);	
	$userlist{$index}{'inuse'} = 0;
}







