package DevEnv::Docker::Control;
use Moose;

use IPC::Run qw/run/;
use File::Which;

has 'docker_file_name' => (
	is      => 'ro',
	isa     => 'Str',
	default => 'docker'
);

has 'docker' => (
	is      => 'ro',
	isa     => 'Str',
	lazy    => 1,
	builder => sub {
		my $self = shift;
		return which( $self->docker_file_name );
	}
);


sub ps {

	my $self = shift;

	my @cmd = (
		$self->docker,
		'ps',
		'-a'
		'--no-trunc'
	);
	
	my ( $stdout, $stderr );

	run 
		\@cmd, 
		'>',   \$stdout,
		\'2>', \$stderr;

	

}

sub run {




}


__PACKAGE__->meta->make_immutable;

1;
