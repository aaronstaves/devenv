package DevEnv::Docker;
use Moose;

extends 'DevEnv';
with 'DevEnv::Role::Project';

use DevEnv::Exceptions;
use DevEnv::Docker::Control;

use Path::Class;
use Data::Dumper;
use LWP::UserAgent;
use File::Path qw/make_path remove_tree/;
use JSON::XS;

has 'control' => (
	is       => 'ro',
	isa      => 'DevEnv::Docker::Control',	
	lazy     => 1,
	builder  => '_build_control'
);
sub _build_control {

	my $self = shift;

	return DevEnv::Docker::Control->new(
		instance_name => $self->instance_name,
		verbose       => $self->verbose
	);
}

has 'image_dirs' => (
	traits   => ['Array'],
	is       => 'ro',
	isa      => 'ArrayRef[Path::Class::Dir]',
	lazy     => 1,
	builder  => '_build_image_dirs',
	handles  => {
		all_image_dirs => "elements"
	}
);
sub _build_image_dirs {

	my $self = shift;

	my @dirs = ();

	if ( defined $ENV{DEVENV_IMAGE_DIR} ) {
		push @dirs, dir ( $ENV{DEVENV_IMAGE_DIR} );
	}
	push @dirs, dir( $ENV{HOME}, ".devenv", "images" );
	push @dirs, $self->base_dir->subdir( "images" );

	return \@dirs;
}

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

	my $ignore_enabled = $args{ignore_enabled} // 0;

	my $scoreboard = undef;

	foreach my $container_name ( keys %{$self->project_config->{containers}} ) {

		my $container_config = $self->project_config->{containers}{ $container_name };

		next if ( not $container_config->{enabled} and not $ignore_enabled );

		# Always start the data container first
		if ( $container_config->{type} eq "data" ) {

			$scoreboard->{ $container_name } += 1_000_000;
		}
	
		# If the we want it in the foreground, make sure the work container goes last
		if ( $container_config->{type} eq "work" ) {

			if ( $args{foreground} ) {
				$scoreboard->{ $container_name } -= 1_000_000;
			}
		}

		$scoreboard->{ $container_name } //= 0;

		# Increase the score of the container that is link required for this one
		if ( defined $container_config->{links} and ref $container_config->{links} eq "ARRAY" ) {

			foreach my $link ( @{$container_config->{links}} ) {

				next if ( not $self->project_config->{containers}{ $link }{enabled} );

				$scoreboard->{ $link }++;
			}
		}

		$container_config->{rank_order} = $scoreboard->{ $container_name };
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

	open my $gateway, q{/sbin/route -n | grep 'UG[ \t]' | awk '{print $2}'} . " |";
	my $gateway_ip = <$gateway>;
	close $gateway;
	chomp $gateway_ip;

	my $env_hashref = {
		DEVENV_MY_UID        => $self->user_id,
		DEVENV_MY_GID        => $self->group_id,
		DEVENV_MY_HOME       => $self->home_dir,
		DEVENV_INSTANCE_NAME => $self->instance_name,
		DEVENV_GATEWAY       => $gateway_ip,
		DEVENV_HELPER_PORT   => $self->project_config->{helper}{port}
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

	if ( $args{foreground} and not defined $args{command} ) {
		$args{command} = "/bin/bash";
	}

	# Get the process list of the containers.
	my $ps     = $self->control->ps;
	my $images = $self->control->images;

	my @container_order = $self->_container_order(
		foreground => $args{foreground}
	);

	$self->debug( "Containter Order = " . join ( ", ", @container_order ) );


	my @instance_names = ();

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

		my $image_name = $self->_image_name( container_name => $container_name );

		# If the container doesn't exists, try to build it
		if ( not defined $images->{ $image_name } ) {

			# TODO: Attempt to download it

			if ( defined $self->project_config->{docker}{registry} ) {

				$self->control->pull(
					registries => $self->project_config->{docker}{registry},
					image_name => $image_name
				);
				
				$images = $self->control->images;
			}

			if ( not defined $images->{ $image_name } ) {

				$self->debug( "Image $container_name does not exist. Find or build it" );

				$self->build(
					container_name => $container_name
				);

				$images = $self->control->images;
			}
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
				DevEnv::Exception::Docker->throw( "Don't know what to do with status $status." );
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

					next if ( not $self->project_config->{containers}{ $link }{enabled} );

					if ( $self->project_config->{containers}{ $link }{type} ne "data" ) {
						push @command, "--link";
						push @command, sprintf( "%s:%s", $self->_instance_name( $link ), $self->_instance_name( $link ) );
					}

					push @command, "--volumes-from";
					push @command, $self->_instance_name( $link );
				}
			}

			# Always mount the home directory in the work container
			if ( $config->{type} eq "work" ) {

				push @{$config->{shares}}, {
					src_dir  => $self->home_dir,
					dest_dir => "/home/dev"
				};
			}

			if ( defined $config->{shares} ) {

				foreach my $share ( @{$config->{shares}} ) {

					push @command, "-v";
					push @command, sprintf( "%s:%s", $share->{src_dir}, $share->{dest_dir} );
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

		# Let the containter start
		sleep 3;

		# Update the PS
		$ps = $self->control->ps;

		if ( not defined $ps->{ $instance_name } ) {

			DevEnv::Exceptions->throw( "Could not start up a container for $instance_name" );
		}

		push @instance_names, $instance_name;
	}

	# Save information about this instance's containters in the $HOME .devenv directory
	my $info = $self->control->status( container_name => join( " ", @instance_names ) );

	my @host_entries = ();
	foreach my $container ( @{$info} ) {
	
		push @host_entries, sprintf( "%s\t%s", $container->{NetworkSettings}{IPAddress}, $container->{Config}{Hostname} );
	}

	if ( defined $self->project_config->{hosts} ) {

		foreach my $host_item ( @{$self->project_config->{hosts}} ) {
			push @host_entries, sprintf( "%s\t%s", $host_item->{ip}, $host_item->{host} );
		}
	}

	my $info_dir = $self->devenv_dir->subdir( "info", $self->instance_name );

	make_path ( $info_dir->stringify );

	open my $fh, ">", $info_dir->file( "docker_hosts" )->stringify;
	print $fh join ( "\n", @host_entries );
	close $fh;

	open $fh, ">", $info_dir->file( "inspect.json" )->stringify;
	print $fh JSON::XS->new->encode( $info );
	close $fh;
}

sub stop {

	my $self = shift;
	my %args = @_;

	# Get the process list of the containers.
	my $ps     = $self->control->ps;
	my $images = $self->control->images;
	
	my @container_order = $self->_container_order(
		ignore_enabled => 1
	);

	$self->debug( "Containter Order = " . join ( ", ", @container_order ) );

	# Get the order that the containers should be started
	foreach my $container_name ( reverse @container_order ) {

		my $config = $self->project_config->{containers}{ $container_name };

		next if ( not $config->{enabled} );

		# No need to stop a data container
		next if ( $config->{type} eq "data" );

		my $instance_name = $self->_instance_name( $container_name );

		my @command = (
			"stop",
			$instance_name
		);

		$self->control->command( command => \@command );
	}
}

sub remove {

	my $self = shift;
	my %args = @_;

	my $force = $args{force} // 0;

	# Get the process list of the containers.
	my $ps     = $self->control->ps;
	my $images = $self->control->images;
	
	my @container_order = $self->_container_order(
		ignore_enabled => 1
	);

	$self->debug( "Containter Order = " . join ( ", ", @container_order ) );

	# Get the order that the containers should be started
	foreach my $container_name ( reverse @container_order ) {

		my $config = $self->project_config->{containers}{ $container_name };

		# Only remove the data container if forced
		next if ( $config->{type} eq "data" and not $force );

		my $instance_name = $self->_instance_name( $container_name );

		my @command = (
			"rm",
			"--force",
			$instance_name
		);

		$self->control->command( command => \@command );
	}
}

sub log {
	
	my $self = shift;
	my %args = @_;

	my $container_name = $args{container_name};

	my @command = (
		"logs",
		$container_name
	);

	return $self->control->run( command => \@command );
}

sub find_image_src {

	my $self = shift;
	my %args = @_;

	my $type  = $args{type};
	my $image = $args{image};

	my $use_makefile_dir = undef;

	foreach my $image_dir ( $self->all_image_dirs ) {

		my $makefile_dir = $image_dir->subdir( $type, $image );

		if ( -d $makefile_dir->stringify() ) {

			$use_makefile_dir = $makefile_dir;
			last;
		}
	}	

	if ( not defined $use_makefile_dir ) {
		DevEnv::Exception->throw( "Cannot find image $type/$image" ) ;
	}

	return $use_makefile_dir;
}

sub build {

	my $self = shift;
	my %args = @_;

	my $container_name = $args{container_name};

	my $config = $self->project_config->{containers}{ $container_name };

	my $use_makefile_dir = $self->find_image_src(
		type  => $config->{type},
		image => $config->{image}
	);

	$self->debug( "Build image with Makefile at $use_makefile_dir" );

	my $PARAMS="";

	system "cd $use_makefile_dir; $PARAMS make";
}

sub status {

	my $self = shift;
	my %args  = @_;

	my $all_containers = $args{all} // 1;

	my $ps     = $self->control->ps();
	my $images = $self->control->images();

	my @container_order = $self->_container_order(
		ignore_enabled => 1
	);


	my $is_running = 1;
	my $num_containers = 0;
	my $running_containers = 0;
	foreach my $container_name ( @container_order ) {

		my $instance_name = $self->_instance_name( $container_name );
		my $container_config = $self->project_config->{containers}{ $container_name };

		next if ( not $container_config->{enabled} or $container_config->{type} eq "data" );

		$num_containers++;

		my $container_ps = $ps->{ $instance_name };

		if ( defined $container_ps ) {

			if ( $container_ps->{status} !~ m/^Up/ ) {
				$is_running = 0;
			}
			else {
				$running_containers++;
			}
		}
	}

	my $status = {
		is_running         => ( $running_containers > 0 and $is_running ),
		num_containers     => $num_containers,
		running_containers => $running_containers,
		is_error           => ( $running_containers != 0 and $num_containers != $running_containers )?1:0,
	};

	foreach my $container_name ( @container_order ) {

		my $instance_name = $self->_instance_name( $container_name );

		my $container_config = $self->project_config->{containers}{ $container_name };
		my $container_ps     = $ps->{ $instance_name };

		push @{$status->{containers}}, {
			status => {
				error => (
					$container_config->{type} ne "data" and 
					$container_config->{enabled} and 
					$is_running and 
					defined $container_ps and
					$container_ps->{status} !~ m/^Up/
				)?1:0,
				is_running => ( defined $container_ps and $container_ps->{status} =~ m/^Up/)?1:0,
			},
			config => $container_config,
			ps     => $container_ps,
			image  => $images->{ $self->_image_name( container_name => $container_name ) }
		};
	}

	@{$status->{containers}} = sort {
		$b->{config}{enabled} <=> $a->{config}{enabled} || 
			$b->{config}{rank_order} <=> $a->{config}{rank_order} ||
			$a->{config}{name} cmp $b->{config}{name}
	} @{$status->{containers}};

	return $status;
}

sub host_file_write {

	my $self = shift;

	open my $host, "cat /etc/hosts |";

	close $host;
}

__PACKAGE__->meta->make_immutable;

1;
