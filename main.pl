#example: perl mail.pl -u userlist.txt -t logfile.txt
#
# need to add a routine to the parent thread that checks if threads exited abnormally, and regain their un/pw
# 
# need to start work loop
#


#use strict;
#use warnings;
#use Cwd;
use threads;
use threads::shared;
use Thread::Semaphore;
use Time::HiRes qw(gettimeofday);
use Data::Dumper qw(Dumper);
use HTTP::Request::Common qw(GET);
use HTTP::Cookies;
use WWW::Mechanize;

my $DEBUG = 1;
$SIG{'INT'} = \&exit_clean;
$SIG{'QUIT'} = \&exit_clean;
$SIG{'CHLD'} = \&child_handler;

#for locking use_credentials
my $use_credentials_semaphore = Thread::Semaphore->new();


my $userlist_index_counter; #counter for incrementing the index when populating %userlist hash
my $userlist_inuse_LOCK; #variable to store a lock value for the "inuse" check.
$userlist_inuse_LOCK = 0;

my $log_file;
my $log_filehandle;


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
open(my $userlist_filehandle , "<", $userlist_file) || die("could not find user list $userlist, quitting...\n");
$userlist_index_counter = 1;

while(<$userlist_filehandle>){
	#if the format of the record is okay, load into data structure
	if( m/^([A-Za-z0-9 ]+),([A-Za-z0-9 ]*)$/ ){
		$userlist{$userlist_index_counter}{'username'} = $1;
		$userlist{$userlist_index_counter}{'password'} = $2;
		$userlist{$userlist_index_counter}{'inuse'} = 0;
		$userlist_index_counter++;
	}
}
close($userlist_filehandle) || warn("could not close user list $userlist \n");



# data structure
# $data{$id}{...}			where $id is an int that contains the thread number 
# $data{'currentThreads'}	thread counter
my %data;

#data structure for threads
# $thread_data{'browser'}		where browser is a www::mechanize object that contains the webpage we are working with
# $thread_data{'cookie_jar'}	where cookie jar is a cookie store for the www:mechanize object
# $thread_data{'username'}
# $thread_data{'password'}
my %thread_data;



# where to point the script -change later
$target = 'http://sales.schoollogic.com/SchoolLogic/login.aspx?ReturnUrl=%2fschoollogic';



my $maxThreads = 2;
my $threadInterval = 0;	#seconds
my $activityInterval = 10;


while(1){

	#between thread creation we are going to sleep a certain amount of time.
	sleep($threadInterval);

	#make threads until we are at $maxThreads
	if( threads->list(threads::running) < $maxThreads){

	
		#child process time
		threads->create(sub {

			#initial timer for timing the thread
			$thread_data{'time'} = Time::HiRes::gettimeofday();
		
			log_message(threads->tid(). ", create, " . $thread_data{'time'});
		
			#create a new session. $data{$id}{browser} is the main object
			#store cookie jar in memory in this threads hash
			$thread_data{'browser'} = WWW::Mechanize->new( cookie_jar => $thread_data{'cookie_jar'} );
			
			#create a user-agent based on the thread id 
			$thread_data{'browser'}->agent(threads->tid());
			
			#we need to search through %userlist. this could create a race condition, so lock this function.
			my $unpwindex = use_credentials();
			
			

			
				
			
			##LOGIN
			#we make an initial request. login stage
			#make request
#			$thread_data{'browser'}->get( $target ); 
			
			#check that things worked
#			if (! $thread_data{'browser'}->success()) {
#				print $thread_data{'browser'}->status() . "\n"; 
#			}
			
			
			#now we login. the field() function sets the value of a field (www::mechanize magic). 
			#populate username and password, hidden fields, then submit
#			$thread_data{'browser'}->submit_form(	form_name => 'Form1',
#														fields => {
#															txtUserName => $userlist{$unpwindex}{'username'},
#															txtPassword => $userlist{$unpwindex}{'password'},
#															__EVENTVALIDATION => $thread_data{'browser'}->value(__EVENTVALIDATION),
#															#__VIEWSTATE => $thread_data{'browser'}->value(_VIEWSTATE),
#															Submit => 'Login',
#															},
#														button => 'Submit'
#														);
			

			

			
			
			
			
			#NEED TO TURN THIS SECTION IN FETCHING JOBS FROM THE WORK LIST
			#{
			#
			#$thread_data{'browser'}->get( 'https://schoollogic.psd70.ab.ca/Schoollogic/default.aspx' ); 
			#print $thread_data{'browser'}->content();
			#
			#}
			

			
			
			########################################
			#IMPLEMENT LOGOUT HERE
			########################################
			

			
			

		



			
			#check exit state of this thread
			if($DEBUG){
				print threads->list(threads::running) . ", $maxThreads \n";
				print threads->tid() . " un: " . $userlist{$unpwindex}{'username'} . "\n";
				print threads->tid() . " pw: " . $userlist{$unpwindex}{'password'} . "\n";
				print threads->tid() . " unpwindex: " . $unpwindex . "\n";
			}				
		
			
			#get time elapsed since thread started
			$thread_data{'time'} = Time::HiRes::gettimeofday() - $thread_data{'time'};
			#log and exit
			log_message(threads->tid() . ", exit, " . $thread_data{'time'});

			
			
			########################################THREAD CLEANUP
			#release the username/password
			
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
	if($log_file != 0){ 
		close($log_filehandle) || warn("could not close log file $log_file \n"); 
	}
	$SIG{'INT'}  = 'IGNORE';
	$SIG{'QUIT'} = 'IGNORE';
	die("Quitting on signal " . @_ . "\n");
}


sub child_handler(){
	wait;
}


#sub that holds open the logfile so that we don't have overhead of opening and closing logfile for each message
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
	$returnVal = 0;
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


# for reference
#
#foreach my $name (sort keys %grades) {
#foreach my $subject (keys %{ $grades{$name} }) {
#print "$name, $subject: $grades{$name}{$subject}\n";
#}
#}













