
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
my %data;


# where to point the script -change later
$target = 'https://schoollogic.psd70.ab.ca/Schoollogic/';


my $id;
my $maxThreads = 2;

#worker loop
for($id = 1;$id <= $maxThreads; $id++){

	#initial timer
	$data{$id}{time} = Time::HiRes::gettimeofday();

	#child process time
	$newprocess = fork();
	if($newprocess == 0){
	
		#create a new session. $data{$id}{browser} is the main object
		$data{$id}{browser} = WWW::Mechanize->new();
		
		#create a user-agent based on the thread id
		$data{$id}{browser}->agent('Tim'.$id);
		
		#store cookie jar in memory in this threads hash
		$data{$id}{browser}->cookie_jar( $data{$id}{cookie_jar} );
		
		#we make an initial request 
		{
			#make request
			$data{$id}{browser}->get( $target ); 
			
			#check that things worked
			if ($data{$id}{browser}->success()) {
				if($DEBUG){ print $data{$id}{browser}->content() . "\n"; }
			} else {
				if($DEBUG){ print $data{$id}{browser}->status() . "\n"; }
			}
			
			#we need to grab the "__VIEWSTATE" and "__EVENTVALIDATION" strings from the web page
			#this may prove to be redundant. commenting till needed
			# $data{$id}{__EVENTVALIDATION} = $data{$id}{browser}->value(__EVENTVALIDATION);
			# $data{$id}{__VIEWSTATE} = $data{$id}{browser}->value(__VIEWSTATE);

			#now we login. the field() function sets the value of a field (www::mechanize magic)
			$data{$id}{browser}->field( 'txtUsername', '' );
			$data{$id}{browser}->field( 'txtUsername', '' );
			
			
		}
			
	
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