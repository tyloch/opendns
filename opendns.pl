#!/usr/bin/perl

$|=1;
use strict;
use v5.10;
use FindBin qw($Bin);
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use Config::General;
use Data::Dumper;
use HTTP::Cookies;

my $urls = {
	dashboard => 'https://dashboard.opendns.com/',
	logon     => 'https://login.opendns.com',
	filter	  => 'https://dashboard.opendns.com/settings/%s/content_filtering',
	ajax	  => 'https://dashboard.opendns.com/dashboard_ajax.php',
};

my $conf = { Config::General->new( $Bin . '/opendns.conf')->getall };
my (undef,undef,$hour,undef,undef,undef,$wday,undef,undef) = localtime(time);
$wday = 7 unless $wday;
print "Start:".localtime(time)."\n";

my @rules = ();
foreach my $net (keys %{ $conf->{networks}}) {
	foreach my $rules (keys %{ $conf->{networks}->{$net}  }) {
		my ($days, $hours) = split /-/, $rules;
		next if $hours != $hour;
		next if $days !~ /$wday/;
		my $cont = { Config::General->new( $Bin . '/content.conf')->getall };
		push @rules, {
			net  => $net,
			rule => { %$cont, %{  $conf->{networks}->{$net}->{$rules} } }
		}

	}
}
exit unless @rules;
print "Executed ".@rules."\n";
my $ua = LWP::UserAgent->new(ssl_opts => { verify_hostname => 0 });
$ua->cookie_jar( HTTP::Cookies->new( file => $Bin . '/cookie.txt' , autosave => 1) );
$ua->agent($conf->{browser}->{agent});
$ua->timeout(10);
$ua->env_proxy;

if (my $e = checkauth($ua, $conf, $urls) ) {
	if ($e =~ /^\d{3}/) { say 'Auth Error: '. $e; exit } 
	else {
		$e =~ s/\s+/ /msg;
		my ($token) = $e =~ /input type="hidden" name="formtoken" value="([^"]+)"/;
		if ($e = login($ua, $conf, $urls, $token)) { say 'Login Error: ' . $e; exit; }
	}
}
foreach my $rule (@rules) {
acceptrule($ua, $conf, $urls, $rule);
}

sub checkauth {
	my $ua = shift;
	my $conf = shift;
	my $urls = shift;
	my $req = HTTP::Request->new(GET => $urls->{dashboard});
	$req->header('Referer', $urls->{dashboard});
	my $res = $ua->request($req);
	if ($res->is_success) {
		return $res->request->uri =~ /login\.opendns\.com/ ? $res->decoded_content : undef;
	} else {
		return $res->status_line;
	}
}

sub login {
	my $ua = shift;
        my $conf = shift;
        my $urls = shift;
	my $token = shift;
	my %form = (
		username => $conf->{auth}->{login},
		password => $conf->{auth}->{password},
		return_to => $urls->{dashboard},
		dont_expire => 'on',
		formtoken => $token,
	);
	my $req = POST( $urls->{logon}, [ %form ] );
	$req->header('Referer', $urls->{logon});
	my $res = $ua->request($req);
	if ($res->is_success) {
		return $res->request->uri =~ /dashboard\.opendns\.com/ ? undef : $res->request->uri;
	} else {
		return $res->status_line;
	}
}

sub acceptrule {
        my $ua = shift;
        my $conf = shift;
        my $urls = shift;
        my $rule = shift;
	my %form = (
		n => $rule->{net},
		action => 'save_blocking_categories',
		return => sprintf('/settings/%s/content_filtering', $rule->{net}),
		map { sprintf('dt_category[%s]', $_) => $_ } grep { $rule->{rule}->{$_} }  keys %{ $rule->{rule} }
	);
	my $req = POST( $urls->{ajax}, [ %form ] );
        $req->header('Referer', sprintf( $urls->{filter}, $rule->{net} ) );
        my $res = $ua->request($req);
        if ($res->is_success) {
		return
        } else {
                return $res->status_line;
        }
}
