#
# so far the script just logs in as a hard-coded user.
# need to change this to log in with a random user from a hash like:
# $users{someGeneratedInt}{username} = 'joe';	#un for this user
# $users{someGeneratedInt}{password} = 'joe';	#pw for this user
#  $users{someGeneratedInt}{inUse} = 1;			#is this un/pw combo in use? if so no other threads will attempt to use it
#
#


#use strict;
#use warnings;
use Time::HiRes qw(gettimeofday);
use Data::Dumper qw(Dumper);
use HTTP::Request::Common qw(GET);
use HTTP::Cookies;
use WWW::Mechanize;



$DEBUG = 0;
$SIG{'INT'} = \&exit_clean;
$SIG{'QUIT'} = \&exit_clean;
$SIG{'CHLD'} = \&child_handler;

#cookie info
 $cookie_jar = HTTP::Cookies->new(
    file => "C:\lwp_cookies.dat",
    autosave => 1,
  );


# data structure
# $data{$id}{...} 		 >>>>> where $id is an int that contains the thread number 
# $data{$id}{browser} 	 >>>>> where browser is a www::mechanize object that contains the webpage we are working with
# $data{$id}{cookie_jar} >>>>> where cookie jar is a cookie store for the www:mechanize object
my %data;


# where to point the script -change later
$target = 'https://schoollogic.psd70.ab.ca/SchoolLogic/login.aspx?ReturnUrl=%2fSchoollogic%2fdefault.aspx';


my $id;
my $maxThreads = 1;

#worker loop
for($id = 1;$id <= $maxThreads; $id++){

	#initial timer
	$data{$id}{time} = Time::HiRes::gettimeofday();

	#child process time
	$newprocess = fork();
	if($newprocess == 0){
	
		#create a new session. $data{$id}{browser} is the main object
		#store cookie jar in memory in this threads hash
		$data{$id}{browser} = WWW::Mechanize->new( cookie_jar => {} );
		
		#create a user-agent based on the thread id
		$data{$id}{browser}->agent('Mozilla/5.0'.$id);
		
		#we make an initial request 
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
		
		#make a second request
		#{
		#
		#$data{$id}{browser}->get( 'https://schoollogic.psd70.ab.ca/Schoollogic/default.aspx' ); 
		#print $data{$id}{browser} -> content();
		#
		#}
		
	
		#get time elapsed since thread started
		$data{$id}{time} = Time::HiRes::gettimeofday() - $data{$id}{time};
		exit(0);
	}

}



#check work
if($DEBUG){
	print Dumper \%data;
	foreach my $id (sort keys %data) {
		foreach my $time (keys %{ $data{$id} }) {
			print "$name, $subject: $data{$id}{$time}\n";
		}
	}
}


#########subs


sub exit_clean(){

	close(ERRORLOG);
	$sig_got = @_;
	$SIG{'INT'}  = 'IGNORE';
	$SIG{'QUIT'} = 'IGNORE';
	close(SERVERSOCK);
	close(CHLDSOCK);
	if ($errorlog) { print ERRORLOG "Quitting on signal $sig_got"};
	die("Quitting on signal $sig_got\n");
}


sub child_handler(){
	wait;
}


# for reference
#
#foreach my $name (sort keys %grades) {
#foreach my $subject (keys %{ $grades{$name} }) {
#print "$name, $subject: $grades{$name}{$subject}\n";
#}
#}