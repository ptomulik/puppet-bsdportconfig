# bsdportconfig

[![Build Status](https://travis-ci.org/ptomulik/puppet-bsdportconfig.png?branch=master)](https://travis-ci.org/ptomulik/puppet-bsdportconfig)

Configure build options for FreeBSD ports.

### Warning

*Bsdportconfig* was not developed for last few years and may not work with
recent FreeBSD releases. I'm not going to develop it further, as there
is [ptomulik/portsng](https://forge.puppet.com/ptomulik/portsng),
which handles build options, ports maintenance (install/uninstall/update)
and is a mature and tested module.

#### Table of Contents

1. [Overview](#overview)
2. [Module Description](#module-description)
3. [Setup](#setup)
    * [What Bsdportconfig affects](#what-bsdportconfig-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with Bsdportconfig](#beginning-with-bsdportconfig)
4. [Usage](#usage)
5. [Limitations](#limitations)
6. [Development](#development)

## Overview

This module implements a **bsdportconfig** resource which maintains build
options for packages installed with BSD ports.

## Module Description

The **bsdportconfig** module helps to configure BSD ports.

Installation and de-installation of FreeBSD ports is handled quite well by
`package` resource from **puppet**'s core. However, it has no way to
set configuration options for ports (no `make config` stage), and always
installs packages with their default options (or with manually pre-set
options).

This module tries to fill this gap. It helps to ensure, that certain
configuration options are set (or unset) for certain ports. You may chain the
**bsdportconfig** resource with **package** to achieve automatic configuration
of ports before they get installed.

The module supports only the **on/off** options.

## Setup

### What Bsdportconfig affects

This module affects:

* options for given ports, it's done by modifying options files
  `$PORT_DBDIR/*/options.local`, where `$PORT_DBDIR='/var/db/ports'` by
  default,
* make command is used to search ports and retrieve port characteristics,
  these invocations of `make`  are read-only and should not affect your system
  by their own,

### Setup Requirements

You may need to enable **pluginsync** in your *puppet.conf*.

### Beginning with Bsdportconfig

**Note**: the resource writes to file only the options listed in `options`
parameter. Other options do are not written to options files.

**Example**: ensure that `www/apache22` is configured with `SUEXEC` and `CGID`
modules:

    bsdportconfig { 'www/apache22': options => { 'SUEXEC'=>on, 'CGID'=>on } }

**Example**: ensure that `www/apache22` is configured without `CGID` module:

    bsdportconfig { 'www/apache22': options => { 'CGID'=>off } }

**Example**: install `www/apache22` package with `SUEXEC` module enabled:

    bsdportconfig { 'www/apache22': options => { 'SUEXEC'=>on } }
    package { 'www/apache22': require => Bsdportconfig['www/apache22'] }

**Example**: since version 0.1.6 you may use *portnames* to identify ports:

    bsdportconfig { 'apache22': options => {'SUEXEC'=>on} }

**Example**: since version 0.2.0 *pkgnames* are also supported:

    bsdportconfig { 'apache22-2.2.25': options => {'SUEXEC'=>on} }


## Usage

### Resource type: `bsdportconfig`

Set build options for BSD ports.

#### TERMINOLOGY

We use the following terminology when referring ports/packages:

  * a string in form `'apache22'` or `'ruby'` is referred to as *portname*
  * a string in form `'apache22-2.2.25'` or `'ruby-1.8.7.371,1'` is referred to
    as a *pkgname*
  * a string in form `'www/apache22'` or `'lang/ruby18'` is referred to as a
    port *origin*

See [http://www.freebsd.org/doc/en/books/porters-handbook/makefile-naming.html](http://www.freebsd.org/doc/en/books/porters-handbook/makefile-naming.html)

Port *origins* are used as primary identifiers for bsdportconfig instances.
It's recommended to use *origins* or *pkgnames* to identify ports.

#### AMBIGUITY OF PORTNAMES

Accepting *portnames* (e.g. `apache22`) as the [name](#name-required)
parameter was introduced for convenience in 0.2.0. However, *portnames* in
this form are ambiguous, meaning that port search may find multiple ports
matching the given *portname*. For example `'ruby'` package has three ports
at the time of this writing  (2013-08-30): `ruby-1.8.7.371,1`,
`ruby-1.9.3.448,1`, and `ruby-2.0.0.195_1,1` with origins `lang/ruby18`,
`lang/ruby19` and `lang/ruby20` respectively. If you pass a portname which
matches multiple ports, transaction will fail with a message such as:

    Error: Could not prefetch bsdportconfig provider 'ports': found 3 ports with name 'ruby': 'lang/ruby18', 'lang/ruby19', 'lang/ruby20'

#### Parameters within `bsdportconfig`:

##### name (required)

Reference to a port. A *portname*, *pkgname* name or *origin* may be passed as
the `name` parameter (see [TERMINOLOGY](#terminology) in resource description).
If the name has form 'category/subdir' it is treated as an *origin*. Otherwise,
the provider tries to find matching port by *pkgname* and if it fails, by
*portname*. Note, that *portname*s are ambiguous, see [AMBIGUITY OF
PORTNAMES](#ambiguity-of-portnames) in the resource description.


##### options (optional)

Options for the package. This is a hash with keys being option names and values
being `'on'/'off'` strings.

## Limitations

These are limitation I see at the moment:

  * tested manually on FreeBSD only - any feedback welcome from other OSes,
  * unit tests for provider are still missing,
  * only on/off options are currently supported, more knowledge about BSD ports
    is necessary (are there other option types?)
  * only options from option files (`/var/db/ports/*/options{,.local}`) are
    taken into account when retrieving current resource state,
  * we no longer use public `make showconfig` interface to read option values
    (it was too slow); the options are retrieved from options files only; this
    may have some limitations now, and may cause some bugs in future - the
    algorithm used to read files resembles what was seen in ports' Makefiles,
    but it was also seen, that the algorithm used by ports is going to be
    changed (so we may desync at some point)

## Development

Project is held on GitHub:

[https://github.com/ptomulik/puppet-bsdportconfig](https://github.com/ptomulik/puppet-bsdportconfig)

Feel free to submit issue reports to issue tracker or create pull requests.
