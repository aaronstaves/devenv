package DevEnv::Helper;
use Moose;
use MooseX::NonMoose;
extends 'HTTP::Server::Simple::CGI';

use DevEnv;
use DevEnv::Exceptions;

use Template;
use Expect;
use Try::Tiny;
use JSON::XS;

has 'devenv' => (
	isa     => 'DevEnv',
	is      => 'ro',
	lazy    => 1,
	builder => "_build_devenv"
);
sub _build_devenv {

	my $self = shift;

	return DevEnv->new(
		instance_name => "default",
		verbose       => 1
	);
}

sub handle_request {

	my $self = shift;
	my $cgi  = shift;

	my $path = $cgi->path_info();

	my ( $action ) = $path =~ m/([^\/]+)$/;

	print STDERR "Path $path = " . ( $action || "NA" ) . "\n";

	try {

		if ( defined $action and $action =~ m/^(action|page|file)/ and $self->can( "_$action" ) ) {
			my $func = "_$action";
			$self->$func( cgi => $cgi, path => $path );
		}
		elsif ( $path eq "/" ) {
			$self->_page_index(
				cgi => $cgi, path => $path
			);
		}
		else {
			$self->_error(
				status  => 404, 
				error   => "Not Found",
				message => "Could not find an action for $path"
			);
		}
	}
	catch {

		$self->_error(
			cgi     => $cgi,
			error   => "$_",
			message => "Error"
		);
	};

	return undef;
}

sub _template {

	my $self = shift;
	my %args = @_;

	my $vars     = $args{vars} || {};
	my $template = $args{template};

	my $include_path = $self->devenv->base_dir->subdir( "templates", "web" )->stringify();

	print STDERR "Include Path =  $include_path\n";

	my $tt = Template->new({
		INCLUDE_PATH => $include_path,
		EVAL_PERL    => 1,
	}) or die "$Template::ERROR\n";

	my $output = '';
	$tt->process( $template, $vars, \$output) or die "Cannot generate $template";

	print $output;
}

sub _ok {

	my $self = shift;
	my %args = @_;

	my $cgi          = $args{cgi};
	my $template     = $args{template};
	my $vars         = $args{vars} // {};
	my $content_type = $args{content_type} // "text/html";
	my $content      = $args{content};

	print "HTTP/1.0 200 OK\r\n";
	print $cgi->header( $content_type );

	if ( defined $template ) {

		$self->_template(
			template => $template,
			vars     => $vars
		);
	}
	else {
		print $content;
	}

	return undef;
}

sub _error {

	my $self = shift;
	my %args = @_;

	my $cgi     = $args{cgi};
	my $status  = $args{status} || 500;
	my $error   = $args{error};
	my $message = $args{message};

	print STDERR "$error\n";
	print STDERR "$message\n";

	print "HTTP/1.0 $status Error\r\n";
	print $cgi->header;

	$self->_template(
		template => "error.tt",
		vars     => {
			status  => $status,
			title   => $error,
			error   => $error,
			message => $message
		}
	);

	return undef;
}

sub _page_index {

	my $self = shift;
	my %args = @_;

	my $cgi = $args{cgi};

	$self->_ok(
		cgi          => $cgi,
		template     => "helper_index.tt",
	);

	return undef;
}

sub _action_dns {

	my $self = shift;
	my %args = @_;

	my $cgi = $args{cgi};

	my $host = $cgi->param('host');

	my $ip = undef;

	my $exp = Expect->new();
	$exp->raw_pty(1);
	$exp->spawn( "/bin/bash" ) or die "Cannot spawn bash: $!\n";

	$exp->send( "dns-sd -q $host\n");
	$exp->expect(
		10,
		[ 
			qr/STARTING/ => sub {
				my $exp = shift;
				$exp->clear_accum();
           	},
		]
	);
	$exp->expect(
		10,
		[ 
			qr/$host/ => sub {
				my $exp = shift;
	            sleep 2;

				my $buffer = $exp->after();

				( $ip ) = $buffer =~ m/(\d+\.\d+\.\d+\.\d+)/;
           	},
		]
	);
	$exp->hard_close();

	$self->_ok(
		cgi          => $cgi,
		content_type => "applitcation/json",
		content      => JSON::XS->new->utf8->pretty->encode(
			{
				host => $host,
				ip   => $ip
			}
		)
	);

	return undef;
}

no Moose;

__PACKAGE__->meta->make_immutable;
