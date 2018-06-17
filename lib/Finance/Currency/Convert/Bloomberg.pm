package Finance::Currency::Convert::Bloomberg;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::ger;

use List::Util qw(min);

use Exporter 'import';
our @EXPORT_OK = qw(convert_currency);

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    summary => 'Convert currency using Bloomberg',
    description => <<"_",

This module can extract currency rates from the Bloomberg website.

_
};

$SPEC{convert_currency} = {
    v => 1.1,
    summary => 'Get currency conversion rate from Bloomberg website',
    args => {
        n => {
            schema=>'float*',
            req => 1,
            pos => 0,
        },
        from => {
            schema=>'currency::code*',
            req => 1,
            pos => 1,
        },
        to => {
            schema=>'currency::code*',
            req => 1,
            pos => 2,
        },
    },
};
sub convert_currency {
    my %args = @_;
    # XXX schema
    my $n    = $args{n}    or return [400, "Please specify n"];
    my $from = $args{from} or return [400, "Please specify from"];
    my $to   = $args{to}   or return [400, "Please specify to"];

    #return [543, "Test parse failure response"];

    my $ua;
    unless ($args{_page_content} && $args{_api_page_content}) {
        require Mojo::UserAgent;
        $ua = Mojo::UserAgent->new;
        $ua->transactor->name("Mozilla/4.0"); # otherwise bloomberg throws a 404 for the url
    }

    # we need to get 2 urls, the api does not provide the multiplier
    my $url = "https://www.bloomberg.com/quote/$from$to:CUR";
    #log_trace "url=%s", $url;

    my $page;
    if ($args{_page_content}) {
        $page = $args{_page_content};
    } else {
        my $tx = $ua->get($url);
        unless ($tx->success) {
            my $err = $tx->error;
            return [500, "Can't retrieve Bloomberg page ($url): ".
                        "$err->{code} - $err->{message}"];
        }
        $page = $tx->res->body;
    }
    log_trace "Page: [[$page]]";

    exit;
    my $urlapi = "https://www.bloomberg.com/markets/api/quote-page/$from$to:CUR?locale=en";
    #log_trace "urlapi=%s", $urlapi;



    my $data;
  PARSE_JSON:
    {
        require JSON::MaybeXS;
        eval {
            $data = JSON::MaybeXS::decode_json($page);
        };
        return [543, "Didn't get JSON response from URL '$url': $@"] if $@;
    }

    my $mult;
    unless ($page =~ m!<meta itemProp="name" content="$from$to Spot Exchange Rate - Price of ([0-9,.]+) $from in $to"/>!) {
        return [543, "Cannot find signature"];
        unless ($mult = Parse::Number::EN::parse_number_en(text => $1)) {
            return [543, "Cannot parse number '$1'"];
        }
    }

    my $rate;
  GET_RATE:
    {
        #unless ($page =~ m!<span class="priceText__1853e8a5">([0-9,.]+)</span>!) {
        #    return [543, "Cannot extract price"];
        #    $rate = Parse::Number::EN::parse_number_en(text=>$1);
        #    return [543, "Cannot parse number '$1'"] unless $rate;
        #}

        unless ($page =~ m!<meta itemProp="price" content="(\d+(?:\.\d+))"/>!) {
            return [543, "Cannot extract price"];
        }
        $rate = $1;
    }

    my $mtime;
  GET_MTIME:
    {
        unless ($page =~ m!<meta itemProp="quoteTime" content="((\d\d\d\d)-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d(?:.\d+))Z)"/>!) {
            log_warn "Cannot find last update (quote) time";
            last;
        }
        $mtime = Time::Local::timegm($7, $6, $5, $4, $3-1, $2) or do {
            log_warn "Cannot parse last update (quote) time '$1'";
            last;
        };
    }

    [200, "OK", $n * $rate / $mult, {
        'func.mtime' => $mtime,
    }];
}

1;
# ABSTRACT:

=head1 SYNOPSIS

 use Finance::Currency::Convert::Bloomberg qw(convert_currency);

 my $res = convert_currency(n=>1, from=>"USD", to=>"IDR"); # [200, "OK", 13932,

=cut
