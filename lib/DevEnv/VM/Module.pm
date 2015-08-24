package DevEnv::VM::Module;
use Moose;

extends 'DevEnv';
with 'DevEnv::Role::Project';

use Path::Class;
use Moose::Util::TypeConstraints;
use Template;

subtype 'VM_Directory',
	as "Path::Class::Dir";

coerce 'VM_Directory',
	from 'Str',
	via { dir( $_ ) };

has 'vm_dir' => (
	is       => 'ro',
	isa      => 'VM_Directory',
	required => 1,
	coerce   => 1
);

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

	$self->debug( "Building " . $args{name} );

	my $vars = {
		box_name => $self->instance_name,
		name     => $args{name},
		service  => $args{service},
		port     => $args{port},
		records  => [],
	};

	if ( ( grep { $args{service} eq $_ } ( qw/nfs sftp ftp webdav/ ) ) and defined $args{path} ) {
		push @{$vars->{records}}, "path=" . $args{path};
	}
	if ( grep { $args{service} eq $_ } ( qw/ssh sftp ftp/ ) ) {
		push @{$vars->{records}}, "u=dev";
		push @{$vars->{records}}, "p=dev";
	}
	if ( $args{service} eq "device-info" ) {
		push @{$vars->{records}}, "model=Xserve";
	}

	my $inc_path = sprintf( "%s/templates/avahi/", $self->base_dir() );

	$self->debug( "Template include path is $inc_path" );

	my $tt = Template->new(
		INCLUDE_PATH => $inc_path
	);

	my $service_text = "";
	$tt->process( "generic.tt", $vars, \$service_text ) or die $tt->error;

	return $service_text;
}

sub start { }
sub stop  { }
sub halt  { }
sub build { }

__PACKAGE__->meta->make_immutable;

1;
