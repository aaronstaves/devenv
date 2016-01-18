package DevEnv::Docker::Control;
use Moose;

extends 'DevEnv';

use DevEnv::Exceptions;

use IPC::Run;
use File::Which;
use JSON::XS;

has '_docker_file_name' => (
	traits  => ['Array'],
	is      => 'ro',
	isa     => 'ArrayRef[Str]',
	handles => {
		all_file_names => 'elements'
	},
	default => sub {
		return [
			qw/
				docker.io
				docker
			/
		]
	}
);

has 'docker' => (
	is      => 'ro',
	isa     => 'Str',
	lazy    => 1,
	builder => '_build_docker'
);
sub _build_docker {
	my $self = shift;

	my $docker = undef;

	foreach my $file_name ( $self->all_file_names ) {
	
		$docker = which( $file_name );
		
		last if ( defined $docker );
	}

	if ( not defined $docker ) {
		DevEnv::Exception::Docker->throw( "Could not find docker file. Is it installed and in the PATH?" );
	}

	return $docker;
}

sub ps {

	my $self = shift;

	my $ps = undef;
	my @columns = ( 
		{ title   => 'CONTAINER ID', key => 'container_id' },
		{ title   => 'IMAGE',        key => 'image' },
		{ title   => 'COMMAND',      key => 'command' },
		{ title   => 'CREATED',      key => 'created' },
		{ title   => 'STATUS',       key => 'status' },
		{ title   => 'PORTS',        key => 'ports' },
		{ title   => 'NAMES',        key => 'names' }
	);

	my @cmd = (
		$self->docker,
		'ps',
		'-a',
	);
	
	my ( $stdout, $stderr );
	IPC::Run::run
		\@cmd, 
		'>',  \$stdout,
		'2>', \$stderr;

	my @rows = split /\n/, $stdout;

	my $header     = shift @rows;
	my $last_index = length ( $header ) * 2;
	foreach my $column ( reverse @columns ) {
		$column->{start} = index ( $header, $column->{title} );
		$column->{width} = $last_index - $column->{start};
		$last_index = $column->{start}
	}

	foreach my $row ( @rows ) {

		my %record = ();
		foreach my $column ( reverse @columns ) {
			my $value = substr ( $row, $column->{start}, $column->{width} );
			$value =~ s/\s+$//;
			$record{ $column->{key} } = $value;
		}

		my $name = $record{names};
		foreach my $name_part ( split /,/, $name ) {
			if ( $name_part !~ m/\// ) {	
				$name = $name_part;
				last;
			}
		}

		$ps->{ $name } = \%record;
	}

	return $ps;
}

sub images {

	my $self = shift;

	my $images = undef;
	my @columns = ( 
		{ title   => 'REPOSITORY',   key => 'repository' },
		{ title   => 'TAG',          key => 'tag' },
		{ title   => 'IMAGE ID',     key => 'image_id' },
		{ title   => 'CREATED',      key => 'created' },
		{ title   => 'VIRTUAL SIZE', key => 'virtual_size' }
	);

	my @cmd = (
		$self->docker,
		'images',
		'-a',
	);
	
	my ( $stdout, $stderr );
	IPC::Run::run
		\@cmd, 
		'>',  \$stdout,
		'2>', \$stderr;

	my @rows = split /\n/, $stdout;

	my $header     = shift @rows;
	my $last_index = length ( $header ) * 2;
	foreach my $column ( reverse @columns ) {
		$column->{start} = index ( $header, $column->{title} );
		$column->{width} = $last_index - $column->{start};
		$last_index = $column->{start}
	}

	foreach my $row ( @rows ) {

		my %record = ();
		foreach my $column ( reverse @columns ) {
			my $value = substr ( $row, $column->{start}, $column->{width} );
			$value =~ s/\s+$//;
			$record{ $column->{key} } = $value;
		}

		next if ( $record{repository} eq "<none>" );

		$images->{ $record{repository} } = \%record;
	}

	return $images;
}

sub pull {

	my $self = shift;
	my %args = @_;

	my $registries = $args{registries} || [];
	my $image_name = $args{image_name};

	my $found = 0;

	foreach my $registry ( @{$registries} ) {

		my @cmd = (
			$self->docker,
			"pull",
			"$registry/$image_name"
		);

		my ( $stdout, $stderr );
		IPC::Run::run
			\@cmd, 
			'>',  \$stdout,
			'2>', \$stderr;

		#Status: Downloaded newer image for debian:latest
		#Error: image library/blah:latest not found
		#Invalid repository name (ex: "registry.domain.tld/myrepos")
		#Error: image blah:latest not found
	}

	return $found;
}

sub status {

	my $self = shift;
	my %args = @_;

	my $container_name = $args{container_name};
	
	my @cmd = (
		$self->docker,
		'inspect',
		$container_name
	);
	
	my ( $stdout, $stderr );
	IPC::Run::run
		\@cmd, 
		'>',  \$stdout,
		'2>', \$stderr;

	return JSON::XS->new->decode( $stdout );
}

sub run {

	my $self = shift;
	my %args = @_;

	my ( $stdout, $stderr );
	my $command = $args{command} // [];

	my @cmd = (
		$self->docker,
		@{$command}
	);

	IPC::Run::run
		\@cmd, 
		'>',  \$stdout,
		'2>', \$stderr;

	return $stdout;
}


sub command {

	my $self = shift;
	my %args = @_;

	my $command = $args{command} // [];

	my @cmd = (
		$self->docker,
		@{$command}
	);

	my $cmd = join ( " ", @cmd );

	$self->debug( "Docker Cmd = $cmd" );

	system $cmd;

#	my ( $stdout, $stderr );
#	IPC::Run::run
#		\@cmd, 
#		'>',  \$stdout,
#		'2>', \$stderr;
#
#	print STDERR "$stdout\n";
#	print STDERR "$stderr\n";
}


__PACKAGE__->meta->make_immutable;

1;
