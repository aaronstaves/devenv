package DevEnv::VM::Module;
use Moose;

extends 'DevEnv';
with 'DevEnv::Role::Project';

use Path::Class;
use Template;

use Data::Dumper;

has 'temp_dir' => (
	is      => 'ro',
	isa     => 'Path::Class::Dir',
	lazy    => 1,
	builder => '_build_temp_dir'
);
sub _build_temp_dir {

	my $self = shift;

	my $dir = Path::Class::tempdir(CLEANUP => 1);

	$self->debug( "Temp directory created at $dir" );

	return $dir;
}

has 'outside_home' => (
	is      => 'ro',
	isa     => 'Str',
	default => "Home",
);

sub avahi_service {

	my $self = shift;
	my %args = @_;

	my $vars = {
		box_name => $self->instance_name,
		name     => $args{name},
		type     => $args{type},
		port     => $args{port},
		records  => [],
	};

	if ( ( grep { $args{type} eq $_ } ( qw/nfs sftp ftp webdav/ ) ) and defined $args{path} ) {
		push @{$vars->{records}}, "path=" . $args{path};
	}
	if ( grep { $args{type} eq $_ } ( qw/ssh sftp ftp/ ) ) {
		push @{$vars->{records}}, "u=dev";
		push @{$vars->{records}}, "p=dev";
	}
	if ( $args{type} eq "device-info" ) {
		push @{$vars->{records}}, "model=Xserve";
	}

	my $inc_path = sprintf( "%s/templates/avahi/", $self->base_dir() );

	my $tt = Template->new(
		INCLUDE_PATH => $inc_path
	);

	my $service_text = "";
	$tt->process( "generic.tt", $vars, \$service_text ) or die $tt->error;

	return $service_text;
}

sub get_avahi_service_files {

	my $self = shift;

	my @avahi_files = ();
	foreach my $container_name ( keys %{$self->project_config->{containers}} ) {

		my $config = $self->project_config->{containers}{ $container_name };

		if ( defined $config->{services} ) {

			foreach my $service ( @{$config->{services}} ) {

				# Skip services without tpye
				next if ( not defined $service->{type} );

				my $name = lc $service->{name};
				$name =~ s/[^\w]/_/g;
				$name .= ".service";

				push @avahi_files, {
					name => $name,
					file => $self->avahi_service(
						box_name => $self->instance_name,
						name     => $service->{name},
						type     => $service->{type},
						port     => $service->{src_port},
						protocal => ( $service->{dst_port} =~ m/udp/ )?"udp":"tcp"
					)
				}
			}
        }
    }

	return wantarray ? @avahi_files : \@avahi_files;
}


sub start  { }
sub stop   { }
sub remove { }
sub build  { }

__PACKAGE__->meta->make_immutable;

1;
