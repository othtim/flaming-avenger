
use Time::HiRes qw(gettimeofday);
use Data::Dumper qw(Dumper);

$DEBUG = 1;
$SIG{'INT'} = \&exit_clean;
$SIG{'QUIT'} = \&exit_clean;
$SIG{'CHLD'} = \&child_handler;

# data structure
# contains an id ($id)
# $data{1}{time} = 
#

my %data;


my $id;
my $maxThreads = 2;

#worker loop
for($id = 1;$id <= $maxThreads; $id++){

	$data{$id}{time} = Time::HiRes::gettimeofday();

	
	#child process time
	$newprocess = fork();
	if($newprocess == 0){
	
		print $data{$id}{time};
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