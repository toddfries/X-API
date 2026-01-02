X-API
===========
This is a fork of the Twitter::API module that was unceremoniously abandoned by its author when X chose to abandon the Twitter third-party developer community.

The reason given was to combat bot abuse, but the heavy hand effected many businesses relying on third-party access.

Since then, a series of changes has been gradually better, but nowhere near what it was.

First change was many but not all API calls have benn given free tier access, with very limited frequency of use.  Testing can continue, but not in earnest.

Second change was a beta program with per api call charges, very low, like per hour compute in aws, this scales well to low level testing as well as higher use caes, pay as you use essentially.

Third change was a release of a playground go program that simulates the X API in its entirety, so code can be used to test against it with or without limits (it permits you to turn them on and off to ensure your code can handle limits).

Try it out: [X Playground](https://github.com/xdevelopment/playground)

[![Build Status](https://travis-ci.org/semifor/Twitter-API.svg?branch=master)](https://travis-ci.org/semifor/Twitter-API)
[![CPAN](https://img.shields.io/cpan/v/Twitter-API.svg)](https://metacpan.org/pod/Twitter::API)

This is a rewrite of [Net::Twitter][1] and [Net::Twitter::Lite][2]. If it works out, I'll deprecate those modules in favor of this one.

I have several goals for the rewrite:
* leaner
* more robust
* optional support for non-blocking IO (AnyEvent, POE, etc.)
* easier to maintain
* easier to grok, so easier for contributers to…contribute
* support new API endpoints without necessitating a new distribution release

Install
-------

To get started, clone the repository, install [Carton][3] if you don't already have it, and run `carton install` in the working directory.

See the [current examples](examples).

The core of this code is currently in `Twitter::API::request`. The idea is to have a sequence of stages that have the proper granularity so they can be easily augmented with roles (traits) or overridden in derived classes to easily extend and enhance the core. The base module should be lean, and fully functional for the most common use cases.

Feedback
--------

If you have feedback, or want to help, find me in [#net-twitter][4] on irc.perl.org, or file an issue. Be patient on IRC. I'm away for hours, sometimes days, at a time.

[1]: http://metacpan.org/pod/Net::Twitter
[2]: http://metacpan.org/pod/Net::Twitter::Lite
[3]: http://metacpan.org/pod/Carton
[4]: irc:://irc.perl.org#net-twitter
