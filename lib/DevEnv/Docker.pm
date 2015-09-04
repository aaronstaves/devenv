package DevEnv::Docker;
use Moose;

extends 'DevEnv';
with 'DevEnv::Role::Project';

use DevEnv::Docker::Control;

use Path::Class;
use Data::Dumper;

has 'control' => (
	is       => 'ro',
	isa      => 'DevEnv::Docker::Control',	
	lazy     => 1,
	builder  => '_build_control'
);
sub _build_control { return DevEnv::Docker::Control->new() }

has 'image_dir' => (
	is       => 'ro',
	isa      => 'Path::Class::Dir',
	lazy     => 1,
	builder  => '_build_image_dir',
);
sub _build_image_dir { return shift->base_dir->subdir( "images" ) }

has 'port_offset' => (
	is      => 'ro',
	isa     => 'Int',
	lazy     => 1,
	builder  => '_build_port_offset'
);
sub _build_port_offset {

	my $self = shift;
	return $self->project_config->{general}{port_offset} // 0;
}


sub _container_order {

	my $self = shift;
	my %args = @_;

	my $scoreboard = undef;

	foreach my $container_name ( keys %{$self->project_config->{containers}} ) {

		my $container_config = $self->project_config->{containers}{ $container_name };

		# Check if we should enable this container
		if ( grep { $container_name eq $_ } @{$args{containers}} ) {
			$container_config->{enabled} = 1;
		}

		# Always start the data container first
		if ( $container_config->{type} eq "data" ) {

			$scoreboard->{ $container_name } += 1_000_000;

			# data containers are always enabled
			$container_config->{enabled} = 1;
		}
	
		# If the we want it in the foreground, make sure the work container goes last
		if ( $container_config->{type} eq "work" ) {

			if ( $args{foreground} ) {
				$scoreboard->{ $container_name } -= 1_000_000;
			}

			# work containers are always enabled
			$container_config->{enabled} = 1;
		}

		next if ( not $container_config->{enabled} );

		$scoreboard->{ $container_name } //= 0;

		# Increase the score of the container that is link required for this one
		if ( defined $container_config->{link} and ref $container_config->{link} eq "ARRAY" ) {
			foreach my $link ( @{$container_config->{link}} ) {

				$scoreboard->{ $link }++;
	
				# Make sure the contrainer is enabled since we are linking to it
				$self->project_config->{containers}{ $link }{enabled} = 1;
			}
		}
	}

	my @containers = sort { $scoreboard->{$b} <=> $scoreboard->{$a} } keys %{$scoreboard};

	return wantarray ? @containers : \@containers;
}

sub _instance_name {

	my $self           = shift;
	my $container_name = shift;

	if ( defined $self->instance_name ) {
		$container_name = sprintf( "%s_%s", $self->instance_name, $container_name );
	}

	return $container_name;
}

sub _image_name {

	my $self = shift;
	my %args = @_;

	my $container_name = $args{container_name};
	my $config = $self->project_config->{containers}{ $container_name };

	return "devenv/" . sprintf( "%s_%s", $config->{type}, $config->{image} );
}

sub _image_name_version {

	my $self = shift;
	my %args = @_;

	my $container_name = $args{container_name};
	my $images  = $self->control->images();

	my $name    = $self->_image_name( container_name => $container_name );
	my $version = $images->{ $self->_image_name( container_name => $container_name ) }{tag};

	return "$name:$version";
}

sub _env {

	my $self = shift;
	my %args = @_;

	my $container_name = $args{container_name};

	my ( $gid ) = split /\s/, $(;

	my $env_hashref = {
		DEVENV_MY_UID  => $self->user_id,
		DEVENV_MY_GID  => $self->group_id,
		DEVENV_MY_HOME => $self->home_dir,
	};

	my $config = $self->project_config->{containers}{ $container_name };

	if ( defined $config->{envs} ) {
		
		foreach my $env ( @{$config->{envs}} ) {
			$env_hashref->{ "DEVENV_" . $env->{name} } = $env->{value};
		}
	}

	return $env_hashref;
}

sub _env_string {

	my $self = shift;
	my %args = @_;

	my $container_name = $args{container_name};

	my $env_hashref = $self->_env( container_name => $container_name );

	my @envs = ();
	foreach my $name ( sort keys %{$env_hashref} ) {
		
		my $value = $env_hashref->{$name};
		$value =~ s/"/\\"/g;

		push @envs, "$name=\"$value\"";
	}

	return wantarray ? @envs : \@envs;
};

sub start {

	my $self = shift;
	my %args = @_;

	my $tags = $args{tags};
	if ( $args{foreground} and not defined $args{command} ) {
		$args{command} = "/bin/bash";
	}

	# Get the process list of the containers.
	my $ps     = $self->control->ps;
	my $images = $self->control->images;
	
	my @container_order = $self->_container_order(
		containers => $args{containers},
		foreground => $args{foreground}
	);

	$self->debug( "Containter Order = " . join ( ", ", @container_order ) );

	# Get the order that the containers should be started
	while ( my $container_name = shift @container_order ) {

		my $config = $self->project_config->{containers}{ $container_name };

		next if ( not $config->{enabled} );

		$self->debug( "Starting image $container_name" );
		
		my $is_last_container = ( 
			not scalar @container_order
		or 
			( defined $args{start_until} and $args{start_until} eq $container_name )
		)?1:0;

		# If the container doesn't exists, try to build it
		if ( not defined $images->{$container_name} ) {

			# TODO: Attempt to download it

			$self->debug( "Image $container_name does not exist. Find or build it" );

			$self->build(
				container_name => $container_name
			);
		}

		my $instance_name = $self->_instance_name( $container_name );

		$self->debug( "Instance name is $instance_name" );

		my @command = ();

		# If we found it, it needs to be started
		if ( defined $ps->{ $instance_name } ) {

			my $status = $ps->{ $instance_name }{status};

			if ( $status =~ m/^Exit/ ) {
				push @command, "start";
			}
			elsif ( $status =~ m/^Up/  ) {
				push @command, "restart";
			}
			else {
				die "Don't know what to do with status $status";
			}

			push @command, $ps->{ $instance_name }{container_id};
		}
		else {
			push @command, "run";
			push @command, "--name";
			push @command, $instance_name;
			push @command, "-h";
			push @command, $instance_name;

			if ( $args{foreground} and $is_last_container ) {
				push @command, "-i";
				push @command, "-t";
				push @command, "--rm";
			}
			else {
				push @command, "-d";
			}

			if ( defined $config->{links} ) {
		
				foreach my $link ( @{$config->{links}} ) {

					if ( $self->project_config->{containers}{ $link }{type} ne "data" ) {
						push @command, "--link";
						push @command, sprintf( "%s:%s", $self->_instance_name( $link ), $self->_instance_name( $link ) );
					}

					push @command, "--volumes-from";
					push @command, $self->_instance_name( $link );
				}
			}

			if ( defined $config->{services} ) {

				foreach my $service ( @{$config->{services}} ) {
					push @command, "-p";
					push @command, sprintf( "%s:%s", $service->{src_port} + $self->port_offset, $service->{dst_port} );
				}
			}

			foreach my $env ( $self->_env_string( container_name => $container_name ) ) {
				push @command, "-e";
				push @command, $env;
			}

			push @command, $self->_image_name( container_name => $container_name );

			if ( defined $args{command} ) {
				push @command, $args{command};
			}
		}
	
		$self->control->command( command => \@command );
	}
}

sub build {

	my $self = shift;
	my %args = @_;

	my $container_name = $args{container_name};

	my $config = $self->project_config->{containers}{ $container_name };

	my $makefile_dir = $self->image_dir->subdir( $config->{type}, $config->{image} );

	$self->debug( "Build image with Makefile at $makefile_dir" );

	my $PARAMS="";

	system "cd $makefile_dir; $PARAMS make";
}

__PACKAGE__->meta->make_immutable;

1;
