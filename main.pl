#example: perl mail.pl -u userlist.txt -t logfile.txt
#
#todo: make this thing count the number of threads that are active, and keep that number up. and stay alive until control-c
# also needs to spawn threads at an interval (will hack with sleep() calls until i get the action interval set up))
#


#use strict;
#use warnings;
#use Cwd;
use Time::HiRes qw(gettimeofday);
use Data::Dumper qw(Dumper);
use HTTP::Request::Common qw(GET);
use HTTP::Cookies;
use WWW::Mechanize;

my $DEBUG = 0;
$SIG{'INT'} = \&exit_clean;
$SIG{'QUIT'} = \&exit_clean;
$SIG{'CHLD'} = \&child_handler;

my $userlist_index_counter; #counter for incrementing the index when populating %userlist hash
my $userlist_inuse_LOCK = 0; #variable to store a lock value for the "inuse" check.

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
	if( m/^(\s|\S)+,(\S|\s)*$/ ){
		$userlist{$userlist_index_counter}{username} = $1;
		$userlist{$userlist_index_counter}{password} = $2;
		$userlist{$userlist_index_counter}{inuse} = 0;
		$userlist_index_counter++;
	}
}
close($userlist_filehandle) || warn("could not close user list $userlist \n");



# data structure
# $data{$id}{...} 		 >>>>> where $id is an int that contains the thread number 
# $data{$id}{browser} 	 >>>>> where browser is a www::mechanize object that contains the webpage we are working with
# $data{$id}{cookie_jar} >>>>> where cookie jar is a cookie store for the www:mechanize object
# $data{$id}{username} 	 >>>>> username
# $data{$id}{password}   >>>>> password
# $data{$id}{unpwindex}  >>>>> index of the in-use un/pw record in the %userlist hash
my %data;


# where to point the script -change later
$target = 'https://schoollogic.psd70.ab.ca/SchoolLogic/login.aspx?ReturnUrl=%2fSchoollogic%2fdefault.aspx';


my $id;
my $maxThreads = 1;
my $currentThreads = 0;
my $threadInterval = 30;	#seconds
my $activityInterval = 10;


#while(1){

	#worker loop
	for($id = 1;$id <= $maxThreads; $id++){

		#initial timer for timing the thread
		$data{$id}{time} = Time::HiRes::gettimeofday();

		#child process time
		$newprocess = fork();
		if($newprocess == 0){
		
			
		
			#create a new session. $data{$id}{browser} is the main object
			#store cookie jar in memory in this threads hash
			$data{$id}{browser} = WWW::Mechanize->new( cookie_jar => {} );
			
			#create a user-agent based on the thread id
			$data{$id}{browser}->agent('Mozilla/5.0'.$id);
			
			#we need to search through %userlist. this could create a race condition, so lock this function.
			#this should be safe enough.
			#loop until lock is free
			USERLIST_INUSE_LOCK:
			while($userlist_inuse_LOCK == 1){
				
				#if we are here that means this has become unlocked. so relock it.
				$userlist_inuse_LOCK = 1;
							
				foreach my $userlist_sort_indexes (sort keys %userlist) {
					#and find a user/pw combo that isnt in use
					if($userlist{$userlist_sort_indexes}{inuse} == 0){
						#then we are going to take this user and mark it in-use
						$userlist{$userlist_sort_indexes}{inuse} = 1;
						#and assign this thread to use this un/pw
						$data{$id}{username} = $userlist{$userlist_sort_indexes}{username};
						$data{$id}{password} = $userlist{$userlist_sort_indexes}{password};
						$data{$id}{unpwindex} = $userlist_sort_indexes;
					};
				}

				#we are done now, unlock.
				$userlist_inuse_LOCK = 0;			
			}
			
			
			##LOGIN
			#we make an initial request. login stage
			{
				#make request
				$data{$id}{browser}->get( $target ); 
				
				#check that things worked
				if (! $data{$id}{browser}->success()) {
					print $data{$id}{browser}->status() . "\n"; 
				}
				
				
				
				#now we login. the field() function sets the value of a field (www::mechanize magic). 
				#populate username and password, hidden fields, then submit
				$result = $data{$id}{browser}->submit_form(	form_name => 'Form1',
															fields => {
																txtUserName => 'kGarner',
																txtPassword => '10016',
																__EVENTVALIDATION => $data{$id}{browser}->value(__EVENTVALIDATION),
																__VIEWSTATE => $data{$id}{browser}->value(__VIEWSTATE),
																Submit => 'Login',
																},
															button => 'Submit'
															);
				
				#print $result->content();
			
			}
			
			
			
			
			
			#NEED TO TURN THIS SECTION IN FETCHING JOBS FROM THE WORK LIST
			#{
			#
			#$data{$id}{browser}->get( 'https://schoollogic.psd70.ab.ca/Schoollogic/default.aspx' ); 
			#print $data{$id}{browser} -> content();
			#
			#}
			

			
			
			########################################
			#IMPLEMENT LOGOUT HERE
			########################################
			
			
			
			
			########################################THREAD CLEANUP
			#release the username/password
			$userlist{ $data{$id}{unpwindex} }{inuse} = 0;
			$data{$id}{username} = '';
			$data{$id}{password} = '';
			$data{$id}{unpwindex} = '';
		
			#get time elapsed since thread started
			$data{$id}{time} = Time::HiRes::gettimeofday() - $data{$id}{time};
			
			exit(0);
		}

		sleep(10); #temp hack to make this thing wait a while before dying
	}

#end of while() to wait for child functions
#}

############################################################
############################################################
############################################################
############################################################
#PROGRAM CLEANUP GOES HERE



#check work
if($DEBUG){
	print Dumper \%data;
	foreach my $id (sort keys %data) {
		foreach my $time (keys %{ $data{$id} }) {
			print "$name, $subject: $data{$id}{$time}\n";
		}
	}
}



################################################################
################################################################
################################################################
################################################################
################################################################
################################################################
#SUBS GO HERE


sub exit_clean(){
	#close logfile if it exists
	if($log_file != 0){ 
		close($log_filehandle) || warn("could not close log file $log_file \n"); 
	}
	$sig_got = @_;
	$SIG{'INT'}  = 'IGNORE';
	$SIG{'QUIT'} = 'IGNORE';
	close(SERVERSOCK);
	close(CHLDSOCK);
	die("Quitting on signal $sig_got\n");
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



# for reference
#
#foreach my $name (sort keys %grades) {
#foreach my $subject (keys %{ $grades{$name} }) {
#print "$name, $subject: $grades{$name}{$subject}\n";
#}
#}













